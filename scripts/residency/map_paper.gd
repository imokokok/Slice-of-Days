extends Control

signal selected(location: String)

const OVERVIEW = preload("res://art/ui/solmere-map-overview.jpg")
var points: Dictionary = {
	"bus_stop": Vector2(178, 268),
	"cafe": Vector2(334, 268),
	"produce_stall": Vector2(430, 268),
	"night_market": Vector2(520, 268),
	"town_entrance": Vector2(654, 268),
	"print_shop": Vector2(804, 268),
	"handcraft_shop": Vector2(244, 384),
	"library": Vector2(382, 384),
	"record_store": Vector2(507, 384),
	"chess_stall": Vector2(638, 384),
	"tarot_stall": Vector2(790, 384),
	"residence": Vector2(236, 470),
	"dorm": Vector2(510, 470),
	"port": Vector2(654, 472),
	"park": Vector2(670, 560)
}
var dragging := false

func _ready() -> void:
	size = Vector2(1050, 700)
	mouse_filter = MOUSE_FILTER_STOP
	for id in points:
		var button := Button.new()
		button.name = "Destination_" + str(id)
		button.set_meta("location", id)
		button.tooltip_text = TravelSystem.location_name(str(id))
		button.position = Vector2(points[id]) - Vector2(25, 25)
		button.size = Vector2(50, 50)
		button.flat = true
		button.modulate = Color(1, 1, 1, 0.01)
		button.pressed.connect(func() -> void: selected.emit(str(id)))
		add_child(button)
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(OVERVIEW, Rect2(Vector2.ZERO, size), false)
	for id in points:
		var marker: Vector2 = points[id]
		if ResidencySystem.state().map_notes.has(id):
			draw_circle(marker + Vector2(23, -20), 5, Color("b86e4e"))
		if str(id) == GameState.current_location:
			draw_circle(marker, 13, Color("f4f0df", 0.96))
			draw_circle(marker, 8, Color("c85f43"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var old := scale.x
			var value := clampf(old * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), 0.65, 1.45)
			position += event.position * (old - value)
			scale = Vector2.ONE * value
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		position += event.relative * scale.x
		position.x = clampf(position.x, -650, 390)
		position.y = clampf(position.y, -420, 250)
		accept_event()
