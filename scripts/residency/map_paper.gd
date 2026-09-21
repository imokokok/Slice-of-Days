extends Control

signal selected(location: String)


var points: Dictionary = {
	"bus_stop": Vector2(178, 268),
	"cafe": Vector2(334, 268),
	"produce_stall": Vector2(430, 268),
	"night_market": Vector2(520, 268),
	"town_entrance": Vector2(654, 268),
	"print_shop": Vector2(804, 268),
	"handcraft_shop": Vector2(244, 384),
	"library": Vector2(382, 384),
	"record_store": Vector2(507, 384),
	"chess_stall": Vector2(638, 384),
	"tarot_stall": Vector2(790, 384),
	"residence": Vector2(236, 470),
	"dorm": Vector2(510, 470),
	"port": Vector2(654, 472),
	"park": Vector2(670, 560)
}
var dragging := false

func _ready() -> void:
	size=Vector2(1050,700)
	mouse_filter=MOUSE_FILTER_STOP
	var lead := GuidanceSystem.tracked_lead()
	var i := 0
	for id in points:
		points[id]=Vector2(100+(i%5)*202,235+(i/5)*133)
		i+=1
		var marker := preload("res://scripts/ui/components/location_marker.gd").new()
		marker.name="Destination_"+str(id); marker.set_meta("location",id)
		var discovered: bool = ResidencySystem.state().visits.has(id) or str(id)==GameState.current_location
		var route := TravelSystem.route(GameState.current_location,str(id),"walk",GameState.current_role,GameState.current_minute)
		marker.set_meta("state","discovered" if discovered else "undiscovered")
		if not bool(route.get("available",false)) and str(id)!=GameState.current_location: marker.set_meta("state","unavailable")
		marker.text=TravelSystem.location_name(str(id))
		marker.tooltip_text=("已经到访" if discovered else "尚未到访")+"\n"+str(route.get("reason",""))
		marker.position=Vector2(points[id])-Vector2(85,20); marker.size=Vector2(172,42)
		marker.add_theme_font_size_override("font_size",16); add_child(marker)
		marker.selected=str(lead.get("location",""))==str(id)
		marker.pressed.connect(func() -> void: selected.emit(str(id)))
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("e5edf0"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,615),Vector2(220,585),Vector2(440,638),Vector2(725,604),Vector2(1050,620),Vector2(1050,700),Vector2(0,700)]),Color("80b6ca"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(45,164),"Solmere",HORIZONTAL_ALIGNMENT_LEFT,-1,38,PaperLanguage.BLUE)
	for row in 3:
		draw_polyline(PackedVector2Array([Vector2(70,235+row*133),Vector2(310,239+row*133),Vector2(700,232+row*133),Vector2(1000,235+row*133)]),Color("b9c8ba"),4,true)
	for col in [1,3]: draw_line(Vector2(100+col*202,235),Vector2(100+col*202,505),Color("b9c8ba"),3,true)
	for id in points:
		if str(id)==GameState.current_location: draw_circle(Vector2(points[id])+Vector2(0,33),5,PaperLanguage.BLUE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var old := scale.x
			var value := clampf(old * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), 0.65, 1.45)
			position += event.position * (old - value)
			scale = Vector2.ONE * value
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		position += event.relative * scale.x
		position.x = clampf(position.x, -650, 390)
		position.y = clampf(position.y, -420, 250)
		accept_event()
