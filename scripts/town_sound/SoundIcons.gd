extends RefCounted
## Lucide ISC / Feather MIT. Original SVGs and complete licenses are bundled.
static var cache:Dictionary={}
static func get_icon(kind:String) -> Texture2D:
	if cache.has(kind): return cache[kind]
	if kind not in ["cassette-tape","audio-lines","mic","scissors","map-pin","play"]: return null
	var svg:=FileAccess.get_file_as_string("res://art/recording_icons/"+kind+".svg").replace("currentColor","#665348")
	var image:=Image.new()
	if image.load_svg_from_string(svg,2)!=OK: return null
	cache[kind]=ImageTexture.create_from_image(image)
	return cache[kind]
