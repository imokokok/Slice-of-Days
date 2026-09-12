extends Node2D

var world: Node2D
var active := false
var _grab_offset := Vector2.ZERO
var _carried: Array[Dictionary] = []
const SIZE := Vector2(390, 125)
const START := Vector2(1030, 670)

func _ready() -> void:
	position = START
	z_index = -1
	world._stations["chop"] = rect()
	queue_redraw()

func rect() -> Rect2:
	return Rect2(position, SIZE)

func _draw() -> void:
	var texture: Texture2D = preload("res://modules/restaurant/assets/sprite_library.gd").gear(2)
	if texture:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, SIZE), false)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(world) or not world.controls_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and rect().has_point(pointer) and world._food_at(pointer) == null and not world._knife_held and not is_instance_valid(world._held) and not world.has_active_utensil() and not world.pan.active:
			active = true
			_grab_offset = pointer - position
			_carried.clear()
			for body in world._foods.get_children():
				if body is RigidBody2D and bool(body.get_meta("on_board", false)) and not body.is_queued_for_deletion():
					_carried.append({"body": body, "offset": body.position - position})
					body.freeze = true
			world.held_changed.emit("切菜板")
			world.focus_changed.emit("切菜板", "按住拖动；板上的食材会一起移动")
			get_viewport().set_input_as_handled()
		elif not event.pressed and active:
			_finish()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and active:
		var pointer: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * event.position
		position = (pointer - _grab_offset).clamp(Vector2(760, 625), Vector2(1180, 670))
		world._stations["chop"] = rect()
		for item in _carried:
			var body: RigidBody2D = item.body
			if is_instance_valid(body):
				body.position = position + (item.offset as Vector2)
				body.set_deferred("position", body.position)
		get_viewport().set_input_as_handled()

func _finish() -> void:
	active = false
	for item in _carried:
		var body: RigidBody2D = item.body
		if is_instance_valid(body):
			body.freeze = true
			body.linear_velocity = Vector2.ZERO
	_carried.clear()
	world.held_changed.emit("")

func release_board() -> void:
	if active:
		_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_board()
