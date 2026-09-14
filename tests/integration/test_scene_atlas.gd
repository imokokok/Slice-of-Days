extends SceneTree
var Atlas
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	Atlas = load("res://scripts/ui/scene_atlas.gd")
	root.get_node("ChapterSystem").start_new_game()
	check(Atlas.catalog().street.size() == 15 and Atlas.catalog().rooms.size() == 9,"Keep the authored fifteen locations and nine rooms")
	for row in Atlas.catalog().pages: check(ResourceLoader.exists(str(row.image)),"Atlas image imported: " + str(row.page))
	check(Atlas.phase(540) == 0 and Atlas.phase(1050) == 1 and Atlas.phase(1200) == 2,"Day, dusk and night use separate authored plates")
	state.current_location = "town_entrance"
	state.current_minute = 700
	# Upgrade old coordinates proportionally without moving players to another block.
	state.shared_state.street_layout_version = 4
	state.shared_state.street_positions = {"A_1_public_west":950.0}
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.6).timeout
	check(state.current_location == "night_market","Old save keeps its correct street location")
	check(current_scene.street.world_width == 8000,"Main street spans five screens")
	var door: Dictionary = {}
	for item in current_scene.street.hotspots:
		if item.kind == "door": door = item
	check(not door.is_empty() and is_equal_approx(float(door.get("x",0)), current_scene._world_x(3,1120)),"Restaurant interaction aligns with its pictured door on the main street")
	var street = current_scene.street
	street.player_x = 1595.0
	street.move_player(0, 0)
	var camera_before: float = street.camera_x
	street.move_player(1, 0.1)
	check(street.player_x > 1600 and absf(street.camera_x - camera_before) < 30, "Camera follows smoothly across a scene boundary")
	state.current_minute = 1259
	check(Atlas.street("park").pages[0] == 70,"Closed lookout uses its exterior gate")
	state.current_minute = 1260
	check(Atlas.street("park").pages[0] == 66,"After nine, the lookout opens onto the sea terrace")
	if OS.get_cmdline_user_args().has("--screenshots"):
		for shot in [["town_entrance",540,""],["night_market",1050,"restaurant"],["record_store",1140,""],["park",1200,""]]:
			state.current_location = shot[0]
			state.current_minute = shot[1]
			state.shared_state.map_arrival = shot[0]
			var router = root.get_node("SceneRouter")
			router.active_space_id = shot[2]
			if str(shot[2]).is_empty(): router.town_day()
			else: router.interactive_space()
			await create_timer(0.8).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/Users/22416/Documents/Codex/2026-09-13/github-slice-of-days/work/atlas-review/game-"+str(shot[0])+".png")
	print("SCENE ATLAS PASS" if failures == 0 else "SCENE ATLAS FAIL")
	quit(failures)
