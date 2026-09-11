extends Control

const BACKGROUND := preload("res://art/ui/title-screen-background.png")
const ENDINGS_PATH := "res://data/story/endings.json"
const PAPER := Color("fff8eb")
const INK := Color("4a342b")
const MUTED := Color("806b5c")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const LINE := Color("b88963")

var background_texture: Texture2D = BACKGROUND


func _ready() -> void:
	_prepare_capture_state()
	_build_ui()
	if _capture_requested():
		_capture.call_deferred("ending.png")


func _draw() -> void:
	draw_texture_rect(background_texture, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color("fff5df", 0.58))


func _build_ui() -> void:
	var ending_data := _load_json(ENDINGS_PATH)
	var audit := ChapterSystem.journey_audit()
	var a: Dictionary = audit.get("A", {})
	var b: Dictionary = audit.get("B", {})
	var variant_id := _variant_id(a, b)
	var variant: Dictionary = ending_data.get("variants", {}).get(variant_id, {})
	var image_path := str(variant.get("image_path", ""))
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		var loaded = load(image_path)
		if loaded is Texture2D:
			background_texture = loaded
			queue_redraw()
	var title := str(variant.get("title", "七天已经结束"))
	_label(self, title, Vector2(120, 72), Vector2(1100, 60), 38, INK)
	var subtitle := _label(self, str(variant.get("subtitle", "结果只记录发生过的事。")), Vector2(122, 135), Vector2(1160, 54), 17, MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var role_outcomes: Dictionary = ending_data.get("role_outcomes", {})
	_result_panel(Vector2(170, 225), a, role_outcomes.get("A", {}))
	_result_panel(Vector2(830, 225), b, role_outcomes.get("B", {}))
	var closing := str(variant.get("closing", "两张几乎一样的晚霞照片慢慢重叠。"))
	var closing_label := _label(self, closing, Vector2(310, 642), Vector2(980, 38), 20, INK)
	closing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var echo_label := _label(self, _echo_text(ending_data), Vector2(310, 688), Vector2(980, 48), 15, MUTED)
	echo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	echo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var menu := _button(self, "返回主菜单", Vector2(690, 770), Vector2(220, 52), TERRACOTTA)
	menu.pressed.connect(SceneRouter.main_menu)


func _result_panel(at: Vector2, result: Dictionary, outcome_copy: Dictionary) -> void:
	var panel := Panel.new()
	panel.position = at
	panel.size = Vector2(600, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PAPER, 0.95)
	style.border_color = TEAL if bool(result.get("passed", false)) else LINE
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(INK, 0.18)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_label(panel, "%s 的七天" % str(result.get("role", "?")), Vector2(34, 30), Vector2(300, 40), 27, INK)
	_label(panel, "居民认可  %d / %d" % [int(result.get("confirmed", 0)), int(result.get("required", 12))], Vector2(34, 90), Vector2(500, 42), 23, TERRACOTTA)
	var status := "通过试居审核" if bool(result.get("passed", false)) else "没有达到12份认可"
	_label(panel, status, Vector2(34, 145), Vector2(500, 34), 18, TEAL if bool(result.get("passed", false)) else MUTED)
	var copy_key := "passed" if bool(result.get("passed", false)) else "failed"
	var outcome := _label(panel, str(outcome_copy.get(copy_key, "这七天已经被记录。")), Vector2(34, 198), Vector2(532, 58), 15, INK)
	outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(panel, "完成经历 %d · 私人记录 %d" % [int(result.get("completed_events", 0)), int(result.get("journal_entries", 0))], Vector2(34, 270), Vector2(532, 28), 15, MUTED)
	_label(panel, "待定 %d · 拒绝 %d" % [int(result.get("pending", 0)), int(result.get("refused", 0))], Vector2(34, 305), Vector2(500, 28), 15, MUTED)


func _variant_id(a: Dictionary, b: Dictionary) -> String:
	var a_passed := bool(a.get("passed", false))
	var b_passed := bool(b.get("passed", false))
	if a_passed and b_passed:
		return "both_passed"
	if a_passed:
		return "a_passed"
	if b_passed:
		return "b_passed"
	return "neither_passed"


func _echo_text(ending_data: Dictionary) -> String:
	var pieces: Array[String] = []
	for echo in ending_data.get("echoes", []):
		var journal_id := str(echo.get("journal_id", ""))
		var choice_key := str(echo.get("choice_key", ""))
		var artifact_id := str(echo.get("artifact_id", ""))
		if (not journal_id.is_empty() and _any_role_has_journal(journal_id)) or (not choice_key.is_empty() and _any_role_has_choice(choice_key)) or (not artifact_id.is_empty() and _world_has_artifact(artifact_id)):
			pieces.append(str(echo.get("text", "")))
	return "  ".join(pieces.slice(0, 2)) if not pieces.is_empty() else "结果只记录发生过的事，不替她们总结这七天。"


func _any_role_has_journal(journal_id: String) -> bool:
	GameState.commit_active_role_state()
	for role in ["A", "B"]:
		for entry in GameState.role_states.get(role, {}).get("journal_entries", []):
			if str(entry.get("id", "")) == journal_id:
				return true
	return false


func _any_role_has_choice(choice_key: String) -> bool:
	GameState.commit_active_role_state()
	for role in ["A", "B"]:
		for choice in GameState.role_states.get(role, {}).get("choice_history", []):
			if str(choice.get("key", "")) == choice_key:
				return true
	return false


func _world_has_artifact(artifact_id: String) -> bool:
	for collection in GameState.shared_state.get("world_artifacts", {}):
		for artifact in GameState.shared_state.get("world_artifacts", {})[collection]:
			if str(artifact.get("id", "")) == artifact_id:
				return true
	return false


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _prepare_capture_state() -> void:
	if not _capture_requested():
		return
	ChapterSystem.start_new_game("A")
	var resident_ids: Array = ScheduleSystem.residents.keys()
	for role in ["A", "B"]:
		GameState.switch_to_role(role)
		for index in min(12, resident_ids.size()):
			GameState.add_confirmation(str(resident_ids[index]))
	GameState.switch_to_role("A")


func _capture_requested() -> bool:
	return OS.get_cmdline_user_args().has("--capture-ending")


func _capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(filename))
	get_tree().quit()


func _label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = color.darkened(0.16)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	parent.add_child(button)
	return button
