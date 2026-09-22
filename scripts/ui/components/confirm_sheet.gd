extends Control
signal accepted
signal cancelled
var heading := "确认"
var description := ""
var confirm_text := "确认"
var busy := false
func _ready() -> void:
	add_to_group("native_confirmation")
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter=MOUSE_FILTER_STOP
	var shade := ColorRect.new(); shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT); shade.color=Color("16334b",.55); add_child(shade)
	var panel := Panel.new(); add_child(panel); panel.set_anchors_preset(PRESET_CENTER); panel.position=size*.5-Vector2(270,205); panel.size=Vector2(540,410)
	var face := StyleBoxFlat.new(); face.bg_color=Color("f3f5f3"); face.set_corner_radius_all(12); panel.add_theme_stylebox_override("panel",face)
	var title := Label.new(); title.text=heading; title.position=Vector2(36,31); title.size=Vector2(468,74); title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; title.add_theme_font_size_override("font_size",28); panel.add_child(title)
	var body := Label.new(); body.text=description; body.position=Vector2(36,123); body.size=Vector2(468,166); body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_theme_font_size_override("font_size",21); panel.add_child(body)
	for i in 2:
		var b := preload("res://scripts/ui/components/solmere_button.gd").new(); b.text="取消" if i==0 else confirm_text; b.position=Vector2(36+i*245,321); b.size=Vector2(223,52); b.selected=i==1; panel.add_child(b)
		b.pressed.connect(func() -> void:
			if busy: return
			if i==1: busy=true; accepted.emit()
			else: cancelled.emit(); queue_free())
		if i==0: b.grab_focus()
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not busy:
		cancelled.emit(); queue_free(); get_viewport().set_input_as_handled()
