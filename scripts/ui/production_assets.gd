extends RefCounted
## Official project-use assets installed by tools/import_solmere_resources.py.
## Missing licensed media retains the authored base game, never a dead control.
const MANIFEST_PATH := "res://data/presentation/resource_manifest.json"
static var catalog: Dictionary = {}
static var textures: Dictionary = {}
static var sounds: Dictionary = {}
const INK := Color("38423e")
const MUTED_INK := Color("56655e")

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
	# Protect the source's actual uneven edge instead of stretching a notch
	# through the writing area. Margins follow the supplied PNG geometry.
	var edges: Vector4={"paper_label":Vector4(16,24,12,8),"paper_tab":Vector4(18,32,18,10),"paper_large":Vector4(56,12,44,12),"paper_wide":Vector4(8,28,8,24)}.get(kind,Vector4(24,24,24,24))
	face.texture_margin_left=edges.x; face.texture_margin_top=edges.y
	face.texture_margin_right=edges.z; face.texture_margin_bottom=edges.w
	face.set_content_margin_all(margin)
	if kind=="paper_large":
		face.content_margin_left=maxf(margin,64)
		face.content_margin_right=maxf(margin,52)
	if kind in ["paper_label","paper_tab"]:
		face.content_margin_top=minf(margin,6); face.content_margin_bottom=minf(margin,6)
	return face

static func surface(tint := Color("faf5e8"), margin := 18) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color=tint; face.set_content_margin_all(margin)
	face.set_corner_radius_all(3); face.set_border_width_all(1)
	face.border_color=Color("8a816b",.5)
	face.shadow_color=Color("252d29",.16); face.shadow_size=4; face.shadow_offset=Vector2(0,3)
	return face

static func button_face(variant: String, state: String, selected := false) -> StyleBoxFlat:
	var primary := variant in ["primary","choice","pause","camera","guidance"]
	var active := state in ["hover","pressed"] or selected
	var face := StyleBoxFlat.new()
	face.set_content_margin_all(10); face.content_margin_top=6; face.content_margin_bottom=6
	face.set_corner_radius_all(3)
	face.bg_color=Color("faf5e8")
	if variant in ["tab","archive","goods"]: face.bg_color=Color("f3eddd")
	if primary: face.bg_color=Color("415c57")
	if active: face.bg_color=Color("e7dbb6") if not primary else Color("eddda9")
	face.border_color=Color("797463",.35)
	if variant in ["paper","outlined"] or primary: face.set_border_width_all(1)
	elif variant=="tab" or active: face.border_width_bottom=2 if active else 1
	if selected: face.border_color=Color("526d61"); face.border_width_bottom=3
	if state=="disabled": face.bg_color=Color("e8e4d9"); face.border_color=Color("c6c0b0")
	if state=="focus":
		face.bg_color=Color.TRANSPARENT; face.set_border_width_all(2); face.border_color=Color("aa7a38")
	return face

static func apply_theme(theme: Theme) -> void:
	if not available("paper_label"): return
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var tint: Color = {"normal":Color("f5e9d2"),"hover":Color("eee0b9"),"pressed":Color("d8dcb9"),"disabled":Color("e1ded3")}[state]
			theme.set_stylebox(state, type, button_face("paper",state))
		for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]: theme.set_color(state,type,INK)
		theme.set_color("font_disabled_color",type,MUTED_INK)
	for type in ["TextEdit", "LineEdit"]:
		for state in ["normal", "read_only"]:
			theme.set_stylebox(state,type,surface(Color("fffaf0"),12))
		for state in ["font_color","font_selected_color","font_readonly_color","caret_color"]: theme.set_color(state,type,INK)
		theme.set_color("font_placeholder_color",type,MUTED_INK)
		theme.set_color("selection_color",type,Color("ded5ac"))
	for type in ["Panel", "PanelContainer", "PopupPanel", "AcceptDialog"]:
		theme.set_stylebox("panel",type,surface(Color("faf5e8"),18))
	# A filled paper silhouette becomes a solid block when tinted as an icon.
	for state in ["checked", "checked_disabled"]: theme.set_icon(state,"CheckBox",preload("res://art/ui/check-on.svg"))
	for state in ["unchecked", "unchecked_disabled"]: theme.set_icon(state,"CheckBox",preload("res://art/ui/check-off.svg"))
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]: theme.set_color(state,"CheckBox",INK)

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
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; node.texture = art
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = at; node.size = extent; node.modulate = tint
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
