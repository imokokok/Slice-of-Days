extends Control
## The player's actual pen strokes, stored as page-relative coordinates.
var strokes: Array=[]
var drawing := false
var editable := true
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_STOP
	mouse_default_cursor_shape=CURSOR_CROSS
func _gui_input(event: InputEvent) -> void:
	if not editable: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		drawing=event.pressed
		if drawing and strokes.size()<100: strokes.append([])
		else: drawing=false
		accept_event()
	if event is InputEventMouseMotion and drawing and not strokes.is_empty():
		var stroke: Array=strokes.back()
		var count := 0
		for saved in strokes: count+=saved.size()
		if stroke.size()<1200 and count<16000: stroke.append([clampf(event.position.x/size.x,0,1),clampf(event.position.y/size.y,0,1)])
		queue_redraw(); accept_event()
func _draw() -> void:
	for stroke in strokes:
		var points := PackedVector2Array()
		for xy in stroke: points.append(Vector2(float(xy[0]),float(xy[1]))*size)
		if points.size()>1: draw_polyline(points,Color("315e79"),2.4,true)
