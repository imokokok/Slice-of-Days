@tool
class_name ConstellationData
extends Resource
@export var id := "bird"
@export var title := "飞鸟"
@export_multiline var hint := ""
@export var template := PackedVector2Array()
@export var positions := PackedVector3Array()
@export var sizes := PackedFloat32Array()
@export var main_stars := PackedInt32Array()
@export var lines := PackedInt32Array()
@export var reference_angles := Vector2.ZERO
@export var orbit_radius := 14.0
@export var reference_fov := 55.0
@export var error_threshold := 0.008
@export var hold_duration := 1.25
@export var attraction_strength := 0.2
func reference_transform() -> Transform3D:
 var basis := Basis.from_euler(Vector3(reference_angles.y, reference_angles.x, 0))
 return Transform3D(basis, basis * Vector3(0, 0, orbit_radius))
# 透视射线上分配深度，不能只改 Z，否则参考投影会被破坏。
func regenerate_depths(seed_value: int = 42) -> void:
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value
 positions.clear()
 var reference := reference_transform()
 var scale_y := tan(deg_to_rad(reference_fov * 0.5))
 for p in template:
  var depth := rng.randf_range(19.0, 52.0)
  positions.append(reference * Vector3(p.x * scale_y * depth, -p.y * scale_y * depth, -depth))
