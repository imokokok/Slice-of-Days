extends Control
## One independently focusable placed material. Data belongs to ResidencySystem.
var data: Dictionary = {}
var owner_canvas: Control
var selected := false
var photo: Texture2D
func _ready() -> void:
	focus_mode=FOCUS_ALL; mouse_filter=MOUSE_FILTER_STOP
	focus_entered.connect(func() -> void: owner_canvas.select_id(str(data.id)))
	if data.get("kind","")=="photo":
		var library := PhotoLibrary.new()
		var source: Dictionary=ResidencySystem.state().materials.get(str(data.get("material","")),{})
		library.root_path=str(source.get("library_root",library.root_path))
		var image := library.load_photo(str(data.get("material","")))
		if image!=null: photo=ImageTexture.create_from_image(image)
func _draw() -> void:
	var ink := Color("31658b")
	var r := Rect2(Vector2.ZERO,size)
	if data.get("kind","")=="drawing":
		var points := PackedVector2Array()
		for point in data.get("points",[]): points.append(Vector2(point[0],point[1])+size*.5)
		if points.size()>1: draw_polyline(points,ink,2,true)
	elif data.get("kind","")=="photo":
		draw_rect(r,Color("fffaf0"))
		if photo!=null:
			var fit := minf((size.x-16)/photo.get_width(),(size.y-16)/photo.get_height())
			var extent := photo.get_size()*fit
			draw_texture_rect(photo,Rect2((size-extent)*.5,extent),false)
	else:
		if data.get("kind","") not in ["text","recognition"]: draw_rect(r,Color("faf4df"))
		var words := TextParagraph.new(); words.width=size.x-16
		words.add_string(str(data.get("text","")),get_theme_font("font"),22)
		words.draw(get_canvas_item(),Vector2(8,8),ink)
	if selected or has_focus(): draw_rect(r,Color("e8c75d"),false,2)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var forwarded := event.duplicate()
		forwarded.position=owner_canvas.get_global_transform_with_canvas().affine_inverse()*(get_global_transform_with_canvas()*event.position)
		owner_canvas._gui_input(forwarded)
		accept_event()
	elif event.is_pressed():
		if event.is_action_pressed("portfolio_delete"): owner_canvas.transform_selected("remove")
		else:
			var movement := Vector2.ZERO
			for row in [["ui_left",Vector2(-5,0)],["ui_right",Vector2(5,0)],["ui_up",Vector2(0,-5)],["ui_down",Vector2(0,5)]]:
				if event.is_action_pressed(row[0]): movement=row[1]
			if movement==Vector2.ZERO: return
			owner_canvas.move_selected(movement)
		accept_event()

func _can_drop_data(at: Vector2, value: Variant) -> bool:
	return owner_canvas._can_drop_data(at,value)
func _drop_data(at: Vector2, value: Variant) -> void:
	owner_canvas._drop_data(owner_canvas.get_global_transform_with_canvas().affine_inverse()*(get_global_transform_with_canvas()*at),value)
