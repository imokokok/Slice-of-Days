extends RefCounted
## Source-space anchors shared by the supplied art and its live interactions.
const PLATFORM = preload("res://art/user_scenes/lookout_platform_supplied.jpg")
const SCREEN = preload("res://art/user_scenes/lookout_screen_supplied.jpg")
const Paper = preload("res://scripts/ui/authored_jpeg.gd")
const PLATFORM_SCALE := 1300.0 / 1920.0
const SCREEN_SCALE := .34
const SCREEN_OFFSET := Vector2(180.0, -150.0)
const PLATFORM_OPENINGS: Array[Vector2i] = [
	Vector2i(500,665), Vector2i(1050,660), Vector2i(1550,665),
	Vector2i(700,690), Vector2i(900,690), Vector2i(1200,690),
	Vector2i(1430,690), Vector2i(175,735), Vector2i(300,680),
	Vector2i(550,660), Vector2i(620,670), Vector2i(660,603), Vector2i(1340,598),
	Vector2i(1086,624), Vector2i(1481,624), Vector2i(991,626), Vector2i(974,674),
	Vector2i(665,675), Vector2i(1161,676), Vector2i(1502,680), Vector2i(1801,625),
]
const SCREEN_OPENINGS: Array[Vector2i] = [Vector2i(900,800), Vector2i(1300,775)]

static func platform_rect(center: float, ground := 718.0) -> Rect2:
	return Rect2(center + 50.0 - 960.0 * PLATFORM_SCALE, ground - 850.0 * PLATFORM_SCALE, 1920.0 * PLATFORM_SCALE, 1080.0 * PLATFORM_SCALE)

static func screen_rect(center: float, ground := 718.0) -> Rect2:
	# Behind the middle of the two benches, above their backrests.
	return Rect2(center + SCREEN_OFFSET.x - 960.0 * SCREEN_SCALE, ground + SCREEN_OFFSET.y - 984.0 * SCREEN_SCALE, 1920.0 * SCREEN_SCALE, 1080.0 * SCREEN_SCALE)

static func photo_rect(center: float, ground := 718.0) -> Rect2:
	var screen := screen_rect(center, ground)
	return Rect2(screen.position + Vector2(407,137) * SCREEN_SCALE, Vector2(1060,567) * SCREEN_SCALE)

static func telescope_offset() -> float:
	return 50.0 + (1734.0 - 960.0) * PLATFORM_SCALE

static func telescope_rect(center: float, ground := 718.0) -> Rect2:
	return Rect2(platform_rect(center, ground).position + Vector2(1600,355) * PLATFORM_SCALE, Vector2(220,365) * PLATFORM_SCALE)

static func platform_texture() -> Texture2D:
	return Paper.cutout(PLATFORM, false, PLATFORM_OPENINGS)

static func screen_texture() -> Texture2D:
	return Paper.cutout(SCREEN, false, SCREEN_OPENINGS)
