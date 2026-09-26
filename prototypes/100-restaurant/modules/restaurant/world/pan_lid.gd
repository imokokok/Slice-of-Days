extends Node2D
## Hand-painted vector vessel prop. Pressure is a time-compressed game proxy.
const Geometry = preload("res://modules/restaurant/world/pan_geometry.gd")
const HOME := Vector2(1216, 554)
const REST_ANGLE := -1.12
const REST_SCALE := Vector2(0.68, 0.9)
const FLIGHT_GRAVITY := 720.0
const LAUNCH_SPEED := 630.0
var world: Node2D
var covered := false
var active := false
var pressure := 0.0
var steam_ml := 0.0
var received_steam_ml := 0.0
var escaped_steam_ml := 0.0
var condensed_ml := 0.0
var burst_count := 0
var burst_left := 0.0
var burst_origin := Vector2.ZERO
var _flight := false
var _flight_age := 0.0
var _settling := 0.0
var _stand: Node2D
var _velocity := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _warning := 0
var _rattle_clock := 0.0
var _collision: StaticBody2D
var _paint_target: Node2D
var _shape: CollisionShape2D

func _ready() -> void:
	rest_lid()
	z_index = 34
	_stand = Node2D.new()
	_stand.position = HOME + Vector2(0, 104)
	_stand.z_index = 33
	world.add_child(_stand)
	_stand.draw.connect(_draw_stand)
	_collision = StaticBody2D.new()
	_collision.collision_layer = 1
	_collision.collision_mask = 16 | 32
	_shape = CollisionShape2D.new()
	var segment := SegmentShape2D.new()
	segment.a = Vector2(695, 536)
	segment.b = Vector2(928, 536)
	_shape.shape = segment
	_shape.disabled = true
	_collision.add_child(_shape)
	world.add_child(_collision)

func blocks(point: Vector2) -> bool:
	return covered and ((world.pan.local_point(point) - Geometry.CENTER) / (Geometry.RADIUS + Vector2(5, 8))).length() <= 1.12

func hit(point: Vector2) -> bool:
	return ((to_local(world.to_global(point)) - Vector2(0, -11)) / Vector2(165, 72)).length() <= 1.0

func close_lid() -> bool:
	if world.pan.active or world.pan.falling or world.has_active_utensil() or is_instance_valid(world._held) or world._knife_held: return false
	covered = true
	active = false
	_flight = false
	_settling = 0.0
	scale = Vector2.ONE
	_warning = 0
	_shape.set_deferred("disabled", false)
	_sync_pose()
	world.audio.play_effect("pan", 0.55)
	world.interaction.emit("notice", "锅盖合上了。留意边沿蒸汽和盖子的震动，拖开锅盖可以泄汽。")
	return true

func open_lid() -> void:
	if not covered: return
	covered = false
	pressure = 0.0
	_warning = 0
	escaped_steam_ml += steam_ml
	steam_ml = 0.0
	_shape.set_deferred("disabled", true)
	burst_origin = position
	burst_left = 0.6
	world.audio.play_effect("pan", 0.4)

func _sync_pose() -> void:
	if covered:
		position = world.pan.point(Geometry.CENTER)
		scale = Vector2.ONE
		rotation = world.pan.angle
		if pressure > 0.45:
			position += Vector2(sin(_rattle_clock * 39.0), -absf(sin(_rattle_clock * 31.0))) * smoothstep(0.45, 1.0, pressure) * 6.0
			rotation += sin(_rattle_clock * 27.0) * smoothstep(0.7, 1.0, pressure) * 0.025
		_collision.transform = world.pan.transform_pan()

func _process(_dt: float) -> void:
	_sync_pose()
	queue_redraw()

func advance(dt: float, vapor_ml: float, temperature: float, moist_food: bool) -> void:
	_rattle_clock += dt
	burst_left = maxf(0.0, burst_left - dt)
	if _flight:
		_flight_age += dt
		_velocity.y += dt * FLIGHT_GRAVITY
		position += _velocity * dt
		rotation += dt * 5.2
		# Foreshortening makes the metal disc visibly tumble in the existing 2D view.
		scale = Vector2(1.0, 0.32 + 0.68 * absf(cos(_flight_age * 5.2)))
		if position.y >= HOME.y and _velocity.y > 0.0:
			position.y = HOME.y
			_flight = false
			_settling = 0.8
			world.audio.play_effect("pan", 0.85)
	elif _settling > 0.0:
		_settling = maxf(0.0, _settling - dt)
		position.x = lerpf(position.x, HOME.x, minf(1.0, dt * 12.0))
		position.y = HOME.y - absf(sin((0.8 - _settling) * 16.0)) * _settling * 13.0
		rotation = lerp_angle(rotation, REST_ANGLE, minf(1.0, dt * 15.0))
		scale = scale.lerp(REST_SCALE, minf(1.0, dt * 15.0))
		if _settling == 0.0: rest_lid()
	if not covered: return
	# Capture only water actually removed by the authoritative thermal owner.
	received_steam_ml += vapor_ml
	steam_ml += vapor_ml
	var condensed := minf(steam_ml, steam_ml * dt * 0.08)
	condensed = minf(condensed, world.pan_free_ml())
	steam_ml -= condensed
	condensed_ml += condensed
	if condensed > 0.0:
		world.pan.water_heat = (world.pan.water_heat * world.pan.water_ml + 85.0 * condensed) / (world.pan.water_ml + condensed)
		world.pan.water_ml += condensed
	var escaped := minf(steam_ml, steam_ml * dt * 0.045)
	steam_ml -= escaped
	escaped_steam_ml += escaped
	# A loose pan lid is not a real pressure vessel. The retained heat/vapor
	# warning and lid pop are deliberately exaggerated for playful feedback.
	var source := clampf(vapor_ml / maxf(dt, 0.000001) * 1.8 + (0.25 if moist_food else 0.0), 0.0, 1.0)
	pressure = clampf(pressure + dt * (maxf(0.0, temperature - 100.0) / 3300.0 * source - 0.006), 0.0, 1.0)
	if pressure >= 0.55 and _warning == 0:
		_warning = 1
		world.interaction.emit("notice", "锅盖开始咔哒作响，蒸汽正在积聚。揭盖或减小火力。")
	if pressure >= 0.83 and _warning == 1:
		_warning = 2
		world.interaction.emit("notice", "锅盖快被顶起来了！快揭盖、关火或把锅移离炉灶。")
	if pressure >= 1.0: burst()
	if pressure > 0.5 and int(_rattle_clock * 3.0) != int((_rattle_clock - dt) * 3.0): world.audio.play_effect("pan", 0.2 + pressure * 0.3)

func agitate(distance: float) -> void:
	if covered and pressure > 0.01 and world.reactions.pan_c > 105.0:
		pressure = minf(1.0, pressure + clampf(distance / 1800.0, 0.0, 0.09))

func burst() -> void:
	if not covered: return
	burst_count += 1
	burst_origin = world.pan.point(Geometry.CENTER)
	open_lid()
	burst_left = 1.8
	_flight = true
	_flight_age = 0.0
	_settling = 0.0
	# Solve the descending time to the clear counter support. No sideways tween
	# or teleport: each fixed thermal-owner step integrates impulse and gravity.
	var flight_time := (LAUNCH_SPEED + sqrt(LAUNCH_SPEED * LAUNCH_SPEED + 2.0 * FLIGHT_GRAVITY * (HOME.y - position.y))) / FLIGHT_GRAVITY
	_velocity = Vector2((HOME.x - position.x) / flight_time, -LAUNCH_SPEED)
	world.audio.play_effect("pan", 1.0)
	world.audio.play_effect("hot_drop", 0.9)
	var index := 0
	for body in world._foods.get_children():
		if not body is RigidBody2D or body.is_queued_for_deletion() or not body.get_meta("enrolled", false) or body.get_meta("plated", false) or not world.pan.contains(body.position): continue
		body.freeze = false
		body.sleeping = false
		body.linear_velocity = Vector2(float(index % 3 - 1) * 165.0, -225.0 - float(index % 2) * 40.0)
		body.angular_velocity = float(index % 3 - 1) * 3.0
		body.set_meta("stir_until", world._time + 1.0)
		index += 1
	var spill := minf(world.pan.water_ml * 0.08, 45.0)
	world.pan.water_ml -= spill
	if spill > 0.0: world.spill_pan_water(spill, world.pan.point(Vector2(935, 620)))
	var heat_hint := "炉火还开着，赶快照顾锅里的菜！" if world.cooking else "锅里还有余热，赶快照顾锅里的菜！"
	world.interaction.emit("notice", "砰！蒸汽把锅盖顶飞了，食物和汁水溅了出来。" + heat_hint)

func rest_lid() -> void:
	position = HOME
	rotation = REST_ANGLE
	scale = REST_SCALE
	_settling = 0.0

func _draw_stand() -> void:
	_stand.draw_style_box(_stand_style(), Rect2(-59, -8, 118, 15))
	_stand.draw_line(Vector2(-36, -3), Vector2(-18, -25), Color("788574"), 5.0, true)
	_stand.draw_line(Vector2(34, -3), Vector2(22, -25), Color("788574"), 5.0, true)

func _stand_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7c8876")
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.2, 0.23, 0.17, 0.22)
	style.shadow_size = 3
	return style

func suspend() -> void:
	if active:
		active = false
		rest_lid()
		world.held_changed.emit("")

func _input(event: InputEvent) -> void:
	if not world.controls_enabled: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and hit(point) and not _flight and _settling <= 0.0 and not world.pan.active and not world.has_active_utensil() and not world._knife_held and not is_instance_valid(world._held):
			open_lid()
			active = true
			scale = Vector2.ONE
			rotation = 0.0
			_grab_offset = position - point
			world.held_changed.emit("锅盖")
			world.focus_changed.emit("锅盖", "按住把手拖到锅口盖上；拖离锅口揭盖泄汽 · Q 放回")
			get_viewport().set_input_as_handled()
		elif not event.pressed and active:
			active = false
			if world.pan.contains(position): close_lid()
			else: rest_lid()
			world.held_changed.emit("")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		position = (world.get_global_transform_with_canvas().affine_inverse() * event.position + _grab_offset).clamp(Vector2(190, 250), Vector2(1400, 735))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and active and event.pressed and event.physical_keycode in [KEY_Q, KEY_ESCAPE]:
		suspend()
		get_viewport().set_input_as_handled()

func _ellipse(center: Vector2, radius: Vector2, color: Color, line := false) -> void:
	var points := PackedVector2Array()
	for i in 65: points.append(center + Vector2(cos(i * TAU / 64.0), sin(i * TAU / 64.0)) * radius)
	if line: _paint_target.draw_polyline(points, color, 2.3, true)
	else: _paint_target.draw_colored_polygon(points, color)

func _draw() -> void:
	paint(self)

func paint(target: Node2D) -> void:
	_paint_target = target
	_paint_atmosphere()
	# Match the pan mouth projection and preserve the existing warm painted palette.
	_ellipse(Vector2(3, 9), Vector2(161, 54), Color(0.18, 0.21, 0.18, 0.19))
	_ellipse(Vector2.ZERO, Vector2(161, 53), Color("454f47"))
	_ellipse(Vector2(0, -8), Vector2(157, 54), Color("b7c8b7"))
	_ellipse(Vector2(0, -13), Vector2(150, 51), Color("d0dcca"))
	_ellipse(Vector2(0, -15), Vector2(137, 44), Color("e2e7d2"))
	_ellipse(Vector2(0, -9), Vector2(155, 53), Color("657d6b"), true)
	for i in 7:
		var x := -92.0 + i * 28.0
		_paint_target.draw_line(Vector2(x, -20), Vector2(x + 10, -23), Color(0.95, 0.96, 0.88, 0.21), 1.0, true)
	_ellipse(Vector2(0, -18), Vector2(34, 11), Color(0.21, 0.28, 0.22, 0.18))
	_paint_target.draw_style_box(_knob_style(), Rect2(-27, -42, 54, 23))
	_paint_target.draw_line(Vector2(-17, -37), Vector2(14, -37), Color("879083"), 3.0, true)
	if covered:
		var fog := clampf(steam_ml / 4.0, 0.0, 1.0)
		for i in 9:
			var p := Vector2(sin(i * 4.1) * 113, cos(i * 5.3) * 28 - 8)
			_paint_target.draw_circle(p, 2.0 + fog * 1.2, Color(0.97, 0.98, 0.93, fog * 0.65))
		if pressure > 0.1:
			for side in [-1, 1]: _steam(Vector2(side * 149, -1), pressure, false)

func _paint_atmosphere() -> void:
	if burst_left > 0.0:
		var age := 1.8 - burst_left
		for i in 9:
			var center := burst_origin + Vector2((i - 4) * (13.0 + age * 22.0), -age * (75.0 + (i % 3) * 23.0))
			_world_puff(center, Vector2(17.0 + age * 30.0, 11.0 + age * 23.0), Color(0.94, 0.96, 0.87, minf(0.5, burst_left * 0.34)))
	# Smoke is driven by actual char/temperature, remains visible with the lid off.
	if world.reactions == null: return
	for body in world._foods.get_children():
		if not body is RigidBody2D or body.is_queued_for_deletion() or not body.get_meta("enrolled", false) or body.get_meta("plated", false) or not world.pan.contains(body.position): continue
		var s: Dictionary = body.get_meta("thermal", {})
		if s.is_empty(): continue
		var charred := maxf(float(s.char[0]), float(s.char[1]))
		var strength := smoothstep(0.12, 0.65, charred) * smoothstep(110.0, 180.0, maxf(float(s.faces_c[0]), float(s.faces_c[1])))
		if strength > 0.01:
			var source: Vector2 = world.pan.point(Vector2(930, 573)) if covered else body.position
			_smoke(source, strength)

func _knob_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("4d574c")
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.18, 0.23, 0.18, 0.25)
	style.shadow_size = 3
	return style

func _steam(origin: Vector2, strength: float, pop: bool) -> void:
	var rise := fmod(_rattle_clock * (1.0 if pop else 0.75) + origin.x * 0.013, 1.0)
	var points := PackedVector2Array()
	for j in 12: points.append(origin + Vector2(sin(j * 0.55 + _rattle_clock * 2.0) * (4.0 + rise * 8.0), -j * 4.0 - rise * 20.0))
	_paint_target.draw_polyline(points, Color(0.95, 0.96, 0.87, strength * (1.0 - rise) * 0.65), 3.0 if pop else 2.0, true)

func _smoke(origin: Vector2, strength: float) -> void:
	for i in 3:
		var rise := fmod(_rattle_clock * 0.36 + i * 0.33, 1.0)
		var point := origin + Vector2(sin(rise * 5.0 + i) * 15.0, -12.0 - rise * 88.0)
		_world_puff(point, Vector2(9.0 + rise * 19.0, 5.0 + rise * 10.0), Color(0.27, 0.26, 0.23, strength * (1.0 - rise) * 0.28))

func _world_puff(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 49:
		var p := center + Vector2(cos(i * TAU / 48.0), sin(i * TAU / 48.0)) * radius
		points.append(to_local(world.to_global(p)))
	_paint_target.draw_colored_polygon(points, color)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(world): suspend()

func _exit_tree() -> void:
	if is_instance_valid(_collision): _collision.queue_free()
	if is_instance_valid(_stand): _stand.queue_free()
