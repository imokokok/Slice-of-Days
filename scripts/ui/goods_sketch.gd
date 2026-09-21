extends Control
## Small original pen sketches, shared by the shop shelf and the player's bag.
var item_id := ""
const INK := Color("31658b")
var tin: Texture2D=preload("res://art/ui/sea-bean-tin.png")
func _ready() -> void: mouse_filter=MOUSE_FILTER_IGNORE
func _draw() -> void:
	if item_id in ["sea_beans","pretty_can"]:
		var side := minf(size.x,size.y)
		draw_texture_rect(tin,Rect2((size-Vector2.ONE*side)*.5,Vector2.ONE*side),false,Color.WHITE if item_id=="sea_beans" else Color("c6d9bd"))
		return
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
			draw_circle(Vector2(0,6),25,Color("bf6d50") if item_id=="tomato" else Color("eed577")); draw_arc(Vector2(0,6),25,0,TAU,28,Color("78906b"),1.5,true)
			draw_arc(Vector2(-3,5),19,PI,PI*1.55,18,Color("fff5d5",.45),4,true)
			draw_line(Vector2(0,-19),Vector2(15,-27),INK,2,true)
	elif item_id=="bread":
		var loaf := _paper(); loaf.bg_color=Color("cdab77"); loaf.set_corner_radius_all(19)
		draw_style_box(loaf,Rect2(-38,-24,76,49))
		for x in [-20,0,20]: draw_line(Vector2(x-5,-12),Vector2(x+5,3),INK,2,true)
	elif item_id=="cheese":
		draw_colored_polygon(PackedVector2Array([Vector2(-32,22),Vector2(30,22),Vector2(20,-24)]),Color("eed577"))
		draw_polyline(PackedVector2Array([Vector2(-32,22),Vector2(30,22),Vector2(20,-24),Vector2(-32,22)]),INK,1.6,true)
		for p in [Vector2(8,4),Vector2(20,14)]: draw_arc(p,4,0,TAU,12,INK,1,true)
	elif item_id=="soap":
		var soap := _paper(); soap.bg_color=Color("aec7c4"); soap.set_corner_radius_all(11)
		draw_style_box(soap,Rect2(-30,-20,60,40)); draw_arc(Vector2(0,0),10,0,TAU,20,INK,1,true)
	elif item_id=="matches":
		var packet := _paper(); packet.bg_color=Color("c8a06a")
		draw_style_box(packet,Rect2(-29,-21,58,42))
		for x in [-18,-9,0,9,18]:
			draw_line(Vector2(x,12),Vector2(x,-12),INK,1,true); draw_circle(Vector2(x,-12),2,Color("eed577"))
	elif item_id=="crooked_cup":
		draw_arc(Vector2(24,-3),17,-PI*.5,PI*.5,24,Color("6c929e"),8,true)
		draw_colored_polygon(PackedVector2Array([Vector2(-28,-24),Vector2(27,-21),Vector2(21,26),Vector2(-23,26)]),Color("6c929e"))
		draw_line(Vector2(-25,-23),Vector2(25,-21),Color("dce6da"),5,true)
	elif item_id=="star_salt":
		var jar := _paper(); jar.bg_color=Color("d6e5df"); jar.set_corner_radius_all(8)
		draw_style_box(jar,Rect2(-23,-26,46,62)); draw_rect(Rect2(-22,-33,44,11),Color("bc9967"))
		for p in [Vector2(-10,-7),Vector2(9,4),Vector2(-7,18)]:
			for i in 5: draw_line(p,p+Vector2.from_angle(i*TAU/5)*6,Color("fff9e6"),3,true)
	elif item_id=="hotel_307_tag":
		draw_arc(Vector2(0,-29),12,0,TAU,24,Color("ae8c50"),3,true)
		draw_colored_polygon(PackedVector2Array([Vector2(-15,-20),Vector2(15,-20),Vector2(26,14),Vector2(0,38),Vector2(-26,14)]),Color("c4a366"))
		draw_string(PaperLanguage.body_font,Vector2(-15,10),"307",HORIZONTAL_ALIGNMENT_LEFT,-1,17,INK)
	elif item_id in ["misprint_postcard","ticket_bundle"]:
		draw_style_box(_paper(),Rect2(-39,-26,78,52))
		draw_rect(Rect2(-32,-18,64,28),Color("98bbc5")); draw_circle(Vector2(18,-11),6,Color("eed577"))
		draw_colored_polygon(PackedVector2Array([Vector2(-32,10),Vector2(-12,-6),Vector2(4,10),Vector2(22,-3),Vector2(32,10)]),Color("6b8a76"))
		draw_line(Vector2(-28,17),Vector2(9,17),INK,1,true)
	elif item_id=="blue_stamp":
		draw_circle(Vector2(0,-20),14,Color("608895")); draw_rect(Rect2(-8,-18,16,40),Color("608895")); draw_rect(Rect2(-29,19,58,12),INK)
	else:
		draw_style_box(_paper(),Rect2(-30,-23,60,46))
		draw_polyline(PackedVector2Array([Vector2(-29,-13),Vector2(0,-8),Vector2(29,-14)]),INK,1.5,true)
		draw_line(Vector2(0,-8),Vector2(0,22),INK,1.5,true)
	draw_set_transform(Vector2.ZERO)
func _paper() -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color=Color("faf7ee"); style.border_color=INK
	style.set_border_width_all(1); style.set_corner_radius_all(3)
	return style
