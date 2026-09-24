extends SceneTree
## Real native controls, local audio and persisted feedback; isolated save only.
var checks := 0
var failures := 0
var gs
var guide
var shell
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
	else: print("PASS ",message)
func settle() -> void:
	await process_frame
	await process_frame
func capture(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.runtime/pocket-captures")
	root.get_texture().get_image().save_png("res://.runtime/pocket-captures/"+tag+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.gui_disable_input=true
	gs=root.get_node("GameState"); guide=root.get_node("GuidanceSystem")
	root.get_node("ChapterSystem").start_new_game()
	gs.current_location="print_shop"; gs.current_minute=660; gs.shared_state.map_arrival="print_shop"
	change_scene_to_file("res://scenes/town_day.tscn"); await create_timer(.3).timeout
	shell=current_scene.get_node("GameplayShell")
	check(shell.pocket_objects.size()==6,"Six real object buttons are mounted, without duplicate old HUD")
	var stage=current_scene.street
	var cabinet: Array=stage.hotspots.filter(func(h):return h.kind=="public_traces")
	check(cabinet.is_empty(),"Removed street cabinet leaves no invisible interaction")
	check(not stage.world_labels.has("public_cabinet"),"No permanent cabinet label can cover a resident")
	await capture("01-street-and-badges")
	for mode in ["notebook","dossier","bag","map"]:
		shell.get_node("Pocket_"+mode).pressed.emit(); await settle()
		check(is_instance_valid(shell.overlay) and shell.overlay.mode==mode,"Badge opens real "+mode)
		check(shell.pocket_objects.all(func(b):return not b.visible),"Only one navigation layer while "+mode+" is open")
		shell.overlay.close(); await settle()
		check(not is_instance_valid(shell.overlay),"Close returns to exploration from "+mode)
	check(shell.get_node("Pocket_camera").disabled==not root.get_node("FilmSystem").camera_available(false),"Camera badge reflects actual camera ownership")
	var messages: Array=[]
	gs.message_posted.connect(func(message: String): messages.append(message))
	for i in 8: shell._process(.02)
	check(messages.is_empty(),"Passive camera ownership checks never flood feedback")
	var film=root.get_node("FilmSystem")
	gs.current_location="cafe"; gs.current_minute=660
	film.notice_camera(); check(film.acquire_camera(false).ok,"Camera is acquired through the actual shop exchange")
	shell.get_node("Pocket_camera").pressed.emit(); await settle()
	var camera=shell.tool
	check(is_instance_valid(camera),"Owned camera opens from the same badge")
	camera.finder_layer.get_node("OpenGallery").pressed.emit()
	await settle(); await settle()
	check(not is_instance_valid(shell.tool) and is_instance_valid(shell.overlay) and shell.overlay.mode=="gallery","Camera hands off to the actual gallery after it closes")
	if not is_instance_valid(shell.overlay): quit(1); return
	shell.overlay.close(); await settle()
	shell.get_node("Pocket_recorder").pressed.emit(); await settle()
	var recorder=shell.tool
	check(is_instance_valid(recorder) and recorder.recorder is FieldRecorder,"Recorder uses the production capture service")
	check(shell.blocks_walking(),"Expanded recorder keeps knob navigation from moving the player")
	var knob=recorder.find_child("RecordingGain",true,false)
	knob.value=1.45
	check(is_equal_approx(recorder.recorder.input_gain,1.45),"Physical gain control changes actual recording input")
	recorder._toggle_compact(); check(not shell.blocks_walking(),"Folded recorder permits walking")
	recorder._toggle_compact()
	recorder.toggle_recording()
	if DisplayServer.get_name()!="headless":
		check(recorder.recorder.capturing,"Recorder captures real game audio")
		await create_timer(2.3).timeout
		recorder.mark_recording(); recorder.toggle_recording(); await settle()
		check(recorder.saved and recorder.pending_wav==null and recorder.playback.stream.get_length()>1,"Stop saves real playable WAV")
		check(not recorder.play_button.disabled and recorder.marks.size()==1,"Saved sound exposes actual playback and marker")
		recorder._play_last(); check(recorder.playback.playing,"Playback plays the recorded WAV")
		recorder._play_last(); check(not recorder.playback.playing,"Playback can stop")
	await capture("02-recorder")
	recorder._open_library(); await settle(); await settle()
	check(not is_instance_valid(shell.tool) and is_instance_valid(shell.overlay) and shell.overlay.mode=="sound_library","Recorder library button closes capture and opens real collection")
	if not is_instance_valid(shell.overlay): quit(1); return
	shell.overlay.close(); await settle()
	shell.open_tool("recorder"); await settle()
	check(is_equal_approx(shell.tool.recorder.input_gain,1.45),"Gain survives closing and reopening recorder")
	shell.tool.finish_for_exit(); await settle()
	var save=root.get_node("SaveManager")
	check(save.save_game() and save.load_game(),"UI state passes a save/load roundtrip")
	check(is_equal_approx(float(gs.artifacts.recorder_gain),1.45),"Recording gain is saved with the active role")
	guide.refresh(); guide.feedback_queue.clear()
	root.get_node("ResidencySystem")._add("test_real_response","note","居民留下的回应",{"source":"resident_reply","text":"谢谢你带来今天的海边声音。","source_material":"test_sound"})
	guide.refresh(); guide.feedback_age=1
	var toast=shell.get_node("GuidanceToast"); toast.current={}; toast._process(.2)
	check(toast.current.get("target",{}).get("material_id","")=="test_real_response","Reply notification points at the actual material ID")
	await capture("03-real-reply-notice")
	toast.card.pressed.emit(); await settle()
	check(is_instance_valid(shell.overlay) and is_instance_valid(shell.overlay.detail),"Clicking reply opens its real saved text")
	shell.overlay.close(); await settle()
	var recipes=load("res://scripts/core/recipe_book.gd")
	var recipe: Dictionary=recipes.originals()[0].duplicate(true); recipe.id="test_pocket_recipe"; recipe.author="A"; recipe.title="A 留下的菜谱"
	check(recipes.save_recipe(recipe,true).ok,"A shares a genuine recipe entry")
	check(not recipes.appreciate(recipe.id).ok,"Recipe owner cannot add a self-like")
	gs.switch_to_role("B",2,true)
	check(recipes.appreciate(recipe.id).ok,"B can actually appreciate A's shared recipe")
	check(not recipes.appreciate(recipe.id).ok and recipes.appreciations(recipe.id).size()==1,"Repeated appreciation does not invent additional people")
	check(save.save_game() and save.load_game(),"Recipe appreciation survives save and reload")
	gs.switch_to_role("A",3,true); guide.refresh(); guide.feedback_age=1
	toast.current={}; toast._process(.2)
	check(toast.current.get("target",{}).get("recipe_id","")==recipe.id,"Owner receives notification for the actual appreciated recipe")
	toast.card.pressed.emit(); await settle()
	var books=get_nodes_in_group("recipe_book")
	check(books.size()==1 and books[0].chosen.id==recipe.id,"Appreciation opens the corresponding shared recipe")
	if not books.is_empty(): books[0].queue_free(); await settle()
	# Exercise both prepared vegetables and the uncut tin.
	gs.switch_to_role("B",2,true); gs.current_minute=660; gs.current_location="night_market"
	var router=root.get_node("SceneRouter"); router.active_space_id="restaurant"
	var economy=root.get_node("EconomySystem")
	check(economy.accept_procurement().ok,"Cooking begins with the actual restaurant order")
	gs.current_location="produce_stall"; router.active_space_id=""
	for id in ["tomato","herbs","sea_beans"]:
		check(economy.set_cart_quantity("produce_stall",id,2).ok,"Actual shopping basket contains "+id)
	check(economy.purchase_cart("produce_stall").ok,"Cooking ingredients are purchased with real receipts")
	gs.current_location="night_market"; router.active_space_id="restaurant"
	check(economy.deliver_procurement().ok,"Actual order delivered before cooking")
	check(root.get_node("GameplayModuleSystem").begin_session("cooking","street:night_market"),"Actual cooking session starts")
	change_scene_to_file("res://scenes/native_module_game.tscn"); await settle()
	var kitchen=current_scene
	for id in ["tomato","herbs","sea_beans"]: kitchen.token_buttons[id].pressed.emit()
	check(kitchen.prep_board.items.size()==3,"Selected ingredients appear on the real cutting board")
	preload("res://tests/integration/cooking_walkthrough.gd").prepare_and_cook(kitchen,1)
	check(kitchen.stage_ready,"Alternative ingredient preparation remains a complete cooking path")
	kitchen.value_slider.value=.59
	check(kitchen.added_tokens.size()==3 and kitchen.prep_board.items.is_empty(),"Adjusting heat does not teleport food out of the pan")
	# Reset the ingredient selection to exercise the alternative preparation path.
	kitchen.cooking_reset_button.pressed.emit(); kitchen.primary_button.pressed.emit()
	for i in 3:
		kitchen.prep_option_buttons[0].pressed.emit()
		while not kitchen.prep_board.target_id.is_empty(): kitchen.prep_board.pressed.emit()
	check(kitchen._interaction_record().mechanic.cut_ingredients.size()==2,"Actual cuts record tomato and herbs; the tin is never cut")
	preload("res://tests/integration/cooking_walkthrough.gd").finish_prepared(kitchen)
	check(kitchen.stage_ready,"Prepared dish uses the same real heat mechanic")
	await capture("04-cooking-table")
	kitchen._complete_choice("careful_menu")
	check(kitchen.completed and int(gs.inventory.tomato)==1,"Serving consumes one actual ingredient set")
	if not kitchen.completed: print(kitchen.status_label.text); quit(1); return
	check(save.save_game() and save.load_game(),"Cooking outcome persists")
	var result: Dictionary=root.get_node("GameplayModuleSystem").latest_outcome("cooking")
	check(result.interaction.mechanic.cut_ingredients.size()==2,"Preparation survives loading the saved outcome")
	print("POCKET_OBJECTS: ",checks," checks / ",failures," failures")
	quit(failures)
