extends Control
const PALETTE=preload("res://scripts/ui/components/interface_palette.gd")
var status: Label
var tab := "me"
var notice := ""
var cards: Array=[]
var selection: OptionButton
var transport: OptionButton
var hour: SpinBox
var minute: SpinBox

func _ready() -> void:
	name="DayFivePlanner"
	if CharacterSystem.switch_unlocked(): tab="plan"
	rebuild()

func rebuild() -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	PALETTE.words(self,"随身本 · 今天的我",Vector2.ZERO,1115,30,PALETTE.INK)
	PALETTE.words(self,"第 %d 天  /  %s     可支配 %d 元 · 今日收入 %d 元"%[GameState.current_day,GameState.clock_text(),GameState.money,LifeSystem.today_income()],Vector2(0,46),1120,20,PALETTE.MUTED)
	var tabs := [["me","今天的我"],["plan","安排一天"],["work","工作与收入"],["people","人物页"]]
	for i in tabs.size():
		var key := str(tabs[i][0])
		var b := _button(str(tabs[i][1]),Vector2(i*205,86),Vector2(193,43),func(): tab=key; notice=""; rebuild())
		b.name="LifeTab_"+key; b.disabled=tab==key
	status=PALETTE.words(self,notice if not notice.is_empty() else "写下计划后，要亲自去做。旧安排和实际经历都会留在这里。",Vector2(0,547),1120,20,PALETTE.MUTED)
	match tab:
		"me": _me()
		"plan": _plans()
		"work": _work()
		"people": _people()

func _me() -> void:
	var left := _scroll(Vector2(0,154),Vector2(520,368))
	for row in LifeSystem.describe(): _words(left,str(row.label),25); _words(left,str(row.text),21); _spacer(left,14)
	var right := _scroll(Vector2(565,154),Vector2(545,368))
	_words(right,"给自己留一点时间",25)
	_words(right,"休息、吃饭和整理思绪都在家里进行，会花掉真实的时间。食物需要先带回家。",21)
	for item in [["rest","在家歇一会儿 · 30分钟"],["meal","坐下来吃点东西 · 20分钟"],["quiet","安静整理思绪 · 20分钟"]]:
		var id := str(item[0]); _row_button(right,str(item[1]),func(): _result(LifeSystem.everyday(id))).name="LifeAction_"+id
	var history: Array=LifeSystem.state().history
	if not history.is_empty():
		_spacer(right,12); _words(right,"最近留下的感觉",23)
		for i in range(maxi(0,history.size()-5),history.size()): _words(right,"%s  %s"%[GuidanceSystem.time_text(int(history[i].minute)),str(history[i].text)],20)

func _plans() -> void:
	var left := _scroll(Vector2(0,154),Vector2(520,368))
	_words(left,"安排自己的时间",25)
	var preview := GameState.flexible_merge_preview()
	if not preview.is_empty():
		_words(left,"私人整理可以推迟，总空闲时间不会增加。反复重排会让思绪更乱。",20)
		_row_button(left,"合并相邻空档",func():
			notice="重新安排好了。" if GameState.combine_flexible_time() else "当前不能调整，先收好手头的活动。"; rebuild()).name="CombineFlexibleTime"
	var next := CharacterSystem.next_window(GameState.current_role)
	if next>=0:
		_row_button(left,"等到 %s · %d分钟"%[GuidanceSystem.time_text(next),next-GameState.current_minute],func():
			var sheet := preload("res://scripts/ui/components/confirm_sheet.gd").new(); sheet.heading="让这段时间过去？"; sheet.description="等待会消耗时间。跨过工作或已经答应的安排会留下缺席记录。"; sheet.confirm_text="等一会儿"; add_child(sheet)
			sheet.accepted.connect(func():
				sheet.queue_free()
				notice="等待结束。" if CharacterSystem.wait_for_window() else "先收起手头的工具，再等待。"
				rebuild())).name="WaitForWindow"
	for shift in GameState.commitments_for_day(): _words(left,"固定 · %s—%s %s"%[GuidanceSystem.time_text(int(shift.start)),GuidanceSystem.time_text(int(shift.end)),shift.label],21)
	for appointment in GameState.appointments:
		if int(appointment.get("day",0))==GameState.current_day: _words(left,"约定 · %s—%s %s · %s"%[GuidanceSystem.time_text(int(appointment.get("start",0))),GuidanceSystem.time_text(int(appointment.get("end",0))),str(appointment.get("label","")),str(appointment.get("status",""))],20)
	_words(left,"今天留出的空档",23)
	for span in GameState.active_time_blocks(): _words(left,"%s — %s%s"%[GuidanceSystem.time_text(int(span[0])),GuidanceSystem.time_text(int(span[1]))," · 已过" if int(span[1])<=GameState.current_minute else ""],20)
	if CharacterSystem.switch_unlocked():
		for role in ["A","B"]:
			var b := _row_button(left,"正在使用 "+role if role==GameState.current_role else "以 "+role+" 继续",func():
				if CharacterSystem.switch_character(): rebuild())
			b.disabled=role==GameState.current_role; b.name="Choose_"+role
	var right := _scroll(Vector2(565,154),Vector2(545,368))
	_words(right,"把听说的事写下来",25)
	cards=LifeSystem.known_cards()
	selection=OptionButton.new(); selection.custom_minimum_size=Vector2(510,43); selection.name="PlanActivity"
	for card in cards: selection.add_item(str(card.title)+" · %d分钟"%int(card.minutes))
	right.add_child(selection)
	var time_row := HBoxContainer.new(); right.add_child(time_row)
	hour=SpinBox.new(); hour.min_value=0; hour.max_value=23; hour.value=GameState.current_minute/60; hour.custom_minimum_size=Vector2(105,42); hour.name="PlanHour"; time_row.add_child(hour)
	var colon := Label.new(); colon.text=":"; time_row.add_child(colon)
	minute=SpinBox.new(); minute.min_value=0; minute.max_value=59; minute.value=GameState.current_minute%60; minute.custom_minimum_size=Vector2(105,42); minute.name="PlanMinute"; time_row.add_child(minute)
	transport=OptionButton.new(); transport.custom_minimum_size=Vector2(170,42); transport.name="PlanTransport"
	for label in ["步行 · 免费","公交 · 车费","出租车 · 更快"]: transport.add_item(label)
	time_row.add_child(transport)
	_row_button(right,"写进今天的日程",func():
		if selection.selected>=0: _result(LifeSystem.add_plan(str(cards[selection.selected].id),int(hour.value)*60+int(minute.value),["walk","bus","taxi"][transport.selected]))).name="AddPlan"
	_words(right,"交通是出门时的打算；写进本子不会自动抵达。出发前在地图确认路程和车费。",18)
	var found := false
	for row: Dictionary in LifeSystem.state().plans:
		if int(row.day)!=GameState.current_day: continue
		found=true
		var prefix: String={"planned":"待做","done":"已做","cancelled":"划掉","missed":"错过"}.get(str(row.status),"")
		var title := "%s %s—%s  %s"%[prefix,GuidanceSystem.time_text(int(row.start)),GuidanceSystem.time_text(int(row.end)),row.title]
		if str(row.status)=="cancelled":
			var crossed := RichTextLabel.new(); crossed.bbcode_enabled=true; crossed.fit_content=true; crossed.text="[s]"+title+"[/s]"; crossed.custom_minimum_size=Vector2(490,40); right.add_child(crossed)
		else: _words(right,title,21)
		if str(row.status)=="planned":
			_row_button(right,"按记下的交通方式出发",func():
				var quote := LifeSystem.departure_quote(str(row.id))
				if not bool(quote.ok): _result(quote); return
				var sheet := preload("res://scripts/ui/components/confirm_sheet.gd").new(); sheet.heading="现在出发？"; sheet.description=str(quote.message); sheet.confirm_text="出发"; add_child(sheet)
				sheet.accepted.connect(func(): sheet.queue_free(); _result(LifeSystem.depart(str(row.id)))))
			_row_button(right,"划掉这条安排",func(): _result(LifeSystem.cancel_plan(str(row.id))))
		if LifeSystem.value("clarity")<35 and str(row.status)=="planned": _words(right,"再看一遍："+str(row.title)+"，别忘了路上的时间。",18)
	if not found: _words(right,"这页还没有安排。",20)

func _work() -> void:
	var left := _scroll(Vector2(0,154),Vector2(520,368))
	_words(left,"今天的账",25); _words(left,"可支配 %d 元\n今日收入 %d 元"%[GameState.money,LifeSystem.today_income()],23)
	for row in GameState.money_ledger:
		if int(row.day)==GameState.current_day: _words(left,"%s  %+d 元 · %s"%[GuidanceSystem.time_text(int(row.minute)),int(row.amount),str(row.reason)],20)
	var right := _scroll(Vector2(565,154),Vector2(545,368))
	if GameState.current_role=="A":
		_words(right,"今天的开销，也会影响之后几天。",25); _words(right,"目前没有固定工资。先看需要留给吃饭和出行的钱，再决定要不要买想要的东西。",22); return
	_words(right,"饭店的固定班次",25)
	for shift in GameState.commitments_for_day(): _words(right,"%s—%s · 完整班次 %d 元"%[GuidanceSystem.time_text(int(shift.start)),GuidanceSystem.time_text(int(shift.end)),int(shift.pay)],22)
	_words(right,"到饭店开始实际备料和出餐后才结工资。迟到和早退按工作分钟结算；请假没有这班工资。",21)
	_row_button(right,"开始工作 · 做完剩余班次",func(): _result(LifeSystem.start_shift())).name="StartFullShift"
	_row_button(right,"和店主说好 · 工作90分钟后早退",func(): _result(LifeSystem.start_shift(true))).name="StartShortShift"
	_row_button(right,"今天请假 · 放弃这班工资",func(): _confirm_shift("leave")).name="LeaveShift"
	_row_button(right,"申请换班 · 占用下一工作日的上午",func(): _confirm_shift("swap")).name="SwapShift"
	for key in GameState.shared_state.get("life_shift_moves",{}):
		var move: Dictionary=GameState.shared_state.life_shift_moves[key]
		if move.has("added"): _words(right,"已换入：第%s天 09:00—13:00 饭店班次"%str(key).get_slice("_",1),20)

func _confirm_shift(action: String) -> void:
	var sheet := preload("res://scripts/ui/components/confirm_sheet.gd").new(); sheet.heading="调整这次班次"; sheet.description="请假会失去这班收入。" if action=="leave" else "换班需要实际合作建立的信任。今天不领这班工资，下次的上午要留给工作。"; sheet.confirm_text="确认请假" if action=="leave" else "申请换班"; add_child(sheet)
	sheet.accepted.connect(func(): sheet.queue_free(); _result(LifeSystem.adjust_shift(action)))

func _people() -> void:
	var rows := _scroll(Vector2(0,154),Vector2(1110,368))
	if CharacterSystem.switch_unlocked():
		_row_button(rows,"交换两个人记下的认识 · 经历和关系仍各自保留",func():
			var snapshot := GameState.to_save_data().duplicate(true); PeoplePuzzleSystem.exchange(); _result(LifeSystem.persist(snapshot,"已经交换人物页的认识。")))
	var seen: Array=GameState.encountered_residents.duplicate()
	if CharacterSystem.switch_unlocked():
		for id in GameState.shared_state.get("shared_people_facets",{}):
			if not seen.has(id): seen.append(id)
	for npc in seen: _words(rows,GuidanceSystem.source_name(str(npc)),26); _words(rows,PeoplePuzzleSystem.text_for(str(npc)),21); _spacer(rows,20)
	if seen.is_empty(): _words(rows,"还没认识镇上的人。先走近一个人，听听对方在做什么。",23)

func _result(result: Dictionary) -> void: notice=str(result.get("message","")); rebuild()

func _scroll(at: Vector2, dimensions: Vector2) -> VBoxContainer:
	var area := ScrollContainer.new(); area.position=at; area.size=dimensions; area.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(area)
	var rows := VBoxContainer.new(); rows.custom_minimum_size.x=dimensions.x-24; rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",9); area.add_child(rows); return rows

func _words(parent: Node, text: String, point: int) -> Label:
	var words := Label.new(); words.text=text; words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; words.add_theme_font_override("font",PaperLanguage.handwriting); words.add_theme_font_size_override("font_size",point); words.add_theme_color_override("font_color",PALETTE.INK); parent.add_child(words); return words

func _spacer(parent: Node, height: float) -> void:
	var c := Control.new(); c.custom_minimum_size.y=height; parent.add_child(c)

func _row_button(parent: Node, text: String, action: Callable) -> Button:
	var b := preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=text; b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; b.custom_minimum_size.y=47; parent.add_child(b); b.pressed.connect(action); return b

func _button(text: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var b := _row_button(self,text,action); b.position=at; b.size=dimensions; return b
