extends RefCounted
## Lucide ISC / Feather MIT. Original SVGs and complete licenses are bundled.
static var cache:Dictionary={}
static func get_icon(kind:String) -> Texture2D:
	if cache.has(kind): return cache[kind]
	if kind not in ["cassette-tape","audio-lines","mic","scissors","map-pin","play"]: return null
	cache[kind]=load("res://art/recording_icons/"+kind+".svg") as Texture2D
	return cache[kind]
