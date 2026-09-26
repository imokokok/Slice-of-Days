extends SceneTree
## Actual street rendering and entrance checks, in a disposable save profile.
const Composition=preload("res://scripts/ui/street_composition.gd")
const Cutout=preload("res://scripts/ui/authored_jpeg.gd")
var failures:=0
var checks:=0
var gs
var router
var capture_dir:="res://.runtime/supplied-frontages/captures"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
	else: print("PASS ",message)
func settle() -> void:
	await process_frame
	while router.transitioning: await process_frame
	await create_timer(.3).timeout
func arrive(place: String) -> void:
	gs.current_location=place; gs.shared_state.map_arrival=place
	router.town_day(.01); await settle()
	current_scene.set_process(false)
	current_scene.street.player_x=current_scene._place_center()+Composition.entry_offset(place)
	current_scene.street.move_player(0,0); current_scene._refresh()
	await settle()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir+"/"+name+".png")==OK,"Capture "+name)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_title("Solmere · 新邮局、菜摊与杂货店")
	gs=root.get_node("GameState"); router=root.get_node("SceneRouter")
	root.get_node("ChapterSystem").start_new_game(); gs.switch_to_role("A",3,true); gs.current_minute=630
	var produce: Texture2D=load("res://art/user_scenes/produce_stall_supplied.jpg")
	var cutout:=Cutout.cutout(produce,false,Composition.PRODUCE_PAPER_OPENINGS)
	var pixels:=cutout.get_image()
	check(pixels.get_pixel(0,0).a==0 and pixels.get_pixel(700,400).a==0,"Produce sky and enclosed stall opening are transparent")
	check(pixels.get_pixel(610,180).a>.99,"Orange canopy remains opaque")
	check(pixels.get_pixel(550,180).a>.99,"White canopy stripe remains opaque")
	check(pixels.get_pixel(400,370).a>.99,"Welcome sign remains opaque")
	for place in ["handcraft_shop","produce_stall","cafe"]:
		var canvas: Vector2=Composition.POST_OFFICE_CANVAS if place=="handcraft_shop" else Composition.PRODUCE_CANVAS if place=="produce_stall" else Composition.GROCERY_CANVAS
		var rect:=Composition.cutout_rect(place,canvas,800)
		check(absf(rect.position.y+Composition.CUTOUTS[place].ground*rect.size.y/canvas.y-Composition.CURB)<.01,"Authored ground aligns: "+place)
		await arrive(place); await shot(place)
		if place=="handcraft_shop":
			var door=current_scene.street.hotspots.filter(func(item): return item.kind=="door" and item.id=="letter_office")
			check(door.size()==1 and absf(door[0].x-current_scene.street.player_x)<.01,"Postal entrance follows the painted left door")
			current_scene._interact(); await settle()
			check(router.active_space_id=="letter_office","Painted postal entrance opens existing letter office")
		elif place=="cafe":
			current_scene._interact(); await settle()
			check(router.active_space_id.is_empty() and current_scene.event_overlay.visible,"Grocery opens counter conversation without an invented interior")
			current_scene.event_panel.find_child("Grocery_shop",true,false).pressed.emit(); await settle()
			check(is_instance_valid(current_scene.pocket_panel) and current_scene.pocket_panel.checkout_button.visible,"Grocery keeps direct checkout")
		else:
			var point=current_scene.street.hotspots.filter(func(item): return item.kind=="shop" and item.id=="produce_stall")[0]
			current_scene.street.player_x=point.x; current_scene._interact(); await settle()
			check(is_instance_valid(current_scene.pocket_panel) and current_scene.pocket_panel.checkout_button.visible,"Produce keeps working purchase entry and direct checkout")
	print("SUPPLIED_FRONTAGES: ",checks," checks / ",failures," failures")
	if OS.get_cmdline_user_args().has("--keep-open") and failures==0:
		await arrive("handcraft_shop")
		current_scene.set_process(true)
	else: quit(failures)
