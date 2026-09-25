extends RefCounted
## Shared raster art adapter. Only presentation; ingredient IDs and physics stay unchanged.
static var _catalog: Array = []
static var _cache: Dictionary = {}
static var _sheets: Dictionary = {}
const WHOLE := ["shrimp","mushroom","cheese","chicken","pork","beef","fish","tofu","potato","carrot","cucumber","corn","lotus_root","bread","sausage","salmon","watermelon","durian","century_egg","blue_cheese"]
static var _bounds: Dictionary = {}
static var _handdrawn: Dictionary = {}
static var _team_jpeg: Dictionary = {}
static var _supplementary: Dictionary = {}
static var _outlines: Dictionary = {}
static var _authored_pixels: Dictionary = {}
static var _hit_pixels: Dictionary = {}
const MYSTERY := ["baseball_bat","computer_mouse","slipper","sock","perfume","doll","lipstick","rubber_duck","rock"]
# Physical silhouettes share a common 30 cm skillet reference. The body
# polygon, held artwork and countertop artwork all use this one scale.
static var _physical_scales: Dictionary = {}
static var _physical_definitions: Dictionary = {}
const CONTAINER_SCALES := {"oil":1.55, "pepper":1.13, "salt":0.48, "sugar":0.45, "soy_sauce":0.58, "ketchup":0.68, "mayonnaise":0.68, "mustard":0.68, "chili_sauce":0.68, "vinegar":0.68}
const LONGEST_SIDE_PX := {
	"carrot":84.0, "cucumber":99.0, "zucchini":99.0, "corn":92.0,
	"eggplant":88.0, "banana":88.0, "noodles":78.0,
	"cabbage":94.0, "lettuce":86.0, "pumpkin":108.0,
	"watermelon":116.0, "durian":115.0,
	"baseball_bat":143.0, "computer_mouse":62.0, "slipper":102.0,
	"sock":81.0, "paper":79.0, "resignation_letter":79.0,
	"toilet_paper":78.0, "toothpaste":69.0, "doll":85.0,
	"rock":79.0, "alarm_clock":71.0, "tennis_ball":45.0,
	"button":23.0, "eraser":33.0, "lipstick":43.0,
	"confetti":28.0, "sponge":44.0
}
static func physical_art_scale(id: String) -> float:
	# The artist's ten rack bottles are calibrated against their actual slots.
	if CONTAINER_SCALES.has(id): return float(CONTAINER_SCALES[id])
	if _physical_scales.has(id): return float(_physical_scales[id])
	if _physical_definitions.is_empty():
		for row in JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json")):
			_physical_definitions[str(row.id)] = row
	var definition: Dictionary = _physical_definitions.get(id, {})
	var mass_kg := maxf(0.015, float(definition.get("mass", 0.18)))
	# Cubic-root mass scales the longest visible side like a solid volume.
	# Long produce and irregular objects use measured silhouette overrides.
	var target_px := float(LONGEST_SIDE_PX.get(id, clampf(64.0 * pow(mass_kg / 0.18, 1.0 / 3.0), 35.0, 112.0)))
	var texture := food(id)
	var fit_size := fit(texture, Vector2.ZERO, Vector2(78, 78)).size if texture != null else Vector2(78, 78)
	var value := target_px / maxf(1.0, maxf(fit_size.x, fit_size.y))
	_physical_scales[id] = value
	return value
static func handdrawn_manifest() -> Dictionary:
	if _handdrawn.is_empty():
		_handdrawn = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/assets/handdrawn_manifest.json"))
	return _handdrawn

static func handdrawn_food(id: String) -> Texture2D:
	var entry: Dictionary = handdrawn_manifest().get(id, {})
	if entry.is_empty(): return null
	var key := "handdrawn:" + id
	if _cache.has(key): return _cache[key]
	var source: Texture2D = load(entry.path)
	if source == null: return null
	var pixels := source.get_image()
	if pixels.is_compressed(): pixels.decompress()
	var b: Array = entry.bounds
	# The original file is untouched. Select transparent canvas bounds only;
	# retain ALL authored colour and alpha, including antialiased brush edges.
	var region := pixels.get_region(Rect2i(b[0], b[1], b[2], b[3]))
	_authored_pixels[id] = region
	var result := ImageTexture.create_from_image(region)
	_cache[key] = result
	return result

static func team_jpeg_manifest() -> Dictionary:
	if _team_jpeg.is_empty():
		_team_jpeg = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/assets/team_jpeg_manifest.json"))
	return _team_jpeg

static func team_jpeg_food(id: String) -> Texture2D:
	var entry: Dictionary = team_jpeg_manifest().get(id, {})
	if entry.is_empty(): return null
	var key := "team_jpeg:" + id
	if _cache.has(key): return _cache[key]
	var source: Texture2D = load(entry.path) if ResourceLoader.exists(entry.path) else null
	var pixels := source.get_image() if source != null else Image.load_from_file(entry.path)
	if pixels == null or pixels.is_empty(): return null
	if pixels.is_compressed(): pixels.decompress()
	pixels.convert(Image.FORMAT_RGBA8)
	# The supplied originals are opaque JPEGs on black. Leave source files byte-identical;
	# derive downsampled alpha in memory for every presentation and collision path.
	var scale := minf(1.0, 768.0 / maxf(pixels.get_width(), pixels.get_height()))
	pixels.resize(maxi(1, roundi(pixels.get_width() * scale)), maxi(1, roundi(pixels.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	var width := pixels.get_width()
	var height := pixels.get_height()
	var rows := PackedInt32Array()
	var columns := PackedInt32Array()
	rows.resize(height)
	columns.resize(width)
	for y in height:
		for x in width:
			var c := pixels.get_pixel(x, y)
			if maxf(c.r, maxf(c.g, c.b)) > 0.16:
				rows[y] += 1
				columns[x] += 1
	var left := width
	var right := -1
	var top := height
	var bottom := -1
	for x in width:
		if columns[x] >= 3:
			left = mini(left, x)
			right = x
	for y in height:
		if rows[y] >= 3:
			top = mini(top, y)
			bottom = y
	if right < left or bottom < top: return null
	var box := Rect2i(maxi(0, left - 5), maxi(0, top - 5), mini(width - maxi(0, left - 5), right - left + 11), mini(height - maxi(0, top - 5), bottom - top + 11))
	var region := pixels.get_region(box)
	for y in region.get_height():
		for x in region.get_width():
			var c := region.get_pixel(x, y)
			var brightness := maxf(c.r, maxf(c.g, c.b))
			c.a = smoothstep(0.025, 0.125, brightness)
			if c.a < 0.015: c.a = 0.0
			region.set_pixel(x, y, c)
	var result := ImageTexture.create_from_image(region)
	_cache[key] = result
	return result

static func supplementary_food(id: String) -> Texture2D:
	if _supplementary.is_empty():
		_supplementary = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/assets/supplementary_manifest.json"))
	var entry: Dictionary = _supplementary.get(id, {})
	if entry.is_empty(): return null
	var key := "supplementary:" + id
	if _cache.has(key): return _cache[key]
	var source: Texture2D = load(entry.path) if ResourceLoader.exists(entry.path) else null
	var sheet := source.get_image() if source != null else Image.load_from_file(entry.path)
	if sheet == null or sheet.is_empty(): return null
	if sheet.is_compressed(): sheet.decompress()
	var bounds: Array = entry.region
	var pixels := sheet.get_region(Rect2i(bounds[0], bounds[1], bounds[2], bounds[3]))
	var result := ImageTexture.create_from_image(pixels)
	_cache[key] = result
	return result

static func body_outline(id: String) -> PackedVector2Array:
	if _outlines.has(id): return _outlines[id]
	var texture := food(id)
	if texture == null: return PackedVector2Array()
	var mask := BitMap.new()
	var pixels := texture.get_image()
	if pixels.is_compressed(): pixels.decompress()
	mask.create_from_image_alpha(pixels, 0.1)
	var points := PackedVector2Array()
	var rect := fit(texture, Vector2.ZERO, Vector2(78, 78))
	for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, mask.get_size()), 1.0):
		for point in polygon:
			points.append((rect.position + point / texture.get_size() * rect.size) * physical_art_scale(id))
	# Stable convex support approximation, sharing the rendered art's coordinates.
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]): hull.remove_at(hull.size() - 1)
	_outlines[id] = hull
	return hull

static func authored_alpha_at(id: String, body_point: Vector2) -> float:
	var texture := handdrawn_food(id)
	if texture == null: return 0.0
	var rect := fit(texture, Vector2.ZERO, Vector2(78, 78))
	var uv := (body_point / physical_art_scale(id) - rect.position) / rect.size
	if uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1: return 0.0
	var pixels: Image = _authored_pixels[id]
	return pixels.get_pixelv(Vector2i(uv * texture.get_size())).a

static func alpha_at(id: String, art_point: Vector2) -> float:
	if not art_point.is_finite(): return 0.0
	var texture := food(id)
	if texture == null: return 0.0
	var rect := fit(texture, Vector2.ZERO, Vector2(78, 78))
	var uv := (art_point - rect.position) / rect.size
	if uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1: return 0.0
	if not _hit_pixels.has(id):
		var pixels := texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		_hit_pixels[id] = pixels
	return (_hit_pixels[id] as Image).get_pixelv(Vector2i(uv * texture.get_size())).a

static func food(id: String) -> Texture2D:
	var authored := handdrawn_food(id)
	if authored != null: return authored
	var team_source := team_jpeg_food(id)
	if team_source != null: return team_source
	var new_art := supplementary_food(id)
	if new_art != null: return new_art
	if id in MYSTERY and id!="sock": return mapped_sprite("odd_objects",str(MYSTERY.find(id)))
	if _catalog.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json"))
		for row in data: _catalog.append(str(row.id))
	var index := _catalog.find(id)
	if index < 0: return null
	var sheet := index/20+1
	var item := index%20
	if WHOLE.has(id):
		sheet = 5
		item = WHOLE.find(id)
	var key := "%d:%d" % [sheet,item]
	if _cache.has(key): return _cache[key]
	if _bounds.is_empty(): _bounds = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/assets/food_bounds.json"))
	if not _bounds.has(key): return null
	var values: Array = _bounds[key]
	var path := "res://modules/restaurant/assets/food_atlas_%d.png" % sheet
	if not ResourceLoader.exists(path): return null
	var texture := prepared_region(path,Rect2i(values[0],values[1],values[2],values[3]))
	_cache[key] = texture
	return texture

static func prepared_region(path: String,rect: Rect2i) -> Texture2D:
	# All consumers receive the same alpha-bearing texture, including photographs,
	# clipped physical slices and authoring stickers. Never rely on a scene shader.
	var key := path+str(rect)
	if _cache.has(key): return _cache[key]
	var texture: Texture2D = load(path)
	var pixels := texture.get_image()
	if pixels.is_compressed(): pixels.decompress()
	pixels = pixels.get_region(rect)
	pixels.convert(Image.FORMAT_RGBA8)
	var magenta := false
	var cyan := false
	var native_alpha := pixels.detect_alpha()!=Image.ALPHA_NONE
	for corner in [Vector2i.ZERO,Vector2i(pixels.get_width()-1,0),Vector2i(0,pixels.get_height()-1)]:
		var c := pixels.get_pixelv(corner)
		if c.r>0.8 and c.b>0.8 and c.g<0.25: magenta = true
		if c.g>0.8 and c.b>0.8 and c.r<0.25: cyan = true
	for y in pixels.get_height():
		for x in pixels.get_width():
			var c := pixels.get_pixel(x,y)
			if native_alpha:
				pass
			elif cyan:
				var amount := clampf(minf(c.g,c.b)-c.r,0,1)
				if amount>0.04:
					c.a*=1-amount
					if c.a>0.01:
						c.g=clampf((c.g-amount)/c.a,0,1)
						c.b=clampf((c.b-amount)/c.a,0,1)
						c.r=clampf(c.r/c.a,0,1)
			elif magenta:
				var key_amount := minf(c.r,c.b)-c.g
				if key_amount > 0.04:
					c.a *= 1.0-clampf(key_amount,0,1)
					if c.a>0.01:
						c.r = clampf((c.r-(1-c.a))/c.a,0,1)
						c.b = clampf((c.b-(1-c.a))/c.a,0,1)
						c.g = clampf(c.g/c.a,0,1)
			else:
				# Compatibility for retired checker-matte atlases during an import.
				if maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b))<0.055 and c.get_luminance()>0.48: c.a=0
			# Quantized near-transparent atlas matte must not tint a rectangular
			# area behind the ingredient on bright countertops or photographs.
			if c.a<0.05: c=Color.TRANSPARENT
			pixels.set_pixel(x,y,c)
	var result := ImageTexture.create_from_image(pixels)
	_cache[key] = result
	return result

static func gear(index: int) -> Texture2D:
	return mapped_sprite("kitchen_props",str(index))

static func guest(id: String) -> Texture2D:
	var ids := ["lin","jiao","chen","qi","mei","xu","tao","mo","zhou"]
	return mapped_sprite("customers",str(maxi(0,ids.find(id))))

static func mapped_sprite(atlas: String, id: String) -> Texture2D:
	var path := "res://modules/restaurant/assets/"+atlas
	if not ResourceLoader.exists(path+".png") or not FileAccess.file_exists(path+".json"): return null
	var bounds = JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
	if not bounds is Dictionary or not bounds.has(id): return null
	var r: Array = bounds[id]
	return prepared_region(path+".png",Rect2i(r[0],r[1],r[2],r[3]))

static func tile(path: String,index: int,grid: Vector2i) -> Texture2D:
	var key := path+":"+str(index)
	if _cache.has(key): return _cache[key]
	if not ResourceLoader.exists(path): return null
	if not _sheets.has(path):
		var texture: Texture2D = load(path)
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		_sheets[path] = {"texture":texture,"image":image}
	var sheet: Dictionary = _sheets[path]
	var dimensions: Vector2i = sheet.image.get_size()
	var cell := Vector2i(dimensions.x/grid.x,dimensions.y/grid.y)
	var region := Rect2i(Vector2i(index%grid.x,index/grid.x)*cell,cell)
	var pixels: Image = sheet.image.get_region(region)
	var bounds := pixels.get_used_rect()
	if not bounds.has_area(): return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet.texture
	atlas.region = Rect2(region.position+bounds.position,bounds.size)
	atlas.filter_clip = true
	_cache[key] = atlas
	return atlas

static func fit(texture: Texture2D,center: Vector2,maximum: Vector2) -> Rect2:
	var dimensions := texture.get_size()
	var factor := minf(maximum.x/dimensions.x,maximum.y/dimensions.y)
	return Rect2(center-dimensions*factor/2,dimensions*factor)
