extends Control
## A light held-camera state, followed by a fixed 3:2 optical viewfinder.
var source: Image
var source_provider: Callable
var context: Dictionary = {}
var library := PhotoLibrary.new()
var focus_active := false
var preview: TextureRect
var preview_frame: Control
var count_label: Label
var focus_label: Label
var zoom_label: Label
var held_label: Label
var shutter: Button
var flash: ColorRect
var capture_card: Panel
var zoom_value := 1.0
var zoom_steps := [1.0,1.3,1.6]
var pan := Vector2(.5,.5)
var dragging := false
var current_subject: Dictionary = {}
var subjects: Array = []
var hold_layer: Control
var finder_layer: Control
var hint: Label
var _focusing := false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	add_to_group("world_tool")
	theme = preload("res://scripts/town_sound/MediaTheme.gd").build()
	if not FilmSystem.camera_available(false): queue_free(); return
	subjects = context.get("subjects",[])
	if subjects.is_empty():
		var content: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/photography/subjects.json"))
		subjects=content.get("locations",{}).get(str(context.get("location","")),[])
	hold_layer=Control.new()
	hold_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hold_layer.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(hold_layer)
	held_label=_label(hold_layer,"",Vector2(1210,110),Vector2(355,116),20)
	finder_layer=Control.new()
	finder_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	finder_layer.mouse_filter=MOUSE_FILTER_STOP
	add_child(finder_layer)
	for rect in [Rect2(0,0,1600,105),Rect2(0,795,1600,105),Rect2(0,105,282.5,690),Rect2(1317.5,105,282.5,690)]:
		var dim:=ColorRect.new()
		dim.position=rect.position
		dim.size=rect.size
		dim.color=Color(0.04,.06,.07,.54)
		dim.mouse_filter=MOUSE_FILTER_IGNORE
		finder_layer.add_child(dim)
	preview_frame=Control.new()
	preview_frame.position=Vector2(282.5,105)
	preview_frame.size=Vector2(1035,690)
	preview_frame.gui_input.connect(_viewfinder_input)
	finder_layer.add_child(preview_frame)
	preview=TextureRect.new()
	preview.size=preview_frame.size
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter=MOUSE_FILTER_IGNORE
	preview_frame.add_child(preview)
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE,UV); float g=fract(sin(dot(UV*vec2(1035.,690.),vec2(12.9898,78.233)))*43758.5453)-.5; float v=1.-.055*dot(UV-.5,UV-.5); COLOR=vec4(c.rgb*vec3(1.008,1.,.99)*v+g*.008,c.a); }"
	var material:=ShaderMaterial.new()
	material.shader=shader
	preview.material=material
	var outline: Control=load("res://scripts/photography/camera_frame.gd").new()
	outline.size=preview_frame.size
	outline.mouse_filter=MOUSE_FILTER_IGNORE
	preview_frame.add_child(outline)
	focus_label=_label(finder_layer,"",Vector2(290,807),Vector2(620,40),19)
	count_label=_label(finder_layer,"",Vector2(1140,807),Vector2(180,40),21)
	count_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	zoom_label=_label(finder_layer,"",Vector2(1190,67),Vector2(130,32),17)
	hint=_label(finder_layer,"Space 拍摄  /  Scroll 缩放  /  Esc 放下",Vector2(490,844),Vector2(740,34),18)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shutter=Button.new()
	shutter.visible=false
	shutter.pressed.connect(take_photo)
	finder_layer.add_child(shutter)
	capture_card=Panel.new()
	capture_card.hide()
	add_child(capture_card)
	flash=ColorRect.new()
	flash.position=preview_frame.position
	flash.size=preview_frame.size
	flash.color=Color.BLACK
	flash.modulate.a=0
	flash.mouse_filter=MOUSE_FILTER_IGNORE
	finder_layer.add_child(flash)
	finder_layer.hide()
	_refresh_count()

func _label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label:=Label.new()
	label.text=LocalizationSystem.text(text)
	label.position=at
	label.size=dimensions
	label.mouse_filter=MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("f1ead6"))
	label.add_theme_color_override("font_shadow_color",Color("253d46"))
	label.add_theme_constant_override("shadow_offset_y",2)
	parent.add_child(label)
	return label

func enter_viewfinder() -> void:
	if focus_active or _focusing: return
	_focusing=true
	focus_active=true
	if source_provider.is_valid():
		hide()
		var latest = await source_provider.call()
		if latest is Image: source=latest
		show()
	_focusing=false
	hold_layer.hide()
	finder_layer.show()
	hint.modulate.a=1
	var tween:=create_tween()
	tween.tween_interval(2)
	tween.tween_property(hint,"modulate:a",0,.3)
	update_preview()

func leave_viewfinder() -> void:
	focus_active=false
	dragging=false
	finder_layer.hide()
	hold_layer.show()
	_refresh_count()

func cropped_image() -> Image:
	if source==null or source.is_empty(): return Image.new()
	var height:=maxi(2,int(minf(source.get_height(),source.get_width()/1.5)/zoom_value))
	height-=height%2
	var width:=height*3/2
	var x:=clampi(int((source.get_width()-width)*pan.x),0,source.get_width()-width)
	var y:=clampi(int((source.get_height()-height)*pan.y),0,source.get_height()-height)
	return source.get_region(Rect2i(x,y,width,height))

func update_preview() -> void:
	if source==null or preview==null: return
	var image:=cropped_image()
	if image.is_empty(): return
	preview.texture=ImageTexture.create_from_image(image)
	zoom_label.text="%.1f×" % zoom_value
	current_subject={}
	for subject in subjects:
		var target: Array=subject.get("target",[.5,.5])
		if pan.distance_to(Vector2(float(target[0]),float(target[1])))<.12: current_subject=subject; break
	_refresh_count()

func _set_zoom(value: float) -> void:
	var nearest:=1.0
	var distance:=INF
	for step in zoom_steps:
		if absf(float(step)-value)<distance: nearest=float(step); distance=absf(float(step)-value)
	zoom_value=nearest
	update_preview()

func _scroll(direction: int) -> void:
	var index:=zoom_steps.find(zoom_value)
	_set_zoom(float(zoom_steps[clampi(index+direction,0,zoom_steps.size()-1)]))

func take_photo() -> void:
	if not focus_active or _focusing or shutter.disabled: return
	shutter.disabled=true
	var shot:=context.duplicate(true)
	shot.merge({"subject_id":str(current_subject.get("id","")),"subject_name":str(current_subject.get("name","")),"location":GameState.current_location,"role":GameState.current_role},true)
	shot["title"]=TravelSystem.location_name(GameState.current_location)+" · "+GameState.clock_text()
	var captured:=FilmSystem.capture(cropped_image(),shot,library)
	if captured.is_empty(): focus_label.text=LocalizationSystem.text(FilmSystem.last_error); shutter.disabled=false; return
	WorldSound.play_ui("shutter")
	flash.modulate.a=1
	var tween:=create_tween()
	tween.tween_interval(.1)
	tween.tween_property(flash,"modulate:a",0,.015)
	tween.tween_interval(.12)
	tween.tween_callback(func()->void:if is_instance_valid(shutter):shutter.disabled=false)
	_refresh_count()

func _refresh_count() -> void:
	var roll:=FilmSystem.active_roll()
	var used:=int(roll.get("exposures_used",0))
	var title:=str(FilmSystem.config.types.get(str(roll.get("film_type","normal")),{}).get("name","胶片"))
	held_label.text=LocalizationSystem.text(("%02d / 24  ·  %s\nLMB 查看取景框\nC / Esc 收起" % [24-used,title]) if not roll.is_empty() else "相机里没有胶卷\n到杂货店装一卷\nC / Esc 收起")
	count_label.text="%02d / 24" % used
	focus_label.text=LocalizationSystem.text(title+" · 24张" if used<24 else "这一卷已拍满 · 杂货店可送洗")

func _viewfinder_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: _scroll(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1)
		elif event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
		preview_frame.accept_event()
	elif event is InputEventMouseMotion and dragging:
		pan=(pan-event.relative/preview_frame.size).clamp(Vector2.ZERO,Vector2.ONE)
		update_preview()
		preview_frame.accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("open_camera"): queue_free()
		elif event.is_action_pressed("ui_cancel"):
			if focus_active: leave_viewfinder()
			else: queue_free()
		elif event.is_action_pressed("dialogue_advance") and focus_active: take_photo()
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not focus_active and event.button_index==MOUSE_BUTTON_LEFT:
		enter_viewfinder()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	_input(event)
