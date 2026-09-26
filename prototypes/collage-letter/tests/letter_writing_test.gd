extends SceneTree
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.conversation_open=false;game.set_tool("write");await process_frame
	var content: String="亲爱的小满：\n\n海盐镇今天下了一小阵雨。饭店窗边那篮柠檬，让我想起以前和你一起喝的汽水。\n\n我在这里过得很好。等你来，我们沿着海边慢慢走。\n\n祝你一切安好。\n林舟"
	game.desk.writing.insert_text_at_caret(content);await process_frame
	check(game.letter_text==content,"Writing on the page stores the actual letter")
	check(game.pieces_root.get_child_count()==0,"Writing a letter does not require collage decorations")
	game.set_tool("move");await process_frame
	check(game.letter_text_node.visible and game.letter_text_node.text==content,"Message remains printed on the paper when arranging collage")
	game.save_game(true);game.letter_text="";game.load_game(true);game.build_ui()
	check(game.letter_text==content,"Letter body survives saving and loading")
	await process_frame;await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join("written-letter.png"))
	await game.complete_letter()
	check(game.stage=="FOLDING" and game.letter_preview!=null,"A written letter can be folded and sent without stickers")
	check(absf(float(game.letter_preview.get_width())/game.letter_preview.get_height()-210.0/297.0)<0.004,"Outgoing artwork retains the A4 aspect ratio")
	game.restart();check(game.letter_text.is_empty(),"A new commission starts with a fresh letter")
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("LETTER_WRITING_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
