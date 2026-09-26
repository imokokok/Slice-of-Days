extends RefCounted
## Local, optional CC0 additions. Existing authored art remains the primary art.
const MANIFEST := "res://data/presentation/open_ui_manifest.json"
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}
static var _sounds: Dictionary = {}

static func catalog() -> Dictionary:
	if _manifest.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary: _manifest = parsed
	return _manifest

static func icon(kind: String) -> Texture2D:
	if _textures.has(kind): return _textures[kind]
	var entry: Dictionary = catalog().get("icons", {}).get(kind, {})
	if entry.is_empty(): return null
	var texture := load(str(entry.path)) as Texture2D
	_textures[kind] = texture
	return texture

static func sound(cue: String, variation := 0) -> AudioStream:
	var entry: Dictionary = catalog().get("sounds", {}).get(cue, {})
	var variants: Array = entry.get("variants", [])
	if variants.is_empty(): return null
	var path := str(variants[posmod(variation, variants.size())].path)
	if not _sounds.has(path): _sounds[path] = load(path) as AudioStream
	return _sounds[path]

static func volume(cue: String) -> float:
	return float(catalog().get("sounds", {}).get(cue, {}).get("volume_db", -24))
