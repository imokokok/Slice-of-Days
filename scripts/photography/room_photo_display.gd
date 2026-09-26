extends Control
## Physical paper copies visible in the existing home, backed by real Gallery files.
func _ready() -> void:
	position=Vector2(785,190)
	size=Vector2(655,175)
	mouse_filter=MOUSE_FILTER_IGNORE
	GameState.state_changed.connect(refresh)
	FilmSystem.changed.connect(refresh)
	refresh()

func refresh() -> void:
	for child in get_children(): child.queue_free()
	var ids: Array=FilmSystem.state().room_display
	for i in mini(ids.size(),4):
		var id:=str(ids[ids.size()-1-i])
		var photo:=FilmSystem.photo(id)
		var library:=PhotoLibrary.new()
		library.root_path=str(photo.get("library_root","user://photos"))
		var image:=library.load_photo(id)
		if image==null: continue
		var border:=preload("res://scripts/photography/photo_print.gd").new()
		border.position=Vector2(i*152+10,18+(i%2)*9)
		border.size=Vector2(139,116)
		border.image=image
		border.metadata=photo
		border.rotation=(-.03 if i%2 else .025)
		border.mouse_filter=MOUSE_FILTER_IGNORE
		add_child(border)
	queue_redraw()

func _draw() -> void:
	if FilmSystem.state().room_display.is_empty(): return
	draw_line(Vector2(0,24),Vector2(625,35),Color("796a4d"),2)
