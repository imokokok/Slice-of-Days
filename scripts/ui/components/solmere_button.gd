extends Button
## Shared native states; variants express the reference without duplicating behavior.
var variant := "quiet"
var feedback_tween: Tween
var icon_kind := "":
	set(value):
		icon_kind=value
		if is_inside_tree(): refresh()
var selected := false:
	set(value):
		selected=value
		if is_inside_tree(): refresh()
const Production = preload("res://scripts/ui/production_assets.gd")
func _ready() -> void:
	text=LocalizationSystem.text(text)
	focus_mode=FOCUS_ALL
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	refresh()
	if toggle_mode:
		selected=button_pressed
		toggled.connect(func(value: bool) -> void: selected=value)
	for signal_name in ["mouse_entered","mouse_exited","focus_entered","focus_exited","button_down","button_up"]:
		connect(signal_name,queue_redraw)
	mouse_entered.connect(_feedback.bind(true)); mouse_exited.connect(_feedback.bind(false))
	focus_entered.connect(_feedback.bind(true)); focus_exited.connect(_feedback.bind(false))

func _feedback(active: bool) -> void:
	if disabled: return
	if feedback_tween: feedback_tween.kill()
	feedback_tween=create_tween()
	feedback_tween.tween_property(self,"self_modulate",Color.WHITE if active else Color(.94,.96,.98),.01 if SettingsSystem.reduced_motion() else .14)
func refresh() -> void:
	var dark := variant in ["primary","choice","pause","camera","guidance"]
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,Production.button_face(variant,state,selected))
	add_theme_color_override("font_color",PaperLanguage.WHITE if dark and not selected else Production.INK)
	add_theme_color_override("font_hover_color",Production.INK)
	add_theme_color_override("font_pressed_color",Production.INK)
	add_theme_color_override("font_hover_pressed_color",Production.INK)
	add_theme_color_override("font_focus_color",PaperLanguage.WHITE if dark and not selected else Production.INK)
	add_theme_color_override("font_disabled_color",Production.MUTED_INK)
	icon=preload("res://scripts/ui/open_assets.gd").icon(icon_kind) if not icon_kind.is_empty() else null
	expand_icon=true
	add_theme_constant_override("icon_max_width",24)
	add_theme_constant_override("h_separation",10)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var color := get_theme_color("font_color" if state=="normal" else "font_"+state+"_color")
		add_theme_color_override("icon_"+state+"_color",color)
	add_theme_font_override("font",PaperLanguage.body_font)
	if not has_theme_font_size_override("font_size"): add_theme_font_size_override("font_size",20)

func _draw() -> void:
	# No additional random contour over the native focus/state surface.
	if selected: draw_line(Vector2(13,size.y-4),Vector2(35,size.y-4),Color("526d61"),2,true)
