extends Control

const INK := Color("07090f")
const ROAD := Color("17212b")
const AMBER := Color("d98a39")
const CYAN := Color("58abb2")

var current_point := Vector2(156, 592)
var selected_point := Vector2(156, 592)


func set_points(current: Vector2, selected: Vector2) -> void:
	current_point = current
	selected_point = selected
	queue_redraw()


func _draw() -> void:
	var scale_value := Vector2(size.x / 1600.0, size.y / 900.0)
	draw_set_transform(Vector2.ZERO, 0.0, scale_value)
	draw_rect(Rect2(0, 0, 1600, 900), INK)
	# The town is staged as disconnected planes, joined only by the route being considered.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 720), Vector2(290, 555), Vector2(535, 620), Vector2(780, 470), Vector2(1000, 585), Vector2(1245, 410), Vector2(1600, 570), Vector2(1600, 760), Vector2(1220, 605), Vector2(1000, 735), Vector2(775, 615), Vector2(535, 760), Vector2(275, 690), Vector2(0, 825)]), ROAD)
	draw_colored_polygon(PackedVector2Array([Vector2(240, 298), Vector2(430, 240), Vector2(408, 540), Vector2(220, 572)]), Color("11212c"))
	draw_colored_polygon(PackedVector2Array([Vector2(1040, 220), Vector2(1220, 178), Vector2(1202, 495), Vector2(1024, 530)]), Color("281922"))
	draw_colored_polygon(PackedVector2Array([Vector2(1270, 280), Vector2(1510, 228), Vector2(1490, 610), Vector2(1250, 570)]), Color("10242a"))
	for x in [310, 1090, 1330]:
		draw_line(Vector2(x, 260), Vector2(x - 20, 610), Color("9e5436"), 3.0)
	draw_circle(current_point, 82.0, Color(AMBER, 0.08))
	draw_circle(current_point, 13.0, AMBER)
	if selected_point != current_point:
		draw_dashed_line(current_point, selected_point, CYAN, 3.0, 14.0)
		draw_circle(selected_point, 33.0, Color(CYAN, 0.14))
		draw_circle(selected_point, 8.0, CYAN)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
