extends Node2D
var controller: Node2D
func _draw() -> void :
	if controller.world.cooking and controller.on_stove():
		_draw_burner_flame()
	var tex: = preload("res://modules/restaurant/assets/sprite_library.gd").gear(0)
	# Restore vertical body so the pan reads as a deep vessel.
	if tex: draw_texture_rect(tex, Rect2(684, 534, 384, 112), false)
	if controller.residue.total_kg() > 0.000001:
		var index := 0
		for item in controller.residue.components.values():
			var pigment := Color(str(item.color))
			pigment.a = clampf(float(item.mass_kg) * 950.0, 0.05, 0.7)
			_ellipse(Vector2(764 + (index % 4) * 29, 573 + (index / 4) * 6), Vector2(16, 5), pigment)
			index += 1
	var water: float = controller.water_ml
	if water > 0:
		var fill: float = controller.world.pan_fill_ratio()
		_ellipse(Vector2(810, 597 - fill * 18), Vector2(78 + fill * 32, 13 + fill * 21), Color("a1b9ae", 0.3))
		if fill >= 0.999 and controller.faucet_on and controller.under_tap():
			for x in [774.0, 810.0, 846.0]:
				draw_line(Vector2(x, 604), Vector2(x + sin(controller.world._time * 4.0 + x) * 3.0, 628), Color("91d3d0", 0.8), 3.0, true)
		var boiling: float = controller.world.reactions.water_activity()
		if boiling>0.08:
			for i in range(8):
				var phase: float = fmod(controller.world._time * 1.8 + i * 0.173, 1)
				draw_arc(Vector2(750 + i * 17, 581 + sin(i * 3) * 8), (1.5 + phase * 4)*boiling, 0, TAU, 12, Color("d5e1c5",(1.0-phase)*0.85), 1)

func _draw_burner_flame() -> void :


	var strength: float = {"low": 0.72, "medium": 1.0, "high": 1.32}.get(str(controller.world.heat_level), 1.0)
	var now: float = controller.world._time
	_ellipse(Vector2(810, 610), Vector2(92 * strength, 12 * strength), Color(0.91, 0.28, 0.07, 0.25))
	for i in range(11):
		var x: = 705.0 + i * 21.0
		var flicker: = sin(now * (8.0 + i * 0.37) + i * 1.71)
		var height: = (17.0 + (i % 3) * 5.0 + flicker * 3.5) * strength
		var base: = Vector2(x, 618)
		_poly([base + Vector2(-8, 0), base + Vector2(-5, - height * 0.48), base + Vector2(flicker * 3.0, - height), base + Vector2(6, - height * 0.42), base + Vector2(8, 0)], Color("e85a18"))
		_poly([base + Vector2(-4, 0), base + Vector2(-2, - height * 0.42), base + Vector2(flicker * 1.4, - height * 0.68), base + Vector2(3, - height * 0.3), base + Vector2(4, 0)], Color("ffd36a"))
	for i in range(4):
		var x: = 735.0 + i * 50.0
		_poly([Vector2(x - 4, 620), Vector2(x, 613 - sin(now * 9 + i) * 1.5), Vector2(x + 4, 620)], Color("6fb7bc", 0.72))

func _poly(points: Array, color: Color) -> void :
	draw_colored_polygon(PackedVector2Array(points), color)
func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void :
	var points: = PackedVector2Array()
	for i in range(24): points.append(center + Vector2.from_angle(i * TAU / 24.0) * radius)
	draw_colored_polygon(points, color)
