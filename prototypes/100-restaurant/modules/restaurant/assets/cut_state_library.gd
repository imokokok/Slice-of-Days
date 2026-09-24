extends RefCounted
## Generated derivative appearance only. Geometry and mass always come from the knife.
const ROWS := {"tomato": [0,0], "onion": [0,1], "carrot": [0,2], "potato": [0,3], "mushroom": [1,0], "eggplant": [1,1], "bell_pepper": [1,2], "cucumber": [1,3]}
const SHEETS := ["res://modules/restaurant/assets/cut_states/roots.png", "res://modules/restaurant/assets/cut_states/vegetables.png"]
## Explicit alpha bounds: generated cells have uneven gutters and some cross grid lines.
const BOUNDS := [
	[[44,55,216,206],[330,82,166,158],[584,94,137,131],[821,71,166,173],[1094,106,120,119],[1311,86,162,157]],
	[[45,297,213,201],[331,322,168,157],[589,345,125,117],[825,314,157,170],[1098,339,114,124],[1332,324,151,153]],
	[[50,540,196,192],[334,566,150,139],[600,590,103,95],[819,552,161,164],[1097,574,117,122],[1317,562,165,159]],
	[[42,769,212,198],[334,799,158,144],[594,816,119,111],[824,796,153,154],[1099,816,110,115],[1321,794,165,154]],
	[[68,82,177,182],[324,105,166,156],[577,112,102,159],[825,122,148,132],[1096,139,135,116],[1364,164,101,101]],
	[[48,302,204,201],[326,331,168,158],[598,365,126,118],[846,337,132,144],[1113,359,128,126],[1375,384,98,101]],
	[[50,530,215,205],[327,562,186,171],[589,580,149,149],[856,583,134,152],[1132,598,113,136],[1346,612,107,113]],
	[[58,762,217,209],[337,784,186,174],[616,821,119,120],[860,819,134,139],[1130,826,127,132],[1369,845,123,113]]]
static var _cache: Dictionary = {}

static func texture(id: String, style: String, variant: int = 0) -> Texture2D:
	if not ROWS.has(id): return null
	var key := "%s_%s_%d" % [id, style, posmod(variant, 3)]
	if _cache.has(key): return _cache[key]
	var sheet: Texture2D = load(SHEETS[ROWS[id][0]])
	if sheet == null: return null
	var column := posmod(variant, 3) + (3 if style == "dice" else 0)
	var box: Array = BOUNDS[ROWS[id][0] * 4 + ROWS[id][1]][column]
	var region := Rect2i(box[0]-2,box[1]-2,box[2]+4,box[3]+4)
	# Trim transparent gutters in memory; never modify the generated PNG or team art.
	var pixels := sheet.get_image().get_region(region)
	# Polygon2D uses pixel UVs on its texture RID; an AtlasTexture here samples
	# unrelated cells from the full sheet. Give every face its own runtime region.
	var result := ImageTexture.create_from_image(pixels)
	_cache[key] = result
	return result

static func style_for(previous_axis: Vector2, next_axis: Vector2, previous_style: String) -> String:
	if previous_style == "dice": return "dice"
	return "dice" if previous_axis.length() > 0.1 and absf(previous_axis.normalized().dot(next_axis.normalized())) < 0.75 else "slice"
