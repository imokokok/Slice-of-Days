extends Control
var selected := ""
var info: VBoxContainer
var notice: Label
func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.set_color("font_color","Label",Color("294f56"))
	theme = ui_theme
	selected = str(GameState.shared_state.get("map_destination", ""))
	GameState.shared_state.erase("map_destination")
	var title := Label.new()
	title.text = "SOLMERE   /   小镇地图      %s · 第%d天 · %s · %d元" % [GameState.current_role, GameState.current_day, GameState.clock_text(), GameState.money]
	title.position = Vector2(42, 28)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	for id in WorldGraph.config.map_positions:
		var point: Array = WorldGraph.config.map_positions[id]
		var b := Button.new()
		b.position = Vector2(float(point[0]) * 0.8 - 65, float(point[1]) + 65)
		b.size = Vector2(155, 48)
		b.text = ("● " if str(id) == GameState.current_location else "") + TravelSystem.location_name(str(id))
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_select.bind(str(id)))
		add_child(b)
	info = VBoxContainer.new()
	info.position = Vector2(1070, 110)
	info.size = Vector2(480, 690)
	info.add_theme_constant_override("separation", 12)
	add_child(info)
	var back := Button.new()
	back.position = Vector2(1340, 28)
	back.size = Vector2(210, 48)
	back.text = "合上地图  M / Esc"
	back.pressed.connect(SceneRouter.return_from_gameplay)
	add_child(back)
	_select(selected)
func _draw() -> void:
	draw_rect(Rect2(0,0,1600,900), Color("eddfbe"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,80),Vector2(1000,80),Vector2(1000,300),Vector2(850,245),Vector2(700,190),Vector2(480,250),Vector2(300,215),Vector2(0,280)]), Color("298da8"))
	for source in TravelSystem.adjacency:
		if not WorldGraph.config.map_positions.has(source): continue
		var a: Array = WorldGraph.config.map_positions[source]
		for edge in TravelSystem.adjacency[source]:
			var b: Array = WorldGraph.config.map_positions.get(str(edge.to), a)
			draw_line(Vector2(float(a[0])*0.8+12,float(a[1])+89),Vector2(float(b[0])*0.8+12,float(b[1])+89),Color("b89468"),4,true)
	draw_rect(Rect2(1038,90,540,745),Color("faf2de"))
func _text(value: String, font_size := 21) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", Color("294f56"))
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 470
	info.add_child(label)
	return label
func _select(id: String) -> void:
	selected = id
	for child in info.get_children():
		info.remove_child(child)
		child.queue_free()
	if id.is_empty():
		_text("每条路，都通向另一段生活。", 28)
		_text("选择地点查看路程。公交需从站点出发；熟人接送取决于关系和对方日程。")
		return
	_text(TravelSystem.location_name(id),28)
	var pin := Button.new()
	pin.text = "取消标记" if WorldGraph.pins().has(id) else "夹一张地点便签" if GameState.current_role == "A" else "Pin 到日程本"
	pin.pressed.connect(func() -> void: WorldGraph.toggle_pin(id); _select(id))
	info.add_child(pin)
	if id == "park": _text("观景台每天 21:00 开放。",18)
	for method in ["walk", "bus", "taxi", "friend"]:
		var quote := TravelSystem.route(GameState.current_location,id,method,GameState.current_role,GameState.current_minute)
		if not bool(quote.get("available",false)):
			_text(str(quote.get("reason", "")),16)
			continue
		var button := Button.new()
		button.text = "%s · %d分钟 · %d元\n等候%d分钟 · 到达%02d:%02d" % [str(quote.label),int(quote.minutes),int(quote.cost),int(quote.wait),int(quote.arrival)/60,int(quote.arrival)%60]
		button.custom_minimum_size = Vector2(470,76)
		button.add_theme_font_size_override("font_size",21)
		button.disabled = int(quote.cost) > GameState.money or int(quote.arrival) >= 1440
		button.pressed.connect(_depart.bind(method))
		info.add_child(button)
		if not quote.conflicts.is_empty(): _text("可能错过：" + "、".join(quote.conflicts),17)
	notice = _text("选择上方交通方式后出发。",17)
func _depart(method: String) -> void:
	var result := SceneRouter.travel_to(selected,method)
	if not bool(result.get("ok",false)): notice.text = str(result.get("message","现在无法出发。"))
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.is_action_pressed("open_map") or event.is_action_pressed("ui_cancel")): SceneRouter.return_from_gameplay()
