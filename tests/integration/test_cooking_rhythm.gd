extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://.runtime/cooking-feedback-pages")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder+"/"+name+".png")


func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var state=root.get_node("GameState")
	var gameplay=root.get_node("GameplayModuleSystem")
	var rules=load("res://scripts/core/cooking_mechanics.gd")
	state.begin_new_game("B"); state.current_location="night_market"; state.current_minute=600
	check(gameplay.begin_session("cooking","cooking_rhythm_test"),"Cooking session should begin")
	var scene=load("res://scenes/native_module_game.tscn").instantiate(); root.add_child(scene); await process_frame
	var tomato: Dictionary=scene._token_data("tomato")
	var juicy: Dictionary=rules.prepared_token(tomato,"keep_juice")
	var drained: Dictionary=rules.prepared_token(tomato,"drain")
	check(float(drained.heat_drop)<float(juicy.heat_drop) and float(drained.heat_window[0])>float(juicy.heat_window[0]),"Draining a tomato should preserve more pan heat and change its comfortable range")
	check(str(rules.preparation_action("small","bread").verb)=="撕开" and int(rules.preparation_action("small","bread").strokes)==2,"Tearing bread should use a distinct two-step action")
	check(str(rules.preparation_action("squeeze","lemon").verb)=="挤压" and str(rules.preparation_action("bells","alarm_clock").verb)=="拆开","Squeezing citrus and removing clock bells should have distinct actions")
	check(get_nodes_in_group("recipe_book").is_empty(),"The recipe book should stay closed until requested")
	scene._open_recipe_book()
	var book: Node=get_nodes_in_group("recipe_book").back()
	check(book.visible,"The recipe button should open a visible recipe overlay")
	var house_recipe: Dictionary=load("res://scripts/core/recipe_book.gd").originals()[0]
	book.emit_signal("follow_recipe",house_recipe)
	check(scene.active_recipe.get("title","")==house_recipe.title and scene.instruction_label.text.contains(str(house_recipe.title)),"Following a recipe should put its short hint above the workbench")
	check(scene.get_node_or_null("KitchenTopHint")!=null and scene.get_node_or_null("KitchenToolTray")!=null,"The cooking hint and tool area should replace the permanently open side recipe")
	book.queue_free(); scene._reset_cooking(); scene.selected_tokens.clear(); scene._update_state(); await process_frame
	for token_id in ["lemon","bread","cheese"]: scene._toggle_token(token_id)
	var inventory_before: Dictionary=state.inventory.duplicate(true)
	# A rough first attempt must still reach the table. The game records the
	# improvisation and lets the player restart before any real stock is spent.
	scene._perform_primary_action()
	for _prep in 3:
		scene._choose_prep_option(1)
		while not scene.prep_board.target_id.is_empty(): scene.prep_board.pressed.emit()
	for token_id in scene.selected_tokens:
		scene.value_slider.value=0.0
		scene._toggle_token(token_id)
		scene._perform_primary_action()
	for style in ["gentle","fold"]:
		scene.value_slider.value=1.0
		scene._stir(style)
	scene._perform_primary_action()
	var rough_expected: String=rules.seasoning_target(scene._selected_token_data())
	var rough_choice := "brighten" if rough_expected!="brighten" else "salt"
	scene._choose_seasoning(rough_choice)
	scene._finish_seasoning()
	scene._choose_plating("generous")
	check(scene.stage_ready and str(scene._interaction_record().mechanic.grade.id)=="improvised","Mistakes should change the record without destroying the dish")
	var rough_reply: String=rules.service_response(scene._interaction_record())
	check((rough_reply.contains("锅温") or rough_reply.contains("过火") or rough_reply.contains("略生")) and rough_reply.contains("端上桌"),"A rough dish should receive a response to its real heat and plating")
	scene._reset_cooking()
	check(scene.cooking_phase=="select" and scene.selected_tokens.size()==3,"Restarting should preserve the chosen ingredients for easy revision")
	check(state.inventory==inventory_before,"Restarting before serving should consume no inventory")

	# A second, attentive attempt follows each ingredient's sensory cue.
	scene._perform_primary_action()
	check(scene.cooking_phase=="prep" and scene.prepared_tokens.is_empty(),"Choosing ingredients should not silently prepare them")
	for option in [0,1,0]:
		scene._choose_prep_option(option)
		while not scene.prep_board.target_id.is_empty(): scene.prep_board.pressed.emit()
	await capture("01-prepared")
	check(scene.prepared_tokens==["lemon","bread","cheese"],"Preparation order should be recorded")
	check(str(scene.prep_board.cuts.get("bread",""))=="small","The board should retain the chosen bread cut for drawing")
	var chosen_cook_order := ["cheese","bread","lemon"]
	for token_id in chosen_cook_order:
		var token: Dictionary=scene._prepared_token(token_id)
		var window: Array=token.get("heat_window",[.42,.70])
		scene.value_slider.value=(float(window[0])+float(window[1]))*.5
		scene._toggle_token(token_id)
		scene._perform_primary_action()
	check(scene.added_tokens==chosen_cook_order,"The player should be able to revise the pan order after preparation")
	await capture("02-pan")
	check(str(scene.illustrated_pot.prepared.get("bread",""))=="small","The pan should display the chosen bread cut")
	for addition in scene.cooking_additions:
		var effective: Dictionary=scene._prepared_token(str(addition.get("id","")))
		check(addition.heat_window==effective.heat_window and is_equal_approx(float(addition.heat)-float(addition.heat_after),float(effective.heat_drop)),"The pan result should use the selected preparation's heat behavior")
	check(scene.token_buttons["cheese"].order_badge==1 and scene.token_buttons["bread"].order_badge==2 and scene.token_buttons["lemon"].order_badge==3,"Ingredient badges should switch to the real pan order")
	for style in ["gentle","fold"]:
		scene.value_slider.value=.58
		scene._stir(style)
	var pot: Button=scene.illustrated_pot
	var left: Vector2=pot._food_slot(0,3)
	var right: Vector2=pot._food_slot(1,3)
	var near: Vector2=pot._food_slot(2,3)
	check(left.distance_to(right)>65.0 and left.distance_to(near)>45.0 and near.y-left.y>35.0,"Three ingredients should form a compact staggered arrangement inside the pan")
	check(pot.stir_count==2 and pot.stir_style=="fold","The pan should preserve the chosen stirring movement")
	var bread_after_stir: Dictionary=scene.cooking_additions[1]
	var bread_target_tint: Color=rules.food_tint("bread",str(bread_after_stir.state),float(bread_after_stir.cook_progress),float(bread_after_stir.browning),float(scene.value_slider.value))
	var bread_start_tint: Color=pot.stir_from_tints["bread"]
	check(bread_start_tint.g-bread_target_tint.g>0.05,"The stirring motion should visibly transition food from its previous color to its cooked color")
	check(float(scene.cooking_additions[0].get("cook_progress",0.0))>0.04,"Stirring should advance the food's visible cooking state")
	var gently_cooked: Dictionary=rules.advance_exposure({"cook_progress":0.4,"browning":0.0},0.42,3.0)
	var seared: Dictionary=rules.advance_exposure({"cook_progress":0.4,"browning":0.0},0.94,3.0)
	check(float(seared.browning)>float(gently_cooked.browning),"High heat should brown food faster than gentle heat")
	check(rules.food_tint("carrot","just_right",float(seared.cook_progress),float(seared.browning),0.94)!=rules.food_tint("carrot","just_right",0.0,0.0,0.20),"Cooked food should have a distinct color from the raw ingredient")
	var raw_bread: Color=rules.food_tint("bread","just_right",0.0,0.0,0.58)
	var cooked_bread: Color=rules.food_tint("bread","just_right",0.55,0.0,0.58)
	check(raw_bread.r-cooked_bread.r>0.12 and raw_bread.g-cooked_bread.g>0.17,"Stirred food should visibly deepen in color as it cooks")
	await create_timer(0.85).timeout
	check(pot.stir_progress>=0.99 and pot._food_position(0).distance_to(pot._food_slot(2,3))<1.0,"Food should settle in its new pan position after stirring")
	await capture("02-pan-stirred")
	check(scene.cooking_phase=="stir","Two stirs should make tasting available without forcing it")
	scene._perform_primary_action()
	check(scene.cooking_phase=="taste","The player should decide when to taste")
	await capture("03-taste")
	var before_simmer := float(scene.cooking_additions[0].cook_progress)
	scene._simmer_cooking()
	check(float(scene.cooking_additions[0].cook_progress)>before_simmer,"Choosing to cook longer should advance real doneness")
	check(str(rules.cooking_grade(14,[{"id":"carrot","label":"胡萝卜","cook_progress":0.05,"browning":0.0}]).id)!="attentive","An undercooked ingredient should prevent an attentive grade")
	var expected: String=rules.seasoning_target(scene._selected_token_data())
	if expected!="rest": scene._choose_seasoning("wasabi" if expected=="brighten" else expected)
	scene._choose_seasoning("pepper")
	check(scene.seasoning_layers.size()==(1 if expected=="rest" else 2) and scene.cooking_phase=="taste","Seasonings should layer without skipping the tasting stage")
	await capture("04-seasoned")
	scene._finish_seasoning()
	check(not scene.stage_ready and scene.cooking_phase=="plating","Seasoning should lead to a separate plating decision")
	scene._choose_plating("share")
	await capture("05-shared")
	check(scene.stage_ready and scene.cooking_phase=="serve","Plating should unlock serving without a hard failure state")
	check(str(scene.plated_dish.prepared.get("bread",""))=="small","The plated dish should preserve the chosen bread cut")
	var record: Dictionary=scene._interaction_record()
	var mechanic: Dictionary=record.mechanic
	check((mechanic.additions as Array).size()==3,"Every pan addition should survive in the result record")
	check((mechanic.preparations as Array).size()==3,"Every ingredient-specific preparation should survive in the result record")
	check((mechanic.stirs as Array).size()==2,"A player-chosen stir count should survive in the result record")
	check(str(mechanic.seasoning)==("pepper" if expected=="rest" else "wasabi" if expected=="brighten" else expected) and (mechanic.seasoning_layers as Array).has("pepper"),"The player's seasoning layers should survive")
	check(str(mechanic.plating)=="share","The player's plating decision should survive")
	check(int(mechanic.craft_score)>=10,"Following sensory cues should earn the attentive grade")
	scene._complete_choice("improvise")
	check(scene.completed,"A plated dish should complete through the existing result contract")
	var outcome: Dictionary=gameplay.latest_outcome("cooking")
	check(str(outcome.get("craft_grade",{}).get("id",""))=="attentive","The outcome should expose its craft grade")
	check(str(outcome.get("service_response","")).contains("切开挤汁") and str(outcome.get("service_response","")).contains("分成小碟"),"The cook should respond to the actual preparation and plating")
	var recipes: Array=state.shared_state.get("world_artifacts",{}).get("recipes",[])
	check(not recipes.is_empty(),"Cooking should still publish a real public recipe")
	if not recipes.is_empty():
		check(str(recipes[-1].get("notes","")).contains("剩下的奶酪 → 昨天的面包 → 一袋柠檬"),"The recipe should describe the actual pan order")
		check(str(recipes[-1].get("notes","")).contains("分成小碟"),"The recipe should preserve plating as part of the cooking memory")
		check(str(recipes[-1].get("notes","")).contains("石泳琪端起盘子"),"The public recipe should retain the cook's response")
	print("COOKING_RHYTHM_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
