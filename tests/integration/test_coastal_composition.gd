extends SceneTree
const Composition = preload("res://scripts/ui/street_composition.gd")
var failures := 0
var checks := 0
var state: Node
var folder := "res://.runtime/coastal-composition"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func capture(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(folder+"/"+name+".png")
	return picture

func town(location: String) -> void:
	state.current_location = location
	state.shared_state.erase("street_positions")
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.25).timeout
	var scene = current_scene
	for hotspot in scene.street.hotspots:
		if hotspot.kind in ["person","shopkeeper"]:
			check(absf(scene.street.player_x-float(hotspot.x))>=95,location+": new arrival does not overlap a resident")
	var left: float=scene.route_offset+scene.current_index*scene.BLOCK_WIDTH
	scene.street.player_x = Composition.clear_arrival(scene._place_center()-130,scene.street.hotspots,left,left+scene.BLOCK_WIDTH)
	scene.street.move_player(0,0)
	scene._on_walk(scene.street.player_x)
	scene._refresh()
	scene.street.enabled = false
	await create_timer(.2).timeout

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	state = root.get_node("GameState")
	state.begin_new_game("A"); state.current_minute=660
	var locations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/locations.json"))
	for row in locations.locations:
		var location: String = row.id
		await town(location)
		var scene = current_scene
		var stage = scene.street
		var bodies: Array[float] = []
		for hotspot in stage.hotspots:
			var kind := str(hotspot.kind)
			if kind in ["person","shopkeeper"]: bodies.append(float(hotspot.x))
			if kind == "argument":
				bodies.append(float(hotspot.x)-70); bodies.append(float(hotspot.x)+70)
			if kind in ["person","shopkeeper","door","home","shop","module","event"]:
				stage.player_x = float(hotspot.x)
				check(not stage.nearest_of([kind]).is_empty(),location+": moved interaction is reachable: "+kind)
		for i in bodies.size():
			check(stage._actor_ground_at(bodies[i])>Composition.CURB+100,location+": residents stand on foreground pavement")
			for j in range(i+1,bodies.size()): check(absf(bodies[i]-bodies[j])>=110,location+": residents have individual standing space")
		var left: float=scene.route_offset+scene.current_index*scene.BLOCK_WIDTH
		stage.player_x = Composition.clear_arrival(scene._place_center()-130,stage.hotspots,left,left+scene.BLOCK_WIDTH)
		stage.move_player(0,0); stage.queue_redraw()
		await capture(location)
		check(stage.material.shader.resource_path.ends_with("coastal_grade.gdshader"),location+": world receives the shared finish")
		check(scene.material==null,location+": world finish does not tint global UI")
	# The actual counter, optional dialogue and cancel still operate after staging.
	await town("cafe")
	var scene = current_scene
	var vendor: Dictionary = scene.street.hotspots.filter(func(h):return h.kind=="shopkeeper")[0]
	scene.street.player_x=vendor.x+60
	scene._talk_to_nearest()
	await create_timer(.2).timeout
	check(is_instance_valid(scene.conversation),"Walking beside the relocated shopkeeper opens actual dialogue")
	var cancel := InputEventAction.new(); cancel.action="ui_cancel"; cancel.pressed=true
	root.push_input(cancel)
	await process_frame; await process_frame
	check(not is_instance_valid(scene.conversation),"Cancel still exits the real conversation")
	# Both original art and generated facades dim together; UI remains legible.
	await town("produce_stall")
	var day := await capture("produce-day")
	state.current_minute=1260
	await create_timer(.1).timeout
	current_scene.street.queue_redraw()
	var night := await capture("produce-night")
	var screen_scale := Vector2(day.get_size())/Vector2(1600,900)
	for point in [Vector2(80,280),Vector2(80,860)]:
		var p := Vector2i(point*screen_scale)
		check(night.get_pixelv(p).get_luminance()<day.get_pixelv(p).get_luminance()*.88,"Background and pavement both follow night light")
	var clock_pixel := Vector2i(Vector2(230,35)*screen_scale)
	check(day.get_pixelv(clock_pixel).is_equal_approx(night.get_pixelv(clock_pixel)),"World light never changes UI panel colors")
	var before: float=current_scene.street.player_x
	current_scene.street.enabled=true
	for i in 20: current_scene.street.move_player(1,.016)
	check(current_scene.street.player_x>before+25,"World polish preserves continuous walking")
	current_scene._remember_position()
	var saved_x: float=current_scene.street.player_x
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.3).timeout
	check(is_equal_approx(current_scene.street.player_x,saved_x),"Reopening a street preserves the saved player position")
	print("COASTAL COMPOSITION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
