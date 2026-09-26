extends Control
## The same white-bordered print is used in the camera, album and room.
const HAND := preload("res://art/ui/fonts/xiaolai/Xiaolai-Regular.ttf")
const INK := Color("252b27")
var image: Image
var metadata: Dictionary = {}
var editable := false
var fit_height := false
var note_input: TextEdit
var note_label: Label
var date_label: Label
var picture: TextureRect

func _ready() -> void:
	var paper := Panel.new()
	paper.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	paper.mouse_filter=MOUSE_FILTER_IGNORE
	var face := StyleBoxFlat.new()
	face.bg_color=Color("fffdf6")
	face.border_color=Color("d9d7cd")
	face.set_border_width_all(1)
	face.shadow_color=Color("252920",.22)
	face.shadow_size=12
	face.shadow_offset=Vector2(3,7)
	paper.add_theme_stylebox_override("panel",face)
	add_child(paper)
	date_label=Label.new()
	date_label.text="DAY %02d · %02d:%02d" % [int(metadata.get("day",1)),int(metadata.get("game_minute",0))/60,int(metadata.get("game_minute",0))%60]
	date_label.add_theme_font_override("font",HAND)
	date_label.add_theme_color_override("font_color",INK)
	date_label.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(date_label)
	picture=TextureRect.new()
	if image!=null and not image.is_empty(): picture.texture=ImageTexture.create_from_image(image)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(picture)
	if editable:
		note_input=TextEdit.new()
		note_input.name="WhiteBorderWriting"
		note_input.text=str(metadata.get("notes",""))
		note_input.placeholder_text=LocalizationSystem.text("在照片白边写下这一刻……")
		note_input.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
		note_input.add_theme_font_override("font",HAND)
		note_input.add_theme_color_override("font_color",INK)
		note_input.add_theme_color_override("font_placeholder_color",Color("8a8e82"))
		note_input.add_theme_color_override("caret_color",INK)
		note_input.add_theme_color_override("selection_color",Color("d7dbbb",.7))
		for state in ["normal","focus","read_only"]:
			var empty := StyleBoxEmpty.new()
			empty.set_content_margin_all(2)
			note_input.add_theme_stylebox_override(state,empty)
		add_child(note_input)
	else:
		note_label=Label.new()
		note_label.text=str(metadata.get("notes",""))
		note_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		note_label.clip_text=true
		note_label.add_theme_font_override("font",HAND)
		note_label.add_theme_color_override("font_color",INK)
		note_label.mouse_filter=MOUSE_FILTER_IGNORE
		add_child(note_label)
	_layout()

func _notification(what: int) -> void:
	if what==NOTIFICATION_RESIZED and is_instance_valid(picture): _layout()

func _layout() -> void:
	if fit_height and size.x>0: custom_minimum_size.y=size.x*710.0/960.0
	var scale_factor := size.x/960.0
	var edge := size.x*.03
	date_label.position=Vector2(edge,size.y*.022)
	date_label.size=Vector2(size.x-edge*2,size.y*.061)
	date_label.add_theme_font_size_override("font_size",maxi(8,roundi(25*scale_factor)))
	picture.position=Vector2(edge,size.y*.085)
	picture.size=Vector2(size.x-edge*2,(size.x-edge*2)*9.0/16.0)
	var writing_rect := Rect2(Vector2(edge,picture.position.y+picture.size.y+size.y*.022),Vector2(size.x-edge*2,maxf(20,size.y-picture.position.y-picture.size.y-size.y*.053)))
	var writing: Control=note_input if editable else note_label
	writing.position=writing_rect.position
	writing.size=writing_rect.size
	writing.add_theme_font_size_override("font_size",maxi(8,roundi(26*scale_factor)))

func writing() -> String:
	return note_input.text if editable and is_instance_valid(note_input) else str(metadata.get("notes",""))
