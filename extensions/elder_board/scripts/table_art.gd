extends RefCounted
## Authored tabletop and cutout pieces; coordinates remain native game hit areas.
const TABLE = preload("res://art/ui/pocket_doodles/chess_table.png")
const PIECES = preload("res://art/ui/pocket_doodles/chess_pieces.png")
const INK := Color("594c38")
const WOOD := Color("edcf98")
const SAGE := Color("9ea786")
const ORIGIN := Vector2(250, 177)
const EXTENT := 608.0

static func tabletop(canvas: CanvasItem) -> void:
	canvas.draw_texture_rect(TABLE, Rect2(0, 0, 1579, 972), false)

static func piece(canvas: CanvasItem, kind: int, side: int, rect: Rect2) -> void:
	# Keep one full atlas cell so the relative heights of pawn and king survive.
	var source := Rect2((kind - 1) * 256, 76 if side > 0 else 520, 256, 436)
	var at := Rect2(rect.position + Vector2(rect.size.x * .11, 2), Vector2(rect.size.x * .78, rect.size.y - 4))
	canvas.draw_texture_rect_region(PIECES, at, source)

static func stone(canvas: CanvasItem, at: Vector2, radius: float, side: int) -> void:
	canvas.draw_circle(at + Vector2(1, 2), radius, Color(INK, .16))
	canvas.draw_circle(at, radius, Color("52665d") if side > 0 else Color("fcf0d3"))
	canvas.draw_arc(at, radius, 0, TAU, 36, INK, 1.3, true)
	canvas.draw_arc(at + Vector2(-radius * .08, -radius * .04), radius * .77, PI * 1.12, PI * 1.55, 12, Color("d7cba9", .35), 1.0, true)

static func grid(canvas: CanvasItem, n: int, origin: Vector2 = ORIGIN) -> void:
	var cell := EXTENT / (n - 1)
	for i in n:
		canvas.draw_line(origin + Vector2(i * cell, 0), origin + Vector2(i * cell, EXTENT), Color(INK, .77), 1.4, true)
		canvas.draw_line(origin + Vector2(0, i * cell), origin + Vector2(EXTENT, i * cell), Color(INK, .77), 1.4, true)
	var stars := [3, int(n / 2), n - 4] if n != 9 else [2, 4, 6]
	for x in stars:
		for y in stars:
			if n == 19 or x == y or x + y == n - 1:
				canvas.draw_circle(origin + Vector2(x, y) * cell, 3.5, INK)
