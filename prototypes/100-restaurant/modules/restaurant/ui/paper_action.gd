extends Button
## Small illustrated paper tabs; standard Button keyboard/focus/input behavior.
var symbol := "book"
var accent := Color("6d8d79")
func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_color_override("font_color", Color("284b47"))
	add_theme_color_override("font_hover_color", Color("173f3d"))
	add_theme_color_override("font_pressed_color", Color("173f3d"))
	add_theme_color_override("font_disabled_color", Color("8a9184"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color("f6e9c8") if state == "normal" else Color("eddaab")
		if state == "disabled": skin.bg_color = Color("e7e1d1")
		if state == "focus":
			skin.bg_color = Color.TRANSPARENT
			skin.border_color = accent
			skin.set_border_width_all(2)
		skin.set_corner_radius_all(9)
		skin.content_margin_left = 66
		skin.content_margin_right = 20
		skin.content_margin_top = 14
		skin.content_margin_bottom = 14
		if state == "normal":
			skin.shadow_color = Color("795937", 0.13)
			skin.shadow_offset = Vector2(0, 3)
			skin.shadow_size = 2
		add_theme_stylebox_override(state, skin)
	resized.connect(queue_redraw)

func _draw() -> void:
	var p := Vector2(34, size.y * 0.5)
	var ink := accent if not disabled else Color("9b9b8c")
	if symbol == "book":
		for side in [-1, 1]:
			var poly := PackedVector2Array([p, p + Vector2(side * 19, -4), p + Vector2(side * 19, -23), p + Vector2(0, -19)])
			poly += PackedVector2Array([p])
			poly = Transform2D(0, Vector2(0, 11)) * poly
			draw_polyline(poly, ink, 2.5, true)
	elif symbol == "arrow":
		draw_line(p + Vector2(17, 0), p - Vector2(15, 0), ink, 3, true)
		draw_polyline(PackedVector2Array([p + Vector2(-3, -11), p + Vector2(-15, 0), p + Vector2(-3, 11)]), ink, 3, true)
	else:
		draw_arc(p, 17, 0, TAU, 32, ink, 2, true)
		draw_polyline(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(-1, 7), p + Vector2(10, -7)]), ink, 3, true)
