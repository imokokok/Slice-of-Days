extends Control
signal accepted
signal cancelled
var heading := "确认"
var description := ""
var confirm_text := "确认"
var busy := false
var paper: Panel
var body_scroll: ScrollContainer
var body_label: Label
const P=preload("res://scripts/ui/components/interface_palette.gd")
func _ready() -> void:
	add_to_group("native_confirmation")
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter=MOUSE_FILTER_STOP
	theme=P.theme_for_tools()
	preload("res://scripts/ui/modal_focus.gd").install(self)
	var shade := ColorRect.new(); shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT); shade.color=Color("16334b",.55); add_child(shade)
	paper=Panel.new(); paper.name="ConfirmationPaper"; add_child(paper)
	paper.size=Vector2(620,480); paper.position=(size-paper.size)*.5
	paper.add_theme_stylebox_override("panel",preload("res://scripts/ui/production_assets.gd").surface(P.CREAM,24))
	preload("res://scripts/ui/solmere_motion.gd").paper_open(paper,SettingsSystem.reduced_motion())
	var title:=P.words(paper,heading,Vector2(36,28),548,28,P.INK)
	title.name="ConfirmationTitle"; title.max_lines_visible=2; title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; title.tooltip_text=title.text
	body_scroll=ScrollContainer.new(); body_scroll.name="ConfirmationTextScroll"
	body_scroll.position=Vector2(36,116); body_scroll.size=Vector2(548,247); body_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; paper.add_child(body_scroll)
	body_label=P.words(body_scroll,description,Vector2.ZERO,528,21,P.INK)
	body_label.name="ConfirmationText"; body_label.size_flags_horizontal=SIZE_EXPAND_FILL
	for i in 2:
		var b := preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=LocalizationSystem.text("取消" if i==0 else confirm_text); b.position=Vector2(36+i*285,389); b.size=Vector2(263,54); b.variant="primary" if i==1 else "quiet"; paper.add_child(b)
		b.pressed.connect(func() -> void:
			if busy: return
			if i==1: busy=true; accepted.emit()
			else: cancelled.emit(); queue_free())
		if i==0: b.grab_focus()
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not busy:
		cancelled.emit(); queue_free(); get_viewport().set_input_as_handled()
