extends Range
## Mouse, keyboard and controller change the same real recording gain.
var dragging := false
var last_y := 0.0
func _ready() -> void:
	focus_mode=FOCUS_ALL; mouse_default_cursor_shape=CURSOR_POINTING_HAND
	min_value=.25; max_value=2; step=.05
	value_changed.connect(func(_v: float): queue_redraw())
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			dragging=event.pressed; last_y=event.position.y
			if dragging: grab_focus()
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			value+=step*(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1); accept_event()
	elif event is InputEventMouseMotion and dragging:
		value+=(last_y-event.position.y)*.01; last_y=event.position.y; accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up"):
		value+=step; accept_event()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_down"):
		value-=step; accept_event()
	queue_redraw()

func _draw() -> void:
	var center := size*.5
	var radius := minf(size.x,size.y)*.38
	draw_circle(center,radius,Color("e8d4ad"))
	var contour := PackedVector2Array()
	for i in 41:
		var angle := i*TAU/40.0
		contour.append(center+Vector2.from_angle(angle)*(radius+sin(angle*5)*.6))
	draw_polyline(contour,Color("624f35"),2,true)
	var angle := lerpf(-PI*.75,PI*.75,ratio)-PI*.5
	draw_line(center+Vector2.from_angle(angle)*radius*.25,center+Vector2.from_angle(angle)*radius*.82,Color("624f35"),3,true)
	if has_focus(): draw_arc(center,radius+6,-PI*.1,PI*1.7,42,Color("bd8d47"),2,true)
