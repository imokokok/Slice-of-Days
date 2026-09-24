extends Node2D
func _draw() -> void :
	var tex: = preload("res://modules/restaurant/assets/sprite_library.gd").gear(6)
	if tex:
		draw_set_transform(Vector2.ZERO, 0.22)
		draw_texture_rect(tex, Rect2(-93, -24, 188, 52), false)
