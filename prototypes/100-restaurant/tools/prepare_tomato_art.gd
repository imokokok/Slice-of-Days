extends SceneTree
## Reproducible white-matte extraction of the user-supplied tomato.
## The source JPEG and every retained RGB pixel stay unchanged; only alpha is added.
const SOURCE := "res://docs/supplied_assets/20260925-tomato/tomato-original.jpg"
const OUTPUT := "res://modules/restaurant/assets/derived/tomato.png"
const SOURCE_SHA256 := "682335f386a407c78cd7141c0049c4e9c37c2f83cd019be4cb2eeba17cd0bea9"
const CROP := Rect2i(417, 472, 198, 176)
const CLEAR_AT := 0.02
const OPAQUE_AT := 0.18

func _initialize() -> void:
	if FileAccess.get_sha256(SOURCE) != SOURCE_SHA256:
		push_error("Supplied tomato source changed; refusing to make a derivative")
		quit(1)
		return
	var source := Image.load_from_file(SOURCE)
	if source == null or source.is_empty() or source.get_size() != Vector2i(1079, 1527):
		push_error("Could not read the original supplied tomato JPEG")
		quit(1)
		return
	var art := source.get_region(CROP)
	art.convert(Image.FORMAT_RGBA8)
	for y in art.get_height():
		for x in art.get_width():
			var color := art.get_pixel(x, y)
			var distance_from_white := 1.0 - minf(color.r, minf(color.g, color.b))
			color.a = smoothstep(CLEAR_AT, OPAQUE_AT, distance_from_white)
			if color.a < 0.01: color.a = 0.0
			art.set_pixel(x, y, color)
	var error := art.save_png(OUTPUT)
	if error != OK:
		push_error("Could not save transparent tomato: %s" % error)
		quit(1)
		return
	print("PASS: preserved supplied tomato RGB and removed only its white matte: ", OUTPUT)
	quit()
