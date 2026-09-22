extends "interactable_object.gd"

var texture: Texture2D
var bounds := Rect2()
var action := ""
var lift := 0.0

func _process(delta: float) -> void:
	var target := -2.0 if hovered and object_id != "mat" else 0.0
	if absf(lift - target) > 0.05:
		lift = lerpf(lift, target, minf(delta * 15.0, 1.0))
		queue_redraw()

func contains_point(point: Vector2) -> bool:
	return bounds.has_point(to_local(point))

func _draw() -> void:
	if texture:
		var raised := Rect2(bounds.position + Vector2(0, lift), bounds.size)
		if hovered:
			draw_texture_rect(texture, Rect2(raised.position + Vector2(0, 2), raised.size), false, Color("e9c55b", .25))
		draw_texture_rect(texture, raised, false)
