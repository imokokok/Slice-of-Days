extends Control
## Full-screen viewfinder; the saved photo and preview use the same optical crop.
signal gallery_requested
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
var capture_card: Control
var zoom_value := 1.0
var zoom_steps := [1.0,1.3,1.6]
var pan := Vector2(.5,.5)
var dragging := false
var current_subject: Dictionary = {}
var subjects: Array = []
var hold_layer: Control
var finder_layer: Control
var hint: Label
var subject_label: Label
var finder_outline: Control
var zoom_marks: Array[Panel] = []
const STYLE := preload("res://scripts/photography/photo_style.gd")
const FRAME_FRACTION := .84
const PAN_STEP := .18
var _focusing := false

func _ready() -> void:
	add_to_group("photo_viewfinder")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	add_to_group("world_tool")
	theme = STYLE.theme()
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
	preview_frame=Control.new()
	preview_frame.position=Vector2.ZERO
	preview_frame.size=Vector2(1600,900)
	preview_frame.gui_input.connect(_viewfinder_input)
	finder_layer.add_child(preview_frame)
	preview=TextureRect.new()
	preview.size=preview_frame.size
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter=MOUSE_FILTER_IGNORE
	preview_frame.add_child(preview)
	preview.texture_filter=TEXTURE_FILTER_LINEAR
	finder_outline=load("res://scripts/photography/camera_frame.gd").new()
	finder_outline.size=preview_frame.size
	finder_outline.mouse_filter=MOUSE_FILTER_IGNORE
	preview_frame.add_child(finder_outline)
	focus_label=_label(finder_layer,"",Vector2(138,46),Vector2(340,46),20)
	count_label=_label(finder_layer,"",Vector2(1325,46),Vector2(202,46),22)
	count_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	subject_label=_label(finder_layer,"",Vector2(560,82),Vector2(480,52),23)
	subject_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var zoom_panel := Panel.new(); zoom_panel.position=Vector2(48,286); zoom_panel.size=Vector2(88,292)
	zoom_panel.add_theme_stylebox_override("panel",STYLE.surface(STYLE.PAPER,36)); finder_layer.add_child(zoom_panel)
	_icon(zoom_panel,"plus","ZoomIn",Vector2(18,18),Vector2(52,52),"放大",func() -> void: _scroll(1))
	_icon(zoom_panel,"minus","ZoomOut",Vector2(18,224),Vector2(52,52),"缩小",func() -> void: _scroll(-1))
	zoom_label=_label(zoom_panel,"",Vector2(8,80),Vector2(72,32),17)
	zoom_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var track := Line2D.new(); track.points=PackedVector2Array([Vector2(44,132),Vector2(44,208)]); track.width=3; track.default_color=Color("b4cbda"); zoom_panel.add_child(track)
	for i in 3:
		var marker := Panel.new(); marker.position=Vector2(38,200-i*34); marker.size=Vector2(12,12)
		marker.mouse_filter=MOUSE_FILTER_IGNORE; zoom_panel.add_child(marker); zoom_marks.append(marker)
	_label(finder_layer,"移动构图",Vector2(1344,254),Vector2(190,36),18).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var pan_pad := Panel.new(); pan_pad.position=Vector2(1344,306); pan_pad.size=Vector2(190,190)
	pan_pad.add_theme_stylebox_override("panel",STYLE.surface(STYLE.PAPER,28)); finder_layer.add_child(pan_pad)
	var directions := [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]
	var kinds := ["up","down","left","right"]
	var names := ["PanUp","PanDown","PanLeft","PanRight"]
	var titles := ["取景向上","取景向下","取景向左","取景向右"]
	for index in 4:
		var direction: Vector2=directions[index]
		_icon(pan_pad,kinds[index],names[index],Vector2(68,68)+direction*59,Vector2(54,54),titles[index],func() -> void: _pan_frame(direction*PAN_STEP))
	_icon(pan_pad,"center","Recenter",Vector2(68,68),Vector2(54,54),"构图回到中心",_recenter)
	hint=_label(finder_layer,SettingsSystem.binding_text("camera_shutter")+" 拍照 · 滚轮缩放 · 拖动 / 方向键移动",Vector2(370,820),Vector2(860,46),19)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shutter=_icon(finder_layer,"shutter","Shutter",Vector2(1368,742),Vector2(118,118),"拍照",take_photo)
	flash=ColorRect.new()
	flash.position=preview_frame.position
	flash.size=preview_frame.size
	flash.color=Color("fffdf3")
	flash.modulate.a=0
	flash.mouse_filter=MOUSE_FILTER_IGNORE
	finder_layer.add_child(flash)
	finder_layer.hide()
	_refresh_count()
	for parent in [hold_layer,finder_layer]:
		_icon(parent,"back","CameraBack",Vector2(48,38),Vector2(68,68),"放下相机",queue_free)
	var focus := Button.new(); focus.text=LocalizationSystem.text("举起相机"); focus.position=Vector2(1210,250); focus.size=Vector2(355,52); hold_layer.add_child(focus); focus.pressed.connect(enter_viewfinder)
	_icon(finder_layer,"album","OpenGallery",Vector2(65,752),Vector2(92,92),"查看相册",func() -> void: gallery_requested.emit(); queue_free())
	enter_viewfinder.call_deferred()

func _icon(parent: Node, kind: String, node_name: String, at: Vector2, extent: Vector2, title: String, action: Callable) -> Button:
	var button := preload("res://scripts/photography/photo_icon_button.gd").new()
	button.kind=kind; button.name=node_name; button.position=at; button.size=extent
	button.accessibility_name=LocalizationSystem.text(title); button.tooltip_text=LocalizationSystem.text(title)
	button.pressed.connect(action); parent.add_child(button)
	return button

func _label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var caption := Panel.new(); caption.position=at; caption.size=dimensions; caption.mouse_filter=MOUSE_FILTER_IGNORE
	caption.add_theme_stylebox_override("panel",STYLE.surface(STYLE.PAPER,18)); parent.add_child(caption)
	var label:=Label.new()
	label.text=LocalizationSystem.text(text)
	label.position=Vector2(8,3)
	label.size=dimensions-Vector2(16,6)
	label.mouse_filter=MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",STYLE.INK)
	caption.add_child(label)
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
	hint.get_parent().modulate.a=1
	update_preview()

func leave_viewfinder() -> void:
	focus_active=false
	dragging=false
	finder_layer.hide()
	hold_layer.show()
	_refresh_count()

func crop_rect() -> Rect2i:
	if source==null or source.is_empty(): return Rect2i()
	# Reserve travel at normal magnification; a full-source frame cannot pan.
	var height:=maxi(9,int(minf(source.get_height(),source.get_width()*9.0/16.0)*FRAME_FRACTION/zoom_value))
	height-=height%9
	var width:=height*16/9
	var x:=clampi(int((source.get_width()-width)*pan.x),0,source.get_width()-width)
	var y:=clampi(int((source.get_height()-height)*pan.y),0,source.get_height()-height)
	return Rect2i(x,y,width,height)

func cropped_image() -> Image:
	var region := crop_rect()
	return source.get_region(region) if region.has_area() else Image.new()

func _pan_frame(offset: Vector2) -> void:
	if not focus_active or _focusing or is_instance_valid(capture_card): return
	pan=(pan+offset).clamp(Vector2.ZERO,Vector2.ONE)
	update_preview()

func _recenter() -> void:
	_pan_frame(Vector2(.5,.5)-pan)

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
	subject_label.get_parent().visible=not current_subject.is_empty()
	subject_label.text=LocalizationSystem.text("取景 · "+str(current_subject.get("name","")))
	finder_outline.focused=not current_subject.is_empty(); finder_outline.queue_redraw()
	for i in zoom_marks.size(): zoom_marks[i].add_theme_stylebox_override("panel",STYLE.surface(STYLE.CORAL if is_equal_approx(zoom_value,float(zoom_steps[i])) else STYLE.BLUE,6))
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
	if not focus_active or _focusing or shutter.disabled or is_instance_valid(capture_card): return
	dragging=false
	shutter.disabled=true
	if source_provider.is_valid():
		hide()
		var latest = await source_provider.call()
		if latest is Image: source=latest
		show()
	var shot:=context.duplicate(true)
	shot.merge({"subject_id":str(current_subject.get("id","")),"subject_name":str(current_subject.get("name","")),"location":GameState.current_location,"role":GameState.current_role},true)
	shot["title"]=TravelSystem.location_name(GameState.current_location)+" · "+GameState.clock_text()
	var image:=cropped_image()
	var captured:=FilmSystem.capture(image,shot,library)
	if captured.is_empty(): focus_label.text=LocalizationSystem.text(FilmSystem.last_error); shutter.disabled=false; return
	WorldSound.play_ui("shutter")
	flash.modulate.a=1
	var tween:=create_tween()
	tween.tween_interval(.1)
	tween.tween_property(flash,"modulate:a",0,.015)
	tween.tween_interval(.12)
	tween.tween_callback(_show_capture_print.bind(captured,image))
	_refresh_count()

func _show_capture_print(captured: Dictionary, image: Image) -> void:
	capture_card=preload("res://scripts/photography/photo_inscription.gd").new()
	capture_card.image=image
	capture_card.metadata=captured
	capture_card.library=library
	capture_card.is_negative=true
	capture_card.closed.connect(func() -> void:
		capture_card=null
		shutter.disabled=false)
	add_child(capture_card)

func _refresh_count() -> void:
	var roll:=FilmSystem.active_roll()
	var used:=int(roll.get("exposures_used",0))
	var title:=str(FilmSystem.config.types.get(str(roll.get("film_type","normal")),{}).get("name","胶片"))
	held_label.text=LocalizationSystem.text(("%02d / 24  ·  %s\n选择查看取景框\n拍摄后到杂货店冲洗" % [24-used,title]) if not roll.is_empty() else "相机里没有胶卷\n到杂货店装一卷\n选择收起相机")
	count_label.text="%02d / 24" % used
	focus_label.text=LocalizationSystem.text(title+" · 24张" if used<24 else "这一卷已拍满 · 杂货店可送洗")

func _viewfinder_input(event: InputEvent) -> void:
	if not focus_active or _focusing or is_instance_valid(capture_card): return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: _scroll(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1)
		elif event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
		preview_frame.accept_event()
	elif event is InputEventMouseMotion and dragging:
		var frame := Vector2(crop_rect().size)
		var travel := Vector2(source.get_size())-frame
		var displacement: Vector2=event.relative/preview_frame.size*frame
		_pan_frame(-displacement/Vector2(maxf(1,travel.x),maxf(1,travel.y)))
		preview_frame.accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: dragging=false
	if is_instance_valid(capture_card): return
	if event is InputEventKey and event.pressed and focus_active and not _focusing:
		var direction := Vector2.ZERO
		if event.is_action_pressed("ui_up",true): direction=Vector2.UP
		elif event.is_action_pressed("ui_down",true): direction=Vector2.DOWN
		elif event.is_action_pressed("ui_left",true): direction=Vector2.LEFT
		elif event.is_action_pressed("ui_right",true): direction=Vector2.RIGHT
		if direction!=Vector2.ZERO:
			_pan_frame(direction*PAN_STEP)
			get_viewport().set_input_as_handled()
			return
	if event.is_pressed() and not event.is_echo() and not event is InputEventMouseButton:
		if event.is_action_pressed("open_camera"): queue_free()
		elif event.is_action_pressed("ui_cancel"): queue_free()
		elif event.is_action_pressed("camera_shutter") and focus_active: take_photo()
		else: return
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	_input(event)
