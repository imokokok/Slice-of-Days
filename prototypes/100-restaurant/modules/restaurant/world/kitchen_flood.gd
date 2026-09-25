extends Node2D
## Stylized room-wide water surface. Volume belongs to KitchenWorld; this node
## only draws the shared waterline above the physical kitchen scene.
var world: Node2D

func _process(_delta: float) -> void:
	if world.flood_water_ml > 0.001: queue_redraw()

func _draw() -> void:
	var ratio: float = world.flood_ratio()
	if ratio <= 0.0001: return
	# Leave enough room for the wave peaks at the bottom edge. A polygon whose
	# surface crosses y=900 self-intersects and cannot be triangulated by Godot.
	var water_y := lerpf(885.0, -22.0, ratio)
	var time: float = world._time
	var surface := PackedVector2Array()
	for i in 65:
		var x := float(i) * 25.0
		var y := water_y + sin(x * 0.018 + time * 2.1) * 4.0 + sin(x * 0.041 - time * 1.35) * 2.0
		surface.append(Vector2(x, y))
	var body := PackedVector2Array(surface)
	body.append(Vector2(1600, 900))
	body.append(Vector2(0, 900))
	draw_colored_polygon(body, Color(0.18, 0.51, 0.65, lerpf(0.35, 0.56, ratio)))
	for band in 4:
		var top := water_y + 20.0 + float(band) * 65.0
		if top >= 900.0: break
		draw_rect(Rect2(0, top, 1600, minf(65.0, 900.0 - top)), Color(0.15, 0.45, 0.57, 0.025 + float(band) * 0.012))
	draw_polyline(surface, Color(0.76, 0.91, 0.88, 0.80), 4.0, true)
	for i in 17:
		var x := fmod(float(i) * 103.0 + time * (13.0 + float(i % 4) * 4.0), 1600.0)
		var y := water_y + 17.0 + fmod(float(i * 79) - time * (17.0 + float(i % 3) * 4.0), maxf(20.0, 880.0 - water_y))
		if y > water_y + 8.0 and y < 894.0:
			draw_arc(Vector2(x, y), 2.0 + float(i % 3), 0.0, TAU, 12, Color(0.91, 0.99, 0.97, 0.31), 1.2, true)
