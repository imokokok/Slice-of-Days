extends Control
## The book is native geometry, independent from every interactive page element.
var backing: Texture2D=preload("res://art/ui/blank-notebook-spread.png")
var spread := true
var ruled := false
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _sheet(rect: Rect2, ink: Color, bend: float) -> void:
	var p := PackedVector2Array()
	for i in 25:
		var t := i/24.0
		p.append(rect.position+Vector2(t*rect.size.x,3*sin(t*PI)+sin(i*2.6)*.6))
	for i in 25:
		var t := i/24.0
		p.append(rect.position+Vector2((1-t)*rect.size.x,rect.size.y+sin(t*PI)*bend))
	draw_colored_polygon(p,ink)
	p.append(p[0]); draw_polyline(p,Color("a9a697",.4),1,true)
func _draw() -> void:
	var w := size.x; var h := size.y
	if spread:
		draw_texture_rect(backing,Rect2(Vector2(-30,-9),size+Vector2(60,18)),false)
		if ruled:
			for y in range(150,int(h-80),58): draw_line(Vector2(243,y),Vector2(w*.5-43,y-2),Color("8e9e9c",.18),1,true)
		return
	_sheet(Rect2(0,14,w,h-20),Color("607e8f"),3)
	for i in 4:
		_sheet(Rect2(6+i*3,9+i*2,w-12-i*4,h-26-i*2),Color("d2c7a7").lightened(i*.065),2)
	if spread:
		_sheet(Rect2(23,18,w*.5-24,h-48),Color("f4edda"),-5)
		_sheet(Rect2(w*.5,18,w*.5-26,h-48),Color("f8f2e2"),-5)
		for i in 22:
			var a := .065*(1.0-absf(i-11)/11)
			draw_line(Vector2(w*.5-11+i,22),Vector2(w*.5-11+i,h-31),Color("776e50",a),1)
		draw_line(Vector2(w*.5,24),Vector2(w*.5,h-34),Color("b6ae96",.38),1)
	else:
		_sheet(Rect2(22,19,w-45,h-45),Color("f6efdf"),-2)
	if ruled:
		for y in range(140,int(h-90),60): draw_line(Vector2(87,y),Vector2(w*.5-58,y-3),Color("8e9e9c",.19),1,true)
	var rng := RandomNumberGenerator.new(); rng.seed=98
	for i in 2800:
		var at := Vector2(rng.randf_range(30,w-34),rng.randf_range(25,h-32))
		draw_line(at,at+Vector2(rng.randf_range(.5,2),.4),Color("8b805e",.045),1,true)
