extends SceneTree
## Opens real town conversations without touching the player's normal save.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		push_error("Dialogue preview requires an isolated save"); quit(1); return
	root.get_node("ChapterSystem").start_new_game("A")
	var state = root.get_node("GameState")
	var mode := "counter"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--dialogue-preview="): mode=argument.get_slice("=",1)
	state.current_location="produce_stall" if mode in ["cici","argument"] else "produce_stall"
	state.current_minute=600
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.6).timeout
	if mode=="room":
		root.get_node("SceneRouter").active_space_id="restaurant"
		change_scene_to_file("res://scenes/interactive_space.tscn")
		await create_timer(.5).timeout
		current_scene.stage.player_x=800
		current_scene._start_conversation("shi_yongqi")
		DisplayServer.window_set_title("Solmere · 室内对话（试玩）")
		return
	current_scene.street.player_x=current_scene._world_x(current_scene.street_order.find(state.current_location),900)
	current_scene._on_walk(current_scene.street.player_x)
	current_scene._refresh()
	for item in current_scene.street.hotspots:
		if str(item.get("id",""))=="beetman":
			current_scene.street.player_x=float(item.x)-110.0
			current_scene.street.move_player(0,0)
	await process_frame
	await process_frame
	if mode=="argument": current_scene._start_market_encounter()
	else: current_scene._talk_nearby("wu_wu" if mode=="cici" else "beetman")
	DisplayServer.window_set_title("Solmere · 清晰对话（最新试玩）")
