extends SceneTree
var failures:=0
func check(ok: bool, why: String) -> void:
	if not ok:failures+=1;push_error(why)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.conversation_open=false;game.tools_open=true;game.build_ui();game.take_letter(626,Vector2(710,365))
	var original: Dictionary=game.selected.serialize()
	game.set_tool("rect")
	check(absf(game.LETTER.size.x/game.LETTER.size.y-210.0/297.0)<0.001,"All base papers use the A4 aspect ratio")
	var hashes: Array=[]
	for style in game.LetterPaper.NAMES.size():
		game.desk.kit.get_node("LetterPaper_"+str(style)).pressed.emit()
		await process_frame;await RenderingServer.frame_post_draw
		check(game.letter_paper_style==style,"Paper swatch switches style")
		check(game.pieces_root.get_child_count()==1 and game.selected.serialize()==original,"Changing paper preserves the collage")
		var screenshot: Image=game.get_viewport().get_texture().get_image()
		var region:=screenshot.get_region(Rect2i(465,220,480,475))
		var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(region.get_data());hashes.append(digest.finish().hex_encode())
		var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
		if not folder.is_empty():screenshot.save_png(folder.path_join("paper-"+str(style)+".png"))
	var unique: Dictionary={}
	for hash_value in hashes:unique[hash_value]=true
	check(unique.size()==24,"All 24 paper appearances differ")
	game.choose_letter_paper(3);game.save_game(true);game.letter_paper_style=0;game.load_game(true)
	check(game.letter_paper_style==3,"Selected paper survives reload")
	check(game.pieces_root.get_child_count()==1,"Collage survives paper reload")
	game.tape_start=Vector2(665,360);game.finish_tape(Vector2(755,370))
	await game.complete_letter()
	check(game.stage=="FOLDING" and game.letter_preview!=null,"Selected paper is captured into the outgoing letter")
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("LETTER_PAPER_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
