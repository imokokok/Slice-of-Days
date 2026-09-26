extends RefCounted
## Display-sized copies only. Original files and imported resources stay unchanged.
const MAX_CACHED_TEXTURES: int = 48
static var textures: Dictionary = {}
static var recent: Array[String] = []

static func get_texture(path: String, max_edge: int = 1024) -> Texture2D:
	var key := path + "|" + str(max_edge)
	if textures.has(key):
		recent.erase(key)
		recent.append(key)
		return textures[key]
	# Do not put the full scan into ResourceLoader's shared cache. Other callers
	# may hold an original for another purpose; this display copy never alters it.
	var original := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if original == null:
		return null
	var texture: Texture2D
	if max_edge > 0 and maxi(original.get_width(), original.get_height()) > max_edge:
		var image := original.get_image()
		original = null
		texture = from_image(image, max_edge)
	else:
		# Pixel letters pass max_edge=0, preserving their exact alpha and pixels.
		texture = original
	if texture == null:
		return null
	textures[key] = texture
	recent.append(key)
	while recent.size() > MAX_CACHED_TEXTURES:
		textures.erase(recent.pop_front())
	# Removing a cache reference cannot invalidate textures still held by cards.
	return texture

static func from_image(image: Image, max_edge: int = 1024) -> Texture2D:
	if image == null or image.is_empty():
		return null
	if image.is_compressed() and image.decompress() != OK:
		return null
	var edge := maxi(image.get_width(), image.get_height())
	if max_edge > 0 and edge > max_edge:
		var ratio := float(max_edge) / edge
		image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
