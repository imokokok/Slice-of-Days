extends Control
signal chosen(topic: String)
var npc := ""
var choosing := false
var card: Panel

func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=MOUSE_FILTER_STOP
	var scene := get_tree().current_scene
	var stage: Control = scene.get("street") if scene.get("street")!=null else scene.get("stage")
	card=preload("res://scripts/ui/components/dialogue_card.gd").new()
	add_child(card)
	card.configure(stage,npc)
	card.speaker_label.text=LocalizationSystem.text("问一件事 · %d分钟" % int(MetaExperience.catalog.timing.ask_minutes))
	card.hint_label.text=SettingsSystem.binding_text("ui_accept")+" 回应 · "+SettingsSystem.binding_text("ui_cancel")+" 离开"
	_show_questions(false)

func _show_questions(interests: bool) -> void:
	card.clear_choices()
	var rows: Array = [["今天什么时候在？","schedule_info"],["附近有什么地方？","town_info"],["聊聊你喜欢的事。","interests"],["聊聊熟悉的人。","relationship_followup"],["先不问了",""]]
	if interests:
		rows=[]
		for topic: Dictionary in ResidentProfileSystem.topics_for(npc): rows.append([topic.label,"interest:"+str(topic.id)])
		rows.append(["回到刚才的话题","back"])
	var box := VBoxContainer.new()
	for row in rows:
		var button := preload("res://scripts/ui/components/dialogue_choice.gd").new()
		button.text=LocalizationSystem.text(str(row[0]))
		button.custom_minimum_size.y=46
		box.add_child(button)
		button.pressed.connect(_choose.bind(str(row[1])))
	card.attach_choices(box)
	box.get_child(0).grab_focus()

func _choose(topic: String) -> void:
	if choosing: return
	if topic in ["interests", "back"]:
		_show_questions(topic == "interests")
		return
	choosing=true
	if not topic.is_empty(): chosen.emit(topic)
	else: card.dismiss()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_choose("")
		get_viewport().set_input_as_handled()
