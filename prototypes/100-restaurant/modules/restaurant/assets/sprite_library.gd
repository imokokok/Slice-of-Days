extends RefCounted
## Shared raster art adapter. Only presentation; ingredient IDs and physics stay unchanged.
static var _catalog: Array = []
static var _cache: Dictionary = {}
static var _sheets: Dictionary = {}
const WHOLE := ["shrimp","mushroom","cheese","chicken","pork","beef","fish","tofu","potato","carrot","cucumber","corn","lotus_root","bread","sausage","salmon","watermelon","durian","century_egg","blue_cheese"]
static var _bounds: Dictionary = {}
const MYSTERY := ["baseball_bat","computer_mouse","slipper","sock","perfume","doll","lipstick","rubber_duck","rock"]
static func food(id: String) -> Texture2D:
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
			if c.a<0.01: c=Color.TRANSPARENT
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
