extends Control
signal selected(location: String)
var points: Dictionary = {}
var dragging := false

func _ready() -> void:
	size = Vector2(1050,610)
	mouse_filter = MOUSE_FILTER_STOP
	var rows := {"main_street":275,"residential":85,"cultural_street":465,"lookout_route":140}
	for segment in WorldGraph.config.segments:
		for i in segment.locations.size():
			var id := str(segment.locations[i])
			var x: float = 55.0 + i*147
			if segment.id == "residential": x = 220+i*150
			if segment.id == "lookout_route": x = 955
			points[id] = Vector2(x,float(rows.get(str(segment.id),275)))
			var button := Button.new()
			button.name = "Destination_"+id
			button.set_meta("location",id)
			button.text = TravelSystem.location_name(id).replace("小镇街道公共区域","街道")
			button.position = points[id]-Vector2(62,22)
			button.size = Vector2(130,44)
			button.add_theme_font_size_override("font_size",17)
			button.add_theme_color_override("font_color",Color("405452"))
			var style := StyleBoxFlat.new()
			style.bg_color = Color("fbf2d9") if id != GameState.current_location else Color("a6cddb")
			style.border_color = Color("b89d77")
			style.set_border_width_all(1)
			var order := EconomySystem.procurement_summary()
			if not EconomySystem.active_order().is_empty() and order.source_locations.has(id):
				style.border_color=Color("75935e")
				style.set_border_width_all(3)
				button.tooltip_text=str(order.next)
			button.add_theme_stylebox_override("normal",style)
			button.pressed.connect(func() -> void: selected.emit(id))
			add_child(button)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("e6ead5"))
	for y in range(24,610,34): draw_line(Vector2(0,y),Vector2(1050,y+9),Color("bfccb9",0.15),1)
	draw_rect(Rect2(0,545,1050,65),Color("9dc5cc",0.6))
	for segment in WorldGraph.config.segments:
		for i in range(1,segment.locations.size()):
			draw_line(points[str(segment.locations[i-1])],points[str(segment.locations[i])],Color("bba889"),9,true)
	draw_polyline(PackedVector2Array([Vector2(642,275),Vector2(642,175),Vector2(220,175),Vector2(220,85)]),Color("bba889"),7,true)
	draw_line(Vector2(642,275),Vector2(55,465),Color("bba889"),7,true)
	draw_line(Vector2(790,275),Vector2(955,140),Color("bba889"),7,true)
	for id in points:
		if ResidencySystem.state().map_notes.has(id): draw_circle(points[id]+Vector2(52,-28),6,Color("b86e4e"))
	if points.has(GameState.current_location):
		var p: Vector2 = points[GameState.current_location]
		draw_colored_polygon(PackedVector2Array([p+Vector2(-8,40),p+Vector2(8,40),p+Vector2(0,27)]),Color("366579"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var old := scale.x
			var value := clampf(old*(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.12),0.65,1.7)
			position += event.position*(old-value)
			scale = Vector2.ONE*value
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		position += event.relative*scale.x
		position.x = clampf(position.x,-800,650)
		position.y = clampf(position.y,-420,370)
		accept_event()
