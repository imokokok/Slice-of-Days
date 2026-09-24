extends RefCounted
## Inventory shows packaging; the preparation board and pan show edible food.
const FOOD = preload("res://art/ui/pocket_doodles/edible_food.png")
const ART = preload("res://scripts/ui/components/handmade_assets.gd")
const SUPPLIED = preload("res://scripts/ui/components/kitchen_art_catalog.gd")
static var cache: Dictionary={}
static func can_cut(id: String) -> bool:
	if SUPPLIED.is_supplied_ingredient(id): return SUPPLIED.can_cut(id)
	return id not in ["sea_beans","star_salt"]
static func texture(id: String, prepared := false) -> Texture2D:
	if SUPPLIED.is_supplied_ingredient(id): return SUPPLIED.texture(id,prepared)
	if id=="cheese" or (id=="bread" and not prepared):
		return ART.texture(id)
	var index := int({"sea_beans":0,"lemon":1,"star_salt":2}.get(id,-1))
	if prepared: index=int({"tomato":3,"herbs":4,"bread":5}.get(id,index))
	if index<0: return ART.texture(id)
	if not cache.has(index):
		var region := AtlasTexture.new(); region.atlas=FOOD
		region.region=Rect2((index%3)*512,floori(index/3.0)*512,512,512); cache[index]=region
	return cache[index]

static func picture(parent: Node, id: String, at: Vector2, extent: Vector2, stretch := false) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_SCALE if stretch else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture=texture(id); picture.position=at; picture.size=extent
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture
