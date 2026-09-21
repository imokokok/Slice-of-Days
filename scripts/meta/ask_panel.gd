extends Control
signal chosen(topic: String)
var npc := ""
var choosing := false

func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var scene := get_tree().current_scene
	var stage: Node = scene.get("street") if scene.get("street")!=null else scene.get("stage")
	panel.position = PaperLanguage.near_actor(stage,Vector2(420,330))
	panel.size = Vector2(420,330)
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	var title := Label.new()
	title.text = LocalizationSystem.text("问一件事 · %d分钟" % int(MetaExperience.catalog.timing.ask_minutes))
	title.add_theme_color_override("font_color",PaperLanguage.WHITE)
	title.add_theme_color_override("font_outline_color",Color("203e55"))
	title.add_theme_constant_override("outline_size",3)
	title.add_theme_font_size_override("font_size",18)
	box.add_child(title)
	for row in [["今天什么时候在？","schedule_info"],["附近有什么地方？","town_info"],["最近听到了什么？","rumor"]]:
		var button := preload("res://scripts/ui/components/solmere_button.gd").new()
		button.variant="choice"
		button.text = LocalizationSystem.text(str(row[0]))
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 54
		box.add_child(button)
		button.pressed.connect(func() -> void:
			if choosing: return
			choosing=true
			chosen.emit(str(row[1]))
			queue_free())
	var close := preload("res://scripts/ui/components/solmere_button.gd").new()
	close.variant="choice"
	close.text = LocalizationSystem.text("先不问了")
	close.alignment=HORIZONTAL_ALIGNMENT_LEFT
	close.custom_minimum_size.y=54
	box.add_child(close)
	close.pressed.connect(queue_free)
	box.get_child(1).grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
