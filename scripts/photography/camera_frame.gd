extends Control
func _draw() -> void:
	var ink := Color("fffaf0",.8)
	var extent := size*Vector2(.52,.55)
	var origin := (size-extent)*.5
	for corner in [Vector2.ZERO,Vector2(extent.x,0),Vector2(0,extent.y),extent]:
		var direction := Vector2(1 if corner.x==0 else -1,1 if corner.y==0 else -1)
		draw_line(origin+corner,origin+corner+Vector2(33*direction.x,0),ink,2,true)
		draw_line(origin+corner,origin+corner+Vector2(0,33*direction.y),ink,2,true)
