extends Node3D

signal die_clicked(index: int)
signal roll_finished(values: Array)

const Die3DScene = preload("res://scenes/die_3d.tscn")
const KEEP_SLOTS = [
	Vector3(-3.2, 0.6, -3.2),
	Vector3(-1.6, 0.6, -3.2),
	Vector3(0.0, 0.6, -3.2),
	Vector3(1.6, 0.6, -3.2),
	Vector3(3.2, 0.6, -3.2)
]

const ROLL_SPAWN = [
	Vector3(-2.0, 3.5, 0.5),
	Vector3(-1.0, 3.8, 1.2),
	Vector3(0.0, 4.0, 0.2),
	Vector3(1.0, 3.7, 1.0),
	Vector3(2.0, 3.6, 0.6)
]

var dice_nodes: Array = []
var pending_stops: int = 0
var is_rolling_phase: bool = false
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	spawn_dice()

func spawn_dice() -> void:
	for i in range(5):
		var die = Die3DScene.instantiate()
		die.name = "Die3D_%d" % i
		die.position = KEEP_SLOTS[i]
		add_child(die)
		dice_nodes.append(die)
		die.stopped.connect(_on_single_die_stopped.bind(i))
		die.freeze = true

func roll(held_states: Array) -> void:
	is_rolling_phase = true
	pending_stops = 0
	
	for i in range(5):
		var die = dice_nodes[i]
		if not held_states[i]:
			pending_stops += 1
			die.freeze = false
			die.position = ROLL_SPAWN[i]
			die.linear_velocity = Vector3.ZERO
			die.angular_velocity = Vector3.ZERO
			
			# 물리적 임펄스 및 회전 토크 적용
			var impulse = Vector3(
				rng.randf_range(-1.5, 1.5),
				rng.randf_range(1.0, 3.0),
				rng.randf_range(-1.5, 1.5)
			)
			var torque = Vector3(
				rng.randf_range(-15.0, 15.0),
				rng.randf_range(-15.0, 15.0),
				rng.randf_range(-15.0, 15.0)
			)
			die.roll(impulse, torque)

func set_held(index: int, is_held: bool) -> void:
	var die = dice_nodes[index]
	if is_held:
		var target_tf = Transform3D(Basis(), KEEP_SLOTS[index])
		die.set_kept(true, target_tf, 0.35)
	else:
		die.set_kept(false)

func _on_single_die_stopped(face: int, index: int) -> void:
	if not is_rolling_phase:
		return
	pending_stops -= 1
	if pending_stops <= 0:
		is_rolling_phase = false
		var values = []
		for die in dice_nodes:
			values.append(die.value if die.is_kept else die.get_top_face())
		roll_finished.emit(values)

func get_dice_values() -> Array:
	var values = []
	for die in dice_nodes:
		values.append(die.value if die.is_kept else die.get_top_face())
	return values
