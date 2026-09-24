extends SceneTree
## Visible source / packed-runtime review, isolated from the player's save.
func _initialize(): call_deferred("run")
func run():
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var gs=root.get_node("GameState")
	root.get_node("ChapterSystem").start_new_game(); gs.current_location="cafe"; gs.current_minute=1080
	root.get_node("WorldAtmosphere").reset_to_clock()
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.4).timeout
	var town=current_scene
	town.street.player_x=town._place_center()-120; town.street.move_player(0,0); town.street.enabled=false
	var freeze := Control.new(); freeze.add_to_group("meta_modal"); town.add_child(freeze)
	DisplayServer.window_set_title("Solmere · 天色连续过渡实测")
	var folder := ProjectSettings.globalize_path("res://.runtime/atmosphere-review/frames")
	DirAccess.make_dir_recursive_absolute(folder)
	await create_timer(25.0).timeout
	gs.spend_time(120)
	for i in 81:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/%03d.png"%i)
		await create_timer(.4).timeout
	DisplayServer.window_set_title("Solmere · 天色连续过渡实测 · 已到夜晚")
