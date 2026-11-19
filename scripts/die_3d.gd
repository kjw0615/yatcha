extends RigidBody3D
## D6 physics controller. Attach a centered CollisionShape3D and align the mesh
## with the face axes below. Keep this body and its ancestors at unit scale.

signal stopped(value: int)

@export_group("Face layout (opposite face = 7 - value)")
@export_range(1, 6) var positive_y_face: int = 1
@export_range(1, 6) var positive_x_face: int = 2
@export_range(1, 6) var positive_z_face: int = 3

@export_group("Settling")
@export_range(0.001, 2.0) var linear_stop_threshold: float = 0.08
@export_range(0.001, 5.0) var angular_stop_threshold: float = 0.12
@export_range(0.0, 2.0) var settle_time: float = 0.35
@export_range(0.0, 2.0) var minimum_roll_time: float = 0.2
@export var require_contact_to_settle: bool = true
@export_range(0.0, 5.0) var roll_linear_damp: float = 0.3
@export_range(0.0, 5.0) var roll_angular_damp: float = 0.45

@export_group("Keep")
@export_range(0.0, 2.0) var keep_duration: float = 0.3

## Scoring result: updated on stop or when entering keep, preserved during keep.
var value: int = 1
var is_kept: bool:
	get:
		return _kept
var is_rolling: bool:
	get:
		return _rolling

var containment_enabled: bool = false
var containment_frame := Transform3D.IDENTITY
var containment_min := Vector3(-4.6, 0.5, -3.6)
var containment_max := Vector3(4.6, 5.1, 3.6)
var max_up_speed: float = 3.5

var _kept: bool = false
var _rolling: bool = false
var _roll_elapsed: float = 0.0
var _quiet_elapsed: float = 0.0
var _launch_pending: bool = false
var _pending_impulse := Vector3.ZERO
var _pending_torque := Vector3.ZERO
var _keep_tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	linear_damp = roll_linear_damp
	angular_damp = roll_angular_damp
	var material := PhysicsMaterial.new()
	material.friction = 0.75
	material.bounce = 0.08
	physics_material_override = material
	can_sleep = true
	continuous_cd = true
	# Contact reporting works without the more expensive contact_monitor signals.
	max_contacts_reported = maxi(max_contacts_reported, 4)
	var pairs := [mini(positive_x_face, 7 - positive_x_face),
		mini(positive_y_face, 7 - positive_y_face),
		mini(positive_z_face, 7 - positive_z_face)]
	if pairs[0] == pairs[1] or pairs[0] == pairs[2] or pairs[1] == pairs[2]:
		push_error("D6 face axes must use three different opposite pairs (1/6, 2/5, 3/4).")
	value = get_top_face()


## World-space linear impulse and angular impulse, applied once per throw.
## A kept die ignores throws; explicitly release it with set_kept(false).
func roll(impulse: Vector3, torque: Vector3) -> void:
	if _kept:
		return
	_cancel_keep_tween()
	freeze = false
	sleeping = false
	_roll_elapsed = 0.0
	_quiet_elapsed = 0.0
	_rolling = true
	_pending_impulse = impulse
	_pending_torque = torque
	_launch_pending = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _kept or freeze or (state.sleeping and not _launch_pending):
		return
	if _launch_pending:
		_launch_pending = false
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		state.apply_central_impulse(_pending_impulse)
		state.apply_torque_impulse(_pending_torque)
	var velocity := state.linear_velocity
	velocity.y = minf(velocity.y, max_up_speed)
	state.linear_velocity = velocity.limit_length(10.0)
	state.angular_velocity = state.angular_velocity.limit_length(16.0)
	if containment_enabled:
		var pose := state.transform
		var local_position := containment_frame.affine_inverse() * pose.origin
		var local_velocity := containment_frame.basis.inverse() * state.linear_velocity
		for axis in range(3):
			if local_position[axis] < containment_min[axis]:
				local_position[axis] = containment_min[axis]
				local_velocity[axis] = maxf(local_velocity[axis], 0.0)
			elif local_position[axis] > containment_max[axis]:
				local_position[axis] = containment_max[axis]
				local_velocity[axis] = minf(local_velocity[axis], 0.0)
		pose.origin = containment_frame * local_position
		state.transform = pose
		state.linear_velocity = containment_frame.basis * local_velocity



## Convenience throw for a roughly unit-sized, 1 kg die; tune for your scene.
func roll_random(impulse_strength: float = 4.0, torque_strength: float = 1.0) -> void:
	var direction := Vector3(_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(1.0, 2.0), _rng.randf_range(-1.0, 1.0)).normalized()
	var spin := Vector3(_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
	if spin.is_zero_approx():
		spin = Vector3.RIGHT
	roll(direction * impulse_strength, spin.normalized() * torque_strength)


## Geometric result, even while moving. Read `value` for the settled score.
## Ties (exactly on an edge/corner) resolve in +Y,-Y,+X,-X,+Z,-Z order.
func get_top_face() -> int:
	var axes := global_transform.basis.orthonormalized()
	var normals: Array[Vector3] = [axes.y, -axes.y, axes.x, -axes.x, axes.z, -axes.z]
	var faces: Array[int] = [positive_y_face, 7 - positive_y_face,
		positive_x_face, 7 - positive_x_face, positive_z_face, 7 - positive_z_face]
	var best_dot: float = -INF
	var best_face: int = positive_y_face
	for index in range(normals.size()):
		var up_dot: float = normals[index].dot(Vector3.UP)
		if up_dot > best_dot:
			best_dot = up_dot
			best_face = faces[index]
	return best_face


func _physics_process(delta: float) -> void:
	if not _rolling or _kept or freeze or _launch_pending:
		return
	_roll_elapsed += delta
	if _roll_elapsed < minimum_roll_time:
		return
	if sleeping:
		_finish_roll()
		return
	var slow := linear_velocity.length_squared() <= linear_stop_threshold * linear_stop_threshold \
		and angular_velocity.length_squared() <= angular_stop_threshold * angular_stop_threshold
	var supported := not require_contact_to_settle or get_contact_count() > 0
	if slow and supported:
		_quiet_elapsed += delta
		if _quiet_elapsed >= settle_time:
			_finish_roll()
	else:
		_quiet_elapsed = 0.0


func _finish_roll() -> void:
	# Clear before emitting so a listener can immediately roll or keep this die.
	_rolling = false
	_quiet_elapsed = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	value = get_top_face()
	stopped.emit(value)


## slot is a WORLD transform. Repeated calls retarget an in-flight keep tween.
## duration < 0 uses keep_duration; 0 snaps immediately. Release keeps position.
func set_kept(keep: bool, slot: Transform3D = Transform3D.IDENTITY, duration: float = -1.0) -> void:
	_cancel_keep_tween()
	if keep and not _kept:
		value = get_top_face()
	_kept = keep
	_rolling = false
	_launch_pending = false
	_quiet_elapsed = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if not keep:
		freeze = false
		sleeping = false
		return
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	var seconds := keep_duration if duration < 0.0 else duration
	if seconds <= 0.0 or not is_inside_tree():
		global_transform = slot
		return
	var origin := global_transform
	_keep_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_keep_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_keep_tween.tween_method(_interpolate_keep.bind(origin, slot), 0.0, 1.0, seconds)


func _interpolate_keep(weight: float, origin: Transform3D, target: Transform3D) -> void:
	global_transform = origin.interpolate_with(target, weight)


func _cancel_keep_tween() -> void:
	if _keep_tween != null and _keep_tween.is_valid():
		_keep_tween.kill()
	_keep_tween = null


func _exit_tree() -> void:
	_cancel_keep_tween()
