extends Control
## A finite, physical serving source on the dry counter beside the sink.
## The same rice body can be returned while it is still untouched.

signal serving_requested(screen_position: Vector2)
signal notice_requested(message: String)
signal sound_requested(effect: String)

const CLOSED = preload("res://modules/restaurant/assets/appliances/rice_cooker_closed.png")
const OPEN = preload("res://modules/restaurant/assets/appliances/rice_cooker_open.png")
const RICE_BOWL := Rect2(31, 50, 72, 40)
const LID := Rect2(19, 0, 100, 47)

var lid_open := false
var serving_available := true

func _ready() -> void:
	name = "RiceCooker"
	position = Vector2(438, 579)
	size = Vector2(132, 130)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_hint()

func _draw() -> void:
	# The unit rests on the same dry counter that supports the nearby utensils.
	draw_colored_polygon(PackedVector2Array([
		Vector2(17, 119), Vector2(33, 124), Vector2(100, 124),
		Vector2(119, 119), Vector2(101, 127), Vector2(31, 127)
	]), Color(0.24, 0.17, 0.11, 0.21))
	draw_texture_rect(OPEN if lid_open else CLOSED, Rect2(Vector2.ZERO, size), false)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	accept_event()
	var point: Vector2 = event.position
	if not lid_open:
		if not serving_available:
			notice_requested.emit("电饭煲里这一份米饭已经盛走了。")
			return
		lid_open = true
		sound_requested.emit("rice_open")
		notice_requested.emit("电饭煲打开了。点击锅内米饭，用旁边的饭勺盛一份。")
	elif LID.has_point(point):
		lid_open = false
		sound_requested.emit("rice_close")
		notice_requested.emit("盖好了电饭煲。")
	elif RICE_BOWL.has_point(point):
		if serving_available:
			serving_requested.emit(get_global_transform_with_canvas() * point)
		else:
			notice_requested.emit("电饭煲里没有剩余米饭。")
	else:
		notice_requested.emit("点击米饭盛取，点击上方锅盖合上。")
	_refresh_hint()
	queue_redraw()

func set_serving_available(available: bool) -> void:
	serving_available = available
	if not available:
		# The single prepared 220 g portion has left the pot. Closing the lid
		# avoids showing a full pot after it has been emptied.
		lid_open = false
	_refresh_hint()
	queue_redraw()

func slot_at(point: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(point)

func _refresh_hint() -> void:
	tooltip_text = ("电饭煲 · 点击锅盖打开，再点击米饭盛取一份\n未加工的米饭可以放回锅里" if serving_available else "电饭煲 · 本班次这一份米饭已盛完")
