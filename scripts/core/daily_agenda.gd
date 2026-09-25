extends RefCounted
## Read-only view of the current role's real reservations and completed actions.
const CLOSED := ["done", "missed", "cancelled"]

static func place_name(location: String) -> String:
	if location=="residence": return "家 · 海风路17号"
	var display := TravelSystem.location_name(location)
	return display if not location.is_empty() and display!=location else "地点待确认"

static func rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shift in GameState.commitments_for_day():
		var token := GameState._commitment_token(shift)
		var status := "planned"
		if GameState.completed_commitments.has(token):
			status = "missed" if GameState.journal_entries.any(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == "missed_commitment_" + token) else "done"
		elif str(LifeSystem.active_shift().get("token", "")) == token: status = "active"
		elif GameState.current_minute >= int(shift.end): status = "missed"
		var place := str(shift.get("location_label", TravelSystem.location_name(str(shift.get("location", "residence")))))
		result.append({"id":token, "kind":"固定", "start":int(shift.start), "end":int(shift.end), "title":str(shift.label), "location":str(shift.get("location", "residence")), "place":place, "status":status, "detail":"%s 前到%s。到店开始备料、做菜并出餐；完整班次收入 %d 元。" % [GuidanceSystem.time_text(int(shift.get("return_by", shift.start))), place, int(shift.get("pay",0))]})
	for appointment in GameState.appointments:
		if int(appointment.get("day",0)) != GameState.current_day: continue
		var status: String = {"scheduled":"planned", "active":"due", "completed":"done", "missed":"missed", "cancelled":"cancelled"}.get(str(appointment.get("status","scheduled")), "planned")
		var finish := int(appointment.get("end", int(appointment.get("start",0))+120))
		if status not in CLOSED and GameState.current_minute >= finish: status="missed"
		var location := str(appointment.get("location",""))
		result.append({"id":str(appointment.get("id","")), "kind":"约定", "start":int(appointment.get("start",0)), "end":finish, "title":str(appointment.get("label","约定")), "location":location, "place":place_name(location), "status":status, "detail":"在约定时段到场；只有实际赴约才算完成。"})
	for plan in LifeSystem.state().plans:
		if int(plan.day) != GameState.current_day: continue
		var status := str(plan.status)
		if status == "planned" and GameState.current_minute >= int(plan.end): status="missed"
		var travel: String = {"walk":"步行", "bus":"公交", "taxi":"出租车"}.get(str(plan.get("transport","walk")), "步行")
		result.append({"id":str(plan.id), "kind":"计划", "start":int(plan.start), "end":int(plan.end), "title":str(plan.title), "location":str(plan.location), "place":place_name(str(plan.location)), "status":status, "detail":"打算%s前往 · 活动 %d 分钟，另外留出路程。" % [travel, int(plan.end)-int(plan.start)]})
	result.append({"id":"home_deadline", "kind":"回家", "start":1439, "end":1440, "title":"回家，结束今天", "location":"residence", "place":"A、B 的家", "status":"planned", "detail":"23:59 前到家，00:00 进入下一天。"})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.start)<int(b.start))
	return result

static func next_row() -> Dictionary:
	for row in rows():
		if str(row.status) not in CLOSED and int(row.end)>GameState.current_minute: return row
	return {}

static func note_text(row: Dictionary) -> String:
	if str(row.id)=="home_deadline": return "23:59 前到家，00:00 就是下一天了。"
	if str(row.kind)=="计划" and str(row.location)=="residence": return "在家给自己留 %d 分钟。" % [int(row.end)-int(row.start)]
	match str(row.kind):
		"固定": return "提前到店，备料、做菜、出餐。"
		"约定": return "答应过的见面，记得准时到。"
		_: return str(row.detail)

static func todo_title(row: Dictionary) -> String:
	return "去%s上班" % str(row.place) if str(row.kind)=="固定" else str(row.title)

static func status_text(row: Dictionary) -> String:
	var status := str(row.status)
	if status=="planned" and GameState.current_minute>=int(row.start): return "现在该做"
	return {"planned":"待做", "due":"可以赴约", "active":"进行中", "done":"已完成", "missed":"已错过", "cancelled":"已取消"}.get(status,"待做")

static func free_windows() -> Array:
	var windows: Array = []
	for span in GameState.active_time_blocks():
		var start := maxi(GameState.current_minute,int(span[0]))
		var finish := mini(1439,int(span[1]))
		if start<finish: windows.append([start,finish])
	for row in rows():
		if str(row.status) in CLOSED: continue
		var remaining: Array=[]
		for span in windows:
			if int(row.start)>=int(span[1]) or int(row.end)<=int(span[0]): remaining.append(span); continue
			if int(span[0])<int(row.start): remaining.append([span[0],int(row.start)])
			if int(row.end)<int(span[1]): remaining.append([int(row.end),span[1]])
		windows=remaining
	return windows
