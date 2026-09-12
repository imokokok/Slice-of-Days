extends Node2D

var definition: Dictionary = {}
var dispense_mode: = "squeeze"
var liquid_state: Dictionary = {}

func _draw() -> void :
	var color: = Color.from_string(str(definition.get("color", "d96143")), Color("d96143"))
	var volume: = maxf(0.2, float(liquid_state.get("volume_ml", 3.0)))
	var fullness: = clampf(sqrt(volume / 3.0), 0.55, 2.25)
	var mixedness: = clampf(float(liquid_state.get("mixedness", 0.0)), 0.0, 1.0)
	var layered: = bool(liquid_state.get("layered", false))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(fullness, 0.72 + fullness * 0.28))
	match dispense_mode:
		"powder":

			for index in range(21):
				var phase: = float(index) * 2.39996
				var radius: = sqrt(float(index + 1) / 21.0) * 11.5
				var point: = Vector2(cos(phase), sin(phase) * 0.68) * radius
				draw_rect(Rect2(point, Vector2(2.0 + index % 2, 2.0)), color.lightened(float(index % 3) * 0.08))
		"pour":
			_polygon([Vector2(-12, 2), Vector2(-7, -4), Vector2(3, -5), Vector2(12, -1), Vector2(10, 5), Vector2(1, 7), Vector2(-10, 6)], color.darkened(0.08))
			_polygon([Vector2(-7, -1), Vector2(-3, -3), Vector2(7, -1), Vector2(4, 1), Vector2(-5, 1)], color.lightened(0.18))
		_:
			_polygon([Vector2(-12, 3), Vector2(-10, -4), Vector2(-3, -6), Vector2(0, -10), Vector2(4, -5), Vector2(11, -3), Vector2(12, 4), Vector2(6, 8), Vector2(-7, 8)], color.darkened(0.06))
			_polygon([Vector2(-7, -3), Vector2(0, -7), Vector2(5, -2), Vector2(1, 0), Vector2(-6, 1)], color.lightened(0.17))
	if layered:
		draw_arc(Vector2(0, 2), 7, 0.1, PI - 0.1, 18, color.lightened(0.28), 2.0, true)
	elif mixedness > 0.05:
		draw_circle(Vector2(3, -1), 2.0 + mixedness * 1.5, color.lightened(0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _polygon(points: Array, color: Color) -> void :
	draw_colored_polygon(PackedVector2Array(points), color)
