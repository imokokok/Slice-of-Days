extends Control

signal selected(location: String)


var painting: Texture2D=preload("res://art/ui/pocket_doodles/folded_map.png")
const MAP_SIZE := Vector2(1284,856)
var points: Dictionary = {
	"bus_stop":Vector2(298,602), "cafe":Vector2(242,489), "produce_stall":Vector2(389,422),
	"night_market":Vector2(484,451), "town_entrance":Vector2(128,376), "print_shop":Vector2(784,286),
	"handcraft_shop":Vector2(387,347), "library":Vector2(553,359), "record_store":Vector2(815,506),
	"chess_stall":Vector2(791,412), "tarot_stall":Vector2(858,368), "residence":Vector2(200,193),
	"dorm":Vector2(298,211), "port":Vector2(788,725), "park":Vector2(1175,470)
}
var dragging := false
var map_font := SystemFont.new()
const FRAME := 12.0

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	size=MAP_SIZE
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
		marker.text=LocalizationSystem.text({"town_entrance":"街口","produce_stall":"菜摊","handcraft_shop":"书信事务所"}.get(str(id),TravelSystem.location_name(str(id))))
		marker.tooltip_text=LocalizationSystem.text("已经到访" if discovered else "尚未到访")+"\n"+LocalizationSystem.text(str(route.get("reason","")))
		marker.position=Vector2(points[id])-Vector2(64,0); marker.size=Vector2(128,34)
		marker.add_theme_font_size_override("font_size",21); add_child(marker)
		marker.selected=str(lead.get("location",""))==str(id)
		marker.pressed.connect(func() -> void: selected.emit(str(id)))
	queue_redraw()
	GuidanceSystem.updated.connect(refresh_markers)
	GameState.state_changed.connect(refresh_markers)
	refresh_markers()

func refresh_markers() -> void:
	var next := GuidanceSystem.next_step()
	for marker in get_children():
		if not marker is Button: continue
		var id := str(marker.get_meta("location",""))
		var status := GuidanceSystem.location_status(id)
		var discovered: bool=ResidencySystem.state().visits.has(id) or id==GameState.current_location
		marker.set_meta("state",("discovered" if discovered else "undiscovered") if bool(status.open) else "unavailable")
		marker.tooltip_text=LocalizationSystem.text(str(status.reason) if not bool(status.open) else "已经到访" if discovered else "可以沿路去看看")
		marker.selected=str(next.get("location",""))==id and bool(status.open)
		marker.refresh()

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
	# One complete folded sheet. Its edge is the map edge, with no extra frame.
	draw_texture_rect(painting,Rect2(Vector2.ZERO,size),false)
	draw_string(map_font,Vector2(92,86),"Solmere",HORIZONTAL_ALIGNMENT_LEFT,-1,40,Color("574738"))
	var c := Vector2(1125,122)
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
