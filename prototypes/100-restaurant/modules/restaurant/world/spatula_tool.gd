extends Node2D

const SauceState = preload("res://modules/restaurant/domain/sauce_state.gd")
const HOME: = Vector2(600, 493)
const PAN: = Rect2(704, 550, 222, 100)
var world: Node2D
var active: = false
var kind: = "black"
var title: = "锅铲"
var home: = Vector2(458, 615)
var _offset: = Vector2.ZERO
var _last_head: = Vector2.ZERO
var _contacts: Dictionary = {}
var _bowl_body: AnimatableBody2D
var _bowl_shapes: Array[CollisionShape2D] = []
var _rim_visual: Node2D
var _bowl_captured: Dictionary = {}
var _spoon_velocity: = Vector2.ZERO
var _residue: = {"volume_ml": 0.0, "composition_ml": {}, "mixedness": 0.0, "layered": false, "colour_model": "weighted_srgb_visual_approximation"}

func _ready() -> void :
	position = home
	z_index = 42
	if kind == "spoon": _build_spoon_bowl()
	queue_redraw()

func _build_spoon_bowl() -> void :


	_bowl_body = AnimatableBody2D.new()
	_bowl_body.name = "SpoonBowlPhysics"
	_bowl_body.collision_layer = 0
	_bowl_body.collision_mask = 16 | 32
	_bowl_body.sync_to_physics = true
	add_child(_bowl_body)
	for points in [[Vector2(-45, -12), Vector2(-39, 11)], [Vector2(-39, 11), Vector2(-12, 11)], [Vector2(-12, 11), Vector2(-5, -12)]]:
		var shape: = CollisionShape2D.new()
		var segment: = SegmentShape2D.new()
		segment.a = points[0]
		segment.b = points[1]
		shape.shape = segment
		shape.disabled = true
		_bowl_body.add_child(shape)
		_bowl_shapes.append(shape)
	_rim_visual = preload("res://modules/restaurant/world/spoon_rim.gd").new()
	_rim_visual.name = "SpoonFrontRim"
	_rim_visual.tool = self
	_rim_visual.visible = false
	add_child(_rim_visual)

func _set_bowl_enabled(value: bool) -> void :
	if is_instance_valid(_bowl_body): _bowl_body.collision_mask = 16 | 32 if value else 0
	for shape in _bowl_shapes: shape.set_deferred("disabled", not value)
	if is_instance_valid(_rim_visual): _rim_visual.visible = value

func _draw() -> void :
	paint(self)

func paint(target: Node2D) -> void :
	var tex: = preload("res://modules/restaurant/assets/sprite_library.gd").gear({"black": 3, "wooden": 4, "spoon": 5}[kind])
	if tex: target.draw_texture_rect(tex, Rect2(-42, -20, 134, 40), false)
	if kind == "spoon" and float(_residue.get("volume_ml", 0.0)) > 0.01:
		target.draw_circle(Vector2(-25, 4), clampf(3.0 + sqrt(float(_residue.volume_ml)) * 1.6, 3.0, 10.0), Color("a75d3d").lerp(Color("d0965a"), float(_residue.get("mixedness", 0.0)) * 0.4))

func _input(event: InputEvent) -> void :
	if event is InputEventMouseButton and active and kind == "spoon" and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		rotation = clampf(rotation + deg_to_rad(10) * (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), -0.85, 0.85)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and active:
			release_tool()
			get_viewport().set_input_as_handled()
		elif event.pressed and world.controls_enabled and not world._knife_held and not world.pan.active and not world.has_active_utensil() and not is_instance_valid(world._held):
			var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
			if Rect2(position + Vector2(-42, -20), Vector2(134, 40)).has_point(point):
				active = true


				rotation = -0.22 if kind == "spoon" else - PI / 3
				_offset = - Vector2(54, 3).rotated(rotation)
				position = point + _offset
				_last_head = position
				_contacts.clear()
				world.held_changed.emit(title)
				world.focus_changed.emit(title, "轻移承托食物，快速甩动会滑出；滚轮倾勺" if kind == "spoon" else "按住拖入锅中，左右推拌、向上翻动；松开放回锅边 · Q 归位")
				_set_bowl_enabled(true)
				queue_redraw()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		if not world.controls_enabled or not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			release_tool()
		else:
			var point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
			var previous_position: = position
			position = (point + _offset).clamp(Vector2(80, 140), Vector2(1530, 785))
			_spoon_velocity = (position - previous_position) * 30.0
			stir_sweep(_last_head, position)
			_last_head = position
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and active:
		if event.pressed and event.physical_keycode in [KEY_Q, KEY_ESCAPE]: release_tool()

		if event.physical_keycode in [KEY_Q, KEY_E, KEY_G]: get_viewport().set_input_as_handled()

func release_tool() -> void :
	if not active: return
	active = false
	_set_bowl_enabled(false)
	for carried in _bowl_captured.values():
		if is_instance_valid(carried): carried.set_meta("container_location", "pan" if world.pan.contains(carried.position) else "worktop")
	_bowl_captured.clear()
	_spoon_velocity = Vector2.ZERO
	rotation = 0
	position = home
	_contacts.clear()
	world.held_changed.emit("")
	world.focus_changed.emit(title, "按住拖入锅中，接触食物后操作")
	queue_redraw()

func stir_sweep(from: Vector2, to: Vector2) -> int:
	if not active or not world.controls_enabled or from.distance_to(to) < 3:
		return 0
	var count: = 0
	var now: = Time.get_ticks_msec()
	for body in world._foods.get_children():
		if not body is RigidBody2D or body.is_queued_for_deletion() or body.freeze:
			continue
		if body == world._held or body.get_meta("is_container", false) or body.get_meta("plated", false):
			continue
		var center: Vector2 = world.to_local(body.global_position)
		if not world.pan.contains(center) and float(body.get_meta("stir_until", 0)) <= world._time: continue
		if body.get_meta("overflow", false): continue
		var head_offset: = Vector2(-24 if kind == "spoon" else -14, 0).rotated(rotation)
		var touch: Vector2 = Geometry2D.get_closest_point_to_segment(center, from + head_offset, to + head_offset)
		if touch.distance_to(center) > 35: continue
		var key: int = body.get_instance_id()
		if now - int(_contacts.get(key, -1000)) < 160: continue
		_contacts[key] = now
		var direction: = signf(to.x - from.x)
		if is_zero_approx(direction): direction = 1.0 if center.x < 809 + world.pan.offset.x else -1.0
		if center.x < 750 + world.pan.offset.x: direction = 1.0
		elif center.x > 868 + world.pan.offset.x: direction = -1.0
		var strength: = clampf(0.22 / body.mass, 0.7, 1.25)
		var speed: = clampf(from.distance_to(to) * 2.2, 85, 180) * strength
		var lift: = clampf((150 + maxf(0, from.y - to.y) * 1.2) * strength, 140, 220)


		var target: = Vector2(direction * speed * (0.48 if kind == "spoon" else 1.0), - lift * (0.35 if kind == "spoon" else 1.0))
		body.sleeping = false
		body.apply_central_impulse((target - body.linear_velocity) * body.mass)
		body.angular_velocity = direction * (0.8 if kind == "spoon" else 3.0)
		body.set_meta("stir_until", world._time + 0.8)
		count += 1
		world.audio.play_food_stir(body, kind)
		_exchange_liquid(body, from.distance_to(to))
	return count

func _exchange_liquid(body: RigidBody2D, speed: float) -> void :
	if body.has_meta("liquid_state"):
		var state: Dictionary = body.get_meta("liquid_state")
		SauceState.agitate(state, clampf(speed / 900.0, 0.01, 0.16))
		body.set_meta("liquid_state", state)
		var art = body.get_node_or_null("SauceBlob")
		if art: art.liquid_state = state;art.queue_redraw()
		return
	var coating: Dictionary = body.get_meta("surface_sauce", {"volume_ml": 0.0, "composition_ml": {}, "mixedness": 0.0, "layered": false})
	if kind == "spoon" and float(_residue.get("volume_ml", 0.0)) > 0.01:
		SauceState.transfer(_residue, coating, minf(0.24, float(_residue.volume_ml)))
	for candidate in world._foods.get_children():
		if candidate == body or not candidate is RigidBody2D or not candidate.has_meta("liquid_state"): continue
		if candidate.global_position.distance_to(body.global_position) > 42.0: continue
		var liquid: Dictionary = candidate.get_meta("liquid_state")
		SauceState.transfer(liquid, coating, minf(0.18 if kind == "spoon" else 0.09, float(liquid.get("volume_ml", 0.0))))
		candidate.set_meta("liquid_state", liquid)
		candidate.set_meta("volume_ml", liquid.get("volume_ml", 0.0))
	body.set_meta("surface_sauce", coating)
	queue_redraw()

func liquid_inventory() -> Dictionary:
	return _residue.duplicate(true)

func bowl_contains(body: RigidBody2D) -> bool:
	if kind != "spoon" or not active or not is_instance_valid(body): return false
	if _bowl_captured.has(body.get_instance_id()): return true
	var p: = to_local(body.global_position)
	return ((p - Vector2(-25, 1)) / Vector2(31, 20)).length() <= 1.0

func bowl_contents() -> Array:
	var result: Array = []
	if kind != "spoon" or not active: return result
	for body in world._foods.get_children():
		if body is RigidBody2D and bowl_contains(body): result.append(body)
	return result

func _physics_process(_delta: float) -> void :
	if kind != "spoon" or not active or not world.controls_enabled: return
	var center: = to_global(Vector2(-25, 1))
	for body in world._foods.get_children():
		if not body is RigidBody2D or body.freeze or body == world._held or body.get_meta("is_container", false) or body.get_meta("plated", false): continue
		var key: int = body.get_instance_id()
		var normalized: = ((to_local(body.global_position) - Vector2(-25, 1)) / Vector2(31, 20)).length()
		if normalized <= 1.05:
			var first_capture: = not _bowl_captured.has(key)
			_bowl_captured[key] = body
			body.set_meta("container_location", "spoon")
			if first_capture and body.has_meta("liquid_state"):
				var liquid: Dictionary = body.get_meta("liquid_state")
				SauceState.transfer(liquid, _residue, minf(0.8, float(liquid.get("volume_ml", 0.0))))
				body.set_meta("liquid_state", liquid)
				body.set_meta("volume_ml", liquid.get("volume_ml", 0.0))
				queue_redraw()
		if not _bowl_captured.has(key): continue



		if normalized > 1.75 or absf(rotation) > 0.72 or _spoon_velocity.length() > 360:
			_bowl_captured.erase(key)
			body.set_meta("container_location", "pan" if world.pan.contains(body.position) else "worktop")
			continue
		var desired: Vector2 = _spoon_velocity.limit_length(220) + (center - body.global_position) * 10.0
		var delta_v: Vector2 = (desired - body.linear_velocity).limit_length(180)
		body.apply_central_impulse(delta_v * body.mass * 0.42)
		body.angular_velocity *= 0.82
	_spoon_velocity *= 0.78

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(world): release_tool()
