extends Sprite2D
## Display the two supplied standing poses directly from the original model sheet.
const SHEET = preload("res://art/user_scenes/zhou_xiaoliu.png")
const POSES := [Rect2(216,60,400,916), Rect2(695,60,360,916)]

func _init() -> void:
	texture = SHEET
	region_enabled = true
	region_filter_clip_enabled = true
	centered = false
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://scripts/ui/coastal_grade.gdshader")
	ink.set_shader_parameter("paper_key",true)
	material = ink

func stand_at(feet: Vector2, height: float, side_pose: bool, tint: Color) -> void:
	region_rect = POSES[1 if side_pose else 0]
	scale = Vector2.ONE * height / region_rect.size.y
	position = feet - Vector2(region_rect.size.x * scale.x * 0.5,height)
	modulate = tint
