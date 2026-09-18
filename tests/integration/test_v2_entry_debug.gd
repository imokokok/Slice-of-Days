extends SceneTree
var errors := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: errors+=1;push_error(label)
	else: print("PASS ",label)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):quit(1);return
	root.gui_disable_input=true
	var state=root.get_node("GameState")
	var meta=root.get_node("MetaExperience")
	state.begin_new_game("A")
	state.current_location="residence"
	root.get_node("SceneRouter").active_space_id="home_a"
	root.get_node("SettingsSystem").values.reduced_motion=true
	change_scene_to_file("res://scenes/interactive_space.tscn")
	await create_timer(.4).timeout
	var entry=load("res://scripts/meta/memory_entry.gd").new()
	current_scene.add_child(entry)
	await process_frame
	entry._enter(0)
	check(entry.memory_view.entry_background!=null,"Entry uses the real previous desk image")
	check(entry.memory_view.entry_rect==entry.cards[0].get_global_rect(),"Entry begins at the clicked paper")
	await create_timer(1.3).timeout
	check(entry.memory_view.ready_to_walk,"Physical paper handoff completes")
	entry.memory_view._leave()
	await process_frame
	entry.queue_free()
	await process_frame
	var panel=load("res://scripts/ui/conversation_panel.gd").new()
	panel.npc="maya"
	meta.deterministic_test_mode=true
	await create_timer(meta.voice_cooldown_remaining()+.1).timeout
	current_scene.add_child(panel)
	await create_timer(1.1).timeout
	check(meta.voice_debug.get("reason","")=="已显示","Current normal dialogue still triggers voice")
	var debug=load("res://scripts/meta/runtime_debug.gd").new()
	current_scene.add_child(debug)
	await create_timer(.2).timeout
	check(debug.report.text.contains("faculty_remaining"),"Developer panel shows faculty cooldowns")
	check(debug.size.y<=780,"Developer controls stay inside viewport")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/meta/v2_debug.png")
	print("V2_ENTRY_DEBUG ",errors," failures")
	quit(errors)
