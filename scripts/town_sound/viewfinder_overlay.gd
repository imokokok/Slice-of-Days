extends Control

var locked := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_focus(value: bool) -> void:
	locked = value
	queue_redraw()


func _draw() -> void:
	var ink := Color("f5ead2", 0.34)
	var accent := Color("eecb74", 0.96) if locked else Color("f5ead2", 0.72)
	for i in [1, 2]:
		var x := size.x * float(i) / 3.0
		var y := size.y * float(i) / 3.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), ink, 1.0)
		draw_line(Vector2(0, y), Vector2(size.x, y), ink, 1.0)
	var corner := 34.0
	var inset := 18.0
	for point in [Vector2(inset, inset), Vector2(size.x - inset, inset), Vector2(inset, size.y - inset), Vector2(size.x - inset, size.y - inset)]:
		var sx := 1.0 if point.x < size.x * 0.5 else -1.0
		var sy := 1.0 if point.y < size.y * 0.5 else -1.0
		draw_line(point, point + Vector2(corner * sx, 0), accent, 3.0)
		draw_line(point, point + Vector2(0, corner * sy), accent, 3.0)
	var center := size * 0.5
	var radius := 32.0 if locked else 24.0
	draw_arc(center, radius, 0, TAU, 48, accent, 2.0)
	draw_line(center + Vector2(-48, 0), center + Vector2(-12, 0), accent, 2.0)
	draw_line(center + Vector2(12, 0), center + Vector2(48, 0), accent, 2.0)
	draw_line(center + Vector2(0, -48), center + Vector2(0, -12), accent, 2.0)
	draw_line(center + Vector2(0, 12), center + Vector2(0, 48), accent, 2.0)
	if locked:
		draw_circle(center, 4.0, accent)
