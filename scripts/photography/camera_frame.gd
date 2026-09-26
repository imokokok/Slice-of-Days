extends Control
var focused := false
func _draw() -> void:
	var ink := Color("fffdf5",.94)
	var extent := size*Vector2(.70,.67)
	var origin := (size-extent)*.5
	for corner in [Vector2.ZERO,Vector2(extent.x,0),Vector2(0,extent.y),extent]:
		var direction := Vector2(1 if corner.x==0 else -1,1 if corner.y==0 else -1)
		for endpoint in [Vector2(38*direction.x,0),Vector2(0,38*direction.y)]:
			draw_line(origin+corner+Vector2(0,1.5),origin+corner+endpoint+Vector2(0,1.5),Color("345a69",.35),5,true)
			draw_line(origin+corner,origin+corner+endpoint,ink,3,true)
	var center := size*.5
	var focus_color := Color("ffe08e") if focused else ink
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]: draw_line(center+direction*12,center+direction*22,focus_color,2,true)
	draw_circle(center,3,focus_color)
