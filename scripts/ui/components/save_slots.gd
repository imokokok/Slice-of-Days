extends Control
signal loaded(slot: int)
signal changed
func _ready() -> void:
	size=Vector2(1020,445)
	for i in SaveManager.SLOT_COUNT:
		var slot := i+1
		var info := SaveManager.slot_summary(slot)
		var card := preload("res://scripts/ui/components/solmere_button.gd").new()
		card.variant="outlined"; card.position=Vector2(i*340,0); card.size=Vector2(318,368); card.disabled=not bool(info.get("exists",false)) or not bool(info.get("compatible",false)); card.name="LoadSlot_%d" % slot; add_child(card)
		card.pressed.connect(func() -> void: loaded.emit(slot))
		var paper := ColorRect.new(); paper.position=Vector2(12,12); paper.size=Vector2(294,165); paper.color=Color("c8d9e0"); paper.mouse_filter=MOUSE_FILTER_IGNORE; card.add_child(paper)
		if not str(info.get("thumbnail","")).is_empty():
			var image := Image.load_from_file(str(info.thumbnail))
			if image!=null:
				var photo := TextureRect.new(); photo.texture=ImageTexture.create_from_image(image); photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; photo.position=paper.position; photo.size=paper.size; photo.mouse_filter=MOUSE_FILTER_IGNORE; card.add_child(photo)
		else: _label(card,"尚无影像" if bool(info.get("exists",false)) else "尚未开始",Vector2(28,78),22)
		_label(card,"旅程 %02d" % slot,Vector2(21,199),24)
		if bool(info.get("exists",false)):
			_label(card,("Day %02d · %s" % [int(info.day),GuidanceSystem.time_text(int(info.minute))]) if bool(info.get("compatible",false)) else "旧七日存档 · 请开始新旅程",Vector2(21,249),18)
			_label(card,TravelSystem.location_name(str(info.location)),Vector2(21,292),20)
			var remove := preload("res://scripts/ui/components/solmere_button.gd").new(); remove.text="删除这份存档"; remove.position=Vector2(i*340+64,386); remove.size=Vector2(200,40); remove.disabled=not FileAccess.file_exists(SaveManager.path_for_slot(slot)); add_child(remove)
			remove.pressed.connect(func() -> void:
				var confirm := preload("res://scripts/ui/components/confirm_sheet.gd").new(); confirm.heading="删除旅程 %02d？" % slot; confirm.description="这份存档删除后无法恢复。\n\n取消即可继续保留。"; confirm.confirm_text="删除存档"
				confirm.accepted.connect(func() -> void:
					if SaveManager.delete_slot(slot): changed.emit()
					confirm.queue_free())
				get_tree().current_scene.add_child(confirm))

func _label(parent: Node, text: String, at: Vector2, point: int) -> void:
	var label := Label.new(); label.text=text; label.position=at; label.size=Vector2(276,40); label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; label.add_theme_font_size_override("font_size",point); label.mouse_filter=MOUSE_FILTER_IGNORE; parent.add_child(label)
