extends Control
## A visual light table / B layered sound desk. Enter a paper, return to the same desk.
var selected := 0
var papers: Array = []
var cards: Array[TextureButton] = []
var memory_view: Control
var stem_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for row in MetaExperience.memories:
		if str(row.role) == GameState.current_role: papers.append(row)
	_build()

func _draw() -> void:
	draw_rect(Rect2(0,0,1600,900),Color("304b4c"))
	draw_rect(Rect2(65,135,1470,690),Color("9b7250"))
	for y in range(140,820,85):draw_line(Vector2(65,y),Vector2(1535,y),Color("6f503d",.3),2)
	draw_rect(Rect2(155,200,1265,460),Color("d6d2b5" if GameState.current_role == "A" else "20373d"))
	if GameState.current_role == "A":
		draw_circle(Vector2(1450,170),37,Color("bd8790"))
		draw_circle(Vector2(1450,132),30,Color("bd8790"))
		draw_circle(Vector2(1414,170),16,Color("ce9fa7"))
		draw_circle(Vector2(1486,170),16,Color("ce9fa7"))
		for x in [1439,1461]:draw_circle(Vector2(x,128),3,Color("354b4e"))

func _build() -> void:
	var title := Label.new()
	title.text = LocalizationSystem.text("A · 透光台" if GameState.current_role == "A" else "B · 采样桌")
	title.position = Vector2(80,50)
	title.add_theme_font_size_override("font_size",32)
	add_child(title)
	var hint := Label.new()
	hint.text = LocalizationSystem.text("点开一张纸。声音会先到。")
	hint.position = Vector2(80,100)
	add_child(hint)
	for i in papers.size():
		var button := TextureButton.new()
		button.texture_normal = load(str(papers[i].paper))
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.position = Vector2(160+i*165,245+(i%2)*50)
		button.size = Vector2(250,330)
		button.rotation = deg_to_rad(-5+i*1.5) if GameState.current_role == "A" else 0.0
		button.tooltip_text = LocalizationSystem.text(papers[i].title)
		add_child(button)
		cards.append(button)
		button.pressed.connect(_enter.bind(i))
		var caption := Label.new()
		caption.position = Vector2(150+i*198,610)
		caption.size = Vector2(185,65)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size",17)
		caption.text = LocalizationSystem.text(str(papers[i].title))
		add_child(caption)
		if GameState.current_role == "B":
			var stem := AudioStreamPlayer.new()
			stem.stream = load(str(papers[i].audio))
			stem.volume_db = -9
			add_child(stem)
			stem_players.append(stem)
			var toggle := CheckButton.new()
			toggle.position = Vector2(150+i*198,705)
			toggle.text = LocalizationSystem.text("听这一层")
			add_child(toggle)
			toggle.toggled.connect(func(on: bool) -> void: stem.play() if on else stem.stop())
			stem.finished.connect(func() -> void: if toggle.button_pressed: stem.play())
			var gain := HSlider.new()
			gain.position = Vector2(157+i*198,765)
			gain.size = Vector2(150,22)
			gain.min_value = -30
			gain.max_value = 0
			gain.value = -9
			gain.tooltip_text = LocalizationSystem.text("这一层的音量")
			gain.value_changed.connect(func(value: float) -> void: stem.volume_db = value)
			add_child(gain)
	if GameState.current_role == "A":
		var combine := CheckButton.new()
		combine.text = LocalizationSystem.text("叠起来看")
		combine.position = Vector2(190,740)
		add_child(combine)
		combine.toggled.connect(func(on: bool) -> void:
			for i in cards.size():
				cards[i].position = Vector2(540+i*12,220+i*8) if on else Vector2(160+i*165,245+(i%2)*50)
				cards[i].size = Vector2(400,380) if on else Vector2(250,330)
				cards[i].modulate.a = .35 if on else 1.0)
	var close := Button.new()
	close.text = LocalizationSystem.text("回到房间")
	close.position = Vector2(1330,50)
	close.size = Vector2(190,50)
	close.pressed.connect(queue_free)
	add_child(close)
	var room_button := Button.new()
	room_button.text = LocalizationSystem.text("看看房间")
	room_button.position = Vector2(1100,50)
	room_button.size = Vector2(190,50)
	add_child(room_button)
	room_button.pressed.connect(func() -> void:
		if is_instance_valid(memory_view): return
		memory_view = preload("res://scripts/meta/memory_view.gd").new()
		var room: Dictionary = papers[0].duplicate(true)
		room.id = GameState.current_role+"0"
		room.title = LocalizationSystem.text("A的房间" if GameState.current_role=="A" else "B的房间")
		room.model = "res://art/memories/"+str(room.id)+".glb"
		room.beat = "桌上的七张纸还在那里。"
		memory_view.definition = room
		add_child(memory_view))

func _enter(index: int) -> void:
	if is_instance_valid(memory_view): return
	if not MetaExperience.enabled("memories"): return
	selected = index
	for player in stem_players: player.stop()
	memory_view = preload("res://scripts/meta/memory_view.gd").new()
	memory_view.definition = papers[index]
	memory_view.entry_rect = cards[index].get_global_rect()
	if DisplayServer.get_name()!="headless": memory_view.entry_background = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	add_child(memory_view)

func _input(event: InputEvent) -> void:
	if is_instance_valid(memory_view): return
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
