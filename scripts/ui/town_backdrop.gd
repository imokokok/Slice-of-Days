extends Control

const TOWN_BACKGROUND := preload("res://art/reference/town-direction.png")

const PAPER := Color("f8edd9")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")

var current_point := Vector2(156, 592)
var selected_point := Vector2(156, 592)


func _ready() -> void:
	resized.connect(queue_redraw)


func set_points(current: Vector2, selected: Vector2) -> void:
	current_point = current
	selected_point = selected
	queue_redraw()


func _draw() -> void:
	var scale_value := Vector2(size.x / 1600.0, size.y / 900.0)
	draw_set_transform(Vector2.ZERO, 0.0, scale_value)
	draw_rect(Rect2(0, 0, 1600, 900), PAPER)
	draw_texture_rect(TOWN_BACKGROUND, Rect2(0, 0, 1600, 900), false)
	draw_rect(Rect2(0, 0, 1600, 900), Color(PAPER, 0.10))
	draw_circle(current_point, 42.0, Color(TERRACOTTA, 0.22))
	draw_circle(current_point, 12.0, TERRACOTTA)
	draw_circle(current_point, 5.0, Color("fff8e8"))
	if selected_point != current_point:
		draw_dashed_line(current_point, selected_point, Color("fff8e8", 0.95), 7.0, 16.0)
		draw_dashed_line(current_point, selected_point, TEAL, 3.0, 16.0)
		draw_circle(selected_point, 28.0, Color(TEAL, 0.22))
		draw_circle(selected_point, 8.0, TEAL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
