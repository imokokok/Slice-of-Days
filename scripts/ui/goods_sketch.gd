extends Control
## Small original pen sketches, shared by the shop shelf and the player's bag.
var item_id := ""
const INK := Color("31658b")
func _ready() -> void: mouse_filter=MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_set_transform(size*.5,0,Vector2.ONE*minf(size.x/120,size.y/100))
	if "bean" in item_id or "can" in item_id:
		draw_style_box(_paper(),Rect2(-24,-33,48,65))
		draw_arc(Vector2(0,-31),24,PI,TAU,30,INK,2,true)
		draw_line(Vector2(-23,-24),Vector2(23,-23),INK,1.5,true)
		draw_line(Vector2(-23,24),Vector2(23,25),INK,1.5,true)
		for p in [Vector2(-8,-5),Vector2(8,5),Vector2(-5,12)]: draw_arc(p,5,0,TAU,15,INK,1.5,true)
	elif item_id in ["herbs","lemon","tomato"]:
		draw_line(Vector2(0,34),Vector2(0,-28),INK,2,true)
		if item_id=="herbs":
			for y in [-20,-3,14]:
				draw_colored_polygon(PackedVector2Array([Vector2(0,y+12),Vector2(-24,y),Vector2(-15,y-7)]),Color("91a778"))
				draw_colored_polygon(PackedVector2Array([Vector2(0,y+15),Vector2(22,y-5),Vector2(13,y-10)]),Color("91a778"))
		else:
			draw_circle(Vector2(0,6),25,Color("eed577")); draw_arc(Vector2(0,6),25,0,TAU,28,INK,1.5,true)
			draw_line(Vector2(0,-19),Vector2(15,-27),INK,2,true)
	elif item_id=="bread":
		draw_style_box(_paper(),Rect2(-35,-22,70,47))
		for x in [-20,0,20]: draw_line(Vector2(x-5,-12),Vector2(x+5,3),INK,2,true)
	elif item_id=="cheese":
		draw_colored_polygon(PackedVector2Array([Vector2(-32,22),Vector2(30,22),Vector2(20,-24)]),Color("eed577"))
		draw_polyline(PackedVector2Array([Vector2(-32,22),Vector2(30,22),Vector2(20,-24),Vector2(-32,22)]),INK,1.6,true)
		for p in [Vector2(8,4),Vector2(20,14)]: draw_arc(p,4,0,TAU,12,INK,1,true)
	elif item_id=="soap":
		draw_style_box(_paper(),Rect2(-30,-20,60,40)); draw_arc(Vector2(0,0),10,0,TAU,20,INK,1,true)
	elif item_id=="matches":
		draw_style_box(_paper(),Rect2(-29,-21,58,42))
		for x in [-18,-9,0,9,18]:
			draw_line(Vector2(x,12),Vector2(x,-12),INK,1,true); draw_circle(Vector2(x,-12),2,Color("eed577"))
	else:
		draw_style_box(_paper(),Rect2(-30,-23,60,46))
		draw_polyline(PackedVector2Array([Vector2(-29,-13),Vector2(0,-8),Vector2(29,-14)]),INK,1.5,true)
		draw_line(Vector2(0,-8),Vector2(0,22),INK,1.5,true)
	draw_set_transform(Vector2.ZERO)
func _paper() -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color=Color("faf7ee"); style.border_color=INK
	style.set_border_width_all(1); style.set_corner_radius_all(3)
	return style
