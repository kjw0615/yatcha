extends Node3D

signal die_clicked(index: int)
signal roll_finished(values: Array)
signal cup_state_changed(is_shaking: bool, power: float)

const Die3DScene = preload("res://scenes/die_3d.tscn")
const KEEP_SLOTS = [
	Vector3(-3.2, 0.6, -3.4),
	Vector3(-1.6, 0.6, -3.4),
	Vector3(0.0, 0.6, -3.4),
	Vector3(1.6, 0.6, -3.4),
	Vector3(3.2, 0.6, -3.4)
]

var dice_nodes: Array = []
var pending_stops: int = 0
var is_rolling_phase: bool = false
var rng = RandomNumberGenerator.new()

# 3D 프리미엄 가죽 다이스 컵(Dice Cup) 관련 노드 및 상태
var dice_cup: Node3D
var cup_outer_mesh: MeshInstance3D
var cup_inner_mesh: MeshInstance3D
var cup_bottom_mesh: MeshInstance3D
var cup_rim_mesh: MeshInstance3D

var is_cup_shaking: bool = false
var mouse_accumulated_power: float = 0.0
# 통의 기본 위치: 살짝 앞으로 나오고, 카메라 쪽으로 입구가 보이도록 앞으로 -26도 기울임
var cup_base_pos: Vector3 = Vector3(0, 3.6, 2.0)
var cup_target_pos: Vector3 = Vector3(0, 3.6, 2.0)
const CUP_DEFAULT_ROT: Vector3 = Vector3(-0.45, 0.0, 0.0) # 약 -26도 전방 틸트 (입구 내부 직시)

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
	dice_cup.position = cup_base_pos
	dice_cup.rotation = CUP_DEFAULT_ROT
	add_child(dice_cup)
	
	# 1. 외피: 블랙 프리미엄 가죽 원통 (지름 3.5m, 높이 3.6m - 5개 주사위가 넉넉히 들어감)
	cup_outer_mesh = MeshInstance3D.new()
	var outer_cyl = CylinderMesh.new()
	outer_cyl.top_radius = 1.75
	outer_cyl.bottom_radius = 1.60
	outer_cyl.height = 3.6
	outer_cyl.radial_segments = 36
	cup_outer_mesh.mesh = outer_cyl
	
	var outer_mat = StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.10, 0.10, 0.11, 1.0)
	outer_mat.roughness = 0.45
	outer_mat.metallic = 0.1
	cup_outer_mesh.material_override = outer_mat
	dice_cup.add_child(cup_outer_mesh)
	
	# 2. 내피: 강렬한 레드 벨벳/펠트 라이닝 (위쪽 입구가 트여 내부가 선명히 보임)
	cup_inner_mesh = MeshInstance3D.new()
	var inner_cyl = CylinderMesh.new()
	inner_cyl.top_radius = 1.66
	inner_cyl.bottom_radius = 1.52
	inner_cyl.height = 3.58
	inner_cyl.radial_segments = 36
	cup_inner_mesh.mesh = inner_cyl
	
	var inner_mat = StandardMaterial3D.new()
	inner_mat.albedo_color = Color(0.85, 0.08, 0.12, 1.0)
	inner_mat.roughness = 0.82
	cup_inner_mesh.material_override = inner_mat
	dice_cup.add_child(cup_inner_mesh)
	
	# 3. 컵 안쪽 바닥 레드 펠트
	cup_bottom_mesh = MeshInstance3D.new()
	var bottom_cyl = CylinderMesh.new()
	bottom_cyl.top_radius = 1.50
	bottom_cyl.bottom_radius = 1.50
	bottom_cyl.height = 0.2
	cup_bottom_mesh.mesh = bottom_cyl
	cup_bottom_mesh.position = Vector3(0, -1.6, 0)
	cup_bottom_mesh.material_override = inner_mat
	dice_cup.add_child(cup_bottom_mesh)
	
	# 4. 컵 테두리(Rim) 마감 스티치 링
	cup_rim_mesh = MeshInstance3D.new()
	var rim_mesh = TorusMesh.new()
	rim_mesh.inner_radius = 1.62
	rim_mesh.outer_radius = 1.78
	rim_mesh.rings = 24
	rim_mesh.ring_segments = 16
	cup_rim_mesh.mesh = rim_mesh
	cup_rim_mesh.position = Vector3(0, 1.8, 0)
	cup_rim_mesh.material_override = outer_mat
	dice_cup.add_child(cup_rim_mesh)
	
	dice_cup.visible = false

func _process(delta: float) -> void:
	if is_cup_shaking:
		# 마우스 이동 속도가 줄어들면 파워 서서히 감쇠
		mouse_accumulated_power = max(0.2, mouse_accumulated_power - delta * 0.45)
		
		# [핵심] 통 자체가 마우스 조작을 따라 역동적으로 이동하고 흔들림
		dice_cup.position = dice_cup.position.lerp(cup_target_pos, delta * 18.0)
		
		# 마우스 좌우/상하 이동에 반응하여 통의 기울기가 역동적으로 꺾이며 통 내부가 보임
		var dynamic_tilt_x = CUP_DEFAULT_ROT.x + clamp((dice_cup.position.z - cup_base_pos.z) * 0.4, -0.35, 0.35)
		var dynamic_tilt_z = clamp(-(dice_cup.position.x - cup_base_pos.x) * 0.5, -0.5, 0.5)
		var dynamic_tilt_y = clamp((dice_cup.position.x - cup_base_pos.x) * 0.3, -0.4, 0.4)
		dice_cup.rotation = Vector3(dynamic_tilt_x, dynamic_tilt_y, dynamic_tilt_z)
		
		# [핵심] 통 안에 있는 5개의 주사위가 통의 움직임과 회전에 동기화되어 통 내부에서 부딪히며 덜컹거림
		var idx = 0
		var num_shaking = 0
		for i in range(5):
			if not current_held_states[i]:
				num_shaking += 1
		
		var radius_spread = 0.8
		for i in range(5):
			if not current_held_states[i]:
				var d = dice_nodes[i]
				var angle = (float(idx) / max(1.0, float(num_shaking))) * TAU + Time.get_ticks_msec() * 0.012
				
				# 통의 로컬 좌표계 기준으로 내부 바닥~중간 높이에서 마우스 파워에 맞춰 춤추듯 회전
				var local_offset = Vector3(
					cos(angle) * radius_spread + rng.randf_range(-0.12, 0.12),
					-0.3 + sin(Time.get_ticks_msec() * 0.02 + idx * 1.5) * 0.35 * mouse_accumulated_power,
					sin(angle) * radius_spread + rng.randf_range(-0.12, 0.12)
				)
				# 통의 회전(Transform3D.basis)을 적용하여 통이 기울어지는 방향과 완벽 일치시킴
				d.position = dice_cup.position + dice_cup.transform.basis * local_offset
				d.rotation += Vector3(
					mouse_accumulated_power * 0.28,
					mouse_accumulated_power * 0.35,
					mouse_accumulated_power * 0.22
				)
				idx += 1
		cup_state_changed.emit(true, mouse_accumulated_power)

func handle_mouse_motion(relative: Vector2) -> void:
	if not is_cup_shaking:
		return
	var speed = relative.length()
	# 마우스 이동 속도에 따라 통 흔들기 파워 축적
	mouse_accumulated_power = clamp(mouse_accumulated_power + speed * 0.022, 0.2, 2.0)
	
	# 마우스 이동을 3D 통(Cup)의 큰 폭 이동으로 직접 연결
	var offset_x = clamp((relative.x * 0.025), -2.6, 2.6)
	var offset_z = clamp((relative.y * 0.025), -1.8, 1.8)
	cup_target_pos = cup_base_pos + Vector3(offset_x, rng.randf_range(-0.15, 0.25), offset_z)

func spawn_dice() -> void:
	for i in range(5):
		var die = Die3DScene.instantiate()
		die.name = "Die3D_%d" % i
		die.position = KEEP_SLOTS[i]
		add_child(die)
		dice_nodes.append(die)
		die.stopped.connect(_on_single_die_stopped.bind(i))
		die.freeze = true

func start_shaking_cup(held_states: Array) -> void:
	if is_rolling_phase:
		return
	current_held_states = held_states.duplicate()
	is_cup_shaking = true
	mouse_accumulated_power = 0.35
	dice_cup.visible = true
	dice_cup.rotation = CUP_DEFAULT_ROT
	dice_cup.position = cup_base_pos
	cup_target_pos = cup_base_pos
	
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
	var final_power = mouse_accumulated_power
	cup_state_changed.emit(false, 0.0)
	
	# 통을 앞으로 힘차게 기울여 사각 레드 펠트 트레이 안으로 주사위를 쏟아붓는 모션
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(dice_cup, "rotation", Vector3(-1.45, 0, 0), 0.18)
	tween.tween_property(dice_cup, "position", Vector3(0, 3.8, 0.2), 0.18)
	await tween.finished
	dice_cup.visible = false
	
	# 주사위들을 사각형 가죽 트레이 안으로 안전하게 물리 투척
	execute_throw(final_power)
	
	# 최대 4.0초 안전 타임아웃 (멈춤 지연으로 인한 게임 소프트락 완전 방지)
	await get_tree().create_timer(4.0).timeout
	if is_rolling_phase and pending_stops > 0:
		_force_settle_all()

func _force_settle_all() -> void:
	if not is_rolling_phase:
		return
	is_rolling_phase = false
	pending_stops = 0
	var values = []
	for die in dice_nodes:
		if not die.is_kept:
			die.linear_velocity = Vector3.ZERO
			die.angular_velocity = Vector3.ZERO
			die.freeze = true
		values.append(die.value if die.is_kept else die.get_top_face())
	roll_finished.emit(values)

func execute_throw(power: float = 1.0) -> void:
	is_rolling_phase = true
	pending_stops = 0
	
	var throw_speed = clamp(power, 0.5, 1.8)
	var active_idx = 0
	for i in range(5):
		var die = dice_nodes[i]
		if not current_held_states[i]:
			pending_stops += 1
			die.freeze = false
			# 통 입구 중심부에서 사각형 트레이 중앙 바닥을 향해 자연스럽게 방사형 투척
			var spawn_angle = active_idx * 1.25
			die.position = Vector3(
				cos(spawn_angle) * 0.85,
				2.8 + rng.randf_range(0.0, 0.4),
				sin(spawn_angle) * 0.85 + 0.3
			)
			die.linear_velocity = Vector3.ZERO
			die.angular_velocity = Vector3.ZERO
			
			# 사각형 트레이 중앙(-Z 방향)으로 튕겨나가며 트레이 벽면 안에서만 구르도록 충격량 제어
			var impulse = Vector3(
				rng.randf_range(-1.5, 1.5) * throw_speed,
				rng.randf_range(0.3, 0.8) * throw_speed,
				rng.randf_range(-2.4, -1.3) * throw_speed
			)
			var torque = Vector3(
				rng.randf_range(-15.0, 15.0) * throw_speed,
				rng.randf_range(-15.0, 15.0) * throw_speed,
				rng.randf_range(-15.0, 15.0) * throw_speed
			)
			die.roll(impulse, torque)
			active_idx += 1

func roll(held_states: Array) -> void:
	current_held_states = held_states.duplicate()
	dice_cup.position = cup_base_pos
	execute_throw(1.0)

func set_held(index: int, is_held: bool) -> void:
	var die = dice_nodes[index]
	current_held_states[index] = is_held
	if is_held:
		# 윗면 눈을 유지한 채 가장 가까운 축만 수직으로 정렬 (Basis()로 두면 항상 1이 위로 감)
		var current = die.global_transform.basis.orthonormalized()
		var up_axis: Vector3 = current.y
		for axis in [-current.y, current.x, -current.x, current.z, -current.z]:
			if axis.dot(Vector3.UP) > up_axis.dot(Vector3.UP):
				up_axis = axis
		var upright = Basis(Quaternion(up_axis, Vector3.UP)) * current
		var target_tf = Transform3D(upright.orthonormalized(), KEEP_SLOTS[index])
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
