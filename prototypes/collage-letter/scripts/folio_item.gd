extends Button
var desk
var material_id: int=-1
var handle: String=""
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var at: Vector2=get_global_transform()*event.position
		if handle.is_empty():desk.begin_material_drag(material_id,at)
		else:desk.begin_handle_drag(handle,at)
