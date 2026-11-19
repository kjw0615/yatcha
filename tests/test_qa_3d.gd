extends SceneTree

const Board3DScene = preload("res://scenes/board_3d.tscn")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func run() -> void:
	var board = Board3DScene.instantiate()
	root.add_child(board)
	await physics_frame
	await physics_frame
	# 킵한 주사위는 이동 전후로 윗면 눈이 같아야 한다 (화면 눈 == 점수 계산 값).
	var rotations: Array[Vector3] = [Vector3.ZERO, Vector3(PI, 0, 0),
		Vector3(0, 0, PI / 2), Vector3(0, 0, -PI / 2),
		Vector3(-PI / 2, 0, 0), Vector3(PI / 2, 0, 0), Vector3(0.4, 1.1, 0.7)]
	for rot in rotations:
		var die = board.dice_nodes[0]
		die.set_kept(false)
		die.freeze = true
		die.global_transform = Transform3D(Basis.from_euler(rot), Vector3(0, 2, 0))
		var before: int = die.get_top_face()
		board.set_held(0, true)
		for i in range(60):
			await physics_frame
		check(die.get_top_face() == before, "keep changed top face %d -> %d (rot %s)" % [before, die.get_top_face(), rot])
		board.set_held(0, false)
		check(die.get_top_face() == before, "unkeep changed top face (rot %s)" % rot)
	for message in failures:
		push_error(message)
		print("FAIL: ", message)
	if failures.is_empty():
		print("PASS: %d QA 3D checks" % checks)
	quit(0 if failures.is_empty() else 1)
