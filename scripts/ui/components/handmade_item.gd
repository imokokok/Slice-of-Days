extends Button
## Individually visible, focusable merchandise; never an invisible hotspot.
const ART = preload("res://scripts/ui/components/cooking_ingredients.gd")
var item_id := ""
var caption := ""
var caption_back: Panel
var label: Label
var selected := false:
	set(value):
		selected=value; queue_redraw()
var art: TextureRect
var motion: Tween
func _ready() -> void:
	focus_mode=FOCUS_ALL; mouse_default_cursor_shape=CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	art=ART.picture(self,item_id,Vector2(6,4),Vector2(size.x-12,size.y-38))
	caption_back=Panel.new(); caption_back.name="PriceLabelBacking"
	caption_back.position=Vector2(0,size.y-34); caption_back.size=Vector2(size.x,34)
	caption_back.mouse_filter=MOUSE_FILTER_IGNORE
	caption_back.add_theme_stylebox_override("panel",preload("res://scripts/ui/components/interface_palette.gd").face(Color("faf7ee"),2,0)); add_child(caption_back)
	label = preload("res://scripts/ui/components/interface_palette.gd").words(self,caption,Vector2(4,size.y-30),size.x-8,19)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.max_lines_visible=2; label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	tooltip_text=LocalizationSystem.text(caption)
	for state in ["mouse_entered","mouse_exited","focus_entered","focus_exited","button_down","button_up"]: connect(state,_feedback)
	resized.connect(_layout_caption)
	_layout_caption()
func _layout_caption() -> void:
	if not is_instance_valid(label): return
	var width:=maxf(40,size.x-12)
	label.custom_maximum_size.x=width
	label.size.x=width
	# Include the Label's actual line spacing and fallback CJK font metrics.
	var height:=maxf(34,label.get_minimum_size().y+8)
	caption_back.position=Vector2(0,size.y-height); caption_back.size=Vector2(size.x,height)
	label.position=Vector2(6,size.y-height+4); label.size=Vector2(width,height-8)
	art.size=Vector2(size.x-12,maxf(24,size.y-height-6))
func _feedback() -> void:
	queue_redraw()
	if not is_instance_valid(art): return
	if motion: motion.kill()
	motion=create_tween()
	motion.tween_property(art,"position:y",7.0 if is_pressed() else -2.0 if is_hovered() or has_focus() else 4.0,.01 if SettingsSystem.reduced_motion() else .12)
func _draw() -> void:
	# Availability must not make the name disappear with the illustration.
	modulate.a=1.0
	if is_instance_valid(art): art.self_modulate=Color(.68,.71,.69) if disabled else Color.WHITE
	if is_instance_valid(label): label.add_theme_color_override("font_color",Color("56655e") if disabled else Color("38423e"))
	if selected or has_focus() or is_hovered():
		draw_line(Vector2(12,size.y-2),Vector2(size.x-12,size.y-2),Color("315e79") if has_focus() else Color("eed577"),4 if selected else 2,true)
