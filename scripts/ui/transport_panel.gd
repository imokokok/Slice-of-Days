extends Control
## A route board: destination list, one journey, one departure action.
## Quotes and departure use the existing clock/fare/save transaction.
const P = preload("res://scripts/ui/components/interface_palette.gd")
const BUTTON = preload("res://scripts/ui/components/solmere_button.gd")
const METHODS := {"walk":"步行", "bus":"公交", "taxi":"出租车", "friend":"找人借车"}
var origin := ""
var selected := ""
var method := "walk"
var destinations: Dictionary = {}
var choices: Dictionary = {}
var detail: Control
var notice: Label
var depart: Button
var busy := false

func _ready() -> void:
	name="TransportRoutes"; add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT); mouse_filter=MOUSE_FILTER_STOP
	theme=P.theme_for_tools(); origin=GameState.current_location
	var dim := ColorRect.new(); dim.color=Color("173b50",.4); dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(dim)
	var surface := Panel.new(); surface.position=Vector2(488,54); surface.size=Vector2(1056,792)
	surface.add_theme_stylebox_override("panel",P.face(P.CREAM,10,0)); add_child(surface)
	P.words(self,"SOMEWHERE  →",Vector2(536,91),800,37,P.SEA)
	P.words(self,"从 "+TravelSystem.location_name(origin)+" 出发",Vector2(536,151),690,19,P.MUTED)
	_button(self,"收起  ·  "+SettingsSystem.binding_text("ui_cancel"),Vector2(1300,91),Vector2(200,44),queue_free)
	P.words(self,"想去哪里",Vector2(536,210),370,19,P.MUTED)
	var scroll := ScrollContainer.new(); scroll.position=Vector2(530,249); scroll.size=Vector2(370,552)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal=SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",5); scroll.add_child(list)
	for id in WorldGraph.street_locations:
		var button: Button=BUTTON.new(); button.text=TravelSystem.location_name(id)+(" · 这里" if id==origin else "")
		button.name="Destination_"+id; button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.custom_minimum_size=Vector2(330,49)
		button.disabled=id==origin; button.pressed.connect(_select.bind(id)); list.add_child(button); destinations[id]=button
		if selected.is_empty() and id!=origin: selected=id
	detail=Control.new(); add_child(detail)
	_select(selected)
	if destinations.has(selected): destinations[selected].grab_focus()
	if not SettingsSystem.reduced_motion():
		modulate.a=0; create_tween().tween_property(self,"modulate:a",1,.18)

func _draw() -> void:
	draw_line(Vector2(940,218),Vector2(940,794),Color(P.SEA,.18),1,true)

func _button(parent: Node, text: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var button: Button=BUTTON.new(); button.text=text; button.position=at; button.size=extent; button.pressed.connect(action); parent.add_child(button); return button

func _select(id: String) -> void:
	selected=id
	for key in destinations: destinations[key].selected=key==id
	_refresh_journey()

func _quote(id: String) -> Dictionary:
	var quote := TravelSystem.route(origin,selected,id,GameState.current_role,GameState.current_minute).duplicate()
	if bool(quote.get("available",false)) and int(quote.get("cost",0))>GameState.money:
		quote.available=false; quote.reason="钱包余额不足。"
	return quote

func _refresh_journey() -> void:
	for child in detail.get_children(): detail.remove_child(child); child.queue_free()
	choices.clear()
	P.words(detail,TravelSystem.location_name(origin)+"  →",Vector2(984,210),488,20,P.MUTED)
	P.words(detail,TravelSystem.location_name(selected),Vector2(984,246),486,34,P.SEA)
	P.words(detail,str(WorldGraph.segment_for(selected).name)+"   /   选择出行方式",Vector2(986,306),490,18,P.MUTED)
	var index := 0
	for id in METHODS:
		var quote := _quote(id)
		var text: String=METHODS[id]
		var available := bool(quote.get("available",false))
		text+="     %d 分钟  ·  %d 元" % [int(quote.minutes),int(quote.cost)] if available else "     暂不可用"
		var b := _button(detail,text,Vector2(980,354+index*70),Vector2(516,43),_choose_method.bind(id))
		b.name="Method_"+id; b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.disabled=not available; b.selected=id==method
		choices[id]=b
		var hint := "预计 %02d:%02d 抵达" % [int(quote.arrival)/60,int(quote.arrival)%60] if available else str(quote.get("reason","暂不可用"))
		if available and int(quote.get("wait",0))>0: hint+=" · 含等候 %d 分钟" % int(quote.wait)
		P.words(detail,hint,Vector2(992,399+index*70),498,15,P.MUTED)
		index+=1
	var active := _quote(method)
	var valid := bool(active.get("available",false))
	notice=P.words(detail,"钱包  %d 元" % GameState.money,Vector2(992,655),492,18,P.MUTED)
	if valid and not active.get("conflicts",[]).is_empty(): notice.text="路上可能错过："+"、".join(active.conflicts)
	elif not valid: notice.text=str(active.get("reason","请选择可用的方式。"))
	depart=_button(detail,"出发  →" if valid else "当前方式不可用",Vector2(982,732),Vector2(510,61),_depart)
	depart.name="Depart"; depart.variant="guidance"; depart.refresh(); depart.disabled=not valid

func _choose_method(value: String) -> void:
	method=value; _refresh_journey(); choices[value].grab_focus()

func _depart() -> void:
	if busy: return
	busy=true; depart.disabled=true
	var result := SceneRouter.travel_to(selected,method)
	if not bool(result.get("ok",false)):
		busy=false; _refresh_journey(); notice.text=str(result.message)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not busy:
		queue_free(); get_viewport().set_input_as_handled()
