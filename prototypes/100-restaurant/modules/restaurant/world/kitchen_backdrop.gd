extends Node2D

var cooking: = false
var customer: Dictionary = {}
var knife_held: = false
var time: = 0.0
var bell_time := 0.0
const ROOM = preload("res://modules/restaurant/assets/kitchen_reference_no_recipe_stand.png")
const FONT = preload("res://modules/restaurant/assets/fonts/noto_serif_sc.ttf")
func _draw() -> void :
	draw_texture_rect(ROOM, Rect2(0, 0, 1600, 900), false)
	# Only replace the old baked-in towel rectangle. The rest is the approved room.
	draw_texture_rect_region(preload("res://modules/restaurant/assets/cut_states/counter_patch.png"), Rect2(342.7,685.5,238.5,126.6), Rect2(329,780,229,144))
	# Separate small signs leave the illustrated room and chalkboard visible.
	draw_string(FONT, Vector2(58, 55), "100饭店", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("fff0b8"))
	draw_string(FONT, Vector2(58, 80), "好好吃饭，也好好生活", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("eadbc4"))
	draw_rect(Rect2(0, 798, 1600, 102), Color("393632", 0.96))
	draw_string(FONT, Vector2(48, 851), "100  /  自由厨房", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("fff1bd"))
	# The original reference already contains the paper and clipboard.
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
