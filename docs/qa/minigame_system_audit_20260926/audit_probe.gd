extends SceneTree
var report: Array=[]
var gs
var modules
var life
func _initialize() -> void: call_deferred("run")
func record(id: String, data: Dictionary) -> void:
 data["id"]=id; report.append(data); print("AUDIT ",JSON.stringify(data))
func fresh(role: String, day: int, minute: int, place: String) -> void:
 root.get_node("ChapterSystem").start_new_game()
 gs.switch_to_role(role,day,true); gs.current_minute=minute; gs.current_location=place
 root.get_node("ChapterSystem").story().reveal_completed=day==5
 root.get_node("SceneRouter").active_space_id=""
func run() -> void:
 gs=root.get_node("GameState");modules=root.get_node("GameplayModuleSystem");life=root.get_node("LifeSystem")
 root.get_node("CoreLoopSystem").set_process(false);root.get_node("ChapterSystem").set_process(false)
 var dummy:=Control.new(); root.add_child(dummy); current_scene=dummy
 fresh("A",1,610,"record_store")
 root.get_node("CoreLoopSystem").encounter("xanni")
 var accepted: Dictionary=root.get_node("DialogueSystem").accept_invitation("xanni")
 record("known_activity_missing",{"accepted":not accepted.is_empty(),"known_lead":root.get_node("KnowledgeSystem").facts().any(func(f:Dictionary):return str(f.get("module",""))=="sound_sampling" or str(f.get("id",""))=="invite_sound_sampling"),"unlocked":modules.is_unlocked("sound_sampling"),"in_planner":life.known_cards().any(func(c:Dictionary):return str(c.id)=="sound_sampling")})
 fresh("B",5,1080,"record_store")
 modules.unlock("sound_sampling")
 record("music_duration",{"card_minutes":modules.required_minutes("sound_sampling"),"standard_gate":modules.entry_check("sound_sampling"),"delivery_gate":modules.entry_check("sound_sampling",60),"plan":life.add_plan("sound_sampling",1080,"walk")})
 fresh("A",5,1390,"print_shop")
 record("legacy_photo_business_hours",{"shop":root.get_node("WorldGraph").location_status("print_shop"),"module_gate":modules.entry_check("photography"),"mapped_location":root.get_node("WorldGraph").activity_location("photography")})
 fresh("B",2,600,"night_market")
 var began: bool=modules.begin_session("cooking","audit")
 var kitchen=load("res://scenes/native_module_game.tscn").instantiate();root.add_child(kitchen);await process_frame
 for id in ["bread","cheese","lemon"]: kitchen._toggle_token(id)
 preload("res://tests/integration/cooking_walkthrough.gd").prepare_and_cook(kitchen)
 kitchen._complete_choice("careful_menu")
 record("cooking_signature_bypass",{"began":began,"completed":kitchen.completed,"confirmed":gs.confirmed_residents.duplicate(),"facets":root.get_node("PeoplePuzzleSystem").page("shi_yongqi").facets.size(),"minute":gs.current_minute})
 kitchen.queue_free();await process_frame
 fresh("B",5,600,"print_shop")
 var clock=load("res://scripts/ui/clock_repair.gd").new();root.add_child(clock);await process_frame
 clock.hour_value=clock.target_hour;clock.minute_value=clock.target_minute
 var minute_before: int=gs.current_minute;var money_before: int=gs.money
 var body: float=life.value("body");var engagement: float=life.value("engagement")
 clock._submit()
 record("clock_no_time",{"before":minute_before,"after":gs.current_minute,"money_change":gs.money-money_before,"body_change":life.value("body")-body,"engagement_change":life.value("engagement")-engagement})
 clock.queue_free();await process_frame
 fresh("B",5,600,"port")
 body=life.value("body");engagement=life.value("engagement")
 var fish=load("res://scripts/core/coastal_fishing.gd")
 var cast: Dictionary=fish.begin_cast()
 if cast.ok:
  fish.land(cast.fish)
  fish.resolve(true)
 record("fishing_state",{"cast_ok":cast.ok,"minute":gs.current_minute,"body_change":life.value("body")-body,"engagement_change":life.value("engagement")-engagement,"in_planner":life.known_cards().any(func(c:Dictionary):return str(c.id)=="fishing")})
 fresh("B",5,600,"print_shop")
 clock=load("res://scripts/ui/clock_repair.gd").new();root.add_child(clock);await process_frame
 clock.hour_value=clock.target_hour;clock.minute_value=clock.target_minute
 var saves=root.get_node("SaveManager");var original=saves.get_script();var failure:=GDScript.new()
 failure.source_code="extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\treturn false\n"
 failure.reload();saves.set_script(failure);money_before=gs.money;clock._submit()
 record("clock_save_failure",{"money_change":gs.money-money_before,"paid_flag":clock._is_paid(),"visible_feedback":clock.status_label.text})
 saves.set_script(original);clock.queue_free();await process_frame
 fresh("A",5,690,"produce_stall")
 record("translation_disabled",{"argument_pending":root.get_node("DialogueSystem").argument_pending(),"module_available":root.get_node("ChapterSystem").module_available("translation"),"begin":modules.begin_session("translation","audit")})
 var f:=FileAccess.open("/private/tmp/solmere-minigame-audit-20260926/probe.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("AUDIT PROBE COMPLETE");quit()
