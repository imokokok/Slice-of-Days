extends Control
## Original geometry artwork for the in-world used camera and film shelf.
var kind := "normal"
func _draw() -> void:
	var ink:=Color("34474c")
	if kind=="camera":
		draw_style_box(_box(Color("c5d3c8"),13),Rect2(8,size.y*.22,size.x-16,size.y*.62))
		draw_style_box(_box(ink,5),Rect2(size.x*.08,size.y*.33,size.x*.84,size.y*.26))
		draw_circle(Vector2(size.x*.56,size.y*.55),size.y*.25,Color("667c76"))
		draw_circle(Vector2(size.x*.56,size.y*.55),size.y*.19,ink)
		draw_circle(Vector2(size.x*.56,size.y*.55),size.y*.12,Color("8bbac2"))
		draw_circle(Vector2(size.x*.54,size.y*.51),size.y*.04,Color("e5ecd7"))
		draw_rect(Rect2(size.x*.11,size.y*.27,size.x*.19,size.y*.12),Color("ede4bd"))
		draw_rect(Rect2(size.x*.78,size.y*.17,size.x*.10,size.y*.06),Color("ad6c4c"))
	else:
		var color:=Color({"normal":"b3b985","expired":"c78c60","bw":"98aaa9","night":"597682"}.get(kind,"b3b985"))
		draw_style_box(_box(color,3),Rect2(0,8,size.x*.73,size.y-16))
		draw_rect(Rect2(5,27,size.x*.63,size.y*.31),Color("ece5c9"))
		draw_style_box(_box(ink,8),Rect2(size.x*.59,20,size.x*.36,size.y*.72))
		draw_rect(Rect2(size.x*.64,44,size.x*.26,size.y*.27),color)
		draw_rect(Rect2(size.x*.69,12,size.x*.16,10),ink)

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	return style
