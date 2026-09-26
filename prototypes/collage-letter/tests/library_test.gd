extends SceneTree
const L=preload("res://scripts/localization.gd")
var failures:=0
var output:=OS.get_environment("COLLAGE_TEST_OUTPUT")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func has_chinese(value: String) -> bool:
	for character in value:
		if character.unicode_at(0)>=0x3400 and character.unicode_at(0)<=0x9fff: return true
	return false
func check_controls(node: Node) -> void:
	if node is Label or node is Button: check(not has_chinese(node.text),"English control: "+node.text)
	if node is OptionButton:
		for index in node.item_count: check(not has_chinese(node.get_item_text(index)),"English option")
	for child in node.get_children(): check_controls(child)
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if not output.is_empty(): root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	if DisplayServer.get_name()=="headless" or not "--fresh" in OS.get_cmdline_user_args(): quit(2);return
	var game=load("res://Main.tscn").instantiate()
	root.add_child(game)
	for frame in 600:
		if game.ready_done: break
		await process_frame
	game.smoke=true
	check(game.ready_done and game.materials.size()==678,"678 material library loads")
	check(game.texture_cache.size()<=18,"Only visible sources render at startup")
	var counts={"图案":100,"纸张":96,"广告":160,"文字":120,"票据":121,"乐谱":17,"字母":52}
	for group in counts: check(game.material_ids(group).size()==counts[group],"Category "+group)
	var english:=0;var chinese:=0
	for raw in game.source_materials:
		var en=L.material(raw,"en")
		for field in ["title","headline","body","brand","footer","badge"]: check(not has_chinese(en[field]),"English material %d %s" % [raw.id,field])
		if raw.kind in ["print","advert","ticket"]:
			if raw.text_language_zh=="zh": chinese+=1
			else: english+=1
	check(float(chinese)/(chinese+english)>0.79 and float(chinese)/(chinese+english)<0.82,"Chinese text share around 80 percent")
	check(game.stage=="WORKBENCH","Commission opens directly at the workbench")
	game.catalog_group="广告";game.open_material_catalog()
	check(game.catalog_layer.find_children("Material_*","Button",true,false).size()==24,"Catalog page capped at 24")
	await capture("zh-ad-catalog")
	game.close_material_catalog()
	game.take_letter(626,Vector2(680,390))
	var retained_piece=game.selected
	var retained_texture=retained_piece.texture
	var hashes: Dictionary={}
	var atlas:=Image.create(180*10,144*68,false,Image.FORMAT_RGBA8)
	var detail:=Image.create(300*4,240*5,false,Image.FORMAT_RGBA8)
	var detail_count:=0
	for batch in range(0,678,24):
		for id in range(batch,mini(batch+24,678)): game.get_material_texture(id)
		await process_frame
		await RenderingServer.frame_post_draw
		for id in range(batch,mini(batch+24,678)):
			var source: Image=game.get_material_texture(id).get_image()
			check(source.get_size()==Vector2i(300,240),"Rendered material "+str(id))
			var hash:=image_hash(source.get_data())
			check(not hashes.has(hash),"Distinct rendered material "+str(id));hashes[hash]=id
			if id in [30,31,32,33,34,35,36,150,151,152,153,154,243,244,245,246,247,248,249,250]:
				detail.blit_rect(source,Rect2i(0,0,300,240),Vector2i((detail_count%4)*300,(detail_count/4)*240));detail_count+=1
			source.resize(180,144,Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(source,Rect2i(0,0,180,144),Vector2i((id%10)*180,(id/10)*144))
			game.tool="rect";game.cutting_source=id;game.start=game.sources[id].position+Vector2(24,26);game.finish_cut(game.start+Vector2(240,176))
			check(game.selected.source_id==id and game.selected.texture!=null,"Material crops "+str(id))
			game.pieces_root.remove_child(game.selected);game.selected.queue_free();game.selected=null
	if not output.is_empty():
		atlas.save_png(output.path_join("678-materials.png"));detail.save_png(output.path_join("material-detail.png"))
	check(game.texture_cache.size()<=game.MAX_CACHED_MATERIALS,"Unused material renderers are released after browsing all sources")
	check(retained_piece.texture==retained_texture and not retained_texture.get_image().is_empty(),"Placed cutout keeps its texture while the material cache is pruned")
	game.pieces_root.remove_child(retained_piece);retained_piece.queue_free();game.selected=null
	game.select_catalog_material(626)
	await process_frame
	await RenderingServer.frame_post_draw
	check(game.selected.source_id==626 and game.selected.alpha_hit,"Catalog letter is a separate movable cutout")
	check(game.selected.texture.get_image().get_pixel(0,0).a==0,"Letter background is transparent")
	game.selected.position=Vector2(700,360);game.selected.rotation=0.15
	game.save_game(true);game.load_game(true)
	check(game.pieces_root.get_child(0).alpha_hit and is_equal_approx(game.pieces_root.get_child(0).rotation,0.15),"Letter placement survives save")
	for node in game.pieces_root.get_children(): game.pieces_root.remove_child(node);node.queue_free()
	game.selected=null
	game.doodle_drawing=true;game.doodle_path=PackedVector2Array([Vector2(600,400),Vector2(640,450),Vector2(680,410)])
	game.finish_doodle()
	check(game.pieces_root.get_child(0).source_id==-3 and game.pieces_root.get_child(0).hit(Vector2(620,425)),"Doodle remains an independently movable stroke")
	for style in 8:
		game.tape_style=style;game.tape_start=Vector2(550,500+style*5);game.finish_tape(Vector2(750,500+style*5))
		check(game.selected.tape_style==style and game.selected==game.pieces_root.get_child(game.pieces_root.get_child_count()-1),"Newest patterned tape is on top")
	check(game.overlay.z_index>game.pieces_root.z_index,"Live tape and pen are above paper")
	game.save_game(true);game.load_game(true)
	check(game.pieces_root.get_child(0).strokes.size()==3 and game.pieces_root.get_child(8).tape_style==7,"Doodle and tape patterns survive save")
	game.audio.muted=false
	var clips: Dictionary={}
	for event in ["KNIFE_SLICE","PENCIL_DRAW","TAPE_PULL"]:
		game.audio.cooldown.clear();game.audio.play(event);clips[game.audio.last_clip]=true
	check(clips.size()==3,"Knife, pencil and tape use three distinct recorded sources")
	for node in game.pieces_root.get_children(): game.pieces_root.remove_child(node);node.queue_free()
	game.selected=null
	game.select_catalog_material(243)
	game.tool="rect";game.cutting_source=243;game.start=game.sources[243].position+Vector2(24,26);game.finish_cut(game.start+Vector2(240,176))
	var piece=game.selected
	var old_texture=piece.texture
	game.switch_language()
	check(L.language=="en" and piece.source_language=="zh" and piece.texture==old_texture,"Switch retains existing cutout language")
	game.save_game(true);game.load_game(true)
	check(game.pieces_root.get_child(0).source_language=="zh" and game.pieces_root.get_child(0).texture==old_texture,"Reload retains cutout language")
	game.tool="rect";game.cutting_source=243;game.start=game.sources[243].position+Vector2(24,26);game.finish_cut(game.start+Vector2(240,176))
	check(game.selected.source_language=="en","New cut uses English source")
	game.build_ui();check_controls(game.ui)
	game.help_open=true;game.build_ui();check_controls(game.ui)
	game.help_open=false;game.build_ui()
	check(not has_chinese(L.t("火漆留下了不规则的印记，它也是这封信的一部分。")),"English wax feedback is translated")
	await capture("en-workbench")
	for phase in ["DIALOGUE","FOLDING","ENVELOPE","WAX_SEAL","SEND","END"]:
		game.stage=phase;game.build_ui();check_controls(game.ui)
	game.stage="WORKBENCH";game.build_ui()
	game.catalog_group="广告";game.catalog_page=0;game.open_material_catalog();check_controls(game.catalog_layer)
	await capture("en-ad-catalog")
	game.close_material_catalog()
	game.open_bottles()
	await capture("en-post-office")
	for child in game.get_children():
		if child is CanvasLayer and child!=game.ui: check_controls(child)
	game.audio.shutdown()
	game.queue_free()
	await process_frame
	await process_frame
	print("LIBRARY_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures," unique=",hashes.size()," Chinese share=",float(chinese)/(chinese+english))
	quit(failures)

func image_hash(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256);context.update(bytes)
	return context.finish().hex_encode()
