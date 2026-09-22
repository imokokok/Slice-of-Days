extends Node3D
signal return_requested
signal finish_requested
const Volume = preload("res://extensions/observatory/scripts/nebula_volume.gd")
const ButtonComponent = preload("res://scripts/ui/components/solmere_button.gd")
const Catalog = preload("res://extensions/observatory/resources/nebula_catalog.gd")
var entries: Array = Catalog.entries()
var selected_index := 0
var angles := Vector2.ZERO
var distance := 52.0
var pan := Vector3.ZERO
var camera: Camera3D
var volume: Node3D
var ui: CanvasLayer
var chrome: Control
var sky_drag: Control
var heading: Label
var description: Label
var credits: RichTextLabel
var hint: Label
var capture_button: Button
var finish_button: Button
var tabs: Array[Button] = []
var library := PhotoLibrary.new()
var legacy: Node3D
var gallery: Control
var is_capturing := false
var solmere_completed := false
var session_photos: Array[Dictionary] = []
var view_age := 0.0
var original_views: Dictionary = {}
var legacy_ui: CanvasLayer
var captured_session_ids: Array[String] = []
var pending_image: Image
var pending_context: Dictionary
var science_panel: PanelContainer

func _ready() -> void:
	camera = $Camera3D
	volume = Volume.new()
	add_child(volume)
	original_views = GameState.artifacts.get("telescope_views", {}).duplicate(true)
	_build_ui()
	var previous := str(GameState.artifacts.get("telescope_selected", "orion"))
	for i in entries.size():
		if entries[i].id == previous: selected_index=i
	select_nebula(selected_index)

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := ButtonComponent.new()
	b.variant="camera"; b.text=text
	b.add_theme_font_size_override("font_size",22)
	b.custom_minimum_size=Vector2(96,48)
	parent.add_child(b)
	b.pressed.connect(callback)
	b.pressed.connect(func():
		if is_instance_valid(sky_drag) and not is_instance_valid(gallery) and not is_instance_valid(legacy):
			sky_drag.grab_focus())
	return b

func _label(parent: Node, text: String, font_size := 20) -> Label:
	var label := Label.new()
	label.text=text
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",PaperLanguage.body_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("faf7ee"))
	parent.add_child(label)
	return label

func _build_ui() -> void:
	ui=CanvasLayer.new(); ui.name="UI"; ui.layer=30; add_child(ui)
	chrome=Control.new(); chrome.name="Chrome"; ui.add_child(chrome)
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter=Control.MOUSE_FILTER_IGNORE
	sky_drag=Control.new(); sky_drag.name="SkyDrag"; chrome.add_child(sky_drag)
	sky_drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky_drag.focus_mode=Control.FOCUS_ALL
	sky_drag.mouse_default_cursor_shape=Control.CURSOR_DRAG
	sky_drag.gui_input.connect(_sky_input)
	var top := HBoxContainer.new(); top.name="Navigation"; chrome.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left=32; top.offset_right=-32; top.offset_top=24
	top.add_theme_constant_override("separation",12)
	_button(top,"← 海边",_return)
	var space := Control.new(); space.size_flags_horizontal=Control.SIZE_EXPAND_FILL; top.add_child(space)
	for i in entries.size():
		tabs.append(_button(top,entries[i].title,select_nebula.bind(i)))
	space=Control.new(); space.size_flags_horizontal=Control.SIZE_EXPAND_FILL; top.add_child(space)
	_button(top,"连星",open_constellations)
	_button(top,"观测册",open_gallery)
	_button(top,"关于这片星云",_toggle_science)
	var footer := Panel.new(); footer.name="ReadableObservation"; chrome.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top=-254
	footer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	footer.add_theme_stylebox_override("panel",preload("res://scripts/ui/components/interface_palette.gd").face(Color("192c3c"),0,0))
	var bottom := HBoxContainer.new(); bottom.name="Observation"; chrome.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left=40; bottom.offset_right=-40; bottom.offset_top=-237; bottom.offset_bottom=-82
	bottom.alignment=BoxContainer.ALIGNMENT_BEGIN
	bottom.add_theme_constant_override("separation",14)
	var info := VBoxContainer.new(); info.size_flags_horizontal=Control.SIZE_EXPAND_FILL; bottom.add_child(info)
	heading=_label(info,"",30)
	description=_label(info,"",22)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color",Color("c6d3df"))
	hint=_label(info,"",26)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var actions := VBoxContainer.new(); actions.size_flags_vertical=Control.SIZE_SHRINK_END; bottom.add_child(actions)
	var zooms := HBoxContainer.new(); actions.add_child(zooms)
	_button(zooms,"－ 远",zoom.bind(1.15))
	_button(zooms,"＋ 近",zoom.bind(.87))
	_button(zooms,"复位",reset_view)
	capture_button=_button(actions,"留下这片星光",collect)
	finish_button=_button(actions,"带着观测回去",func():finish_requested.emit())
	finish_button.hide()
	credits=RichTextLabel.new(); credits.name="Credits"; ui.add_child(credits)
	credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	credits.offset_left=40; credits.offset_right=-40; credits.offset_top=-62; credits.offset_bottom=-8
	credits.add_theme_font_override("normal_font",PaperLanguage.body_font)
	credits.add_theme_font_size_override("normal_font_size",17)
	credits.add_theme_color_override("default_color",Color("c6d3df"))
	credits.bbcode_enabled=true; credits.scroll_active=false
	credits.meta_clicked.connect(func(url: Variant): OS.shell_open(str(url)))
	sky_drag.grab_focus()

func _remember_view() -> void:
	var views: Dictionary = GameState.artifacts.get("telescope_views",{})
	views[entries[selected_index].id]={"angles":[angles.x,angles.y],"distance":distance,"pan":[pan.x,pan.y,pan.z]}
	GameState.artifacts["telescope_views"]=views
	original_views=views.duplicate(true)
	GameState.artifacts["telescope_selected"]=entries[selected_index].id

func select_nebula(index: int) -> void:
	if is_capturing: return
	if volume.get_child_count()>0: _remember_view()
	selected_index=posmod(index,entries.size())
	var entry: Dictionary=entries[selected_index]
	var view: Dictionary=GameState.artifacts.get("telescope_views",{}).get(entry.id,{})
	var a: Array=view.get("angles",[0.0,0.0])
	angles=Vector2(float(a[0]),float(a[1]))
	distance=clampf(float(view.get("distance",40.0 if not entry.has("model") else 36.0)),18,85)
	var p: Array=view.get("pan",[0.0,0.0,0.0])
	pan=Vector3(float(p[0]),float(p[1]),float(p[2]))
	volume.build(entry)
	heading.text=entry.title+"  /  "+entry.subtitle
	description.text=str(entry.get("introduction",entry.treatment))
	if is_instance_valid(science_panel): science_panel.queue_free(); science_panel=null
	credits.text="[url="+entry.source+"]"+entry.credit+"[/url]\n"+("照片 [url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url] · " if not str(entry.image).is_empty() else "")+"Solmere：空间呈现与着色；非机构背书"
	for i in tabs.size(): tabs[i].selected=i==selected_index
	view_age=0
	hint.text="拖动环绕 · 滚轮拉近 · "+SettingsSystem.binding_text("nebula_left")+"/"+SettingsSystem.binding_text("nebula_right")+" 转动 · "+SettingsSystem.binding_text("ui_cancel")+" 返回"
	update_camera()

func update_camera() -> void:
	angles.y=clampf(angles.y,-1.15,1.15)
	angles.x=wrapf(angles.x,-PI,PI)
	var basis := Basis.from_euler(Vector3(angles.y,angles.x,0))
	camera.transform=Transform3D(basis,pan+basis*Vector3(0,-5.5,distance))

func _sky_input(event: InputEvent) -> void:
	if is_capturing or is_instance_valid(gallery): return
	if event is InputEventMouseButton and event.pressed:
		sky_drag.grab_focus()
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom(.9)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom(1.1)
		sky_drag.accept_event()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			angles-=event.relative*.004
			update_camera(); sky_drag.accept_event()
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			pan += camera.basis * Vector3(-event.relative.x,event.relative.y,0)*distance*.0007
			pan=pan.clamp(Vector3(-12,-12,-8),Vector3(12,12,8))
			update_camera(); sky_drag.accept_event()

func zoom(factor: float) -> void:
	if is_capturing: return
	distance=clampf(distance*factor,18,85)
	update_camera()

func reset_view() -> void:
	angles=Vector2.ZERO; pan=Vector3.ZERO; distance=40.0 if not entries[selected_index].has("model") else 36.0
	update_camera()

func _process(delta: float) -> void:
	if is_capturing or is_instance_valid(legacy) or is_instance_valid(gallery): return
	view_age+=delta
	hint.modulate.a=1.0
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and focused != sky_drag: return
	var direction := Input.get_vector("nebula_left","nebula_right","nebula_up","nebula_down")
	if direction.length_squared()>.001:
		angles+=direction*delta*.55
		update_camera()
	var zoom_input := Input.get_axis("nebula_near","nebula_far")
	if absf(zoom_input)>.01: zoom(exp(zoom_input*delta*.6))

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(legacy) or is_capturing: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(science_panel): science_panel.queue_free(); science_panel=null
		elif is_instance_valid(gallery): close_gallery()
		else: _return()
	elif event.is_action_pressed("camera_shutter") and not is_instance_valid(gallery):
		get_viewport().set_input_as_handled()
		collect()

func _toggle_science() -> void:
	if is_instance_valid(science_panel): science_panel.queue_free(); science_panel=null; return
	var entry: Dictionary=entries[selected_index]
	science_panel=PanelContainer.new(); science_panel.name="NebulaScience"; chrome.add_child(science_panel)
	science_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	science_panel.offset_left=-612; science_panel.offset_right=-32; science_panel.offset_top=96; science_panel.offset_bottom=624
	science_panel.add_theme_stylebox_override("panel",preload("res://scripts/ui/components/interface_palette.gd").face(Color("203a4c"),6,24))
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; science_panel.add_child(scroll)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",19); scroll.add_child(rows)
	_label(rows,str(entry.title)+" · 观测笔记",29)
	for paragraph in entry.get("science",[]):
		var line := _label(rows,str(paragraph),23); line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var treatment := _label(rows,"这里的空间呈现\n"+str(entry.treatment),21); treatment.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var source := LinkButton.new(); source.text="阅读 NASA / ESA 原始资料"; source.add_theme_font_size_override("font_size",22); source.pressed.connect(func():OS.shell_open(str(entry.get("science_source",entry.source)))); rows.add_child(source)
	_button(rows,"收起介绍",_toggle_science).grab_focus()

func _return() -> void:
	if is_capturing: return
	_remember_view()
	return_requested.emit()

func preserve_after_cancel() -> void:
	# Cancel rolls the gameplay session back. Keep only earned local media and
	# telescope view settings, without silently completing/charging the activity.
	var views: Dictionary=original_views.duplicate(true)
	views[entries[selected_index].id]={"angles":[angles.x,angles.y],"distance":distance,"pan":[pan.x,pan.y,pan.z]}
	GameState.artifacts["telescope_views"]=views
	GameState.artifacts["telescope_selected"]=entries[selected_index].id
	for photo in session_photos: GameState.add_artifact("photos",photo)
	ResidencySystem._sync_sources()
	GameState.commit_active_role_state()

func collect() -> void:
	if is_capturing or is_instance_valid(legacy) or is_instance_valid(gallery): return
	is_capturing=true
	capture_button.disabled=true
	if pending_image==null:
		chrome.hide()
		await RenderingServer.frame_post_draw
		if not is_inside_tree(): return
		pending_image=get_viewport().get_texture().get_image()
		chrome.show()
		var entry: Dictionary=entries[selected_index]
		pending_context={"title":"星云观测 · "+entry.title,"location":"夜海观景台","location_id":"park","day":GameState.current_day,"game_minute":GameState.current_minute,"role":GameState.current_role,"capture_id":"telescope_"+str(Time.get_ticks_usec()),"source":"telescope","nebula_id":entry.id,"source_url":entry.source,"credit":entry.credit,"treatment":entry.treatment,"view_angles":[angles.x,angles.y],"view_distance":distance}
	var photo := library.save_photo(pending_image,pending_context)
	if not photo.is_empty():
		photo.merge(pending_context,true)
		photo["id"]=photo.photo_id; photo["kind"]="photo"; photo["status"]="DEVELOPED"
		photo["developed_path"]=library.root_path.path_join(str(photo.photo_id)).path_join("photo.png")
		if library.update_metadata(str(photo.photo_id),photo):
			var snapshot := GameState.to_save_data().duplicate(true)
			GameState.add_artifact("photos",photo)
			_remember_view()
			ResidencySystem._sync_sources()
			GameState.commit_active_role_state()
			if SaveManager.save_game():
				session_photos.append(photo)
				captured_session_ids.append(str(photo.nebula_id))
				solmere_completed=true
				pending_image=null
				finish_button.show()
				ObservatoryAudio.feedback(true)
				hint.text="已收入相册，也可以放进七天作品集。"
				view_age=0
			else:
				GameState.load_save_data(snapshot)
				hint.text="画面已保留，存档暂时没写入。点击重试保存。"
		else: hint.text="照片信息未写入；画面已保留，点击重试。"
	else: hint.text=library.last_error
	capture_button.text="重试保存星光" if pending_image!=null else "再留一张"
	capture_button.disabled=false
	is_capturing=false

func open_constellations() -> void:
	if is_capturing or is_instance_valid(legacy): return
	_remember_view()
	chrome.hide(); credits.hide(); volume.hide()
	legacy=load("res://extensions/observatory/scenes/Constellations3D.tscn").instantiate()
	add_child(legacy)
	# Nested legacy layer must sit above the telescope's retained UI layer.
	legacy_ui=legacy.get_node("UI")
	legacy_ui.layer=31
	legacy.return_requested.connect(func():
		solmere_completed=solmere_completed or bool(legacy.solmere_completed)
		remove_child(legacy); legacy.queue_free(); legacy=null
		camera.make_current(); chrome.show(); credits.show(); volume.show()
		finish_button.visible=solmere_completed
		sky_drag.grab_focus())

func open_gallery() -> void:
	if is_capturing or is_instance_valid(gallery): return
	gallery=PanelContainer.new(); gallery.name="ObservationAlbum"; ui.add_child(gallery)
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery.offset_left=72; gallery.offset_top=85; gallery.offset_right=-72; gallery.offset_bottom=-80
	var style := StyleBoxFlat.new()
	style.bg_color=Color("142337"); style.set_content_margin_all(24); style.set_corner_radius_all(8)
	gallery.add_theme_stylebox_override("panel",style)
	var layout := VBoxContainer.new(); gallery.add_child(layout)
	var photos := library.list_photos().filter(func(row: Dictionary)->bool:return row.get("source","")=="telescope" and row.get("role","")==GameState.current_role)
	var header := HBoxContainer.new(); layout.add_child(header)
	_label(header,"观测册",24).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(header,"返回星空",close_gallery)
	if photos.is_empty():
		_label(layout,"还没有留下星云。转动望远镜，选一个想带走的角度。",20)
		return
	var image := TextureRect.new(); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical=Control.SIZE_EXPAND_FILL; layout.add_child(image)
	var caption := _label(layout,"",17)
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var nav := HBoxContainer.new(); nav.alignment=BoxContainer.ALIGNMENT_CENTER; layout.add_child(nav)
	gallery.set_meta("index",0)
	var show_photo := func():
		var row: Dictionary=photos[int(gallery.get_meta("index"))]
		var loaded := library.load_photo(row.photo_id)
		image.texture=ImageTexture.create_from_image(loaded) if loaded!=null else null
		caption.text=str(row.title)+" · Day "+str(row.day)+"\n"+str(row.get("credit",""))
		if loaded==null: caption.text+="\n这张照片文件暂时无法读取。"
	_button(nav,"← 上一张",func(): gallery.set_meta("index",posmod(int(gallery.get_meta("index"))-1,photos.size())); show_photo.call())
	_button(nav,"下一张 →",func(): gallery.set_meta("index",posmod(int(gallery.get_meta("index"))+1,photos.size())); show_photo.call())
	show_photo.call()
	nav.get_child(0).grab_focus()

func close_gallery() -> void:
	if not is_instance_valid(gallery): return
	gallery.queue_free(); gallery=null
	sky_drag.grab_focus()

func observation_result() -> Dictionary:
	return {"nebula_ids":captured_session_ids.duplicate(),"photo_ids":session_photos.map(func(p:Dictionary)->String:return p.photo_id)}
