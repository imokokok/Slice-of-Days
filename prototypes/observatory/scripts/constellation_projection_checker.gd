class_name ConstellationProjectionChecker
extends Node
signal matched
@export var error_threshold := 0.008
@export var hold_duration := 1.25
@export var attraction_strength := 0.2
var elapsed := 0.0
var attraction := 0.0
var error := INF
var completed := false
func configure(data: ConstellationData) -> void:
 error_threshold = data.error_threshold
 hold_duration = data.hold_duration
 attraction_strength = data.attraction_strength
 elapsed = 0.0
 completed = false
 attraction = 0.0
 error = INF
func normalize_points(points: PackedVector2Array) -> PackedVector2Array:
 var center := Vector2.ZERO
 for p in points: center += p
 center /= max(points.size(), 1)
 var radius := 0.0
 for p in points: radius += p.distance_squared_to(center)
 radius = sqrt(radius / max(points.size(), 1))
 var result := PackedVector2Array()
 for p in points: result.append((p - center) / max(radius, 0.0001))
 return result
func measure(camera: Camera3D, data: ConstellationData) -> float:
 if data.positions.size() != data.template.size() or data.positions.size() < 3: return INF
 var projected := PackedVector2Array()
 var rect := camera.get_viewport().get_visible_rect()
 for p in data.positions:
  if camera.is_position_behind(p): return INF
  var screen := camera.unproject_position(p)
  if not rect.has_point(screen): return INF
  projected.append(screen)
 var a := normalize_points(projected)
 var b := normalize_points(data.template)
 var total := 0.0
 for i in a.size(): total += a[i].distance_to(b[i])
 return total / a.size()
func step(camera: Camera3D, data: ConstellationData, delta: float) -> void:
 error = measure(camera, data)
 attraction = (1.0 - smoothstep(error_threshold, error_threshold * 3.0, error)) * attraction_strength
 if completed: return
 elapsed = elapsed + delta if error < error_threshold else 0.0
 if elapsed >= hold_duration:
  completed = true
  matched.emit()
