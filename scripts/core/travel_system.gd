extends Node

const LOCATION_ORDER := ["residence", "library", "cafe", "bus_stop", "park", "night_market", "tarot_stall"]


func route(from_id: String, to_id: String, method: String, role: String, minute: int) -> Dictionary:
	if from_id == to_id:
		return {"available": false, "reason": "已经在这里。"}
	var from_index := LOCATION_ORDER.find(from_id)
	var to_index := LOCATION_ORDER.find(to_id)
	if from_index < 0 or to_index < 0:
		return {"available": false, "reason": "未知路线。"}
	var distance: int = abs(to_index - from_index) + 1
	match method:
		"walk":
			return {"available": true, "minutes": 8 + distance * 7, "cost": 0, "label": "步行"}
		"bus":
			var wait := (15 - minute % 15) % 15
			return {"available": true, "minutes": 7 + distance * 3 + wait, "cost": 2, "label": "公交"}
		"taxi":
			return {"available": true, "minutes": 6 + distance * 2, "cost": 20, "label": "打车"}
		"friend":
			var available := role == "B" and minute >= 1140 and minute <= 1200
			return {
				"available": available,
				"minutes": 8 + distance * 2,
				"cost": 0,
				"label": "朋友顺路",
				"reason": "朋友只在19:00至20:00顺路。" if not available else "",
			}
	return {"available": false, "reason": "不支持的交通方式。"}


func travel(to_id: String, method: String) -> Dictionary:
	var option := route(GameState.current_location, to_id, method, GameState.current_role, GameState.current_minute)
	if not bool(option.get("available", false)):
		return {"ok": false, "message": str(option.get("reason", "当前无法使用。"))}
	var duration := int(option.get("minutes", 0))
	var cost := int(option.get("cost", 0))
	if not GameState.can_fit_now(duration):
		return {"ok": false, "message": "当前时间块放不下这段路程。"}
	if cost > 0 and not GameState.spend_money(cost):
		return {"ok": false, "message": "余额不足。"}
	GameState.spend_time(duration)
	GameState.current_location = to_id
	GameState.state_changed.emit()
	return {"ok": true, "message": "%s用了%d分钟，花费%d元。" % [str(option.get("label", "移动")), duration, cost]}
