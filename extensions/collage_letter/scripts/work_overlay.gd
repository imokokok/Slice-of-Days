extends Node2D
const Tape=preload("res://extensions/collage_letter/scripts/tape_art.gd")
var game: Node2D
func _draw() -> void:
	if game.stage!="WORKBENCH":return
	if game.tape_drawing:
		var endpoint:=game.get_global_mouse_position()
		var length:=minf(game.tape_start.distance_to(endpoint),500)
		draw_set_transform((game.tape_start+endpoint)*0.5,(endpoint-game.tape_start).angle())
		Tape.paint(self,PackedVector2Array([Vector2(-length/2,-11),Vector2(length/2,-11),Vector2(length/2,11),Vector2(-length/2,11)]),game.tape_style)
		draw_set_transform(Vector2.ZERO)
	if game.doodle_drawing and game.doodle_path.size()>1: draw_polyline(game.doodle_path,game.pen_color,game.pen_width,true)
