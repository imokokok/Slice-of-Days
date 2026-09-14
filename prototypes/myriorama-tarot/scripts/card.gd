extends TextureRect

signal picked(card_id: String)
signal swapped(from_id: String, to_id: String)
var card_id := ""
var orientation := "upright" # Reserved: "reversed". Current build uses upright only.
var sortable := false
var surface: ShaderMaterial
var contact: Panel
var hover_tween: Tween
var glow: Panel
var selected := false

func _ready() -> void:
	surface = ShaderMaterial.new()
	surface.shader = preload("res://shaders/card_surface.gdshader")
	surface.set_shader_parameter("hover", 0.0)
	material = surface
	contact = Panel.new()
	contact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contact.show_behind_parent = true
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color("b6a88a")
	edge.border_color = Color("6f6858")
	edge.border_width_bottom = 1
	edge.set_corner_radius_all(1 if sortable else 5)
	edge.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	edge.shadow_size = 2 if sortable else 5
	edge.shadow_offset = Vector2(1, 2) if sortable else Vector2(2, 4)
	contact.add_theme_stylebox_override("panel", edge)
	add_child(contact)
	glow = Panel.new()
	glow.show_behind_parent = true
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aura := StyleBoxFlat.new()
	aura.bg_color = Color(0, 0, 0, 0)
	aura.border_color = Color("ffe7a3")
	aura.set_border_width_all(2)
	aura.set_corner_radius_all(6)
	aura.shadow_color = Color(1.0, 0.76, 0.30, 0.58)
	aura.shadow_size = 9
	glow.add_theme_stylebox_override("panel", aura)
	glow.modulate.a = 0.0
	add_child(glow)
	resized.connect(update_surface)
	update_surface()
	if card_id.begins_with("draw:"):
		modulate = Color(0.68, 0.71, 0.70, 1.0)
	mouse_entered.connect(func(): set_hover(1.0))
	mouse_exited.connect(func(): set_hover(0.0))

func update_surface() -> void:
	if surface == null:
		return
	surface.set_shader_parameter("card_size", size)
	surface.set_shader_parameter("joined", 1.0 if sortable else 0.0)
	contact.position = Vector2(0.3, 0.8) if sortable else Vector2(0.4, 1.6)
	contact.size = size
	glow.position = Vector2(-2, -2)
	glow.size = size + Vector2(4, 4)

func set_hover(value: float) -> void:
	if card_id.begins_with("draw:"):
		z_index = 20 if value > 0 else 0
	if is_instance_valid(hover_tween):
		hover_tween.kill()
	hover_tween = create_tween()
	var current: float = float(surface.get_shader_parameter("hover"))
	hover_tween.tween_method(func(amount: float): surface.set_shader_parameter("hover", amount), current, value, 0.18)
	hover_tween.parallel().tween_property(glow, "modulate:a", 1.0 if value > 0 or selected else 0.0, 0.12)
	if card_id.begins_with("draw:"):
		hover_tween.parallel().tween_property(self, "modulate", Color.WHITE if value > 0 else Color(0.68, 0.71, 0.70, 1.0), 0.12)

func set_selected(value: bool) -> void:
	selected = value
	if is_instance_valid(glow):
		glow.modulate.a = 1.0 if selected else 0.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		picked.emit(card_id)
		accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not sortable:
		return null
	var preview := TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = size * 0.8
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {"tarot_card": card_id}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return sortable and data is Dictionary and data.has("tarot_card") and data.tarot_card != card_id

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	swapped.emit(str(data.tarot_card), card_id)
