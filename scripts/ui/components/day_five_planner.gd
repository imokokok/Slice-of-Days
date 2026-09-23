extends Control
const PALETTE=preload("res://scripts/ui/components/interface_palette.gd")
var status: Label
func _ready() -> void: name="DayFivePlanner"; rebuild()
func rebuild() -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	var revealed := CharacterSystem.switch_unlocked()
	PALETTE.words(self,"今天余下的时间" if revealed else "今天的时间",Vector2.ZERO,1120,32,PALETTE.INK)
	PALETTE.words(self,"第 %d 天 · %s"%[GameState.current_day,GameState.clock_text()],Vector2(0,48),1120,22,PALETTE.MUTED)
	var roles: Array=["A","B"] if revealed else [GameState.current_role]
	for i in roles.size():
		var role: String=roles[i]
		var x := float(i)*580
		PALETTE.words(self,(role+" · " if revealed else "")+("可以重组的空档" if role=="A" else "已留好的整块时间"),Vector2(x,94),540,26,PALETTE.INK)
		var blocks: Array=GameState.schedule_for(role,GameState.current_day).get("blocks",[])
		for j in blocks.size():
			var span: Array=blocks[j]
			var past := int(span[1])<=GameState.current_minute
			var active := GameState.current_minute>=int(span[0]) and not past
			PALETTE.words(self,GuidanceSystem.time_text(int(span[0]))+" — "+GuidanceSystem.time_text(int(span[1]))+(" · 已过" if past else " · 现在" if active else ""),Vector2(x,140+j*38),540,21,PALETTE.MUTED if past else PALETTE.INK)
		if role=="B": PALETTE.words(self,"今天是已排好的轮休日。\n这段完整时间可以留给自己的创作。" if GameState.current_day==5 else "14:00—18:00 饭店固定班次\n去出餐口旁开始，错过不结算本班收入。",Vector2(x,255),540,20,PALETTE.MUTED)
		if revealed:
			var button := _button("正在使用 "+role if role==GameState.current_role else "以 "+role+" 继续",Vector2(x,350),Vector2(530,48),func():
				if CharacterSystem.switch_character(): rebuild()
				else: status.text="先收起正在操作的物件。")
			button.disabled=role==GameState.current_role; button.name="Choose_"+role
	status=PALETTE.words(self,GameState.current_time_guidance(),Vector2(0,414),1120,21,PALETTE.INK)
	var preview := GameState.flexible_merge_preview()
	if not preview.is_empty():
		var join := _button("合并相邻空档",Vector2(0,477),Vector2(450,49),func():
			var confirm := preload("res://scripts/ui/components/confirm_sheet.gd").new(); confirm.heading="给这一件事多留一点时间"; confirm.description="把 %s 的 %d 分钟私人整理延到 %s。\n总空闲时间不增加，暂时让下一件事等一等。"%[GuidanceSystem.time_text(int(preview.start)),int(preview.gap),GuidanceSystem.time_text(int(preview.moved_to))]; confirm.confirm_text="调整私人安排"; add_child(confirm)
			confirm.accepted.connect(func():
				if GameState.combine_flexible_time(): confirm.queue_free(); rebuild()
				else: confirm.busy=false))
		join.name="CombineFlexibleTime"
	var next := CharacterSystem.next_window(GameState.current_role)
	var wait := _button("等到 "+GuidanceSystem.time_text(next)+" 的下一段空闲" if next>=0 else "今天没有更晚的空闲时段",Vector2(0,541),Vector2(550,49),func():
		var confirm := preload("res://scripts/ui/components/confirm_sheet.gd").new(); confirm.heading="等一会儿"; confirm.description="从 %s 等到 %s，共 %d 分钟。"%[GameState.clock_text(),GuidanceSystem.time_text(next),next-GameState.current_minute]+("\n跨过已答应的饭店班次会记为缺席，没有这班收入。" if GameState.current_role=="B" and next>=1080 and GameState.current_minute<1080 else ""); confirm.confirm_text="等待"; add_child(confirm)
		confirm.accepted.connect(func():
			confirm.queue_free()
			if CharacterSystem.wait_for_window(): rebuild()
			else: status.text="等待暂时未能保存，可以再试一次。"))
	wait.disabled=next<0; wait.name="WaitForWindow"
	PALETTE.words(self,"23:59 前到家 · 00:00 换日",Vector2(595,548),535,20,PALETTE.MUTED)
func _button(text: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var result := preload("res://scripts/ui/components/solmere_button.gd").new(); result.text=LocalizationSystem.text(text); result.position=at; result.size=dimensions; add_child(result); result.pressed.connect(action); return result
