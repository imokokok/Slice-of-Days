extends Control

const CREAM := Color("fff6e5")
const INK := Color("332b28")
const TERRACOTTA := Color("b85f45")
const SEA := Color("557a80")

var module_id := ""
var metadata: Dictionary = {}
var experience: Node
var complete_button: Button
var status_label: Label
var completion_ready := false


func _ready() -> void:
	module_id = GameplayModuleSystem.pending_module_id()
	metadata = GameplayModuleSystem.modules.get(module_id, {})
	var scene_path := str(metadata.get("extension_scene_path", ""))
	if module_id.is_empty() or scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		call_deferred("_fail_and_return", "扩展场景不存在，已安全返回。")
		return
	var packed = load(scene_path)
	if not packed is PackedScene:
		call_deferred("_fail_and_return", "扩展场景无法读取，已安全返回。")
		return
	experience = packed.instantiate()
	add_child(experience)
	_fit_experience()
	_build_host_bar()


func _fit_experience() -> void:
	if experience is Control:
		experience.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if experience is Node2D:
		if module_id == "ghostwriting":
			experience.position = Vector2(80, 0)
		elif module_id == "translation":
			experience.scale = Vector2(0.9, 0.9)
			experience.position = Vector2(80, 0)


func _build_host_bar() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 500
	add_child(layer)
	var panel := Panel.new()
	panel.position = Vector2(825, 12)
	panel.size = Vector2(755, 88)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(CREAM, 0.96)
	style.border_color = Color(TERRACOTTA, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(INK, 0.2)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var title := Label.new()
	title.text = str(metadata.get("name", module_id))
	title.position = Vector2(18, 10)
	title.size = Vector2(250, 28)
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", INK)
	panel.add_child(title)
	status_label = Label.new()
	status_label.text = str(metadata.get("completion_hint", "完成这段经历后返回小镇。"))
	status_label.position = Vector2(18, 40)
	status_label.size = Vector2(370, 37)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", SEA)
	panel.add_child(status_label)
	var leave := _button(panel, "暂时离开", Vector2(405, 19), Vector2(145, 50), false)
	leave.pressed.connect(_cancel)
	complete_button = _button(panel, "完成并返回", Vector2(564, 19), Vector2(170, 50), true)
	complete_button.disabled = true
	complete_button.pressed.connect(_complete)


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	var style := StyleBoxFlat.new()
	style.bg_color = TERRACOTTA if primary else Color(SEA, 0.14)
	style.border_color = TERRACOTTA if primary else SEA
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", CREAM if primary else INK)
	parent.add_child(button)
	return button


func _process(_delta: float) -> void:
	if experience == null or complete_button == null:
		return
	var ready := _experience_completed()
	if ready == completion_ready:
		return
	completion_ready = ready
	complete_button.disabled = not ready
	if ready:
		status_label.text = "这段经历已经完整，可以把结果带回 Solmere。"


func _experience_completed() -> bool:
	match module_id:
		"translation":
			return bool(experience.get("finished"))
		"ghostwriting":
			return str(experience.get("stage")) == "END"
		"chess":
			return bool(experience.get("solmere_completed"))
		"contemplation":
			return bool(ObservatoryState.discovered.get("bird", false)) or bool(ObservatoryState.discovered.get("whale", false))
	return true


func _complete() -> void:
	if not _experience_completed():
		return
	var pending: Dictionary = GameState.shared_state.get("pending_module", {})
	var source_event_id := str(pending.get("source_event_id", ""))
	if source_event_id.begins_with("space:"):
		var direct_minutes := int(metadata.get("direct_time_minutes", 0))
		if direct_minutes > 0 and not GameState.use_free_time(direct_minutes):
			status_label.text = "当前时间块已不足 %d 分钟。进度保留在扩展内部，请暂时离开。" % direct_minutes
			return
	var outcome := {
		"choice_id": "extension_complete",
		"label": str(metadata.get("name", module_id)),
		"source_event_id": source_event_id,
		"interaction": {"mode": "extension", "selected_labels": [str(metadata.get("name", module_id))]},
	}
	if not GameplayModuleSystem.complete_external(module_id, outcome, metadata.get("external_results", {})):
		status_label.text = "结果暂时无法写入主存档，请重试。"
		return
	SaveManager.save_game()
	SceneRouter.return_from_gameplay()


func _cancel() -> void:
	GameplayModuleSystem.cancel_session()
	SaveManager.save_game()
	SceneRouter.return_from_gameplay()


func _fail_and_return(message: String) -> void:
	push_error(message)
	GameplayModuleSystem.cancel_session()
	SceneRouter.return_from_gameplay()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		_cancel()
