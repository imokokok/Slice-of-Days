extends RefCounted
## Inventory shows packaging; the preparation board and pan show edible food.
const FOOD = preload("res://art/ui/pocket_doodles/edible_food.png")
const ART = preload("res://scripts/ui/components/handmade_assets.gd")
const SUPPLIED = preload("res://scripts/ui/components/kitchen_art_catalog.gd")
const PREPARED_COMMON = preload("res://art/ui/kitchen_open_redraw/prepared_common_atlas.png")
const PREPARED_PEPPERS = preload("res://art/ui/kitchen_open_redraw/prepared_peppers_atlas.png")
const PREPARED_COMMON_INDEX := {
	"mushrooms":0,"potato":1,"carrot":2,"beet":3,
	"eggplant":4,"zucchini":5,"lemon":6,"bread":7,
	"cheese":8,"tomato":9,"herbs":10,"sardine":11,"sea_bream":11,
}
const PREPARED_PEPPER_INDEX := {
	"bell_pepper_yellow":0,"bell_pepper_purple":1,"bell_pepper_orange":2,"bell_pepper_dark":3,
	"bell_pepper_bronze":4,"bell_pepper_white":5,"bell_pepper_red":6,"bell_pepper_green":7,
}
static var cache: Dictionary={}

static func _atlas_cell(atlas: Texture2D, columns: int, rows: int, index: int, key: String) -> Texture2D:
	if cache.has(key): return cache[key]
	var cell := Vector2(atlas.get_width()/float(columns),atlas.get_height()/float(rows))
	var region := AtlasTexture.new()
	region.atlas=atlas
	region.region=Rect2(Vector2((index%columns)*cell.x,floori(index/float(columns))*cell.y),cell)
	cache[key]=region
	return region

static func prepared_texture(id: String) -> Texture2D:
	if PREPARED_COMMON_INDEX.has(id):
		return _atlas_cell(PREPARED_COMMON,4,3,int(PREPARED_COMMON_INDEX[id]),"prepared_common_"+id)
	if PREPARED_PEPPER_INDEX.has(id):
		return _atlas_cell(PREPARED_PEPPERS,4,2,int(PREPARED_PEPPER_INDEX[id]),"prepared_pepper_"+id)
	return null

static func can_cut(id: String) -> bool:
	if SUPPLIED.is_supplied_ingredient(id): return SUPPLIED.can_cut(id)
	return id not in ["sea_beans","star_salt"]
static func texture(id: String, prepared := false) -> Texture2D:
	if prepared:
		var redrawn := prepared_texture(id)
		if redrawn: return redrawn
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


static func has_distinct_prep_drawing(id: String, option: String) -> bool:
	return (id=="lemon" and option=="squeeze") or (id=="bread" and option=="small") or (id=="cheese" and option=="chunks")


static func draw_prepared(canvas: CanvasItem, id: String, option: String, rect: Rect2, tint := Color.WHITE) -> void:
	var art := texture(id,true)
	if art==texture(id,false) and can_cut(id):
		var pieces := 4 if option in ["small","dice","crumbs","chop","ribbons","strips"] else 3
		var gap := minf(5.0,rect.size.x*0.06)
		var piece_width := (rect.size.x-gap*float(pieces-1))/float(pieces)
		for i in pieces:
			var source := Rect2(float(i)*art.get_width()/float(pieces),0.0,art.get_width()/float(pieces),art.get_height())
			var dest := Rect2(rect.position+Vector2(float(i)*(piece_width+gap),float(i%2)*4.0),Vector2(piece_width,rect.size.y-4.0))
			canvas.draw_texture_rect_region(art,dest,source,tint)
		return
	if not has_distinct_prep_drawing(id,option):
		canvas.draw_texture_rect(art,rect,false,tint)
		return
	if id=="lemon":
		canvas.draw_texture_rect(art,Rect2(rect.position+Vector2(rect.size.x*0.02,rect.size.y*0.18),rect.size*Vector2(0.58,0.65)),false,tint)
		for i in 3:
			var center := rect.position+rect.size*Vector2(0.62+0.12*float(i%2),0.36+0.22*float(i/2))
			canvas.draw_circle(center,maxf(2.0,rect.size.x*0.055),Color("f0c94e")*tint)
		return
	for i in 3:
		var offset := Vector2(0.03+0.34*float(i%2),0.03+0.37*float(i/2))
		canvas.draw_texture_rect(art,Rect2(rect.position+rect.size*offset,rect.size*Vector2(0.57,0.57)),false,tint)

static func picture(parent: Node, id: String, at: Vector2, extent: Vector2, stretch := false) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_SCALE if stretch else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture=texture(id); picture.position=at; picture.size=extent
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture
