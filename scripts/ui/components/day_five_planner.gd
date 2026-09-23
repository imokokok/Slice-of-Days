extends Control
const PALETTE=preload("res://scripts/ui/components/interface_palette.gd")
var status: Label
func _ready() -> void: name="DayFivePlanner"; rebuild()
func rebuild() -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	if not CharacterSystem.switch_unlocked():
		PALETTE.words(self,"今天的时间",Vector2.ZERO,1100,32,PALETTE.INK)
		PALETTE.words(self,"第 %d 天 · %s · %s" % [GameState.current_day,GameState.current_role,GameState.clock_text()],Vector2(0,58),1100,22,PALETTE.MUTED)
		var blocks: Array=GameState.schedule_for(GameState.current_role,GameState.current_day).get("blocks",[])
		for i in blocks.size():
			var span: Array=blocks[i]
			PALETTE.words(self,GuidanceSystem.time_text(int(span[0]))+" — "+GuidanceSystem.time_text(int(span[1]))+" · 今天的活动时间",Vector2(0,123+i*56),1000,24,PALETTE.INK)
		PALETTE.words(self,GameState.current_time_guidance(),Vector2(0,250),1060,23,PALETTE.INK)
		PALETTE.words(self,"23:59 前回家。午夜到来时，旅程进入下一天。",Vector2(0,325),1060,23,PALETTE.MUTED)
		PALETTE.words(self,"先过好今天。另一位主角的视角会随旅程展开；此时不能切换角色。",Vector2(0,437),1060,23,PALETTE.INK)
		return
	PALETTE.words(self,"今天余下的时间",Vector2(0,0),900,32,PALETTE.INK)
	PALETTE.words(self,"现在 "+GuidanceSystem.time_text(GameState.current_minute)+" · 切换视角共用同一个小镇时钟",Vector2(0,50),1100,21,PALETTE.MUTED)
	for i in 2:
		var role := "A" if i==0 else "B"
		var x := float(i)*580
		PALETTE.words(self,role+" · "+("连续的创作时间" if i==0 else "工作之间的空闲"),Vector2(x,110),540,27,PALETTE.INK)
		var blocks: Array=GameState.schedule_for(role,5).get("blocks",[])
		for j in blocks.size():
			var span: Array=blocks[j]
			var past := int(span[1])<=GameState.current_minute
			var active := GameState.current_minute>=int(span[0]) and not past
			var face := Panel.new(); face.position=Vector2(x,165+j*57); face.size=Vector2(520,47)
			face.add_theme_stylebox_override("panel",PALETTE.face(PALETTE.LEMON if active else Color("e1e8e8") if past else PALETTE.CREAM,5)); add_child(face)
			PALETTE.words(face,GuidanceSystem.time_text(int(span[0]))+" — "+GuidanceSystem.time_text(int(span[1]))+(" · 已经过了" if past else " · 现在可用" if active else " · 稍后"),Vector2(16,9),480,20,PALETTE.MUTED if past else PALETTE.INK)
		var b := preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=LocalizationSystem.text_with_values("正在使用 %s" if role==GameState.current_role else "以 %s 继续",[role]); b.position=Vector2(x,423); b.size=Vector2(520,54); add_child(b)
		b.disabled=role==GameState.current_role
		b.name="Choose_"+role
		b.pressed.connect(func():
			if CharacterSystem.switch_character(): rebuild()
			else: status.text=LocalizationSystem.text("请先收起正在操作的物件。"))
	status=PALETTE.words(self,"活动前会提示耗时；完整活动必须放得进当前空闲时段。",Vector2(0,494),1120,20,PALETTE.INK)
	var wait := preload("res://scripts/ui/components/solmere_button.gd").new(); wait.position=Vector2(0,544); wait.size=Vector2(550,52); add_child(wait)
	var next := CharacterSystem.next_window(GameState.current_role)
	wait.text=LocalizationSystem.text_with_values("等到 %s 的下一段空闲",[GuidanceSystem.time_text(next)]) if next>=0 else LocalizationSystem.text("今天没有更晚的空闲时段")
	wait.disabled=next<0
	wait.name="WaitForWindow"
	wait.pressed.connect(func():
		var confirm := preload("res://scripts/ui/components/confirm_sheet.gd").new(); confirm.heading="等一会儿"; confirm.description="时间将从 %s 走到 %s，共 %d 分钟。\n两个人共用的时间都会向前。"%[GuidanceSystem.time_text(GameState.current_minute),GuidanceSystem.time_text(next),next-GameState.current_minute]; confirm.confirm_text="等待"; add_child(confirm)
		confirm.accepted.connect(func():
			confirm.queue_free()
			if CharacterSystem.wait_for_window(): rebuild()))
