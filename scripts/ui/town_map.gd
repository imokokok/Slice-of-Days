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
	title.text = LocalizationSystem.text("SOLMERE   /   我的手绘旅行地图")
	title.position = Vector2(42, 28)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	for index in WorldGraph.street_locations.size():
		var id := WorldGraph.street_locations[index]
		var b := Button.new()
		b.position = _map_point(index) - Vector2(69, 24)
		b.size = Vector2(138, 48)
		b.text = ("● " if str(id) == GameState.current_location else "") + LocalizationSystem.text(TravelSystem.location_name(str(id)))
		b.add_theme_font_size_override("font_size", 16)
		var face := StyleBoxFlat.new()
		face.bg_color = Color("e6ba79") if id == GameState.current_location else Color("fff7e5")
		face.border_color = Color("9a9276")
		face.set_border_width_all(1)
		face.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", face)
		var hover: StyleBoxFlat = face.duplicate()
		hover.bg_color = Color("d6e7d6")
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_color_override("font_color", Color("294f56"))
		b.add_theme_color_override("font_hover_color", Color("294f56"))
		b.add_theme_color_override("font_pressed_color", Color("294f56"))
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
	back.text = LocalizationSystem.text("合上地图  M / Esc")
	back.pressed.connect(SceneRouter.return_from_gameplay)
	add_child(back)
	_select(selected)
func _draw() -> void:
	draw_rect(Rect2(0,0,1600,900), Color("faf7ee"))
	draw_colored_polygon(PackedVector2Array([Vector2(825,80),Vector2(1030,80),Vector2(1030,290),Vector2(945,255),Vector2(850,220)]), Color("a0ccd0"))
	var colors := [Color("31658b"),Color("eed577"),Color("6d9fb9"),Color("8caa87")]
	var routes: Array = WorldGraph.config.segments
	for r in routes.size():
		var ids: Array = routes[r].locations
		for i in range(1, ids.size()):
			draw_line(_point(str(ids[i-1])), _point(str(ids[i])), colors[r], 5, true)
	for path in [[Vector2(720,360),Vector2(720,230),Vector2(350,230),Vector2(350,150)], [Vector2(720,360),Vector2(720,490),Vector2(160,490),Vector2(160,620)], [Vector2(890,360),Vector2(995,360),Vector2(995,190),Vector2(930,190)]]:
		for i in range(1, path.size()): draw_line(path[i-1],path[i],Color("8b9b86"),4,true)
	for caption in [["住宅区 · A 的家 / B 的家 / 停车区",Vector2(300,100)],["主街 · 从左侧公交站出发",Vector2(40,315)],["文化街支路 · 巷尾可以转身返回",Vector2(100,570)],["海边观景台",Vector2(835,135)]]:
		draw_string(ThemeDB.fallback_font,caption[1],LocalizationSystem.text(caption[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("294f56"))
	draw_rect(Rect2(1038,90,540,745),Color("f4f0e5"))
func _map_point(index: int) -> Vector2:
	return _point(WorldGraph.street_locations[index])
func _point(id: String) -> Vector2:
	var point: Array = WorldGraph.config.map_positions[id]
	return Vector2(float(point[0]), float(point[1]))
func _text(value: String, font_size := 21) -> Label:
	var label := Label.new()
	label.text = LocalizationSystem.text(value)
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
		_text("选一个地点看看方向，或夹上便签。合上地图后，沿街步行就能到达。")
		return
	_text(TravelSystem.location_name(id),28)
	var pin := Button.new()
	pin.text = LocalizationSystem.text("取消标记" if WorldGraph.pins().has(id) else "夹一张地点便签" if GameState.current_role == "A" else "Pin 到日程本")
	pin.pressed.connect(func() -> void: WorldGraph.toggle_pin(id); _select(id))
	info.add_child(pin)
	if id == "park": _text("观景台在街道最右端，每天 21:00 开放。",18)
	if id == GameState.current_location:
		_text("你就在这里。", 22)
	else:
		_text("%s。" % WorldGraph.directions(GameState.current_location, id), 20)
		_add_travel_option("walk", "步行")
		_add_travel_option("friend", "找人借车")
		_add_travel_option("taxi", "坐出租")
	_text("主街拱门路口：↑ / W 进入住宅区，↓ / S 进入文化街。支路向左走回主街。",16)
	notice = _text("选择一种方式出发；时间和费用按实际路程计算。",16)

func _add_travel_option(method: String, title: String) -> void:
	title = LocalizationSystem.text(title)
	var option := TravelSystem.route(GameState.current_location, selected, method, GameState.current_role, GameState.current_minute)
	var available := bool(option.get("available", false))
	var reason := str(option.get("reason", ""))
	var caption := title
	if available:
		caption = LocalizationSystem.text_with_values("%s · %d分钟 · %d元", [title, int(option.get("minutes", 0)), int(option.get("cost", 0))])
		if int(option.get("cost", 0)) > GameState.money:
			available = false
			reason = "余额不足。"
	else:
		caption = LocalizationSystem.text_with_values("%s · 暂不可用", [title])
	var choice := Button.new()
	choice.text = caption
	choice.custom_minimum_size = Vector2(470, 46)
	choice.add_theme_font_size_override("font_size", 19)
	choice.disabled = not available
	choice.tooltip_text = LocalizationSystem.text(reason)
	choice.pressed.connect(_depart.bind(method))
	info.add_child(choice)
func _depart(method: String) -> void:
	var result := SceneRouter.travel_to(selected,method)
	if not bool(result.get("ok",false)): notice.text = LocalizationSystem.text(str(result.get("message","现在无法出发。")))
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.is_action_pressed("open_map") or event.is_action_pressed("ui_cancel")): SceneRouter.return_from_gameplay()
