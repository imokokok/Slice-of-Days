extends Node2D

var definition: Dictionary = {}
var polygon: = PackedVector2Array()
var art_offset: = Vector2.ZERO
var cut: = true
var heat: = 0.0:
	set(value):
		heat = value
		queue_redraw()
		if is_instance_valid(_art):
			_art.set("heat", value)
var softness: = 0.0:
	set(value):
		softness = clampf(value, 0.0, 1.0)
		if is_instance_valid(_art):
			_art.set("softness", softness)
var _art: Node2D

func _ready() -> void :
	var mask: = Polygon2D.new()
	mask.polygon = polygon
	mask.color = Color.WHITE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(mask)
	_art = preload("res://modules/restaurant/assets/food_art.gd").new()
	_art.set("definition", definition)
	_art.set("cut", false)
	_art.set("heat", heat)
	_art.set("softness", softness)
	_art.set("shadows", false)
	_art.position = art_offset
	_art.scale = Vector2.ONE * 0.61
	mask.add_child(_art)
	queue_redraw()

func _draw() -> void :

	var flesh: = preload("res://modules/restaurant/assets/cooking_appearance.gd").edge_color(definition, heat)
	var library = preload("res://modules/restaurant/assets/sprite_library.gd")
	var id := str(definition.get("id", ""))
	var authored: bool = library.handdrawn_manifest().has(id)
	for i in range(polygon.size()):
		var a: = polygon[i]
		var b: = polygon[(i + 1) % polygon.size()]
		if a.distance_to(b) > 14:
			if authored:
				# Convex collision support can span transparent gaps in a painted
				# mushroom cluster. Never outline those gaps as a visible triangle.
				var segments := ceili(a.distance_to(b) / 0.6)
				for step in segments:
					var start := a.lerp(b, float(step) / segments)
					var finish := a.lerp(b, float(step + 1) / segments)
					if library.authored_alpha_at(id, (start + finish) / 2 - art_offset) > 0.35:
						draw_line(start, finish, flesh, 1.0, true)
			else:
				draw_line(a, b, flesh, 2.5, true)
