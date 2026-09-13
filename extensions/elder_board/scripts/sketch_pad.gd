extends Control
signal changed
var strokes: Array = []
var ink := Color("29352d")
var drawing := false
var photo: Image
var photo_texture: ImageTexture
var show_grid := true

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	clip_contents = true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("eeece3"))
	if photo_texture: draw_texture_rect(photo_texture, Rect2(Vector2.ZERO, size), false)
	if show_grid:
		for x in range(1, 12): draw_line(Vector2(size.x * x / 12.0, 0), Vector2(size.x * x / 12.0, size.y), Color(0.3, 0.4, 0.3, 0.15))
		for y in range(1, 6): draw_line(Vector2(0, size.y * y / 6.0), Vector2(size.x, size.y * y / 6.0), Color(0.3, 0.4, 0.3, 0.15))
	for stroke in strokes:
		var points := PackedVector2Array()
		for p in stroke.points: points.append(Vector2(p[0], p[1]))
		if points.size() == 1: draw_circle(points[0], 3, Color(stroke.color))
		elif points.size() > 1: draw_polyline(points, Color(stroke.color), 5, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drawing = event.pressed
		if drawing:
			strokes.append({"color": ink.to_html(), "points": [[event.position.x, event.position.y]]})
			changed.emit()
		queue_redraw()
	elif event is InputEventMouseMotion and drawing:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			drawing = false
			return
		var p: Vector2 = event.position.clamp(Vector2.ZERO, size - Vector2.ONE)
		strokes[-1].points.append([p.x, p.y])
		changed.emit()
		queue_redraw()

func undo() -> void:
	if not strokes.is_empty(): strokes.pop_back()
	changed.emit()
	queue_redraw()

func clear() -> void:
	strokes.clear()
	photo = null
	photo_texture = null
	drawing = false
	changed.emit()
	queue_redraw()

func load_picture(path: String) -> Error:
	var loaded := Image.load_from_file(path)
	if loaded == null or loaded.is_empty(): return ERR_FILE_UNRECOGNIZED
	# Fit the complete image inside the paper without changing its aspect ratio.
	var ratio := minf(size.x / loaded.get_width(), size.y / loaded.get_height())
	loaded.resize(maxi(1, int(loaded.get_width() * ratio)), maxi(1, int(loaded.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	photo = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	photo.fill(Color("eeece3"))
	loaded.convert(Image.FORMAT_RGBA8)
	photo.blit_rect(loaded, Rect2i(Vector2i.ZERO, loaded.get_size()), (Vector2i(size) - loaded.get_size()) / 2)
	photo_texture = ImageTexture.create_from_image(photo)
	strokes.clear()
	changed.emit()
	queue_redraw()
	return OK

func has_art() -> bool:
	return photo != null or not strokes.is_empty()

func picture() -> Image:
	var result := photo.duplicate() as Image if photo else Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	if not photo: result.fill(Color("eeece3"))
	if show_grid:
		for x in range(1, 12): result.fill_rect(Rect2i(int(size.x * x / 12.0), 0, 1, int(size.y)), Color("cdd0c5"))
		for y in range(1, 6): result.fill_rect(Rect2i(0, int(size.y * y / 6.0), int(size.x), 1), Color("cdd0c5"))
	for stroke in strokes:
		var previous := Vector2(stroke.points[0][0], stroke.points[0][1])
		for p in stroke.points:
			var target := Vector2(p[0], p[1])
			var steps := maxi(1, ceili(previous.distance_to(target)))
			for step in range(steps + 1):
				var center := previous.lerp(target, float(step) / steps)
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						var pixel := Vector2i(center) + Vector2i(dx, dy)
						if pixel.x >= 0 and pixel.y >= 0 and pixel.x < result.get_width() and pixel.y < result.get_height(): result.set_pixelv(pixel, Color(stroke.color))
			previous = target
	return result
