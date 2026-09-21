extends "res://scripts/ui/components/solmere_button.gd"
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
var item: Dictionary={}
var quantity := ""
func _ready() -> void:
	variant="goods"; custom_minimum_size=Vector2(278,264)
	super._ready()
	var sketch := preload("res://scripts/ui/goods_sketch.gd").new()
	sketch.item_id=str(item.get("id","")); sketch.position=Vector2(62,10); sketch.size=Vector2(154,133); add_child(sketch)
	var title := PALETTE.words(self,str(item.get("name","物件")),Vector2(16,155),246,21)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var caption := PALETTE.words(self,quantity,Vector2(16,205),246,17,PALETTE.MUTED)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	tooltip_text=str(item.get("description",""))

func _draw() -> void:
	super._draw()
	draw_line(Vector2(34,245),Vector2(size.x-34,245),Color(PALETTE.SEA,.14),1,true)
	if selected: draw_circle(Vector2(size.x-23,22),4,PALETTE.SEA)
