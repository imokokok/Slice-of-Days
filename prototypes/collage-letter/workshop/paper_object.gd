extends "interactable_object.gd"

var texture: Texture2D
var paper_mask: Image
var cut_history: Array = []
var drawing_layer: Array = []
var tape_layers: Array = []
var source_id := -1
var paper_kind := "paper"
var selected := false
var ink := Color("343f39")
var image: Image

func set_image(value: Image) -> void:
	image = value.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	paper_mask = image
	texture = ImageTexture.create_from_image(image)
	is_cuttable = paper_kind != "tape"
	queue_redraw()

func local_pixel(point: Vector2) -> Vector2:
	return to_local(point) + Vector2(image.get_size()) * 0.5

func contains_point(point: Vector2) -> bool:
	if not image or not visible:
		return false
	var pixel := local_pixel(point)
	return Rect2(Vector2.ZERO, image.get_size()).has_point(pixel) and image.get_pixelv(Vector2i(pixel)).a > 0.15

func _draw() -> void:
	if texture:
		var at := -Vector2(texture.get_size()) * 0.5
		draw_texture(texture, at + Vector2(3, 5), Color(0.16, 0.12, 0.07, 0.18 if not hovered else 0.28))
		draw_texture(texture, at + Vector2(0, -2 if hovered and not selected else 0))
		if selected:
			# Quiet corner ticks; no glowing outline or editor handles.
			for corner in [at, at + Vector2(texture.get_width(), 0), -at]:
				draw_circle(corner, 2.0, Color(0.35, 0.25, 0.16, 0.55))

func stroke(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var count := maxi(1, ceili(a.distance_to(b) * 1.5))
	var radius := maxi(1, ceili(width))
	for i in range(count + 1):
		var p := a.lerp(b, float(i) / count)
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var q := Vector2i(p) + Vector2i(x, y)
				if q.x < 0 or q.y < 0 or q.x >= image.get_width() or q.y >= image.get_height(): continue
				if Vector2(x, y).length() > width or image.get_pixelv(q).a < 0.2: continue
				var old := image.get_pixelv(q)
				image.set_pixelv(q, old.lerp(color, 0.72 + 0.18 * sin(q.x * 5 + q.y * 7)))
	drawing_layer.append([a.x, a.y, b.x, b.y, width, color.to_html()])
	texture.update(image)
	queue_redraw()

func split_mask(polygon: PackedVector2Array, kind: String) -> Array:
	if not is_cuttable or polygon.size() < 3:
		return []
	var inside := image.duplicate()
	var outside := image.duplicate()
	var in_count := 0
	var out_count := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.05: continue
			var sample := Vector2(x, y)
			if kind == "scissors": sample.y += sin(x * 1.7 + y * 0.2) * 0.7
			if Geometry2D.is_point_in_polygon(sample, polygon):
				outside.set_pixel(x, y, Color.TRANSPARENT)
				in_count += 1
			else:
				inside.set_pixel(x, y, Color.TRANSPARENT)
				out_count += 1
	if in_count < 12 or out_count < 12: return []
	var points: Array=[]
	for point in polygon: points.append([point.x,point.y])
	cut_history.append({"tool": kind, "points": points})
	return [inside, outside]

func record() -> Dictionary:
	return {"id":object_id, "title":title, "kind":paper_kind, "source":source_id,
		"position":[position.x,position.y], "rotation":rotation, "scale":[scale.x,scale.y], "z":z_index,
		"png":Marshalls.raw_to_base64(image.save_png_to_buffer()), "cut_history":cut_history,
		"drawing_layer":drawing_layer, "tape_layers":tape_layers,
		"foldable":is_foldable, "cuttable":is_cuttable, "movable":is_movable}

func restore(data: Dictionary) -> bool:
	var restored := Image.new()
	if restored.load_png_from_buffer(Marshalls.base64_to_raw(data.get("png", ""))) != OK: return false
	object_id = data.get("id", "")
	title = data.get("title", "纸片")
	paper_kind = data.get("kind", "paper")
	source_id = int(data.get("source", -1))
	set_image(restored)
	position = Vector2(data.position[0], data.position[1])
	rotation = float(data.get("rotation", 0))
	scale = Vector2(data.scale[0], data.scale[1])
	z_index = int(data.get("z", 0))
	cut_history = data.get("cut_history", [])
	drawing_layer = data.get("drawing_layer", [])
	tape_layers = data.get("tape_layers", [])
	is_foldable = data.get("foldable", false)
	is_cuttable = data.get("cuttable", true)
	is_movable = data.get("movable", true)
	return true
