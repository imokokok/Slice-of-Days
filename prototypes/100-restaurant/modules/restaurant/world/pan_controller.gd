extends Node2D

const SINK_X: = 211.0
const HOME: = Vector2(-11, 100)
const ART_SCALE: = Vector2(1.25, 1.35)
const PIVOT: = Vector2(809, 599)
var world: Node2D
var active: = false
var offset: = Vector2.ZERO
var water_ml: = 0.0
var water_heat: = 0.0
var overflow_water_ml: = 0.0
var faucet_amount: = 0.0
var faucet_on: bool:
	get: return faucet_amount >= 0.45
	set(value): faucet_amount = 1.0 if value else 0.0
var faucet_dragging: = false
var _faucet_drag_start_y: = 0.0
var _faucet_drag_start_amount: = 0.0
var _grab_point: = Vector2.ZERO
var _pointer: = Vector2.ZERO
var angle: = 0.0
var falling: = false
var _fall_speed: = 0.0
var _tipping: = false
var _carried: Array = []
var _last_transport: = 0
var pan_back: Node2D
var pan_front: Node2D
var faucet_art: Node2D

func _ready() -> void :
	z_index = 3
	pan_back = preload("res://modules/restaurant/world/pan_art.gd").new()
	pan_back.controller = self
	pan_back.z_index = 4
	world.add_child(pan_back)
	pan_front = preload("res://modules/restaurant/world/kitchen_foreground.gd").new()
	pan_front.z_index = 9
	world.add_child(pan_front)
	faucet_art = preload("res://modules/restaurant/world/sink_faucet.gd").new()
	faucet_art.controller = self
	faucet_art.z_index = 11
	world.add_child(faucet_art)

func on_stove() -> bool:
	return absf(offset.x - HOME.x) < 45 and absf(offset.y - HOME.y) < 4 and absf(angle) < 0.1 and not active and not falling

func under_tap() -> bool:
	return above_sink() and absf(angle) < 0.1 and not active and not falling

func above_sink() -> bool:
	return absf(809 + offset.x - SINK_X) < 70 and absf(offset.y - HOME.y) < 30

func _process(delta: float) -> void :
	if world.controls_enabled:
		if active and _tipping: set_angle(move_toward(angle, deg_to_rad(110), delta * 3.8))
		if faucet_on and under_tap():
			var incoming: = delta * 180 * faucet_amount
			var accepted: = minf(incoming, maxf(0.0, 1500.0 - water_ml))
			water_heat *= water_ml / maxf(water_ml + accepted, 1)
			water_ml += accepted
			overflow_water_ml += incoming - accepted
		if world.cooking and on_stove() and water_ml > 0:
			water_heat = minf(100, water_heat + delta * 7)
			if water_heat >= 99: water_ml = maxf(0, water_ml - delta * 8)
		else: water_heat = maxf(0, water_heat - delta * 2)
	pan_back.queue_redraw()
	faucet_art.queue_redraw()
	queue_redraw()

func _input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and faucet_dragging:
		faucet_dragging = false
		world.audio.play_effect("tap")
		world.interaction.emit("notice", "水龙头已转开，把锅放在水流下接水。" if faucet_on else "水龙头已回转关闭。")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and faucet_dragging:
		var faucet_pointer: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		faucet_amount = clampf(_faucet_drag_start_amount + (faucet_pointer.y - _faucet_drag_start_y) / 62.0, 0.0, 1.0)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and active:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_tipping = event.pressed
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			set_angle(angle + deg_to_rad(15) * (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		if not event.pressed and active:
			move_pointer(p)
			release_pan()
			get_viewport().set_input_as_handled()
		elif event.pressed and world.controls_enabled and not is_instance_valid(world._held) and not world._knife_held and not world.has_active_utensil():
			if Rect2(268, 565, 62, 66).has_point(p):
				faucet_dragging = true
				_faucet_drag_start_y = p.y
				_faucet_drag_start_amount = faucet_amount
				world.interaction.emit("notice", "按住把手向下转开，向上回转关闭。")
				get_viewport().set_input_as_handled()
			elif Rect2(80, 748, 270, 32).has_point(p) and under_tap():
				water_ml = 0
				water_heat = 0
				overflow_water_ml = 0
				world.audio.play_effect("drain")
				world.interaction.emit("notice", "锅中的水倒入了水槽。")
				get_viewport().set_input_as_handled()
			elif can_grab(p):
				grab(p)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		move_pointer(world.get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and active and event.pressed:
		if event.physical_keycode in [KEY_Q, KEY_ESCAPE]: release_pan()
		elif event.physical_keycode in [KEY_A, KEY_D]:
			set_angle(angle + deg_to_rad(15) * (1 if event.physical_keycode == KEY_D else -1))
			get_viewport().set_input_as_handled()

func transform_pan() -> Transform2D:
	var basis: = Transform2D(angle, ART_SCALE, 0, Vector2.ZERO)
	basis.origin = PIVOT + offset - basis * PIVOT
	return basis

func point(base_point: Vector2) -> Vector2:
	return transform_pan() * base_point

func local_point(p: Vector2) -> Vector2:
	return transform_pan().affine_inverse() * p

func contains(p: Vector2) -> bool:
	return Rect2(696, 546, 231, 102).has_point(local_point(p))

func can_grab(p: Vector2) -> bool:
	var local: = local_point(p)
	if Rect2(925, 548, 140, 35).has_point(local): return true
	var rim: = (local - Vector2(810, 570)) / Vector2(116, 32)
	return rim.length() > 0.86 and rim.length() < 1.12 and world._food_at(p) == null

func grab(p: Vector2) -> void :
	active = true
	falling = false
	_fall_speed = 0
	_tipping = false
	_pointer = p
	_grab_point = local_point(p)
	_carried.clear()
	for body in world._foods.get_children():
		if body.get_meta("enrolled", false) and not body.get_meta("plated", false) and contains(body.position):
			_carried.append(body)
			body.set_meta("pan_origin", local_point(body.position))
			body.set_meta("pan_rotation", body.rotation - angle)
			body.freeze = true
	world.held_changed.emit("平底锅")
	world.focus_changed.emit("平底锅", "自由拖动 · 按住右键倾倒 / 滚轮调角度 · 松手落下")

func move_pointer(p: Vector2) -> void :
	_pointer = p
	move_to(p - PIVOT - ((_grab_point - PIVOT) * ART_SCALE).rotated(angle))

func move_to(destination: Variant) -> void :

	var desired: Vector2 = destination if destination is Vector2 else Vector2(float(destination), 0)
	offset = desired.clamp(Vector2(-650, -520), Vector2(610, 150))
	_last_transport = Time.get_ticks_msec()
	var pose: = transform_pan()
	pan_back.transform = pose
	pan_front.transform = pose
	world._pan_area.transform = Transform2D(angle, ART_SCALE, 0, point(PIVOT))
	for wall in world._pan_walls: wall.transform = pose
	for body in _carried:
		if is_instance_valid(body):
			var target: = point(body.get_meta("pan_origin"))
			body.position = target
			body.set_deferred("position", target)
			body.rotation = float(body.get_meta("pan_rotation", 0)) + angle
	world._stations["cook"] = pose * Rect2(677, 535, 265, 125)
	world._update_landed_seasoning()

func set_angle(value: float) -> void :
	var was_below_pour_angle := absf(angle) < deg_to_rad(85)
	angle = clampf(value, deg_to_rad(-125), deg_to_rad(125))
	move_pointer(_pointer)
	if absf(angle) >= deg_to_rad(85):
		if was_below_pour_angle and water_ml > 0.0:
			var poured_ml := water_ml
			water_ml = 0.0
			water_heat = 0.0
			if above_sink():
				world.audio.play_effect("drain")
				world.interaction.emit("notice", "锅里的水顺着低侧锅沿倒进了水槽。")
			else:
				overflow_water_ml += poured_ml
				world.spill_pan_water(poured_ml, point(Vector2(810, 610)) + Vector2(0, 48))
				world.audio.play_effect("pour")
		for body in _carried:
			if not is_instance_valid(body): continue
			body.freeze = false
			body.sleeping = false
			body.linear_velocity = Vector2.ZERO
			body.set_meta("poured", true)
		_carried.clear()

func release_pan() -> void :
	if not active: return
	active = false
	_tipping = false
	angle = 0
	move_to(Vector2(offset.x, minf(offset.y, HOME.y)))
	falling = offset.y < HOME.y
	_fall_speed = 0
	if not falling: _land()
	world.held_changed.emit("")

func _physics_process(delta: float) -> void :
	if not world.controls_enabled: return
	if active:
		for body in _carried:
			if is_instance_valid(body):
				body.position = point(body.get_meta("pan_origin"))
				body.set_deferred("position", body.position)
	if falling:
		_fall_speed += 1000 * delta
		move_to(offset + Vector2(0, _fall_speed * delta))
		if offset.y >= HOME.y:
			move_to(Vector2(offset.x, HOME.y))
			_land()

func _land() -> void :
	falling = false
	_last_transport = Time.get_ticks_msec()
	for body in _carried:
		if is_instance_valid(body):
			body.position = point(body.get_meta("pan_origin"))
			body.set_deferred("position", body.position)
			body.freeze = false
			body.sleeping = false
	_carried.clear()
	world.audio.play_effect("pan")

func is_carrying(body: Node) -> bool:
	return _carried.has(body)

func transporting() -> bool:
	return active or falling or Time.get_ticks_msec() - _last_transport < 100

func suspend() -> void :
	release_pan()
	if falling:
		move_to(Vector2(offset.x, HOME.y))
		_land()
	faucet_on = false
	faucet_dragging = false

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(world): suspend()

func _draw() -> void :
	pass

func _box(color: Color) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
