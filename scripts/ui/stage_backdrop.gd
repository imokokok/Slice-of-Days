extends Control

const WORKBENCH_BACKGROUND := preload("res://art/reference/workbench-direction.png")
const PAPER := Color("f8edd9")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var sx: float = size.x / 1600.0
	var sy: float = size.y / 900.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	draw_rect(Rect2(0, 0, 1600, 900), PAPER)
	draw_texture_rect(WORKBENCH_BACKGROUND, Rect2(0, 0, 1600, 900), false)
	draw_rect(Rect2(0, 0, 1600, 900), Color(PAPER, 0.08))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
