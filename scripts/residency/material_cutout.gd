extends Control
## A loose material, with the same physical face used for its drag preview.
signal activated
var material_id := ""
var item: Dictionary = {}
var photo: Texture2D
var hovering := false
var click_pending := false
func _ready() -> void:
	focus_mode=FOCUS_ALL
	mouse_default_cursor_shape=CURSOR_DRAG
	mouse_filter=MOUSE_FILTER_STOP
	clip_contents=true
	tooltip_text=str(item.get("title","素材"))+"\n点击放入 · 拖到纸上 · 回车确认"
	mouse_entered.connect(func() -> void: hovering=true; queue_redraw())
	mouse_exited.connect(func() -> void: hovering=false; queue_redraw())
	if str(item.get("kind",""))=="photo" and photo==null:
		var library := PhotoLibrary.new()
		library.root_path=str(item.get("library_root",library.root_path))
		var source := library.load_photo(material_id)
		if source!=null: photo=ImageTexture.create_from_image(source)
func _draw() -> void:
	var kind := str(item.get("kind","note"))
	var ink := Color("31658b")
	var face := Color("fffdf6") if kind in ["photo","receipt"] else Color("f5edcc")
	if kind=="recognition": face=Color("e3edf2")
	var artwork := str(item.get("asset_id","receipt" if kind=="receipt" else ""))
	if not artwork.is_empty():
		var tex := preload("res://scripts/ui/components/handmade_assets.gd").texture(artwork)
		draw_texture_rect(tex,Rect2(Vector2.ZERO,size),false)
	else: draw_rect(Rect2(Vector2.ZERO,size),face)
	if hovering: draw_line(Vector2(8,size.y-3),Vector2(size.x-8,size.y-3),Color("e3c557"),3,true)
	var top := 21.0
	if photo!=null:
		var area := size-Vector2(16,40)
		var fit := minf(area.x/photo.get_width(),area.y/photo.get_height())
		var extent := photo.get_size()*fit
		draw_texture_rect(photo,Rect2(Vector2((size.x-extent.x)/2,8),extent),false)
		top=size.y-27
	elif kind=="sound":
		for i in 24:
			var height := 5+absf(sin(i*1.8))*22
			draw_line(Vector2(12+i*5,27-height/2),Vector2(12+i*5,27+height/2),ink,1.5,true)
		top=52
	elif kind=="receipt":
		draw_string(get_theme_font("font"),Vector2(10,20),"SOLMERE / 小票",HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
		draw_dashed_line(Vector2(8,28),Vector2(size.x-8,28),Color(ink,.4),1,4)
		top=39
	elif kind=="recognition":
		draw_arc(Vector2(size.x-27,27),16,0,TAU,28,Color(ink,.5),1.5,true)
		top=51
	else:
		draw_rect(Rect2(size.x*.35,0,size.x*.3,12),Color("eed577",.65))
	var words := TextParagraph.new()
	words.width=size.x-20
	words.add_string(str(item.get("title",item.get("text","素材"))),get_theme_font("font"),16)
	words.draw(get_canvas_item(),Vector2(10,top),ink)
func _get_drag_data(_position: Vector2) -> Variant:
	click_pending=false
	var preview := Control.new()
	var card = get_script().new()
	card.material_id=material_id; card.item=item; card.photo=photo; card.size=size
	card.position=-size*.5; card.rotation=rotation
	preview.add_child(card); set_drag_preview(preview)
	return {"residency_material":material_id}
func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"): activated.emit(); accept_event()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: click_pending=true; grab_focus()
		else:
			if click_pending and Rect2(Vector2.ZERO,size).has_point(event.position): activated.emit()
			click_pending=false
		accept_event()
