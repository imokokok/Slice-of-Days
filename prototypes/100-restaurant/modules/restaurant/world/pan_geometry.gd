extends RefCounted
## Shared local-space vessel silhouette; rendering and pointer occlusion agree.
const CENTER := Vector2(810, 582)
const RADIUS := Vector2(124, 44)
# The original top-view painting was squeezed into 76 px, flattening a 1.5 L
# vessel. This projection leaves room for a visible curved, deep front wall.
const ART_RECT := Rect2(686, 530, 412, 116)
const FRONT_BOTTOM_CENTER_Y := 595.0
const FRONT_BOTTOM_RADIUS_Y := 74.0

static func front_y(x: float) -> float:
	var u := (x - CENTER.x) / RADIUS.x
	return CENTER.y + RADIUS.y * sqrt(maxf(0.0, 1.0 - u * u))

static func front_occludes(point: Vector2) -> bool:
	var u := (point.x - CENTER.x) / RADIUS.x
	if absf(u) > 1.0: return false
	var arc := sqrt(maxf(0.0, 1.0 - u * u))
	return point.y >= CENTER.y + RADIUS.y * arc and point.y <= FRONT_BOTTOM_CENTER_Y + FRONT_BOTTOM_RADIUS_Y * arc

static func water_center(fill: float) -> Vector2:
	return Vector2(810, 607 - fill * 20)

static func water_radius(fill: float) -> Vector2:
	return Vector2(78 + fill * 32, 15 + fill * 24)
