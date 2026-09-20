extends "interactable_object.gd"

var texture: Texture2D
var bounds := Rect2()
var action := ""
var lift := 0.0

func _process(delta: float) -> void:
	var target := -5.0 if hovered else 0.0
	if absf(lift - target) > 0.05:
		lift = lerpf(lift, target, minf(delta * 15.0, 1.0))
		queue_redraw()

func contains_point(point: Vector2) -> bool:
	return bounds.has_point(to_local(point))

func _draw() -> void:
	if texture:
		var raised := Rect2(bounds.position + Vector2(0, lift), bounds.size)
		if hovered:
			draw_texture_rect(texture, Rect2(raised.position + Vector2(3, 7), raised.size), false, Color(0.1, 0.07, 0.04, 0.14))
		draw_texture_rect(texture, raised, false)
