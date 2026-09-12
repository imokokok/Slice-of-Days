extends Control
signal return_requested
signal match_finished(result: String)
const Grid = preload("res://scripts/grid_rules.gd")
const Chess = preload("res://scripts/chess_rules.gd")
const Text = preload("res://scripts/game_text.gd")
const GLYPHS := ["", "♟", "♞", "♝", "♜", "♛", "♚"]

var game_id: StringName
var board: Array = []
var n := 9
var cell := 70.0
var origin := Vector2(152, 175)
var turn := 1
var busy := false
var ended := false
var scoring := false
var generation := 0
var last_move := -1
var selected := -1
var passes := 0
var history: Dictionary = {}
var dead: Dictionary = {}
var chess: Dictionary = {}
var legal_moves: Array = []
var status: Label
var detail: Label
var pass_button: Button
var score_button: Button
var promotion: OptionButton
var piece_font: SystemFont
var go_size := 9
var talk_index := 0
var feedback := ""
var rules_view: Control

func setup(id: StringName, preferred_go_size: int = 9) -> void:
	game_id = id
	go_size = preferred_go_size if preferred_go_size in [9, 13, 19] else 9

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(1579, 972)
	piece_font = SystemFont.new()
	piece_font.font_names = PackedStringArray(["Segoe UI Symbol", "DejaVu Sans", "Arial Unicode MS"])
	_build_ui()
	restart()

func label_at(text: String, p: Vector2, width: float, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = p
	label.size.x = width
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eeeeee"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func button_at(text: String, p: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = p
	button.size = Vector2(420, 62)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	add_child(button)
	return button

func _build_ui() -> void:
	var titles := {&"go": "围棋 · %d 路" % go_size, &"gomoku": "五子棋 · 15 路", &"chess": "国际象棋"}
	label_at(titles[game_id], Vector2(110, 60), 750, 42)
	label_at("老棋友 · 本地 AI", Vector2(1000, 95), 470, 32)
	status = label_at("", Vector2(1000, 160), 450, 30)
	detail = label_at("", Vector2(1000, 250), 440, 23)
	pass_button = button_at("停一手", Vector2(1000, 460), human_pass)
	pass_button.visible = game_id == &"go"
	score_button = button_at("确认死子，计算结果", Vector2(1000, 460), finish_score)
	score_button.hide()
	button_at("重新开局", Vector2(1000, 550), restart)
	button_at("认输", Vector2(1000, 635), resign)
	button_at("返回棋类选择", Vector2(1000, 720), func(): return_requested.emit())
	button_at("规则说明", Vector2(1000, 805), show_rules)
	label_at("点击棋盘落子；国际象棋先选棋子，再选目标格。", Vector2(110, 850), 800, 23)
	promotion = OptionButton.new()
	for item in ["升变：后", "升变：车", "升变：象", "升变：马"]: promotion.add_item(item)
	promotion.position = Vector2(1000, 460)
	promotion.size = Vector2(420, 62)
	promotion.visible = game_id == &"chess"
	add_child(promotion)

func restart() -> void:
	generation += 1
	busy = false
	ended = false
	scoring = false
	turn = 1
	passes = 0
	talk_index = 0
	feedback = ""
	last_move = -1
	selected = -1
	history.clear()
	dead.clear()
	score_button.hide()
	pass_button.visible = game_id == &"go"
	pass_button.disabled = false
	n = 8 if game_id == &"chess" else (go_size if game_id == &"go" else 15)
	cell = 76.0 if game_id == &"chess" else 608.0 / (n - 1)
	board.resize(n * n)
	board.fill(0)
	if game_id == &"chess":
		chess = Chess.initial()
		board = chess.board
		legal_moves = Chess.legal(chess)
		history[Chess.key(chess)] = 1
	else: history[Grid.key(board)] = true
	status.text = "轮到你了"
	var descriptions := {
		&"go": "这次用 %d 路棋盘。你拿黑子先下，我拿白子。先找个喜欢的位置，不用急着围住所有地方。\n不清楚的地方，随时点“规则说明”。" % n,
		&"gomoku": "来，黑子给你。咱们轮流下，谁先连成五个谁赢。横竖斜着都算，可别只盯着一个方向哦。",
		&"chess": "你用白棋，先走。点一下棋子，我会把它能走的位置标出来。想复习走法，就打开“规则说明”。"
	}
	detail.text = descriptions[game_id]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.11, 0.11, 0.97))
	if game_id == &"chess":
		for i in range(64):
			var p := origin + Vector2(i % 8, i / 8) * cell
			draw_rect(Rect2(p, Vector2.ONE * cell), Color("c2c0b5") if (i % 8 + int(i / 8)) % 2 == 0 else Color("696e68"))
			if i == last_move: draw_rect(Rect2(p, Vector2.ONE * cell), Color(0.8, 0.8, 0.4, 0.28))
			if i == selected: draw_rect(Rect2(p + Vector2.ONE * 3, Vector2.ONE * (cell - 6)), Color("e5ddad"), false, 4)
			var piece: int = board[i]
			if piece != 0:
				var glyph: String = GLYPHS[absi(piece)]
				var pos := p + Vector2(7, 60)
				draw_string_outline(piece_font, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, 3, Color("292929") if piece > 0 else Color("dddddd"))
				draw_string(piece_font, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color("fafafa") if piece > 0 else Color("202020"))
		if selected >= 0:
			for move in legal_moves:
				if move.from == selected:
					var p := origin + Vector2(move.to % 8 + 0.5, int(move.to / 8) + 0.5) * cell
					draw_circle(p, 8, Color("eadf9b"))
	else:
		draw_rect(Rect2(origin - Vector2.ONE * 30, Vector2.ONE * (608 + 60)), Color("b6b3a5"))
		for i in range(n):
			draw_line(origin + Vector2(i * cell, 0), origin + Vector2(i * cell, 608), Color("454741"), 1.5)
			draw_line(origin + Vector2(0, i * cell), origin + Vector2(608, i * cell), Color("454741"), 1.5)
		var stars := [3, int(n / 2), n - 4]
		if n == 9: stars = [2, 4, 6]
		for x in stars:
			for y in stars:
				if n == 19 or x == y or x + y == n - 1: draw_circle(origin + Vector2(x, y) * cell, 4, Color("454741"))
		for i in range(board.size()):
			if board[i] == 0: continue
			var p := origin + Vector2(i % n, i / n) * cell
			var radius := cell * 0.42
			draw_circle(p + Vector2(2, 3), radius, Color(0, 0, 0, 0.2))
			draw_circle(p, radius, Color("242626") if board[i] == 1 else Color("eeeee8"))
			if i == last_move: draw_arc(p, radius * 0.4, 0, TAU, 24, Color("a6a485"), 2)
			if dead.has(i):
				draw_line(p - Vector2(10, 10), p + Vector2(10, 10), Color("b55252"), 3)
				draw_line(p - Vector2(10, -10), p + Vector2(10, -10), Color("b55252"), 3)

func _gui_input(event: InputEvent) -> void:
	if is_instance_valid(rules_view): return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	if ended or busy: return
	var p: Vector2 = (event.position - origin) / cell
	var x := int(floor(p.x)) if game_id == &"chess" else roundi(p.x)
	var y := int(floor(p.y)) if game_id == &"chess" else roundi(p.y)
	if x < 0 or y < 0 or x >= n or y >= n: return
	var i := y * n + x
	if scoring:
		if board[i] == 0: return
		var remove := dead.has(i)
		for stone in Grid.group(board, i, n).stones:
			if remove: dead.erase(stone)
			else: dead[stone] = true
		queue_redraw()
		return
	if turn != 1: return
	if game_id == &"chess":
		for move in legal_moves:
			if move.from == selected and move.to == i:
				if move.promo != 0 and move.promo != [5, 4, 3, 2][promotion.selected]: continue
				play_chess(move)
				if not ended: ai_turn()
				return
		selected = i if board[i] > 0 else -1
		queue_redraw()
	else:
		if play_stone(i, 1) and not ended: ai_turn()

func play_stone(i: int, side: int) -> bool:
	if board[i] != 0: return false
	if side == 1: feedback = ""
	if game_id == &"go":
		var move := Grid.go_move(board, i, side, n, history)
		if move.is_empty():
			status.text = "此处不能落子（无气或同形）"
			detail.text = "这一步暂时不能下：落子后要有气，也不能重复之前的棋盘局面。换个点试试？"
			return false
		board = move.board
		if move.captured > 0:
			feedback = "刚才你提走了 %d 颗白子，眼力不错。也看看自己棋块的气吧。" % move.captured if side == 1 else "我提走了 %d 颗黑子。别灰心，先照顾好附近还在盘上的棋。" % move.captured
		history[Grid.key(board)] = true
	else:
		board[i] = side
		if Grid.five(board, i, side, n): finish("你赢了！" if side == 1 else "老棋友获胜，再来一局？")
		elif not board.has(0): finish("棋盘已满，本局和棋。")
	passes = 0
	last_move = i
	turn = -side
	queue_redraw()
	return true

func play_chess(move: Dictionary) -> void:
	var moving_side: int = chess.turn
	if moving_side == 1: feedback = ""
	var captured: bool = chess.board[move.to] != 0 or (absi(chess.board[move.from]) == 1 and move.to == chess.ep)
	if captured:
		feedback = "你刚才吃了我的棋子。这下我得重新想想了，轮到你继续走。" if moving_side == 1 else "我这步吃了一个子。别着急，先看看还有哪些棋子能互相照应。"
	if move.promo != 0: feedback = "兵走到底线，升变完成了！小兵也能成为决定局面的力量。"
	chess = Chess.apply(chess, move)
	board = chess.board
	turn = chess.turn
	last_move = move.to
	selected = -1
	legal_moves = Chess.legal(chess)
	var position_key := Chess.key(chess)
	history[position_key] = history.get(position_key, 0) + 1
	if legal_moves.is_empty():
		if Chess.in_check(chess, turn): finish("将死，你赢了！" if turn == -1 else "你被将死，老棋友获胜。")
		else: finish("无合法走法且未被将军：和棋。")
	elif Chess.insufficient(board): finish("双方子力不足以将死：和棋。")
	elif history[position_key] >= 3: finish("局面出现三次：和棋。")
	elif chess.half >= 100: finish("50 回合无吃子或兵步：和棋。")
	queue_redraw()

func ai_turn() -> void:
	busy = true
	pass_button.disabled = true
	status.text = "老棋友正在思考…"
	var token := generation
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree() or generation != token or ended: return
	if game_id == &"chess":
		var move := Chess.ai(chess)
		if not move.is_empty(): play_chess(move)
	elif game_id == &"gomoku":
		var i := Grid.gomoku_ai(board, n)
		if i >= 0: play_stone(i, -1)
	else:
		var i := Grid.go_ai(board, n, history, passes > 0)
		if i < 0:
			passes += 1
			turn = 1
			if passes >= 2: begin_score()
			else: status.text = "老棋友停一手，轮到你了。"
		else: play_stone(i, -1)
	busy = false
	pass_button.disabled = false
	if not ended and not scoring:
		status.text = "轮到你了" if passes == 0 else "老棋友停一手，轮到你了。"
		if game_id == &"chess" and Chess.in_check(chess, 1): status.text = "你被将军了，请应将。"
		if game_id == &"chess" and Chess.in_check(chess, 1):
			detail.text = "将军啦。这一步得先照顾你的王：移开、挡住攻击，或者吃掉攻击它的棋子。"
		elif passes > 0:
			detail.text = "我先停一手。你可以接着下；如果也觉得差不多了，就停手一起数子。"
		elif not feedback.is_empty(): detail.text = feedback
		else:
			detail.text = Text.LINES[game_id][talk_index % Text.LINES[game_id].size()]
			talk_index += 1
	queue_redraw()

func human_pass() -> void:
	if game_id != &"go" or busy or ended or scoring or turn != 1: return
	passes += 1
	turn = -1
	if passes >= 2: begin_score()
	else: ai_turn()

func begin_score() -> void:
	scoring = true
	busy = false
	pass_button.hide()
	score_button.show()
	status.text = "双方停手，请确认死子。"
	detail.text = "那咱们一起数数。点击棋子标记整块死子，点错了再点一次就能取消。确认好红叉，再算分数。白方会加上 7.5 子。"

func finish_score() -> void:
	if not scoring or ended: return
	var final_board := board.duplicate()
	for stone in dead: final_board[stone] = 0
	var result := Grid.go_score(final_board, n)
	scoring = false
	score_button.hide()
	finish("你赢了！" if result.x > result.y else "老棋友获胜。")
	detail.text += "\n黑方：%.1f 子；白方：%.1f 子（含贴子）。" % [result.x, result.y]

func resign() -> void:
	if ended: return
	generation += 1
	scoring = false
	score_button.hide()
	finish("你已认输，老棋友获胜。")

func finish(message: String) -> void:
	if ended: return
	ended = true
	busy = false
	status.text = message
	pass_button.disabled = true
	if "你赢了" in message:
		detail.text = "这局是你赢了，下得好！愿意的话再来一盘，我也想试试新的走法。"
	elif "和棋" in message:
		detail.text = "这回不分胜负。能下到这里也很有意思，咱们换个开局再试试？"
	elif "认输" in message:
		detail.text = "好，这局就到这里。休息一下也行，换种棋也行，我在这儿等你。"
	else:
		detail.text = "这局我先拿下了。别在意，多下一盘就多一点经验。要不要再来？"
	match_finished.emit(message)

func show_rules() -> void:
	if is_instance_valid(rules_view): return
	rules_view = preload("res://scripts/rules_panel.gd").new()
	rules_view.configure(game_id, false, go_size)
	rules_view.closed.connect(func():
		rules_view.queue_free()
		rules_view = null
	)
	add_child(rules_view)
