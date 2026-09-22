extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(why)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game("A")
	var gs=root.get_node("GameState")
	var fish=load("res://scripts/core/coastal_fishing.gd")
	var rng := RandomNumberGenerator.new(); rng.seed=20260922
	for species: Dictionary in fish.SPECIES:
		var in_range := true
		var common := 0
		var lengths := {}
		for i in 2000:
			var length: float=fish.sample_length(species,rng)
			in_range=in_range and length>=species.min_cm and length<=species.max_cm
			if length>=species.common_min_cm and length<=species.common_max_cm: common+=1
			lengths[length]=true
		check(in_range,"Fish length stays within its species range: "+species.id)
		check(common>1500 and common<1850,"Most catches are common sizes, with small and large outliers")
		check(lengths.size()>50,"Catches have varied lengths")
		check(str(species.source).begins_with("https://www.fao.org/"),"Facts retain an authoritative source")
	check(fish.size_description({"id":"sardine","length_cm":23.1})=="较大个体","23.1 cm sardine is unusually large, not the common size")
	gs.current_location="port"; gs.current_minute=660
	var cast: Dictionary=fish.begin_cast()
	check(cast.ok,"Actual fishing activity starts at the sea")
	check(fish.land(cast.fish),"Landing creates a persistent pending catch")
	check(fish.resolve(false).ok,"Release creates a real fish record")
	check(gs.inventory.get(cast.fish.id,0)==0,"A released catch does not create food")
	var id: String=cast.fish.catch_id
	var materials: Dictionary=root.get_node("ResidencySystem").state().materials
	check(materials.has(id) and materials[id].length_cm==cast.fish.length_cm,"Catch material retains measured length for portfolio use")
	check(root.get_node("SaveManager").load_game(),"Reload actual saved fish journal")
	check(fish.state().catches.size()==1 and fish.state().catches[0].catch_id==id,"Save and reload retain catch identity")
	check(fish.state().catches[0].scientific_name==cast.fish.scientific_name,"Species metadata survives reload")
	var journal=load("res://scripts/ui/fish_journal.gd").new(); root.add_child(journal); await process_frame
	check(journal.detail.get_child_count()>6,"Journal renders real catch details and educational content")
	check(journal.illustration.texture!=null,"The selected actual species has its hand-drawn illustration")
	journal.queue_free(); await process_frame
	var map=load("res://scripts/residency/map_paper.gd").new(); root.add_child(map); await process_frame; await process_frame
	var marker: Button=map.get_child(0)
	check(marker.get_theme_stylebox("normal").bg_color.a==1,"Deferred global styling cannot make map labels transparent")
	check(marker.get_theme_font_size("font_size")>=20,"Chinese map names retain readable type")
	map.queue_free(); await process_frame
	print("FISH FIELD NOTES checks=",checks," failures=",failures); quit(failures)
