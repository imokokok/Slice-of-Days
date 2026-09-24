extends SceneTree
func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	root.size = Vector2i(1200, 940)
	root.content_scale_size = Vector2i(1200, 940)
	var paper := ColorRect.new()
	paper.color = Color("ede0c4")
	paper.size = Vector2(1200,940)
	root.add_child(paper)
	var library = preload("res://modules/restaurant/assets/cut_state_library.gd")
	var ids := ["tomato","onion","carrot","potato","mushroom","eggplant","cucumber"]
	label("DERIVED CUT ART / appearance variants; knife geometry determines amount",Vector2(26,15))
	for column in 6: label(["Slice A","Slice B","End slice","Chunk A","Chunk B","Wedge"][column],Vector2(200+column*162,50))
	for row in ids.size():
		label(ids[row],Vector2(25,122+row*117))
		for column in 6:
			var icon := TextureRect.new()
			icon.texture = library.texture(ids[row],"slice" if column<3 else "dice",column%3)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(180+column*162,80+row*117)
			icon.size = Vector2(140,100)
			root.add_child(icon)
	await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var error := root.get_texture().get_image().save_png(args[0])
	print("PASS: 42 active cut appearance variants rendered" if error==OK else "FAIL: capture write")
	quit(error)

func label(words: String, point: Vector2) -> void:
	var node := Label.new()
	node.text = words
	node.position = point
	node.add_theme_color_override("font_color", Color("503e31"))
	node.add_theme_font_size_override("font_size",18)
	root.add_child(node)
