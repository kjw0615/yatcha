extends Node3D

signal die_clicked(index: int)
signal roll_finished(values: Array)
signal cup_state_changed(is_shaking: bool, power: float)

const Die3DScene = preload("res://scenes/die_3d.tscn")
const KEEP_SLOTS = [
	Vector3(-3.2, 0.6, -3.2),
	Vector3(-1.6, 0.6, -3.2),
	Vector3(0.0, 0.6, -3.2),
	Vector3(1.6, 0.6, -3.2),
	Vector3(3.2, 0.6, -3.2)
]

var dice_nodes: Array = []
var pending_stops: int = 0
var is_rolling_phase: bool = false
var rng = RandomNumberGenerator.new()

# 3D 컵(Cup) 관련 노드 및 상태
var dice_cup: Node3D
var cup_mesh: MeshInstance3D
var is_cup_shaking: bool = false
var shake_timer: float = 0.0
var shake_intensity: float = 0.0
var current_held_states: Array = [false, false, false, false, false]

func _ready() -> void:
	rng.randomize()
	build_dice_cup()
	spawn_dice()
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.0
	for child in get_children():
		if child is StaticBody3D:
			child.physics_material_override = material

func build_dice_cup() -> void:
	dice_cup = Node3D.new()
	dice_cup.name = "DiceCup"
	dice_cup.position = Vector3(0, 3.2, 2.2)
	add_child(dice_cup)
	
	cup_mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 1.3
	cylinder.bottom_radius = 0.9
	cylinder.height = 2.4
	cup_mesh.mesh = cylinder
	
	var cup_mat = StandardMaterial3D.new()
	cup_mat.albedo_color = Color(0.88, 0.76, 0.58, 0.9)
	cup_mat.roughness = 0.2
	cup_mat.metallic = 0.1
	cup_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cup_mesh.material_override = cup_mat
	dice_cup.add_child(cup_mesh)
	dice_cup.visible = false

func _process(delta: float) -> void:
	if is_cup_shaking:
		shake_timer += delta
		shake_intensity = clamp(shake_intensity + delta * 0.8, 0.2, 1.8)
		# 컵 흔들기 쉐이크 모션
		var offset_x = sin(shake_timer * 26.0) * (0.28 * shake_intensity)
		var offset_y = cos(shake_timer * 34.0) * (0.16 * shake_intensity)
		var offset_z = sin(shake_timer * 20.0) * (0.12 * shake_intensity)
		dice_cup.position = Vector3(offset_x, 3.2 + offset_y, 1.6 + offset_z)
		dice_cup.rotation = Vector3(
			sin(shake_timer * 18.0) * 0.25,
			cos(shake_timer * 22.0) * 0.3,
			sin(shake_timer * 30.0) * 0.35
		)
		
		# 컵 안에 담긴 주사위들도 컵 내부에서 덜컹거리며 함께 흔들림
		var idx = 0
		for i in range(5):
			if not current_held_states[i]:
				var d = dice_nodes[i]
				var d_offset = Vector3(
					sin(shake_timer * 24.0 + idx * 1.3) * 0.4,
					cos(shake_timer * 28.0 + idx * 1.1) * 0.3,
					cos(shake_timer * 20.0 + idx * 1.5) * 0.4
				)
				d.position = dice_cup.position + Vector3(0, -0.3, 0) + d_offset
				d.rotation = Vector3(
					sin(shake_timer * 15.0 + idx) * 3.0,
					cos(shake_timer * 18.0 + idx) * 3.0,
					idx * 1.2
				)
				idx += 1
		cup_state_changed.emit(true, shake_intensity)

func spawn_dice() -> void:
	for i in range(5):
		var die = Die3DScene.instantiate()
		die.name = "Die3D_%d" % i
		die.position = KEEP_SLOTS[i]
		add_child(die)
		die.containment_enabled = true
		die.containment_frame = global_transform
		dice_nodes.append(die)
		die.stopped.connect(_on_single_die_stopped.bind(i))
		die.freeze = true

func start_shaking_cup(held_states: Array) -> void:
	if is_rolling_phase:
		return
	current_held_states = held_states.duplicate()
	is_cup_shaking = true
	shake_timer = 0.0
	shake_intensity = 0.2
	dice_cup.visible = true
	dice_cup.rotation = Vector3.ZERO
	dice_cup.position = Vector3(0, 3.2, 1.6)
	
	for i in range(5):
		var die = dice_nodes[i]
		if not current_held_states[i]:
			die.freeze = true
			die.linear_velocity = Vector3.ZERO
			die.angular_velocity = Vector3.ZERO

func release_and_throw_cup() -> void:
	if not is_cup_shaking:
		return
	is_cup_shaking = false
	cup_state_changed.emit(false, 0.0)
	
	# 컵을 앞으로 기울여 쏟아붓는 트윈 연출
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(dice_cup, "rotation", Vector3(-1.3, 0, 0), 0.2)
	tween.tween_property(dice_cup, "position", Vector3(0, 3.8, 0.4), 0.2)
	await tween.finished
	dice_cup.visible = false
	
	# 주사위들을 트레이 바닥으로 물리적으로 투척
	execute_throw(shake_intensity)

func execute_throw(power: float = 1.0) -> void:
	is_rolling_phase = true
	pending_stops = 0
	
	var throw_speed = clamp(power, 0.5, 2.0)
	for i in range(5):
		var die = dice_nodes[i]
		if not current_held_states[i]:
			pending_stops += 1
			die.freeze = false
			# 컵 위치에서 앞으로 발사
			die.position = Vector3((i - 2) * 1.8, 3.4, 1.0)

			die.linear_velocity = Vector3.ZERO
			die.angular_velocity = Vector3.ZERO
			
			var impulse = Vector3(
				rng.randf_range(-2.2, 2.2) * throw_speed,
				rng.randf_range(0.4, 1.0) * throw_speed,
				rng.randf_range(-2.5, -1.5) * throw_speed
			)
			var torque = Vector3(
				rng.randf_range(-1.2, 1.2) * throw_speed,
				rng.randf_range(-1.2, 1.2) * throw_speed,
				rng.randf_range(-1.2, 1.2) * throw_speed
			)
			die.roll(impulse, torque)

func roll(held_states: Array) -> void:
	# 단발 롤(Quick Roll) 요청 시 컵 흔들기 -> 바로 던지기 수행
	current_held_states = held_states.duplicate()
	dice_cup.position = Vector3(0, 3.4, 1.8)
	execute_throw(1.0)

func set_held(index: int, is_held: bool) -> void:
	var die = dice_nodes[index]
	current_held_states[index] = is_held
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
