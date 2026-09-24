extends SceneTree
## Records the complete seven-stage kitchen loop through its public controls.
## Run with --isolated-save and Godot's --write-movie option.

func _initialize() -> void:
	call_deferred("run")


var capture_fps := 24


func pause(seconds: float) -> void:
	for frame in maxi(1,roundi(seconds*float(capture_fps))):
		await process_frame
		await RenderingServer.frame_post_draw


func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(2)
		return
	if OS.get_cmdline_user_args().has("--quick-video"): capture_fps=2
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-fps="):
			capture_fps=clampi(int(argument.trim_prefix("--capture-fps=")),2,24)
	root.size=Vector2i(1600,900)
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.get_node("ChapterSystem").start_new_game()
	var state: Node=root.get_node("GameState")
	state.switch_to_role("B",2,true)
	state.current_location="night_market"
	state.current_minute=660
	state.money=500
	state.inventory={"lemon":2,"bread":2,"cheese":2}
	state.commit_active_role_state()
	if not root.get_node("GameplayModuleSystem").begin_session("cooking","kitchen_video"):
		push_error("Kitchen video could not start a cooking session")
		quit(3)
		return
	var kitchen: Control=load("res://scenes/native_module_game.tscn").instantiate()
	root.add_child(kitchen)
	await process_frame
	await pause(2.2)
	for id in ["lemon","bread","cheese"]:
		kitchen.token_buttons[id].pressed.emit()
		await pause(0.8)
	await pause(1.3)
	kitchen.primary_button.pressed.emit()
	await pause(1.4)
	for option in [0,1,1]:
		kitchen.prep_option_buttons[option].pressed.emit()
		await pause(1.4)
	await pause(1.3)
	for id in ["bread","cheese","lemon"]:
		var token: Dictionary=kitchen._prepared_token(id)
		var window: Array=token.get("heat_window",[0.4,0.7])
		kitchen.value_slider.value=(float(window[0])+float(window[1]))*0.5
		await pause(0.8)
		kitchen.token_buttons[id].pressed.emit()
		await pause(0.7)
		kitchen.illustrated_pot.pressed.emit()
		await pause(1.8)
	kitchen.value_slider.value=0.58
	kitchen.stir_buttons.gentle.pressed.emit()
	await pause(1.6)
	kitchen.stir_buttons.fold.pressed.emit()
	await pause(1.6)
	kitchen.primary_button.pressed.emit()
	await pause(2.0)
	var seasoning: String=preload("res://scripts/core/cooking_mechanics.gd").seasoning_target(kitchen._selected_token_data())
	kitchen.seasoning_buttons[seasoning].pressed.emit()
	await pause(1.6)
	kitchen.plating_buttons.share.pressed.emit()
	await pause(3.0)
	kitchen.choice_buttons.improvise.pressed.emit()
	await pause(2.0)
	var sheets: Array=get_nodes_in_group("native_confirmation")
	if sheets.is_empty():
		push_error("Kitchen video did not reach serving confirmation")
		quit(4)
		return
	sheets.back().accepted.emit()
	await pause(4.0)
	if not kitchen.completed:
		push_error("Kitchen video failed to serve its dish")
		quit(5)
		return
	kitchen._open_recipe_book()
	await pause(1.0)
	var books: Array=get_nodes_in_group("recipe_book")
	if not books.is_empty():
		books.back()._switch("shared")
		await pause(3.0)
	if OS.get_cmdline_user_args().has("--quick-video"):
		root.get_texture().get_image().save_png("/private/tmp/solmere-kitchen-final.png")
	print("KITCHEN_WALKTHROUGH_COMPLETE")
	quit()
