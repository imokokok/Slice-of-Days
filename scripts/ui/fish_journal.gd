extends Control
const FISH = preload("res://scripts/core/coastal_fishing.gd")
const ART = preload("res://scripts/ui/components/handmade_assets.gd")
const P = preload("res://scripts/ui/components/interface_palette.gd")
var detail: VBoxContainer
var illustration: TextureRect
func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT); theme=P.theme_for_tools()
	var back := Panel.new(); back.set_anchors_and_offsets_preset(PRESET_FULL_RECT); back.add_theme_stylebox_override("panel",P.face(P.CREAM,0,0)); add_child(back)
	P.words(self,"海边笔记 · 每一次遇见",Vector2(78,48),1080,34)
	var close := preload("res://scripts/ui/components/solmere_button.gd").new(); close.text=LocalizationSystem.text("返回")+" · "+SettingsSystem.binding_text("ui_cancel"); close.position=Vector2(1290,42); close.size=Vector2(230,48); close.pressed.connect(queue_free); add_child(close)
	var scroll := ScrollContainer.new(); scroll.position=Vector2(78,145); scroll.size=Vector2(495,370); add_child(scroll)
	illustration=TextureRect.new(); illustration.position=Vector2(130,550); illustration.size=Vector2(350,190); illustration.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; illustration.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; illustration.mouse_filter=MOUSE_FILTER_IGNORE; add_child(illustration)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal=SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",16); scroll.add_child(rows)
	var detail_scroll := ScrollContainer.new(); detail_scroll.position=Vector2(643,145); detail_scroll.size=Vector2(815,635); detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(detail_scroll)
	detail=VBoxContainer.new(); detail.size_flags_horizontal=SIZE_EXPAND_FILL; detail.add_theme_constant_override("separation",19); detail_scroll.add_child(detail)
	var catches: Array=FISH.state().catches.duplicate(true); catches.reverse()
	for caught: Dictionary in catches:
		var button := preload("res://scripts/ui/components/solmere_button.gd").new(); button.custom_minimum_size=Vector2(460,86); rows.add_child(button)
		button.text=LocalizationSystem.text("%s · %.1f 厘米\n第 %d 天 · %s" % [LocalizationSystem.text(FISH.species(str(caught.id)).get("name",caught.get("name","鱼获"))),float(caught.length_cm),int(caught.day),LocalizationSystem.text("带回厨房" if caught.kept else "放回海里")])
		button.pressed.connect(_select.bind(caught))
	if catches.is_empty():
		var empty := Label.new(); empty.text=LocalizationSystem.text("还没有鱼获记录。\n钓到后，无论收下或放生，\n都可以在这里翻看。"); rows.add_child(empty)
		_words("先认识这里的海鱼",28)
		for species: Dictionary in FISH.SPECIES:
			var button := preload("res://scripts/ui/components/solmere_button.gd").new(); button.text=LocalizationSystem.text(species.name)+" · "+LocalizationSystem.text("资料"); button.custom_minimum_size.y=52; detail.add_child(button); button.pressed.connect(_select.bind({"id":species.id}))
	else: _select(catches[0])
	close.grab_focus()
func _words(text: String, point := 23) -> Label:
	var label := Label.new(); label.text=LocalizationSystem.text(text); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size",point); detail.add_child(label); return label
func _select(caught: Dictionary) -> void:
	for child in detail.get_children(): detail.remove_child(child); child.queue_free()
	var species := FISH.species(str(caught.id))
	illustration.texture=ART.texture(str(caught.id)) if not species.is_empty() else null
	_words(str(species.get("name",caught.get("name","历史记录"))),32)
	_words(str(species.get("scientific_name","")),20)
	if caught.has("length_cm"):
		var place := "港湾海边" if str(caught.location)=="port" else "观景台下的海边" if str(caught.location)=="park" else TravelSystem.location_name(str(caught.location))
		_words("%.1f 厘米 · %s\n第 %d 天 %02d:%02d · %s" % [float(caught.length_cm),FISH.size_description(caught),int(caught.day),int(caught.minute)/60,int(caught.minute)%60,place],24)
		var same: Array = FISH.state().catches.filter(func(row: Dictionary):return row.id==caught.id)
		var longest := 0.0
		for row: Dictionary in same: longest=maxf(longest,float(row.length_cm))
		_words("已记录 %d 次 · 自己遇见的最长个体 %.1f 厘米" % [same.size(),longest],20)
	_words(str(species.get("size_note","")))
	_words(str(species.get("habitat",""))+"\n"+str(species.get("diet","")))
	_words(str(species.get("story","")))
	_words("尺寸资料：FAO。出现比例属于游戏设计。",18)
	var source := LinkButton.new(); source.text=LocalizationSystem.text("阅读鱼种资料"); source.add_theme_font_size_override("font_size",21)
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]: source.add_theme_color_override(state,P.INK)
	source.pressed.connect(func(): OS.shell_open(str(species.get("source","")))); detail.add_child(source)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): queue_free(); get_viewport().set_input_as_handled()
