extends Control
## A material backing for concise, contextual instructions. Text stays accessible.
const CARD=preload("res://art/town_sound_cc0/card.png")
var tint:=Color("fff7df")
var ruled:=true
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var shadow:=StyleBoxFlat.new(); shadow.bg_color=Color("624e39",.13)
	draw_style_box(shadow,Rect2(Vector2(3,5),size))
	var paper:=StyleBoxTexture.new(); paper.texture=CARD; paper.modulate_color=tint
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: paper.set_texture_margin(side,4)
	draw_style_box(paper,Rect2(Vector2.ZERO,size))
	if ruled:
		for y in range(37,int(size.y)-7,28): draw_line(Vector2(16,y),Vector2(size.x-16,y),Color("91856c",.10))
	for i in 80:
		var x:=float(posmod(i*97,997))/997*size.x
		var y:=float(posmod(i*139,991))/991*size.y
		draw_line(Vector2(x,y),Vector2(x+2,y),Color("806e52",.045))
	draw_set_transform(Vector2(size.x*.72,1),-.05)
	draw_rect(Rect2(-35,-6,70,16),Color("b8ad7e",.6))
	draw_set_transform(Vector2.ZERO)
