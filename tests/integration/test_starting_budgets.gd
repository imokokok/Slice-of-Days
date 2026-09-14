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
	state.begin_new_game("A")
	check(state.money == 12000 and state.role_states.B.money == 1600, "New A/B budgets are 12000/1600")
	state.spend_money(18,"奶酪")
	state.earn_money(35,"书信委托")
	var modern: Dictionary = state.to_save_data()
	state.load_save_data(modern)
	check(state.money == 12017, "New saves never receive a migration top-up")
	var old: Dictionary = modern.duplicate(true)
	old.shared_state.erase("starting_budget_version")
	old.role_states.A.money = 317
	old.role_states.A.money_ledger = [{"amount":-18,"reason":"奶酪"},{"amount":35,"reason":"书信委托"}]
	old.current_role = "B"
	old.role_states.B.money = 93
	state.load_save_data(old)
	check(state.money == 1533 and state.role_states.A.money == 12017, "Both roles receive only their missing starting capital")
	check(state.role_states.A.money_ledger.size() == 3, "Existing transactions survive with one adjustment entry")
	var migrated: Dictionary = state.to_save_data()
	state.load_save_data(migrated)
	state.switch_to_role("A")
	check(state.money == 12017 and state.money_ledger.size() == 3, "Reload and character switching never duplicate the grant")
	state.switch_to_role("B")
	check(state.money == 1533, "B keeps the same spent balance after switching")
	var previous: Dictionary = old.duplicate(true)
	previous.shared_state.starting_budget_version = 2
	previous.role_states.A.money = 1017
	state.load_save_data(previous)
	check(state.role_states.A.money == 12017 and state.money == 1533, "The 1000/160 release migrates directly without repeating its earlier A grant")
	state.load_save_data({"current_role":"A","money":91,"current_day":1})
	var ancient: Dictionary = state.to_save_data()
	state.load_save_data(ancient)
	check(state.money == 91, "Unversioned historic saves keep their unknown starting-budget history")
	print("STARTING BUDGETS PASS" if failures == 0 else "STARTING BUDGETS FAIL")
	quit(failures)
