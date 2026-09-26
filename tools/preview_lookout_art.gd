extends SceneTree
## Preview the supplied lookout art with an isolated save and real town UI.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game("A")
	var state := root.get_node("GameState")
	state.current_location = "park"
	state.current_minute = 1260 if OS.get_cmdline_user_args().has("--night") else 660
	state.shared_state.erase("street_positions")
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.5).timeout
	var town = current_scene
	town.street.player_x = 4200
	town.street.move_player(0,0)
	town._refresh()
	DisplayServer.window_set_title("Solmere · 观景台素材预览")
	if not OS.get_cmdline_user_args().has("--capture"): return
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var folder := "res://.runtime/lookout-art"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.get_texture().get_image().save_png(folder + ("/night.png" if state.current_minute >= 1260 else "/day.png"))
	if state.current_minute >= 1260:
		var module: Dictionary = town.street.hotspots.filter(func(h): return h.kind == "module" and h.id == "contemplation")[0]
		var expected: float = town._place_center() + preload("res://scripts/ui/lookout_art.gd").telescope_offset()
		assert(is_equal_approx(float(module.x),expected), "Telescope interaction must match supplied art")
		town.street.player_x = module.x
		town.street.move_player(0,0)
		assert(not town.street.nearest_of(["module"]).is_empty(), "Telescope must remain reachable")
	print("LOOKOUT ART PREVIEW PASS")
	quit()
