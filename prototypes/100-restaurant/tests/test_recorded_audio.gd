extends SceneTree

var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	Engine.max_fps = 120
	call_deferred("_run")

func _run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://audio_qa_%s/book.json" % Time.get_ticks_usec(), "shift_seconds": 600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	await process_frame
	var world = game.world
	var sound = world.audio
	for group in sound.banks:
		for path in sound.banks[group]:
			_expect(str(path).contains("/recorded/"), "all banks use licensed recorded assets")
			var stream: AudioStreamWAV = load(path)
			_expect(stream != null and stream.get_length() > 0.1, "recording decodes to playable audio")
	_expect(sound.banks.chop.size() >= 3, "chopping has independently recorded variants")
	_expect(sound.banks.boil.size() >= 2, "boiling has multiple recordings")
	_expect(not sound.banks.has("rice_open") and not sound.banks.has("rice_close"), "removed cooker sounds are absent from playback banks")
	_expect(sound.banks.toss.size() >= 2 and sound.banks.hot_drop.size() >= 1, "pan motion and hot food entry have separate recorded layers")
	world.spawn_ingredient(game._definition("tomato"))
	var tomato: RigidBody2D = world._held
	world.drop_into_pan()
	await create_timer(0.6).timeout
	_expect(sound.cooking_profile(world) == "", "cold food makes no frying sound")
	game.session.set_heating(true)
	await create_timer(0.1).timeout
	tomato.impact_speed = 90.0
	sound.play_food_drop(tomato)
	_expect(not sound.effects.hot_drop.playing, "a cold pan does not play a false hot-drop sizzle")
	world.reactions.pan_c = 150.0
	sound.play_food_drop(tomato)
	_expect(sound.effects.hot_drop.playing, "moist food landing in a truly hot pan adds a brief real sizzle")
	tomato.set_meta("cooking_heat", 2.0)
	var thermal: Dictionary = world.reactions.ensure_state(tomato)
	thermal.faces_c=[135.0,115.0]
	_expect(sound.cooking_profile(world) == "fry_vegetable", "hot moist vegetable selects vegetable frying recording")
	tomato.set_meta("definition", game._definition("egg"))
	_expect(sound.cooking_profile(world) == "fry_egg", "egg selects actual frying egg recording")
	tomato.set_meta("definition", game._definition("beef"))
	_expect(sound.cooking_profile(world) == "fry_meat", "meat selects separate frying recording")
	tomato.set_meta("definition", game._definition("bread"))
	thermal.water_kg=0.0
	_expect(sound.cooking_profile(world) == "", "dry bread alone does not invent wet sizzling")
	tomato.set_meta("surface_sauce", {"volume_ml": 8.0, "composition_ml": {"oil": 8.0}})
	_expect(sound.cooking_profile(world) == "", "oil cannot create water bubbles in completely dry food")
	thermal.water_kg=0.012
	_expect(sound.cooking_profile(world) == "fry_vegetable", "oil-coated food with residual moisture can fry")
	tomato.set_meta("surface_sauce", {"volume_ml": 12.0, "composition_ml": {"ketchup": 12.0}})
	_expect(sound.cooking_profile(world) == "simmer_sauce", "sauce composition selects thick sauce bubbling")
	world.pan.water_ml = 400.0
	world.pan.water_heat = 25.0
	_expect(sound.cooking_profile(world) == "", "cold water suppresses frying and bubbling")
	world.pan.water_heat = 100.0
	_expect(sound.cooking_profile(world) == "boil", "boiling water takes priority over sauce and frying")
	sound.update_kitchen(world)
	_expect(sound.loops.boil.playing and not sound.loops.sizzle.playing and not sound.loops.sauce.playing, "wet cooking uses one appropriate cooking bed")
	world.set_controls_enabled(false)
	sound.update_kitchen(world)
	_expect(sound.active_loop_count() == 0, "modal immediately stops every kitchen bed")
	world.set_controls_enabled(true)
	sound.focused = false
	sound.update_kitchen(world)
	_expect(sound.active_loop_count() == 0, "unfocused kitchen cannot restart beds")
	sound.focused = true
	world.pan.water_ml = 0.0
	world.spawn_ingredient(game._definition("oil"))
	var bottle = world._held
	world._squeezing = true
	world.squeeze_pressure = 0.8
	sound.update_kitchen(world)
	_expect(sound.loops.pour.playing and sound.loop_banks.pour == "pour_oil", "pouring oil uses an oil recording")
	bottle.set_meta("remaining_ml", 0.0)
	sound.update_kitchen(world)
	_expect(not sound.loops.pour.playing, "empty bottle makes no flowing sound")
	world._stop_squeezing()
	world.discard_held()
	sound.stop_all()
	world.reactions.set_physics_process(false)
	tomato.set_meta("definition", game._definition("tomato"))
	tomato.set_meta("surface_sauce", {})
	sound._last_effect.clear()
	sound.play_food_stir(tomato, "spoon", 20.0)
	_expect(sound.effects.stir_wood.playing and not sound.effects.stir_metal.playing, "wooden tool uses a wooden pan-contact recording")
	var stamp: int = sound._last_effect.get("stir_contact", 0)
	for i in range(48): sound.play_food_stir(tomato, "spoon", 20.0)
	_expect(sound._last_effect.get("stir_contact", 0) == stamp, "batch contacts aggregate instead of restarting 48 sounds")
	sound.stop_all()
	sound._last_effect.clear()
	sound.play_food_stir(tomato, "black", 20.0)
	_expect(sound.effects.stir_metal.playing and not sound.effects.stir_wood.playing, "metal tool uses a separate contact recording")
	world.pan.water_ml = 400.0
	sound.stop_all()
	sound._last_effect.clear()
	sound.play_food_stir(tomato, "spoon", 20.0)
	_expect(sound.effects.stir_water.playing, "water in pan selects wet stirring even for a dry definition")
	world.pan.water_ml = 0.0
	sound._last_effect.clear()
	world.pan.grab(world.pan.point(Vector2(1000, 577)))
	var tossed: int = world.pan._toss_contents(Vector2(0, -40), Time.get_ticks_msec())
	_expect(tossed > 0 and sound.effects.toss.playing, "a real pan toss adds cookware motion sound only when food launches")
	world.pan.release_pan()
	sound.muted = true
	for player in sound.loops.values() + sound.effects.values():
		_expect(not player.playing, "mute stops every recorded player")
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: recorded audio, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
