extends SceneTree

const CATALOG = preload("res://scripts/ui/components/kitchen_art_catalog.gd")
const INGREDIENT_ART = preload("res://scripts/ui/components/cooking_ingredients.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1600,900)
	var entries := CATALOG.tokens()
	var cooking_rules=load("res://scripts/core/cooking_mechanics.gd")
	check(entries.size()==31,"Every supplied ingredient should have cooking data")
	check(CATALOG.asset_paths().size()==32,"Both prepared and unprepared artist assets should be registered")
	for path in CATALOG.asset_paths():
		check(ResourceLoader.exists(path),"Missing supplied kitchen art: "+path)
		var texture := load(path) as Texture2D
		check(texture!=null,"Supplied kitchen art did not import: "+path)
		if texture:
			check(maxi(texture.get_width(),texture.get_height())<=640,"Kitchen cutout was not trimmed to a runtime-sized asset: "+path)
	var frozen := INGREDIENT_ART.texture("ice_block",false)
	var softened := INGREDIENT_ART.texture("ice_block",true)
	check(frozen!=null and softened!=null and frozen.resource_path!=softened.resource_path,"The ice block should use both supplied preparation states")
	for id in ["mushrooms","potato","carrot","beet","eggplant","zucchini","lemon","bread","cheese","tomato","herbs","sardine","sea_bream","bell_pepper_yellow","bell_pepper_purple","bell_pepper_orange","bell_pepper_dark","bell_pepper_bronze","bell_pepper_white","bell_pepper_red","bell_pepper_green"]:
		var raw_texture := INGREDIENT_ART.texture(id,false)
		var prepared_texture := INGREDIENT_ART.texture(id,true)
		check(raw_texture!=null and prepared_texture!=null and raw_texture!=prepared_texture,"Prepared cooking art should differ from the raw ingredient: "+id)

	var state=root.get_node("GameState")
	var gameplay=root.get_node("GameplayModuleSystem")
	state.begin_new_game("B"); state.current_location="night_market"; state.current_minute=600
	check(gameplay.begin_session("cooking","kitchen_supplied_art_test"),"Kitchen art fixture should begin")
	var scene=load("res://scenes/native_module_game.tscn").instantiate()
	root.add_child(scene); await process_frame
	check(scene.interaction.tokens.size()==40,"The original pantry and every supplied ingredient should share one cooking list")
	for value in scene.interaction.tokens:
		var token: Dictionary=value
		var options: Array=token.get("prep_options",[])
		check(options.size()==2,"Every cooking ingredient should offer two preparations: "+str(token.get("id","")))
		if options.size()!=2: continue
		var first: Dictionary=cooking_rules.prepared_token(token,str(options[0].get("id","")))
		var second: Dictionary=cooking_rules.prepared_token(token,str(options[1].get("id","")))
		check(first.heat_window!=second.heat_window or not is_equal_approx(float(first.heat_drop),float(second.heat_drop)),"Preparation should change how the ingredient responds in the pan: "+str(token.get("id","")))
	check(scene.ingredient_pages.size()==7,"The expanded pantry should be split into readable shelves")
	for page_index in scene.ingredient_pages.size():
		scene.ingredient_page=page_index; scene._refresh_ingredient_shelf()
		var visible: Array[String]=scene._visible_ingredient_ids()
		check(not visible.is_empty() and visible.size()<=8,"Each shelf page should expose one readable row")
		for id in visible:
			check(scene.token_buttons[id].visible,"The current shelf should reveal its art button: "+id)
			check(scene.token_buttons[id].art.texture==INGREDIENT_ART.texture(id),"Shelf art should use the same ingredient texture as the board and pan: "+id)
		if OS.get_cmdline_user_args().has("--screenshots"):
			await process_frame
			var viewport_texture := root.get_texture()
			if viewport_texture:
				var folder := ProjectSettings.globalize_path("res://.runtime/kitchen-art-pages")
				DirAccess.make_dir_recursive_absolute(folder)
				viewport_texture.get_image().save_png(folder+"/shelf-%02d.png"%page_index)
	for id in ["cooking_oil","carrot","alarm_clock"]:
		check(root.get_node("EconomySystem").ingredient_available(id),"Supplied kitchen art should be selectable in the pantry: "+id)
		scene._toggle_token(id)
	check(scene.selected_tokens==["cooking_oil","carrot","alarm_clock"],"Selections from different shelves should stay together")
	check(scene.token_buttons["cooking_oil"].order_badge==1 and scene.token_buttons["carrot"].order_badge==2 and scene.token_buttons["alarm_clock"].order_badge==3,"The shelf should show the chosen order on the actual ingredient art")
	scene._perform_primary_action()
	check(scene.cooking_phase=="prep" and scene._visible_ingredient_ids()==scene.selected_tokens,"Preparation should replace browsing pages with the three chosen art buttons")
	check(scene.cooking_prep_detail_label.visible and not scene.cooking_prep_detail_label.text.is_empty(),"Preparation should show an option's effect without requiring hover")
	if OS.get_cmdline_user_args().has("--screenshots"): await _capture("phase-prep")
	# Put a vegetable first to verify the full-to-cut transition itself.
	scene._reset_cooking(); scene.selected_tokens.clear(); scene._update_state()
	for id in ["carrot","cooking_oil","alarm_clock"]: scene._toggle_token(id)
	scene._perform_primary_action(); scene._choose_prep_option(0)
	check(scene.prepared_tokens.is_empty() and scene.prep_board.target_id=="carrot","Choosing a cut should leave the carrot whole on the board")
	for stroke_index in 2:
		scene.prep_board.pressed.emit()
		check(scene.prepared_tokens.is_empty() and not scene.prep_board.cuts.has("carrot"),"Incomplete strokes should keep the vegetable whole")
	scene.prep_board.pressed.emit()
	check(scene.prepared_tokens.has("carrot") and scene.prep_board.cuts.has("carrot"),"The last stroke should reveal the prepared carrot")
	scene._reset_cooking(); scene.selected_tokens.clear(); scene._update_state()
	for id in ["cooking_oil","carrot","alarm_clock"]: scene._toggle_token(id)
	scene._perform_primary_action()
	for step in 3:
		scene._choose_prep_option(step%2)
		while not scene.prep_board.target_id.is_empty(): scene.prep_board.pressed.emit()
	check(scene.cooking_phase=="cook","The supplied art selection should complete ingredient-specific preparation")
	scene._toggle_token("carrot")
	check(scene.cooking_heat_guide.visible and is_equal_approx(scene.cooking_heat_guide.comfortable_low,float(scene._prepared_token("carrot").heat_window[0])),"The heat guide should follow the prepared ingredient at the pan")
	if OS.get_cmdline_user_args().has("--screenshots"): await _capture("phase-prepared")
	for id in scene.selected_tokens:
		var token: Dictionary=scene._prepared_token(id)
		var window: Array=token.get("heat_window",[0.4,0.7])
		scene.value_slider.value=(float(window[0])+float(window[1]))*.5
		scene._toggle_token(id); scene._perform_primary_action()
	check(scene.added_tokens==scene.selected_tokens,"The same supplied art should reach the pan in the chosen order")
	check(scene.illustrated_pot.cooking_phase=="stir" and scene.illustrated_pot.addition_states.size()==3,"The illustrated pot should receive the live cooking states")
	check(scene.cooking_recipe_strip.ingredients==scene.added_tokens,"The live recipe page should illustrate the actual pan order")
	if OS.get_cmdline_user_args().has("--screenshots"): await _capture("phase-pan")
	for _stir in 2: scene._stir("fold")
	scene._perform_primary_action()
	if OS.get_cmdline_user_args().has("--screenshots"): await _capture("phase-taste")
	var expected: String=str(load("res://scripts/core/cooking_mechanics.gd").seasoning_target(scene._selected_token_data()))
	scene._choose_seasoning(expected)
	check(scene.plated_dish.visible and scene.cooking_phase=="plating","Tasting should reveal an ingredient-accurate plating preview")
	scene._preview_plating("share")
	check(scene.plated_dish.plating_mode=="share","Hovering a plating choice should preview its arrangement")
	scene._choose_plating("share")
	check(scene.cooking_phase=="serve" and scene.plated_dish.visible,"The chosen plated dish should remain visible for serving")
	if OS.get_cmdline_user_args().has("--screenshots"): await _capture("phase-plating")
	print("KITCHEN_SUPPLIED_ART_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	gameplay.cancel_session(); scene.queue_free(); await process_frame
	quit(failures)


func _capture(filename: String) -> void:
	await process_frame
	var viewport_texture := root.get_texture()
	if not viewport_texture: return
	var folder := ProjectSettings.globalize_path("res://.runtime/kitchen-art-pages")
	DirAccess.make_dir_recursive_absolute(folder)
	viewport_texture.get_image().save_png(folder+"/"+filename+".png")
