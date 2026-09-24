extends SceneTree
var game
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 120
	call_deferred("run")
func run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.world.spawn_ingredient(game._definition("tomato"))
	var food = game.world._held
	game.world.drop_into_pan()
	await create_timer(0.6).timeout
	var initial: Vector2 = food.position
	mouse(Vector2(1037,654), MOUSE_BUTTON_LEFT, true)
	motion(Vector2(850,250))
	await process_frame
	await physics_frame
	await process_frame
	expect(game.world.pan.offset.y < -300, "pan follows pointer vertically")
	expect(food.position.y < initial.y - 300, "contents follow vertical lift")
	expect(not game.world.pan.on_stove(), "raised pan does not receive stove heat")
	mouse(Vector2(850,250), MOUSE_BUTTON_LEFT, false)
	await process_frame
	expect(game.world.pan.falling, "released raised pan falls under gravity")
	await create_timer(1.3).timeout
	expect(not game.world.pan.falling and absf(game.world.pan.offset.y-game.world.pan.HOME.y) < 0.1, "pan lands on counter and stops following pointer")
	expect(game.session.dish.size() == 1, "gravity landing preserves ingredients")
	var handle: Vector2 = game.world.pan.point(Vector2(1000,566))
	mouse(handle, MOUSE_BUTTON_LEFT, true)
	motion(Vector2(1510,430))
	mouse(Vector2(1510,430), MOUSE_BUTTON_RIGHT, true)
	await create_timer(2.3).timeout
	expect(game.world.pan.angle > 1.5, "right hold tilts held pan")
	expect(food.get_meta("plated", false), "gravity pours original food into plate")
	expect(game.session.dish.size() == 1 and int(game.session.dish[0].physics_id) == food.get_instance_id(), "poured food retains identity without duplication")
	mouse(Vector2(1210,220), MOUSE_BUTTON_RIGHT, false)
	mouse(Vector2(1210,220), MOUSE_BUTTON_LEFT, false)
	game.world.audio.muted = true
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	for f in failures: push_error(f)
	print("%s free pan %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
func expect(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures.append(text)
func mouse(p:Vector2,button:MouseButton,down:bool)->void:
	var e:=InputEventMouseButton.new()
	e.position=root.get_final_transform()*p
	e.global_position=e.position
	e.button_index=button
	e.pressed=down
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if down or button==MOUSE_BUTTON_RIGHT else 0
	Input.parse_input_event(e)
func motion(p:Vector2)->void:
	var e:=InputEventMouseMotion.new()
	e.position=root.get_final_transform()*p
	e.global_position=e.position
	e.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
