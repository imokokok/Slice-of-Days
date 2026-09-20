extends Node2D

var object_id := ""
var title := ""
var hovered := false
var is_movable := true
var is_cuttable := false
var is_foldable := false

func contains_point(_point: Vector2) -> bool:
	return false

func set_hover(value: bool) -> void:
	if hovered != value:
		hovered = value
		queue_redraw()
