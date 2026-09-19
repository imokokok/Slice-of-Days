extends CanvasLayer
var clock := 0.0
var next_wave := 0.0
var next_comment := 0.0
var labels: Array[Label] = []
var pending: Array = []
var visit_key := ""
var was_eligible := false
var place_data: Dictionary = {}
var selected_ids: Array = []

func _ready() -> void:
	layer=10
	add_to_group("marginalia_layers")
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/world/locations.json")).locations: place_data[str(row.id)]=row
	var timer:=Timer.new()
	timer.wait_time=.2
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()

func stage_node() -> Control:
	var host=get_parent()
	return host.stage if str(host.get_script().resource_path).ends_with("interactive_space.gd") else host.street

func evaluate(stage: Control) -> Dictionary:
	var location:=GameState.current_location
	var row: Dictionary=place_data.get(location,{})
	var policy: Dictionary=MetaExperience.catalog.get("place_rules",{}).get(location,{})
	var business:=str(policy.get("type","public"))=="business"
	var hours: Array=row.get("hours",[])
	var open_now:=hours.is_empty() or hours.any(func(h: Array)->bool:return GameState.current_minute>=int(h[0]) and GameState.current_minute<int(h[1]))
	if location=="park": open_now=GameState.current_minute>=WorldGraph.LOOKOUT_OPEN
	var people:=0
	var major:=false
	for h in stage.hotspots:
		var dx:=absf(float(h.get("x",0))-stage.player_x)
		if dx>520: continue
		if str(h.get("kind","")) in ["person","npc","resident","shopkeeper","event","argument","invitation"]: people+=1
		if dx<110 and str(h.get("kind","")) in ["module","object","shop","invitation","argument","event"]: major=true
	var reason:=""
	if not MetaExperience.enabled("marginalia") or not bool(policy.get("enabled",true)): reason="地点未启用"
	elif SceneRouter.transitioning or MetaExperience.modal_open(): reason="界面或过场"
	elif not get_tree().get_nodes_in_group("meta_dialogue").is_empty(): reason="对话中"
	elif not stage.enabled: reason="互动或界面占用"
	elif people>0: reason="焦点区域有人"
	elif business and open_now: reason="正在营业"
	elif not business and major: reason="附近有主要互动"
	return {"location":location,"business":business,"open":open_now,"npcs":people,"eligible":reason.is_empty(),"reason":reason,"pool":MetaExperience.catalog.marginalia.get(location,[]).size(),"selected":selected_ids}

func _tick() -> void:
	clock+=.2
	var stage:=stage_node()
	if not is_instance_valid(stage): return
	var key:=GameState.current_location+"/"+SceneRouter.active_space_id
	if key!=visit_key:
		_clear()
		visit_key=key
		was_eligible=false
	var state:=evaluate(stage)
	MetaExperience.marginalia_debug=state
	if not state.eligible:
		_clear()
		was_eligible=false
		return
	if not was_eligible:
		was_eligible=true
		next_wave=clock+1.2
		MetaExperience.observe(GameState.current_location,"走到这里，停了一下")
	if clock>=next_wave and pending.is_empty():
		begin_burst()
		next_wave=clock+35
	if not pending.is_empty() and clock>=next_comment:
		labels=labels.filter(func(x: Label)->bool:return is_instance_valid(x) and not x.is_queued_for_deletion())
		if labels.size()<4:
			_show_comment(pending.pop_front(),stage)
			next_comment=clock+.8 if selected_ids.size()-pending.size()<3 else clock+1.4

func begin_burst() -> void:
	var location:=GameState.current_location
	var rows: Array=MetaExperience.catalog.marginalia.get(location,[])
	var history: Dictionary=GameState.shared_state.get("recent_marginalia",{})
	var recent: Array=history.get(location,[])
	var choices: Array=[]
	for i in rows.size():
		var row: Dictionary=rows[i] if rows[i] is Dictionary else {"id":location+"_"+str(i),"text":str(rows[i])}
		if not recent.has(str(row.id)): choices.append(row)
	if choices.size()<5:
		for i in rows.size():
			var row: Dictionary=rows[i] if rows[i] is Dictionary else {"id":location+"_"+str(i),"text":str(rows[i])}
			if not choices.has(row): choices.append(row)
	choices.shuffle()
	pending=choices.slice(0,mini(choices.size(),randi_range(5,9)))
	selected_ids=[]
	for row in pending:selected_ids.append(str(row.id))
	history[location]=selected_ids.duplicate()
	GameState.shared_state["recent_marginalia"]=history
	GameState.commit_active_role_state()
	SaveManager.save_or_report("地点短句记录保存失败")
	next_comment=clock

func _show_comment(row: Dictionary, stage: Control) -> void:
	var zones: Array=MetaExperience.catalog.get("marginalia_safe_zones",{}).get(GameState.current_location,[[70,115,410,105],[1110,115,410,105],[95,275,410,105],[1085,275,410,105],[585,115,410,105]])
	var chosen:=Rect2()
	for z in zones:
		var area:=Rect2(z[0],z[1],z[2],z[3])
		var clear:=true
		if area.intersects(Rect2(1120,20,460,270)): clear=false
		for label in labels:
			if is_instance_valid(label) and area.intersects(Rect2(label.position,label.size).grow(12)):clear=false
		for h in stage.hotspots:
			if str(h.get("kind","")) in ["person","shopkeeper","npc","resident"] and area.intersects(Rect2(float(h.x)-stage.camera_x-55,430,110,260)):clear=false
		if area.intersects(Rect2(stage.player_x-stage.camera_x-55,410,110,305)):clear=false
		if clear:chosen=area;break
	if not chosen.has_area():return
	var label:=Label.new()
	label.text=LocalizationSystem.text(str(row.get("byline","")))+"\n"+LocalizationSystem.text(str(row.text)) if row.has("byline") else LocalizationSystem.text(str(row.text))
	label.position=chosen.position
	label.size=chosen.size
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",19)
	label.add_theme_color_override("font_color",Color("eee3cc"))
	label.add_theme_color_override("font_shadow_color",Color("21383c"))
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.modulate.a=0
	add_child(label)
	labels.append(label)
	var tween:=create_tween().bind_node(label)
	label.set_meta("animation",tween)
	tween.tween_property(label,"modulate:a",.88,.35)
	tween.tween_interval(4.2)
	tween.tween_property(label,"modulate:a",0,.45)
	tween.tween_callback(func()->void:
		labels.erase(label)
		if is_instance_valid(label): label.queue_free())

func _clear() -> void:
	pending.clear()
	for label in labels:
		if not is_instance_valid(label) or label.has_meta("fading"):continue
		label.set_meta("fading",true)
		if label.has_meta("animation"): label.get_meta("animation").kill()
		var fade:=create_tween().bind_node(label)
		fade.tween_property(label,"modulate:a",0,.3)
		fade.tween_callback(label.queue_free)
	labels.clear()
