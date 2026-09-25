extends Node2D
var controller: Node2D
const Geometry = preload("res://modules/restaurant/world/pan_geometry.gd")

func _draw() -> void:
	# Opaque curved front wall; food and liquid are behind it.
	var wall := PackedVector2Array()
	var lip := PackedVector2Array()
	for i in range(41):
		var t := PI * float(i) / 40.0
		var p := Geometry.CENTER + Vector2(cos(t), sin(t)) * Geometry.RADIUS
		wall.append(p)
		lip.append(p)
	for i in range(40, -1, -1):
		var t := PI * float(i) / 40.0
		wall.append(Vector2(810 + cos(t) * 124, 584 + sin(t) * 58))
	draw_colored_polygon(wall, Color("33332e"))
	draw_polyline(lip, Color("777369"), 3.0, true)
	var shade := PackedVector2Array()
	for i in range(37):
		var t := 0.12 + (PI - 0.24) * float(i) / 36
		shade.append(Vector2(810 + cos(t) * 121, 587 + sin(t) * 49))
	draw_polyline(shade, Color("47453c"), 2.0, true)
	if is_instance_valid(controller) and controller.world._overflow_until > controller.world._time:
		var path := PackedVector2Array()
		for i in range(17):
			var t := float(i) / 16.0
			path.append(Vector2(922 + 12 * sin(t * PI * 0.5), 593 + t * 48))
		draw_polyline(path, controller.world._overflow_color, 3.0, true)
