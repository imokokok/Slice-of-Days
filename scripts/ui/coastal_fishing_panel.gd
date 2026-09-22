extends Control
const FISH = preload("res://scripts/core/coastal_fishing.gd")
const ART = preload("res://scripts/ui/components/handmade_assets.gd")
const P = preload("res://scripts/ui/components/interface_palette.gd")
enum Phase { READY, WAITING, BITE, REELING, LANDED, ESCAPED }
var phase := Phase.READY
var timer := 0.0
var elapsed := 0.0
var progress := 0.0
var cursor := 0.0
var target := 0.56
var misses := 0
var fish: Dictionary={}
var cast_button: Button
var keep_button: Button
var release_button: Button
var status: Label
var guide: Label
var catch_art: TextureRect
var rod: TextureRect
var bobber: TextureRect
var sea_clock := 0.0
var anim: Tween
var ui: Control
var meter: Control
var sea_view: TextureRect
var journal: Control
func _ready() -> void:
	add_to_group("meta_modal"); theme=P.theme_for_tools()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	sea_view=TextureRect.new(); sea_view.name="OpenWater"
	sea_view.texture=preload("res://art/ui/handmade/fishing_sea.jpg")
	sea_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; sea_view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sea_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT); sea_view.mouse_filter=MOUSE_FILTER_IGNORE; add_child(sea_view)
	sea_view.modulate=preload("res://scripts/ui/street_composition.gd").daylight(GameState.current_minute)
	var caption := Panel.new(); caption.position=Vector2(54,43); caption.size=Vector2(420,62)
	caption.add_theme_stylebox_override("panel",P.face(P.CREAM,7,0)); caption.mouse_filter=MOUSE_FILTER_IGNORE; add_child(caption)
	P.words(self,("港湾" if GameState.current_location=="port" else "观景台下")+" · 海边钓位",Vector2(76,54),800,31,P.INK)
	rod=ART.picture(self,"rod_clean",Vector2(60,270),Vector2(600,397))
	bobber=ART.picture(self,"float",Vector2(855,510),Vector2(30,50))
	ui=Control.new(); add_child(ui)
	var reading := Panel.new(); reading.position=Vector2(600,563); reading.size=Vector2(900,276)
	reading.add_theme_stylebox_override("panel",P.face(P.CREAM,10,0)); reading.mouse_filter=MOUSE_FILTER_IGNORE; ui.add_child(reading)
	status=P.words(ui,"留一点时间给海。",Vector2(638,585),805,28)
	guide=P.words(ui,"每次抛竿用 10 分钟。浮漂下沉时提竿，再趁指针进入黄色区间收线。",Vector2(638,633),800,20,P.MUTED)
	cast_button=_button("抛竿 · 10 分钟",Vector2(635,748),Vector2(460,44),_act)
	_button("收竿 · "+SettingsSystem.binding_text("ui_cancel"),Vector2(1175,748),Vector2(279,44),_leave)
	keep_button=_button("带回厨房",Vector2(633,689),Vector2(370,50),func():_resolve(true))
	release_button=_button("放回海里",Vector2(1040,689),Vector2(370,50),func():_resolve(false))
	var relaxed := preload("res://scripts/ui/components/solmere_button.gd").new()
	relaxed.text="从容收线：开" if bool(FISH.state().relaxed) else "从容收线：关"
	relaxed.position=Vector2(1205,56); relaxed.size=Vector2(275,48); relaxed.variant="paper"; relaxed.toggle_mode=true
	relaxed.button_pressed=bool(FISH.state().relaxed); add_child(relaxed)
	relaxed.toggled.connect(func(value: bool):
		var previous: bool=FISH.state().relaxed; FISH.state().relaxed=value; GameState.commit_active_role_state()
		if not SaveManager.save_or_report("垂钓偏好保存失败"): FISH.state().relaxed=previous; relaxed.set_pressed_no_signal(previous); relaxed.selected=previous
		relaxed.text="从容收线：开" if bool(FISH.state().relaxed) else "从容收线：关"
	)
	meter=Control.new(); meter.mouse_filter=MOUSE_FILTER_IGNORE; meter.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(meter); meter.draw.connect(_draw_meter)
	if not FISH.state().pending.is_empty(): fish=FISH.state().pending.duplicate(true); phase=Phase.LANDED; _show_fish()
	_refresh(); cast_button.grab_focus()
	_button("鱼获与海边笔记",Vector2(76,140),Vector2(310,48),_open_journal).name="OpenFishJournal"
func _button(text: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new(); button.text=text; button.position=at; button.size=extent; button.pressed.connect(action); ui.add_child(button); return button
func _act() -> void:
	match phase:
		Phase.READY, Phase.ESCAPED:
			var result := FISH.begin_cast()
			if not result.ok: status.text=str(result.message); return
			fish=result.fish; phase=Phase.WAITING; timer=randf_range(3.0,6.0); progress=0; elapsed=0; misses=0
			status.text="浮漂轻轻晃着……"; guide.text="等它真正沉下去。可以随时收竿离开。"
			_rod_motion(-.045)
		Phase.WAITING:
			phase=Phase.ESCAPED; status.text="提得太早，水面安静下来。"; guide.text="看见浮漂下沉、听到提示，再提竿。"
		Phase.BITE:
			phase=Phase.REELING; elapsed=0; target=randf_range(.38,.72); status.text="咬住了，慢慢收线。"
			guide.text="指针进黄色区间时点收线。错过会松线；别急，可以等下一圈。"
			WorldSound.play_detail(true)
		Phase.REELING:
			var width: float=float(fish.window)*(1.55 if bool(FISH.state().relaxed) else 1.0)
			if absf(cursor-target)<width*.5:
				progress=minf(1,progress+.27); target=randf_range(.25,.75); status.text="线绷得刚刚好。"; _rod_motion(-.07); WorldSound.play_detail(true)
			else:
				progress=maxf(0,progress-.12); misses+=1; status.text="松一点，等下一圈。"
				if misses>=5 and not bool(FISH.state().relaxed): phase=Phase.ESCAPED; status.text="鱼挣脱了。"; guide.text="海里还有下一次相遇。"
			if progress>=1: _land()
	_refresh()
func _process(delta: float) -> void:
	if is_instance_valid(journal): return
	sea_clock+=delta
	if is_instance_valid(bobber):
		var y := 538.0 if phase==Phase.BITE else 510.0+sin(sea_clock*2.4)*3.0
		bobber.position.y=lerpf(bobber.position.y,y,minf(1,delta*9))
		bobber.modulate.a=.6 if phase==Phase.BITE else 1.0
		bobber.visible=phase!=Phase.LANDED
		if is_instance_valid(meter): meter.queue_redraw()
	if phase in [Phase.WAITING,Phase.BITE]:
		timer-=delta
		if timer<=0:
			if phase==Phase.WAITING:
				phase=Phase.BITE; timer=3.6 if bool(FISH.state().relaxed) else 2.4; status.text="浮漂沉下去了！"; guide.text="现在提竿。"; _rod_motion(-.1); WorldSound.play_detail(true)
			else: phase=Phase.ESCAPED; status.text="鱼游走了。"; guide.text="下次在浮漂沉下去时提竿。"
			_refresh()
	if phase==Phase.REELING:
		elapsed+=delta
		cursor=(sin(elapsed*TAU*float(fish.speed))+1)*.5
		progress=minf(1,progress+delta*(.038 if bool(FISH.state().relaxed) else .022))
		if progress>=1: _land()
		meter.queue_redraw()
func _land() -> void:
	phase=Phase.LANDED
	if FISH.land(fish): _show_fish()
	else:
		status.text="没能保存鱼获，点下方重试。"
		cast_button.text="重试保存鱼获"
	_refresh()
func _show_fish() -> void:
	if is_instance_valid(catch_art): catch_art.queue_free()
	catch_art=ART.picture(self,str(fish.id),Vector2(850,295),Vector2(450,220))
	var row := FISH.species(str(fish.id))
	status.text="%s · %.1f 厘米 · %s" % [row.get("name",fish.name),float(fish.length_cm),FISH.size_description(fish)]
	guide.text="常见 %.0f–%.0f 厘米。收下可做料理；放生同样留下观察记录。" % [float(row.get("common_min_cm",0)),float(row.get("common_max_cm",0))]
	keep_button.call_deferred("grab_focus")
func _resolve(keep: bool) -> void:
	if FISH.state().pending.is_empty():
		if not FISH.land(fish): status.text="还没能存好，请重试。"; return
	var result := FISH.resolve(keep)
	status.text=str(result.message)
	if result.ok:
		phase=Phase.READY; fish={}; guide.text="鱼获记录与随身包已经保存。"
		if is_instance_valid(catch_art): catch_art.queue_free()
	_refresh()
func _refresh() -> void:
	if is_instance_valid(bobber): bobber.visible=phase!=Phase.LANDED
	keep_button.visible=phase==Phase.LANDED; release_button.visible=phase==Phase.LANDED
	cast_button.visible=phase!=Phase.LANDED
	cast_button.text={Phase.READY:"抛竿 · 10 分钟",Phase.WAITING:"提竿（还没有咬钩）",Phase.BITE:"提竿！",Phase.REELING:"收线",Phase.ESCAPED:"再抛一竿 · 10 分钟"}.get(phase,"")
	if phase in [Phase.BITE,Phase.REELING]: cast_button.text+=" · "+SettingsSystem.binding_text("fishing_action")
	if is_instance_valid(meter): meter.queue_redraw()
func _rod_motion(angle: float) -> void:
	if SettingsSystem.reduced_motion(): return
	if anim: anim.kill()
	rod.pivot_offset=Vector2(30,370); anim=create_tween()
	anim.tween_property(rod,"rotation",angle,.15); anim.tween_property(rod,"rotation",0.0,.45)
func _draw_meter() -> void:
	if is_instance_valid(bobber) and bobber.visible:
		# Account for KEEP_ASPECT_CENTERED padding, so the line meets the rod.
		var ratio := minf(rod.size.x/rod.texture.get_width(),rod.size.y/rod.texture.get_height())
		var padding := (rod.size-rod.texture.get_size()*ratio)*.5
		var tip := rod.get_transform()*(padding+Vector2(817,30)*ratio)
		var end := bobber.position+Vector2(15,4)
		var points := PackedVector2Array()
		for step in 21:
			var t := step/20.0
			points.append(tip.lerp(end,t)+Vector2(sin(t*PI)*27,0))
		meter.draw_polyline(points,P.SEA,1.5,true)
		var ripple := PackedVector2Array()
		for step in 33:
			var angle := step*TAU/32
			ripple.append(bobber.position+Vector2(15,43)+Vector2(cos(angle)*(21+sin(sea_clock*2)*3),sin(angle)*5))
		meter.draw_polyline(ripple,Color(P.CREAM,.5),1.3,true)
	if phase!=Phase.REELING: return
	var width: float=float(fish.window)*(1.55 if bool(FISH.state().relaxed) else 1.0)
	var lane := Rect2(641,706,790,10)
	meter.draw_style_box(P.face(Color("c9d9dc"),7,0),lane)
	meter.draw_style_box(P.face(P.LEMON,5,0),Rect2(lane.position+Vector2((target-width*.5)*lane.size.x,0),Vector2(width*lane.size.x,14)))
	meter.draw_circle(Vector2(lane.position.x+cursor*lane.size.x,711),9,P.SEA)
	meter.draw_line(Vector2(642,730),Vector2(642+progress*790,730),P.SAGE,4,true)
func _leave() -> void:
	if phase==Phase.LANDED and FISH.state().pending.is_empty() and not FISH.land(fish):
		status.text="魚获还没能存好，请稍后收竿。"; return
	queue_free()
func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(journal): return
	if event.is_action_pressed("ui_cancel"): _leave(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fishing_action"):
		if phase!=Phase.LANDED: _act()
		get_viewport().set_input_as_handled()

func _open_journal() -> void:
	if is_instance_valid(journal): return
	journal=preload("res://scripts/ui/fish_journal.gd").new(); add_child(journal)
	journal.tree_exited.connect(func(): cast_button.grab_focus())
