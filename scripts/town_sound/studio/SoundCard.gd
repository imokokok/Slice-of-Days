extends Button
var sample: Dictionary
func _ready() -> void:
	custom_minimum_size=Vector2(174,105)
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	tooltip_text="拖到下方纸带，或点一下放入 · "+str(sample.get("name",""))
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
func _draw() -> void:
	var rect:=Rect2(3,7,size.x-6,91)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("adc4b1") if is_hovered() else Color("c7d2bb")
	style.set_corner_radius_all(10); style.border_color=Color("6a7861"); style.set_border_width_all(2)
	draw_style_box(style,rect)
	draw_rect(Rect2(14,17,size.x-28,35),Color("faf0d9"))
	draw_string(get_theme_default_font(),Vector2(20,40),str(sample.get("name","声音")).left(9),HORIZONTAL_ALIGNMENT_LEFT,size.x-38,18,Color("504d3c"))
	for x in [size.x*.29,size.x*.71]:
		draw_circle(Vector2(x,70),12,Color("f7efd8")); draw_circle(Vector2(x,70),5,Color("6a7861"))
	draw_line(Vector2(size.x*.29+12,70),Vector2(size.x*.71-12,70),Color("78876a"),3)
	draw_string(get_theme_default_font(),Vector2(68,93),"%.1f s"%float(sample.get("duration",0)),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("504d3c"))
func _get_drag_data(_at: Vector2) -> Variant:
	if disabled: return null
	var ghost:=Label.new(); ghost.text=str(sample.name); set_drag_preview(ghost)
	return {"sample":sample}
