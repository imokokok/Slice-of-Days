extends Label
## Each letter follows a quiet arc; the thought remains part of the scenery.
var age := 0.0
func _ready() -> void:
	add_theme_color_override("font_color",Color.TRANSPARENT)
	add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
func _process(delta: float) -> void:
	if SettingsSystem.reduced_motion(): return
	age+=delta
	queue_redraw()
func _draw() -> void:
	var font := get_theme_font("font")
	var point := get_theme_font_size("font_size")
	var cursor := Vector2(0,point)
	for i in text.length():
		var letter := text.substr(i,1)
		var width := font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x
		if letter=="\n" or cursor.x+width>size.x:
			cursor=Vector2(0,cursor.y+point*1.6)
			if letter=="\n": continue
		var bend := sin(cursor.x/size.x*PI)*8
		var drift := 0.0 if SettingsSystem.reduced_motion() else sin(age*.7+i*.15)*2
		var at := cursor+Vector2(0,bend+drift)
		font.draw_string_outline(get_canvas_item(),at,letter,HORIZONTAL_ALIGNMENT_LEFT,-1,point,1,Color("254966",.5))
		font.draw_string(get_canvas_item(),at,letter,HORIZONTAL_ALIGNMENT_LEFT,-1,point,Color("fffaf0"))
		cursor.x+=width
