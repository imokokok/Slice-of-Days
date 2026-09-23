extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures+=1;push_error(label)
	else: print("PASS ",label)
func _initialize() -> void:call_deferred("run")
func shot(name_text: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/meta/v2_"+name_text+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):quit(1);return
	root.gui_disable_input=true
	var state=root.get_node("GameState")
	var meta=root.get_node("MetaExperience")
	var router=root.get_node("SceneRouter")
	root.get_node("SettingsSystem").values.reduced_motion=true
	state.begin_new_game("A")
	state.current_location="park"
	state.current_minute=1000
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.6).timeout
	var town=current_scene
	town.set_process(false)
	if state.state_changed.is_connected(town._refresh): state.state_changed.disconnect(town._refresh)
	var stage=town.street
	stage.hotspots.clear()
	stage.enabled=true
	check(get_nodes_in_group("marginalia_layers").is_empty(),"Barrage removed from exploration")
	check(not meta.enabled("marginalia"),"Barrage has no enabled feature toggle")
	stage.enabled=false
	await create_timer(meta.voice_cooldown_remaining()+.1).timeout
	meta.deterministic_test_mode=true
	var panel=load("res://scripts/ui/conversation_panel.gd").new()
	panel.npc="maya"
	town.add_child(panel)
	await create_timer(1.2).timeout
	check(meta.voice_debug.get("reason","")=="已显示","Normal NPC dialogue reaches Inner Voice UI")
	check(meta.voice_label.modulate.a>0,"Thought visibly fades in")
	check(meta.trigger_voice("dialogue").is_empty(),"Voice cooldown respected")
	await shot("dialogue")
	var faculties: Dictionary={}
	for entry in meta.catalog.voices: faculties[str(entry.faculty)]=true
	check(faculties.size()==8,"All eight private voice faculties retain candidates")
	meta.last_voice=-10000
	meta.faculty_times.clear()
	check(meta.trigger_voice("dialogue").is_empty() and meta.voice_debug.blocking_reason=="cooldown","Persisted cooldown resists runtime-field resets")
	panel.queue_free()
	await process_frame
	var definitions: Array=meta.memories.duplicate(true)
	for role in ["A","B"]:
		var definition: Dictionary=meta.memories[0].duplicate(true)
		definition.id=role+"0"
		definition.model="res://art/memories/"+role+"0.glb"
		definitions.append(definition)
	for definition in definitions:
		var view=load("res://scripts/meta/memory_view.gd").new()
		view.definition=definition
		town.add_child(view)
		view._leave()
		check(not view.exit_started,"Entry handoff locked: "+str(definition.id))
		await create_timer(1.35).timeout
		check(view.ready_to_walk,"First person handoff: "+str(definition.id))
		check(view.objects.targets.size()==9,"Nine physical targets: "+str(definition.id))
		var read_item: Dictionary=view.objects.items[0]
		view.set_physics_process(false)
		var read_node: Node3D=view.objects.targets[str(read_item.id)]
		var read_position: Vector3=view.objects._center(read_node)
		view.camera.position=read_position+Vector3(-.65,.63,0)
		view.camera.look_at(read_position+Vector3(0,.04,0))
		await physics_frame
		view.objects.update_target()
		check(str(view.objects.selected.get("id",""))==str(read_item.id),"Camera ray selects the physical paper: "+str(definition.id))
		view.camera.position=read_position+Vector3(-1.5,.63,0)
		view.camera.look_at(read_position)
		view.objects.update_target()
		check(view.objects.selected.is_empty(),"Paper cannot be read from across the room: "+str(definition.id))
		view.set_physics_process(true)
		view.objects.interact(read_item)
		check(is_instance_valid(view.objects.reading) and not view.objects.page_text.text.is_empty(),"Readable paper: "+str(definition.id))
		if definition.id=="A1": await shot("readable")
		view.objects.close_paper()
		for item in view.objects.items:
			if str(item.kind)=="listen":
				view.objects.interact(item)
				check(view.objects.spatial_sound.playing,"Spatial audio: "+str(definition.id))
				break
		for item in view.objects.items:
			if str(item.kind)=="drawer":
				view.objects.interact(item)
				await create_timer(.45).timeout
				check(view.objects.targets[str(item.id)].position.x<-.2,"Drawer moves: "+str(definition.id))
				break
		if definition.id in ["A0","B0","A6","B3","B4"]:
			view.yaw=-.55
			await create_timer(.15).timeout
			await shot(str(definition.id))
		check(view.body.position.y>-.1,"Floor holds player: "+str(definition.id))
		view._leave()
		await process_frame
		check(not is_instance_valid(view),"Exit allowed after handoff: "+str(definition.id))
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(.6).timeout
	var menu=current_scene
	menu._launch_new_game()
	await create_timer(2.5).timeout
	check(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/town_day.tscn","New Game enters playable town without an opening movie")
	await shot("direct_new_game")
	print("V2_RUNTIME ",checks," CHECKS / ",failures," FAILURES")
	quit(1 if failures else 0)
