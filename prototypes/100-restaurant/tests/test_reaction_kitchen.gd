extends SceneTree
var game
var checks := 0
var failures: Array[String] = []
const Thermal = preload("res://modules/restaurant/domain/food_thermal.gd")
func _initialize() -> void:
	root.size=Vector2i(1440,851)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	call_deferred("run")
func run() -> void:
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://reaction_qa_%s/book.json"%Crypto.new().generate_random_bytes(16).hex_encode(),"shift_seconds":900.0})
	root.add_child(game)
	await process_frame
	game._start_shift()
	var world=game.world
	world.audio.muted=true
	world.spawn_ingredient(game._definition("tofu"))
	var tofu: RigidBody2D=world._held
	world.drop_into_pan()
	await create_timer(0.9).timeout
	expect(tofu.get_meta("enrolled",false),"real falling ingredient reaches pan and session")
	game.set_process(false)
	world.reactions.set_physics_process(false)
	tofu.freeze=true
	tofu.position=world.pan.point(Vector2(790,580))
	var sauce := portion("ketchup",15.0,Vector2(790,580))
	var total := tofu.mass+sauce.mass
	var before_volume := float(sauce.get_meta("liquid_state").volume_ml)
	expect(world.reactions.coat(sauce,tofu,4.0)==4.0,"ketchup physically transfers onto food")
	expect(absf(tofu.mass+sauce.mass-total)<0.000001,"coating transfer conserves combined rigid-body mass")
	expect(absf(float(sauce.get_meta("liquid_state").volume_ml)+float(tofu.get_meta("surface_sauce").volume_ml)-before_volume)<0.000001,"coating transfer conserves volume")
	expect(tofu.get_node("FoodArt").coating.composition_ml.ketchup==4.0,"renderer receives actual local ketchup coverage")
	var tiny:=portion("oil",0.25,Vector2(790,580))
	var tiny_id:=tiny.get_instance_id()
	world.reactions.coat(tiny,tofu,0.25)
	var phantom:=false
	for entry in game.session.dish:
		if int(entry.get("physics_id",0))==tiny_id: phantom=true
	expect(tiny.is_queued_for_deletion() and not phantom,"fully absorbed condiment has no ghost portion in plating or recipe")
	var initial_spread := float(tofu.get_meta("surface_sauce").spread)
	world.reactions.stir(tofu,110.0,true)
	expect(float(tofu.get_meta("surface_sauce").spread)>initial_spread,"stirring spreads attached coating")
	expect(tofu.get_meta("thermal").contact_face==1,"upward stirring changes contacted face")
	var soy := portion("soy_sauce",8.0,Vector2(790,580))
	world.reactions.coat(soy,tofu,2.0)
	var appearance := preload("res://modules/restaurant/assets/cooking_appearance.gd").surface(game._definition("tofu"),0,tofu.get_meta("thermal"),tofu.get_meta("surface_sauce"))
	expect(appearance.film_thin>0.0 and appearance.film_color.r>appearance.film_color.b,"soy contributes a thin brown stain to the red coating")
	world.set_cooking(true)
	world.reactions.advance(25.0)
	expect(world.reactions.pan_c>100.0 and float(tofu.get_meta("thermal").core_c)>40.0,"burner heats pan then food core")
	var pan_hot: float=world.reactions.pan_c
	world.set_cooking(false)
	world.reactions.advance(1.0)
	expect(world.reactions.pan_c<pan_hot and world.reactions.pan_c>90,"switching off retains slowly cooling pan heat")
	var state: Dictionary=tofu.get_meta("thermal")
	state.faces_c=[135.0,120.0]
	expect(world.audio.cooking_profile(world)=="simmer_sauce","hot sauce keeps bubbling with burner off")
	await capture("sauce")
	# Actual scene has no second timer mutating water while reactions are paused.
	world.set_controls_enabled(false)
	var saved := state.duplicate(true)
	await create_timer(0.2).timeout
	expect(state==saved,"modal pause preserves all food thermal state")
	world.set_controls_enabled(true)
	tofu.freeze=true
	world.pan.water_ml=350.0
	world.pan.water_heat=22.0
	world.set_cooking(true)
	world.set_heat_level("high")
	world.reactions.advance(65.0)
	expect(world.pan.water_heat>90.0,"water heats according to pan heat exchange")
	expect(world.pan.water_ml<350.0 and world.reactions.evaporated_water_ml>0.0,"boiling removes finite water into steam ledger")
	var snapshot: Dictionary=world.describe_body(tofu)
	snapshot.id="tofu"
	expect(snapshot.has("thermal") and snapshot.surface_sauce.composition_ml.ketchup>0,"snapshot preserves phase history and sauce composition")
	var book_path: String="user://reaction_snapshot_%s/book.json"%Crypto.new().generate_random_bytes(16).hex_encode()
	var repository=preload("res://modules/restaurant/storage/recipe_repository.gd").new(book_path)
	var validation: Dictionary=repository._validate_dish({"ingredients":[snapshot]},false)
	expect(validation.ok,"new thermal state is accepted by recipe storage: "+str(validation.get("error","")))
	var malformed: Dictionary=snapshot.duplicate(true)
	malformed.thermal.faces_c=[100.0]
	expect(not repository._validate_dish({"ingredients":[malformed]},false).ok,"shared recipe rejects malformed temperature arrays before rendering")
	malformed=snapshot.duplicate(true)
	malformed.surface_sauce.origin="bad"
	expect(not repository._validate_dish({"ingredients":[malformed]},false).ok,"shared recipe rejects invalid coating coordinates")
	var canvas=preload("res://modules/restaurant/ui/poster_canvas.gd").new()
	root.add_child(canvas)
	var sticker: Dictionary=snapshot.duplicate(true)
	sticker.id="tofu"
	canvas.add_ingredient(sticker)
	expect(canvas.stickers.size()==1 and canvas.stickers[0].surface_sauce==snapshot.surface_sauce,"DIY ingredient carries actual sauce composition")
	expect(not canvas.stickers.is_empty() and canvas.validate_sticker(canvas.stickers[0]) and canvas._layer_nodes[0].get_child(0).thermal==snapshot.thermal,"editable DIY layer preserves thermal state and validates for reload")
	var recipe: Dictionary={"title":"热锅试验","author":"QA","notes":"实际着色食物","dish":{"ingredients":[snapshot]},"poster":canvas.export_data()}
	var saved_ok: bool=repository.save_recipe(recipe)
	expect(saved_ok,"coated food and editable collage save to disk: "+repository.last_error)
	if saved_ok:
		var reopened=preload("res://modules/restaurant/storage/recipe_repository.gd").new(book_path)
		var loaded: Array=reopened.load_recipes()
		expect(loaded.size()==1 and absf(float(loaded[0].dish.ingredients[0].thermal.core_c)-float(snapshot.thermal.core_c))<0.000001 and absf(float(loaded[0].poster.stickers[0].surface_sauce.composition_ml.ketchup)-float(snapshot.surface_sauce.composition_ml.ketchup))<0.000001,"disk reload retains the cooked and coated ingredient in both dish and DIY")
	canvas.queue_free()
	# Cooking/wet operation preserves existing char instead of resetting it.
	state.char=[0.4,0.1]
	world.reactions.advance(1.0)
	expect(float(state.char[0])>=0.4,"adding water cannot erase prior scorching")
	game._show_plating()
	await process_frame
	game._plating_canvas.add_to_plate(tofu)
	await process_frame
	var clone=game._plating_canvas._visuals[tofu.get_instance_id()].art
	expect(clone.thermal.char[0]>=0.4 and clone.coating.composition_ml.ketchup>0,"plating clone retains visible thermal and coating state")
	await capture("plated")
	game._close_modal()
	world._pickup(tofu)
	tofu.position=world.cutting_board.rect().get_center()
	world.drop_held()
	tofu.position=world.cutting_board.rect().get_center()
	tofu.freeze=true
	var native: Dictionary=tofu.get_meta("thermal").duplicate(true)
	var coated_volume: float=tofu.get_meta("surface_sauce").volume_ml
	var pieces: Array=world.split_food(tofu)
	expect(pieces.size()==2,"cooked coated food can still be cut")
	var liquid_total:=0.0
	var native_total:=0.0
	for piece in pieces:
		liquid_total+=float(piece.get_meta("surface_sauce").volume_ml)
		native_total+=float(piece.get_meta("thermal").initial_kg)
		expect(piece.get_meta("thermal").char==native.char,"cut pieces inherit face heat history")
	expect(absf(liquid_total-coated_volume)<0.000001 and absf(native_total-float(native.initial_kg))<0.000001,"cutting partitions sauce and native state without duplication")
	world.clear_workspace()
	await process_frame
	var butter:=food("butter",Vector2(775,580))
	var bread:=food("bread",Vector2(799,580))
	world.pan.water_ml=0
	world.set_cooking(true)
	var startmass:=butter.mass+bread.mass
	world.reactions.advance(40.0)
	var bs: Dictionary=butter.get_meta("thermal")
	expect(float(bs.liquid_kg)>0.01,"butter becomes a finite fat phase in the actual pan")
	expect(float(bread.get_meta("surface_sauce",{}).get("composition_ml",{}).get("butter",0.0))>0,"melted butter wets neighboring food")
	var vapour: float=float(bs.evaporated_kg)+float(bread.get_meta("thermal").evaporated_kg)
	expect(absf(butter.mass+bread.mass+vapour-startmass)<0.00001,"melting plus coating plus evaporation conserve mass")
	await capture("butter")
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: reaction kitchen, %d checks"%["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
func food(id: String,p: Vector2) -> RigidBody2D:
	var w=game.world
	w.spawn_ingredient(game._definition(id))
	var body: RigidBody2D=w._held
	body.position=w.pan.point(p)
	w.drop_held()
	body.position=w.pan.point(p)
	body.freeze=true
	game._food_entered(id,false,body)
	return body
func portion(id: String,ml: float,p: Vector2) -> RigidBody2D:
	var w=game.world
	w.spawn_ingredient(game._definition(id))
	var body: RigidBody2D=w._dispense_seasoning(ml)
	w.discard_held()
	body.position=w.pan.point(p)
	body.freeze=true
	game._food_entered(id,false,body)
	return body
func capture(label: String) -> void:
	var args:=OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name()=="headless": return
	game._update_hud()
	await process_frame
	if label=="butter":
		for body in game.world._foods.get_children():
			expect(game.world.pan.contains(body.position),"GPU phase fixture remains in pan after deferred transforms")
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(args[0]+"-"+label+".png")==OK,"GPU snapshot saved: "+label)
func expect(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
