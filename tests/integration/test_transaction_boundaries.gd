extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(1)
		return
	var state = root.get_node("GameState")
	root.get_node("ChapterSystem").start_new_game()
	state.switch_to_role("B", 2, true) # Focused private-state fixture, not a chapter shortcut.
	state.current_minute = 700
	var untouched: Dictionary = state.to_save_data()
	check(not state.spend_money(-1, "invalid"), "Negative expenses are rejected")
	check(not state.spend_money(state.money + 1, "invalid"), "Expenses cannot overdraw the wallet")
	state.earn_money(0, "invalid")
	state.earn_money(-1, "invalid")
	check(state.to_save_data() == untouched, "Rejected money changes leave balance, ledger and spending intact")

	check(not bool(state.buy_item({"id":"soap","price":0}).get("ok", false)), "Zero-price purchases are rejected")
	check(not bool(state.buy_item({"id":"soap","price":state.money + 1,"minutes":5}).get("ok", false)), "Unaffordable purchases are rejected")
	check(state.can_fit_now(21), "Five-day schedule no longer has the retired noon block gate")
	check(not bool(state.buy_item({"id":"soap","price":10,"minutes":741}).get("ok", false)), "A purchase cannot exceed the current daytime window")
	check(state.to_save_data() == untouched, "Failed purchases change neither inventory, time nor accounts")

	var start_money: int = state.money
	var start_ledger: int = state.money_ledger.size()
	var result: Dictionary = state.buy_item({"id":"soap","name":"海盐肥皂","price":10,"minutes":5})
	check(bool(result.get("ok", false)), "Affordable purchase inside the free block succeeds")
	check(state.money == start_money - 10 and int(state.inventory.get("soap", 0)) == 1, "Purchase charges once and grants one item")
	check(state.current_minute == 705 and int(state.daily_spending.get("2", 0)) == 10, "Purchase charges five minutes and records spending on B's actual day")
	check(state.money_ledger.size() == start_ledger + 1 and int(state.money_ledger[-1].amount) == -10, "Purchase writes one matching ledger entry")

	var purchased: Dictionary = state.to_save_data()
	check(state.switch_to_role("A"), "Switching to A succeeds")
	check(int(state.inventory.get("soap", 0)) == 0 and state.money_ledger.is_empty(), "A cannot see B's item or expense")
	check(state.switch_to_role("B"), "Switching back to B succeeds")
	check(state.money == start_money - 10 and int(state.inventory.get("soap", 0)) == 1 and state.current_minute == 705, "B's purchase survives role switching")

	state.begin_new_game("A")
	state.load_save_data(purchased)
	check(state.current_role == "B" and state.money == start_money - 10 and int(state.inventory.get("soap", 0)) == 1, "Save data restores the correct owner, balance and item")
	check(state.current_minute == 705 and int(state.daily_spending.get("2", 0)) == 10 and state.money_ledger.size() == start_ledger + 1, "Save data restores time and the expense exactly once")
	print("TRANSACTION BOUNDARIES ", checks, " checks / ", failures, " failures")
	quit(failures)
