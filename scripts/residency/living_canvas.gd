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
var page_id := ""
var item_nodes: Dictionary = {}

func _ready() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode=FOCUS_ALL
	changed.connect(_sync_items)
	selection_changed.connect(_sync_items)
	_sync_items()

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
	draw_rect(Rect2(Vector2.ZERO,size),Color("fffdf7",.17))

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
			pieces[selected].x=at.x; pieces[selected].y=at.y; _sync_items(); queue_redraw(); accept_event()

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
	if not _can_drop_data(at,data): return
	var id := str(data.residency_material)
	var item: Dictionary = ResidencySystem.state().materials.get(id,{})
	if item.is_empty(): return
	var words := str(item.get("text",""))
	if words.is_empty(): words=str(item.get("title",""))
	if str(item.get("kind",""))=="receipt":
		words=str(item.get("title","小票"))+"\n"
		for line in item.get("line_items",[]): words+=str(line.get("name",""))+" × "+str(line.get("quantity",1))+"\n"
		words+="合计 "+str(item.get("total",0))+" 元"
	add_piece({"material":id,"kind":str(item.get("kind","object")),"asset_id":str(item.get("asset_id","")),"text":words,"w":220,"h":210 if item.get("kind","")=="receipt" else 160},at.clamp(Vector2(110,105),size-Vector2(110,105)))

func _sync_items() -> void:
	var keep: Array[String]=[]
	for i in pieces.size():
		var p: Dictionary=pieces[i]
		if not p.has("id"): p.id="piece_"+Crypto.new().generate_random_bytes(12).hex_encode()
		p.page=page_id; p.day=int(page_id.trim_prefix("day_")) if page_id.begins_with("day_") else 0
		p.source_asset=str(p.get("material","")); p.position={"x":p.x,"y":p.y}; p.z_index=i
		var id := str(p.id); keep.append(id)
		if not item_nodes.has(id):
			var item := preload("res://scripts/ui/components/portfolio_item.gd").new()
			item.data=p; item.owner_canvas=self; item.name=id; add_child(item); item_nodes[id]=item
		var item: Control=item_nodes[id]
		item.size=Vector2(float(p.get("w",180)),float(p.get("h",130)))
		item.pivot_offset=item.size*.5; item.position=Vector2(p.x,p.y)-item.size*.5
		item.scale=Vector2.ONE*float(p.get("scale",1)); item.rotation=float(p.get("rotation",0)); item.z_index=i
		item.selected=i==selected; item.mouse_filter=MOUSE_FILTER_IGNORE if drawing or read_only else MOUSE_FILTER_STOP
		item.focus_mode=FOCUS_NONE if read_only else FOCUS_ALL; item.queue_redraw()
	for id in item_nodes.keys():
		if not keep.has(id): item_nodes[id].queue_free(); item_nodes.erase(id)
func select_id(id: String) -> void:
	for i in pieces.size():
		if str(pieces[i].get("id",""))==id: selected=i; selection_changed.emit(); return
func move_selected(offset: Vector2) -> void:
	if read_only or selected<0: return
	var at := (Vector2(pieces[selected].x,pieces[selected].y)+offset).clamp(Vector2(20,20),size-Vector2(20,20))
	pieces[selected].x=at.x; pieces[selected].y=at.y; changed.emit()
