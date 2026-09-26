extends SceneTree
const Layout=preload("res://scripts/ui/components/dialogue_layout.gd")
var failures := 0
var checks := 0
var state: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func capture(caption: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.runtime/dialogue-captures")
	root.get_texture().get_image().save_png("res://.runtime/dialogue-captures/"+caption+".png")
func contrast(ink: Color, background: Color) -> float:
	return (background.srgb_to_linear().get_luminance()+.05)/(ink.srgb_to_linear().get_luminance()+.05)
func key(action: String) -> void:
	var event := InputEventAction.new(); event.action=action; event.pressed=true
	root.push_input(event)
	event=InputEventAction.new(); event.action=action; event.pressed=false
	root.push_input(event)
func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	event.position=button.get_global_rect().get_center(); event.global_position=event.position
	root.push_input(event,true)
	event=event.duplicate(); event.pressed=false; root.push_input(event,true)
func verify_card(card: Panel, stage: Control, caption: String, scenery := true) -> void:
	var obstacles: Dictionary=stage.dialogue_obstacles()
	var face: Color=card.get_theme_stylebox("panel").bg_color
	check(face.a==1 and card.modulate.a==1 and card.content.modulate.a==1,caption+": solid surface throughout the transition")
	check(contrast(card.text_label.get_theme_color("font_color"),face)>=7,caption+":正文 contrast at least 7:1")
	check(contrast(card.hint_label.get_theme_color("font_color"),face)>=4.5,caption+": hint contrast at least 4.5:1")
	check(card.size.x<=420 and card.size.y<=300,caption+": compact measured speech, no menu-sized balloon")
	check(card.text_label.get_visible_line_count()==card.text_label.get_line_count(),caption+": every wrapped line is visible")
	for rect: Rect2 in card.reading_rects():
		check(root.get_visible_rect().grow(-24).encloses(rect),caption+": every reading surface stays in safe area")
		check(Layout.overlap(rect,obstacles.actors)==0,caption+": faces and bodies remain uncovered")
		if scenery: check(Layout.overlap(rect,obstacles.scenery)==0,caption+": building silhouette stays uncovered")
	if is_instance_valid(card.choices):
		check(not card.get_global_rect().intersects(card.choices.get_global_rect()),caption+": responses sit outside the compact speech surface")
		for button in card.choices.get_children():
			for state_name in ["normal","hover","pressed","disabled"]:
				var color: Color=button.get_theme_stylebox(state_name).bg_color
				check(color.a==1,caption+": response state has its own solid backing")
				var ink: Color=button.get_theme_color("font_color" if state_name=="normal" else "font_"+state_name+"_color")
				check(contrast(ink,color)>=4.5,caption+": every response state has readable contrast")
func town(location: String, minute:=630) -> void:
	state.begin_new_game("A"); state.current_location=location
	state.current_minute=minute; state.shared_state.typewriter=false
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.45).timeout
	current_scene.street.player_x=current_scene._world_x(current_scene.street_order.find(location),690)
	current_scene.street.move_player(0,0)
	current_scene._on_walk(current_scene.street.player_x)
	current_scene._refresh()
	await process_frame; await process_frame
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	state=root.get_node("GameState")
	# Geometric regressions: opposite edge speakers, long reply menus, resized windows.
	for width in [960,1280,1600]:
		var view := Rect2(0,0,width,900)
		for actor_x in [65.0,width*.5,width-65.0]:
			var actors := [Rect2(actor_x-55,600,110,240)]
			var buildings := [Rect2(width*.4,350,width*.35,370)]
			var at := Layout.place(view,Vector2(380,430),actors,buildings,Vector2(actor_x,660))
			check(view.encloses(at),"Safe-area bounds for every window width")
			check(Layout.overlap(at,actors)==0,"Never cover an actor at either edge")
			var still := Layout.place(view,at.size,actors,buildings,Vector2(actor_x+2,660),at)
			check(still.position==at.position,"Camera settling does not make the card jitter")
	await town("produce_stall")
	current_scene._talk_nearby("beetman")
	await create_timer(.3).timeout
	var panel=current_scene.conversation
	panel.speech_card.reveal()
	for frame in 8:
		check(panel.speech_card.modulate.a==1 and panel.speech_card.content.modulate.a==1,"Entrance frame remains opaque with readable ink")
		await create_timer(.02).timeout
	verify_card(panel.speech_card,current_scene.street,"Grocery line")
	check(panel.speech_card.get_global_rect().get_center().y>root.get_visible_rect().size.y*.48,"Grocery reading area uses the side of the street, not the roof")
	await capture("01-grocery-line")
	var position: Vector2=panel.speech_card.position
	panel._advance()
	check(panel.speaker_label.text==root.get_node("LocalizationSystem").text("你"),"Real speaker changes")
	check(panel.speech_card.position==position,"Speaker change keeps the same reading position")
	panel.typewriter=true; panel._show_line()
	var same_index: int=panel.index
	key("dialogue_advance")
	check(panel.index==same_index and panel.text_label.visible_characters==-1,"First advance reveals text without skipping a line")
	panel.typewriter=false
	for i in 80:
		if is_instance_valid(panel.vendor_choices):
			if panel.vendor_choices.get_child_count()==5: break
			panel.vendor_choices.get_child(panel.vendor_choices.get_child_count()-1).pressed.emit()
		else: panel._advance()
		await process_frame
	await create_timer(.25).timeout
	check(is_instance_valid(panel.vendor_choices) and panel.vendor_choices.get_child_count()==5,"All five real counter actions appear")
	verify_card(panel.speech_card,current_scene.street,"Grocery choices")
	check(panel.vendor_choices.get_global_rect().position.y>panel.speech_card.get_global_rect().end.y,"Counter reads line first, then responses below")
	await capture("02-grocery-choices")
	panel.vendor_choices.get_child(1).grab_focus()
	key("ui_accept"); await process_frame
	check(is_instance_valid(current_scene.pocket_panel),"Keyboard-selected shelf opens the actual shop")
	current_scene.pocket_panel.queue_free()
	await process_frame; await process_frame
	check(panel.visible and not panel.shopping,"Closing the actual shop resumes this conversation")
	click(panel.vendor_choices.get_child(2)); await process_frame; await process_frame
	var asks=get_nodes_in_group("meta_modal")
	var ask: Node
	for node in asks:
		if node.get_script().resource_path.ends_with("ask_panel.gd"): ask=node
	check(is_instance_valid(ask),"Mouse-selected question opens real topic choices")
	if is_instance_valid(ask):
		await create_timer(.2).timeout
		verify_card(ask.card,current_scene.street,"Question choices")
		await capture("03-questions")
		click(ask.card.choices.get_child(0)); await process_frame; await process_frame
		check(panel.starting_topic=="schedule_info" and not is_instance_valid(panel.vendor_choices),"Topic selection enters its actual reply")
	key("ui_cancel"); await process_frame; await process_frame
	check(not is_instance_valid(current_scene.conversation) and current_scene.street.enabled,"Esc immediately restores walking")
	await town("town_entrance",1080)
	current_scene._talk_nearby("wu_wu")
	await process_frame
	panel=current_scene.conversation
	for i in 30:
		if is_instance_valid(panel.vendor_choices): break
		panel._advance()
	await create_timer(.2).timeout
	check(is_instance_valid(panel.vendor_choices),"Cici encounter presents native branch choices")
	if is_instance_valid(panel.vendor_choices):
		verify_card(panel.speech_card,current_scene.street,"Cici choices")
		await capture("04-cici-choices")
		var disabled: Button=panel.vendor_choices.get_child(2)
		disabled.disabled=true
		click(disabled); await process_frame
		check(not panel.encounter_finished,"Disabled replies cannot execute a branch")
		click(panel.vendor_choices.get_child(1))
		await process_frame
		check(panel.text_label.text.contains("先把手放低"),"Choosing to pet the dog produces that branch")
	panel._close(); await process_frame; await process_frame
	await town("produce_stall")
	check(not root.get_node("DialogueSystem").argument_pending(),"Cancelled misunderstanding minigame is not a live encounter")
	# Room conversations use the same component and respect the larger silhouettes.
	root.get_node("SceneRouter").active_space_id="restaurant"
	state.current_location="night_market"
	state.current_minute=690
	change_scene_to_file("res://scenes/interactive_space.tscn")
	await create_timer(.5).timeout
	current_scene.stage.player_x=800
	current_scene._start_conversation("shi_yongqi")
	await create_timer(.3).timeout
	panel=current_scene.conversation
	verify_card(panel.speech_card,current_scene.stage,"Interior line")
	panel.text_label.text="这是一段用于检查换行的长对白。柜台上放着刚刚收到的信，还有今天要送出去的包裹。你愿意听我把这段故事讲完吗？"
	panel.speech_card.layout()
	await process_frame
	verify_card(panel.speech_card,current_scene.stage,"Long interior line")
	await capture("06-interior-long-line")
	key("ui_cancel"); await process_frame; await process_frame
	check(not is_instance_valid(current_scene.conversation) and current_scene.stage.enabled,"Indoor Esc restores walking")
	var settings=root.get_node("SettingsSystem")
	var motion_before: bool=settings.values.reduced_motion
	settings.values.reduced_motion=true
	current_scene._start_conversation("shi_yongqi")
	await process_frame
	check(current_scene.conversation.text_label.visible_characters==-1 and current_scene.conversation.speech_card.modulate.a==1,"Reduced motion shows the complete line without animation")
	current_scene.conversation._close()
	settings.values.reduced_motion=motion_before
	await town("park",1260)
	current_scene._talk_nearby("yuxingqing")
	await create_timer(.3).timeout
	verify_card(current_scene.conversation.speech_card,current_scene.street,"Night dialogue")
	await capture("07-night-line")
	current_scene.queue_free(); await process_frame
	print("DIALOGUE PRESENTATION checks=",checks," failures=",failures)
	quit(failures)
