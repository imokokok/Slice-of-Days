extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(1)
		return
	var state = root.get_node("GameState")
	root.get_node("ChapterSystem").start_new_game()
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.7).timeout
	var town = current_scene
	var stage = town.street
	stage.enabled = true
	stage.move_player(1,0.2)
	var turn_x: float = stage.player_x
	stage.move_player(-1,0.05)
	check(stage.velocity == 0.0 and stage.player_x == turn_x,"Turn before walking back")
	for i in 5: stage.move_player(-1,0.05)
	check(stage.facing == -1 and stage.player_x < turn_x,"After turning, walk toward the new facing direction")
	var bench: Dictionary = {}
	for item in stage.hotspots:
		if str(item.kind) == "bench": bench = item; break
	stage.player_x = float(bench.x)
	check(stage.nearest().kind == "bench","Bench hotspot must be reachable without road sign stealing it")
	town._interact()
	check(stage.sitting and town.event_overlay.visible,"E must visibly seat player")
	var before: int = state.current_minute
	town._wait_on_bench(30)
	check(state.current_minute == before+30 and stage.sitting,"Seated waiting advances exactly 30 minutes")
	town._stand_from_bench()
	check(not stage.sitting and not town.event_overlay.visible,"Standing restores exploration")
	stage.player_x = stage.world_width - 80.0
	town._on_walk(stage.player_x)
	town._refresh()
	check(not stage.hotspots.any(func(h: Dictionary) -> bool: return str(h.kind) == "roads"),"The joined street must never stop walking for a travel menu")
	var sound = root.get_node("WorldSound")
	check(sound.coast.stream != null and sound.coast.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"Sea sound must be looped")
	var pcm: PackedByteArray = sound.coast.stream.data
	var peak := 0
	for i in range(0,pcm.size(),400): peak = maxi(peak,absi(pcm.decode_s16(i)))
	check(peak > 2000,"Sea waveform must contain audible non-silent signal")
	sound.set_indoor(true)
	check(sound.coast.volume_db < -20,"Interior sea sound must be attenuated")
	print("TURN SIT SEA PASS" if failures == 0 else "TURN SIT SEA FAIL")
	quit(failures)
