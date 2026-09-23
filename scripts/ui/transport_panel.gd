extends Control
## Native route board bound to the existing travel transaction.
const P = preload("res://scripts/ui/components/interface_palette.gd")
const BUTTON = preload("res://scripts/ui/components/solmere_button.gd")
const OPTION = preload("res://scripts/ui/components/transit_option.gd")
const MAP = preload("res://scripts/ui/components/transit_map.gd")
const METHODS := {"walk":"步行", "bus":"公交", "taxi":"出租车", "friend":"找人借车"}
var origin := ""
var selected := ""
var method := "walk"
var destinations: Dictionary={}
var choices: Dictionary={}
var detail: Control
var notice: Label
var depart: Button
var route_map: Control
var rules: Control
var busy := false

func _ready() -> void:
	name="TransportRoutes"; add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT); mouse_filter=MOUSE_FILTER_STOP
	theme=P.theme_for_tools(); origin=GameState.current_location
	_surface(Rect2(0,0,1600,900),Color("162f3b",.52))
	_surface(Rect2(80,54,1440,792),P.CREAM,8)
	_surface(Rect2(80,54,1440,112),P.DEEP,8)
	rules=Control.new(); rules.mouse_filter=MOUSE_FILTER_IGNORE; add_child(rules); rules.draw.connect(_draw_rules)
	var emblem := TextureRect.new(); var atlas := AtlasTexture.new()
	atlas.atlas=preload("res://art/user_scenes/bus_stop.png"); atlas.region=Rect2(443,497,136,137)
	emblem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; emblem.texture=atlas
	emblem.position=Vector2(108,74); emblem.size=Vector2(70,70)
	emblem.mouse_filter=MOUSE_FILTER_IGNORE; add_child(emblem)
	P.words(self,"小镇出行",Vector2(198,72),650,33,P.CREAM)
	P.words(self,"SOLMERE   /   从 "+TravelSystem.location_name(origin)+" 出发",Vector2(200,121),850,19,Color("d0e2df"))
	P.words(self,"DAY %02d   %s" % [GameState.current_day,_time(GameState.current_minute)],Vector2(1124,76),320,22,P.CREAM)
	var close := _button(self,"返回街道  ·  "+SettingsSystem.binding_text("ui_cancel"),Vector2(1270,115),Vector2(216,40),_close)
	close.variant="camera"; close.refresh()
	P.words(self,"目的地",Vector2(118,188),320,25)
	var scroll := ScrollContainer.new(); scroll.position=Vector2(108,237); scroll.size=Vector2(354,569)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal=SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",5); scroll.add_child(list)
	for segment in WorldGraph.config.segments:
		var heading := Label.new(); heading.text=str(segment.name)
		heading.custom_minimum_size.y=39; heading.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
		heading.add_theme_font_size_override("font_size",18); heading.add_theme_color_override("font_color",P.MUTED); list.add_child(heading)
		for id in segment.locations:
			var button := OPTION.new(); button.compact=true
			button.title=LocalizationSystem.text(TravelSystem.location_name(id))+(" · "+LocalizationSystem.text("此处") if id==origin else "")
			button.name="Destination_"+id; button.custom_minimum_size=Vector2(327,49)
			button.disabled=id==origin; button.pressed.connect(_select.bind(id))
			list.add_child(button); destinations[id]=button
			if selected.is_empty() and id!=origin: selected=id
	route_map=MAP.new(); route_map.position=Vector2(508,184); route_map.size=Vector2(970,358)
	route_map.origin=origin; route_map.destination=selected
	route_map.destination_selected.connect(_select); add_child(route_map)
	P.words(self,"位置示意 · 点击圆点或左侧地点选择目的地",Vector2(520,547),930,17,P.MUTED)
	detail=Control.new(); detail.mouse_filter=MOUSE_FILTER_IGNORE; add_child(detail)
	_select(selected)
	if destinations.has(selected): destinations[selected].grab_focus()
	if not SettingsSystem.reduced_motion():
		modulate.a=0; create_tween().tween_property(self,"modulate:a",1,.18)

func _draw_rules() -> void:
	rules.draw_line(Vector2(481,190),Vector2(481,810),Color(P.SEA,.18),1,true)
	rules.draw_line(Vector2(508,741),Vector2(1478,741),Color(P.SEA,.22),1,true)
	rules.draw_line(Vector2(551,690),Vector2(1437,690),P.SAGE,2,true)
	for x in [551,1437]:
		rules.draw_circle(Vector2(x,690),6,P.CREAM); rules.draw_arc(Vector2(x,690),6,0,TAU,24,P.SEA,2,true)

func _surface(rect: Rect2, color: Color, radius := 0) -> void:
	var panel := Panel.new(); panel.position=rect.position; panel.size=rect.size; panel.mouse_filter=MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",P.face(color,radius,0)); add_child(panel)

func _button(parent: Node, text: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var button: Button=BUTTON.new(); button.text=LocalizationSystem.text(text); button.position=at; button.size=extent
	button.pressed.connect(action); parent.add_child(button); return button

func _time(minute: int) -> String:
	return "%02d:%02d" % [minute/60,minute%60]

func _select(id: String) -> void:
	if busy or id==origin or not destinations.has(id): return
	selected=id
	for key in destinations: destinations[key].selected=key==id
	route_map.update_route(origin,id)
	_refresh_journey()

func _quote(id: String) -> Dictionary:
	var quote := TravelSystem.route(origin,selected,id,GameState.current_role,GameState.current_minute).duplicate()
	if bool(quote.get("available",false)) and int(quote.get("cost",0))>GameState.money:
		quote.available=false; quote.reason="钱包余额不足。"
	return quote

func _refresh_journey() -> void:
	for child in detail.get_children(): detail.remove_child(child); child.queue_free()
	choices.clear()
	var index := 0
	for id in METHODS:
		var quote := _quote(id); var available := bool(quote.get("available",false))
		var b := OPTION.new(); b.name="Method_"+id; b.title=METHODS[id]
		b.position=Vector2(508+index*246,581); b.size=Vector2(232,77)
		b.subtitle="%d 分钟 · %s" % [int(quote.get("minutes",0)),"免费" if int(quote.get("cost",0))==0 else "%d 元" % int(quote.cost)] if available else "暂不可用"
		b.disabled=not available; b.selected=id==method; b.pressed.connect(_choose_method.bind(id))
		detail.add_child(b); choices[id]=b
		if not available: b.tooltip_text=LocalizationSystem.text(str(quote.get("reason","暂不可用")))
		index+=1
	var active := _quote(method); var valid := bool(active.get("available",false))
	P.words(detail,_time(GameState.current_minute)+"  出发",Vector2(545,661),300,19,P.SEA)
	var arrival := _time(int(active.arrival))+"  抵达" if valid else "等待选择"
	var arrival_label := P.words(detail,arrival,Vector2(1145,661),300,19,P.SEA); arrival_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var timing := "等候 %d 分钟   ·   行程 %d 分钟" % [int(active.get("wait",0)),int(active.get("minutes",0))-int(active.get("wait",0))] if valid else "此方式当前无法出行"
	var timing_label := P.words(detail,timing,Vector2(712,699),564,20,P.MUTED); timing_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	timing_label.max_lines_visible=1; timing_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	notice=P.words(detail,"钱包 %d 元" % GameState.money,Vector2(516,758),624,21,P.MUTED)
	if valid:
		notice.text=LocalizationSystem.text("%s → %s   ·   %d 元" % [LocalizationSystem.text(TravelSystem.location_name(origin)),LocalizationSystem.text(TravelSystem.location_name(selected)),int(active.cost)])
		P.words(detail,"钱包 %d 元 · 出发后 %d 元" % [GameState.money,GameState.money-int(active.cost)],Vector2(516,792),620,17,P.MUTED)
		if not active.get("conflicts",[]).is_empty():
			timing_label.text=LocalizationSystem.text("可能错过：")+LocalizationSystem.text("、".join(active.conflicts))
			timing_label.add_theme_font_size_override("font_size",17); timing_label.tooltip_text=timing_label.text
	else: notice.text=LocalizationSystem.text(str(active.get("reason","请选择可用的方式。")))
	notice.max_lines_visible=1; notice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; notice.tooltip_text=notice.text
	depart=_button(detail,"%s出发  →" % METHODS[method] if valid else "当前方式不可用",Vector2(1195,758),Vector2(282,66),_depart)
	depart.name="Depart"; depart.variant="guidance"; depart.add_theme_font_size_override("font_size",24); depart.refresh(); depart.disabled=not valid

func _choose_method(value: String) -> void:
	if busy: return
	method=value; _refresh_journey(); choices[value].grab_focus()

func _depart() -> void:
	if busy: return
	busy=true; depart.disabled=true
	var result := SceneRouter.travel_to(selected,method)
	if not bool(result.get("ok",false)):
		busy=false; _refresh_journey(); notice.text=LocalizationSystem.text(str(result.message))

func _close() -> void:
	if not busy: queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not busy:
		_close(); get_viewport().set_input_as_handled()
