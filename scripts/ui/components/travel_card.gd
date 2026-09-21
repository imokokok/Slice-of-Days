extends Control
var journey: Dictionary={}
func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter=MOUSE_FILTER_STOP
	var card := Panel.new(); card.position=Vector2(475,140); card.size=Vector2(650,610); add_child(card)
	var face := StyleBoxFlat.new(); face.bg_color=Color("f5f4ec"); face.set_corner_radius_all(13); card.add_theme_stylebox_override("panel",face)
	var logo := words(card,"Solmere",Vector2(30,28),Vector2(590,75),48)
	var font := SystemFont.new(); font.font_names=PackedStringArray(["Segoe Script"]); logo.add_theme_font_override("font",font)
	words(card,TravelSystem.location_name(str(journey.from))+"   →   "+TravelSystem.location_name(str(journey.to)),Vector2(32,134),Vector2(586,70),24)
	words(card,str(journey.method)+"  ·  %d 分钟  ·  %d 元" % [int(journey.minutes),int(journey.get("cost",0))],Vector2(30,221),Vector2(590,43),24)
	var events: Array=journey.get("events",[])
	for i in mini(3,events.size()): words(card,"◇ "+str(events[i]),Vector2(56,297+i*54),Vector2(542,48),18)
	words(card,GuidanceSystem.time_text(int(journey.start))+"    →    "+GuidanceSystem.time_text(int(journey.finish)),Vector2(30,509),Vector2(590,46),25)
	words(card,"同一座小镇，沿途不同的片刻。",Vector2(30,566),Vector2(590,26),15)
func words(parent: Node,value: String,at: Vector2,extent: Vector2,point: int) -> Label:
	var text := Label.new(); text.text=value; text.position=at; text.size=extent; text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; text.add_theme_font_size_override("font_size",point); text.add_theme_color_override("font_color",PaperLanguage.BLUE); parent.add_child(text); return text
