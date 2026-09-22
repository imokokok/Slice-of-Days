extends Node
## The stage draws these real objects onto the authored tabletop, behind actors.
## Interactions remain proximity-based; this node is only the retained artwork.
var pictures: Array[Texture2D]=[]
func _ready() -> void:
	GameState.state_changed.connect(rebuild)
	rebuild()
func rebuild() -> void:
	pictures.clear()
	var items := ChapterSystem.everyday_at(GameState.current_location)
	for i in mini(items.size(),4):
		pictures.append(texture_for(items[i]))

func draw_on(stage: CanvasItem) -> void:
	var origin := Vector2(546,507) if SceneRouter.active_space_id=="home_a" else Vector2(542,497)
	for i in pictures.size():
		if pictures[i]==null: continue
		stage.draw_set_transform(origin+Vector2(i*35,i%2*5),-.045 if i%2==0 else .035)
		stage.draw_texture_rect(pictures[i],Rect2(0,0,66,28),false,Color("eee2c8"))
	stage.draw_set_transform(Vector2.ZERO)

static func texture_for(item: Dictionary) -> Texture2D:
	var path := str(item.payload.get("record",{}).get("cover_path",item.payload.get("letter",{}).get("preview_path","")))
	if FileAccess.file_exists(path):
		var picture := Image.load_from_file(path)
		if picture!=null: return ImageTexture.create_from_image(picture)
	return preload("res://art/ui/handmade/receipt.png") if str(item.view_kind)=="receipt" else preload("res://art/ui/handmade/recipe_book.png")
