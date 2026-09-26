extends SceneTree
const Assets=preload("res://scripts/ui/open_assets.gd")
var checks:=0
var failures:=0
var played: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle() -> void: await process_frame; await process_frame
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	for kind in Assets.catalog().icons:
		var texture:=Assets.icon(kind)
		check(texture!=null and texture.get_width()==512,"Hand-drawn texture decodes: "+kind)
	for cue in Assets.catalog().sounds:
		for i in Assets.catalog().sounds[cue].variants.size():
			var stream:=Assets.sound(cue,i)
			check(stream is AudioStreamOggVorbis and stream.get_length()>0,"Real sound decodes: "+cue)
	check(Assets.icon("missing")==null and Assets.sound("missing")==null,"Missing optional art has a safe fallback")
	var world=root.get_node("WorldSound")
	world.cue_played.connect(func(cue: String,_stream: AudioStream,_bus: String): played.append(cue))
	world.play_ui("click"); world.play_ui("error"); await settle()
	check(played==["error"],"Semantic result replaces click even when generic signal fires first")
	await create_timer(.15).timeout; played.clear()
	world.play_ui("coin"); world.play_ui("click"); await settle()
	check(played==["coin"],"Semantic result replaces click in reverse signal order")
	await create_timer(.15).timeout; played.clear()
	world.play_ui("slider"); world.play_ui("slider"); world.play_ui("slider")
	check(played==["slider"],"Rapid slider changes are rate-limited")
	check(world.ui.bus=="SoundEffects","UI cannot contaminate town capture")
	world.play_world("door_open")
	check(world.cue_pool.busy_players.any(func(p): return p.bus=="TownWorldSoundEffects"),"Door is routed to world Foley")
	var Pool=load("res://scripts/town_sound/audio/cue_pool.gd")
	var pool=Pool.new(); root.add_child(pool)
	var tone:=AudioStreamWAV.new(); tone.mix_rate=22050; tone.format=AudioStreamWAV.FORMAT_16_BITS
	var bytes:=PackedByteArray(); bytes.resize(22050*4); tone.data=bytes
	var protected: AudioStreamPlayer=pool.play(tone,"SoundEffects",-80,2)
	for i in 12: pool.play(tone,"SoundEffects",-80,0)
	check(pool.busy_players.size()==8 and protected.playing,"Bounded pool preserves result sound under click overload")
	pool.stop_bus("SoundEffects")
	check(pool.busy_players.is_empty() and pool.available_players.size()==8,"Stopping releases voices without orphaning players")
	pool.queue_free()
	var page:=Control.new(); root.add_child(page); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var origin:=Button.new(); origin.text="Open"; page.add_child(origin); origin.grab_focus()
	var sheet=load("res://scripts/ui/components/confirm_sheet.gd").new(); page.add_child(sheet); await settle()
	var buttons: Array[Button]=[]
	for child in sheet.paper.get_children():
		if child is Button: buttons.append(child)
	check(buttons.size()==2 and root.gui_get_focus_owner()==buttons[0],"Confirmation starts on safe Cancel choice")
	buttons[1].grab_focus()
	var event:=InputEventKey.new(); event.keycode=KEY_TAB; event.pressed=true
	Input.parse_input_event(event); await settle()
	check(sheet.is_ancestor_of(root.gui_get_focus_owner()),"Tab stays inside the modal")
	sheet.queue_free(); await settle(); await settle()
	check(root.gui_get_focus_owner()==origin,"Closing modal restores invoking control")
	var saves=root.get_node("SaveManager"); var gs=root.get_node("GameState")
	root.get_node("ChapterSystem").start_new_game()
	var path: String=saves.path_for_slot(1)
	var sentinel: String=path+".tmp"
	var stale:=FileAccess.open(sentinel,FileAccess.WRITE); stale.store_string("other process incomplete save"); stale.close()
	check(saves.save_game(path) and saves.load_game(path),"Save validates and reloads through unique temporary file")
	check(FileAccess.get_file_as_string(sentinel)=="other process incomplete save","Saving never touches another process's temp file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sentinel))
	page.queue_free(); world.set_active(false); await settle()
	print("OPEN_POLISH: ",checks," checks / ",failures," failures")
	quit(failures)
