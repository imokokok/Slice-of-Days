extends Node2D
func _draw() -> void :
	var art = preload("res://modules/restaurant/assets/sprite_library.gd")
	for spec in [[7, Rect2(40, 525, 365, 260)], [8, Rect2(635, 647, 425, 141)]]:
		var tex: Texture2D = art.gear(spec[0])
		if tex: draw_texture_rect(tex, spec[1], false)
