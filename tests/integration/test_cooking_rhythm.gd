extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var state=root.get_node("GameState")
	var gameplay=root.get_node("GameplayModuleSystem")
	var rules=load("res://scripts/core/cooking_mechanics.gd")
	state.begin_new_game("B"); state.current_location="night_market"; state.current_minute=600
	check(gameplay.begin_session("cooking","cooking_rhythm_test"),"Cooking session should begin")
	var scene=load("res://scenes/native_module_game.tscn").instantiate(); root.add_child(scene); await process_frame
	for token_id in ["lemon","bread","cheese"]: scene._toggle_token(token_id)
	var inventory_before: Dictionary=state.inventory.duplicate(true)
	# A rough first attempt must still reach the table. The game records the
	# improvisation and lets the player restart before any real stock is spent.
	scene._perform_primary_action()
	for _prep in 3: scene._choose_prep_option(1)
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
	scene._choose_plating("generous")
	check(scene.stage_ready and str(scene._interaction_record().mechanic.grade.id)=="improvised","Mistakes should change the record without destroying the dish")
	scene._reset_cooking()
	check(scene.cooking_phase=="select" and scene.selected_tokens.size()==3,"Restarting should preserve the chosen ingredients for easy revision")
	check(state.inventory==inventory_before,"Restarting before serving should consume no inventory")

	# A second, attentive attempt follows each ingredient's sensory cue.
	scene._perform_primary_action()
	check(scene.cooking_phase=="prep" and scene.prepared_tokens.is_empty(),"Choosing ingredients should not silently prepare them")
	for option in [0,1,0]: scene._choose_prep_option(option)
	check(scene.prepared_tokens==["lemon","bread","cheese"],"Preparation order should be recorded")
	var chosen_cook_order := ["cheese","bread","lemon"]
	for token_id in chosen_cook_order:
		var token: Dictionary=scene._token_data(token_id)
		var window: Array=token.get("heat_window",[.42,.70])
		scene.value_slider.value=(float(window[0])+float(window[1]))*.5
		scene._toggle_token(token_id)
		scene._perform_primary_action()
	check(scene.added_tokens==chosen_cook_order,"The player should be able to revise the pan order after preparation")
	for style in ["gentle","fold"]:
		scene.value_slider.value=.58
		scene._stir(style)
	check(scene.cooking_phase=="stir","Two stirs should make tasting available without forcing it")
	scene._perform_primary_action()
	check(scene.cooking_phase=="taste","The player should decide when to taste")
	var expected: String=rules.seasoning_target(scene._selected_token_data())
	scene._choose_seasoning(expected)
	check(not scene.stage_ready and scene.cooking_phase=="plating","Seasoning should lead to a separate plating decision")
	scene._choose_plating("share")
	check(scene.stage_ready and scene.cooking_phase=="serve","Plating should unlock serving without a hard failure state")
	var record: Dictionary=scene._interaction_record()
	var mechanic: Dictionary=record.mechanic
	check((mechanic.additions as Array).size()==3,"Every pan addition should survive in the result record")
	check((mechanic.preparations as Array).size()==3,"Every ingredient-specific preparation should survive in the result record")
	check((mechanic.stirs as Array).size()==2,"A player-chosen stir count should survive in the result record")
	check(str(mechanic.seasoning)==expected,"The player's seasoning decision should survive")
	check(str(mechanic.plating)=="share","The player's plating decision should survive")
	check(int(mechanic.craft_score)>=10,"Following sensory cues should earn the attentive grade")
	scene._complete_choice("improvise")
	check(scene.completed,"A plated dish should complete through the existing result contract")
	var outcome: Dictionary=gameplay.latest_outcome("cooking")
	check(str(outcome.get("craft_grade",{}).get("id",""))=="attentive","The outcome should expose its craft grade")
	var recipes: Array=state.shared_state.get("world_artifacts",{}).get("recipes",[])
	check(not recipes.is_empty(),"Cooking should still publish a real public recipe")
	if not recipes.is_empty():
		check(str(recipes[-1].get("notes","")).contains("剩下的奶酪 → 昨天的面包 → 一袋柠檬"),"The recipe should describe the actual pan order")
		check(str(recipes[-1].get("notes","")).contains("分成小碟"),"The recipe should preserve plating as part of the cooking memory")
	print("COOKING_RHYTHM_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
