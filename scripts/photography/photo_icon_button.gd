extends Button
## Original vector controls: big shutter and simple, rounded camera-tool icons.
const S := preload("res://scripts/photography/photo_style.gd")
var kind := "shutter"

func _ready() -> void:
	for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw); button_up.connect(queue_redraw)
	pressed.connect(queue_redraw)

func _draw() -> void:
	var center := size*.5
	var radius := minf(size.x,size.y)*.5-4
	var ink := S.INK if not disabled else Color("a3b3b3")
	draw_circle(center+Vector2(0,3),radius,Color("304967",.18))
	draw_circle(center,radius,S.SUN if is_pressed() else (Color("eff7e8") if is_hovered() else S.PAPER))
	draw_arc(center,radius,0,TAU,64,Color("6586aa"),2.5,true)
	if has_focus(): draw_arc(center,radius-5,0,TAU,64,S.BLUE,2,true)
	if kind=="shutter":
		draw_circle(center,radius*.69,S.SUN if not disabled else Color("dfe6d9"))
		draw_arc(center,radius*.69,0,TAU,64,ink,2,true)
		draw_circle(center,radius*.16,Color("fffef6",.9))
	elif kind=="back":
		draw_polyline(PackedVector2Array([center+Vector2(5,-12),center+Vector2(-7,0),center+Vector2(5,12)]),ink,3,true)
	elif kind in ["up","down","left","right"]:
		var direction: Vector2={"up":Vector2.UP,"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT}[kind]
		var side := direction.orthogonal()
		draw_line(center-direction*9,center+direction*10,ink,2.5,true)
		draw_polyline(PackedVector2Array([center+direction*2+side*7,center+direction*10,center+direction*2-side*7]),ink,2.5,true)
	elif kind=="center":
		draw_arc(center,10,0,TAU,32,ink,2,true)
		draw_circle(center,3,ink)
	elif kind in ["plus","minus"]:
		draw_line(center+Vector2(-10,0),center+Vector2(10,0),ink,3,true)
		if kind=="plus": draw_line(center+Vector2(0,-10),center+Vector2(0,10),ink,3,true)
	elif kind=="album":
		draw_style_box(S.surface(Color("9ab7d8"),3),Rect2(center-Vector2(17,10),Vector2(32,27)))
		draw_style_box(S.surface(S.PAPER,3),Rect2(center-Vector2(11,17),Vector2(30,31)))
		draw_rect(Rect2(center+Vector2(-7,-13),Vector2(22,17)),S.MINT)
		draw_polyline(PackedVector2Array([center+Vector2(-6,2),center+Vector2(1,-7),center+Vector2(6,-1),center+Vector2(10,-5),center+Vector2(15,2)]),ink,1.5,true)
