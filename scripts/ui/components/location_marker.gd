extends "res://scripts/ui/components/solmere_button.gd"
func refresh() -> void:
	super.refresh()
	var face := StyleBoxFlat.new(); face.bg_color=Color.TRANSPARENT; face.content_margin_left=22; face.content_margin_right=5
	add_theme_stylebox_override("normal",face)
	alignment=HORIZONTAL_ALIGNMENT_LEFT
	queue_redraw()
func _draw() -> void:
	var center := Vector2(9,size.y*.5)
	draw_circle(center,4,PaperLanguage.BLUE,false,1.5,true)
	if str(get_meta("state",""))=="discovered": draw_circle(center,2,PaperLanguage.BLUE)
	if selected: draw_arc(center,9,-.15,TAU-.1,30,PaperLanguage.YELLOW,3,true)
