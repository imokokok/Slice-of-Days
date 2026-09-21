extends "res://scripts/ui/components/solmere_button.gd"
var sample: Dictionary

func _get_drag_data(_at: Vector2) -> Variant:
	var label := Label.new()
	label.text = LocalizationSystem.text(str(sample.name))
	set_drag_preview(label)
	return {"sample": sample}
