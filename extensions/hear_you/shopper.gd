extends RefCounted
## A human figure in the shared game's restrained, faceless visual language.
static func draw(canvas: CanvasItem, side: int, at: Vector2) -> void:
	var coat := Color("718573") if side == 0 else Color("a07757")
	var skin := Color("b0a58c")
	var ink := Color("344047")
	var direction := 1.0 if side == 0 else -1.0
	canvas.draw_set_transform(at,0,Vector2(direction,1))
	# Legs, torso, neck and an angular profile; no floating face symbols.
	canvas.draw_line(Vector2(-12,-90),Vector2(-18,-8),ink,19,true)
	canvas.draw_line(Vector2(13,-90),Vector2(23,-8),ink.lightened(0.08),19,true)
	canvas.draw_line(Vector2(-23,-4),Vector2(-4,-4),ink,10,true)
	canvas.draw_line(Vector2(17,-4),Vector2(39,-4),ink,10,true)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-22,-194),Vector2(18,-194),Vector2(31,-102),Vector2(24,-85),Vector2(-29,-85)]),coat)
	canvas.draw_rect(Rect2(-8,-212,18,24),skin.darkened(0.1))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-18,-249),Vector2(9,-256),Vector2(21,-242),Vector2(20,-229),Vector2(26,-224),Vector2(19,-220),Vector2(15,-207),Vector2(-6,-207),Vector2(-18,-222)]),skin)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-19,-220),Vector2(-22,-244),Vector2(-12,-260),Vector2(13,-259),Vector2(23,-244),Vector2(4,-245),Vector2(-6,-231),Vector2(-10,-216)]),ink)
	canvas.draw_line(Vector2(-17,-184),Vector2(-28,-136),coat.darkened(0.12),18,true)
	canvas.draw_line(Vector2(17,-185),Vector2(28,-150),coat.lightened(0.06),18,true)
	canvas.draw_line(Vector2(28,-150),Vector2(55,-156),coat.lightened(0.06),15,true)
	canvas.draw_line(Vector2(55,-156),Vector2(65,-159),skin,8,true)
	canvas.draw_set_transform(Vector2.ZERO)
