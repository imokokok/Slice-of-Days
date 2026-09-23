extends Control
## Mail and application actions share a landing; private rooms remain separate.
const PALETTE=preload("res://scripts/ui/components/interface_palette.gd")
var page: Control
var status: Label

func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme=PALETTE.theme_for_tools()
	var dim := ColorRect.new(); dim.color=Color("263d39",.45); dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(dim)
	page=Control.new(); page.position=Vector2(220,115); page.size=Vector2(1160,650); add_child(page)
	var paper := preload("res://scripts/ui/components/book_surface.gd").new(); paper.size=page.size; page.add_child(paper)
	_words("门口信箱",Vector2(54,48),470,32)
	_words(HouseholdSystem.ADDRESS,Vector2(57,97),470,21)
	_words("放在门口的话",Vector2(638,48),435,28)
	var read_scroll := ScrollContainer.new(); read_scroll.position=Vector2(638,116); read_scroll.size=Vector2(420,295); read_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; page.add_child(read_scroll)
	status=PALETTE.words(read_scroll,"拿好自己的钥匙，回房间时放轻脚步。",Vector2.ZERO,395,23); status.size_flags_horizontal=SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new(); scroll.position=Vector2(54,157); scroll.size=Vector2(470,238); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; page.add_child(scroll)
	var letters := VBoxContainer.new(); letters.add_theme_constant_override("separation",14); letters.size_flags_horizontal=SIZE_EXPAND_FILL; scroll.add_child(letters)
	for row in HouseholdSystem.mail():
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation",10); letters.add_child(line)
		var caption := str(row.title)+" · 第 %d 天"%int(row.day)
		if CharacterSystem.switch_unlocked(): caption+=" · "+str(row.owner)
		var letter := _button(caption,func():status.text=LocalizationSystem.text(str(HouseholdSystem.read_mail(str(row.id)).get("message",""))),"tab")
		letter.custom_minimum_size=Vector2(330,58); letter.size_flags_horizontal=SIZE_EXPAND_FILL; letter.alignment=HORIZONTAL_ALIGNMENT_LEFT; line.add_child(letter)
		var putback := _button("放回",func():status.text=LocalizationSystem.text(str(HouseholdSystem.read_mail(str(row.id),true).get("message",""))))
		putback.custom_minimum_size=Vector2(80,58); line.add_child(putback)
	var audit := HouseholdSystem.application()
	_words("旅居申请",Vector2(54,425),470,25)
	_words("自己获得的认可 %d / 12"%int(audit.confirmed),Vector2(56,466),470,21)
	_at(_button("查看申请进度",func():
		var names: Array[String]=[]
		for id in ResidentProfileSystem.profiles: names.append(("✓ " if GameState.confirmed_residents.has(id) else "○ ")+GuidanceSystem.source_name(str(id)))
		status.text="\n".join(names)),Vector2(54,520),Vector2(220,48))
	_at(_button("投递申请",func():status.text=LocalizationSystem.text(str(HouseholdSystem.submit_application().message)),"paper"),Vector2(289,520),Vector2(220,48))
	if CharacterSystem.switch_unlocked():
		_at(_button("交流居民去向",func():
			if not HouseholdSystem.exchange_leads(): status.text=LocalizationSystem.text("这次交流还没能保存。"); return
			var count := int(HouseholdSystem.state().shared_leads.get(GameState.current_role,0))
			status.text=LocalizationSystem.text("新记下 %d 位居民的地点线索。见面和认可仍要自己完成。"%count if count>0 else "目前没有新的地点线索，已经交流过的内容留在随身本里。")),Vector2(638,448),Vector2(420,48))
	var routines: Array=HouseholdSystem.state().routines.values()
	routines.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.day)*1440+int(a.minute)>int(b.day)*1440+int(b.minute))
	for routine in routines:
		if int(routine.day)==GameState.current_day: status.text=LocalizationSystem.text(str(routine.text)); break
	var enter := _button("上楼回房" if GameState.current_role=="A" else "回楼下房间",func():SceneRouter.enter_space("home_a" if GameState.current_role=="A" else "home_b"); queue_free(),"primary")
	enter.name="EnterPrivateRoom"; _at(enter,Vector2(638,520),Vector2(265,52))
	_at(_button("收起",queue_free),Vector2(919,520),Vector2(139,52)).grab_focus()

func _words(value: String, at: Vector2, width: float, points: int) -> Label:
	return PALETTE.words(page,value,at,width,points)

func _at(node: Control, at: Vector2, extent: Vector2) -> Control:
	node.position=at; node.size=extent; page.add_child(node); return node

func _button(value: String, action: Callable, variant := "quiet") -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new(); button.text=LocalizationSystem.text(value); button.variant=variant; button.pressed.connect(action); return button

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): queue_free(); get_viewport().set_input_as_handled()
