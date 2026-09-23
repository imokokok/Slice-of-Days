extends Control
## Existing map artwork supplies geography; all stops are native Controls.
signal destination_selected(id: String)
const P = preload("res://scripts/ui/components/interface_palette.gd")
const MAP = preload("res://scripts/residency/map_paper.gd")
var origin := ""
var destination := ""
var points: Dictionary={}
var markers: Dictionary={}
var painting: Texture2D
var origin_label: Label
var destination_label: Label
func _ready() -> void:
	clip_contents=true; mouse_filter=MOUSE_FILTER_IGNORE
	var source := MAP.new()
	points=source.points.duplicate(); painting=source.painting; source.free()
	for id in points:
		var marker := Button.new(); marker.name="MapStop_"+str(id)
		marker.position=_point(id)-Vector2(16,16); marker.size=Vector2(32,32)
		marker.focus_mode=FOCUS_ALL; marker.mouse_default_cursor_shape=CURSOR_POINTING_HAND
		marker.tooltip_text=TravelSystem.location_name(str(id))
		marker.pressed.connect(func(): destination_selected.emit(str(id)))
		add_child(marker); markers[id]=marker
	origin_label=P.words(self,"",Vector2.ZERO,206,19)
	destination_label=P.words(self,"",Vector2.ZERO,206,19)
	for label in [origin_label,destination_label]: label.add_theme_stylebox_override("normal",P.face(P.CREAM,4,7))
	update_route(origin,destination)
func _point(id: String) -> Vector2:
	return Vector2(points.get(id,MAP.MAP_SIZE*.5))/MAP.MAP_SIZE*size
func update_route(from: String, to: String) -> void:
	origin=from; destination=to
	if not is_node_ready(): return
	for id in markers:
		var marker: Button=markers[id]; marker.disabled=id==origin
		for state in ["normal","hover","pressed","focus","disabled"]:
			var face := P.face(P.LEMON if id==to or state in ["hover","pressed"] else P.CREAM,16,0)
			face.border_color=P.SEA; face.set_border_width_all(3 if id in [from,to] or state=="focus" else 1)
			if id==from: face.bg_color=P.SEA
			if state=="focus": face.bg_color=Color.TRANSPARENT; face.border_color=P.DEEP; face.set_border_width_all(4)
			marker.add_theme_stylebox_override(state,face)
	origin_label.text=LocalizationSystem.text("此处")+" · "+LocalizationSystem.text(TravelSystem.location_name(from))
	destination_label.text=LocalizationSystem.text("前往")+" · "+LocalizationSystem.text(TravelSystem.location_name(to))
	for pair in [[origin_label,from],[destination_label,to]]:
		var at := _point(pair[1])+Vector2(24,17 if pair[1]==from else -41)
		pair[0].position=Vector2(clampf(at.x,10,size.x-224),clampf(at.y,10,size.y-45))
	queue_redraw()
func _draw() -> void:
	if painting==null: return
	draw_texture_rect(painting,Rect2(Vector2.ZERO,size),false)
	if points.has(origin) and points.has(destination):
		var start := _point(origin); var finish := _point(destination)
		var count := maxi(1,int(start.distance_to(finish)/13))
		for i in count: draw_circle(start.lerp(finish,float(i)/count),2.3,P.SEA)
