extends Control
## Role-local, free composition. Geometry is stored in paper coordinates.
signal selection_changed
signal changed
var pieces: Array = []
var selected := -1
var dragging := false
var drag_offset := Vector2.ZERO
var photo_cache: Dictionary = {}
var drawing := false
var stroke: Array = []
var read_only := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode=FOCUS_ALL

func _input(event: InputEvent) -> void:
	# Finish even if the pointer has left the paper before release.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_gesture()

func _finish_gesture() -> void:
	var modified := dragging
	if stroke.size()>1:
		var bounds := Rect2(Vector2(stroke[0][0],stroke[0][1]),Vector2.ONE)
		for point in stroke: bounds=bounds.expand(Vector2(point[0],point[1]))
		var center := bounds.get_center()
		for point in stroke: point[0]-=center.x; point[1]-=center.y
		pieces.append({"kind":"drawing","x":center.x,"y":center.y,"w":maxf(bounds.size.x,12),"h":maxf(bounds.size.y,12),"points":stroke.duplicate(true),"scale":1.0,"rotation":0.0})
		modified=true
	stroke.clear(); dragging=false
	if modified: changed.emit()
	queue_redraw()

func piece_rect(p: Dictionary) -> Rect2:
	return Rect2(-Vector2(float(p.get("w",180)),float(p.get("h",130)))*0.5,Vector2(float(p.get("w",180)),float(p.get("h",130))))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color.WHITE)
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		draw_set_transform(Vector2(float(p.x),float(p.y)),float(p.get("rotation",0)),Vector2.ONE*float(p.get("scale",1)))
		var r := piece_rect(p)
		var ink := Color("31658b")
		if p.get("kind","") == "drawing":
			var points := PackedVector2Array()
			for point in p.get("points",[]): points.append(Vector2(point[0],point[1]))
			if points.size()>1: draw_polyline(points,ink,2,true)
		elif p.get("kind","") == "photo":
			var id := str(p.get("material",""))
			if not photo_cache.has(id):
				var library := PhotoLibrary.new()
				var source: Dictionary = ResidencySystem.state().materials.get(id,{})
				library.root_path = str(source.get("library_root",library.root_path))
				var image := library.load_photo(id)
				photo_cache[id] = ImageTexture.create_from_image(image) if image != null else null
			draw_rect(r,Color("fffaf0"))
			if photo_cache[id] != null:
				var texture: Texture2D = photo_cache[id]
				var fit := minf((r.size.x-16)/texture.get_width(),(r.size.y-16)/texture.get_height())
				var fitted := texture.get_size()*fit
				draw_texture_rect(texture,Rect2(-fitted*.5,fitted),false)
		else:
			if p.get("kind","") not in ["text","recognition"]: draw_rect(r,Color("faf4df"))
			var paragraph := TextParagraph.new()
			paragraph.width=r.size.x-16
			paragraph.add_string(str(p.get("text","")),get_theme_font("font"),22)
			paragraph.draw(get_canvas_item(),r.position+Vector2(8,8),ink)
		if selected == i: draw_rect(r,Color("e8c75d"),false,2)
	draw_set_transform(Vector2.ZERO)
	if stroke.size()>1:
		var line := PackedVector2Array()
		for point in stroke: line.append(Vector2(point[0],point[1]))
		draw_polyline(line,Color("31658b"),2,true)

func _gui_input(event: InputEvent) -> void:
	if read_only: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			if drawing:
				selected=-1; selection_changed.emit()
				stroke=[[event.position.x,event.position.y]]; accept_event(); return
			selected=-1
			for i in range(pieces.size()-1,-1,-1):
				var p: Dictionary = pieces[i]
				var local: Vector2 = (event.position-Vector2(p.x,p.y)).rotated(-float(p.get("rotation",0)))/float(p.get("scale",1))
				if piece_rect(p).has_point(local): selected=i; break
			dragging=selected>=0
			if dragging: drag_offset=event.position-Vector2(pieces[selected].x,pieces[selected].y)
			selection_changed.emit()
		else:
			_finish_gesture()
		queue_redraw(); accept_event()
	elif event is InputEventMouseMotion:
		if drawing and not stroke.is_empty(): stroke.append([event.position.x,event.position.y]); queue_redraw(); accept_event()
		elif dragging and selected>=0:
			var at: Vector2 = (event.position-drag_offset).clamp(Vector2(20,20),size-Vector2(20,20))
			pieces[selected].x=at.x; pieces[selected].y=at.y; queue_redraw(); accept_event()

func add_piece(data: Dictionary, at: Vector2) -> void:
	if read_only: return
	data.merge({"x":at.x,"y":at.y,"scale":1.0,"rotation":0.0},false)
	pieces.append(data); selected=pieces.size()-1
	changed.emit(); selection_changed.emit(); queue_redraw()

func transform_selected(action: String) -> void:
	if read_only or selected<0 or selected>=pieces.size(): return
	var p: Dictionary = pieces[selected]
	match action:
		"rotate_left": p.rotation=float(p.get("rotation",0))-.12
		"rotate_right": p.rotation=float(p.get("rotation",0))+.12
		"smaller": p.scale=clampf(float(p.get("scale",1))-.1,.25,3)
		"larger": p.scale=clampf(float(p.get("scale",1))+.1,.25,3)
		"front": pieces.remove_at(selected); pieces.append(p); selected=pieces.size()-1
		"back": pieces.remove_at(selected); pieces.push_front(p); selected=0
		"remove": pieces.remove_at(selected); selected=-1
	changed.emit(); selection_changed.emit(); queue_redraw()

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return not read_only and data is Dictionary and data.has("residency_material")

func _drop_data(at: Vector2, data: Variant) -> void:
	var id := str(data.residency_material)
	var item: Dictionary = ResidencySystem.state().materials.get(id,{})
	add_piece({"material":id,"kind":str(item.get("kind","object")),"text":str(item.get("text",item.get("title",""))),"w":220,"h":160},at)
