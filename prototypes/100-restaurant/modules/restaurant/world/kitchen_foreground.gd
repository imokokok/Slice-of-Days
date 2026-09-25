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
		wall.append(Vector2(810 + cos(t) * 124, Geometry.FRONT_BOTTOM_CENTER_Y + sin(t) * Geometry.FRONT_BOTTOM_RADIUS_Y))
	draw_colored_polygon(wall, Color("2f302d"))
	draw_polyline(lip, Color("9b907a"), 3.5, true)
	var shade := PackedVector2Array()
	for i in range(37):
		var t := 0.12 + (PI - 0.24) * float(i) / 36
		shade.append(Vector2(810 + cos(t) * 121, 593 + sin(t) * 58))
	draw_polyline(shade, Color("59564b"), 2.0, true)
	# Broad, restrained painterly facets echo the hand-painted prop atlas while
	# preserving the shared pan silhouette used for pointer occlusion.
	draw_colored_polygon(PackedVector2Array([Vector2(702, 619), Vector2(746, 640), Vector2(761, 652), Vector2(727, 640)]), Color("504a3e", 0.54))
	draw_colored_polygon(PackedVector2Array([Vector2(821, 633), Vector2(865, 637), Vector2(851, 660), Vector2(812, 657)]), Color("3f4039", 0.48))
	if is_instance_valid(controller) and controller.world._overflow_until > controller.world._time:
		var path := PackedVector2Array()
		for i in range(17):
			var t := float(i) / 16.0
			path.append(Vector2(922 + 12 * sin(t * PI * 0.5), 593 + t * 48))
		draw_polyline(path, controller.world._overflow_color, 3.0, true)
