extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var output:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not output.is_empty():root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true;game.conversation_open=false;game.letter_text="你好，远方的朋友。\n\n愿你今天也遇到一件小小的好事。\n\n来自海边的问候";game.letter_text_node.text=game.letter_text
	game.bottle.base_url="http://127.0.0.1:1";game.bottle.player={};game.bottle.identity_path="user://bottle_ritual_test_identity.json"
	game.start_bottle({});game.set_tool("move");await process_frame
	await game.complete_letter()
	check(game.stage=="BOTTLE","Drift letters enter the bottle ritual, without envelope or wax")
	var ritual=game.bottle_finish
	ritual.input(ritual.cork_at,true);ritual.input(Vector2(1120,240),false)
	check(ritual.phase=="ROLL" and ritual.cork_at==Vector2(1000,329),"The ritual cannot skip rolling the letter")
	ritual.input(Vector2(490,650),true);ritual.move(Vector2(490,450));await capture("bottle-rolling")
	ritual.input(Vector2(490,270),false);check(ritual.phase=="UNCORK","Paper must be completely rolled before opening the bottle")
	ritual.input(ritual.cork_at,true);ritual.input(Vector2(1120,240),false);check(ritual.phase=="INSERT","Cork is physically removed")
	ritual.input(ritual.roll_at,true);ritual.input(Vector2(1000,550),false)
	check(ritual.phase=="INSERT" and ritual.insertion==0,"Paper cannot pass through the side of the bottle")
	ritual.input(ritual.roll_at,true);ritual.move(Vector2(1000,220));ritual.move(Vector2(1000,420));await capture("bottle-half-in")
	check(ritual.insertion>0 and ritual.insertion<1,"Insertion is continuous through the mouth")
	var halfway: float=ritual.insertion
	game.save_game(true);game.load_game(true);ritual=game.bottle_finish
	check(ritual.phase=="INSERT" and is_equal_approx(ritual.insertion,halfway) and ritual.started_above_mouth,"A partially inserted letter resumes at the same position")
	ritual.input(ritual.roll_at,true)
	ritual.input(Vector2(1000,558),false);check(ritual.phase=="CORK","Paper reaches the inside before recorking")
	ritual.input(ritual.cork_at,true);ritual.input(Vector2(1000,329),false);check(ritual.phase=="SEA","Pressing the cork seals the bottle")
	await capture("bottle-sealed")
	game.save_game(true);game.load_game(true);ritual=game.bottle_finish
	check(game.stage=="BOTTLE" and ritual.phase=="SEA" and ritual.insertion>=0.98,"Packed bottle survives restarting")
	ritual.input(ritual.bottle_at,true);ritual.input(Vector2(1190,380),false)
	check(ritual.phase=="SEA" and not game.busy,"The letter only leaves when the bottle reaches the visible water")
	ritual.input(ritual.bottle_at,true);ritual.input(Vector2(1270,550),false)
	for poll in 400:
		await create_timer(0.05).timeout
		if not game.busy and ritual.phase=="SEA":break
	check(not game.busy and game.stage=="BOTTLE" and ritual.phase=="SEA" and game.bottle_published_id==0,"Offline publication keeps the sealed bottle available for retry")
	await capture("bottle-offline-retry")
	game.audio.shutdown();game.queue_free();await process_frame;await process_frame
	print("BOTTLE_RITUAL_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
