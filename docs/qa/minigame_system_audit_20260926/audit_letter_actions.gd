extends RefCounted
static func run(g: Node2D, host: Node) -> void:
	g.save_path="user://finishing_qa.json"
	assert(g.stage=="WORKBENCH")
	g.tool="rect";g.cutting_source=0;g.start=Vector2(90,255);g.finish_cut(Vector2(290,370));g.selected.position=Vector2(700,390)
	await g.capture_test("desk-new")
	await g.complete_letter()
	g.stage_input(Vector2(700,650),true);g.stage_input(Vector2(700,450),false)
	await g.get_tree().create_timer(0.6).timeout
	g.stage_input(Vector2(700,270),true);g.stage_input(Vector2(700,450),false)
	await g.get_tree().create_timer(0.6).timeout
	g.stage_input(Vector2(700,450),true);g.stage_input(Vector2(700,450),false)
	assert(g.stage=="ENVELOPE")
	var f=g.finishing
	f.input(f.letter_pos,true);f.mouse_move(Vector2(720,470))
	await g.capture_test("envelope-half-in")
	assert(not f.inserted)
	f.mouse_move(Vector2(720,650));f.input(Vector2(720,650),false)
	assert(f.inserted)
	await g.capture_test("envelope-inserted")
	f.input(Vector2(720,270),true);f.mouse_move(Vector2(720,525));f.input(Vector2(720,525),false)
	assert(g.stage=="WAX_SEAL")
	f.input(f.match_pos,true);f.mouse_move(Vector2(115,699));f.mouse_move(Vector2(205,699))
	assert(f.match_lit and not f.candle)
	f.mouse_move(f.WICK);f.input(f.WICK,false)
	assert(f.candle and f.phase=="PELLETS")
	f.input(Vector2(310,600),true);f.mouse_move(f.spoon);f.input(f.spoon,false)
	assert(f.pellets and f.phase=="MELT")
	await g.capture_test("wax-pellets-in-spoon")
	f.input(f.spoon,true);f.mouse_move(f.WICK-Vector2(0,40));f.input(f.spoon,false)
	await g.get_tree().create_timer(3.4).timeout
	assert(f.phase=="POUR" and f.heat>=1)
	f.input(f.spoon,true);f.mouse_move(f.SEAM-Vector2(0,55));f.input(f.spoon,false)
	await g.get_tree().create_timer(1.3).timeout
	assert(f.phase=="STAMP" and f.pour_good)
	f.input(f.stamp,true);f.mouse_move(f.pool)
	await g.get_tree().create_timer(1.1).timeout
	await g.capture_test("stamp-press")
	f.input(f.pool,false)
	assert(f.impressed and f.impression_good)
	await g.get_tree().create_timer(2).timeout
	assert(g.stage=="SEND")
	g.save_game(true);g.load_game(true);f=g.finishing
	assert(f.impression_good and f.pour_committed)
	f.input(f.mail_pos,true);f.input(f.mail_pos,false)
	assert(f.mailbox==1)
	f.input(f.mail_pos,true);f.mouse_move(Vector2(1070,435));f.input(Vector2(1070,435),false)
	await g.get_tree().create_timer(0.4).timeout
	await g.capture_test("mailbox-half-in")
	await g.get_tree().create_timer(0.6).timeout
	assert(f.mailed==1)
	f.input(Vector2(1070,280),true);f.mouse_move(Vector2(1070,465));f.input(Vector2(1070,465),false)
	assert(g.stage=="END")
	var tree=g.get_tree()
	var gs=tree.root.get_node("GameState")
	var modules=tree.root.get_node("GameplayModuleSystem")
	var before: int=gs.current_minute
	var money: int=gs.money
	host._complete()
	await tree.create_timer(.8).timeout
	assert(modules.state_for("ghostwriting").completed)
	assert(gs.current_minute==before+50 and gs.money==money+90)
	assert(tree.root.get_node("ChapterSystem").day_state().main_completed)
	assert(tree.root.get_node("SaveManager").load_game())
	assert(modules.state_for("ghostwriting").completed and gs.money==money+90)
	print("CURRENT_LETTER_HOST PASS physical finishing, completion, 50 minutes, 90 yuan, Day 3, save reload")
	tree.quit()
