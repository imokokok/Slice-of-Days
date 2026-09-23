extends RefCounted
## Official project-use assets installed by tools/import_solmere_resources.py.
## Missing licensed media retains the authored base game, never a dead control.
const MANIFEST_PATH := "res://data/presentation/resource_manifest.json"
static var catalog: Dictionary = {}
static var textures: Dictionary = {}
static var sounds: Dictionary = {}

static func manifest() -> Dictionary:
	if catalog.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if data is Dictionary: catalog = data
	return catalog

static func path_for(key: String) -> String:
	return str(manifest().get("assets", {}).get(key, {}).get("path", ""))

static func available(key: String) -> bool:
	var path := path_for(key)
	return not path.is_empty() and (ResourceLoader.exists(path) or FileAccess.file_exists(path))

static func texture(key: String) -> Texture2D:
	if textures.has(key): return textures[key]
	if not available(key): return null
	var path := path_for(key)
	var result: Texture2D
	if ResourceLoader.exists(path): result = load(path) as Texture2D
	else:
		var image := Image.load_from_file(path)
		if image != null: result = ImageTexture.create_from_image(image)
	if result != null: textures[key] = result
	return result

static func sound(key: String) -> AudioStreamWAV:
	if sounds.has(key): return sounds[key]
	if not available(key): return null
	# Exported games use Godot's remapped resource, not the editor-only source WAV.
	var path := path_for(key)
	var result: AudioStreamWAV = load(path) as AudioStreamWAV if ResourceLoader.exists(path) else AudioStreamWAV.load_from_file(path)
	if result != null:
		if bool(manifest().assets[key].get("loop", false)):
			result.loop_mode = AudioStreamWAV.LOOP_FORWARD
			result.loop_end = int(manifest().assets[key].get("frames", 0))
		sounds[key] = result
	return result

static func paper(kind := "paper_wide", tint := Color("faf4e5"), margin := 14) -> StyleBox:
	var art := texture(kind)
	if art == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = tint; flat.set_corner_radius_all(5)
		flat.set_content_margin_all(margin)
		return flat
	var face := StyleBoxTexture.new()
	face.texture = art; face.modulate_color = tint
	# Nine-slice keeps the small paper notches at their native scale.
	face.texture_margin_left = 18; face.texture_margin_right = 18
	face.texture_margin_top = 18; face.texture_margin_bottom = 18
	face.set_content_margin_all(margin)
	return face

static func apply_theme(theme: Theme) -> void:
	if not available("paper_label"): return
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var tint: Color = {"normal":Color("f5e9d2"),"hover":Color("eee0b9"),"pressed":Color("d8dcb9"),"disabled":Color("e1ded3")}[state]
			theme.set_stylebox(state, type, paper("paper_label", tint, 10))
		theme.set_color("font_color",type,Color("48483d"))
		theme.set_color("font_hover_color",type,Color("315e79"))
		theme.set_color("font_pressed_color",type,Color("315e79"))
		theme.set_color("font_disabled_color",type,Color("7c8178"))
	for type in ["TextEdit", "LineEdit"]:
		for state in ["normal", "read_only"]:
			theme.set_stylebox(state,type,paper("paper_wide",Color("fffaf0"),12))
	for type in ["Panel", "PanelContainer", "PopupPanel", "AcceptDialog"]:
		theme.set_stylebox("panel",type,paper("paper_large",Color("faf4e5"),18))
	var check := texture("icon_check")
	var empty := texture("paper_square")
	if check and empty:
		# The icons are exposed through compact AtlasTextures to cap layout size.
		for state in ["checked", "checked_disabled"]: theme.set_icon(state,"CheckBox",_small_icon(check,24))
		for state in ["unchecked", "unchecked_disabled"]: theme.set_icon(state,"CheckBox",_small_icon(empty,24))

static func _small_icon(source: Texture2D, extent: int) -> Texture2D:
	var key := "%s_%d" % [source.get_instance_id(),extent]
	if textures.has(key): return textures[key]
	var image := source.get_image()
	image.resize(extent,extent,Image.INTERPOLATE_LANCZOS)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x,y)
			image.set_pixel(x,y,Color(.29,.33,.27,pixel.a))
	var result := ImageTexture.create_from_image(image)
	textures[key] = result
	return result

static func icon(key: String, extent := 24) -> Texture2D:
	var source := texture(key)
	return _small_icon(source,extent) if source else null

static func picture(parent: Node, key: String, at: Vector2, extent: Vector2, tint := Color.WHITE) -> TextureRect:
	var art := texture(key)
	if art == null: return null
	var node := TextureRect.new(); node.name = key.to_pascal_case()
	node.texture = art; node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = at; node.size = extent; node.modulate = tint
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
