extends Panel
var kind := "note"
var caption := ""
var heading := ""
var place := ""
func _ready() -> void:
	custom_minimum_size = Vector2(640,210)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f8ebc8") if kind == "note" else Color("fff8e6")
	style.shadow_color = Color("614e33",0.18)
	style.shadow_size = 4
	add_theme_stylebox_override("panel",style)
	var label := Label.new()
	label.position = Vector2(26 if kind == "note" else 195,25)
	label.size = Vector2(580 if kind == "note" else 410,145)
	label.text = LocalizationSystem.text(heading) + "\n\n" + LocalizationSystem.text(caption)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",21)
	label.add_theme_color_override("font_color",Color("435752"))
	add_child(label)
	if not place.is_empty():
		var pin := Button.new()
		pin.position = Vector2(420,164)
		pin.size = Vector2(190,34)
		pin.text = LocalizationSystem.text("夹住这个地点")
		pin.pressed.connect(func() -> void: WorldGraph.toggle_pin(place); pin.text = LocalizationSystem.text("已夹好" if WorldGraph.pins().has(place) else "夹住这个地点"))
		add_child(pin)
func _draw() -> void:
	if kind == "postcard":
		draw_rect(Rect2(18,18,155,170),Color("406bd0"))
		draw_rect(Rect2(18,112,155,76),Color("2e9aa9"))
		draw_colored_polygon(PackedVector2Array([Vector2(20,148),Vector2(120,143),Vector2(173,170),Vector2(173,188),Vector2(18,188)]),Color("efdcad"))
		draw_line(Vector2(36,135),Vector2(89,135),Color("fff8df"),2)
	else:
		draw_rect(Rect2(245,0,120,13),Color("bcac6e",0.55))
