extends SceneTree
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.conversation_open=false;game.tools_open=true;game.set_tool("write");await process_frame
	var content: String="亲爱的小满：\n\n海盐镇今天下了一小阵雨。饭店窗边那篮柠檬，让我想起以前和你一起喝的汽水。\n\n我在这里过得很好。等你来，我们沿着海边慢慢走。\n\n祝你一切安好。\n林舟"
	game.desk.writing.insert_text_at_caret(content);await process_frame
	check(game.letter_text==content,"Writing on the page stores the actual letter")
	check(game.pieces_root.get_child_count()==0,"Writing a letter does not require collage decorations")
	var editor: TextEdit=game.desk.writing
	var pen=game.desk.writing_pen
	var original_editor_id: int=editor.get_instance_id()
	var original_line: int=editor.get_caret_line();var original_column: int=editor.get_caret_column()
	game.desk.kit.get_node("LetterInk_4").pressed.emit()
	check(game.letter_ink_color==game.LETTER_INKS[4] and editor.get_theme_color("font_color")==game.LETTER_INKS[4],"Ink swatch updates the real writing color")
	check(game.desk.writing.get_instance_id()==original_editor_id and editor.get_caret_line()==original_line and editor.get_caret_column()==original_column,"Choosing ink preserves the editor, caret and editing state")
	check(pen.committed_strokes==1 and game.audio.last_clip=="pencil","Committed words move one pen and play a recorded writing sound")
	check(pen.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Physical pen never intercepts writing clicks")
	await process_frame;await RenderingServer.frame_post_draw;await process_frame
	check(pen.position.distance_to(pen.caret_tip())<8 and game.LETTER.has_point(pen.target_tip),"Pen nib follows the real rendered caret within the paper")
	var commits: int=pen.committed_strokes
	editor.set_caret_line(0);editor.set_caret_column(3)
	await process_frame;await RenderingServer.frame_post_draw;await process_frame
	check(pen.position.distance_to(pen.caret_tip())<8 and pen.committed_strokes==commits,"Moving the caret repositions the pen without writing or replaying a sound")
	editor.text_changed.emit()
	check(pen.committed_strokes==commits and game.letter_text==content,"An unchanged-text signal never counts as committed ink")
	await create_timer(1.0).timeout
	check(pen.modulate.a<0.02,"An idle pen lifts and fades instead of covering the letter")
	editor.insert_text_at_caret("好");await process_frame;await RenderingServer.frame_post_draw;await process_frame
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join("writing-pen.png"))
	check(pen.committed_strokes==commits+1,"A new committed character wakes the same pen instance")
	editor.backspace();await process_frame
	check(game.letter_text==content and pen.committed_strokes==commits+1,"Deleting text does not animate new ink")
	game.set_tool("move");await process_frame
	check(game.letter_text_node.visible and game.letter_text_node.text==content,"Message remains printed on the paper when arranging collage")
	game.save_game(true);game.letter_text="";game.letter_ink_color=game.INK;game.load_game(true);game.build_ui()
	check(game.letter_text==content and game.letter_ink_color==game.LETTER_INKS[4],"Letter body and ink color survive saving and loading")
	check(game.letter_text_node.get_theme_color("font_color")==game.letter_ink_color,"Export label uses the chosen ink")
	await process_frame;await RenderingServer.frame_post_draw
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join("written-letter.png"))
	await game.complete_letter()
	check(game.stage=="FOLDING" and game.letter_preview!=null,"A written letter can be folded and sent without stickers")
	check(absf(float(game.letter_preview.get_width())/game.letter_preview.get_height()-210.0/297.0)<0.004,"Outgoing artwork retains the A4 aspect ratio")
	var export: Image=game.letter_preview.get_image();var ink_pixels:=0
	for y in export.get_height():
		for x in export.get_width():
			var pixel:=export.get_pixel(x,y)
			if absf(pixel.r-game.letter_ink_color.r)+absf(pixel.g-game.letter_ink_color.g)+absf(pixel.b-game.letter_ink_color.b)<0.07:ink_pixels+=1
	check(ink_pixels>40,"The mailed artwork contains the selected ink color, not just an editor tint")
	game.restart();check(game.letter_text.is_empty(),"A new commission starts with a fresh letter")
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("LETTER_WRITING_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
