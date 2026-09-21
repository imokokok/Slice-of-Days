extends Control
## Single scene owns the paper and the 3D room; no loading fade or teleport cut.
var definition: Dictionary = {}
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var body: CharacterBody3D
var paper: MeshInstance3D
var sound: AudioStreamPlayer
var intro_paper: TextureRect
var status: Label
var caption: Label
var ready_to_walk := false
var pitch := 0.0
var yaw := 0.0
var elapsed := 0.0
var exit_started := false
var transition_tween: Tween
var objects: Node
var entry_rect := Rect2(450,230,700,500)
var close: Button
var entry_background: Texture2D

func _ready() -> void:
	add_to_group("memory_space")
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600,900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var packed: PackedScene = load(str(definition.model))
	if packed == null:
		push_error("Memory model missing: "+str(definition.model))
		queue_free()
		return
	var room := packed.instantiate()
	world.add_child(room)
	_add_collisions(room)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("25353d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a8bac6")
	settings.ambient_light_energy = 0.20
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	world.add_child(environment)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0,2.3,0)
	lamp.light_color = Color("ffd6a0")
	lamp.light_energy = 0.62
	lamp.omni_range = 8
	lamp.shadow_enabled = true
	world.add_child(lamp)
	var window := OmniLight3D.new()
	window.position = Vector3(-2,2,-2.9)
	window.light_color = Color("96bde0")
	window.light_energy = 0.28
	window.omni_range = 5
	world.add_child(window)
	paper = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1,.7142857)
	paper.mesh = mesh
	paper.position = Vector3(-0.4,2.05,-3.34)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(str(definition.paper))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.material_override = mat
	world.add_child(paper)
	camera = Camera3D.new()
	camera.fov = 60
	camera.near = 0.015
	world.add_child(camera)
	camera.position = paper.position+Vector3(0,0,0.4871393)
	camera.current = true
	body = CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .22
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = .8
	body.add_child(shape)
	world.add_child(body)
	body.position = Vector3(0,.08,2.7)
	sound = AudioStreamPlayer.new()
	sound.bus = "Music"
	sound.stream = load(str(definition.audio))
	sound.volume_db = -7
	add_child(sound)
	sound.finished.connect(func() -> void: if not exit_started: sound.play())
	sound.play()
	var desk: TextureRect
	if entry_background:
		desk = TextureRect.new()
		desk.texture = entry_background
		desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		desk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(desk)
	intro_paper = TextureRect.new()
	intro_paper.texture = mat.albedo_texture
	intro_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intro_paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	intro_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(intro_paper)
	intro_paper.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	intro_paper.position = entry_rect.position
	intro_paper.size = entry_rect.size
	var unfold := create_tween().set_parallel(true)
	unfold.tween_property(intro_paper,"position",Vector2.ZERO,.7).set_trans(Tween.TRANS_SINE)
	unfold.tween_property(intro_paper,"size",size,.7).set_trans(Tween.TRANS_SINE)
	status = Label.new()
	status.position = Vector2(44,34)
	status.text = LocalizationSystem.text(str(definition.title))
	status.add_theme_font_size_override("font_size",26)
	status.add_theme_color_override("font_color",Color("fff9eb"))
	add_child(status)
	caption = Label.new()
	caption.position = Vector2(250,730)
	caption.size = Vector2(1100,130)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size",24)
	caption.add_theme_color_override("font_color",Color("fff9eb"))
	caption.add_theme_color_override("font_shadow_color",Color("132126"))
	caption.add_theme_constant_override("shadow_offset_y",2)
	add_child(caption)
	close = preload("res://scripts/ui/components/solmere_button.gd").new()
	close.variant="camera"
	close.position = Vector2(1350,35)
	close.size = Vector2(190,44)
	close.text = LocalizationSystem.text("收起记忆"); close.tooltip_text=SettingsSystem.binding_text("ui_cancel")
	close.disabled = true
	close.pressed.connect(_leave)
	add_child(close)
	objects = preload("res://scripts/meta/memory_objects.gd").new()
	add_child(objects)
	objects.setup(self,room)
	await get_tree().create_timer(.8 if SettingsSystem.reduced_motion() else 2.1).timeout
	if exit_started: return
	if is_instance_valid(desk): desk.queue_free()
	intro_paper.hide()
	transition_tween = create_tween()
	transition_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transition_tween.tween_property(camera,"position",Vector3(0,1.65,2.7),.25 if SettingsSystem.reduced_motion() else 3.0)
	await transition_tween.finished
	if exit_started: return
	ready_to_walk = true
	close.disabled = false
	status.text = LocalizationSystem.text(str(definition.title)+"   ·   "+SettingsSystem.binding_text("interact")+" 看物件 · "+SettingsSystem.binding_text("ui_cancel")+" 返回")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _add_collisions(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var title := str(mesh_node.name)
		if title.begins_with("V2_sideboard") or title.begins_with("V2_counter"):
			mesh_node.create_trimesh_collision()
		if title.begins_with("Night_window"):
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color("809aab") if str(definition.id) in ["A1","A4","A7","A0","B0"] else Color("20364e")
			glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh_node.material_override = glass
		if title.begins_with("Memory_paper_support"):
			mesh_node.global_position = Vector3(-0.4,2.05,-3.365)
		if title.begins_with("Floor_collision") or title.begins_with("Back_wall") or title.begins_with("Left_wall") or title.begins_with("Right_wall") or title.begins_with("Front_wall") or title.begins_with("Table_oak_top") or title.begins_with("Bed_frame") or title.begins_with("Kitchen_cabinet") or title.begins_with("Fridge") or title.begins_with("Sofa_base"):
			mesh_node.create_trimesh_collision()
	for child in node.get_children(): _add_collisions(child)

func _physics_process(delta: float) -> void:
	if not ready_to_walk or exit_started: return
	objects.update_target()
	if is_instance_valid(objects.reading): return
	elapsed += delta
	var input := Vector2.ZERO
	input.x=Input.get_axis("move_left","move_right")
	input.y=Input.get_axis("move_forward","move_backward")
	var direction := Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.y).normalized()
	body.velocity.x = direction.x*1.8
	body.velocity.z = direction.z*1.8
	body.velocity.y -= 12*delta
	body.move_and_slide()
	camera.position = body.position+Vector3(0,1.57,0)
	camera.rotation = Vector3(pitch,yaw,0)
	if elapsed > 9: caption.text = ""
	status.modulate.a=clampf(7-elapsed,0,1)

func _input(event: InputEvent) -> void:
	if exit_started: return
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(objects) and is_instance_valid(objects.reading): objects.close_paper()
		else: _leave()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and ready_to_walk and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x*.0022
		pitch = clampf(pitch-event.relative.y*.0022,-1.35,1.35)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and ready_to_walk:
		if not is_instance_valid(objects.reading): objects.interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_map") and ready_to_walk and not is_instance_valid(objects.reading):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _leave() -> void:
	if exit_started or not ready_to_walk: return
	var snapshot := GameState.to_save_data().duplicate(true)
	exit_started = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if transition_tween: transition_tween.kill()
	var seen: Array = GameState.shared_state.get("memory_visits",[])
	if not seen.has(str(definition.id)): seen.append(str(definition.id))
	GameState.shared_state["memory_visits"] = seen
	if not objects.examined.is_empty():
		var material_id := "memory_"+str(definition.id)
		if not ResidencySystem.state().materials.has(material_id):
			ResidencySystem._add(material_id,"work","房间里记住的片刻",{"source":"memory:"+str(definition.id),"related_npc":"maya","examined":objects.examined.duplicate()})
			GameState.spend_time(5)
		CoreLoopSystem.participated(material_id)
		CoreLoopSystem.memory_return(material_id)
	if not SaveManager.save_or_report("房间记忆保存失败"):
		GameState.load_save_data(snapshot); exit_started=false; caption.text="还没能保存，请再试一次收起记忆。"; return
	queue_free()

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
