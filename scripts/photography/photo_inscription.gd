extends Control
## Writing is part of the print's white border, not a separate metadata form.
signal saved(note: String)
signal closed
var image: Image
var metadata: Dictionary = {}
var library := PhotoLibrary.new()
var is_negative := false
var print_view: Control
var status: Label
var save_button: Button
var _saving := false
const STYLE := preload("res://scripts/photography/photo_style.gd")

func _ready() -> void:
	add_to_group("photo_inscription")
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter=MOUSE_FILTER_STOP
	theme=STYLE.theme()
	var shade := ColorRect.new()
	shade.color=Color("afd8cb",.96)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)
	print_view=preload("res://scripts/photography/photo_print.gd").new()
	print_view.name="WritablePhotoPrint"
	print_view.image=image
	print_view.metadata=metadata
	print_view.editable=true
	print_view.position=Vector2(320,55)
	print_view.size=Vector2(960,710)
	add_child(print_view)
	status=Label.new()
	status.position=Vector2(320,785)
	status.size=Vector2(465,65)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color",STYLE.INK)
	status.add_theme_font_size_override("font_size",18)
	add_child(status)
	save_button=_button("收好这张照片" if not is_negative else "保存文字，继续拍摄",Vector2(1010,787),Vector2(270,50),_save)
	_button("不改动返回",Vector2(810,787),Vector2(180,50),_close)
	print_view.note_input.text_changed.connect(_update_status)
	_update_status()
	print_view.note_input.grab_focus.call_deferred()

func _button(title: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text=LocalizationSystem.text(title)
	button.position=at
	button.size=extent
	button.add_theme_font_size_override("font_size",20)
	button.pressed.connect(action)
	add_child(button)
	return button

func _update_status() -> void:
	var length: int=print_view.writing().length()
	save_button.disabled=length>FilmSystem.PHOTO_NOTE_LIMIT
	status.text=LocalizationSystem.text(("白边随胶卷保存，冲洗后可在相册中修改。" if is_negative else "点白边直接写字，文字会留在这张照片上。")+"\n%d / %d 字" % [length,FilmSystem.PHOTO_NOTE_LIMIT])

func _save() -> void:
	if _saving: return
	_saving=true
	var note: String=print_view.writing().strip_edges()
	var id := str(metadata.get("capture_id","")) if is_negative else str(metadata.get("photo_id",metadata.get("id","")))
	if not FilmSystem.write_photo_note(id,note,library):
		status.text=LocalizationSystem.text(FilmSystem.last_error)
		_saving=false
		return
	saved.emit(note)
	_close()

func _close() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_save()
		get_viewport().set_input_as_handled()
