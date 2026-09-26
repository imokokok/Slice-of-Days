extends SceneTree
const Thermal = preload("res://modules/restaurant/domain/food_thermal.gd")
var game
var checks := 0
var failures: Array[String] = []
var output := ""
func _initialize() -> void:
	Engine.max_fps = 120
	root.size = Vector2i(1440, 851)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "-" + name + ".png")
func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = root.get_final_transform() * game.world.get_global_transform_with_canvas() * point
	event.global_position = event.position
	Input.parse_input_event(event)
func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * game.world.get_global_transform_with_canvas() * point
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output = args[0]
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"/private/tmp/pan_lid_qa_%s/book.json" % Time.get_ticks_usec(), "shift_seconds":900.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.set_process(false)
	var world = game.world
	world.audio.muted = true
	world.reactions.set_physics_process(false)
	world.spawn_ingredient(game._definition("chicken"))
	var food: RigidBody2D = world._held
	world.drop_into_pan()
	await create_timer(0.9).timeout
	food.freeze = true
	food.position = world.pan.point(Vector2(795, 583))
	world.reactions.ensure_state(food)
	# The same resting transform drives drawing and pointer picking.
	expect(world.lid.hit(world.lid.HOME), "leaning lid remains selectable at its stand")
	var corners := PackedVector2Array([Vector2(-165,-65),Vector2(165,-65),Vector2(165,62),Vector2(-165,62)])
	var clear := true
	for corner in corners:
		var point: Vector2 = world.lid.transform * corner
		clear = clear and point.x > 1080.0 and point.x < 1340.0 and point.y < 680.0
	expect(clear, "resting lid projection clears seasoning bottles, plate and cutting board")
	await capture("open")
	# Production mouse routing, not only direct state setters.
	mouse(world.lid.HOME, true)
	await process_frame
	expect(world.lid.active, "mouse grabs the physical lid")
	motion(world.pan.point(Vector2(810, 582)))
	await process_frame
	mouse(world.pan.point(Vector2(810, 582)), false)
	await process_frame
	expect(world.lid.covered and not world.lid.active, "drag and release seats the lid on the pan")
	expect(world._food_at(food.position) == null, "covered food cannot be selected through the lid")
	await physics_frame
	await process_frame
	expect(not world.lid._shape.disabled, "closed lid supplies an actual collision ceiling")
	var utensil = world.utensils[0]
	utensil.active = true
	expect(utensil.stir_sweep(food.position-Vector2(30,0),food.position+Vector2(30,0)) == 0, "utensils cannot stir through a closed lid")
	utensil.active = false
	await capture("covered")
	world.spawn_ingredient(game._definition("carrot"))
	var held: RigidBody2D = world._held
	world.drop_into_pan()
	expect(world._held == held and not held.get_meta("enrolled", false), "keyboard cannot drop ingredients through closed lid")
	world._held.position = Vector2(1240, 700)
	world.drop_held()
	world.set_cooking(true)
	world.set_heat_level("high")
	world.reactions.advance(35.0)
	expect(world.lid.pressure > 0.0 and world.lid.received_steam_ml > 0.0, "actual heating and food evaporation accumulate lid warning")
	expect(absf(world.lid.received_steam_ml - world.lid.steam_ml - world.lid.escaped_steam_ml - world.lid.condensed_ml) < 0.00001, "captured water is conserved across steam, venting and condensation")
	expect(world.lid.condensed_ml > 0.0 and world.pan.water_ml > 0.0, "finite condensate returns to the pan")
	var before_pressure: float = world.lid.pressure
	world.set_controls_enabled(false)
	await create_timer(0.15).timeout
	expect(world.lid.pressure == before_pressure, "modal pause does not advance pressure")
	world.set_controls_enabled(true)
	world.reactions.pan_c = 215.0
	world.lid.pressure = 0.7
	await capture("warning")
	mouse(world.lid.position, true)
	await process_frame
	expect(not world.lid.covered and world.lid.pressure == 0.0, "dragging lid off vents pressure immediately")
	motion(world.lid.HOME)
	mouse(world.lid.HOME, false)
	await process_frame
	expect(world.lid.position == world.lid.HOME, "lid returns to its counter rest position")
	world.lid.close_lid()
	world.lid.pressure = 0.5
	world.set_cooking(false)
	world.reactions.pan_c = 70.0
	world.reactions.advance(5.0)
	expect(world.lid.pressure < 0.5, "cooling releases accumulated warning")
	world.lid.open_lid()
	world.lid.rest_lid()
	world.set_cooking(true)
	world.set_heat_level("high")
	world.reactions.pan_c = 235.0
	var fresh := Thermal.make_state(game._definition("chicken"),food.mass, 1.0)
	food.set_meta("thermal", fresh)
	food.position = world.pan.point(Vector2(795, 583))
	world.lid.close_lid()
	# No direct pressure injection here: actual food/water/heat step until a pop.
	var elapsed := 0.0
	while world.lid.burst_count == 0 and elapsed < 240.0:
		world.reactions.advance(1.0)
		elapsed += 1.0
	expect(world.lid.burst_count == 1 and not world.lid.covered, "sustained real heating pops the lid once")
	expect(food.linear_velocity.y < 0.0 and world.cooking, "burst moves the same food bodies while burner remains on")
	expect(food.get_meta("thermal").initial_kg == fresh.initial_kg, "burst preserves food identity and processing history")
	await capture("burst")
	var peak: float = world.lid.position.y
	var previous_pose: Vector2 = world.lid.position
	var largest_step := 0.0
	var descending := false
	var airborne_rotation: float = world.lid.rotation
	for i in 280:
		world.reactions.advance(0.01)
		peak = minf(peak, world.lid.position.y)
		largest_step = maxf(largest_step, previous_pose.distance_to(world.lid.position))
		previous_pose = world.lid.position
		if world.lid._flight and world.lid._velocity.y > 0.0: descending = true
	expect(world.lid.burst_origin.y - peak > 220.0, "steam impulse launches lid visibly high above the pan")
	expect(descending and absf(airborne_rotation) > 0.1, "lid spins and descends under gravity")
	expect(largest_step < 9.0, "flight and rebound remain continuous without a sideways teleport")
	expect(not world.lid._flight and world.lid._settling == 0.0 and world.lid.position == world.lid.HOME and world.lid.scale == world.lid.REST_SCALE, "popped lid settles into clear stand and is reusable")
	world.lid.close_lid()
	world.lid.burst()
	var paused_pose: Vector2 = world.lid.position
	world.set_controls_enabled(false)
	await create_timer(0.15).timeout
	expect(world.lid.position == paused_pose, "modal pause freezes airborne lid")
	world.set_controls_enabled(true)
	world.reactions.advance(3.0)
	world.pan.water_ml = 0.0
	food.freeze = true
	food.position = world.pan.point(Vector2(795, 583))
	# Real dry cooking from existing state, no invented cooked/char values.
	world.reactions.advance(250.0)
	var state: Dictionary = food.get_meta("thermal")
	var charred := maxf(float(state.char[0]),float(state.char[1]))
	expect(charred > 0.15 and food.get_meta("burn_warning",false), "prolonged frying produces irreversible char and warning")
	food.freeze = false
	utensil.active = true
	var previous_face := int(state.contact_face)
	expect(utensil.stir_sweep(food.position + Vector2(45,40), food.position + Vector2(-15,-20)) == 1, "actual upward spatula contact turns burnt food")
	utensil.active = false
	food.freeze = true
	expect(int(state.contact_face) != previous_face and float(state.char[1-int(state.contact_face)]) > 0.15, "flipping exposes the actual burnt underside and preserves both faces")
	world.reactions._apply(food,state)
	await capture("burnt")
	var saved_char: Array = state.char.duplicate()
	world.pan.water_ml = 400.0
	world.pan.water_heat = 95.0
	world.reactions.advance(10.0)
	expect(state.char == saved_char, "adding water cannot repair char or create further wet-heat char")
	var snapshot: Dictionary = world.describe_body(food)
	expect(snapshot.thermal.char == saved_char, "plating snapshot retains burnt surfaces")
	world.lid.close_lid()
	world.pan.move_to(world.pan.HOME + Vector2(-180, 0))
	await process_frame
	expect(world.lid.position.distance_to(world.pan.point(Vector2(810,582))) < 0.01, "lid follows moved pan using the same geometry")
	world.lid.open_lid()
	world.lid.rest_lid()
	world.clear_food()
	world.pan.water_ml = 0.0
	world.pan.move_to(world.pan.HOME)
	world.lid.close_lid()
	world.reactions.advance(120.0)
	world.lid.agitate(160.0)
	expect(world.lid.pressure == 0.0 and world.lid.burst_count == 2, "an empty dry pan has no steam explosion")
	world.pan.move_to(Vector2(world.pan.SINK_X - 809, world.pan.HOME.y))
	world.pan.faucet_on = true
	world.pan._process(0.5)
	expect(world.pan.water_ml == 0.0 and world.sink_water_ml > 0.0, "tap water runs off closed lid instead of entering the pot")
	world.pan.faucet_on = false
	print("Lid pop after %s seconds of accelerated hot-pan fixture cooking" % elapsed)
	for failure in failures: push_error(failure)
	print("%s: pan lid and burning, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
