extends Node2D

var cooking: = false
var customer: Dictionary = {}
var knife_held: = false
var time: = 0.0
var bell_time := 0.0
const ROOM = preload("res://modules/restaurant/assets/kitchen_daylight_mediterranean.png")
const FONT = preload("res://modules/restaurant/assets/fonts/noto_serif_sc.ttf")
func _draw() -> void :
	draw_texture_rect(ROOM, Rect2(0, 0, 1600, 900), false)
	draw_rect(Rect2(0, 0, 1600, 92), Color("214e4b", 0.94))
	draw_string(FONT, Vector2(38, 55), "100饭店", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("fff0b8"))
	draw_string(FONT, Vector2(606, 74), "今日，主厨做主", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("f7d96f"))
	draw_rect(Rect2(0, 798, 1600, 102), Color("214946", 0.96))
	draw_string(FONT, Vector2(48, 851), "100  /  自由厨房", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("fff1bd"))
	if not customer.is_empty():
		# Guests communicate through the clipped paper at the service window.
		draw_rect(Rect2(1062, 166, 251, 305), Color("fff4d2"))
		draw_rect(Rect2(1154, 155, 65, 18), Color("d76a3f"))
	_draw_bell()

func ring_bell() -> void:
	bell_time = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if bell_time > 0.0:
		bell_time = maxf(0.0, bell_time - delta)
		queue_redraw()

func _draw_bell() -> void:
	var pivot := Vector2(1028, 151)
	var swing := sin((1.0 - bell_time) * 32.0) * bell_time * 0.18
	var center := pivot + Vector2(0, 29).rotated(swing)
	draw_line(pivot, center + Vector2(0, -11).rotated(swing), Color("355a52"), 5.0, true)
	var bell := PackedVector2Array()
	for point in [Vector2(-14, 10), Vector2(-10, -9), Vector2(0, -16), Vector2(10, -9), Vector2(14, 10)]:
		bell.append(center + point.rotated(swing))
	draw_colored_polygon(bell, Color("e5b83d"))
	draw_polyline(bell, Color("9a6634"), 2.0, true)
	draw_circle(center + Vector2(0, 13).rotated(swing), 4.0, Color("d7653e"))
