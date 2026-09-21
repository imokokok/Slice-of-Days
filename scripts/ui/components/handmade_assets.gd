extends RefCounted
## Original imagegen cutouts, with live text and controls supplied by Godot.
const ROOT := "res://art/ui/handmade/"
const IDS := ["tomato","lemon","herbs","sea_beans","bread","cheese","soap","matches","star_salt","crooked_cup","hotel_307_tag","misprint_postcard","ticket_bundle","blue_stamp","sardine","sea_bream","shelf","crates","worktop","basket","receipt","tag","recipe_book","rod"]
static var cache: Dictionary = {}
static func texture(id: String) -> Texture2D:
	if id == "pretty_can": id = "sea_beans"
	if not IDS.has(id) and not id in ["tote","tape_workstation","photo_mat","archive_sheet","window_frame","rod_clean","float","tackle_mat"]: id = "tag"
	if not cache.has(id): cache[id] = load(ROOT + id + ".png")
	return cache[id]
static func picture(parent: Node, id: String, at: Vector2, extent: Vector2, stretch := false) -> TextureRect:
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE if stretch else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = texture(id); art.position = at; art.size = extent
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art
