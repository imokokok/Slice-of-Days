extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(title)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var gs = root.get_node("GameState")
	var cs = root.get_node("ChapterSystem")
	var rs = root.get_node("ResidencySystem")
	cs.start_new_game()
	var played: Array = []
	for index in 14:
		played.append("%s_%d" % [gs.current_role,gs.current_day])
		rs.state().pages[gs.current_day-1].today = "visited_"+str(index)
		gs.commit_active_role_state()
		if index == 11:
			gs.shared_state.sleep_pending = true
			check(cs.choose_final_role("B"),"Explicit final-day order")
		var result: Dictionary = cs.advance_chapter()
		check(result.ok and bool(result.complete)==(index==13),"Chapter advances exactly once "+str(index))
	for role in ["A","B"]:
		for day in range(1,8): check(played.count("%s_%d" % [role,day])==1,"Exactly one playable day %s %d" % [role,day])
		var pages: Array = gs.role_states[role].artifacts.residency.pages
		check(pages.all(func(p: Dictionary) -> bool: return str(p.today).begins_with("visited_")),"All seven pages survive role switching "+role)
	cs.start_new_game()
	var note: String = rs.add_note("原来的想法")
	var revised: String = rs.add_note("后来的想法",note,"→")
	check(rs.state().materials.has(note) and rs.state().materials.has(revised) and rs.state().annotations.size()==1,"Notebook preserves both revisions")
	var money: int = gs.money
	gs.earn_money(12,"固定工作",{"work_minutes":80})
	var record: Dictionary = rs.proof_candidates("dorm")[-1]
	check(int(record.work_minutes)==80 and gs.money==money+12,"Wage proof retains actual minutes")
	gs.earn_money(5,"初始资金调整")
	check(rs.proof_candidates("dorm").size()==1,"Migration capital is excluded from work proof")
	var wav := AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=8000
	var bytes := PackedByteArray()
	bytes.resize(16000)
	for i in 8000: bytes.encode_s16(i*2,int(sin(i*.1)*12000))
	wav.data=bytes
	var waveform=load("res://scripts/residency/sound_paper.gd").new()
	waveform.wav=wav
	waveform.markers=[0.3]
	root.add_child(waveform)
	await process_frame
	check(waveform.peaks.size()==240 and waveform.peaks[0]>.3,"Waveform measures actual sample data")
	print("FINAL_CALENDAR ",checks," checks / ",failures," failures")
	quit(0 if failures==0 else 1)
