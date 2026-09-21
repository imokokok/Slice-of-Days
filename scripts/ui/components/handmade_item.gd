extends Button
## Individually visible, focusable merchandise; never an invisible hotspot.
const ART = preload("res://scripts/ui/components/handmade_assets.gd")
var item_id := ""
var caption := ""
var selected := false:
	set(value):
		selected=value; queue_redraw()
var art: TextureRect
var motion: Tween
func _ready() -> void:
	focus_mode=FOCUS_ALL; mouse_default_cursor_shape=CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	art=ART.picture(self,item_id,Vector2(6,4),Vector2(size.x-12,size.y-38))
	var label := preload("res://scripts/ui/components/interface_palette.gd").words(self,caption,Vector2(0,size.y-30),size.x,17)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	tooltip_text=caption
	for state in ["mouse_entered","mouse_exited","focus_entered","focus_exited","button_down","button_up"]: connect(state,_feedback)
	resized.connect(func(): art.size=Vector2(size.x-12,size.y-38); label.position.y=size.y-30; label.size.x=size.x)
func _feedback() -> void:
	queue_redraw()
	if not is_instance_valid(art): return
	if motion: motion.kill()
	motion=create_tween()
	motion.tween_property(art,"position:y",7.0 if is_pressed() else -2.0 if is_hovered() or has_focus() else 4.0,.01 if SettingsSystem.reduced_motion() else .12)
func _draw() -> void:
	modulate.a=.42 if disabled else 1.0
	if selected or has_focus() or is_hovered():
		draw_line(Vector2(12,size.y-2),Vector2(size.x-12,size.y-2),Color("315e79") if has_focus() else Color("eed577"),4 if selected else 2,true)
