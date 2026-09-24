extends Node

const ROOT: = "res://modules/restaurant/assets/audio/"
const LOOPS: = {"flame": -17.0, "sizzle": -16.0, "boil": -14.0, "water": -13.0, "squeeze": -10.0, "pour": -12.0, "powder": -14.0}
var muted: = false:
	set(value):
		muted = value
		if value: stop_all()
var focused: = true
var ui_dispense_mode: = ""
var loops: Dictionary = {}
var effects: Dictionary = {}
var _last_effect: Dictionary = {}

func _ready() -> void :
	for id in LOOPS:
		var player: = AudioStreamPlayer.new()
		var stream: = load(ROOT + id + ".wav") as AudioStreamWAV
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
		player.stream = stream
		player.volume_db = LOOPS[id]
		add_child(player)
		loops[id] = player
	for id in ["ignite", "tap", "bell", "pan", "chop", "stir", "stir_wet", "stir_meat", "stir_dry", "stir_hard", "drop", "drain", "wipe", "paper", "serve"]:
		var player: = AudioStreamPlayer.new()
		player.stream = load(ROOT + id + ".wav")
		player.volume_db = -18 if id == "drop" else -12
		add_child(player)
		effects[id] = player

func update_kitchen(world: Node2D) -> void :
	var audible: bool = not muted and focused
	var hot: bool = world.cooking and world.pan.on_stove()
	var has_food: = false
	for body in world._foods.get_children():
		if body.get_meta("enrolled", false) and not body.get_meta("plated", false): has_food = true
	var boiling: bool = hot and world.pan.water_ml > 0 and world.pan.water_heat >= 99
	var dispensing: String = world.get_dispense_mode(world._held.get_meta("definition", {})) if world._squeezing and is_instance_valid(world._held) else ""
	var desired: = {"flame": world.cooking, "sizzle": hot and has_food and world.pan.water_ml < 50, "boil": boiling, "water": world.pan.faucet_on, "squeeze": dispensing == "squeeze", "pour": dispensing == "pour", "powder": dispensing == "powder"}
	for id in loops:
		var player: AudioStreamPlayer = loops[id]
		if id == "squeeze" and world._squeezing:

			player.volume_db = lerpf(-24.0, LOOPS[id], world.squeeze_pressure)
			player.pitch_scale = lerpf(0.82, 1.08, world.squeeze_pressure)
		if audible and ((world.controls_enabled and desired[id]) or (ui_dispense_mode == id and id in ["squeeze", "pour", "powder"])):
			if not player.playing: player.play()
		elif player.playing: player.stop()

func play_effect(id: String) -> void :
	if muted or not focused or not effects.has(id): return
	var now: = Time.get_ticks_msec()
	if now - int(_last_effect.get(id, -1000)) < (160 if id == "stir" else 70): return
	_last_effect[id] = now
	var player: AudioStreamPlayer = effects[id]
	player.pitch_scale = randf_range(0.94, 1.06)
	player.play()

func stir_profile(definition: Dictionary) -> String:
	var id: = str(definition.get("id", ""))
	var category: = str(definition.get("category", ""))
	var tags: Array = definition.get("tags", [])
	if category == "odd" or id in ["baseball_bat", "computer_mouse", "slipper", "rock", "spring", "building_block", "candle"]:
		return "hard"
	if "meat" in tags or "seafood" in tags or id in ["egg", "tofu", "sausage"]:
		return "meat"
	if "vegetable" in tags or "fresh" in tags or id in ["tomato", "mushroom", "fruit", "watermelon"]:
		return "wet"
	return "dry"

func play_food_stir(body: RigidBody2D, utensil_kind: String) -> void :
	if not is_instance_valid(body): return
	var profile: = stir_profile(body.get_meta("definition", {}))
	var id: = "stir_" + profile
	if muted or not focused or not effects.has(id): return
	var cooldown_key: = id + ":" + str(body.get_instance_id())
	var now: = Time.get_ticks_msec()
	if now - int(_last_effect.get(cooldown_key, -1000)) < 150: return
	_last_effect[cooldown_key] = now
	var player: AudioStreamPlayer = effects[id]
	player.pitch_scale = randf_range(0.96, 1.035) * (0.94 if utensil_kind == "spoon" else 1.0)
	player.volume_db = {"wet": -16.0, "meat": -15.0, "dry": -18.0, "hard": -20.0}[profile]
	player.play()

func stop_all() -> void :
	for player in loops.values() + effects.values(): player.stop()

func _exit_tree() -> void :
	stop_all()
	for player in loops.values() + effects.values(): player.stream = null
	loops.clear()
	effects.clear()

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		focused = false
		stop_all()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN: focused = true
