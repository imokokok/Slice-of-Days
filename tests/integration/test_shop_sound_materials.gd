extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run()->void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game()
	var gs=root.get_node("GameState"); var saves=root.get_node("SaveManager")
	gs.switch_to_role("B",2,true); gs.current_location="record_store"; gs.current_minute=660
	var store:=SampleStore.new()
	var work=load("res://scripts/town_sound/studio/StudioScreen.gd").new(); root.add_child(work); await process_frame
	check(not root.get_node("CharacterSystem").owns_pocket_item("recorder"),"B keeps notebook ownership")
	work.find_child("ShopSource_wind",true,false).pressed.emit()
	work.find_child("ShopSource_water",true,false).pressed.emit()
	check(work.model.clips.size()==2 and store.list_samples().size()==2,"Visible buttons add two real source files and two editable clips")
	for sample in store.list_samples():
		check(sample.role=="B" and sample.source_mode=="shop_library","Source metadata says shop library and actual owner")
		var wav=store.load_audio(sample)
		check(wav is AudioStreamWAV and wav.get_length()>0 and sample.signal_peak>0,"Material contains nonempty audible PCM")
	check(await work.prepare_mix(),"Imported materials can be rendered into a real mix")
	check(saves.save_game() and saves.load_game(),"Material ownership persists through reload")
	work.find_child("ShopSource_wind",true,false).pressed.emit()
	check(work.model.clips.size()==3 and store.list_samples().size()==2,"Reusing a source adds a clip without duplicating the source file")
	var script=saves.get_script(); var failing:=GDScript.new()
	failing.source_code="extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\treturn false\n"
	check(failing.reload()==OK,"Save failure fixture compiles")
	saves.set_script(failing); work.find_child("ShopSource_fire",true,false).pressed.emit()
	check(work.model.clips.size()==3 and store.list_samples().size()==2,"Failed save does not append a phantom source or clip")
	saves.set_script(script); work.find_child("ShopSource_fire",true,false).pressed.emit()
	check(work.model.clips.size()==4 and store.list_samples().size()==3,"Save retry imports the real file once")
	gs.current_location="residence"; work._add_shop_sample("water")
	check(work.model.clips.size()==4,"Shop material entry cannot be used away from shop")
	gs.switch_to_role("A",3,true)
	check(store.list_samples().is_empty(),"B's imported sources do not leak into A's library")
	work.queue_free(); await process_frame
	print("SHOP_SOUND_MATERIALS: ",checks," checks / ",failures," failures"); quit(failures)
