extends Panel
## Native, resizable paper. No baked UI image or hotspot layer.
func _ready() -> void:
	var face := StyleBoxFlat.new()
	face.bg_color=Color("faf7ee"); face.border_color=Color("ced4cf")
	face.set_border_width_all(1); face.set_corner_radius_all(8)
	add_theme_stylebox_override("panel",face)
	var grain := preload("res://scripts/ui/paper_grain.gd").new()
	add_child(grain)
