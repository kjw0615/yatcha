extends SceneTree

const Die = preload("res://scripts/die_3d.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		failures += 1

func run() -> void:
	var board = load("res://scenes/board_3d.tscn").instantiate()
	root.add_child(board)
	# Every frame checks all eight vertices, not only the body center.
	for round_index in range(4):
		for i in range(5):
			var die = board.dice_nodes[i]
			die.freeze = true
			die.position = Vector3((i - 2) * 1.8, 3.4, 1.0) if round_index < 3 else Vector3(0, 2, 0)
			die.basis = Basis.from_euler(Vector3(i * 0.31, i * 0.53, i * 0.19))
		await physics_frame
		for i in range(5):
			var die = board.dice_nodes[i]
			var sign_x := -1.0 if i % 2 == 0 else 1.0
			var impulse := Vector3(sign_x * 4.4, 2.0, -5.0)
			if round_index == 1:
				impulse = Vector3(sign_x * 10000, 10000, 10000)
			elif round_index == 2:
				impulse = Vector3(sign_x * 10000, -10000, -10000)
			die.roll(impulse, Vector3(10000, -10000, 10000))
		for tick in range(600):
			await physics_frame
			for die in board.dice_nodes:
				check(die.global_transform.is_finite(), "Finite pose after extreme collision")
				for x in [-0.5, 0.5]:
					for y in [-0.5, 0.5]:
						for z in [-0.5, 0.5]:
							var vertex: Vector3 = die.transform * Vector3(x, y, z)
							check(absf(vertex.x) <= 5.51 and absf(vertex.z) <= 4.51 and vertex.y <= 6.01 and vertex.y >= -0.2,
								"Cube stays inside tray, round %d tick %d: %s" % [round_index, tick, vertex])
			var active := false
			for die in board.dice_nodes:
				active = active or die.is_rolling
			if not active:
				break
		for die in board.dice_nodes:
			check(not die.is_rolling, "Extreme/overlap throw settles within 10 seconds (round %d)" % round_index)
			check(die.value == die.get_top_face(), "Settled score matches geometry")
	# Controlled edge/corner poses: repeatability and both sides of an edge tie.
	var probe = board.dice_nodes[0]
	probe.freeze = true
	for angle in [PI / 4 - 0.0001, PI / 4, PI / 4 + 0.0001, atan(sqrt(2.0))]:
		probe.basis = Basis(Vector3.FORWARD, angle)
		var face: int = probe.get_top_face()
		check(face >= 1 and face <= 6, "Valid tilted face")
		for repeat in range(100):
			check(probe.get_top_face() == face, "Stationary tilted face is repeatable")
	probe.basis = Basis(Vector3.FORWARD, PI / 4 - 0.0001)
	check(probe.get_top_face() == 1, "Before edge tie")
	probe.basis = Basis(Vector3.FORWARD, PI / 4 + 0.0001)
	check(probe.get_top_face() == 5, "After edge tie")
	board.queue_free()
	await process_frame
	print("RESULT: %d checks, %d failures (4 throws, 5 dice)" % [checks, failures])
	quit(0 if failures == 0 else 1)
