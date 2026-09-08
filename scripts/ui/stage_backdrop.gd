extends Control

const INK := Color("07090f")
const INDIGO := Color("111828")
const TEAL := Color("183d49")
const CYAN := Color("4ca9b2")
const AMBER := Color("d78a38")
const EMBER := Color("9f392e")
const BONE := Color("d7cfbd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var sx: float = size.x / 1600.0
	var sy: float = size.y / 900.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	draw_rect(Rect2(0, 0, 1600, 900), INK)

	# Distant stage planes; the town ends in darkness rather than a complete backdrop.
	_poly([Vector2(0, 92), Vector2(430, 82), Vector2(380, 500), Vector2(0, 560)], INDIGO)
	_poly([Vector2(990, 88), Vector2(1600, 62), Vector2(1600, 560), Vector2(1080, 505)], Color("10131f"))
	_poly([Vector2(405, 100), Vector2(1040, 70), Vector2(1100, 500), Vector2(360, 510)], Color("0b0f18"))

	# Fireplace alcove.
	_poly([Vector2(45, 168), Vector2(315, 135), Vector2(350, 470), Vector2(24, 505)], Color("17151a"))
	_poly([Vector2(74, 207), Vector2(278, 190), Vector2(299, 433), Vector2(60, 454)], Color("2a2524"))
	_poly([Vector2(113, 268), Vector2(245, 258), Vector2(261, 419), Vector2(95, 429)], Color("09090d"))
	_poly([Vector2(126, 397), Vector2(148, 306), Vector2(177, 392)], EMBER)
	_poly([Vector2(158, 402), Vector2(190, 286), Vector2(215, 398)], AMBER)
	_poly([Vector2(200, 399), Vector2(219, 327), Vector2(242, 407)], Color("e6aa52"))

	# Central night-market doorway.
	_poly([Vector2(590, 145), Vector2(945, 137), Vector2(930, 486), Vector2(575, 485)], Color("181922"))
	_poly([Vector2(690, 187), Vector2(852, 181), Vector2(848, 455), Vector2(681, 458)], Color("09111d"))
	_poly([Vector2(700, 206), Vector2(836, 201), Vector2(817, 439), Vector2(702, 447)], Color("12333f"))
	_poly([Vector2(724, 238), Vector2(819, 228), Vector2(807, 420), Vector2(734, 425)], Color("1a5260"))
	_poly([Vector2(739, 354), Vector2(805, 282), Vector2(805, 421), Vector2(739, 427)], Color(0.42, 0.78, 0.78, 0.18))

	# Faceted attendant silhouette on the right.
	_poly([Vector2(1260, 214), Vector2(1334, 188), Vector2(1389, 230), Vector2(1361, 333), Vector2(1272, 326)], Color("25212b"))
	_poly([Vector2(1292, 203), Vector2(1336, 174), Vector2(1370, 218), Vector2(1339, 256), Vector2(1299, 244)], Color("1a1b24"))
	_poly([Vector2(1271, 325), Vector2(1362, 331), Vector2(1428, 478), Vector2(1217, 480)], Color("141923"))
	_poly([Vector2(1308, 204), Vector2(1337, 178), Vector2(1340, 250)], Color("b66b43"))
	_poly([Vector2(1360, 331), Vector2(1427, 476), Vector2(1368, 469)], Color("153947"))

	# Table and its angular light pool.
	_poly([Vector2(96, 468), Vector2(1510, 454), Vector2(1600, 666), Vector2(0, 680)], Color("251d1e"))
	_poly([Vector2(217, 492), Vector2(1317, 478), Vector2(1450, 630), Vector2(113, 646)], Color("3c2921"))
	_poly([Vector2(498, 481), Vector2(1098, 474), Vector2(1218, 627), Vector2(390, 640)], Color(0.72, 0.38, 0.16, 0.22))
	_poly([Vector2(548, 502), Vector2(820, 489), Vector2(855, 604), Vector2(531, 613)], Color("202838"))
	_poly([Vector2(913, 497), Vector2(1170, 492), Vector2(1240, 600), Vector2(905, 608)], Color("35231f"))

	# Props represented as simple stage geometry.
	_poly([Vector2(337, 535), Vector2(458, 524), Vector2(468, 594), Vector2(329, 602)], BONE.darkened(0.35))
	_poly([Vector2(366, 546), Vector2(437, 540), Vector2(440, 550), Vector2(365, 556)], BONE.darkened(0.58))
	_poly([Vector2(951, 517), Vector2(1008, 513), Vector2(1020, 584), Vector2(944, 589)], Color("722c31"))
	_poly([Vector2(1045, 510), Vector2(1102, 509), Vector2(1113, 579), Vector2(1037, 583)], Color("1f5360"))
	_poly([Vector2(1135, 511), Vector2(1192, 511), Vector2(1205, 575), Vector2(1127, 580)], Color("665034"))

	# Thin horizon accent and foreground void.
	draw_line(Vector2(0, 666), Vector2(1600, 650), Color(0.63, 0.19, 0.2, 0.5), 2.0)
	_poly([Vector2(0, 680), Vector2(1600, 666), Vector2(1600, 900), Vector2(0, 900)], Color("080b12"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _poly(points: Array[Vector2], color: Color) -> void:
	draw_polygon(PackedVector2Array(points), PackedColorArray([color]))

