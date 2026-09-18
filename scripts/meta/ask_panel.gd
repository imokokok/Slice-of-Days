extends Control
signal chosen(topic: String)
var npc := ""

func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(1040,220)
	panel.size = Vector2(420,330)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	var title := Label.new()
	title.text = LocalizationSystem.text("问一件事 · %d分钟" % int(MetaExperience.catalog.timing.ask_minutes))
	box.add_child(title)
	for row in [["今天什么时候在？","schedule_info"],["附近有什么地方？","town_info"],["最近听到了什么？","rumor"]]:
		var button := Button.new()
		button.text = LocalizationSystem.text(str(row[0]))
		button.custom_minimum_size.y = 54
		box.add_child(button)
		button.pressed.connect(func() -> void:
			chosen.emit(str(row[1]))
			queue_free())
	var close := Button.new()
	close.text = LocalizationSystem.text("先不问了")
	box.add_child(close)
	close.pressed.connect(queue_free)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
