extends Node

signal module_unlocked(role: String, module_id: String)
signal module_started(role: String, module_id: String)
signal module_completed(role: String, module_id: String, outcome: Dictionary)

const MODULES_PATH := "res://data/gameplay/modules.json"
const PROTOTYPES_PATH := "res://data/gameplay/module_prototypes.json"

var modules: Dictionary = {}
var prototypes: Dictionary = {}


func _ready() -> void:
	load_module_data(MODULES_PATH)
	load_prototype_data(PROTOTYPES_PATH)


func load_module_data(path: String) -> void:
	modules.clear()
	if not FileAccess.file_exists(path):
		push_warning("Gameplay module data not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid gameplay module data: %s" % path)
		return
	for module in parsed.get("modules", []):
		var module_id := str(module.get("id", ""))
		if not module_id.is_empty():
			modules[module_id] = module


func load_prototype_data(path: String) -> void:
	prototypes.clear()
	if not FileAccess.file_exists(path):
		push_warning("Gameplay prototype data not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid gameplay prototype data: %s" % path)
		return
	for prototype in parsed.get("prototypes", []):
		var module_id := str(prototype.get("module_id", ""))
		if not module_id.is_empty():
			prototypes[module_id] = prototype


func ensure_state(module_id: String) -> Dictionary:
	if not modules.has(module_id):
		return {}
	if not GameState.module_states.has(module_id):
		var metadata: Dictionary = modules[module_id]
		GameState.module_states[module_id] = {
			"unlocked": bool(metadata.get("initially_unlocked", false)),
			"plays": 0,
			"completed": false,
			"outcomes": [],
			"last_day": 0,
		}
	return GameState.module_states[module_id]


func unlock(module_id: String) -> bool:
	var state := ensure_state(module_id)
	if state.is_empty():
		return false
	if not bool(state.get("unlocked", false)):
		state["unlocked"] = true
		GameState.module_states[module_id] = state
		GameState.commit_active_role_state()
		module_unlocked.emit(GameState.current_role, module_id)
		GameState.state_changed.emit()
	return true


func start(module_id: String) -> bool:
	var state := ensure_state(module_id)
	if state.is_empty() or not bool(state.get("unlocked", false)):
		return false
	state["plays"] = int(state.get("plays", 0)) + 1
	state["last_day"] = GameState.current_day
	GameState.module_states[module_id] = state
	GameState.commit_active_role_state()
	module_started.emit(GameState.current_role, module_id)
	return true


func complete(module_id: String, outcome: Dictionary = {}) -> bool:
	var state := ensure_state(module_id)
	if state.is_empty() or not bool(state.get("unlocked", false)):
		return false
	state["completed"] = true
	state["last_day"] = GameState.current_day
	var outcomes: Array = state.get("outcomes", [])
	var stored := outcome.duplicate(true)
	stored["day"] = int(stored.get("day", GameState.current_day))
	outcomes.append(stored)
	state["outcomes"] = outcomes
	GameState.module_states[module_id] = state
	GameState.commit_active_role_state()
	module_completed.emit(GameState.current_role, module_id, stored)
	GameState.state_changed.emit()
	return true


func is_unlocked(module_id: String) -> bool:
	return bool(ensure_state(module_id).get("unlocked", false))


func state_for(module_id: String) -> Dictionary:
	return ensure_state(module_id).duplicate(true)


func latest_outcome(module_id: String) -> Dictionary:
	var state: Dictionary = GameState.module_states.get(module_id, {})
	var outcomes: Array = state.get("outcomes", [])
	if outcomes.is_empty():
		return {}
	return (outcomes[-1] as Dictionary).duplicate(true)


func begin_session(module_id: String, source_event_id := "", rollback_snapshot: Dictionary = {}) -> bool:
	if module_id == "contemplation" and GameState.current_minute < WorldGraph.LOOKOUT_OPEN:
		return false
	if not unlock(module_id) or not start(module_id):
		return false
	GameState.shared_state["pending_module"] = {
		"module_id": module_id,
		"role": GameState.current_role,
		"day": GameState.current_day,
		"source_event_id": source_event_id,
		"rollback_snapshot": rollback_snapshot.duplicate(true),
	}
	GameState.commit_active_role_state()
	return true


func pending_module_id() -> String:
	var pending: Dictionary = GameState.shared_state.get("pending_module", {})
	if str(pending.get("role", "")) != GameState.current_role:
		return ""
	return str(pending.get("module_id", ""))


func cancel_session() -> void:
	var pending: Dictionary = GameState.shared_state.get("pending_module", {})
	var rollback_snapshot: Dictionary = pending.get("rollback_snapshot", {})
	if not rollback_snapshot.is_empty():
		GameState.load_save_data(rollback_snapshot)
		return
	GameState.shared_state.erase("pending_module")
	GameState.commit_active_role_state()


func prototype_for(module_id: String) -> Dictionary:
	return prototypes.get(module_id, {}).duplicate(true)


func choice_interaction_check(module_id: String, choice_id: String, interaction_record: Dictionary) -> Dictionary:
	if not prototypes.has(module_id):
		return {"ok": false, "message": "找不到这个玩法。"}
	var prototype: Dictionary = prototypes[module_id]
	var selected: Dictionary = {}
	for choice in prototype.get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			selected = choice
			break
	if selected.is_empty():
		return {"ok": false, "message": "找不到这个玩法选择。"}
	if module_id == "clock_setting":
		for outcome_value in GameState.module_states.get(module_id, {}).get("outcomes", []):
			var outcome: Dictionary = outcome_value
			if int(outcome.get("day", 0)) == GameState.current_day:
				return {"ok": false, "message": "今天已经校准过这座旧钟，20元校时费不能重复领取。"}
		var mechanic: Dictionary = interaction_record.get("mechanic", {})
		var target_minute := GameState.current_minute % 1440
		var target_hour := floori(float(target_minute) / 60.0) % 12
		if target_hour == 0:
			target_hour = 12
		if int(mechanic.get("clock_target_minute", -1)) != target_minute or int(mechanic.get("clock_hour", 0)) != target_hour or int(mechanic.get("clock_minute", -1)) != target_minute % 60:
			return {"ok": false, "message": "时针或分针还没有对准当前时间。"}
	var selected_tokens: Array = interaction_record.get("selected_tokens", [])
	var interaction: Dictionary = prototype.get("interaction", {})
	var minimum := int(interaction.get("min_select", 0))
	var maximum := int(interaction.get("max_select", minimum))
	if selected_tokens.size() < minimum:
		return {"ok": false, "message": "还需要选择%d项。" % (minimum - selected_tokens.size())}
	if selected_tokens.size() > maximum:
		return {"ok": false, "message": "选择数量超过了当前上限。"}
	var known_tokens: Array[String] = []
	for token in interaction.get("tokens", []):
		known_tokens.append(str(token.get("id", "")))
	var seen_tokens: Array[String] = []
	for token_id_value in selected_tokens:
		var token_id := str(token_id_value)
		if not known_tokens.has(token_id) or seen_tokens.has(token_id):
			return {"ok": false, "message": "操作记录里有无效或重复的项目。"}
		seen_tokens.append(token_id)
	for required_id_value in selected.get("required_tokens", []):
		var required_id := str(required_id_value)
		if not selected_tokens.has(required_id):
			return {"ok": false, "message": str(selected.get("constraint_note", "这个结果还缺少必要项目。"))}
	for forbidden_id_value in selected.get("forbidden_tokens", []):
		var forbidden_id := str(forbidden_id_value)
		if selected_tokens.has(forbidden_id):
			return {"ok": false, "message": str(selected.get("constraint_note", "当前选择包含不能用于这个结果的项目。"))}
	return {"ok": true, "message": ""}


func complete_choice(choice_id: String, interaction_record: Dictionary = {}) -> Dictionary:
	var module_id := pending_module_id()
	if module_id.is_empty() or not prototypes.has(module_id):
		return {"ok": false, "message": "没有正在进行的玩法。"}
	var prototype: Dictionary = prototypes[module_id]
	var selected: Dictionary = {}
	for choice in prototype.get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			selected = choice
			break
	if selected.is_empty():
		return {"ok": false, "message": "找不到这个玩法选择。"}
	var stored_interaction := interaction_record.duplicate(true)
	if not stored_interaction.has("selected_labels"):
		var selected_labels: Array[String] = []
		for token_id_value in stored_interaction.get("selected_tokens", []):
			selected_labels.append(_prototype_token_label(prototype, str(token_id_value)))
		stored_interaction["selected_labels"] = selected_labels
	var interaction_check := choice_interaction_check(module_id, choice_id, stored_interaction)
	if not bool(interaction_check.get("ok", false)):
		return interaction_check
	var cost: Dictionary = selected.get("cost", {})
	if module_id == "cooking":
		var stock_check := EconomySystem.cooking_check(stored_interaction.get("selected_tokens", []))
		if not bool(stock_check.ok): return stock_check
		cost = EconomySystem.cooking_cost(cost)
	var payment := EventSystem.can_pay_cost_data(cost)
	if not bool(payment.get("ok", false)):
		return {"ok": false, "message": str(payment.get("reason", "当前资源不足。"))}
	var amount := int(cost.get("money", 0))
	var minutes := int(cost.get("minutes", 0))
	if amount > 0:
		GameState.spend_money(amount, "完成%s" % str(prototypes.get(module_id, {}).get("title", module_id)))
	if minutes > 0:
		GameState.use_free_time(minutes)
	var results: Dictionary = selected.get("results", {}).duplicate(true)
	var role_results: Dictionary = selected.get("results_by_role", {}).get(GameState.current_role, {}).duplicate(true)
	var work_payment := 0
	if module_id in ["ghostwriting", "sound_sampling"]:
		work_payment = int(results.get("money",0))
		results.erase("money")
	if module_id == "cooking":
		results.erase("money")
		role_results.erase("money")
	EventSystem.apply_results("module_%s_%s" % [module_id, choice_id], results)
	EventSystem.apply_results("module_%s_%s" % [module_id, choice_id], role_results)
	var outcome := {
		"choice_id": choice_id,
		"label": str(selected.get("label", choice_id)),
		"source_event_id": str(GameState.shared_state.get("pending_module", {}).get("source_event_id", "")),
		"interaction": stored_interaction,
	}
	complete(module_id, outcome)
	if module_id == "cooking": EconomySystem.finish_cooking(outcome, stored_interaction.get("selected_tokens", []))
	if work_payment > 0:
		var issuer := "handcraft_shop" if module_id == "ghostwriting" else "record_store"
		GameState.earn_money(work_payment,"书信委托报酬" if module_id == "ghostwriting" else "采样整理报酬",{"work_minutes":minutes,"kind":"income","issuer":issuer,"source":"module_"+module_id})
		var outcome_index := maxi(0,ensure_state(module_id).outcomes.size()-1)
		ResidencySystem.accept_contribution("module_%s_%d" % [module_id,outcome_index],issuer,{"accepted":true,"source":"counter_delivery"})
	EchoSystem.record_module(module_id, outcome)
	GameState.shared_state.erase("pending_module")
	GameState.commit_active_role_state()
	return {
		"ok": true,
		"message": str(selected.get("result_text", "这次经历已经被记录下来。")),
		"module_id": module_id,
		"outcome": outcome,
	}


func _prototype_token_label(prototype: Dictionary, token_id: String) -> String:
	for token in prototype.get("interaction", {}).get("tokens", []):
		if str(token.get("id", "")) == token_id:
			return str(token.get("label", token_id))
	return token_id


func complete_external(module_id: String, outcome: Dictionary, results: Dictionary = {}) -> bool:
	if not modules.has(module_id) or not is_unlocked(module_id):
		return false
	var was_completed := bool(ensure_state(module_id).get("completed", false))
	if not complete(module_id, outcome):
		return false
	var granted := results.duplicate(true)
	# This extension contains one authored client commission. Reopening its
	# finished letter is a keepsake, not a new payable delivery.
	if module_id == "ghostwriting":
		granted.erase("money")
		if not was_completed and bool(outcome.get("contribution_accepted",false)):
			var work: Dictionary = EconomySystem.config.work.letter
			GameState.earn_money(int(work.pay),"书信委托报酬",{"work_minutes":int(work.minutes),"kind":"income","issuer":"handcraft_shop","source":"letter_delivery"})
	EventSystem.apply_results("module_%s_external" % module_id, granted)
	EchoSystem.record_module(module_id, outcome)
	GameState.shared_state.erase("pending_module")
	GameState.commit_active_role_state()
	return true

func time_hint(module_id: String) -> String:
	var metadata: Dictionary = modules.get(module_id,{})
	if int(metadata.get("direct_time_minutes",0)) > 0: return "%d分钟" % int(metadata.direct_time_minutes)
	var costs: Array[int] = []
	for choice in prototypes.get(module_id,{}).get("choices",[]): costs.append(int(choice.get("cost",{}).get("minutes",0)))
	if costs.is_empty(): return ""
	costs.sort()
	return "%d分钟" % costs[0] if costs[0] == costs[-1] else "%d—%d分钟" % [costs[0],costs[-1]]
