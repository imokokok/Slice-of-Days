extends RefCounted
static func run(g: Node2D) -> void:
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
	var prior=g.commission_index;g.restart();assert(g.stage=="WORKBENCH" and g.commission_index==prior+1)
	# A failed pour and short press stay failed through serialization; there is no retry transition.
	var bad=load("res://scripts/finishing.gd").new(g)
	g.stage="WAX_SEAL";bad.phase="POUR";bad.heat=1;bad.spoon=Vector2(780,510)
	bad.input(bad.spoon,true);bad.input(bad.spoon,false);bad.tick(1.2)
	assert(bad.pour_committed and not bad.pour_good)
	bad.input(bad.stamp,true);bad.mouse_move(bad.pool);bad.input(bad.pool,false)
	assert(bad.impressed and not bad.impression_good)
	var restored=load("res://scripts/finishing.gd").new(g);restored.restore(bad.serialize())
	assert(restored.pour_committed and not restored.impression_good and restored.phase=="COOL")
	g.audio.shutdown()
	print("PHYSICAL_FINISHING_PASS: fold, occlusion, flap drag, matchbox strike, candle, melt, irreversible pour, press, mailbox, save, next commission")
	var tree=g.get_tree()
	bad=null;restored=null;f=null
	g.queue_free()
	await tree.process_frame
	await tree.process_frame
	tree.create_timer(0.1).timeout.connect(tree.quit)
