extends Control

var continuing := false
var words: Label

func _ready() -> void:
	if not bool(GameState.shared_state.get("sleep_pending", false)):
		SceneRouter.town_day()
		return
	var night := ColorRect.new()
	night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night.color = Color("111d28")
	add_child(night)
	words = Label.new()
	words.position = Vector2(300, 367)
	words.size = Vector2(1000, 160)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.add_theme_font_size_override("font_size", 29)
	words.add_theme_color_override("font_color", Color("ddd0b8"))
	var next := ChapterSystem.next_chapter()
	if str(next.get("role", "")) == "choice":
		words.text = LocalizationSystem.text("最后一天，先从哪一扇窗醒来？\n随后，另一位也将度过她的第七天。")
		add_child(words)
		for index in 2:
			var role := "A" if index == 0 else "B"
			var choice := Button.new()
			choice.text = LocalizationSystem.text("进入 " + role + " 的最后一天")
			choice.position = Vector2(470 + index * 360, 570)
			choice.size = Vector2(300, 60)
			choice.pressed.connect(func() -> void:
				if ChapterSystem.choose_final_role(role): _continue_journey())
			add_child(choice)
		return
	words.text = LocalizationSystem.text("灯熄了。海还醒着。" if next.is_empty() else "灯熄了。\n另一扇窗，正透进清晨。")
	if bool(GameState.shared_state.get("midnight_rest", false)):
		words.text = LocalizationSystem.text("夜深了，小镇渐渐安静下来。" if next.is_empty() else "夜深了，小镇渐渐安静下来。\n醒来时，又是新的一天。")
	add_child(words)
	words.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(words, "modulate:a", 1.0, 0.7)
	fade.tween_interval(1.5)
	fade.tween_property(words, "modulate:a", 0.0, 0.5)
	fade.tween_callback(_continue_journey)

func _continue_journey() -> void:
	if continuing: return
	continuing = true
	var rollback_snapshot := GameState.to_save_data().duplicate(true)
	GameState.shared_state.erase("sleep_pending")
	GameState.shared_state.erase("midnight_rest")
	ChapterSystem.mark_transition_complete(str(ChapterSystem.transition_context().get("transition_id", "")))
	var result := ChapterSystem.advance_chapter()
	if not SaveManager.save_or_report("章节切换保存失败"):
		GameState.load_save_data(rollback_snapshot)
		continuing = false
		words.text = LocalizationSystem.text("存档写入失败，请检查磁盘空间后重试。")
		words.modulate.a = 1.0
		return
	if bool(result.get("complete", false)): SceneRouter.ending()
	else: SceneRouter.town_day()
