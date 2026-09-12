extends Control
signal return_requested
signal match_finished(result: String)
const UI = preload("res://scripts/ui_bits.gd")
const Rules = preload("res://scripts/teaching_rules.gd")
const Memory = preload("res://scripts/elder_memory.gd")
var profile: Dictionary
var rule: Dictionary
var board: Array = []
var side := 1
var busy := false
var ended := false
var generation := 0
var move_count := 0
var selected := -1
var last := -1
var moves: Array = []
var status: Label
var words: Label
var rule_view: Control
var origin := Vector2(130, 175)
var cell := 60.0

func setup(saved: Dictionary) -> void:
	profile = saved.duplicate(true)
	rule = profile.rules

func _ready() -> void:
	size = Vector2(1579, 972)
	UI.label(self, rule.name, Rect2(95, 45, 850, 65), 38)
	UI.label(self, "%s教的棋 · %s正在下" % [profile.get("taught_by", "棋友"), Memory.role], Rect2(950, 80, 550, 45), 27)
	status = UI.label(self, "", Rect2(950, 160, 530, 90), 30)
	words = UI.label(self, "", Rect2(950, 270, 520, 225), 25)
	UI.button(self, "看看记住的规则", Rect2(950, 550, 520, 60), show_rules)
	UI.button(self, "再下一局", Rect2(950, 640, 520, 60), restart)
	UI.button(self, "认输", Rect2(950, 730, 240, 60), func(): finish("你已认输。"))
	UI.button(self, "回到棋谱", Rect2(1210, 730, 260, 60), func(): return_requested.emit())
	UI.label(self, "你用黑子，老人用白子。落子棋点击空点；移动棋先点自己的棋子，再点目标。", Rect2(95, 855, 1370, 80), 23)
	restart()

func restart() -> void:
	generation += 1
	board = Rules.initial(rule)
	cell = minf(650.0 / int(rule.width), 600.0 / int(rule.height))
	move_count = 0
	selected = -1
	last = -1
	ended = false
	busy = false
	side = 1 if rule.first == "player" else -1
	words.text = "我记得，这套是%s教的。%s先走，对吧？来，摆好了。" % [profile.get("taught_by", "你"), "你" if side == 1 else "我"]
	refresh()
	if side == -1: call_deferred("ai_turn")

func refresh() -> void:
	moves = Rules.legal(board, side, rule)
	if not ended: status.text = "轮到你了" if side == 1 else "让我照着规则想想…"
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("222822"))
	var w := int(rule.width)
	var h := int(rule.height)
	draw_rect(Rect2(origin, Vector2(w, h) * cell), Color("bbb8a9"))
	for x in range(w + 1): draw_line(origin + Vector2(x * cell, 0), origin + Vector2(x * cell, h * cell), Color("656b60"), 1)
	for y in range(h + 1): draw_line(origin + Vector2(0, y * cell), origin + Vector2(w * cell, y * cell), Color("656b60"), 1)
	for i in range(board.size()):
		var p := origin + Vector2(i % w + 0.5, int(i / w) + 0.5) * cell
		if board[i] != 0: draw_circle(p, cell * 0.34, Color("242925") if board[i] == 1 else Color("f4f2e9"))
		if i == selected or i == last: draw_arc(p, cell * 0.4, 0, TAU, 24, Color("92853e"), 3)
	if selected >= 0:
		for move in moves:
			if move.from == selected:
				draw_circle(origin + Vector2(move.to % w + 0.5, int(move.to / w) + 0.5) * cell, 5, Color("486545"))

func _gui_input(event: InputEvent) -> void:
	if ended or busy or side != 1 or is_instance_valid(rule_view): return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	var p: Vector2 = (event.position - origin) / cell
	var x := floori(p.x)
	var y := floori(p.y)
	if x < 0 or y < 0 or x >= int(rule.width) or y >= int(rule.height): return
	var i := y * int(rule.width) + x
	for move in moves:
		if move.to == i and (rule.kind == "line" or move.from == selected):
			play(move)
			if not ended: ai_turn()
			return
	selected = i if board[i] == 1 else -1
	queue_redraw()

func play(move: Dictionary) -> void:
	if not Rules.legal(board, side, rule).has(move): return
	board = Rules.apply(board, move, side)
	move_count += 1
	last = move.to
	selected = -1
	if Rules.won(board, side, rule):
		finish("你赢了！" if side == 1 else "这局我赢了。")
	else:
		side = -side
		var available := Rules.legal(board, side, rule)
		if available.is_empty():
			finish("棋盘满了，和棋。" if rule.kind == "line" else ("你没有合法走法，这局我赢了。" if side == 1 else "我没有合法走法，你赢了！"))
		elif move_count >= 200 and rule.kind == "capture": finish("按约定走满200步，和棋。")
	refresh()

func ai_turn() -> void:
	if ended or side != -1: return
	busy = true
	var token := generation
	await get_tree().create_timer(0.35).timeout
	if token != generation or ended: return
	var move := Rules.ai(board, rule)
	if not move.is_empty(): play(move)
	busy = false
	if not ended: words.text = ["我下这儿。该你了。", "嗯，就这么走。你看。", "这一手我想好了。来。", "我把手拿开，你看仔细点。"][move_count % 4]
	refresh()

func finish(text: String) -> void:
	if ended: return
	ended = true
	busy = false
	generation += 1
	status.text = text
	words.text = "这棋有意思。我把刚才那几步再摆摆。你要有空，咱们再来；有事就先去忙。"
	match_finished.emit(text)

func show_rules() -> void:
	if is_instance_valid(rule_view): return
	rule_view = Control.new()
	rule_view.size = size
	add_child(rule_view)
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0, 0, 0, 0.7)
	rule_view.add_child(shade)
	UI.panel(rule_view, Rect2(290, 200, 1000, 580))
	UI.rich(rule_view, Rect2(340, 240, 900, 410), 28).text = Rules.summary(rule)
	UI.button(rule_view, "嗯，继续下", Rect2(660, 690, 580, 60), func(): rule_view.queue_free(); rule_view = null)
