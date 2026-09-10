class_name TarotSigil
extends Control

const INK := Color("3d2d29")
const TEAL := Color("4f7d83")
const TERRACOTTA := Color("c85f43")
const SAGE := Color("7d8f59")
const GOLD := Color("c99545")
const PAPER := Color("f7e8c8")

var card_id := ""
var active := false
var illuminated := false


func configure(value: String, is_active := false, is_illuminated := false) -> void:
	card_id = value
	active = is_active
	illuminated = is_illuminated
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var center := Vector2(w * 0.5, h * 0.5)
	var ink := TERRACOTTA if active else (TEAL if illuminated else INK)
	var soft := Color(ink, 0.14)
	draw_circle(center, minf(w, h) * 0.34, soft)
	draw_arc(center, minf(w, h) * 0.31, 0.0, TAU, 48, Color(GOLD, 0.72), 2.0)
	match card_id:
		"fool":
			_draw_path(ink)
		"magician":
			_draw_magician(ink)
		"high_priestess":
			_draw_priestess(ink)
		"empress":
			_draw_empress(ink)
		"emperor":
			_draw_emperor(ink)
		"hierophant":
			_draw_keys(ink)
		"lovers":
			_draw_lovers(ink)
		"chariot":
			_draw_chariot(ink)
		"strength":
			_draw_strength(ink)
		"hermit":
			_draw_hermit(ink)
		"wheel":
			_draw_wheel(ink)
		"justice":
			_draw_justice(ink)
		"hanged_man":
			_draw_hanged(ink)
		"death":
			_draw_death(ink)
		"temperance":
			_draw_temperance(ink)
		"devil":
			_draw_devil(ink)
		"tower":
			_draw_tower(ink)
		"star":
			_draw_star(ink)
		"moon":
			_draw_moon(ink)
		"sun":
			_draw_sun(ink)
		"judgement":
			_draw_judgement(ink)
		"world":
			_draw_world(ink)
		_:
			_draw_star(ink)


func _p(x: float, y: float) -> Vector2:
	return Vector2(size.x * x, size.y * y)


func _figure(at: Vector2, scale: float, color: Color) -> void:
	draw_circle(at + Vector2(0, -10 * scale), 5 * scale, color)
	draw_line(at + Vector2(0, -4 * scale), at + Vector2(0, 15 * scale), color, 3 * scale)
	draw_line(at + Vector2(0, 3 * scale), at + Vector2(-8 * scale, 10 * scale), color, 2 * scale)
	draw_line(at + Vector2(0, 3 * scale), at + Vector2(8 * scale, 10 * scale), color, 2 * scale)
	draw_line(at + Vector2(0, 15 * scale), at + Vector2(-7 * scale, 27 * scale), color, 2 * scale)
	draw_line(at + Vector2(0, 15 * scale), at + Vector2(7 * scale, 27 * scale), color, 2 * scale)


func _draw_path(color: Color) -> void:
	draw_polyline(PackedVector2Array([_p(0.22, 0.72), _p(0.40, 0.57), _p(0.56, 0.61), _p(0.77, 0.32)]), color, 3.0)
	_figure(_p(0.43, 0.42), 0.72, color)
	draw_line(_p(0.72, 0.28), _p(0.84, 0.28), TERRACOTTA, 4.0)


func _draw_magician(color: Color) -> void:
	draw_line(_p(0.24, 0.68), _p(0.76, 0.68), color, 4.0)
	for x in [0.30, 0.43, 0.57, 0.70]:
		draw_circle(_p(x, 0.60), 4.5, GOLD)
	_figure(_p(0.50, 0.35), 0.70, color)
	draw_line(_p(0.50, 0.24), _p(0.50, 0.08), TERRACOTTA, 3.0)


func _draw_priestess(color: Color) -> void:
	draw_rect(Rect2(_p(0.26, 0.24), Vector2(size.x * 0.10, size.y * 0.48)), Color(color, 0.82), false, 3.0)
	draw_rect(Rect2(_p(0.64, 0.24), Vector2(size.x * 0.10, size.y * 0.48)), Color(color, 0.82), false, 3.0)
	draw_line(_p(0.36, 0.30), _p(0.64, 0.54), SAGE, 2.0)
	draw_line(_p(0.36, 0.54), _p(0.64, 0.30), SAGE, 2.0)
	draw_arc(_p(0.50, 0.25), 13, 0.2, PI * 1.8, 24, GOLD, 3.0)


func _draw_empress(color: Color) -> void:
	_figure(_p(0.50, 0.34), 0.82, color)
	for x in [0.26, 0.36, 0.64, 0.74]:
		draw_line(_p(x, 0.76), _p(x, 0.58), SAGE, 2.0)
		draw_circle(_p(x, 0.56), 4.0, GOLD)


func _draw_emperor(color: Color) -> void:
	draw_polyline(PackedVector2Array([_p(0.26, 0.72), _p(0.26, 0.36), _p(0.40, 0.36), _p(0.40, 0.25), _p(0.60, 0.25), _p(0.60, 0.36), _p(0.74, 0.36), _p(0.74, 0.72)]), color, 4.0)
	draw_line(_p(0.32, 0.72), _p(0.68, 0.72), color, 4.0)
	draw_polyline(PackedVector2Array([_p(0.42, 0.29), _p(0.46, 0.18), _p(0.50, 0.27), _p(0.55, 0.17), _p(0.59, 0.29)]), GOLD, 3.0)


func _draw_keys(color: Color) -> void:
	for x in [0.42, 0.58]:
		draw_circle(_p(x, 0.38), 9, color, false, 3.0)
		draw_line(_p(x, 0.48), _p(1.0 - x, 0.72), color, 3.0)
	draw_line(_p(0.50, 0.22), _p(0.50, 0.48), GOLD, 3.0)
	draw_line(_p(0.44, 0.28), _p(0.56, 0.28), GOLD, 3.0)


func _draw_lovers(color: Color) -> void:
	_figure(_p(0.37, 0.42), 0.70, color)
	_figure(_p(0.63, 0.42), 0.70, color)
	draw_arc(_p(0.50, 0.31), 24, PI, TAU, 24, TERRACOTTA, 3.0)
	draw_circle(_p(0.50, 0.22), 5, GOLD)


func _draw_chariot(color: Color) -> void:
	draw_rect(Rect2(_p(0.28, 0.38), Vector2(size.x * 0.44, size.y * 0.24)), Color(color, 0.08), true)
	draw_rect(Rect2(_p(0.28, 0.38), Vector2(size.x * 0.44, size.y * 0.24)), color, false, 3.0)
	draw_circle(_p(0.36, 0.68), 11, color, false, 3.0)
	draw_circle(_p(0.64, 0.68), 11, color, false, 3.0)
	draw_polyline(PackedVector2Array([_p(0.37, 0.33), _p(0.50, 0.20), _p(0.63, 0.33)]), GOLD, 3.0)


func _draw_strength(color: Color) -> void:
	draw_arc(_p(0.50, 0.50), 28, 0.0, TAU, 40, TERRACOTTA, 5.0)
	draw_circle(_p(0.43, 0.46), 4, color)
	draw_circle(_p(0.57, 0.46), 4, color)
	draw_arc(_p(0.50, 0.52), 13, 0.15, PI - 0.15, 18, color, 3.0)
	draw_line(_p(0.30, 0.28), _p(0.70, 0.72), SAGE, 3.0)


func _draw_hermit(color: Color) -> void:
	_figure(_p(0.48, 0.39), 0.78, color)
	draw_line(_p(0.62, 0.38), _p(0.68, 0.76), color, 3.0)
	draw_rect(Rect2(_p(0.28, 0.28), Vector2(22, 26)), Color(GOLD, 0.20), true)
	draw_rect(Rect2(_p(0.28, 0.28), Vector2(22, 26)), GOLD, false, 3.0)


func _draw_wheel(color: Color) -> void:
	var c := _p(0.50, 0.49)
	draw_circle(c, 34, color, false, 4.0)
	draw_circle(c, 9, GOLD, false, 3.0)
	for a in range(0, 360, 45):
		var v := Vector2.from_angle(deg_to_rad(a))
		draw_line(c + v * 10, c + v * 32, color, 2.0)


func _draw_justice(color: Color) -> void:
	draw_line(_p(0.50, 0.22), _p(0.50, 0.75), color, 4.0)
	draw_line(_p(0.28, 0.34), _p(0.72, 0.34), color, 3.0)
	for x in [0.32, 0.68]:
		draw_line(_p(x, 0.34), _p(x, 0.58), GOLD, 2.0)
		draw_arc(_p(x, 0.58), 14, 0.0, PI, 20, GOLD, 3.0)


func _draw_hanged(color: Color) -> void:
	draw_line(_p(0.30, 0.22), _p(0.70, 0.22), color, 4.0)
	draw_line(_p(0.50, 0.22), _p(0.50, 0.42), color, 3.0)
	draw_line(_p(0.50, 0.42), _p(0.50, 0.63), color, 3.0)
	draw_circle(_p(0.50, 0.70), 5.0, color)
	draw_line(_p(0.50, 0.50), _p(0.39, 0.58), color, 2.0)
	draw_line(_p(0.50, 0.50), _p(0.61, 0.58), color, 2.0)
	draw_line(_p(0.50, 0.42), _p(0.43, 0.31), color, 2.0)
	draw_line(_p(0.50, 0.42), _p(0.57, 0.31), color, 2.0)
	draw_circle(_p(0.50, 0.70), 13, Color(GOLD, 0.25))


func _draw_death(color: Color) -> void:
	draw_arc(_p(0.50, 0.50), 30, PI * 0.25, PI * 1.45, 30, color, 4.0)
	draw_line(_p(0.63, 0.28), _p(0.36, 0.73), color, 4.0)
	draw_circle(_p(0.32, 0.68), 9, TERRACOTTA, false, 3.0)
	draw_line(_p(0.22, 0.77), _p(0.78, 0.77), GOLD, 3.0)


func _draw_temperance(color: Color) -> void:
	for x in [0.34, 0.66]:
		draw_arc(_p(x, 0.42 if x < 0.5 else 0.60), 16, 0.0, PI, 20, color, 3.0)
		draw_line(_p(x - 0.09, 0.42 if x < 0.5 else 0.60), _p(x + 0.09, 0.42 if x < 0.5 else 0.60), color, 3.0)
	draw_polyline(PackedVector2Array([_p(0.40, 0.43), _p(0.50, 0.50), _p(0.60, 0.57)]), TEAL, 4.0)


func _draw_devil(color: Color) -> void:
	for x in [0.36, 0.64]:
		draw_circle(_p(x, 0.50), 15, color, false, 4.0)
	draw_arc(_p(0.50, 0.50), 32, 0.15, PI - 0.15, 28, TERRACOTTA, 4.0)
	draw_polyline(PackedVector2Array([_p(0.42, 0.26), _p(0.50, 0.17), _p(0.58, 0.26)]), GOLD, 3.0)


func _draw_tower(color: Color) -> void:
	draw_rect(Rect2(_p(0.34, 0.30), Vector2(size.x * 0.32, size.y * 0.46)), Color(color, 0.08), true)
	draw_rect(Rect2(_p(0.34, 0.30), Vector2(size.x * 0.32, size.y * 0.46)), color, false, 4.0)
	draw_polyline(PackedVector2Array([_p(0.58, 0.10), _p(0.47, 0.36), _p(0.57, 0.34), _p(0.43, 0.64)]), TERRACOTTA, 5.0)


func _draw_star(color: Color) -> void:
	var c := _p(0.50, 0.38)
	for a in range(0, 360, 45):
		var v := Vector2.from_angle(deg_to_rad(a))
		draw_line(c + v * 7, c + v * 29, GOLD, 3.0)
	draw_circle(c, 8, TERRACOTTA)
	draw_polyline(PackedVector2Array([_p(0.25, 0.70), _p(0.40, 0.65), _p(0.54, 0.72), _p(0.76, 0.63)]), TEAL, 3.0)


func _draw_moon(color: Color) -> void:
	draw_circle(_p(0.50, 0.33), 23, GOLD)
	draw_circle(_p(0.59, 0.28), 22, PAPER)
	for x in [0.28, 0.72]:
		draw_rect(Rect2(_p(x - 0.05, 0.46), Vector2(size.x * 0.10, size.y * 0.26)), color, false, 3.0)
	draw_polyline(PackedVector2Array([_p(0.50, 0.74), _p(0.44, 0.61), _p(0.55, 0.50)]), TEAL, 3.0)


func _draw_sun(color: Color) -> void:
	var c := _p(0.50, 0.46)
	draw_circle(c, 22, GOLD, false, 5.0)
	for a in range(0, 360, 30):
		var v := Vector2.from_angle(deg_to_rad(a))
		draw_line(c + v * 30, c + v * 42, TERRACOTTA, 3.0)


func _draw_judgement(color: Color) -> void:
	draw_polygon(PackedVector2Array([_p(0.28, 0.32), _p(0.62, 0.42), _p(0.28, 0.52)]), PackedColorArray([Color(GOLD, 0.35)]))
	draw_polyline(PackedVector2Array([_p(0.28, 0.32), _p(0.62, 0.42), _p(0.28, 0.52), _p(0.28, 0.32)]), color, 3.0)
	draw_line(_p(0.62, 0.42), _p(0.75, 0.42), color, 4.0)
	for x in [0.34, 0.50, 0.66]:
		draw_line(_p(x, 0.62), _p(x, 0.78), TERRACOTTA, 3.0)


func _draw_world(color: Color) -> void:
	var c := _p(0.50, 0.49)
	draw_arc(c, 36, 0.0, TAU, 52, SAGE, 6.0)
	_figure(_p(0.50, 0.42), 0.68, color)
	for pos in [_p(0.24, 0.25), _p(0.76, 0.25), _p(0.24, 0.73), _p(0.76, 0.73)]:
		draw_circle(pos, 5, GOLD)
