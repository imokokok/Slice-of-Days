extends Control
## One front door, shared mail and landing, private rooms on separate floors.
const PALETTE=preload("res://scripts/ui/components/interface_palette.gd")
var rows: VBoxContainer
var status: Label

func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme=PALETTE.theme_for_tools()
	var dim := ColorRect.new(); dim.color=Color("172f45",.32); dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(dim)
	var page := PanelContainer.new(); page.position=Vector2(285,100); page.size=Vector2(1030,700); add_child(page)
	page.add_theme_stylebox_override("panel",PALETTE.face(PALETTE.CREAM,8))
	var margin := MarginContainer.new(); page.add_child(margin)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,32)
	rows=VBoxContainer.new(); rows.add_theme_constant_override("separation",12); margin.add_child(rows)
	_words("门口 · 楼梯与信箱",29)
	_words(HouseholdSystem.ADDRESS+" · "+("楼上是 A 的房间，楼下是 B 的房间。" if CharacterSystem.switch_unlocked() else "拿好自己的钥匙，回房间时放轻脚步。"),20)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size=Vector2(950,260); rows.add_child(scroll)
	var letters := VBoxContainer.new(); letters.size_flags_horizontal=SIZE_EXPAND_FILL; scroll.add_child(letters)
	for row in HouseholdSystem.mail():
		var label := str(row.title)+" · 第 %d 天"%int(row.day)
		if CharacterSystem.switch_unlocked(): label+=" · "+str(row.owner)
		var line := HBoxContainer.new(); letters.add_child(line)
		_button(line,label,func(): status.text=LocalizationSystem.text(str(HouseholdSystem.read_mail(str(row.id)).get("message",""))))
		_button(line,"放回",func(): status.text=LocalizationSystem.text(str(HouseholdSystem.read_mail(str(row.id),true).get("message",""))))
	var audit := HouseholdSystem.application()
	_words("旅居申请 · 自己获得的认可 %d/12"%int(audit.confirmed),23)
	var actions := HBoxContainer.new(); rows.add_child(actions)
	_button(actions,"查看申请进度",func():
		var names: Array[String]=[]
		for id in ResidentProfileSystem.profiles:
			names.append(("✓ " if GameState.confirmed_residents.has(id) else "○ ")+GuidanceSystem.source_name(str(id)))
		status.text=" · ".join(names))
	_button(actions,"投递申请",func():status.text=LocalizationSystem.text(str(HouseholdSystem.submit_application().message)))
	if CharacterSystem.switch_unlocked():
		_button(actions,"交流居民去向",func():
			if not HouseholdSystem.exchange_leads(): status.text=LocalizationSystem.text("这次交流还没能保存。"); return
			var count := int(HouseholdSystem.state().shared_leads.get(GameState.current_role,0))
			status.text=LocalizationSystem.text("新记下 %d 位居民的地点线索。见面和认可仍要自己完成。"%count if count>0 else "目前没有新的地点线索，已经交流过的内容留在随身本里。"))
	status=_words("信箱里的小误差不必立刻解释。用过的通知可以放回去。",21)
	var routines: Array=HouseholdSystem.state().routines.values()
	routines.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.day)*1440+int(a.minute)>int(b.day)*1440+int(b.minute))
	for routine in routines:
		if int(routine.day)==GameState.current_day:
			status.text=LocalizationSystem.text(str(routine.text)); break
	status.custom_minimum_size.y=100
	var home := HBoxContainer.new(); rows.add_child(home)
	_button(home,"上楼回房" if GameState.current_role=="A" else "回楼下房间",func():
		SceneRouter.enter_space("home_a" if GameState.current_role=="A" else "home_b"); queue_free()).name="EnterPrivateRoom"
	_button(home,"收起",queue_free).grab_focus()

func _words(value: String, points: int) -> Label:
	var label := Label.new(); label.text=LocalizationSystem.text(value); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size",points); label.add_theme_color_override("font_color",PALETTE.INK); rows.add_child(label); return label

func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new(); button.text=LocalizationSystem.text(value); button.custom_minimum_size=Vector2(145,49); button.size_flags_horizontal=SIZE_EXPAND_FILL; parent.add_child(button); button.pressed.connect(action); return button

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): queue_free(); get_viewport().set_input_as_handled()
