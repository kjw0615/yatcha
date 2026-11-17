extends Button

var value = 1
var held = false

func _draw() -> void:
	var ink = Color("113e45") if not held else Color("086651")
	var positions = []
	match value:
		1: positions = [Vector2(0.5, 0.5)]
		2: positions = [Vector2(0.28, 0.28), Vector2(0.72, 0.72)]
		3: positions = [Vector2(0.28, 0.28), Vector2(0.5, 0.5), Vector2(0.72, 0.72)]
		4: positions = [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.28, 0.72), Vector2(0.72, 0.72)]
		5: positions = [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.5, 0.5), Vector2(0.28, 0.72), Vector2(0.72, 0.72)]
		6: positions = [Vector2(0.28, 0.25), Vector2(0.72, 0.25), Vector2(0.28, 0.5), Vector2(0.72, 0.5), Vector2(0.28, 0.75), Vector2(0.72, 0.75)]
	for point in positions:
		draw_circle(point * size, 6.0, ink)
