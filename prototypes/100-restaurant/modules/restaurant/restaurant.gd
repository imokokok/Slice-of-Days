extends Node2D

signal shift_completed(result: Dictionary)
signal exit_requested
signal recipe_published(record: Dictionary)
signal poster_published(data: Dictionary)

const Session = preload("res://modules/restaurant/domain/kitchen_session.gd")
const Repository = preload("res://modules/restaurant/storage/recipe_repository.gd")
const KitchenWorld = preload("res://modules/restaurant/world/kitchen_world.gd")
const PosterCanvas = preload("res://modules/restaurant/ui/poster_canvas.gd")
const PosterStore = preload("res://modules/restaurant/ui/poster_store.gd")
const StorageDisplay = preload("res://modules/restaurant/ui/storage_display.gd")
const MoodIcon = preload("res://modules/restaurant/ui/mood_icon.gd")
const FONT = preload("res://modules/restaurant/assets/fonts/noto_serif_sc.ttf")
const CREAM: = Color("284b47")
const MUTED: = Color("64756a")
const ACCENT: = Color("d7653e")
const DARK: = Color("173f3d")

var session = Session.new()
var repository
var poster_store
var world
var context: Dictionary = {}
var session_id: String = ""
var layer: CanvasLayer
var hud: Control
var modal: Control
var modal_panel: PanelContainer
var modal_body: VBoxContainer
var clock_label: Label
var money_label: Label
var hint_label: Label
var _fire_buttons: Dictionary = {}
var customer_label: Label
var customer_mood_icon: Control
var dish_label: Label
var heat_bar: ProgressBar
var toast_label: Label
var toast_time: float = 0.0
var last_customer: String = ""
var last_model_notice: String = ""
var _result_emitted: bool = false
var _saved_mouse_mode: int
var _started: bool = false
var _modal_kind: String = ""
var _pantry_category: String = "all"
var _pantry_search: String = ""
var _pantry_grid: GridContainer
var _last_dish: Dictionary = {}
var _photo: String = ""
var _poster_data: Dictionary = {}
var _poster_canvas
var _recipe_canvas
var _recipe_dish: Dictionary = {}
var _plating_canvas: Control
var _plating_revision: = 0
var _plating_photo_revision: = -1
var _photo_is_plating: = false
var _recipe_photo: String = ""
var _editing_recipe_id: String = ""
var _editor_status: Label
var _title_input: LineEdit
var _author_input: LineEdit
var _notes_input: TextEdit
var _recipe_selected: Dictionary = {}
var _letters: Array = []
const LETTER_PATH := "user://100_restaurant_letters.json"
var _food_by_physics: Dictionary = {}
var _mystery_bag: Array = []
var _last_mystery: = ""

func configure(entry_context: Dictionary) -> void :
	assert ( not is_inside_tree(), "Configure before adding the minigame to the scene tree.")
	context = entry_context.duplicate(true)

func _ready() -> void :
	_saved_mouse_mode = Input.mouse_mode
	session_id = "%s-%s" % [Time.get_ticks_usec(), randi()]
	session.setup()
	session.duration = clampf(float(context.get("shift_seconds", 240.0)), 30.0, 3600.0)
	if context.has("npc_profiles"):
		session.set_customers(context["npc_profiles"])
	repository = Repository.new(str(context.get("repository_path", "user://after_hours_kitchen/cookbook.json")))
	session.set_menu_recipes(repository.load_recipes())
	_load_letters()
	poster_store = PosterStore.new(repository.storage_path.get_basename() + "_poster.json")
	_poster_data = poster_store.load_poster()
	if not _poster_data.is_empty():
		session.apply_poster(_poster_data.get("tags", []))
	world = KitchenWorld.new()
	add_child(world)
	if not _poster_data.is_empty():
		world.set_poster(_poster_data)
	world.interaction.connect(_interact)
	world.focus_changed.connect(_focus)
	world.held_changed.connect( func(title: String):
		if not title.is_empty():
			_notify("手中：" + title + "   /   松手或点击台面放下")
		elif is_instance_valid(toast_label) and toast_label.text.begins_with("手中："):
			toast_time = 0
			toast_label.visible = false)
	if world.has_signal("food_entered_pan"):
		world.food_entered_pan.connect(_food_entered)
	if world.has_signal("food_removed_from_pan"):
		world.food_removed_from_pan.connect(_food_removed)
	_build_ui()
	world.set_controls_enabled(false)
	_show_intro()

func _exit_tree() -> void :
	Input.mouse_mode = _saved_mouse_mode

func _process(delta: float) -> void :

	if not is_instance_valid(modal) or not modal.visible:
		session.heat_contact = world.pan.on_stove()
		session.water_ml = world.pan.water_ml
		session.water_heat = world.pan.water_heat
		for item in session.dish:
			var food = _food_by_physics.get(int(item.get("physics_id", 0)))
			if is_instance_valid(food):
				item["off_heat"] = food.get_meta("plated", false) or not world.pan.contains(food.position)
				world.synchronize_body_state(food, item)
		session.tick(delta)
	if session.phase == "closed" and not _result_emitted:
		_settle()
	_update_hud()
	if is_instance_valid(hint_label): hint_label.visible = toast_time <= 0
	if toast_time > 0:
		toast_time -= delta
		toast_label.visible = toast_time > 0
	if session.last_notice != last_model_notice:
		last_model_notice = session.last_notice
		if session.phase == "service":
			_notify(last_model_notice)
	var customer_id: String = str(session.current_customer.get("id", ""))
	if customer_id != last_customer:
		last_customer = customer_id
		world.set_customer(session.current_customer)
		if not customer_id.is_empty():
			world._backdrop.ring_bell()
			world.audio.play_effect("bell")
	world.set_cooking(session.heating)
	world.set_heat_level(session.heat_level)
	world.set_dish(session.dish, session.ingredients)
	world.plate_presentation = session.presentation

func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if modal.visible and _modal_kind != "intro" and _modal_kind != "result":
				_close_modal()
			elif not modal.visible:
				_show_pause()
			get_viewport().set_input_as_handled()
		if not modal.visible:
			match event.keycode:
				KEY_TAB: _show_pantry()
				KEY_J: _show_cookbook()
				KEY_F1: _show_help()
				KEY_P: _show_poster()

func _build_ui() -> void :
	layer = CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var theme: = Theme.new()
	var readable_font: = FontVariation.new()
	readable_font.base_font = FONT
	readable_font.variation_opentype = {2003265652: 400.0}
	theme.default_font = readable_font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", DARK)
	theme.set_color("font_pressed_color", "Button", DARK)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("normal", "Button", _style(Color("f3dfa1"), 0))
	theme.set_stylebox("hover", "Button", _style(Color("ffe9a0"), 0))
	theme.set_stylebox("pressed", "Button", _style(Color("e6c86f"), 0))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), 10, ACCENT))
	theme.set_stylebox("normal", "LineEdit", _style(Color("fffaf0"), 8))
	theme.set_color("font_color", "LineEdit", CREAM)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_stylebox("normal", "TextEdit", _style(Color("fffaf0"), 8))
	theme.set_color("font_color", "TextEdit", CREAM)
	theme.set_color("font_placeholder_color", "TextEdit", MUTED)
	hud.theme = theme
	var footer: = ColorRect.new()
	footer.name = "DedicatedInstructionBar"
	footer.position = Vector2(0, 900)
	footer.size = Vector2(1600, 46)
	footer.color = Color("214946")
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(footer)
	var storage_display: = StorageDisplay.new()
	hud.add_child(storage_display)
	storage_display.setup(session.active_ingredients())
	storage_display.ingredient_chosen.connect(_take_ingredient)
	storage_display.browse_requested.connect(_show_pantry)
	storage_display.mystery_requested.connect(_draw_mystery)
	clock_label = _label(hud, "准备营业", Vector2(323, 36), 20, Color("fff0b8"))
	money_label = _label(hud, "¥ 0.00", Vector2(1230, 34), 20, Color("f7d96f"))
	var settings: = _dock_button(hud, "暂停 / 帮助", _show_pause, 130)
	settings.position = Vector2(1440, 28)
	var trash: = _dock_button(hud, "丢弃 / 清理台面", func():
		if is_instance_valid(world._held): world.discard_held()
		else: _interact("trash"), 130)
	trash.position = Vector2(1440, 832)
	var cpanel: = Control.new()
	cpanel.position = Vector2(1078, 185)
	cpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(cpanel)
	customer_label = _label(cpanel, "", Vector2.ZERO, 17)
	customer_label.size = Vector2(150, 266)
	customer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	customer_mood_icon = MoodIcon.new()
	customer_mood_icon.position = Vector2(154, 8)
	cpanel.add_child(customer_mood_icon)
	var fire_row: = HBoxContainer.new()
	fire_row.name = "StoveHeatControls"
	fire_row.position = Vector2(718, 750)
	fire_row.add_theme_constant_override("separation", 8)
	hud.add_child(fire_row)
	var fire_group: = ButtonGroup.new()
	for option in [["low", "小火"], ["medium", "中火"], ["high", "大火"], ["off", "关火"]]:
		var fire_button: = _dock_button(fire_row, option[1], func(): _change_heat(option[0]), 48)
		fire_button.toggle_mode = true
		fire_button.button_group = fire_group
		_fire_buttons[option[0]] = fire_button
	dish_label = _label(hud, "", Vector2(477, 812), 15, Color("fff1bd"))
	dish_label.size = Vector2(651, 23)
	dish_label.clip_text = true
	heat_bar = ProgressBar.new()
	heat_bar.position = Vector2(477, 837)
	heat_bar.size = Vector2(651, 3)
	heat_bar.max_value = 16.0
	heat_bar.show_percentage = false
	hud.add_child(heat_bar)
	var dock: = HBoxContainer.new()
	dock.name = "KitchenActionDock"
	dock.position = Vector2(477, 849)
	dock.add_theme_constant_override("separation", 12)
	hud.add_child(dock)
	_dock_button(dock, "食材柜", _show_pantry, 112)
	_dock_button(dock, "菜谱", _show_cookbook, 62)
	_dock_button(dock, "海报", _show_poster, 62)
	_dock_button(dock, "聊聊口味", func(): _interact("talk"), 104)
	_dock_button(dock, "出餐", func(): _interact("serve"), 72)
	_dock_button(dock, "回信", _show_letters, 62)
	var sound: = _dock_button(dock, "声音 开", func(): world.audio.muted = not world.audio.muted, 88)
	sound.pressed.connect( func(): sound.text = "声音 关" if world.audio.muted else "声音 开")
	hint_label = _label(hud, "", Vector2(40, 912), 14, Color("fff3c4"))
	hint_label.size = Vector2(1520, 28)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.clip_text = true
	toast_label = _label(hud, "", Vector2(40, 912), 14, Color("ffe28a"))
	toast_label.size = Vector2(1520, 28)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.clip_text = true
	modal = Control.new()
	modal.theme = theme
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(modal)
	var shade: = ColorRect.new()
	shade.color = Color(0.05, 0.18, 0.17, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	modal_panel = PanelContainer.new()
	modal_panel.add_theme_stylebox_override("panel", _style(Color("fff5dc"), 0, Color("79a59a")))
	modal.add_child(modal_panel)
	modal_body = VBoxContainer.new()
	modal_body.add_theme_constant_override("separation", 14)
	modal_panel.add_child(modal_body)
	modal.visible = false

func _style(color: Color, _radius: int = 0, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.set_content_margin_all(18)
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	return style

func _panel_at(parent: Control, rect: Rect2) -> Panel:
	var panel: = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color("fff7e5"), 0))
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, pos: Vector2 = Vector2.ZERO, font_size: int = 18, color: Color = CREAM) -> Label:
	var label: = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _text(text: String, font_size: int = 18, color: Color = MUTED) -> Label:
	var label: = _label(modal_body, text, Vector2.ZERO, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(parent: Node, text: String, callback: Callable, min_width: float = 0) -> Button:
	var button: = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(min_width, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _row(parent: Node) -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row

func _open_modal(kind: String, title: String, width: float = 800) -> void :
	if is_instance_valid(_plating_canvas): _plating_canvas.stop_gesture()
	modal_panel.theme = null
	modal_body.add_theme_constant_override("separation", 14)
	for child in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()
	_modal_kind = kind
	modal.visible = true
	modal_panel.position = Vector2((1600.0 - width) / 2.0, 80)
	modal_panel.size = Vector2(width, 0)
	world.set_controls_enabled(false)
	var title_row: = _row(modal_body)
	var heading: = _label(title_row, title, Vector2.ZERO, 30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kind != "intro" and kind != "result":
		_button(title_row, "关闭  ×", _close_modal)

func _close_modal() -> void :
	if is_instance_valid(_plating_canvas): _plating_canvas.stop_gesture()
	if session.phase == "closed" and _modal_kind != "intro":
		_settle()
		return
	modal.visible = false
	_modal_kind = ""
	world.set_controls_enabled(true)

func _show_intro() -> void :
	_open_modal("intro", "100饭店", 820)
	_text("100 RESTAURANT  /  自由烹饪", 14, ACCENT)
	_text("老板把今天的厨房交给你。\n给客人做一顿正常的午餐，或者一场意想不到的味觉实验。", 23, CREAM)
	_text("客人会说出想吃的味道。直接从冰箱、架子和篮子取材，在砧板用刀切开，放入锅里控制火候，再装盘出餐。收班获得营业收入的 30%。")
	_text("88 种材料  ·  拿取 / 切配 / 下锅  ·  自由组合\n原创菜谱留存  ·  手绘海报  ·  各有偏好的街坊")
	var row: = _row(modal_body)
	_button(row, "开始今天的营业", _start_shift, 270)
	_button(row, "先在厨房练习", func(): _started = true;_close_modal();_notify("准备期不限时。点击右上角“暂停 / 帮助”可开始营业。"), 240)
	_button(row, "返回主游戏", _request_exit)
	_text("操作：鼠标拖拽 · 松手放下 · 点击工具操作\n拿刀切配 / 单击盘子摆盘，按住可拖动 · 拖锅时按住右键倾倒", 16)

func _start_shift() -> void :
	_started = true
	session.start_shift()
	_close_modal()
	_notify("营业开始。点击食材架，或按 TAB 选择食材。")

func _show_pause() -> void :
	_open_modal("pause", "休息一下", 710)
	_text("小游戏内的时间已暂停。")
	_button(modal_body, "继续操作", _close_modal)
	if session.phase == "prep":
		_button(modal_body, "准备好了，开始营业", _start_shift)
	_button(modal_body, "操作说明", _show_help)
	_button(modal_body, "提前收班并结算", _settle)
	_button(modal_body, "结算并返回主游戏", func(): _settle(false);_request_exit())

func _show_help() -> void :
	_open_modal("help", "从一颗番茄开始", 870)
	_text("01  取材", 22, ACCENT)
	_text("88 种材料都摆在冷藏柜、常温架和篮子里。点击取一份，移动鼠标到台面再点击放下；已放下的食材可以拖拽。TAB 可搜索。")
	_text("02  切配与入锅", 22, ACCENT)
	_text("食材完整取出，放稳在右侧砧板。按住刀柄，让刀刃划过食材，切成的每块都可以单独拖进锅里；松开鼠标就放下刀。")
	_text("03  掌握火候", 22, ACCENT)
	_text("点击灶台开关火。中火下 6–11 秒为适宜火候，超过 14 秒焦糊；小火更慢，大火更快；每块单独计时，离锅停止受热。锅最多 6 份 / 块。按住锅边的铲柄拖进锅内，左右推拌、向上翻动，拖起时斜握铲柄，松开归位。调料拿到锅上方，按住左键撒、倒或挤，松开停止；实际落锅的一份调料计入料理，瓶子留在手里。")
	_text("04  留下你的招牌", 22, ACCENT)
	_text("点击盘子逐份装盘、拖动旋转或淋酱。可选拍照，再到“菜谱”手动加入照片，纸面默认空白。按住锅柄自由拖动，同时按住鼠标右键可倾倒食物。顶部菜谱、海报、暂停按钮都能用鼠标操作。")
	_button(modal_body, "知道了，回厨房", _close_modal)

func _focus(title: String, hint: String) -> void :
	hint_label.text = (title + " · " + hint) if not title.is_empty() else "拖拽食材到锅里，点击工具操作"

func _notify(message: String) -> void :
	if is_instance_valid(toast_label):
		toast_label.text = message
		toast_label.visible = true
		toast_time = 4.2

func _interact(action: String, payload: String = "") -> void :
	if modal.visible:
		return
	match action:
		"pantry", "ingredient": _show_pantry()
		"cook":
			if world.plated:
				world.return_to_pan()
				_notify("料理已回锅。食材落稳后，再点灶台开火。")
			else:
				session.set_heating( not session.heating)
				_notify(session.last_notice)
		"chop": _notify("食材放在菜板上，按住刀柄拖动刀刃切开。")
		"plate":
			session.set_heating(false)
			_show_plating()
		"serve": _serve()
		"talk":
			_notify(session.talk())
			_update_hud()
		"trash":
			session.clear_dish()
			world.clear_workspace()
			_food_by_physics.clear()
			_notify("已清理锅、盘和台面上的食材与洒漏。")
		"cookbook": _show_cookbook()
		"poster": _show_poster()
		"notice": _notify(payload)

func _food_entered(id: String, cut: bool, body: RigidBody2D) -> void :
	var accepted: bool = session.add_ingredient(id, world.describe_body(body))
	if accepted: _plating_changed()
	if accepted:
		var key: int = body.get_instance_id()
		session.dish[-1]["cut"] = cut
		session.dish[-1]["heat"] = float(body.get_meta("saved_heat", 0.0))
		session.dish[-1]["physics_id"] = key
		_food_by_physics[key] = body
	world.accept_food(body, accepted)
	_notify(session.last_notice)

func _food_removed(body: RigidBody2D) -> void :
	_plating_changed()
	var key: int = body.get_instance_id()
	for i in range(session.dish.size() - 1, -1, -1):
		if int(session.dish[i].get("physics_id", 0)) == key:
			body.set_meta("saved_heat", session.dish[i].get("heat", 0.0))
			body.set_meta("cut", session.dish[i].get("cut", false))
			session.dish.remove_at(i)
	_food_by_physics.erase(key)
	if session.dish.is_empty() and not body.get_meta("poured", false):
		session.set_heating(false)

func _update_hud() -> void :
	if not is_instance_valid(clock_label):
		return
	var remaining: int = maxi(0, ceili(session.duration - session.elapsed))
	clock_label.text = "准备营业  /  不限时" if session.phase == "prep" else "日班  %02d:%02d" % [remaining / 60, remaining % 60]
	money_label.text = "¥ %.2f" % session.revenue
	var npc: Dictionary = session.current_customer
	if npc.is_empty():
		customer_mood_icon.visible = false
		customer_label.text = "今日 · 主厨做主\n\n准备一道你的拿手菜。\n客人会按自己的偏好评价。"
	else:
		customer_mood_icon.visible = true
		customer_mood_icon.mood = float(npc.get("mood_before", 50))
		var kind: String = str(npc.get("role", "街坊食客"))
		var menu_line: String = "\n点单：《%s》" % npc.get("ordered_recipe", {}).get("title", "") if npc.has("ordered_recipe") else ""
		customer_label.text = "客人要求\n%s  /  %s\n餐前心情 %d / 100\n%s%s\n等待：%d 秒" % [npc.get("name", "客人"), kind, npc.get("mood_before", 50), npc.get("quote", "今天吃点什么？"), menu_line, ceili(session.customer_wait)]
		if npc.get("preferences_known", false):
			var chat: String = str(npc.get("last_chat", _preference_text(npc) + "\n" + str(npc.get("habit", ""))))
			customer_label.text = "客人要求\n%s  /  %s\n餐前心情 %d / 100\n%s%s\n等待：%d 秒" % [npc.get("name", "客人"), kind, npc.get("mood_before", 50), chat, menu_line, ceili(session.customer_wait)]
	var names: PackedStringArray = []
	var max_heat: float = 0.0
	for item in session.dish:
		var def: Dictionary = _definition(str(item["id"]))
		var heat: float = float(item.get("heat", 0))
		max_heat = maxf(max_heat, heat)
		var state: = "已焦" if heat > 14 else ("已熟" if heat >= 6 else ("未熟" if def.get("needs_cook", false) else "可直接食用"))
		if str(item.get("id", "")) == "noodles" and float(item.get("softness", 0.0)) > 0.02:
			state += "·变软%d%%" % roundi(float(item.get("softness", 0.0)) * 100.0)
		names.append("%s%s · %s" % [def.get("name", item["id"]), "·切" if item.get("cut", false) else "", state])
	var fire_name: String = {"low": "小火", "medium": "中火", "high": "大火"}[session.heat_level]
	dish_label.text = "%s · %s" % [fire_name + "加热" if session.heating else "已关火", " / ".join(names) if not names.is_empty() else "把食材拖进锅中，拿刀在菜板切配，点击盘子摆盘"]
	for level in _fire_buttons:
		_fire_buttons[level].set_pressed_no_signal(level == (session.heat_level if session.heating else "off"))
		_fire_buttons[level].disabled = session.phase == "closed"
	if max_heat > 14:
		dish_label.text += "\n有食材已经焦了！"
	heat_bar.value = max_heat

func _change_heat(level: String) -> void :
	if modal.visible or session.phase == "closed": return
	if level == "off":
		session.set_heating(false)
	elif world.plated:
		_notify("料理已装盘。先点击平底锅回锅，再调整火力。")
		return
	elif session.set_heat_level(level):
		session.set_heating(true)
	world.set_cooking(session.heating)
	_notify(session.last_notice)
	_update_hud()
	if is_instance_valid(hint_label): hint_label.visible = toast_time <= 0

func _preference_text(npc: Dictionary) -> String:
	var tags: = {"fresh": "清爽", "vegetable": "蔬菜", "protein": "蛋白质", "comfort": "家常", "spicy": "辣味", "sweet": "甜味", "odd": "怪味", "seafood": "海鲜", "dairy": "奶香", "umami": "鲜味", "rich": "浓郁", "sour": "酸味", "herbal": "草本", "bold": "浓烈", "fruit": "水果", "grain": "主食"}
	var like_names: PackedStringArray = []
	var dislike_names: PackedStringArray = []
	for tag in npc.get("likes", []): like_names.append(str(tags.get(tag, _definition(str(tag)).get("name", tag))))
	for tag in npc.get("dislikes", []): dislike_names.append(str(tags.get(tag, _definition(str(tag)).get("name", tag))))
	return "喜欢：%s  /  不爱：%s" % ["、".join(like_names), "、".join(dislike_names)]

func _definition(id: String) -> Dictionary:
	for entry in session.ingredients:
		if entry.get("id") == id: return entry
	return {}

func _show_pantry() -> void :
	_open_modal("pantry", "食材架  /  自由搭配", 1120)
	_text("选好后拿在手中。到砧板切配，或直接放入锅里。每道料理最多 6 份。", 16)
	var search: = LineEdit.new()
	search.placeholder_text = "搜索食材，例如：番茄、虾、袜子…"
	search.text = _pantry_search
	search.custom_minimum_size.y = 44
	modal_body.add_child(search)
	search.text_changed.connect( func(value): _pantry_search = value;_refresh_pantry())
	var tabs: = _row(modal_body)
	var cats: = {"all": "全部", "basic": "基础食材", "seasoning": "调味料", "sweet": "甜品饮品", "odd": "怪异材料"}
	for key in cats:
		_button(tabs, cats[key], func(): _pantry_category = key;_refresh_pantry(), 190)
	var scroll: = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1050, 427)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_body.add_child(scroll)
	_pantry_grid = GridContainer.new()
	_pantry_grid.columns = 5
	_pantry_grid.add_theme_constant_override("h_separation", 10)
	_pantry_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_pantry_grid)
	_refresh_pantry()

func _refresh_pantry() -> void :
	for child in _pantry_grid.get_children():
		_pantry_grid.remove_child(child)
		child.queue_free()
	for entry in session.active_ingredients():
		if _pantry_category != "all" and entry.get("category", "basic") != _pantry_category: continue
		if not _pantry_search.is_empty() and not str(entry.get("name", "")).contains(_pantry_search) and not str(entry.get("id", "")).contains(_pantry_search): continue
		var button: = _button(_pantry_grid, "%s\n%.0f g  ·  %s" % [entry["name"], float(entry.get("mass", 0.15)) * 1000.0, "需做熟" if entry.get("needs_cook", false) else "自由处理"], func(): _take_ingredient(entry), 198)
		button.custom_minimum_size.y = 92
		button.add_theme_font_size_override("font_size", 18)
		var color: = Color(str(entry.get("color", "f0bf7d")))
		button.add_theme_stylebox_override("normal", _style(Color("e8ddc4").lerp(color, 0.12), 9, color.darkened(0.3)))
		button.tooltip_text = "质量 %.2f kg · 摩擦 %.2f · 弹性 %.2f\n怪异度 %d%%" % [entry.get("mass", 0.15), entry.get("friction", 0.6), entry.get("bounce", 0.1), int(float(entry.get("weirdness", 0)) * 100)]
		if not world.get_dispense_mode(entry).is_empty():
			button.tooltip_text += "\n" + world.ingredient_operation_hint(entry)

func _take_ingredient(entry: Dictionary) -> void :
	if world.spawn_ingredient(entry):
		_close_modal()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			world.begin_food_drag(world.get_local_mouse_position(), true)
		if not world.get_dispense_mode(entry).is_empty():
			_notify(world.ingredient_operation_hint(entry))
		else:
			_notify("拿起%s。移动到台面点击放下；拖进锅里下锅。" % entry["name"])
	else:
		if modal.visible:
			_text("请先把手里的物品放下；台面最多保留 64 个实体。", 17, ACCENT)
		else:
			_notify("先把手里的物品放到台面。台面最多保留 64 个实体。")

func _serve() -> void :
	if not world.plated:
		_notify("请先把实际做好的食物装进盘子，再交给客人。")
		return
	for body in world._foods.get_children():
		if body.get_meta("enrolled", false) and not body.get_meta("plated", false) and not body.is_queued_for_deletion():
			_notify("还有食物没装盘。点击盘子，把本单料理装好后再出餐。")
			return
	var snapshot: Dictionary = session.plate()
	var result: Dictionary = session.serve()
	if result.is_empty():
		_notify(session.last_notice)
		return
	world.audio.play_effect("serve")
	world._backdrop.ring_bell()
	world.audio.play_effect("bell")
	_last_dish = snapshot
	if not (_photo_is_plating and _plating_photo_revision == _plating_revision): _photo = ""
	world.clear_food()
	_food_by_physics.clear()
	_open_modal("feedback", "这一口，客人怎么说", 860)
	var feedback_head := _row(modal_body)
	var sketch = preload("res://modules/restaurant/ui/customer_sketch.gd").new()
	sketch.customer_id = str(result.get("customer_id", "guest"))
	feedback_head.add_child(sketch)
	var feedback_title := VBoxContainer.new()
	feedback_head.add_child(feedback_title)
	_label(feedback_title, "%s  /  %d 分" % [result.get("customer", "客人"), result.get("score", 0)], Vector2.ZERO, 25, ACCENT)
	_label(feedback_title, "画在反馈纸上的小像  ·  %s" % result.get("role", "食客"), Vector2.ZERO, 17, MUTED)
	_text("%s  ·  %s" % [result.get("role", "食客"), result.get("reaction", "")], 18)
	var mood_row: = _row(modal_body)
	var before_icon: = MoodIcon.new()
	before_icon.mood = float(result.get("mood_before", 50))
	mood_row.add_child(before_icon)
	_label(mood_row, "餐前 %d" % result.get("mood_before", 50), Vector2.ZERO, 18)
	var after_icon: = MoodIcon.new()
	after_icon.mood = float(result.get("mood_after", 50))
	mood_row.add_child(after_icon)
	_label(mood_row, "餐后 %d   变化 %+d" % [result.get("mood_after", 50), result.get("mood_delta", 0)], Vector2.ZERO, 18, ACCENT)
	if not str(result.get("ordered_recipe_title", "")).is_empty():
		_text("点单：《%s》  /  与菜谱实材匹配 %d%%" % [result.ordered_recipe_title, roundi(maxf(0.0, float(result.get("recipe_match", 0.0))) * 100.0)], 18)
	_text("“%s”" % result.get("feedback", "谢谢招待。"), 25, CREAM)
	if not str(result.get("detail", "")).is_empty(): _text(str(result.detail), 20)
	_text("这次做得好，我会直接夸你；没做到的地方也写清楚，下次再一起试。" if int(result.get("score", 0)) < 80 else "这顿饭让我记住了，我愿意把这份称赞留在纸上。", 17, MUTED)
	_text("餐费 ¥%.2f   小费 ¥%.2f   赔偿 ¥%.2f\n本单净收入 ¥%.2f   本班合计 ¥%.2f" % [result.get("meal_fee", 0), result.get("tip", 0), result.get("compensation", 0), result.get("payment", 0), session.revenue], 22)
	var letter_index := _record_feedback(result)
	var reply := TextEdit.new()
	reply.placeholder_text = "写给这位客人的回复……"
	reply.custom_minimum_size = Vector2(790, 62)
	modal_body.add_child(reply)
	var row: = _row(modal_body)
	_button(row, "保存回复", func(): _save_reply(letter_index, reply.text), 160)
	_button(row, "继续招待下一位", _close_modal, 280)
	_button(row, "把这道菜写入菜谱", _show_recipe_editor, 320)

func _new_diy_recipe() -> void :
	_show_recipe_editor()

func _show_recipe_editor(record: Dictionary = {}) -> void :
	world.audio.play_effect("paper")
	_editing_recipe_id = str(record.get("id", ""))
	if record.is_empty():
		_recipe_dish = (session.plate() if not session.dish.is_empty() else _last_dish).duplicate(true)
		if _recipe_dish.is_empty(): _recipe_dish = {"ingredients": []}
		_recipe_photo = _photo if (_photo_is_plating and _plating_photo_revision == _plating_revision) or session.dish.is_empty() else ""
	else:
		_recipe_dish = record.get("dish", {"ingredients": []}).duplicate(true)
		_recipe_photo = str(record.get("thumbnail", ""))
	_open_authoring("recipe_editor", "编辑 DIY 菜谱" if not record.is_empty() else "新建 DIY 菜谱  /  从一张白纸开始")
	var columns: = _row(modal_body)
	_recipe_canvas = _new_paper(columns)
	if record.has("poster"): _recipe_canvas.import_data(record.poster)
	var tools: = _authoring_tools_column(columns)
	var metadata: = _row(tools)
	_title_input = LineEdit.new()
	_title_input.placeholder_text = "菜名（保存时使用）"
	_title_input.max_length = 60
	_title_input.text = str(record.get("title", ""))
	_title_input.custom_minimum_size = Vector2(265, 38)
	metadata.add_child(_title_input)
	_author_input = LineEdit.new()
	_author_input.placeholder_text = "署名"
	_author_input.text = str(record.get("author", context.get("display_name", "主厨")))
	_author_input.max_length = 40
	_author_input.custom_minimum_size = Vector2(210, 38)
	metadata.add_child(_author_input)
	_notes_input = TextEdit.new()
	_notes_input.placeholder_text = "做法、灵感，或者留给下一位主厨的话（也可加入纸面）"
	_notes_input.custom_minimum_size = Vector2(490, 62)
	_notes_input.text = str(record.get("notes", ""))
	tools.add_child(_notes_input)
	_build_collage_tools(tools, _recipe_canvas)
	_used_ingredients(modal_body, _recipe_canvas, _recipe_dish)
	var actions: = _row(modal_body)
	_tool_button(actions, "把菜名放到纸上", func(): _recipe_canvas.add_text(_title_input.text, _recipe_canvas.ink), 220)
	_tool_button(actions, "把做法放到纸上", func(): _recipe_canvas.add_text(_notes_input.text, _recipe_canvas.ink), 220)
	_button(actions, "保存修改" if not _editing_recipe_id.is_empty() else "放入公共菜谱", _save_recipe, 220)
	if not _editing_recipe_id.is_empty():
		_tool_button(actions, "另存为新菜谱", func(): _save_recipe(true), 220)
	_tool_button(actions, "暂不公开", _close_modal, 160)
	if _recipe_dish.get("ingredients", []).is_empty():
		_editor_status.text = "还没做菜也能 DIY：在纸上写字、画画或放照片，取名后保存。"

func _open_authoring(kind: String, title: String) -> void :
	_open_modal(kind, title, 1400)
	var compact: Theme = hud.theme.duplicate()
	compact.default_font_size = 16
	for widget in ["LineEdit", "TextEdit", "Button"]:
		var field: StyleBoxFlat = compact.get_stylebox("normal", widget).duplicate()
		field.set_content_margin_all(8)
		compact.set_stylebox("normal", widget, field)
	modal_panel.theme = compact
	modal_panel.position.y = 22
	modal_body.add_theme_constant_override("separation", 10)
	_text("素材在纸外，点击才会加入。拖动排版 · 滚轮缩放 · Delete 删除 · 编辑时客人等待与火候都暂停。", 16)

func _new_paper(parent: Node):
	var paper = PosterCanvas.new()
	parent.add_child(paper)
	paper.custom_minimum_size = Vector2(850, 460)
	paper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return paper

func _authoring_tools_column(parent: Node) -> VBoxContainer:
	var column: = VBoxContainer.new()
	column.custom_minimum_size.x = 490
	column.add_theme_constant_override("separation", 6)
	parent.add_child(column)
	return column

func _tool_button(parent: Node, text: String, callback: Callable, width: float = 0) -> Button:
	var button: = _button(parent, text, callback, width)
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 16)
	var normal: StyleBoxFlat = _style(Color("f3dfa1"))
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("ffe9a0")
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("e6c86f")
	button.add_theme_stylebox_override("pressed", pressed)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

func _build_collage_tools(parent: Node, canvas) -> void :
	var text_row: = _row(parent)
	var words: = LineEdit.new()
	words.placeholder_text = "写一段文字，再加入纸面"
	words.max_length = 120
	words.custom_minimum_size = Vector2(340, 36)
	text_row.add_child(words)
	_tool_button(text_row, "加入文字", func(): canvas.add_text(words.text, canvas.ink))
	var modes: = _row(parent)
	var group: = ButtonGroup.new()
	var mode_buttons: Dictionary = {}
	for pair in [["select", "移动素材"], ["draw", "画笔涂鸦"], ["cut", "剪出形状"]]:
		var b: = _tool_button(modes, pair[1], func():
			canvas.mode = pair[0]
			canvas.changed.emit())
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = pair[0] == "select"
		mode_buttons[pair[0]] = b
	canvas.changed.connect( func():
		for key in mode_buttons:
			mode_buttons[key].set_pressed_no_signal(canvas.mode == key))
	var brushes: = _row(parent)
	var color_label: = _label(brushes, "画笔颜色", Vector2.ZERO, 15, MUTED)
	var picker: = ColorPickerButton.new()
	picker.name = "CollageColor"
	picker.text = "画笔颜色"
	picker.color = canvas.ink
	picker.custom_minimum_size = Vector2(85, 32)
	var syncing: = {"active": false}
	picker.pressed.connect( func(): canvas.begin_property_edit())
	picker.popup_closed.connect( func(): canvas.end_property_edit())
	picker.color_changed.connect( func(color):
		if syncing.active: return
		if canvas.mode == "select" and not canvas.selected_decoration_settings().is_empty():
			canvas.set_tape_color(color)
		else:
			canvas.ink = color)
	brushes.add_child(picker)
	var brush_label: = _label(brushes, "笔粗", Vector2.ZERO, 15, MUTED)
	var brush: = HSlider.new()
	brush.min_value = 1
	brush.max_value = 24
	brush.value = 4
	brush.custom_minimum_size = Vector2(215, 30)
	brush.value_changed.connect( func(value): canvas.brush_width = value)
	brushes.add_child(brush)
	var tape_hint: = _label(brushes, "贴纸可独立调横向、纵向和颜色；胶带也可拖两端", Vector2.ZERO, 15, MUTED)
	var tape_dimensions: = _row(parent)
	tape_dimensions.name = "TapeDimensions"
	tape_dimensions.add_theme_constant_override("separation", 8)
	_label(tape_dimensions, "长度", Vector2.ZERO, 15, MUTED)
	var tape_length: = HSlider.new()
	tape_length.name = "TapeLength"
	tape_length.min_value = 0.5
	tape_length.max_value = 6.0
	tape_length.step = 0.05
	tape_length.custom_minimum_size = Vector2(125, 30)
	tape_dimensions.add_child(tape_length)
	var length_value: = _label(tape_dimensions, "1.00×", Vector2.ZERO, 14, MUTED)
	length_value.custom_minimum_size.x = 47
	_label(tape_dimensions, "宽度", Vector2.ZERO, 15, MUTED)
	var tape_width: = HSlider.new()
	tape_width.name = "TapeWidth"
	tape_width.min_value = 0.4
	tape_width.max_value = 3.0
	tape_width.step = 0.05
	tape_width.custom_minimum_size = Vector2(125, 30)
	tape_dimensions.add_child(tape_width)
	var width_value: = _label(tape_dimensions, "1.00×", Vector2.ZERO, 14, MUTED)
	width_value.custom_minimum_size.x = 47
	for slider in [tape_length, tape_width]:
		slider.drag_started.connect( func(): canvas.begin_property_edit())
		slider.drag_ended.connect( func(_value_changed): canvas.end_property_edit())
	tape_length.value_changed.connect( func(value):
		if not syncing.active: canvas.set_tape_length(value))
	tape_width.value_changed.connect( func(value):
		if not syncing.active: canvas.set_tape_width(value))
	var sync_properties: = func():
		syncing.active = true
		var settings: Dictionary = canvas.selected_decoration_settings() if canvas.mode == "select" else {}
		var decoration_selected: = not settings.is_empty()
		tape_dimensions.visible = decoration_selected
		tape_hint.visible = decoration_selected
		brush_label.visible = not decoration_selected
		brush.visible = not decoration_selected
		picker.text = "素材颜色" if decoration_selected else "画笔颜色"
		color_label.text = picker.text
		picker.color = Color(str(settings.get("color", "d8b85d"))) if decoration_selected else canvas.ink
		if decoration_selected:
			tape_length.set_value_no_signal(float(settings.get("length", 1.0)))
			tape_width.set_value_no_signal(float(settings.get("width", 1.0)))
			length_value.text = "%.2f×" % tape_length.value
			width_value.text = "%.2f×" % tape_width.value
		syncing.active = false
	canvas.changed.connect(sync_properties)
	sync_properties.call()
	var decoration_sets := [
		[["star", "星星"], ["heart", "爱心"], ["leaf", "叶子"], ["polka", "波点"], ["flower", "小花"]],
		[["lemon", "柠檬"], ["checker", "棋盘格"], ["wave", "波浪"], ["sun", "太阳"], ["tape", "胶带"]]
	]
	for decoration_set in decoration_sets:
		var decorations: = _row(parent)
		for pair in decoration_set:
			_tool_button(decorations, pair[1], func(): canvas.add_sticker(pair[0]))
	var transform: = _row(parent)
	_tool_button(transform, "缩小 −", func(): canvas.resize_selected(0.85))
	_tool_button(transform, "放大 +", func(): canvas.resize_selected(1.15))
	_tool_button(transform, "左转 ↶", func(): canvas.rotate_selected( - PI / 12.0))
	_tool_button(transform, "右转 ↷", func(): canvas.rotate_selected(PI / 12.0))
	var layers: = _row(parent)
	_tool_button(layers, "复制", func(): canvas.duplicate_selected())
	_tool_button(layers, "移到底层", func(): canvas.send_selected_back())
	_tool_button(layers, "删除", func(): canvas.delete_selected())
	_tool_button(layers, "撤销", func(): canvas.undo())
	var photos: = _row(parent)
	_tool_button(photos, "导入照片", func(): _import_collage_photo(canvas))
	_tool_button(photos, "加入已拍的摆盘照片" if _photo_is_plating and _plating_photo_revision == _plating_revision and not _photo.is_empty() else "拍摄料理并加入", func(): _add_dish_photo(canvas))
	_tool_button(photos, "恢复原图", func(): canvas.restore_selected_cut())
	_tool_button(photos, "清空纸面", func(): canvas.clear_canvas())
	_editor_status = _label(parent, "剪纸：选中素材 → 剪出形状 → 逐点画边界 → Enter 完成。", Vector2.ZERO, 14, MUTED)
	_editor_status.custom_minimum_size = Vector2(490, 40)
	_editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _used_ingredients(parent: Node, canvas, dish: Dictionary) -> void :
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	_label(box, "这道菜用到的食材  /  点击加入纸面，可反复使用", Vector2.ZERO, 16, MUTED)
	var entries: Array = dish.get("ingredients", [])
	var strip: = ScrollContainer.new()
	strip.custom_minimum_size.y = 84
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(strip)
	var row: = _row(strip)
	row.custom_minimum_size.y = 70
	var recorded_water: = clampf(float(dish.get("water_ml", 0)), 0, 1500)
	if recorded_water > 0:
		var water_text: = "水 %d ml" % roundi(recorded_water)
		_tool_button(row, water_text + "\n加入纸面文字", func(): canvas.add_text(water_text, Color("52766e")), 160)
	if entries.is_empty():
		_label(row, "尚未记录实际用料。可以先写字、画画或导入图片；纸面自由组合不会改变锅中的料理。", Vector2.ZERO, 17, MUTED)
	for value in entries:
		var item: Dictionary = {"id": value} if value is String else value
		var definition: = _definition(str(item.get("id", item.get("ingredient_id", "")))).duplicate(true)
		if definition.is_empty(): continue
		definition["cut"] = bool(item.get("cut", false))
		definition["heat"] = float(item.get("heat", 0.0))
		var button: = _tool_button(row, "", func(): canvas.add_ingredient(definition), 160)
		button.name = "UsedIngredient_" + str(definition.id)
		button.set_meta("ingredient_id", definition.id)
		button.custom_minimum_size.y = 70
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var art = preload("res://modules/restaurant/assets/food_art.gd").new()
		art.definition = definition
		art.cut = definition.cut
		art.heat = definition.heat
		art.shadows = false
		art.position = Vector2(34, 35)
		art.scale = Vector2.ONE * 0.65
		button.add_child(art)
		var state: = "已切" if definition.cut else "整份"
		if definition.heat >= 14: state += " · 焦"
		elif definition.heat >= 6: state += " · 熟"
		_label(button, str(definition.name) + "\n" + state, Vector2(67, 13), 15, CREAM)

func _import_collage_photo(canvas) -> void :
	var dialog: = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; 图片素材"])
	modal.add_child(dialog)
	dialog.file_selected.connect( func(path: String):
		if not is_instance_valid(canvas):
			dialog.queue_free()
			return
		var source: = Image.load_from_file(path)
		if source == null or source.is_empty():
			_editor_status.text = "这张图片未能读取，请选择 PNG、JPG 或 WebP。"
		else:
			var previous_count: int = canvas.stickers.size()
			canvas.add_photo(ImageTexture.create_from_image(source))
			_editor_status.text = "图片已加入。可移动、缩放、旋转或剪成形状。" if canvas.stickers.size() > previous_count else "未加入图片：纸面最多 32 个素材，请删除一些或换一张较小的图。"
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(1000, 640))

func _add_dish_photo(canvas) -> void :
	if session.dish.is_empty() and _last_dish.is_empty():
		_editor_status.text = "先做一道菜，再拍摄料理；也可以导入自己的图片。"
		return
	if _photo.is_empty() or not _photo_is_plating or _plating_photo_revision != _plating_revision:
		_editor_status.text = "请先到装盘台摆好实际食物，选择“拍照并加入菜谱”。"
		return
	if not is_instance_valid(canvas): return
	if _photo.is_empty():
		_editor_status.text = "暂时无法拍摄。"
		return
	var source: = Image.new()
	if source.load_png_from_buffer(Marshalls.base64_to_raw(_photo)) == OK:
		if is_instance_valid(_recipe_canvas) and canvas == _recipe_canvas: _recipe_photo = _photo
		var previous_count: int = canvas.stickers.size()
		canvas.add_photo(ImageTexture.create_from_image(source))
		_editor_status.text = "实拍照片已加入纸面，可以继续剪贴。" if canvas.stickers.size() > previous_count else "纸面已满，最多 32 个素材；请先删除不需要的内容。"

func _capture_photo() -> void :
	await _snapshot_photo()
	if _modal_kind == "recipe_editor": _recipe_photo = _photo
	if is_instance_valid(_editor_status):
		_editor_status.text = "照片已拍好，将随这道菜一起保存。"

func _snapshot_photo() -> void :
	_photo_is_plating = false
	if DisplayServer.get_name() == "headless":
		_photo = ""
		return
	layer.visible = false
	await RenderingServer.frame_post_draw
	var img: = get_viewport().get_texture().get_image()
	img.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	_photo = Marshalls.raw_to_base64(img.save_png_to_buffer())
	layer.visible = true

func _save_recipe(as_copy: bool = false) -> void :
	if _title_input.text.strip_edges().is_empty():
		_editor_status.text = "先在右侧填写菜名，再放入公共菜谱。"
		return
	var clean_dish: Dictionary = _recipe_dish.duplicate(true)
	for entry in clean_dish.get("ingredients", []):
		if entry is Dictionary:
			entry.erase("physics_id")
			entry.erase("off_heat")
	var record: = {"title": _title_input.text.strip_edges(), "author": _author_input.text.strip_edges(), "notes": _notes_input.text.left(2000), "dish": clean_dish, "thumbnail": _recipe_photo, "poster": _recipe_canvas.export_data()}
	var target_id: String = "" if as_copy else _editing_recipe_id
	if not target_id.is_empty(): record["id"] = target_id
	if repository.save_recipe(record):
		var saved: Array = repository.load_recipes()
		session.set_menu_recipes(saved)
		if target_id.is_empty():
			if not saved.is_empty(): recipe_published.emit(saved[-1].duplicate(true))
		else:
			for entry in saved:
				if str(entry.get("id", "")) == target_id:
					recipe_published.emit(entry.duplicate(true))
					break
		_recipe_photo = ""
		_show_cookbook()
	else:
		_editor_status.text = "保存失败：" + repository.get_last_error()

func _dish_names(data: Dictionary) -> String:
	var names: PackedStringArray = []
	for entry in data.get("ingredients", []):
		var id: String = str(entry) if entry is String else str(entry.get("id", entry.get("ingredient_id", "")))
		names.append(str(_definition(id).get("name", id)))
	return " + ".join(names) if not names.is_empty() else "尚未记录实际用料"

func _show_cookbook() -> void :
	_open_modal("cookbook", "公共菜谱", 1050)
	_text("这本菜谱属于来过厨房的人。当前为本地共享，可通过导入 / 导出交给其他玩家。", 16)
	var row: = _row(modal_body)
	_button(row, "新建 DIY 菜谱", _new_diy_recipe, 260)
	_button(row, "导出菜谱文件", func(): _file_dialog(true), 220)
	_button(row, "导入其他人的菜谱", func(): _file_dialog(false), 260)
	var recipes: Array = repository.load_recipes()
	var scroll: = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_body.add_child(scroll)
	var list: = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	if recipes.is_empty():
		var empty: = _label(list, "这本菜谱还是空的。\n\n点击上方「新建 DIY 菜谱」，从白纸开始自由创作。\n也可以做好料理后，把实际食材放进你的菜谱。", Vector2.ZERO, 23, MUTED)
		empty.custom_minimum_size.y = 210
	for record in recipes:
		var button: = _button(list, "%s    /    %s\n%s" % [record.get("title", "未命名"), record.get("author", "匿名主厨"), _dish_names(record.get("dish", {}))], func(): _view_recipe(record))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.custom_minimum_size.y = 90

func _view_recipe(record: Dictionary) -> void :
	_recipe_selected = record
	_open_modal("recipe", str(record.get("title", "菜谱")), 1100)
	modal_panel.position.y = 22
	modal_body.add_theme_constant_override("separation", 10)
	_text("主厨  " + str(record.get("author", "匿名主厨")), 18, ACCENT)
	if record.has("poster"):
		var centered: = CenterContainer.new()
		modal_body.add_child(centered)
		var canvas = PosterCanvas.new()
		centered.add_child(canvas)
		canvas.custom_minimum_size = Vector2(850.0 * 410.0 / 460.0, 410)
		canvas.import_data(record.poster)
		canvas.editable = false
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif not str(record.get("thumbnail", "")).is_empty():
		var image: = Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(record["thumbnail"])) == OK:
			var photo: = TextureRect.new()
			photo.texture = ImageTexture.create_from_image(image)
			photo.custom_minimum_size = Vector2(400, 220)
			photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			modal_body.add_child(photo)
	_text(_dish_names(record.get("dish", {})), 18, CREAM)
	var notes_scroll: = ScrollContainer.new()
	notes_scroll.custom_minimum_size = Vector2(1000, 72)
	notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_body.add_child(notes_scroll)
	var notes: = _label(notes_scroll, str(record.get("notes", "")), Vector2.ZERO, 16, MUTED)
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: = _row(modal_body)
	_button(row, "参考这道菜", func(): _close_modal();_notify("参考配方：" + _dish_names(record.get("dish", {}))), 240)
	_button(row, "继续 DIY", func(): _show_recipe_editor(record), 230)
	_button(row, "喜欢这道菜", func():
		var liked: bool = repository.like_recipe(str(record.get("id", "")))
		_notify("谢谢，你的喜欢已记下。" if liked else "这次没有新增喜欢：" + repository.get_last_error()), 180)
	_button(row, "返回菜谱", _show_cookbook, 200)

func _file_dialog(exporting: bool) -> void :
	var dialog: = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; 菜谱交换文件"])
	dialog.current_file = "after_hours_cookbook.json" if exporting else ""
	dialog.size = Vector2i(1000, 660)
	modal.add_child(dialog)
	dialog.file_selected.connect( func(path: String):
		if exporting:
			var error: Error = repository.export_to(path)
			_text("菜谱已导出，可把 JSON 文件发给朋友。" if error == OK else "导出失败：" + repository.get_last_error(), 17, ACCENT)
		else:
			var result: Dictionary = repository.import_from(path)
			_show_cookbook()
			_text("导入 %d 道菜谱。%s" % [result.get("added", 0), result.get("error", "")], 17, ACCENT)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _show_poster() -> void :
	world.audio.play_effect("paper")
	_open_authoring("poster", "海报工作台  /  从一张白纸开始")
	var columns: = _row(modal_body)
	_poster_canvas = _new_paper(columns)
	var tools: = _authoring_tools_column(columns)
	_label(tools, "自己的海报，自己排版", Vector2.ZERO, 22, ACCENT)
	_build_collage_tools(tools, _poster_canvas)
	var load_previous: = _tool_button(tools, "继续编辑已贴出的海报", func():
		_poster_canvas.import_data(_poster_data)
		_editor_status.text = "已载入上次的作品。修改后重新贴出即可。")
	load_previous.disabled = _poster_data.is_empty()
	var current: Dictionary = session.plate() if not session.dish.is_empty() else _last_dish
	_used_ingredients(modal_body, _poster_canvas, current)
	var tag_row: = _row(modal_body)
	_button(tag_row, "贴出去 · 家常料理", func(): _publish_poster(["comfort", "fresh", "vegetable"]), 390)
	_button(tag_row, "贴出去 · 怪味特供", func(): _publish_poster(["odd", "bold"]), 390)
	_button(tag_row, "贴出去 · 甜点小食", func(): _publish_poster(["sweet", "dairy"]), 390)

func _publish_poster(tags: Array) -> void :
	_poster_data = _poster_canvas.export_data()
	_poster_data["tags"] = tags
	if not poster_store.save_poster(_poster_data):
		_text("海报未能保存：" + poster_store.get_last_error(), 16, ACCENT)
		return
	world.set_poster(_poster_data)
	session.apply_poster(tags)
	poster_published.emit(_poster_data.duplicate(true))
	_close_modal()
	_notify("海报已贴出。有空、路过看见并感兴趣的客人才会来。")

func _settle(show_result: bool = true) -> void :
	var result: Dictionary = session.end_shift().duplicate(true)
	result["session_id"] = session_id
	result["player_id"] = str(context.get("player_id", "local_demo"))
	if not _result_emitted:
		_result_emitted = true
		shift_completed.emit(result.duplicate(true))
	world.set_cooking(false)
	if not show_result: return
	_open_modal("result", "收班了，辛苦主厨", 820)
	_text("今日的账单", 18, ACCENT)
	_text("营业收入    ¥ %.2f\n你的分成    ¥ %.2f" % [result.get("revenue", 0), result.get("share", 0)], 32, CREAM)
	_text("成功招待 %d 位  ·  离开 %d 位\n分成按营业收入的 30%% 计算。" % [result.get("served", 0), result.get("missed", 0)], 20)
	_text("你留下的菜谱还在，下一位主厨可以接着做。", 18)
	_button(modal_body, "返回主游戏", _request_exit)
	_button(modal_body, "翻翻今天的菜谱", _show_cookbook)

func _request_exit() -> void :
	if not _result_emitted: _settle(false)
	world.set_controls_enabled(false)
	Input.mouse_mode = _saved_mouse_mode
	exit_requested.emit()

func _plating_changed() -> void :
	_plating_revision += 1

func _show_plating() -> void :
	_open_modal("plating", "摆盘工作台  /  让这一餐成为你的作品", 1100)
	modal_panel.position.y = 140
	var columns: = _row(modal_body)
	_plating_canvas = preload("res://modules/restaurant/ui/plating_canvas.gd").new()
	_plating_canvas.game = self
	columns.add_child(_plating_canvas)
	_plating_canvas.changed.connect(_plating_changed)
	var tools: = VBoxContainer.new()
	tools.custom_minimum_size.x = 330
	tools.add_theme_constant_override("separation", 8)
	var tools_scroll: = ScrollContainer.new()
	tools_scroll.custom_minimum_size = Vector2(340, 360)
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(tools_scroll)
	tools_scroll.add_child(tools)
	_label(tools, "按同一次切出的整组装盘", Vector2.ZERO, 19)
	var all_food: Array = []
	var batches: Dictionary = {}
	for body in world._foods.get_children():
		if body.is_queued_for_deletion() or not body.get_meta("enrolled", false): continue
		all_food.append(body)
		var batch_uid := str(body.get_meta("batch_uid", body.get_meta("instance_uid", body.get_instance_id())))
		if not batches.has(batch_uid): batches[batch_uid] = []
		batches[batch_uid].append(body)
	if not all_food.is_empty():
		_tool_button(tools, "全部装盘（%d 块）" % all_food.size(), func(): _plate_bodies(all_food), 280)
	for batch_uid in batches:
		var batch_bodies: Array = batches[batch_uid]
		var title := str(batch_bodies[0].get_meta("title", "食物"))
		_tool_button(tools, "%s × %d" % [title, batch_bodies.size()], func(): _plate_bodies(batch_bodies), 280)
	var modes: = _row(tools)
	_tool_button(modes, "移动食物", func(): _plating_canvas.mode = "move", 144)
	_tool_button(modes, "淋酱", func(): _plating_canvas.mode = "sauce", 144)
	var sauces: = OptionButton.new()
	sauces.custom_minimum_size = Vector2(300, 38)
	for id in ["ketchup", "mayonnaise", "mustard", "chili_sauce", "soy_sauce", "honey"]:
		sauces.add_item(str(_definition(id).get("name", id)))
		sauces.set_item_metadata(sauces.item_count - 1, id)
	sauces.item_selected.connect( func(index: int): _plating_canvas.stop_gesture();_plating_canvas.sauce_id = str(sauces.get_item_metadata(index));_plating_canvas.mode = "sauce")
	tools.add_child(sauces)
	var rotation_row: = _row(tools)
	_tool_button(rotation_row, "逆时针", func(): _plating_canvas.rotate_selected( - PI / 12), 95)
	_tool_button(rotation_row, "顺时针", func(): _plating_canvas.rotate_selected(PI / 12), 95)
	_tool_button(rotation_row, "清除酱汁", _plating_canvas.clear_sauce, 110)
	var description: = _label(tools, "拖动食物；按钮或滚轮旋转。\n淋酱时按住鼠标，松手停止。\n食材和酱料均计入料理。", Vector2.ZERO, 16, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 300
	var status_label: = _label(modal_body, "照片只记录这只盘子的实际食物。选择交给客人，或带进 DIY 菜谱继续拼贴。", Vector2.ZERO, 17, MUTED)
	_plating_canvas.status.connect( func(message: String): status_label.text = message)
	var actions: = _row(modal_body)
	_button(actions, "拍照并交给顾客", func(): await _photograph_and_serve(status_label), 280)
	_button(actions, "拍照并加入菜谱", func(): await _photograph_and_recipe(status_label), 280)
	_button(actions, "完成摆盘，回厨房", _close_modal, 280)

func _plate_bodies(bodies: Array) -> void:
	if not is_instance_valid(_plating_canvas): return
	_plating_canvas.mode = "move"
	for body in bodies:
		if is_instance_valid(body) and body.get_meta("enrolled", false):
			_plating_canvas.add_to_plate(body)

func _photograph_and_serve(status_label: Label) -> void:
	await _photograph_plating()
	if _photo.is_empty():
		status_label.text = "照片没有生成，请再试一次。"
		return
	_close_modal()
	_serve()

func _photograph_and_recipe(status_label: Label) -> void:
	await _photograph_plating()
	if _photo.is_empty():
		status_label.text = "照片没有生成，请再试一次。"
		return
	_last_dish = session.plate()
	_show_recipe_editor()
	await get_tree().process_frame
	if is_instance_valid(_recipe_canvas):
		await _add_dish_photo(_recipe_canvas)

func _load_letters() -> void:
	_letters.clear()
	if not FileAccess.file_exists(LETTER_PATH): return
	var value = JSON.parse_string(FileAccess.get_file_as_string(LETTER_PATH))
	if value is Array:
		for entry in value.slice(-40):
			if entry is Dictionary: _letters.append(entry.duplicate(true))

func _persist_letters() -> void:
	var file := FileAccess.open(LETTER_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_letters, "  "))

func _record_feedback(result: Dictionary) -> int:
	_letters.append({"customer": str(result.get("customer", "客人")), "customer_id": str(result.get("customer_id", "guest")), "score": int(result.get("score", 0)), "feedback": str(result.get("feedback", "")), "detail": str(result.get("detail", "")), "reply": "", "time": Time.get_datetime_string_from_system()})
	if _letters.size() > 40: _letters.pop_front()
	_persist_letters()
	return _letters.size() - 1

func _save_reply(index: int, words: String) -> void:
	if index < 0 or index >= _letters.size(): return
	_letters[index]["reply"] = words.strip_edges().left(600)
	_persist_letters()
	_notify("回复已经收进工作台。")

func _show_letters() -> void:
	_open_modal("letters", "顾客反馈与回信工作台", 980)
	_text("客人的反馈纸会留在这里。写下回复并保存，下次仍能继续查看。", 17, MUTED)
	if _letters.is_empty():
		_text("目前还没有反馈。完成一份料理并交给顾客后，这里会收到第一张纸。", 20)
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(920, 600)
	modal_body.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 890
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	for index in range(_letters.size() - 1, -1, -1):
		var entry: Dictionary = _letters[index]
		var paper := PanelContainer.new()
		paper.add_theme_stylebox_override("panel", _style(Color("fff8df"), 0, Color("e3bd58")))
		list.add_child(paper)
		var body := VBoxContainer.new()
		paper.add_child(body)
		_label(body, "%s  ·  %d 分  ·  %s" % [entry.customer, entry.score, entry.get("time", "")], Vector2.ZERO, 20, ACCENT)
		_label(body, "“%s”\n%s" % [entry.feedback, entry.detail], Vector2.ZERO, 17, CREAM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var edit := TextEdit.new()
		edit.text = str(entry.get("reply", ""))
		edit.placeholder_text = "写回复……"
		edit.custom_minimum_size = Vector2(820, 55)
		body.add_child(edit)
		_button(body, "保存这封回复", func(): _save_reply(index, edit.text), 180)

func _photograph_plating() -> void :
	if not is_instance_valid(_plating_canvas): return
	_plating_canvas.stop_gesture()
	if DisplayServer.get_name() == "headless": return
	var viewport: = SubViewport.new()
	viewport.size = Vector2i(860, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var photo = preload("res://modules/restaurant/ui/plating_canvas.gd").new()
	photo.game = self
	photo.render_only = true
	photo.size = Vector2(860, 480)
	viewport.add_child(photo)
	add_child(viewport)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: = viewport.get_texture().get_image()
	picture.resize(640, 357, Image.INTERPOLATE_LANCZOS)
	_photo = Marshalls.raw_to_base64(picture.save_png_to_buffer())
	_photo_is_plating = true
	_plating_photo_revision = _plating_revision
	viewport.queue_free()
	world.audio.play_effect("tap")

func _hotspot(node_name: String, rect: Rect2, tip: String, callback: Callable) -> void :
	var button: = Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.tooltip_text = tip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(callback)
	hud.add_child(button)

func _dock_button(parent: Node, text: String, callback: Callable, width: float) -> Button:
	var button: = _button(parent, text, callback, width)
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed"]:
		var box: = StyleBoxFlat.new()
		box.bg_color = Color("393029e6") if state == "normal" else Color("6a5440")
		box.border_color = Color("806b52")
		box.set_border_width_all(1)
		box.set_content_margin_all(6)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color("ecd6b6"))
	button.add_theme_color_override("font_hover_color", Color("fff0ce"))
	button.add_theme_color_override("font_pressed_color", Color("fff0ce"))
	return button

func _draw_mystery() -> void :
	if is_instance_valid(world._held) or world._knife_held or world.has_active_utensil() or world.pan.active:
		_notify("先放下手里的东西，再从奇物箱取一件。")
		return
	if _mystery_bag.is_empty():
		_mystery_bag = preload("res://modules/restaurant/assets/sprite_library.gd").MYSTERY.duplicate()
		_mystery_bag.shuffle()
		if _mystery_bag[0] == _last_mystery: _mystery_bag.reverse()
	var id: String = str(_mystery_bag[0])
	var definition: = _definition(id)
	_take_ingredient(definition)
	if is_instance_valid(world._held) and world._held.get_meta("id", "") == id:
		_mystery_bag.pop_front()
		_last_mystery = id
		_notify("奇物箱里是%s！这一轮还剩%d件不同的东西。" % [definition.name, _mystery_bag.size()])
