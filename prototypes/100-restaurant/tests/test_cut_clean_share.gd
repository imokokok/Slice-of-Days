extends SceneTree
var game
var checks := 0
var failures: Array[String] = []
var evidence := ""
const Cuts = preload("res://modules/restaurant/assets/cut_state_library.gd")

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	Engine.max_fps = 120
	if not OS.get_cmdline_user_args().is_empty(): evidence = OS.get_cmdline_user_args()[0]
	call_deferred("run")

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://cut_clean_share_%s/book.json" % Time.get_ticks_usec(), "shift_seconds":600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.world.audio.muted = true
	await process_frame
	var world = game.world
	for id in Cuts.ROWS:
		for style in ["slice", "dice"]:
			for variant in 3:
				var texture := Cuts.texture(id, style, variant)
				expect(texture != null and texture.get_width() > 20, "%s %s %d has cut art" % [id,style,variant])
	world.spawn_ingredient(game._definition("tomato"))
	var whole: RigidBody2D = world._held
	whole.position = world.cutting_board.rect().get_center()
	world.drop_held(false)
	whole.set_meta("surface_sauce", {"volume_ml":10.0,"composition_ml":{"olive_oil":10.0}})
	var initial_mass: float = whole.mass
	var halves: Array = world.split_food(whole, Vector2.RIGHT, Vector2.INF, 4)
	await process_frame
	expect(halves.size() == 2, "real cut produces two pieces")
	if halves.size() != 2: quit(1); return
	var p: Vector2 = halves[0].position
	var r: float = halves[0].rotation
	expect(halves[0].board_settling, "cut pieces enter gravity/tipping settlement")
	world.set_controls_enabled(false)
	await create_timer(0.1).timeout
	expect(halves[0].position == p and halves[0].rotation == r, "modal pause suspends board settling")
	world.set_controls_enabled(true)
	await create_timer(0.18).timeout
	expect(halves[0].position.distance_to(p) > 0.5 and absf(halves[0].rotation-r) > 0.03, "piece moves and tips after knife leaves")
	await create_timer(0.9).timeout
	expect(not halves[0].board_settling and is_zero_approx(halves[0].board_height), "friction settles pieces onto fixed support")
	var quartered: Array = world.split_food(halves[0], Vector2.DOWN, Vector2.INF, 4)
	await process_frame
	var parts: Array = quartered + [halves[1]]
	var mass := 0.0
	var coating := 0.0
	for part in parts:
		mass += part.mass
		coating += float(part.get_meta("surface_sauce").volume_ml)
	expect(is_equal_approx(mass, initial_mass), "crosscut conserves source mass")
	expect(is_equal_approx(coating,10.0), "crosscut conserves coating, never duplicates full sauce")
	expect(quartered[0].get_meta("cut_style") == "dice", "crosswise cut switches to chunk face")
	expect(halves[1].get_meta("cut_style") == "slice", "parallel/first cut keeps slice face")
	await capture("board")
	world.clear_workspace()
	await process_frame
	# Actual module flow: cooked food leaves a finite film; next food picks it up.
	world.spawn_ingredient(game._definition("onion"))
	var onion: RigidBody2D = world._held
	world._held = null
	onion.position = world.pan.point(Vector2(810,575))
	game._food_entered("onion",false,onion)
	onion.set_meta("cooking_heat",8.0)
	var before := onion.mass
	world.set_plated(true)
	var film: float = world.pan.residue.total_kg()
	expect(film > 0 and is_equal_approx(onion.mass+film,before), "plating deposits mass-conserving residue")
	world.set_plated(true)
	expect(is_equal_approx(world.pan.residue.total_kg(),film), "repeated plate action cannot deposit twice")
	world.clear_workspace()
	game.session.dish.clear()
	await process_frame
	expect(is_equal_approx(world.pan.residue.total_kg(),film), "removing meal does not magically wash pan")
	world.spawn_ingredient(game._definition("potato"))
	var potato: RigidBody2D = world._held
	world._held = null
	potato.position = world.pan.point(Vector2(810,575))
	var clean_mass := potato.mass
	game._food_entered("potato",false,potato)
	expect(potato.has_meta("pan_carryover"), "next dish acquires previous flavor")
	expect(is_equal_approx(potato.mass+world.pan.residue.total_kg(),clean_mass+film), "flavor transfer conserves mass")
	expect(game.session.plate().pan_carryover.has("onion"), "carryover survives into evaluation snapshot")
	var review: Dictionary = preload("res://modules/restaurant/domain/customer_review.gd").compose(game.session.plate(),{"kind":"regular"},game.session._catalog,70)
	expect("上一锅" in review.detail,"customer notices flavor carryover")
	var start: Vector2 = world.pan.point(Vector2(730,576))
	var finish: Vector2 = world.pan.point(Vector2(890,576))
	expect(is_zero_approx(world.cloth.wipe_segment(start,finish)), "cloth cannot erase residue while food is in pan")
	world.clear_workspace()
	game.session.dish.clear()
	await process_frame
	world.cooking = false
	world.cloth.wetness = 1
	var dirty: float = world.pan.residue.total_kg()
	expect(is_zero_approx(world.cloth.wipe_segment(start,start)), "holding still does not clean")
	expect(is_zero_approx(world.cloth.wipe_segment(Vector2(20,20),Vector2(80,20))), "no cleaning outside actual pan")
	world.cooking = true
	expect(is_zero_approx(world.cloth.wipe_segment(start,finish)), "turn heat off before wiping")
	world.cooking = false
	var removed: float = world.cloth.wipe_segment(start,finish)
	expect(removed > 0 and is_equal_approx(dirty,world.pan.residue.total_kg()+world.cloth.absorbed_kg), "contact transfers dirt to cloth")
	for i in 5: world.cloth.wipe_segment(start,finish)
	expect(world.pan.residue.total_kg() < 0.000001, "several real wiping strokes clean pan")
	world.cloth.active = true
	world.cloth.position = Vector2(220,680)
	world.pan.faucet_on = true
	world.pan.faucet_amount = 1
	var dirt_on_cloth: float = world.cloth.absorbed_kg
	await create_timer(0.4).timeout
	expect(world.cloth.absorbed_kg < dirt_on_cloth and world.pan.residue.waste_kg > 0, "running water rinses dirty cloth to drain")
	world.cloth.release_tool()
	world.pan.faucet_on = false
	mouse(world.cloth.HOME,"down")
	await process_frame
	expect(world.cloth.active and world.has_active_utensil(), "real input picks up cloth and reserves tool interaction")
	mouse(world.cloth.HOME+Vector2(20,-20),"move")
	await process_frame
	expect(world.cloth.position != world.cloth.HOME, "held cloth follows motion input")
	world.set_controls_enabled(false)
	expect(not world.cloth.active and world.cloth.position == world.cloth.HOME,"modal safely releases cloth to its own place")
	world.set_controls_enabled(true)
	mouse(world.cloth.HOME,"up")
	await capture("clean")
	var vignette = preload("res://modules/restaurant/ui/recipe_vignette.gd").new()
	vignette.stage = "cut"
	vignette.entries = [{"id":"onion","cut":true}]
	vignette.catalog = game.session.ingredients
	root.add_child(vignette)
	expect(vignette.get_child(0).get_child_count()==2, "recipe cutting sketch displays both separated faces")
	for mask in vignette.get_child(0).get_children():
		expect(mask.get_child(0).definition.id=="onion" and mask.get_child(0).cut, "recipe sketch preserves actual ingredient identity instead of default tomato")
	vignette.queue_free()
	await share_checks()
	game.queue_free()
	await process_frame
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: cut / cleaning / single recipe sharing, %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func share_checks() -> void:
	var record := {"id":"shared_page","title":"我的洋葱小锅 <script>alert(1)</script>","author":"测试主厨","notes":"第一步切片。\n第二步煮熟。\n<img src=x onerror=alert(1)>","dish":{"ingredients":[{"id":"onion","cut":true,"heat":7.0}]}}
	expect(game.repository.save_recipe(record), "save a recipe before sharing")
	expect(game.repository.save_recipe({"id":"private_page","title":"这页没打算分享","author":"测试","dish":{"ingredients":["potato"]}}), "second private recipe fixture saved")
	var json_path: String = game.repository.storage_path.get_base_dir()+"/shared.json"
	expect(game.repository.export_recipe_to("shared_page",json_path)==OK, "one-page JSON export succeeds")
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	expect(json.recipes.size()==1 and json.recipes[0].id=="shared_page", "single share does not disclose other recipes")
	expect(game.repository.export_recipe_to("shared_page",game.repository.storage_path)==ERR_INVALID_PARAMETER, "share cannot overwrite library")
	var stored: Dictionary = game.repository.load_recipes()[0]
	game._view_recipe(stored)
	await process_frame
	await process_frame
	var png := ""
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		png = Marshalls.raw_to_base64(game._recipe_stand.viewport.get_texture().get_image().save_png_to_buffer())
	else:
		var img := Image.create(16,16,false,Image.FORMAT_RGBA8)
		img.fill(Color("ddbc88"))
		png = Marshalls.raw_to_base64(img.save_png_to_buffer())
	var html_path: String = game.repository.storage_path.get_base_dir()+"/page.html"
	expect(game.repository.export_reading_page("shared_page",html_path,png,game.session.ingredients)==OK,"portable HTML export succeeds")
	var html := FileAccess.get_file_as_string(html_path)
	expect(not html.contains("<script>") and not html.contains("<img src=x"), "recipe text is escaped, no executable user markup")
	expect(html.contains("&lt;script&gt;") and html.contains("data:application/json;base64,") and html.contains("data:image/png;base64,"), "HTML contains safe text, artwork and editable attachment")
	var marker := "data:application/json;base64,"
	var payload := html.get_slice(marker,1).get_slice('"',0)
	var downloaded := Marshalls.base64_to_utf8(payload)
	var downloaded_json := json_path.get_base_dir()+"/friend.json"
	var file := FileAccess.open(downloaded_json,FileAccess.WRITE)
	file.store_string(downloaded)
	file.close()
	var friend := preload("res://modules/restaurant/storage/recipe_repository.gd").new(json_path.get_base_dir()+"/friend_book.json")
	expect(friend.import_from(downloaded_json).added==1,"friend imports the actual embedded editable recipe")
	# Human-review evidence uses a normal authored page, after adversarial checks above.
	if not evidence.is_empty():
		stored.title = "慢慢煮一锅洋葱"
		stored.notes = "把洋葱切成薄片。小火翻炒到柔软，再添半杯水。\n关火前尝一口，留一点甜给今天。"
		game._show_recipe_editor(stored)
		await process_frame
		game._recipe_canvas.add_text("洋葱小锅", Color("66533c"))
		game._recipe_canvas.stickers[-1].position = [0.5,0.18]
		game._recipe_canvas.stickers[-1].scale = 0.18
		game._recipe_canvas.add_ingredient({"id":"onion","cut":true,"heat":7.0})
		game._recipe_canvas.stickers[-1].position = [0.27,0.63]
		game._recipe_canvas.stickers[-1].scale = 0.2
		game._recipe_canvas.add_text("切片 · 炒软\n添水 · 煮开", Color("66533c"))
		game._recipe_canvas.stickers[-1].position = [0.7,0.62]
		game._recipe_canvas.stickers[-1].scale = 0.11
		stored.poster = game._recipe_canvas.export_data()
		expect(game.repository.save_recipe(stored),"normal DIY page with editable drawing/text saves")
		game._view_recipe(stored)
		await process_frame
		await RenderingServer.frame_post_draw
		png = Marshalls.raw_to_base64(game._recipe_stand.viewport.get_texture().get_image().save_png_to_buffer())
		expect(game.repository.export_reading_page("shared_page",html_path,png,game.session.ingredients)==OK,"actual DIY page exports after revision")
	await capture("recipe")
	if not evidence.is_empty():
		expect(game.repository.export_recipe_to("shared_page",json_path)==OK,"shared editable attachment matches revised DIY page")
		DirAccess.copy_absolute(html_path,evidence+"-page.html")
		DirAccess.copy_absolute(json_path,evidence+"-recipe.json")

func capture(suffix: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence+"-"+suffix+".png")

func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)

func mouse(point: Vector2, kind: String) -> void:
	point = root.get_final_transform() * point
	if kind == "move":
		var event := InputEventMouseMotion.new()
		event.position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = kind == "down"
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if event.pressed else 0
		Input.parse_input_event(event)
