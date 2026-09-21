extends Node
## Authored mesh groups in the Blender source are the interaction targets.
var view: Control
var items: Array = []
var targets: Dictionary = {}
var selected: Dictionary = {}
var prompt: Label
var reading: PanelContainer
var page_text: RichTextLabel
var page := 0
var pages: Array = []
var spatial_sound: AudioStreamPlayer3D
var paper_sound: AudioStreamPlayer
var examined: Array[String]=[]

func setup(owner_view: Control, room: Node) -> void:
	view = owner_view
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/meta/memory_interactions.json"))
	items = data.rooms.get(str(view.definition.id),{}).get("items",[])
	for item in items:
		var target := room.find_child(str(item.node),true,false) as Node3D
		if target == null:
			push_error("Missing memory object: "+str(item.node))
			continue
		targets[str(item.id)] = target
		_bind_meshes(target,item)
	prompt = Label.new()
	prompt.position = Vector2(560,470)
	prompt.size = Vector2(480,50)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size",21)
	prompt.add_theme_color_override("font_shadow_color",Color("15272c"))
	prompt.add_theme_constant_override("shadow_offset_y",2)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(prompt)
	spatial_sound = AudioStreamPlayer3D.new()
	spatial_sound.bus = "SoundEffects"
	spatial_sound.max_distance = 9
	spatial_sound.unit_size = 2
	spatial_sound.volume_db = -12
	view.world.add_child(spatial_sound)
	paper_sound = AudioStreamPlayer.new()
	paper_sound.bus = "SoundEffects"
	paper_sound.stream = WorldSound.make_ui("paper")
	paper_sound.volume_db = -16
	add_child(paper_sound)

func _bind_meshes(node: Node, item: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh:
		node.create_trimesh_collision()
		for body in node.get_children():
			if body is StaticBody3D: body.set_meta("memory_item",item)
	for child in node.get_children():
		if not child is PhysicsBody3D: _bind_meshes(child,item)

func update_target() -> void:
	selected = {}
	prompt.text = ""
	if is_instance_valid(reading) or not view.ready_to_walk: return
	var origin: Vector3 = view.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin,origin-view.camera.global_basis.z*2.1)
	query.exclude = [view.body.get_rid()]
	var hit: Dictionary = view.world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("memory_item"): return
	var item: Dictionary = hit.collider.get_meta("memory_item")
	if origin.distance_to(hit.position)>float(item.get("range",2.1)):return
	selected = item
	prompt.text = SettingsSystem.binding_text("interact")+" · " + LocalizationSystem.text(str(item.name))

func interact(item: Dictionary = {}) -> void:
	if not view.ready_to_walk: return
	if item.is_empty(): item = selected
	if item.is_empty(): return
	if str(item.kind)!="leave" and not examined.has(str(item.id)): examined.append(str(item.id))
	var node := targets.get(str(item.id)) as Node3D
	match str(item.kind):
		"read":
			view.caption.text = ""
			open_paper(item)
			return
		"listen":
			spatial_sound.global_position = _center(node)
			spatial_sound.stream = WorldSound.make_ui("record_start") if _cue(item)=="alarm" else WorldSound.make_detail("cafe" if _cue(item)=="clink" else "residence")
			spatial_sound.play()
		"drawer":
			var opened := not bool(node.get_meta("opened",false))
			node.set_meta("opened",opened)
			var home: Vector3 = node.get_meta("home",node.position)
			node.set_meta("home",home)
			view.create_tween().tween_property(node,"position",home+Vector3(-.3 if opened else 0,0,0),.4)
			spatial_sound.global_position = _center(node)
			spatial_sound.stream = WorldSound.make_detail("residence")
			spatial_sound.play()
		"toggle":
			if str(item.name) in ["屏幕","电脑","录音设备"]:
				_toggle_display(node)
				view.caption.text = LocalizationSystem.text(str(item.get("text","")))
				view.elapsed = 0
				return
			if str(item.name)=="水龙头":
				if spatial_sound.playing:spatial_sound.stop()
				else:
					spatial_sound.global_position=_center(node)
					spatial_sound.stream=_running_water()
					spatial_sound.play()
				return
			if str(item.name) in ["窗帘","板擦"]:
				var moved := not bool(node.get_meta("moved",false))
				node.set_meta("moved",moved)
				view.create_tween().tween_property(node,"position:x",.25 if moved else 0,.5)
				return
			var lamp := node.get_node_or_null("InteractiveLight") as OmniLight3D
			if lamp == null:
				lamp = OmniLight3D.new()
				lamp.name = "InteractiveLight"
				node.add_child(lamp)
				lamp.global_position = _center(node)+Vector3(0,.15,0)
				lamp.light_color = Color("ffd49b")
				lamp.omni_range = 3.5
				lamp.light_energy = .55
			else: lamp.visible = not lamp.visible
		"leave":
			view._leave()
			return
	view.caption.text = LocalizationSystem.text(str(item.get("text","")))
	view.elapsed = 0

func _toggle_display(node: Node3D) -> void:
	var on := not bool(node.get_meta("display_on",true))
	node.set_meta("display_on",on)
	for child in node.get_children():
		if child is MeshInstance3D:
			if not child.has_meta("lit_material"):child.set_meta("lit_material",child.material_override)
			var dark := StandardMaterial3D.new()
			dark.albedo_color = Color("18262a")
			child.material_override = child.get_meta("lit_material") if on else dark

func _cue(item: Dictionary) -> String:
	var name_text := str(item.name)
	if name_text.contains("钟") or name_text.contains("手机"): return "alarm"
	if name_text.contains("杯") or name_text.contains("钥匙"): return "clink"
	return "room"

func _running_water() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new(); wav.mix_rate=22050; wav.format=AudioStreamWAV.FORMAT_16_BITS
	var samples := PackedByteArray(); samples.resize(22050*2*2)
	var random := RandomNumberGenerator.new(); random.seed=7226
	var low := 0.0
	for frame in 44100:
		var noise := random.randf_range(-1,1); low=lerpf(low,noise,.12)
		var time := frame/22050.0
		var edge := minf(1,minf(time*40,(2-time)*40))
		var value := ((noise-low)*.06+low*.18)*(0.8+0.2*sin(time*TAU*3))*edge
		samples.encode_s16(frame*2,int(value*32767))
	wav.data=samples; wav.loop_mode=AudioStreamWAV.LOOP_FORWARD; wav.loop_end=44100
	return wav

func _center(node: Node3D) -> Vector3:
	for child in node.get_children():
		if child is MeshInstance3D: return child.global_position
	return node.global_position

func open_paper(item: Dictionary) -> void:
	if is_instance_valid(reading): reading.queue_free()
	pages = item.get("pages",[item.get("text","")])
	page = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	reading = PanelContainer.new()
	reading.position = Vector2(420,95)
	reading.size = Vector2(760,710)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("eee2c7")
	style.content_margin_left = 50
	style.content_margin_right = 50
	style.content_margin_top = 34
	style.content_margin_bottom = 30
	style.shadow_color = Color(0,0,0,.25)
	style.shadow_size = 18
	reading.add_theme_stylebox_override("panel",style)
	view.add_child(reading)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",22)
	reading.add_child(column)
	var heading := Label.new()
	heading.text = LocalizationSystem.text(str(item.name))
	heading.add_theme_font_size_override("font_size",25)
	heading.add_theme_color_override("font_color",Color("354b49"))
	column.add_child(heading)
	page_text = RichTextLabel.new()
	page_text.bbcode_enabled = true
	page_text.custom_minimum_size = Vector2(650,490)
	page_text.add_theme_color_override("default_color",Color("35413e"))
	page_text.add_theme_font_size_override("normal_font_size",27)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi","Microsoft YaHei"])
	page_text.add_theme_font_override("normal_font",font)
	column.add_child(page_text)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation",35)
	column.add_child(nav)
	for action in ["上一页","下一页","放回去"]:
		var button := Button.new()
		button.text = LocalizationSystem.text(action)
		button.disabled = pages.size()<2 and action!="放回去"
		nav.add_child(button)
		button.pressed.connect(func() -> void:
			if action == "放回去":close_paper()
			else:
				page = posmod(page+(-1 if action=="上一页" else 1),pages.size())
				_show_page())
	_show_page()

func _show_page() -> void:
	page_text.text = LocalizationSystem.text(str(pages[page]))
	paper_sound.play()

func close_paper() -> void:
	if is_instance_valid(reading):reading.queue_free()
	reading = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	paper_sound.play()
