extends Node2D


signal interaction(action: String, payload: String)
signal focus_changed(title: String, hint: String)
signal food_entered_pan(id: String, cut: bool, body: RigidBody2D)
signal food_removed_from_pan(body: RigidBody2D)
signal held_changed(title: String)

var controls_enabled: = false
var cooking: = false
var heat_level: = "medium"
var plated: = false
var camera: Camera2D
var _held: RigidBody2D
var _foods: Node2D
var _pan_area: Area2D
var _pan_walls: Array = []
var pan: Node2D
var plate: Node2D
var cutting_board: Node2D
var utensils: Array[Node2D] = []
var plate_presentation: Dictionary = {}
var audio: Node
var _customer: Dictionary = {}
var _backdrop: Node2D
var _font: Font
var _time: = 0.0
var _focus: = ""
var _dragging: = false
var _food_drag_offset: = Vector2.ZERO
var _food_drag_origin: = Vector2.ZERO
var _food_drag_moved: = false
var _food_drag_from_storage: = false
var _drag_group: Array[Dictionary] = []
var _food_art: Script
var _held_foreground: Node2D
var _held_proxy: Node2D
var _held_proxy_source: Node2D
var _sound: AudioStreamPlayer
var _chop_flash: = 0.0
var _last_mouse: = Vector2.ZERO
var _mouse_velocity: = Vector2.ZERO
var _squeezing: = false
var _squeeze_elapsed: = 0.0
var _squeeze_dispensed: = false
var squeeze_pressure: = 0.0
var _squeeze_distance: = 0.0
var _squeeze_last_nozzle: = Vector2.ZERO
const SauceState = preload("res://modules/restaurant/domain/sauce_state.gd")
var _knife_held: = false
var _spatula: Node2D
var _knife_cutting: = false
var _knife_visual: Node2D
var _previous_blade_tip: = Vector2.ZERO
var _knife_rest_position: = Vector2(1407, 730)
var _knife_last_valid_rest: = Vector2(1407, 730)
var _knife_drag_offset: = Vector2.ZERO
var _poster_canvas: Control
var _stations: = {
	"pantry": Rect2(40, 190, 300, 310), 
	"chop": Rect2(1030, 680, 390, 108), 
	"cook": Rect2(677, 535, 265, 125), 
	"plate": Rect2(1340, 535, 240, 95), 

	"talk": Rect2(720, 210, 250, 205), 

	"trash": Rect2(1440, 825, 130, 60)
}
var _titles: = {"pantry": "食材架", "chop": "料理台", "cook": "平底锅", "plate": "装盘台", "serve": "出餐窗口", "talk": "今日客人", "cookbook": "公共菜谱", "poster": "海报工作台", "trash": "回收桶"}
var _hints: = {"pantry": "挑选食材", "chop": "食材放稳后，按住刀柄拖动切开", "cook": "空手点击开火 / 离火；食材拖入锅中", "plate": "放大餐盘，自由摆放、淋酱与拍照", "serve": "给客人上菜", "talk": "聊聊口味与忌口", "cookbook": "命名 · 署名 · 分享", "poster": "涂鸦 · 拼贴 · 招呼街坊", "trash": "丢弃手中食材 / 清空料理"}

func _ready() -> void :
	_backdrop = preload("res://modules/restaurant/world/kitchen_backdrop.gd").new()
	_backdrop.z_index = -5
	add_child(_backdrop)
	var bundled_font: = FontVariation.new()
	bundled_font.base_font = preload("res://modules/restaurant/assets/fonts/noto_sans_sc.ttf")
	bundled_font.variation_opentype = {2003265652: 500.0}
	_font = bundled_font
	if ResourceLoader.exists("res://modules/restaurant/assets/food_art.gd"):
		_food_art = load("res://modules/restaurant/assets/food_art.gd")
	_foods = Node2D.new()
	_foods.name = "PhysicalIngredients"
	_foods.z_index = 5
	add_child(_foods)
	_foods.child_entered_tree.connect(_connect_food_audio)
	var held_layer: = CanvasLayer.new()
	held_layer.name = "HeldIngredientForeground"
	held_layer.layer = 2
	add_child(held_layer)
	_held_foreground = preload("res://modules/restaurant/world/held_foreground.gd").new()
	_held_foreground.world = self
	_held_foreground.visible = false
	held_layer.add_child(_held_foreground)
	var surfaces: = preload("res://modules/restaurant/world/worktop_art.gd").new()
	surfaces.z_index = -1
	add_child(surfaces)
	cutting_board = preload("res://modules/restaurant/world/cutting_board.gd").new()
	cutting_board.world = self
	add_child(cutting_board)
	_build_physics()
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -17
	add_child(_sound)
	_knife_visual = preload("res://modules/restaurant/world/knife_tool.gd").new()
	_knife_visual.name = "ChefKnife"
	_knife_visual.z_index = 40
	_knife_visual.position = _knife_rest_position
	_knife_visual.visible = true
	add_child(_knife_visual)
	_spatula = preload("res://modules/restaurant/world/spatula_tool.gd").new()
	_spatula.name = "CookingSpatula"
	_spatula.world = self
	_spatula.home = Vector2(458, 615)
	add_child(_spatula)
	utensils.append(_spatula)
	for variant in [["wooden", "木铲", Vector2(458, 531)], ["spoon", "木勺", Vector2(458, 573)]]:
		var tool = preload("res://modules/restaurant/world/spatula_tool.gd").new()
		tool.world = self
		tool.kind = variant[0]
		tool.title = variant[1]
		tool.home = variant[2]
		add_child(tool)
		utensils.append(tool)
	audio = preload("res://modules/restaurant/world/kitchen_audio.gd").new()
	add_child(audio)
	pan = preload("res://modules/restaurant/world/pan_controller.gd").new()
	pan.world = self
	add_child(pan)
	pan.move_to(pan.HOME)
	plate = preload("res://modules/restaurant/world/plate_controller.gd").new()
	plate.world = self
	add_child(plate)
	var floating: = preload("res://modules/restaurant/world/floating_tools.gd").new()
	floating.world = self
	add_child(floating)
	var plate_ink: = preload("res://modules/restaurant/world/plate_sauce.gd").new()
	plate_ink.world = self
	plate_ink.z_index = 10
	add_child(plate_ink)
	_last_mouse = get_global_mouse_position()
	set_process(true)

func _build_physics() -> void :

	_static_box(Vector2(800, 870), Vector2(1600, 174))
	_static_box(Vector2(-18, 450), Vector2(32, 900))
	_static_box(Vector2(1608, 450), Vector2(32, 900))
	# The visible worktop is a real support surface.  Loose bottles and unused
	# ingredients settle here instead of falling behind the lower UI.
	_static_segment(Vector2(365, 718), Vector2(1590, 718), false)


	_static_segment(Vector2(55, 610), Vector2(78, 686), false)
	_static_segment(Vector2(78, 686), Vector2(342, 686), false)
	_static_segment(Vector2(342, 686), Vector2(365, 610), false)


	_static_segment(Vector2(695, 566), Vector2(732, 599))
	_static_segment(Vector2(732, 599), Vector2(884, 599))
	_static_segment(Vector2(884, 599), Vector2(925, 566))
	_pan_area = Area2D.new()
	_pan_area.name = "PanInterior"
	_pan_area.position = Vector2(809, 599)
	_pan_area.collision_layer = 0
	_pan_area.collision_mask = 16 | 32
	var shape: = RectangleShape2D.new()
	shape.size = Vector2(174, 58)
	var collision: = CollisionShape2D.new()
	collision.shape = shape
	_pan_area.add_child(collision)
	_pan_area.body_entered.connect(_on_pan_entered)
	_pan_area.body_exited.connect(_on_pan_exited)
	add_child(_pan_area)

func _draw() -> void :
	pass

func _process(delta: float) -> void :
	_backdrop.set("cooking", cooking)
	_backdrop.set("customer", _customer)
	_backdrop.set("time", _time)
	_backdrop.set("knife_held", _knife_held)
	_backdrop.queue_redraw()
	_time += delta
	_chop_flash = maxf(0, _chop_flash - delta)
	var mouse: = get_global_mouse_position()
	_mouse_velocity = (mouse - _last_mouse) / maxf(delta, 0.001)
	_last_mouse = mouse
	if _squeezing:
		squeeze_pressure = move_toward(squeeze_pressure, 1.0, delta * 3.2)
	else:
		squeeze_pressure = move_toward(squeeze_pressure, 0.0, delta * 5.0)
	if is_instance_valid(_held) and controls_enabled:
		_held.global_position = Vector2(clampf(mouse.x, 727.0 + pan.offset.x, 895.0 + pan.offset.x), minf(mouse.y, 526.0 + pan.offset.y)) if _squeezing else mouse + (_food_drag_offset if _dragging else Vector2.ZERO)
		if _squeezing:
			var mode: = get_dispense_mode(_held.get_meta("definition", {}))
			_held.rotation = PI + (sin(_time * 25.0) * 0.1 if mode == "powder" else 0.0)
			if not _squeeze_region().has_point(mouse):
				_stop_squeezing()
			else:
				_squeeze_elapsed += delta
				var nozzle_now: = _nozzle_world_position()
				_squeeze_distance += nozzle_now.distance_to(_squeeze_last_nozzle)
				_squeeze_last_nozzle = nozzle_now
				var interval: = lerpf(0.28, 0.075, squeeze_pressure)
				if _squeeze_elapsed >= interval:
					var elapsed_for_flow: = _squeeze_elapsed
					_squeeze_elapsed = 0.0
					var flow_rate: = float(_held.get_meta("definition", {}).get("flow_ml_s", 18.0 if mode == "squeeze" else 26.0))
					var volume_ml: = maxf(0.18, flow_rate * elapsed_for_flow * maxf(0.12, squeeze_pressure))
					if is_instance_valid(_dispense_seasoning(volume_ml)):
						_squeeze_dispensed = true
	if controls_enabled:
		var next: = ""
		for action in _stations:
			if _stations[action].has_point(mouse):
				next = action
		if next != _focus:
			_focus = next
			if is_instance_valid(_spatula) and has_active_utensil():
				for utensil in utensils:
					if utensil.active:
						focus_changed.emit(utensil.title, "轻移承托、滚轮倾勺；快速甩动会滑出" if utensil.kind == "spoon" else "按住拖入锅中推拌、向上翻动；松开放回锅边")
						break
			elif _knife_held:
				focus_changed.emit("主厨刀", "按住并拖动刀刃切食材；松开就放下")
			elif _held_is_sauce_bottle():
				focus_changed.emit(get_held_name(), get_held_operation_hint())
			else:
				focus_changed.emit(str(_titles.get(next, "")), str(_hints.get(next, "")))
	_sync_held_foreground()
	_update_landed_seasoning()
	audio.update_kitchen(self)
	queue_redraw()

func _physics_process(_delta: float) -> void :
	if not controls_enabled or not is_instance_valid(_pan_area):
		return


	for body in _pan_area.get_overlapping_bodies():
		if is_instance_valid(body) and pan.contains(body.position):
			_on_pan_entered(body)
	for body in _foods.get_children():
		if body.is_queued_for_deletion() or body == _held or body.get_meta("plated", false): continue
		if body.get_meta("poured", false) and not pan.contains(body.position) and plate.hit_rect().has_point(body.position):
			_land_on_plate(body)
		elif body.get_meta("enrolled", false) and not pan.contains(body.position):
			_on_pan_exited(body)

func _land_on_plate(body: RigidBody2D) -> void :
	if body.get_meta("overflow", false) or body.get_meta("is_container", false): return
	body.set_meta("plated", true)
	body.set_meta("pending", false)
	if not body.get_meta("enrolled", false):
		body.set_meta("pending", true)
		food_entered_pan.emit(str(body.get_meta("id")), bool(body.get_meta("cut", false)), body)
	if body.get_meta("enrolled", false):
		body.set_deferred("freeze", true)
		_update_plated_flag()
		interaction.emit("notice", "食物已经倒进盘中，可以继续倒菜或直接出餐。")
	else: body.set_meta("plated", false)

func _input(event: InputEvent) -> void :

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _knife_held:
			_release_knife()
			get_viewport().set_input_as_handled()
			return
		if _squeezing:
			_stop_squeezing()
			get_viewport().set_input_as_handled()
			return
		if _dragging:
			_move_dragged_food(get_global_transform_with_canvas().affine_inverse() * event.position)
			_finish_food_drag()
			get_viewport().set_input_as_handled()
			return
	if controls_enabled and _dragging and event is InputEventMouseMotion:
		_move_dragged_food(get_global_transform_with_canvas().affine_inverse() * event.position)
	if controls_enabled and _knife_held and event is InputEventMouseMotion:


		_move_knife(get_global_transform_with_canvas().affine_inverse() * event.position)

func _unhandled_input(event: InputEvent) -> void :
	if not controls_enabled or pan.active or plate.active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and _squeezing:
			_stop_squeezing()
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			if is_instance_valid(_held):
				if _held_is_sauce_bottle() and _squeeze_region().has_point(get_global_mouse_position()):
					_squeezing = true
					_squeeze_elapsed = 0.0
					_squeeze_dispensed = false
					_squeeze_distance = 0.0
					_squeeze_last_nozzle = _nozzle_world_position()
					_dragging = false
					get_viewport().set_input_as_handled()
					return
				elif _stations.chop.has_point(get_global_mouse_position()):
					drop_held(false)
				elif _focus == "trash":
					discard_held()
				else:
					drop_held(false)
			else:
				var pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
				var food: = _food_at(pointer)
				if _wipe_spill_at(pointer):
					get_viewport().set_input_as_handled()
				elif _knife_handle_rect().has_point(pointer):
					pickup_knife(pointer)
					get_viewport().set_input_as_handled()
				elif food:
					_pickup(food)
					begin_food_drag(pointer)
					get_viewport().set_input_as_handled()
				elif _knife_grab_rect().has_point(pointer):
					pickup_knife(pointer)
					get_viewport().set_input_as_handled()
				elif not _focus.is_empty():
					interaction.emit(_focus, "")
		elif _dragging:
			_dragging = false
			if is_instance_valid(_held):
				if _focus == "chop":
					chop_held()
					drop_held(false)
				elif _focus == "trash":
					discard_held()
				else:
					drop_held(false)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			if _knife_held or ( not is_instance_valid(_held) and not _knife_rest_position.is_equal_approx(Vector2(1407, 730))):
				put_knife_back()
			else:
				drop_held(false)
		elif event.physical_keycode == KEY_G:
			drop_held(true)
		elif event.physical_keycode == KEY_E and not _focus.is_empty():
			if _focus == "chop" and is_instance_valid(_held):
				chop_held()
			elif _focus == "cook" and is_instance_valid(_held):
				drop_into_pan()
			else:
				interaction.emit(_focus, "")

func set_poster(_data: Dictionary) -> void :

	if is_instance_valid(_poster_canvas):
		_poster_canvas.queue_free()
		_poster_canvas = null

func set_controls_enabled(value: bool) -> void :
	if not value and is_instance_valid(pan): pan.suspend()
	if not value and is_instance_valid(plate): plate.finish(false)
	if not value and _dragging: _finish_food_drag(true)
	controls_enabled = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_foods):
		for body in _foods.get_children():
			if body == _held:
				continue
			if not value:
				if not body.has_meta("modal_freeze"):
					body.set_meta("modal_freeze", body.freeze)
				body.freeze = true
			elif body.has_meta("modal_freeze"):
				body.freeze = bool(body.get_meta("plated", false)) or bool(body.get_meta("modal_freeze"))
				body.remove_meta("modal_freeze")
	if not value:
		for tool in utensils: tool.release_tool()
		if is_instance_valid(cutting_board): cutting_board.release_board()
		_stop_squeezing()
		if _knife_held:
			_release_knife()
		_focus = ""
		focus_changed.emit("", "")
	_sync_held_foreground()

func spawn_ingredient(definition: Dictionary) -> bool:
	if is_instance_valid(_held) or _knife_held or has_active_utensil() or _foods.get_child_count() >= 64:
		return false
	var body: = preload("res://modules/restaurant/world/food_body.gd").new()
	body.mass = clampf(float(definition.get("mass", 0.15)), 0.01, 3.0)
	body.collision_layer = 16
	body.collision_mask = 17
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.linear_damp = 2.5
	body.angular_damp = 4.0
	var physics: = PhysicsMaterial.new()
	physics.friction = float(definition.get("friction", 0.55))
	physics.bounce = minf(float(definition.get("bounce", 0.08)), 0.12)
	body.physics_material_override = physics
	body.set_meta("id", str(definition.get("id", "tomato")))
	body.set_meta("title", str(definition.get("name", "食材")))
	body.set_meta("definition", definition.duplicate(true))
	body.set_meta("cut", false)
	body.set_meta("enrolled", false)
	body.set_meta("pending", false)
	body.set_meta("plated", false)
	body.set_meta("is_container", not get_dispense_mode(definition).is_empty())
	var instance_uid: = "food_%s_%s" % [Time.get_ticks_usec(), _foods.get_child_count()]
	body.set_meta("instance_uid", instance_uid)
	body.set_meta("batch_uid", instance_uid)
	body.set_meta("lineage", [])
	body.set_meta("surface_sauce", {"volume_ml": 0.0, "composition_ml": {}, "mixedness": 0.0, "layered": false})
	if body.get_meta("is_container", false): body.set_meta("remaining_ml", float(definition.get("container_ml", 240.0)))
	var source_polygon: = PackedVector2Array()
	for i in range(32): source_polygon.append(Vector2.from_angle(i * TAU / 32.0) * 24.0)
	body.set_meta("fragment_polygon", source_polygon)
	var collision: = CollisionShape2D.new()
	var shape: = CircleShape2D.new()
	shape.radius = 18.0
	collision.shape = shape
	body.add_child(collision)
	_foods.add_child(body)
	_make_food_visual(body, definition)
	_pickup(body)
	return true

func _make_food_visual(body: RigidBody2D, definition: Dictionary) -> void :
	if _food_art:
		var visual: = Node2D.new()
		visual.name = "FoodArt"
		visual.set_script(_food_art)
		visual.set("definition", definition)
		visual.scale = Vector2.ONE * 0.61
		body.add_child(visual)
	else:
		var sprite: = Polygon2D.new()
		var points: = PackedVector2Array()
		for i in range(20):
			points.append(Vector2.from_angle(i * TAU / 20.0) * 19)
		sprite.polygon = points
		sprite.color = Color(str(definition.get("color", "d95b40")))
		body.add_child(sprite)

func _food_at(pos: Vector2) -> RigidBody2D:
	var found: RigidBody2D
	var nearest: = 35.0
	for body in _foods.get_children():
		if body.is_queued_for_deletion() or body == _held or body.get_meta("overflow", false): continue
		var visual: = body.get_node_or_null("SauceBlob")
		var center: Vector2 = to_local(visual.global_position if is_instance_valid(visual) else body.global_position)
		var distance: float = center.distance_to(pos)
		if distance < nearest:
			nearest = distance
			found = body
	return found

func begin_food_drag(pointer: Vector2, from_storage: = false) -> void :
	if not controls_enabled or not is_instance_valid(_held): return
	_drag_group.clear()
	if bool(_held.get_meta("cut", false)) and not bool(_held.get_meta("enrolled", false)) and not bool(_held.get_meta("plated", false)):
		var batch_uid: = str(_held.get_meta("batch_uid", ""))
		for candidate in _foods.get_children():
			if candidate == _held or not candidate is RigidBody2D or candidate.is_queued_for_deletion(): continue
			if str(candidate.get_meta("batch_uid", "")) != batch_uid or bool(candidate.get_meta("enrolled", false)) or bool(candidate.get_meta("plated", false)): continue
			if candidate.global_position.distance_to(_held.global_position) > 220.0: continue
			_drag_group.append({"body": candidate, "offset": candidate.global_position - _held.global_position})
			candidate.freeze = true
			candidate.collision_layer = 0
			candidate.linear_velocity = Vector2.ZERO
			candidate.angular_velocity = 0.0
			candidate.z_index = 19
	_dragging = true
	_food_drag_origin = pointer
	_food_drag_from_storage = from_storage
	_food_drag_moved = false
	_food_drag_offset = Vector2.ZERO if from_storage else _held.global_position - to_global(pointer)
	_move_dragged_food(pointer)

func _move_dragged_food(pointer: Vector2) -> void :
	if not _dragging or not is_instance_valid(_held): return
	if pointer.distance_to(_food_drag_origin) > 6: _food_drag_moved = true
	_held.global_position = to_global(pointer) + _food_drag_offset
	for member in _drag_group:
		var body: RigidBody2D = member.get("body")
		if is_instance_valid(body):
			body.global_position = _held.global_position + (member.get("offset", Vector2.ZERO) as Vector2)
	_sync_held_foreground()

func _finish_food_drag(force: = false) -> void :
	var keep_carried: = _food_drag_from_storage and not _food_drag_moved and not force
	_dragging = false
	_food_drag_offset = Vector2.ZERO
	_food_drag_from_storage = false
	if not is_instance_valid(_held) or keep_carried: return
	var point: = to_local(_held.global_position)
	if not force and _held_is_sauce_bottle() and _squeeze_region().has_point(point):
		interaction.emit("notice", "调料已拿到锅边。" + get_held_operation_hint())
		return

	var primary: RigidBody2D = _held
	var dropped_batch: Array[RigidBody2D] = [primary]
	for member in _drag_group:
		var grouped: RigidBody2D = member.get("body")
		if is_instance_valid(grouped): dropped_batch.append(grouped)
	if pan.contains(point) and bool(primary.get_meta("cut", false)) and not bool(primary.get_meta("is_container", false)):
		# Every slot is unique.  Reusing six positions made large cut batches start
		# inside one another, so the physics solver ejected them across the room.
		var pan_slots := [
			Vector2(742, 552), Vector2(774, 550), Vector2(806, 549), Vector2(838, 550), Vector2(870, 552),
			Vector2(754, 566), Vector2(786, 564), Vector2(818, 563), Vector2(850, 565), Vector2(882, 567),
			Vector2(744, 580), Vector2(776, 578), Vector2(808, 577), Vector2(840, 578), Vector2(872, 580),
			Vector2(761, 590), Vector2(793, 589), Vector2(825, 589), Vector2(857, 590)
		]
		for index in dropped_batch.size():
			# More than nineteen fragments are layered with a small, deterministic
			# offset.  Accepted pan food does not collide with other food, so it can
			# overlap naturally without gaining an explosive impulse.
			var layer: int = index / pan_slots.size()
			var slot: Vector2 = pan_slots[index % pan_slots.size()] + Vector2(layer * 3, -layer * 3)
			dropped_batch[index].position = pan.point(slot)
			dropped_batch[index].set_deferred("position", dropped_batch[index].position)
	else:
		_held.global_position = to_global(point.clamp(Vector2(40, 520), Vector2(1560, 700)))
	drop_held(false)
	_release_drag_group()
	if pan.contains(primary.position):
		for body in dropped_batch:
			_on_pan_entered(body)

func _release_drag_group() -> void :
	for member in _drag_group:
		var body: RigidBody2D = member.get("body")
		if not is_instance_valid(body): continue
		body.collision_layer = 32 if bool(body.get_meta("dispensed", false)) else 16
		body.freeze = false
		body.sleeping = false
		body.z_index = 0
		body.linear_velocity = Vector2(0, 20)
		body.angular_velocity = 0.0
		if _stations.chop.has_point(body.position):
			body.position = body.position.clamp(_board_food_min(), _board_food_max())
			body.freeze = true
			body.set_meta("on_board", true)
			body.linear_velocity = Vector2.ZERO
		elif is_instance_valid(plate) and plate.hit_rect().has_point(body.position):
			_land_on_plate(body)
		else:
			body.set_meta("on_board", false)
	_drag_group.clear()

func _pickup(body: RigidBody2D) -> void :
	if is_instance_valid(_held) or _knife_held or has_active_utensil() or pan.active:
		return
	if bool(body.get_meta("enrolled", false)):
		food_removed_from_pan.emit(body)
		body.set_meta("enrolled", false)
	body.set_meta("plated", false)
	body.set_meta("on_board", false)
	_update_plated_flag()
	body.set_meta("pending", false)
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 1 if bool(body.get_meta("dispensed", false)) else 17
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0
	body.z_index = 20
	_held = body
	var sauce = body.get_node_or_null("SauceBlob")
	if is_instance_valid(sauce):
		sauce.position = Vector2.ZERO
		sauce.scale = Vector2.ONE
		sauce.rotation = 0
	_sync_held_foreground()
	held_changed.emit(str(body.get_meta("title", "食材")))
	if _held_is_sauce_bottle():
		focus_changed.emit(get_held_name(), get_held_operation_hint())

func drop_held(throw_item: = false) -> void :
	_dragging = false
	_food_drag_offset = Vector2.ZERO
	if not is_instance_valid(_held):
		return
	_stop_squeezing()
	var body: = _held
	_held = null
	_sync_held_foreground()
	body.collision_layer = 32 if bool(body.get_meta("dispensed", false)) else 16
	body.freeze = false
	body.sleeping = false
	body.z_index = 0
	body.linear_velocity = Vector2(0, 20)
	body.angular_velocity = 0
	body.set_deferred("global_position", body.global_position)
	if _stations.chop.has_point(body.position) and not body.get_meta("is_container", false):
		body.position = body.position.clamp(_board_food_min(), _board_food_max())
		body.set_deferred("position", body.position)
		body.freeze = true
		body.set_meta("on_board", true)
		body.linear_velocity = Vector2.ZERO
	if is_instance_valid(plate) and plate.hit_rect().has_point(body.position) and not body.get_meta("is_container", false):
		_land_on_plate(body)
	if throw_item:
		body.linear_velocity = Vector2(0, 20)
	held_changed.emit("")

func drop_into_pan() -> void :
	if not is_instance_valid(_held):
		return
	_held.global_position = pan.point(Vector2(809 + randf_range(-35, 35), 521))
	drop_held(false)

func chop_held() -> void :

	if not is_instance_valid(_held): return
	_held.position = Vector2(1210, 735)
	drop_held(false)
	interaction.emit("notice", "食材已完整放在菜板上，请拿刀切开。")

func _on_pan_entered(body: Node2D) -> void :
	if body.get_meta("overflow", false): return
	if body is RigidBody2D and body != _held and bool(body.get_meta("is_container", false)):
		if not body.get_meta("container_notice", false):
			body.set_meta("container_notice", true)
			interaction.emit("notice", "容器里还没出料。拿起后移到锅上方，按住左键撒、倒或挤。")
		return
	if body is RigidBody2D and body.has_meta("id") and body != _held and not bool(body.get_meta("plated", false)) and not bool(body.get_meta("is_container", false)):
		if not bool(body.get_meta("enrolled", false)) and not bool(body.get_meta("pending", false)):
			body.set_meta("pending", true)
			food_entered_pan.emit(str(body.get_meta("id")), bool(body.get_meta("cut", false)), body)

func _on_pan_exited(body: Node2D) -> void :
	if pan.is_carrying(body): return
	if body is RigidBody2D and utensil_holds(body):
		body.set_meta("container_location", "spoon")
		return
	if float(body.get_meta("stir_until", 0)) > _time and absf(body.position.x - pan.point(Vector2(809, 599)).x) < 135: return
	if body is RigidBody2D and bool(body.get_meta("enrolled", false)) and not bool(body.get_meta("plated", false)):
		body.set_meta("enrolled", false)
		body.set_meta("pending", false)
		body.collision_mask = 1 if bool(body.get_meta("dispensed", false)) else 17
		food_removed_from_pan.emit(body)

func accept_food(body: RigidBody2D, accepted: bool) -> void :
	if not is_instance_valid(body):
		return
	body.set_meta("pending", false)
	body.set_meta("enrolled", accepted)
	if accepted:
		body.set_meta("container_location", "pan")
		# Food in a shallow 2D pan should collide with the pan, not explode away
		# because several cut pieces touch each other at the same time.
		body.collision_mask = 1
	if not accepted:
		body.set_meta("rejected", true)
		if bool(body.get_meta("dispensed", false)):
			_stop_squeezing()
		body.set_deferred("global_position", Vector2(620, 680))
		body.set_deferred("linear_velocity", Vector2(-40, -20))

func _board_food_min() -> Vector2:
	return _stations.chop.position + Vector2(28, 24)

func _board_food_max() -> Vector2:
	return _stations.chop.end - Vector2(28, 24)

func set_dish(entries: Array, _ingredient_defs: Array) -> void :
	for entry in entries:
		if not entry is Dictionary:
			continue
		var physics_id: = int(entry.get("physics_id", 0))
		if physics_id > 0 and is_instance_id_valid(physics_id):
			var body = instance_from_id(physics_id)
			if is_instance_valid(body):
				var art = body.get_node_or_null("FoodArt")
				if art:
					art.set("heat", float(entry.get("heat", 0)))
					art.set("cut", bool(entry.get("cut", false)))
					art.set("softness", float(entry.get("softness", 0.0)))
				if str(entry.get("id", "")) == "noodles":
					body.set_meta("hydration", float(entry.get("hydration", 0.0)))
					body.set_meta("softness", float(entry.get("softness", 0.0)))
					_apply_noodle_collision(body, float(entry.get("softness", 0.0)))
				if body.has_meta("liquid_state") and body.get_node_or_null("SauceBlob"):
					body.get_node("SauceBlob").set("liquid_state", body.get_meta("liquid_state"))

func describe_body(body: RigidBody2D) -> Dictionary:
	var state: = {
		"instance_uid": str(body.get_meta("instance_uid", "food_%s" % body.get_instance_id())), 
		"batch_uid": str(body.get_meta("batch_uid", body.get_meta("instance_uid", "food_%s" % body.get_instance_id()))),
		"mass_kg": snappedf(body.mass, 0.0001), 
		"lineage": body.get_meta("lineage", []).duplicate(true), 
		"container": str(body.get_meta("container_location", "worktop")), 
		"surface_sauce": body.get_meta("surface_sauce", {}).duplicate(true)
	}
	var polygon: PackedVector2Array = body.get_meta("fragment_polygon", PackedVector2Array())
	var encoded: Array = []
	for point in polygon: encoded.append([snappedf(point.x, 0.01), snappedf(point.y, 0.01)])
	state["geometry"] = encoded
	if str(body.get_meta("definition", {}).get("id", "")) == "noodles":
		state["hydration"] = float(body.get_meta("hydration", 0.0))
		state["softness"] = float(body.get_meta("softness", 0.0))
	if body.has_meta("liquid_state"):
		state["liquid_state"] = body.get_meta("liquid_state").duplicate(true)
		state["volume_ml"] = float(body.get_meta("liquid_state", {}).get("volume_ml", 0.0))
	return state

func synchronize_body_state(body: RigidBody2D, entry: Dictionary) -> void :
	if not is_instance_valid(body): return

	var hydration: = float(entry.get("hydration", body.get_meta("hydration", 0.0)))
	var softness: = float(entry.get("softness", body.get_meta("softness", 0.0)))
	entry.merge(describe_body(body), true)
	entry["cut"] = bool(body.get_meta("cut", false))
	entry["heat"] = float(entry.get("heat", body.get_meta("saved_heat", 0.0)))
	entry["hydration"] = hydration
	entry["softness"] = softness
	body.set_meta("hydration", hydration)
	body.set_meta("softness", softness)

func _apply_noodle_collision(body: RigidBody2D, softness: float) -> void :
	softness = clampf(softness, 0.0, 1.0)
	if absf(softness - float(body.get_meta("collision_softness", -1.0))) < 0.04:
		return
	var collision: = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not is_instance_valid(collision): return
	var shape: = ConvexPolygonShape2D.new()
	var points: = PackedVector2Array()
	var radius: = Vector2(lerpf(18.0, 50.0, softness), lerpf(18.0, 11.0, softness))
	for index in 16:
		var phase: = float(index) * TAU / 16.0
		points.append(Vector2(cos(phase) * radius.x, sin(phase) * radius.y))
	shape.points = points
	collision.set_deferred("shape", shape)
	body.set_meta("collision_softness", softness)

func utensil_holds(body: RigidBody2D) -> bool:
	for utensil in utensils:
		if utensil.kind == "spoon" and utensil.bowl_contains(body): return true
	return false

func set_plated(value: bool) -> void :
	if not value:
		return_to_pan()
		return
	var index: = 0
	for body in _foods.get_children():
		if bool(body.get_meta("enrolled", false)):

			body.set_meta("plated", true)
			body.freeze = true
			body.global_position = plate.center + Vector2(-60 + float(index % 4) * 40, - float(index / 4) * 15)
			index += 1
	_update_plated_flag()

func return_to_pan() -> void :

	cooking = false
	var index: = 0
	for body in _foods.get_children():
		if not bool(body.get_meta("plated", false)):
			continue
		if bool(body.get_meta("enrolled", false)):

			food_removed_from_pan.emit(body)
		body.set_meta("enrolled", false)
		body.set_meta("pending", false)
		body.set_meta("plated", false)
		body.collision_layer = 32 if bool(body.get_meta("dispensed", false)) else 16
		body.global_position = pan.point(Vector2(760 + float(index % 3) * 49, 521 - float(index / 3) * 48))
		body.set_deferred("position", body.position)
		body.linear_velocity = Vector2(0, 20)
		body.angular_velocity = 0
		body.freeze = false
		body.sleeping = false

		if not controls_enabled:
			body.set_meta("modal_freeze", false)
			body.freeze = true
		elif body.has_meta("modal_freeze"):
			body.remove_meta("modal_freeze")
		index += 1
	_update_plated_flag()

func _update_plated_flag() -> void :
	plated = false
	for body in _foods.get_children():
		if bool(body.get_meta("plated", false)) and bool(body.get_meta("enrolled", false)):
			plated = true
			return

func set_cooking(value: bool) -> void :
	if cooking != value and is_instance_valid(audio) and controls_enabled: audio.play_effect("ignite" if value else "tap")
	cooking = value

func set_heat_level(value: String) -> void :
	if value in ["low", "medium", "high"]:
		heat_level = value

func set_customer(customer: Dictionary) -> void :
	_customer = customer.duplicate()

func clear_food() -> void :
	pan.water_ml = 0
	pan.water_heat = 0
	pan.overflow_water_ml = 0
	for body in _foods.get_children():
		if bool(body.get_meta("enrolled", false)):
			body.set_meta("enrolled", false)
			body.queue_free()
	plated = false

func clear_workspace() -> void:
	pan.water_ml = 0
	pan.water_heat = 0
	pan.overflow_water_ml = 0
	pan._carried.clear()
	for body in _foods.get_children():
		if body == _held:
			_held = null
		body.set_meta("enrolled", false)
		body.queue_free()
	plated = false
	held_changed.emit("")

func discard_held() -> bool:
	if not is_instance_valid(_held):
		return false
	_stop_squeezing()
	audio.play_effect("drop")
	_held.queue_free()
	_held = null
	_sync_held_foreground()
	held_changed.emit("")
	return true

func get_held_name() -> String:
	for utensil in utensils:
		if utensil.active: return utensil.title
	if _knife_held:
		return "主厨刀 · 按住拖动，松手放下；Q 归位"
	return str(_held.get_meta("title", "")) if is_instance_valid(_held) else ""

func show_notice(_message: String) -> void :
	pass

func get_station_position(action: String) -> Vector2:
	return _stations[action].get_center() if _stations.has(action) else Vector2.ZERO

func aim_at_station(_action: String) -> void :
	pass

func _static_box(pos: Vector2, dimensions: Vector2) -> void :
	var body: = StaticBody2D.new()
	body.position = pos
	var collision: = CollisionShape2D.new()
	var shape: = RectangleShape2D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _static_segment(from: Vector2, to: Vector2, pan_wall: = true) -> void :
	var body: = StaticBody2D.new()
	var collision: = CollisionShape2D.new()
	var shape: = SegmentShape2D.new()
	shape.a = from
	shape.b = to
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	if pan_wall: _pan_walls.append(body)

func _play_chop_sound() -> void :
	audio.play_effect("chop")

func pan_rect() -> Rect2:
	return pan.transform_pan() * Rect2(704, 551, 222, 103)

func _held_is_sauce_bottle() -> bool:

	return is_instance_valid(_held) and bool(_held.get_meta("is_container", false))

func get_dispense_mode(definition: Dictionary) -> String:
	var mode: = str(definition.get("dispense_mode", ""))
	if mode in ["powder", "pour", "squeeze"]:
		return mode

	return "squeeze" if str(definition.get("id", "")) == "ketchup" else ""

func ingredient_operation_hint(definition: Dictionary) -> String:
	var mode: = get_dispense_mode(definition)
	if mode.is_empty():
		return "拖到砧板切配，或拖入锅中；松手放下"
	var action: String = {"powder": "撒粉", "pour": "倾倒", "squeeze": "挤酱"}[mode]
	return "移到锅上方，按住左键持续%s；松开停止" % action

func get_held_operation_hint() -> String:
	if _knife_held:
		return "按住并拖动刀刃切食材；松开就放下"
	return ingredient_operation_hint(_held.get_meta("definition", {})) if is_instance_valid(_held) else ""

func _sync_held_foreground() -> void :
	if not is_instance_valid(_held_foreground):
		return
	var source: Node2D
	if is_instance_valid(_held):
		source = _held.get_node_or_null("FoodArt")
		if not is_instance_valid(source):
			source = _held.get_node_or_null("SauceBlob")
	if not is_instance_valid(source):


		if is_instance_valid(_held_proxy_source):
			_held_proxy_source.visible = true
		if is_instance_valid(_held_proxy):
			_held_foreground.remove_child(_held_proxy)
			_held_proxy.queue_free()
		_held_proxy = null
		_held_proxy_source = null
		_held_foreground.visible = false
		if not is_instance_valid(_held):
			_held = null
			_stop_squeezing()
		_held_foreground.queue_redraw()
		return
	if source != _held_proxy_source:
		if is_instance_valid(_held_proxy_source):
			_held_proxy_source.visible = true
		if is_instance_valid(_held_proxy):
			_held_foreground.remove_child(_held_proxy)
			_held_proxy.queue_free()
			_held_proxy = null
		_held_proxy_source = source
		if is_instance_valid(source):
			_held_proxy = Node2D.new()
			_held_proxy.set_script(source.get_script())

			for property in source.get_property_list():
				var property_name: = str(property.name)
				if property_name in ["definition", "cut", "heat", "softness", "shadows", "polygon", "art_offset", "dispense_mode", "liquid_state"]:
					_held_proxy.set(property_name, source.get(property_name))
			_held_proxy.z_index = 1
			_held_foreground.add_child(_held_proxy)
	if is_instance_valid(source) and is_instance_valid(_held_proxy):
		source.visible = false
		_held_proxy.transform = source.get_global_transform_with_canvas()
		if _squeezing and get_dispense_mode(_held.get_meta("definition", {})) == "squeeze":

			_held_proxy.scale *= Vector2(1.0 + squeeze_pressure * 0.12, 1.0 - squeeze_pressure * 0.16)

		for property_name in ["cut", "heat", "softness"]:
			if property_name in source:
				_held_proxy.set(property_name, source.get(property_name))
	_held_foreground.visible = controls_enabled and is_instance_valid(source)
	_held_foreground.queue_redraw()

func _draw_dispensing_stream(target: Node2D) -> void :
	if not controls_enabled or not _squeezing or not is_instance_valid(_held):
		return
	var definition: Dictionary = _held.get_meta("definition", {})
	var mode: = get_dispense_mode(definition)
	var color: = Color.from_string(str(definition.get("color", "d96143")), Color("d96143"))
	var nozzle_world: = _nozzle_world_position()
	var canvas_transform: = get_global_transform_with_canvas()
	var nozzle: = canvas_transform * to_local(nozzle_world)
	var end: = canvas_transform * to_local(Vector2(nozzle_world.x, 601 + pan.offset.y))
	var drawing_scale: = canvas_transform.get_scale().abs().x
	if nozzle.y >= end.y:
		return
	if mode != "powder":
		target.draw_line(nozzle, end, color.darkened(0.12), (3.0 if mode == "pour" else lerpf(1.5, 6.5, squeeze_pressure)) * drawing_scale, false)
	if _pan_capacity_used() >= 6:
		var spill_path: = PackedVector2Array()
		for point in [Vector2(888, 601), Vector2(911, 602), Vector2(924, 613), Vector2(939, 637), Vector2(958, 641)]:
			spill_path.append(canvas_transform * (point + pan.offset))
		target.draw_polyline(spill_path, color, (2.0 if mode == "powder" else 5.0) * drawing_scale)
	var count: = 18 if mode == "powder" else 5
	for index in range(count):
		var phase: = fmod(_time * 2.5 + float(index) / float(count), 1.0)
		var point: = nozzle.lerp(end, phase)
		if mode == "powder":
			point.x += sin(index * 13.37) * (3.0 + 17.0 * phase) * drawing_scale
			target.draw_rect(Rect2(point, Vector2(2.0 + index % 2, 2.0) * drawing_scale), color.lightened(float(index % 3) * 0.08))
		else:
			var width: = 3.0 if mode == "pour" else 5.0
			target.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -5) * drawing_scale, point + Vector2(width, 2) * drawing_scale, point + Vector2(0, 5) * drawing_scale, point + Vector2( - width, 2) * drawing_scale]), color.lightened(0.12))

func _squeeze_region() -> Rect2:
	return pan.transform_pan() * Rect2(692, 420, 238, 215)

func _nozzle_world_position() -> Vector2:
	if not is_instance_valid(_held): return Vector2.ZERO
	var def: Dictionary = _held.get_meta("definition", {})
	var mode: = get_dispense_mode(def)
	var compression: = squeeze_pressure * 4.0 if mode == "squeeze" else 0.0
	return _held.global_position + Vector2(0, 24.0 - compression).rotated(_held.rotation)

func _stop_squeezing() -> void :
	_squeezing = false
	_squeeze_elapsed = 0.0
	_squeeze_dispensed = false
	_squeeze_distance = 0.0
	if is_instance_valid(_held):
		_held.rotation = 0

func _dispense_ketchup() -> void :

	_dispense_seasoning()

func _pan_capacity_used() -> int:
	var count: = 0
	for body in _foods.get_children():
		if body.is_queued_for_deletion() or body == _held or bool(body.get_meta("is_container", false)) or body.get_meta("overflow", false):
			continue
		if bool(body.get_meta("enrolled", false)) or bool(body.get_meta("pending", false)):
			count += 1
		elif bool(body.get_meta("dispensed", false)) and not bool(body.get_meta("rejected", false)) and Rect2(Vector2(704, 400) + pan.offset, Vector2(222, 245)).has_point(body.global_position):

			count += 1
	return count

func _dispense_seasoning(requested_ml: float = -1.0) -> RigidBody2D:
	if not _held_is_sauce_bottle() or not controls_enabled:
		return null
	if _foods.get_child_count() >= 64:
		_stop_squeezing()
		interaction.emit("notice", "台面太满了，先清理一些食材。")
		return null
	var definition: Dictionary = _held.get_meta("definition", {}).duplicate(true)
	var id: = str(definition.get("id", "ketchup"))
	var mode: = get_dispense_mode(definition)
	var default_ml: = maxf(0.2, float(definition.get("dispense_mass", 0.035)) * 1000.0)
	var volume_ml: = default_ml if requested_ml < 0.0 else maxf(0.05, requested_ml)
	var remaining_ml: = float(_held.get_meta("remaining_ml", definition.get("container_ml", 240.0)))
	volume_ml = minf(volume_ml, remaining_ml)
	if volume_ml <= 0.001:
		_stop_squeezing()
		interaction.emit("notice", "%s已经挤空了。" % definition.get("name", "容器"))
		return null
	_held.set_meta("remaining_ml", snappedf(remaining_ml - volume_ml, 0.001))
	var source_uid: = str(_held.get_meta("instance_uid", id + "_container"))
	var liquid_state: = SauceState.make_batch(definition, volume_ml, source_uid, squeeze_pressure)
	if _pan_capacity_used() >= 6:
		return _add_overflow(definition, liquid_state)
	var body: = preload("res://modules/restaurant/world/food_body.gd").new()
	body.name = id.capitalize().replace("_", "") + "Portion"
	body.mass = clampf(volume_ml * float(definition.get("density_g_ml", 1.03)) / 1000.0, 0.001, 0.2)


	body.collision_layer = 32
	body.collision_mask = 1
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.linear_damp = 1.5
	body.angular_damp = 2.0
	var material: = PhysicsMaterial.new()
	material.friction = 0.55 if mode == "pour" else 0.95
	material.bounce = 0.0
	body.physics_material_override = material
	body.set_meta("id", id)
	var action: String = {"powder": "撒出", "pour": "倒出", "squeeze": "挤出"}[mode]
	body.set_meta("title", str(definition.get("name", "调料")) + " · 已" + action)
	body.set_meta("definition", definition)
	body.set_meta("cut", false)
	body.set_meta("enrolled", false)
	body.set_meta("pending", false)
	body.set_meta("plated", false)
	body.set_meta("is_container", false)
	body.set_meta("dispensed", true)
	body.set_meta("dispense_mode", mode)
	body.set_meta("surface_slot", _pan_capacity_used())
	body.set_meta("instance_uid", "liquid_%s_%s" % [Time.get_ticks_usec(), _foods.get_child_count()])
	body.set_meta("liquid_state", liquid_state)
	body.set_meta("volume_ml", volume_ml)
	body.set_meta("container_location", "air")
	var collision: = CollisionShape2D.new()
	var shape: = CircleShape2D.new()
	shape.radius = 9.0
	collision.shape = shape
	body.add_child(collision)
	var sauce: = preload("res://modules/restaurant/world/sauce_blob.gd").new()
	sauce.name = "SauceBlob"
	sauce.definition = definition
	sauce.dispense_mode = mode
	sauce.liquid_state = liquid_state
	body.add_child(sauce)
	_foods.add_child(body)
	body.global_position = Vector2(clampf(_nozzle_world_position().x, 735 + pan.offset.x, 886 + pan.offset.x), minf(_nozzle_world_position().y, 554 + pan.offset.y))
	body.linear_velocity = Vector2(0, 100)
	interaction.emit("notice", "%s一份%s，实际落锅后计入料理；松开左键停止。" % [action, definition.get("name", "调料")])
	return body

func _update_landed_seasoning() -> void :


	for body in _foods.get_children():
		if body.is_queued_for_deletion() or body.get_meta("overflow", false): continue
		var visual: = body.get_node_or_null("SauceBlob") as Node2D
		if not is_instance_valid(visual): continue
		var landed: bool = body != _held and body.get_meta("enrolled", false) and not body.get_meta("plated", false) and pan.local_point(to_local(body.global_position)).y > 599 and absf(pan.angle) < 0.1
		if landed:
			var slot: = int(body.get_meta("surface_slot", 0)) % 6
			var surface: = Vector2(clampf(to_local(body.global_position).x + (slot % 3 - 1) * 25, 752 + pan.offset.x, 865 + pan.offset.x), 591 + pan.offset.y + (slot / 3) * 12)
			visual.global_position = to_global(surface)
			visual.global_rotation = global_rotation
			visual.scale = Vector2(1.6, 0.85)
			visual.z_index = 6
		else:
			visual.position = Vector2.ZERO
			visual.rotation = 0
			visual.scale = Vector2.ONE
			visual.z_index = 0

func spill_pan_water(volume_ml: float, spill_position: Vector2) -> void:
	if volume_ml <= 0.0: return
	var definition := {"id": "water", "name": "水", "color": "75b9bd", "dispense_mode": "pour", "density": 1.0, "viscosity": 0.08}
	var state := SauceState.make_batch(definition, volume_ml, "pan", 0.0)
	_add_overflow(definition, state, spill_position)

func _add_overflow(definition: Dictionary, incoming_state: Dictionary = {}, spill_position: Vector2 = Vector2.INF) -> RigidBody2D:
	var id: = str(definition.get("id", "ketchup"))
	var spill: RigidBody2D
	for body in _foods.get_children():
		if not body.is_queued_for_deletion() and body.get_meta("overflow", false) and body.get_meta("id", "") == id:
			spill = body
			break
	if not is_instance_valid(spill):
		if _foods.get_child_count() >= 64:
			_stop_squeezing()
			return null
		spill = RigidBody2D.new()
		spill.name = "CounterSpill"
		spill.mass = 0.04
		spill.collision_layer = 32
		spill.collision_mask = 1
		spill.set_meta("id", id)
		spill.set_meta("overflow", true)
		spill.set_meta("enrolled", false)
		spill.set_meta("dispensed", true)
		spill.set_meta("spilled_portions", 0)
		spill.set_meta("liquid_state", SauceState.make_batch(definition, 0.0, str(incoming_state.get("source_id", "unknown")), float(incoming_state.get("pressure", 0.0))))
		var shape: = CollisionShape2D.new()
		shape.shape = CircleShape2D.new()
		shape.shape.radius = 5
		spill.add_child(shape)
		var art: = preload("res://modules/restaurant/world/sauce_blob.gd").new()
		art.name = "SauceBlob"
		art.definition = definition.duplicate(true)
		art.dispense_mode = get_dispense_mode(definition)
		art.liquid_state = spill.get_meta("liquid_state")
		spill.add_child(art)
		_foods.add_child(spill)
		spill.position = spill_position if spill_position != Vector2.INF else Vector2(minf(951 + pan.offset.x + (_foods.get_child_count() % 3) * 8, 1550), 754)
		spill.z_index = 6
		interaction.emit("notice", "锅里的水洒到了台面，点击水渍可以擦掉。" if id == "water" else "锅满了，调料正在溢到台面！松手停止；放下容器后点击洒出的调料擦掉。")
	var amount: = mini(int(spill.get_meta("spilled_portions", 0)) + 1, 10000)
	spill.set_meta("spilled_portions", amount)
	if not incoming_state.is_empty():
		var spill_state: Dictionary = spill.get_meta("liquid_state", {})
		SauceState.merge_into(spill_state, incoming_state, 0.0)
		spill.set_meta("liquid_state", spill_state)
		spill.set_meta("volume_ml", float(spill_state.get("volume_ml", 0.0)))
		spill.get_node("SauceBlob").liquid_state = spill_state
	spill.get_node("SauceBlob").scale = Vector2(minf(1.4 + sqrt(amount) * 0.55, 4.2), minf(0.65 + sqrt(amount) * 0.16, 1.5))
	return spill

func _wipe_spill_at(pointer: Vector2) -> bool:
	if _knife_held or has_active_utensil(): return false
	for body in _foods.get_children():
		if body.is_queued_for_deletion() or not body.get_meta("overflow", false): continue
		var visual: = body.get_node("SauceBlob") as Node2D
		if visual.to_local(to_global(pointer)).length() <= 16:
			if str(body.get_meta("id", "")) == "water":
				pan.overflow_water_ml = maxf(0.0, pan.overflow_water_ml - float(body.get_meta("volume_ml", 0.0)))
			body.queue_free()
			audio.play_effect("wipe")
			interaction.emit("notice", "擦干净了。水渍和溢到台面的调料都不会计入料理。")
			return true
	return false

func pickup_knife(pointer: = Vector2.INF) -> bool:
	if is_instance_valid(_held) or _knife_held or has_active_utensil() or pan.active:
		return false
	_knife_held = true
	_knife_cutting = true
	_knife_visual.visible = true
	var grab_point: = get_global_mouse_position() if pointer == Vector2.INF else pointer
	_knife_drag_offset = _knife_visual.global_position - grab_point
	_knife_last_valid_rest = _knife_rest_position
	_previous_blade_tip = _knife_visual.global_position + Vector2(-50, -22)
	held_changed.emit("主厨刀")
	focus_changed.emit("主厨刀", "按住并拖动刀刃切食材；松开就放下")
	return true

func put_knife_back() -> void :
	_knife_last_valid_rest = Vector2(1407, 730)
	_release_knife()

func _release_knife() -> void :
	_knife_held = false
	_knife_cutting = false
	_knife_rest_position = _knife_last_valid_rest
	_knife_visual.global_position = _knife_rest_position
	_knife_visual.visible = true
	held_changed.emit("")
	focus_changed.emit("料理台", "食材先放在砧板；按住刀柄拖动切开，松手放下")

func _move_knife(pointer: Vector2) -> void :
	if not _knife_held or not _knife_cutting or not controls_enabled:
		return
	_knife_visual.global_position = pointer + _knife_drag_offset
	var blade_tip: = _knife_visual.global_position + Vector2(-50, -22)
	if blade_tip.distance_to(_previous_blade_tip) > 2.0:
		_perform_knife_sweep(_previous_blade_tip - Vector2(34, 0), blade_tip - Vector2(34, 0))
		_perform_knife_sweep(_previous_blade_tip, blade_tip)
		_perform_knife_sweep(_previous_blade_tip + Vector2(22, 0), blade_tip + Vector2(22, 0))
	_previous_blade_tip = blade_tip
	if _stations.chop.grow(22.0).has_point(_knife_visual.global_position):
		_knife_last_valid_rest = _knife_visual.global_position

func _knife_handle_rect() -> Rect2:
	return Rect2(_knife_visual.global_position + Vector2(5, 8), Vector2(91, 51))

func _knife_grab_rect() -> Rect2:
	return Rect2(_knife_visual.global_position + Vector2(-96, -47), Vector2(192, 110))

func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _dragging: _finish_food_drag(true)
		_stop_squeezing()
		if _knife_held and is_instance_valid(_knife_visual):
			_release_knife()

func _exit_tree() -> void :
	if is_instance_valid(_sound):
		_sound.stop()
		_sound.stream = null

func _perform_knife_sweep(from: Vector2, to: Vector2) -> void :
	if not _knife_held or not _knife_cutting or from.distance_to(to) < 2.0:
		return
	var direction: = (to - from).normalized()
	var normal: = Vector2( - direction.y, direction.x)
	for body in _foods.get_children():
		if body.is_queued_for_deletion() or body == _held or bool(body.get_meta("is_container", false)) or bool(body.get_meta("dispensed", false)):
			continue
		if not _stations.chop.grow(8.0).has_point(body.global_position):
			continue
		if _time - float(body.get_meta("last_cut_time", -100.0)) < 0.3:
			continue
		var point: = Geometry2D.get_closest_point_to_segment(body.global_position, from, to)
		if point.distance_to(body.global_position) <= float(body.get_meta("cut_radius", 22.0)):
			split_food(body, normal, point, 4)

func split_food(body: RigidBody2D, normal: = Vector2.RIGHT, world_cut: = Vector2.INF, max_depth: = 2) -> Array[RigidBody2D]:
	var result: Array[RigidBody2D] = []
	if not is_instance_valid(body) or body.is_queued_for_deletion() or body == _held:
		return result
	if bool(body.get_meta("is_container", false)) or bool(body.get_meta("dispensed", false)):
		return result
	if int(body.get_meta("cut_depth", 0)) >= max_depth or _foods.get_child_count() >= 63:
		return result
	if not _stations.chop.grow(8.0).has_point(body.global_position):
		return result

	var polygon: PackedVector2Array = body.get_meta("fragment_polygon", PackedVector2Array())
	if polygon.is_empty():
		for i in range(32):
			polygon.append(Vector2.from_angle(i * TAU / 32.0) * 24.0)
	var local_normal: = normal.normalized().rotated( - body.rotation)
	var cut_origin: = _polygon_centroid(polygon) if world_cut == Vector2.INF else body.to_local(world_cut)
	var first: = _clip_half(polygon, local_normal, cut_origin.dot(local_normal))
	var second: = _clip_half(polygon, - local_normal, - cut_origin.dot(local_normal))
	if first.size() < 3 or second.size() < 3 or _polygon_area(first) < 20 or _polygon_area(second) < 20:
		return result
	if bool(body.get_meta("enrolled", false)):
		food_removed_from_pan.emit(body)
		body.set_meta("enrolled", false)
	var definition: Dictionary = body.get_meta("definition", {})
	var art_offset: Vector2 = body.get_meta("art_offset", Vector2.ZERO)
	for index in range(2):
		var piece: PackedVector2Array = first if index == 0 else second
		var center: = _polygon_centroid(piece)
		var centered: = PackedVector2Array()
		var cut_radius: = 0.0
		for point in piece:
			centered.append(point - center)
			cut_radius = maxf(cut_radius, (point - center).length())
		var fragment: = preload("res://modules/restaurant/world/food_body.gd").new()
		fragment.name = "Cut_" + str(body.get_meta("id", "food"))
		fragment.mass = body.mass * _polygon_area(piece) / _polygon_area(polygon)
		fragment.collision_layer = 16
		fragment.collision_mask = 17
		fragment.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		fragment.linear_damp = 2.5
		fragment.angular_damp = 4.0
		fragment.physics_material_override = body.physics_material_override
		for key in ["id", "title", "definition", "saved_heat"]:
			if body.has_meta(key):
				fragment.set_meta(key, body.get_meta(key))
		fragment.set_meta("title", str(definition.get("name", "食材")) + " · 切块")
		fragment.set_meta("cut", true)
		fragment.set_meta("cut_depth", int(body.get_meta("cut_depth", 0)) + 1)
		fragment.set_meta("enrolled", false)
		fragment.set_meta("pending", false)
		fragment.set_meta("plated", false)
		fragment.set_meta("is_container", false)
		fragment.set_meta("instance_uid", "food_%s_%s" % [Time.get_ticks_usec(), index])
		fragment.set_meta("batch_uid", str(body.get_meta("batch_uid", body.get_meta("instance_uid", body.get_instance_id()))))
		var parent_lineage: Array = body.get_meta("lineage", []).duplicate(true)
		parent_lineage.append(str(body.get_meta("instance_uid", body.get_instance_id())))
		fragment.set_meta("lineage", parent_lineage)
		fragment.set_meta("surface_sauce", body.get_meta("surface_sauce", {}).duplicate(true))
		fragment.set_meta("last_cut_time", _time)
		fragment.set_meta("fragment_polygon", centered)
		fragment.set_meta("art_offset", art_offset - center)
		fragment.set_meta("cut_radius", cut_radius)
		var collision: = CollisionShape2D.new()
		var shape: = ConvexPolygonShape2D.new()
		shape.points = centered
		collision.shape = shape
		fragment.add_child(collision)
		var visual: = preload("res://modules/restaurant/world/food_fragment.gd").new()
		visual.name = "FoodArt"
		visual.definition = definition
		visual.polygon = centered
		visual.art_offset = art_offset - center
		visual.heat = float(body.get_meta("saved_heat", 0.0))
		fragment.add_child(visual)
		_foods.add_child(fragment)
		var separation: = normal.normalized() * (3.5 if index == 0 else -3.5)
		fragment.global_position = body.global_position + center.rotated(body.rotation) + separation
		fragment.rotation = body.rotation
		fragment.linear_velocity = body.linear_velocity + normal.normalized() * (12.0 if index == 0 else -12.0)
		if body.get_meta("on_board", false):
			fragment.set_meta("on_board", true)
			fragment.freeze = true
			fragment.linear_velocity = Vector2.ZERO
			fragment.angular_velocity = 0
		result.append(fragment)
	body.collision_layer = 0
	body.collision_mask = 0
	body.visible = false
	body.queue_free()
	_chop_flash = 0.2
	_play_chop_sound()
	interaction.emit("notice", "切开了！每块保留独立重量和碰撞；拖任意一块可把同批切块一起下锅。")
	return result

func _clip_half(polygon: PackedVector2Array, normal: Vector2, distance: float) -> PackedVector2Array:
	var output: = PackedVector2Array()
	for i in range(polygon.size()):
		var current: = polygon[i]
		var previous: = polygon[(i + polygon.size() - 1) % polygon.size()]
		var dc: = current.dot(normal) - distance
		var dp: = previous.dot(normal) - distance
		if (dc >= 0.0) != (dp >= 0.0):
			output.append(previous.lerp(current, dp / (dp - dc)))
		if dc >= 0.0:
			output.append(current)
	return output

func _polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	var center: = Vector2.ZERO
	var cross_sum: = 0.0
	for i in range(polygon.size()):
		var a: = polygon[i]
		var b: = polygon[(i + 1) % polygon.size()]
		var cross: = a.cross(b)
		center += (a + b) * cross
		cross_sum += cross
	return center / (3.0 * cross_sum) if absf(cross_sum) > 0.0001 else polygon[0]

func _connect_food_audio(body: Node) -> void :
	if not body is RigidBody2D: return
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect( func(_other: Node):
		if controls_enabled and is_instance_valid(audio) and not body.freeze and body.linear_velocity.length() > 55 and _other is StaticBody2D:
			audio.play_effect("tap" if body.get_meta("is_container", false) else "drop"))

func _polygon_area(polygon: PackedVector2Array) -> float:
	var area: = 0.0
	for i in range(polygon.size()): area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(area) * 0.5

func has_active_utensil() -> bool:
	for tool in utensils:
		if tool.active: return true
	return false
