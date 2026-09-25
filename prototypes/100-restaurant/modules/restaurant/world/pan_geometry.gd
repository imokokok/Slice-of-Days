extends RefCounted
## Shared local-space vessel silhouette; rendering and pointer occlusion agree.
const CENTER := Vector2(810, 579)
const RADIUS := Vector2(124, 38)
const ART_RECT := Rect2(686, 541, 412, 76)

static func front_y(x: float) -> float:
	var u := (x - CENTER.x) / RADIUS.x
	return CENTER.y + RADIUS.y * sqrt(maxf(0.0, 1.0 - u * u))

static func front_occludes(point: Vector2) -> bool:
	var u := (point.x - CENTER.x) / RADIUS.x
	if absf(u) > 1.0: return false
	var arc := sqrt(maxf(0.0, 1.0 - u * u))
	return point.y >= CENTER.y + RADIUS.y * arc and point.y <= 584.0 + 58.0 * arc

static func water_center(fill: float) -> Vector2:
	return Vector2(810, 597 - fill * 18)

static func water_radius(fill: float) -> Vector2:
	return Vector2(78 + fill * 32, 13 + fill * 21)
