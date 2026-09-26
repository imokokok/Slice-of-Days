extends SceneTree
## New-feature-only production GPU movie. Inputs use the engine viewport API.
## Waiting sections explicitly accelerate the whole simulation; no pressure/char injection.
var game
var foods: Array[RigidBody2D] = []
var caption: Label
var speed_label: Label
var cursor: Node2D
var frame_count := 0
var checks := 0
var previous := Vector2.ZERO
var held_mouse := false
var stage := ""
var events: Array = []
var evidence := ""

func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")

func require(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		push_error("Lid recording failed: " + message)
		quit(1)
	return ok

func label(parent: Node, text: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.position = pos
	node.size = size
	node.add_theme_font_override("font", preload("res://modules/restaurant/assets/fonts/noto_sans_sc.ttf"))
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color("fff1d2"))
	node.add_theme_color_override("font_shadow_color", Color("322e27"))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func title(text: String) -> void:
	stage = text
	caption.text = text
	events.append({"frame": frame_count, "seconds":frame_count/24.0, "stage":text})
	print("MOVIE at %.2fs: %s" % [frame_count/24.0,text])

func speed(value: float) -> void:
	Engine.time_scale = value
	speed_label.text = "加热等待 · %.0f× 加速" % value if value>1.0 else "正常速度 · 游戏实际音效"

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): evidence = args[0]
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"/private/tmp/lid_movie_%s/book.json" % Time.get_ticks_usec(),"shift_seconds":3600.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var world = game.world
	# All preparation is behind a short opening card, outside the requested clip.
	var overlay := CanvasLayer.new()
	overlay.layer = 120
	root.add_child(overlay)
	var card := ColorRect.new()
	card.color = Color("273730")
	card.size = Vector2(1600,946)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(card)
	var opening := label(card,"锅盖 · 爆锅 · 焦糊\n新增功能实机演示",Vector2(400,340),Vector2(800,220),44)
	opening.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world.audio.muted = true
	world.spawn_ingredient(game._definition("chicken"))
	world._held.position = Vector2(1220,723)
	world.drop_held()
	var source: RigidBody2D
	for body in world._foods.get_children():
		if body.get_meta("id","")=="chicken": source=body
	if not require(is_instance_valid(source),"chicken supplied from production definition"): return
	var pieces: Array[RigidBody2D] = world.split_food(source,Vector2.RIGHT)
	if not require(pieces.size()==2,"real cutting makes two equal mass pieces"): return
	for index in pieces.size():
		var body := pieces[index]
		body.set_meta("on_board",false)
		body.freeze = false
		body.position = world.pan.point(Vector2(780+index*52,553))
		body.linear_velocity = Vector2(0,20)
		foods.append(body)
	await frames(60)
	for food in foods:
		if not require(food.get_meta("enrolled",false),"prepared piece physically settles in pan"): return
	var panel := Panel.new()
	panel.position = Vector2(460,166)
	panel.size = Vector2(650,88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12,0.18,0.15,0.89)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel",style)
	overlay.add_child(panel)
	caption = label(panel,"",Vector2(20,10),Vector2(620,36),23)
	speed_label = label(panel,"",Vector2(20,47),Vector2(620,27),17)
	cursor = Node2D.new()
	cursor.z_index = 10
	overlay.add_child(cursor)
	cursor.draw.connect(func():
		cursor.draw_circle(Vector2.ZERO,8.0,Color(1.0,0.88,0.55,0.26 if held_mouse else 0.12))
		cursor.draw_arc(Vector2.ZERO,9.0,0,TAU,20,Color("fff0ba"),1.6,true)
		cursor.draw_line(Vector2(-13,0),Vector2(-5,0),Color("fff0ba"),1.3,true)
		cursor.draw_line(Vector2(0,-13),Vector2(0,-5),Color("fff0ba"),1.3,true))
	card.queue_free()
	world.audio.muted = false
	speed(1)
	title("① 锅盖斜放在独立支架，拖到锅口盖上")
	await still("rest")
	await frames(36)
	await drag(world.lid.HOME,world.pan.point(Vector2(810,582)),35)
	if not require(world.lid.covered,"engine drag seats lid"): return
	await frames(45)
	click_button(game._fire_buttons.high)
	await frames(5)
	if not require(world.cooking and world.heat_level=="high","actual stove button starts high heat"): return
	title("② 盖住持续加热，蒸汽逐渐积聚")
	speed(6)
	if not await wait_pressure(0.57,1800): return
	speed(1)
	title("盖沿冒汽、锅盖开始震动和敲击")
	await still("steam")
	await frames(100)
	title("③ 拖开锅盖，放出蒸汽")
	await drag(world.lid.position,world.lid.HOME,32)
	if not require(not world.lid.covered and world.lid.pressure==0.0,"uncover vents actual accumulated pressure"): return
	await frames(50)
	title("④ 再次盖上，继续大火加热")
	await drag(world.lid.HOME,world.pan.point(Vector2(810,582)),32)
	if not require(world.lid.covered,"lid can be reused"): return
	speed(5)
	if not await wait_pressure(0.65,1800): return
	speed(1)
	title("盖着摇锅：热汽继续积聚，食物不能穿盖")
	var handle: Vector2 = world.pan.point(Vector2(1035,578))
	mouse(handle,"down")
	await frames(2)
	mouse(handle+Vector2(0,-42),"move")
	await frames(2)
	mouse(handle+Vector2(0,-42),"up")
	await frames(35)
	if not require(world.lid.covered,"lid remains on shaking pan"): return
	title("危险升高，锅盖马上被顶起")
	if not await wait_pressure(0.84,1000): return
	await still("warning")
	var waits := 0
	while world.lid.burst_count==0 and waits<1200:
		await frame()
		waits+=1
	if not require(world.lid.burst_count==1,"sustained production heating triggers steam lid pop"): return
	title("⑤ 砰！锅盖向上炸飞、翻转，再落地回弹")
	await frames(18)
	await still("pop")
	await frames(85)
	if not require(not world.lid._flight and world.lid._settling==0.0 and world.lid.position==world.lid.HOME,"popped lid lands and can be used again"): return
	# Move the same escaped pieces back with production pickup/drop operations.
	for food in foods:
		if not is_instance_valid(food): continue
		if not world.pan.contains(food.position):
			title("把溅出的原食材放回锅里")
			await drag(food.position,world.pan.point(Vector2(790,570)),24)
			await frames(25)
	await frames(35)
	for food in foods:
		if not require(is_instance_valid(food) and food.get_meta("enrolled",false) and world.pan.contains(food.position),"same food remains/reenters the pan after pop"): return
	title("⑥ 不关火继续炒：焦黄逐渐变成焦糊")
	speed(6)
	var burning_frames := 0
	while max_char()<0.7 and burning_frames<2400:
		await frame()
		burning_frames+=1
	if not require(max_char()>=0.7,"continuous real dry heating produces visible char"): return
	speed(1)
	title("用锅铲向上翻动，露出真正烧焦的底面")
	await flip_foods()
	await frames(60)
	if not require(visible_char() >= 0.7, "spatula input exposes the truly charred contact face"): return
	title("已经炒糊：斑驳焦色、焦味提醒和轻烟")
	await still("burnt")
	await frames(170)
	click_button(game._fire_buttons.off)
	await frames(10)
	if not require(not world.cooking,"actual off button ends burner heat"): return
	title("⑦ 关火仍有余热，焦糊的部分不会恢复")
	await frames(100)
	await still("off")
	print("PASS: new lid feature movie, %d checks, %d annotated frames, %.2fs" % [checks,frame_count,frame_count/24.0])
	if not evidence.is_empty():
		var file := FileAccess.open(evidence+"-timeline.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"fps":24,"frames":frame_count,"events":events,"checks":checks,"note":"Actual production GPU recording; raw food prepared before shot; explicitly accelerated waiting; no pressure, char or temperature injection."},"\t"))
	for connection in cursor.draw.get_connections(): cursor.draw.disconnect(connection.callable)
	overlay.queue_free()
	game.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	quit(0)

func flip_foods() -> void:
	var tool = game.world.utensils[0]
	mouse(tool.home,"down")
	await frames(5)
	if not require(tool.active,"production input selects spatula"): return
	var center := Vector2.ZERO
	for food in foods: center += food.position
	center /= foods.size()
	# One rising sweep turns the neighbouring pieces once; repeated strokes
	# could turn the first piece back onto its burnt underside.
	mouse(center + Vector2(-80, 55) - tool._offset,"move")
	await frames(8)
	mouse(center + Vector2(85, -45) - tool._offset,"move")
	await frames(40)
	mouse(previous,"up")
	await frames(8)

func visible_char() -> float:
	var result := 0.0
	for food in foods:
		var s: Dictionary = food.get_meta("thermal",{})
		if not s.is_empty(): result = maxf(result, float(s.char[1-int(s.contact_face)]))
	return result

func max_char() -> float:
	var result := 0.0
	for food in foods:
		if not is_instance_valid(food): continue
		var s: Dictionary = food.get_meta("thermal",{})
		if not s.is_empty(): result=maxf(result,maxf(float(s.char[0]),float(s.char[1])))
	return result

func wait_pressure(target: float, limit: int) -> bool:
	var count := 0
	while game.world.lid.pressure<target and game.world.lid.burst_count==0 and count<limit:
		await frame()
		count+=1
	return require(game.world.lid.pressure>=target,"real heating reaches pressure warning %.2f"%target)

func still(name: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless": return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(evidence+"-"+name+".png")

func click_button(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	mouse(point,"down")
	await frames(3)
	mouse(point,"up")

func drag(from: Vector2,to: Vector2,count: int) -> void:
	mouse(from,"down")
	await frames(3)
	for i in count:
		mouse(from.lerp(to,float(i+1)/count),"move")
		await frame()
	mouse(to,"up")
	await frames(3)

func mouse(point: Vector2,kind: String) -> void:
	cursor.position = point
	cursor.queue_redraw()
	var window_point: Vector2 = root.get_final_transform()*point
	if kind=="move":
		var event := InputEventMouseMotion.new()
		event.position=window_point
		event.global_position=window_point
		event.relative=window_point-root.get_final_transform()*previous
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if held_mouse else 0
		Input.parse_input_event(event)
	else:
		held_mouse=kind=="down"
		var event := InputEventMouseButton.new()
		event.position=window_point
		event.global_position=window_point
		event.button_index=MOUSE_BUTTON_LEFT
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if held_mouse else 0
		event.pressed=held_mouse
		Input.parse_input_event(event)
	previous=point

func frames(count: int) -> void:
	for i in count: await frame()

func frame() -> void:
	await process_frame
	frame_count+=1
	if DisplayServer.get_name()!="headless": RenderingServer.force_draw(false)
