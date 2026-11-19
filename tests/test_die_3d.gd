extends SceneTree

const Die = preload("res://scripts/die_3d.gd")
var checks: int = 0
var results: Array[int] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)


func make_die() -> RigidBody3D:
	var die := Die.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	die.add_child(collision)
	return die


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var die := make_die()
	die.freeze = true
	world.add_child(die)
	# Exercise all 24 cube orientations, including every opposite face and yaw.
	var rotations: Array[Vector3] = [Vector3.ZERO, Vector3(PI, 0, 0),
		Vector3(0, 0, PI / 2), Vector3(0, 0, -PI / 2),
		Vector3(-PI / 2, 0, 0), Vector3(PI / 2, 0, 0)]
	var faces: Array[int] = [1, 6, 2, 5, 3, 4]
	for index in range(rotations.size()):
		for yaw in range(4):
			die.basis = Basis(Vector3.UP, yaw * PI / 2) * Basis.from_euler(rotations[index])
			check(die.get_top_face() == faces[index], "Cube orientation %d/%d" % [index, yaw])
	world.rotation = Vector3(0.3, 0.6, -0.4)
	die.global_basis = Basis(Vector3.RIGHT, -PI / 2)
	check(die.get_top_face() == 3, "Uses global axes under rotated parent")
	world.rotation = Vector3.ZERO
	die.positive_y_face = 6
	die.basis = Basis.IDENTITY
	check(die.get_top_face() == 6, "Configurable mesh face layout")
	die.positive_y_face = 1
	die.stopped.connect(func(face: int) -> void: results.append(face))

	# An airborne slow body must not score at a trajectory apex.
	die.gravity_scale = 0.0
	die.can_sleep = false
	die.position = Vector3(0, 5, 0)
	die.roll(Vector3.ZERO, Vector3.ZERO)
	await create_timer(0.7).timeout
	check(results.is_empty() and die.is_rolling, "Airborne zero speed does not settle")
	die.sleeping = true
	await create_timer(0.1).timeout
	check(results.size() == 1 and results[0] == 1, "Sleeping completes the roll")
	await create_timer(0.1).timeout
	check(results.size() == 1, "Stopped emits once per throw")

	# Real floor collision and threshold-based settling, with auto-sleep disabled.
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30, 1, 30)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	die.freeze = true
	die.position = Vector3(0, 1, 0)
	die.gravity_scale = 1.0
	await physics_frame
	die.roll(Vector3(0.4, 3, 0.3), Vector3(0.4, 0.2, 0.3))
	await create_timer(0.1).timeout
	check(die.linear_velocity.length() > 0.1, "Impulse causes physical movement")
	check(die.angular_velocity.length() > 0.1, "Torque impulse causes physical spin")
	for tick in range(900):
		await physics_frame
		if not die.is_rolling:
			break
	check(results.size() == 2 and not die.is_rolling, "Collision throw settles without automatic sleep")
	check(results[1] == die.get_top_face(), "Reported physical result matches orientation")
	check(die.position.y > 0.4 and die.position.y < 0.7, "Die rests on floor")

	var scored: int = die.value
	var slot := Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(3, 2, -1))
	die.set_kept(true, slot, 0.15)
	check(die.is_kept and die.freeze and die.freeze_mode == RigidBody3D.FREEZE_MODE_KINEMATIC,
		"Keep freezes physics in kinematic mode")
	die.roll_random()
	check(not die.is_rolling, "Kept dice ignore throws")
	await create_timer(0.3).timeout
	check(die.global_transform.is_equal_approx(slot), "Keep tween reaches slot position and rotation")
	check(die.value == scored and results.size() == 2, "Keep preserves score and emits no extra stop")
	var other_slot := Transform3D(Basis.IDENTITY, Vector3(-3, 4, 0))
	die.set_kept(true, other_slot, 0.2)
	await create_timer(0.05).timeout
	die.set_kept(false)
	check(not die.freeze and not die.is_kept, "Release restores physics")
	die.gravity_scale = 0.0
	die.linear_velocity = Vector3.ZERO
	var released: Vector3 = die.global_position
	await create_timer(0.3).timeout
	check(die.global_position.is_equal_approx(released), "Release cancels pending keep tween")
	die.set_kept(true, slot, 0.0)
	check(die.global_transform.is_equal_approx(slot), "Zero duration snaps to slot")
	die.set_kept(false)
	die.roll(Vector3.ZERO, Vector3.ZERO)
	await create_timer(0.05).timeout
	die.sleeping = true
	await create_timer(0.4).timeout
	check(results.size() == 3, "New throw rearms stop signal")
	world.queue_free()
	await process_frame
	print("PASS: %d 3D die checks" % checks)
	quit(0)
