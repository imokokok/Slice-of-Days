extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	state.begin_new_game("B")
	state.switch_to_role("B",2,true)
	check(state.daily_spending_plan().planned == 80 and state.daily_spending_plan().remaining == 80, "B starts every day with an 80-yuan plan")
	state.buy_item({"id":"tomato","name":"番茄","price":8,"minutes":5})
	state.spend_money(20,"日用品")
	state.earn_money(45,"工作收入")
	check(state.daily_spending_plan().spent == 28 and state.daily_spending_plan().remaining == 52, "Income must not erase actual spending")
	var journal = load("res://scripts/ui/journal.gd").new()
	check(journal._today_text().contains("今日花钱计划 80元") and journal._today_text().contains("还可安排 52元"), "Notebook distinguishes daily plan from wallet")
	journal.free()
	state.spend_money(60,"晚饭和杂货")
	check(state.daily_spending_plan().over == 8 and state.spending_plan_text().contains("超出计划 8元"), "Over-budget spending is recorded and explained")
	var shop = load("res://scripts/ui/shop_panel.gd").new()
	shop.shop_id = "grocery"
	root.add_child(shop)
	await process_frame
	check(shop.budget_label.text.contains("超出计划 8元"), "Purchase screen shows the same live plan")
	shop.queue_free()
	await process_frame
	for i in 90: state.spend_money(1,"小额支出")
	var saved: Dictionary = state.to_save_data()
	state.load_save_data(saved)
	check(state.daily_spending_plan().spent == 178, "Daily total survives ledger truncation and reload")
	state.switch_to_role("A")
	check(state.spending_plan_text().is_empty(), "A does not inherit B's daily plan")
	state.switch_to_role("B",3,true)
	check(state.daily_spending_plan().spent == 0 and state.daily_spending_plan().remaining == 80, "New day has a fresh plan without charging the wallet")
	state.switch_to_role("B",2)
	check(state.daily_spending_plan().spent == 178, "Earlier daily totals remain intact")
	var old: Dictionary = state.to_save_data()
	old.role_states.B.erase("daily_spending")
	old.role_states.B.money_ledger = [{"day":2,"amount":-12},{"day":2,"amount":45},{"day":1,"amount":-7}]
	state.load_save_data(old)
	check(state.daily_spending_plan().spent == 12, "Old saves reconstruct daily spending from available expense records")
	print("DAILY SPENDING PASS" if failures == 0 else "DAILY SPENDING FAIL")
	quit(failures)
