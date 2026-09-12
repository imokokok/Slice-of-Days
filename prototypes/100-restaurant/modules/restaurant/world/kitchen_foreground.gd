extends Node2D
func _draw() -> void :

	var tex: = preload("res://modules/restaurant/assets/sprite_library.gd").gear(0)
	if not tex: return
	var image: = tex.get_size()
	draw_texture_rect_region(tex, Rect2(684, 603, 279, 43), Rect2(0, image.y * 0.66, image.x * 0.725, image.y * 0.34))
