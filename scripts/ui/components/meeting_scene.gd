extends Control
## A voluntary, resumable in-scene meeting. Only the last acknowledgement reveals.
var beat := 0
var card: Panel
var next: Button
var lines: Array[String]=[]
func _ready() -> void:
	add_to_group("meta_dialogue")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if not ChapterSystem.meeting_available(): queue_free(); return
	var street: Control=get_meta("street")
	card=preload("res://scripts/ui/components/dialogue_card.gd").new(); add_child(card); card.configure(street,"")
	lines=ChapterSystem.meeting_lines()
	if lines.is_empty(): lines=["两个人终于在约好的地方见面。"]
	beat=int(GameState.shared_state.get("meeting_beat",0))
	beat=clampi(beat,0,lines.size()-1)
	var choices := VBoxContainer.new()
	next=preload("res://scripts/ui/components/dialogue_choice.gd").new(); next.custom_minimum_size.y=48; next.pressed.connect(_advance); choices.add_child(next)
	card.attach_choices(choices)
	_show_beat()
func _show_beat() -> void:
	card.speaker_label.text=LocalizationSystem.text("赴约的人") if beat<lines.size()-1 else ""
	card.text_label.text=LocalizationSystem.text(lines[clampi(beat,0,lines.size()-1)])
	card.text_label.visible_characters=-1
	next.text=LocalizationSystem.text("继续" if beat<lines.size()-1 else "一起在小镇走走")
	card.hint_label.text=SettingsSystem.binding_text("ui_cancel")+" "+LocalizationSystem.text("暂时离开")
	card.layout(true); next.grab_focus()
func _advance() -> void:
	var snapshot := GameState.to_save_data()
	if beat<lines.size()-1:
		beat+=1
		GameState.shared_state["meeting_beat"]=beat
		if not SaveManager.save_or_report("相遇记录未能保存"):
			GameState.load_save_data(snapshot); beat-=1
		_show_beat(); return
	if not ChapterSystem.finish_reveal(): return
	if not SaveManager.save_or_report("相遇未能保存"):
		GameState.load_save_data(snapshot); card.text_label.text=LocalizationSystem.text("暂时没能保存，可以再试一次。"); return
	queue_free()
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): queue_free(); get_viewport().set_input_as_handled()
