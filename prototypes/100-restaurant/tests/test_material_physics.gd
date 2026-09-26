extends SceneTree
const Response = preload("res://modules/restaurant/domain/material_response.gd")
const Spring = preload("res://modules/restaurant/third_party/spring_damper/spring_damper.gd")
var game
var checks := 0
var failures: Array[String] = []
var evidence := ""

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	if not OS.get_cmdline_user_args().is_empty(): evidence = OS.get_cmdline_user_args()[0]
	call_deferred("run")

func sample(id: String):
	game.world.spawn_ingredient(game._definition(id))
	var body = game.world._held
	game.world._held = null
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_physics_process(false)
	body.position = Vector2(1200, 730)
	return body

func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://material_physics_%s/book.json" % Crypto.new().generate_random_bytes(16).hex_encode(),"shift_seconds":3600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.world.audio.muted = true
	var defs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json"))
	for d in defs:
		expect(Response.data.items.has(d.id), "%s has an explicit material assignment" % d.id)
		var p := Response.profile(d)
		expect(p.friction > 0 and p.bounce >= 0 and p.bounce < 1 and p.spring_damping > 0, "%s finite dissipative configuration" % d.id)
	# Every playable renderer also has an actual silhouette, not a universal circle.
	for d in game.session.ingredients:
		if d.id in ["fish","salmon"]: continue
		expect(preload("res://modules/restaurant/assets/sprite_library.gd").body_outline(d.id).size() >= 3, "%s has a silhouette collision hull" % d.id)
	var carrot = sample("carrot")
	var tofu = sample("tofu")
	var bounds := Rect2(900, 600, 600, 250)
	carrot.begin_board_settle(bounds, Vector2(50,0), 1.5, 6.0)
	tofu.begin_board_settle(bounds, Vector2(50,0), 1.5, 6.0)
	for i in 5:
		carrot._physics_process(1.0/60.0)
		tofu._physics_process(1.0/60.0)
	expect(is_equal_approx(carrot.board_height, tofu.board_height), "different masses share gravitational acceleration")
	for i in 90:
		carrot._physics_process(1.0/60.0)
		tofu._physics_process(1.0/60.0)
	expect(carrot.position.x > tofu.position.x + 3.0, "hard smooth root slides farther than soft tofu under identical launch")
	expect(not carrot.board_settling and not tofu.board_settling, "both settle without endless board jitter")
	carrot.set_meta("surface_sauce", {"volume_ml":3.0,"composition_ml":{"oil":3.0}})
	carrot.refresh_response()
	var lubricated: float = carrot.physics_material_override.friction
	carrot.set_meta("surface_sauce", {})
	carrot.refresh_response()
	expect(lubricated < carrot.physics_material_override.friction * 0.5, "actual oil coating reduces support friction")
	var cold: float = carrot.physics_material_override.bounce
	carrot.set_meta("cooking_heat",32.0)
	carrot.refresh_response()
	expect(carrot.physics_material_override.bounce < cold, "cooking softening reduces root rebound")
	var tomato = sample("tomato")
	var pumpkin = sample("pumpkin")
	var light_acceleration: float = Response.utensil_impulse(tomato, Vector2(100,-150),false).length()/tomato.mass
	var heavy_acceleration: float = Response.utensil_impulse(pumpkin, Vector2(100,-150),false).length()/pumpkin.mass
	expect(light_acceleration > heavy_acceleration*2.0, "finite-mass spatula moves a tomato more than a whole pumpkin")
	var bottle = sample("ketchup")
	var glass = sample("oil")
	var tube = sample("mustard")
	for i in 60:
		bottle.advance_feedback(1.0/60.0,Vector2.ZERO,1.0)
		glass.advance_feedback(1.0/60.0,Vector2.ZERO,1.0)
		tube.advance_feedback(1.0/60.0,Vector2.ZERO,1.0)
	expect(bottle.compression > 0.05 and tube.compression > bottle.compression, "tube and soft bottle have different pressure compliance")
	expect(is_zero_approx(glass.compression), "rigid oil glass never squeezes")
	var art = bottle.get_node("FoodArt")
	var rect := Rect2(-20,-39,40,78)
	expect(art.grip_vertex(Vector2(.5,0),rect)==Vector2(0,-39), "squeeze keeps nozzle anchored")
	expect(art.grip_vertex(Vector2(1,.5),rect).x < 20, "local grip indents the middle of the same painted art")
	expect(art.grip_vertex(Vector2(1,0),rect).x == 20, "cap width stays rigid while grip indents")
	for i in 100: bottle.advance_feedback(1.0/60.0,Vector2.ZERO,0.0)
	expect(bottle.compression < 0.0001, "soft bottle recovers continuously after release")
	# Real dispensing into the live kitchen checks loss = portion mass, including very small doses.
	game.world._held = bottle
	var total_before: float = bottle.mass
	expect(game.world._dispense_seasoning(0.0)==null and bottle.mass==total_before, "zero pressure volume cannot create a minimum dose")
	var dose = game.world._dispense_seasoning(0.15)
	expect(dose != null and is_equal_approx(total_before,bottle.mass+dose.mass), "sub-ml dispensing conserves packaging plus contents mass")
	var almost_empty := 0.07
	bottle.set_meta("remaining_ml", almost_empty)
	bottle.refresh_response()
	var low_mass: float = bottle.mass
	var last = game.world._dispense_seasoning(10.0)
	expect(last != null and is_equal_approx(low_mass,bottle.mass+last.mass), "last drop cannot create mass or leave negative contents")
	expect(is_equal_approx(bottle.mass,Response.profile(game._definition("ketchup")).tare_kg), "empty bottle retains packaging tare")
	expect(game.world._dispense_seasoning(1.0)==null, "empty bottle cannot dispense again")
	bottle.set_meta("remaining_ml", 80.0)
	bottle.refresh_response()
	game.world.pan.water_ml=game.world.PAN_CAPACITY_ML
	var overflow_before: float = bottle.mass
	var spill = game.world._dispense_seasoning(23.0)
	expect(spill != null and spill.get_meta("overflow",false) and is_equal_approx(overflow_before,bottle.mass+spill.mass), "overflow conserves bottle mass into the real spill")
	game.world.pan.water_ml=0.0
	game.world._held = null
	# The production held-motion update, not just a static art transform: double rotation
	# must never make the spout face away from the pan during a held action.
	game.world.clear_workspace()
	await process_frame
	for d in game.session.ingredients:
		if str(d.get("dispense_mode","")) not in ["pour","powder","squeeze"]: continue
		var container = sample(str(d.id))
		container.set_physics_process(true)
		game.world._held=container
		game.world.set_process(false)
		game.world._squeezing=true
		game.world.squeeze_pressure=0.8
		for tick in 2:
			game.world._update_held_motion(1.0/60.0,game.world.pan.point(Vector2(810,550)))
			game.world._sync_held_foreground()
		expect(game.world._squeezing and game.world._nozzle_world_position().y > container.global_position.y, "%s mouth faces pan through production held-motion update" % d.id)
		if d.id=="ketchup" and not evidence.is_empty() and DisplayServer.get_name()!="headless":
			for tick in 35:
				game.world._update_held_motion(1.0/60.0,game.world.pan.point(Vector2(810,550)))
				game.world._sync_held_foreground()
				await physics_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(evidence+"-dispensing.png")
		game.world._stop_squeezing()
		game.world._held=null
		container.queue_free()
		await process_frame
	game.world.set_process(true)
	glass = sample("oil")
	tofu = sample("tofu")
	var oil_rate := Response.flow_rate(game._definition("oil"),1.0,240.0)
	var honey_rate := Response.flow_rate(game._definition("honey"),1.0,160.0)
	expect(oil_rate > honey_rate * 2.0, "viscous honey exits more slowly than oil")
	expect(Response.flow_rate(game._definition("oil"),1.0,5.0)<oil_rate*.5, "low fill reduces gravity-pour head")
	glass.advance_feedback(1.0/60.0,Vector2(600,0),0.0)
	for i in 10: glass.advance_feedback(1.0/60.0,Vector2(600,0),0.0)
	expect(absf(glass.feedback_angle)>0.0001, "liquid inertia creates delayed bottle reaction")
	for i in 300: glass.advance_feedback(1.0/60.0,Vector2.ZERO,0.0)
	expect(absf(glass.feedback_angle)<0.0001, "sloshing dissipates after motion stops")
	# Analytic open source spring should not diverge with a different tick rate.
	var spring30 = Spring.new(1.0,0.0,17.0,.4)
	var spring120 = Spring.new(1.0,0.0,17.0,.4)
	for i in 30: spring30.update_spring_damper(0.0,1.0/30.0)
	for i in 120: spring120.update_spring_damper(0.0,1.0/120.0)
	expect(absf(spring30.pos-spring120.pos)<.00001, "open source spring has consistent fixed-step decay")
	# Native engine collision: the same round fixture isolates restitution from shape.
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(2600,420)
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(600,20)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	game.world.add_child(floor_body)
	var rebounds: Array = []
	for id in ["rock","tennis_ball"]:
		var b = sample(id)
		for child in b.get_children():
			if child is CollisionShape2D: child.disabled = true
		var c := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius=18
		c.shape=circle
		b.add_child(c)
		b.position=Vector2(2500+rebounds.size()*100,250)
		b.collision_layer=16
		b.collision_mask=1
		b.freeze=false
		b.sleeping=false
		b.set_physics_process(true)
		rebounds.append(b)
	var peaks := [0.0,0.0]
	var bounced := [false,false]
	for frame in 180:
		await physics_frame
		for i in 2:
			if rebounds[i].linear_velocity.y < -10: bounced[i]=true
			if bounced[i]: peaks[i]=maxf(peaks[i],392-rebounds[i].position.y)
	print("MEASURED native rebound pixels: stone=%.3f tennis=%.3f" % peaks)
	expect(peaks[1]>peaks[0]+12.0, "native solver gives rubber a larger rebound than stone")
	# Pause suspends support simulation.
	tofu.begin_board_settle(bounds,Vector2(40,0),2.0,10.0)
	game.world.set_controls_enabled(false)
	var paused: Vector2 = tofu.position
	tofu._physics_process(1.0/60.0)
	expect(paused==tofu.position and tofu.board_height==10.0, "modal pause freezes material response and settling")
	game.world.set_controls_enabled(true)
	await capture_materials()
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: material physics, %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func capture_materials() -> void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless": return
	# QA comparison uses the exact game renderer and untouched team textures.
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var background := ColorRect.new()
	background.color=Color("e4cfaa")
	background.size=Vector2(1600,946)
	layer.add_child(background)
	var ids := ["oil","ketchup","mustard","toothpaste"]
	for col in 4:
		var title := Label.new()
		title.text=str(game._definition(ids[col]).name)
		title.position=Vector2(230+col*345,80)
		title.add_theme_color_override("font_color",Color("39362f"))
		title.add_theme_font_size_override("font_size",28)
		layer.add_child(title)
		for row in 3:
			var art = preload("res://modules/restaurant/assets/food_art.gd").new()
			art.definition=game._definition(ids[col])
			art.compression=0.0 if row!=1 or col==0 else float(Response.profile(art.definition).compliance)
			art.position=Vector2(280+col*345,235+row*265)
			art.scale=Vector2.ONE*2.65
			layer.add_child(art)
	for row in 3:
		var text := Label.new()
		text.text=["松手","施压","回弹后"][row]
		text.position=Vector2(25,225+row*265)
		text.add_theme_font_size_override("font_size",26)
		text.add_theme_color_override("font_color",Color("39362f"))
		layer.add_child(text)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence+"-packaging.png")
	layer.queue_free()
	await process_frame
	game.world.clear_workspace()
	await process_frame
	for id in ["tomato","carrot","tofu"]:
		var b=sample(id)
		b.position=Vector2(1125+["tomato","carrot","tofu"].find(id)*80,735)
		b.set_meta("on_board",true)
		game.world.split_food(b,Vector2.RIGHT,Vector2.INF,4)
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence+"-kitchen.png")

func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
