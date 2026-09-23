extends Button
## Approved doodles are decoration on a real, accessible native Button.
const ART = preload("res://art/ui/pocket_doodles/badges.png")
var object_index := 0
var title := ""
var action := ""
var selected := false
var lift := 0.0
var feedback: Tween

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_to_group("pocket_object_button")
	focus_mode=FOCUS_ALL
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for event in [mouse_entered,mouse_exited,focus_entered,focus_exited,button_down,button_up]: event.connect(_feedback)
	resized.connect(queue_redraw)
	tooltip_text=title+" · "+SettingsSystem.binding_text(action)
	accessibility_name=title

func _feedback() -> void:
	if feedback: feedback.kill()
	feedback=create_tween()
	feedback.tween_property(self,"lift",0.0 if disabled else 2.0 if button_pressed else -3.0 if is_hovered() or has_focus() else 0.0,.01 if SettingsSystem.reduced_motion() else .12)
	feedback.parallel().tween_method(func(_v: float): queue_redraw(),0.0,1.0,.13)

func _draw() -> void:
	# The art follows each object silhouette, with only a small nameplate below.
	# Crop transparent cell margins; labels remain native and localizable.
	var cell := Vector2((object_index%3)*512,floori(object_index/3.0)*512)
	var crop := Rect2(48,48,424,430) if object_index<3 else Rect2(24,42,464,402)
	var rect := Rect2(Vector2(3,3+lift),size-Vector2(6,6))
	var active := (is_hovered() or has_focus() or selected) and not disabled
	draw_texture_rect_region(ART,rect,Rect2(cell+crop.position,crop.size),Color(1.08,1.05,.94) if active else Color(1,1,1,.55 if disabled else 1))
	var ink := Color("473b2f")
	var font := PaperLanguage.handwriting
	draw_string(font,Vector2(0,size.y-11+lift),title,HORIZONTAL_ALIGNMENT_CENTER,size.x,17,Color(ink,.55 if disabled else 1))
	if has_focus(): draw_polyline(PackedVector2Array([Vector2(8,size.y+3),Vector2(size.x*.45,size.y+1),Vector2(size.x-8,size.y+3)]),Color("e3bd70"),3,true)
