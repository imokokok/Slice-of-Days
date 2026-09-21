extends Control

signal selected(location: String)


var painting: Texture2D=preload("res://art/ui/solmere-tourist-map-painting.png")
var points: Dictionary = {
	"bus_stop":Vector2(100,530), "cafe":Vector2(292,497), "produce_stall":Vector2(215,391),
	"night_market":Vector2(462,400), "town_entrance":Vector2(80,267), "print_shop":Vector2(638,214),
	"handcraft_shop":Vector2(293,212), "library":Vector2(416,301), "record_store":Vector2(670,390),
	"chess_stall":Vector2(666,307), "tarot_stall":Vector2(802,455), "residence":Vector2(114,155),
	"dorm":Vector2(797,182), "port":Vector2(598,558), "park":Vector2(972,290)
}
var dragging := false
var map_font := SystemFont.new()

func _ready() -> void:
	size=Vector2(1284,646)
	map_font.font_names=PackedStringArray(["Segoe Script"])
	mouse_filter=MOUSE_FILTER_STOP
	var lead := GuidanceSystem.tracked_lead()
	if GuidanceSystem.help_level>=3: lead=GuidanceSystem.next_step()
	for id in points:
		var marker := preload("res://scripts/ui/components/location_marker.gd").new()
		marker.name="Destination_"+str(id); marker.set_meta("location",id)
		var discovered: bool = ResidencySystem.state().visits.has(id) or str(id)==GameState.current_location
		var route := TravelSystem.route(GameState.current_location,str(id),"walk",GameState.current_role,GameState.current_minute)
		marker.set_meta("state","discovered" if discovered else "undiscovered")
		if not bool(route.get("available",false)) and str(id)!=GameState.current_location: marker.set_meta("state","unavailable")
		marker.text=TravelSystem.location_name(str(id))
		marker.tooltip_text=("已经到访" if discovered else "尚未到访")+"\n"+str(route.get("reason",""))
		marker.position=Vector2(points[id])-Vector2(16,22); marker.size=Vector2(174,44)
		marker.add_theme_font_size_override("font_size",16); add_child(marker)
		marker.selected=str(lead.get("location",""))==str(id)
		marker.pressed.connect(func() -> void: selected.emit(str(id)))
	queue_redraw()

func filter_locations(filter_index: int) -> void:
	var heard := {}
	for lead in GuidanceSystem.leads(): heard[str(lead.get("location",""))]=true
	for fact in KnowledgeSystem.facts():
		var location := str(fact.get("location_id",fact.get("subject_id","")))
		if points.has(location): heard[location]=true
	var tracked := str(GuidanceSystem.tracked_lead().get("location",""))
	for marker in get_children():
		if not marker is Button: continue
		var id := str(marker.get_meta("location",""))
		marker.visible=filter_index==0 or (filter_index==1 and (ResidencySystem.state().visits.has(id) or id==GameState.current_location)) or (filter_index==2 and heard.has(id)) or (filter_index==3 and (id==tracked or id==GameState.current_location))

func _draw() -> void:
	draw_texture_rect(painting,Rect2(Vector2.ZERO,size),false,Color(1,1,1,.93))
	draw_string(map_font,Vector2(47,92),"Solmere",HORIZONTAL_ALIGNMENT_LEFT,-1,54,PaperLanguage.BLUE)
	var c := Vector2(1195,78)
	draw_circle(c,32,Color("fff8e4",.85)); draw_arc(c,32,0,TAU,64,PaperLanguage.BLUE,1,true)
	draw_line(c-Vector2(0,42),c+Vector2(0,42),PaperLanguage.BLUE,1,true)
	draw_line(c-Vector2(42,0),c+Vector2(42,0),PaperLanguage.BLUE,1,true)
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,-27),c+Vector2(8,8),c,c+Vector2(-8,8)]),PaperLanguage.BLUE)
	for id in points:
		if str(id)==GameState.current_location: draw_circle(Vector2(points[id])+Vector2(0,31),5,PaperLanguage.BLUE)

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
