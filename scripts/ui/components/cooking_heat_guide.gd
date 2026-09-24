extends Control
## A quiet heat cue beneath the slider. The highlighted range belongs to the
## ingredient at the pan, so the visual guide and spoken hint stay in sync.

var heat := 0.58
var comfortable_low := 0.40
var comfortable_high := 0.70

func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE

func update_guide(value: float, low: float, high: float) -> void:
	heat=clampf(value,0.0,1.0)
	comfortable_low=clampf(low,0.0,1.0)
	comfortable_high=clampf(high,comfortable_low,1.0)
	queue_redraw()

func _draw() -> void:
	var width := size.x
	draw_rect(Rect2(0,3,width,6),Color("526b77",0.28))
	var start := width*comfortable_low
	var end := width*comfortable_high
	draw_rect(Rect2(start,1,maxf(2,end-start),10),Color("eed577",0.95))
	draw_line(Vector2(start,0),Vector2(start,12),Color("82644c",0.8),2)
	draw_line(Vector2(end,0),Vector2(end,12),Color("82644c",0.8),2)
	var current := width*heat
	draw_line(Vector2(current,-2),Vector2(current,14),Color("315e79"),3)
