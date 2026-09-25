extends Control
## Compatibility host for the shop; recording itself belongs to RecordingSession.
var shop_mode:=false
var store:=SampleStore.new()
var page_scroll: Control
var recorder: FieldRecorder:
	get: return RecordingSession.recorder

func _ready() -> void:
	add_to_group("town_sound_workspace"); add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	preload("res://scripts/town_sound/data/LegacyTownSound.gd").migrate()
	load("res://scripts/town_sound/record_shop/PresetRecords.gd").ensure_presets()
	page_scroll=load("res://scripts/town_sound/SoundCollection.gd").new()
	page_scroll.shop_mode=can_edit_here(); add_child(page_scroll)
	page_scroll.closed.connect(queue_free)
	page_scroll.studio_requested.connect(_open_studio)

func _label(text:String,font_size:=17) -> Label:
	var label:=Label.new(); label.text=LocalizationSystem.text(text); label.add_theme_font_size_override("font_size",font_size); return label
func _button(text:String,action:Callable) -> Button:
	var button=preload("res://scripts/ui/components/solmere_button.gd").new(); button.variant="paper"; button.text=LocalizationSystem.text(text); button.pressed.connect(action); return button
func can_edit_here() -> bool: return shop_mode and GameState.current_location=="record_store"
func _open_studio() -> void:
	if not can_edit_here() or not RecordingSession.finish_for_exit(): return
	if not page_scroll.visible: return
	page_scroll.player.stop()
	var studio=load("res://scripts/town_sound/studio/StudioScreen.gd").new()
	studio.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(studio); page_scroll.hide()
	studio.tree_exited.connect(func():
		if is_instance_valid(page_scroll): page_scroll.show(); page_scroll.refresh())
func _open_record_shelf() -> void:
	if not can_edit_here() or not RecordingSession.finish_for_exit(): return
	page_scroll.player.stop()
	var shelf=load("res://scripts/town_sound/record_shop/RecordShelf.gd").new(); shelf.host=self; add_child(shelf); page_scroll.hide()
	shelf.tree_exited.connect(func():
		if is_instance_valid(page_scroll): page_scroll.show(); page_scroll.refresh())
func request_close() -> void:
	if RecordingSession.finish_for_exit(): queue_free()
