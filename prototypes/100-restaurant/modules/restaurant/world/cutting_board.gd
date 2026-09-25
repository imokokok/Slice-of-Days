extends Node2D

var world: Node2D
const SIZE := Vector2(390, 125)
const START := Vector2(1030, 670)

func _ready() -> void:
	position = START
	# The board sits on the worktop in front of the pan handle. Food and the
	# knife have higher z order, so this only hides the handle crossing its edge.
	z_index = 5
	world._stations["chop"] = rect()
	queue_redraw()

func rect() -> Rect2:
	return Rect2(position, SIZE)

func _draw() -> void:
	var texture: Texture2D = preload("res://modules/restaurant/assets/sprite_library.gd").gear(2)
	if texture:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, SIZE), false)
