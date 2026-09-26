extends CanvasLayer
## Persistent pocket controls, including native and hosted minigames.
var page: Control
var pocket: Button
var stop_button: Button
var view: Control
var collection: Control
var last_scene: Node
var thumbnail: Control
var sample_notice:=0.0
var capture_hidden:=false
const SCENES=["res://scenes/town_day.tscn","res://scenes/interactive_space.tscn","res://scenes/native_module_game.tscn","res://scenes/module_workbench.tscn","res://scenes/extension_host.tscn","res://scenes/tarot_table.tscn","res://scenes/town_map.tscn"]
var recorder: FieldRecorder:
	get: return RecordingSession.recorder
var levels: Array[float]:
	get: return RecordingSession.levels
var playback: AudioStreamPlayer:
	get: return RecordingSession.playback

func _ready() -> void:
	layer=80; process_mode=Node.PROCESS_MODE_ALWAYS
	page=Control.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); page.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(page)
	page.theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	pocket=preload("res://scripts/ui/components/solmere_button.gd").new(); pocket.variant="paper"; pocket.name="GlobalRecorderPocket"; pocket.text="录音机"; pocket.icon=preload("res://scripts/town_sound/SoundIcons.gd").get_icon("cassette-tape"); pocket.add_theme_constant_override("icon_max_width",24); pocket.size=Vector2(148,48); pocket.pressed.connect(open_recorder); page.add_child(pocket)
	stop_button=preload("res://scripts/ui/components/solmere_button.gd").new(); stop_button.variant="primary"; stop_button.size=Vector2(114,48); stop_button.text="■ 保存"; stop_button.pressed.connect(RecordingSession.stop); page.add_child(stop_button)
	thumbnail=preload("res://scripts/ui/components/live_sound_window.gd").new(); thumbnail.source=self; thumbnail.size=Vector2(148,83); page.add_child(thumbnail)
	RecordingSession.sample_saved.connect(func(_item:Dictionary): sample_notice=4)
	get_tree().auto_accept_quit=false

func current_mv_kind() -> String: return RecordingSession.current_mv_kind()
func current_mv_seed() -> int: return RecordingSession.current_mv_seed()
func available() -> bool:
	var scene:=get_tree().current_scene
	return is_instance_valid(scene) and scene.scene_file_path in SCENES
func focused() -> bool: return is_instance_valid(view) or is_instance_valid(collection)

func _process(delta:float) -> void:
	var scene:=get_tree().current_scene
	if scene!=last_scene:
		last_scene=scene
		if is_instance_valid(view): view.queue_free()
		if is_instance_valid(collection): collection.queue_free()
	sample_notice=maxf(0,sample_notice-delta)
	var recording:=recorder.capturing
	var camera_open:=not get_tree().get_nodes_in_group("photo_viewfinder").is_empty()
	var workspace_open:=not get_tree().get_nodes_in_group("town_sound_workspace").is_empty()
	var visible_now:=available() and not focused() and not capture_hidden and not camera_open and not workspace_open and not SceneRouter.transitioning
	pocket.visible=visible_now; stop_button.visible=visible_now and recording; thumbnail.visible=visible_now and recording
	var x:=page.size.x-166
	# The town's direction card and material notice occupy the first 300 px.
	var y:=330.0 if is_instance_valid(scene) and scene.has_node("GameplayShell") else 92.0
	pocket.position=Vector2(x,y); stop_button.position=Vector2(x-122,y); thumbnail.position=Vector2(x,y+54)
	pocket.text="● %02d:%02d"%[int(recorder.elapsed)/60,int(recorder.elapsed)%60] if recording else "✓ 已保存" if sample_notice>0 else "录音机"
	pocket.tooltip_text="展开录音机 · "+SettingsSystem.binding_text("open_recorder")+"\n环境声、背景声与互动音效一起收集"
	if RecordingSession.pending_wav!=null: pocket.text="录音待保存"

func open_recorder() -> Control:
	if is_instance_valid(view): return view
	if is_instance_valid(collection): collection.queue_free()
	RecordingSession.recover_pending()
	view=load("res://scripts/residency/recorder_lite.gd").new(); page.add_child(view)
	return view

func open_library() -> void:
	if not RecordingSession.finish_for_exit(): open_recorder(); return
	if is_instance_valid(collection): return
	if is_instance_valid(view): view.queue_free()
	collection=load("res://scripts/town_sound/SoundCollection.gd").new(); page.add_child(collection)

func _unhandled_input(event:InputEvent) -> void:
	if not available() or focused() or SceneRouter.transitioning or not get_tree().get_nodes_in_group("town_sound_workspace").is_empty() or not event.is_pressed() or event.is_echo(): return
	if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit: return
	if event.is_action_pressed("open_recorder"):
		if recorder.capturing: RecordingSession.stop()
		else: open_recorder()
		get_viewport().set_input_as_handled()

func _input(event:InputEvent) -> void:
	# Native minigames also used R as a local action. Claim the global recorder
	# shortcut before their unhandled input, without taking text-entry keys.
	var scene:=get_tree().current_scene
	if is_instance_valid(scene) and not scene.has_node("GameplayShell"):
		_unhandled_input(event)

func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if RecordingSession.finish_for_exit(): get_tree().quit()
		else: open_recorder()
