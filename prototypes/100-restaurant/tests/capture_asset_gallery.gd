extends SceneTree
func _initialize() -> void:
	root.size=Vector2i(1600,946)
	call_deferred("run")
func run() -> void:
	var panel:=Control.new()
	root.add_child(panel)
	var rows=JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json"))
	var art=preload("res://modules/restaurant/assets/sprite_library.gd")
	var errors:=0
	for i in rows.size():
		var bg:=ColorRect.new()
		bg.color=Color("4c4439") if i%2 else Color("c9b48f")
		bg.position=Vector2((i%10)*160,(i/10)*105)
		bg.size=Vector2(158,103)
		panel.add_child(bg)
		var texture: Texture2D=art.food(rows[i].id)
		if texture==null:
			push_error("Missing sprite: "+rows[i].id)
			errors+=1
			continue
		var image:=texture.get_image()
		for y in image.get_height():
			for x in image.get_width():
				var c:=image.get_pixel(x,y)
				if c.a>0.1 and minf(c.r,c.b)-c.g>0.78:
					push_error("Visible matte: "+rows[i].id)
					errors+=1
		var view:=TextureRect.new()
		view.texture=texture
		view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		view.position=Vector2(24,4)
		view.size=Vector2(110,78)
		bg.add_child(view)
		var name_label:=Label.new()
		name_label.text=rows[i].name
		name_label.add_theme_font_override("font",preload("res://modules/restaurant/assets/fonts/noto_serif_sc.ttf"))
		name_label.add_theme_font_size_override("font_size",16)
		name_label.position=Vector2(3,80)
		name_label.size=Vector2(150,22)
		name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		bg.add_child(name_label)
	if DisplayServer.get_name()!="headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../100饭店_食材检查.png")
	print("Asset alpha audit: %d sprites, %d errors"%[rows.size(),errors])
	panel.queue_free()
	await process_frame
	quit(0 if errors==0 else 1)
