extends Button
var sample: Dictionary

func _get_drag_data(_at: Vector2) -> Variant:
	var label := Label.new()
	label.text = str(sample.name)
	set_drag_preview(label)
	return {"sample": sample}
