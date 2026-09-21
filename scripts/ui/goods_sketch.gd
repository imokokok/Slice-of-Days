extends Control
## All legacy goods callers now use the approved painted sprites.
var item_id := "":
	set(value): item_id=value; queue_redraw()
func _ready() -> void: mouse_filter=MOUSE_FILTER_IGNORE
func _draw() -> void:
	var tex := preload("res://scripts/ui/components/handmade_assets.gd").texture(item_id)
	var extent := tex.get_size() * minf(size.x/tex.get_width(),size.y/tex.get_height())
	draw_texture_rect(tex,Rect2((size-extent)*.5,extent),false)
