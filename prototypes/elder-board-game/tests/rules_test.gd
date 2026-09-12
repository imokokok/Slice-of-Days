extends SceneTree
const Chess = preload("res://scripts/chess_rules.gd")
const Grid = preload("res://scripts/grid_rules.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func perft(state: Dictionary, depth: int) -> int:
	if depth == 0: return 1
	var result := 0
	for move in Chess.legal(state): result += perft(Chess.apply(state, move), depth - 1)
	return result

func from_fen(fen: String) -> Dictionary:
	var parts := fen.split(" ")
	var board: Array = []
	for char_value in parts[0]:
		if char_value == "/": continue
		if char_value.is_valid_int():
			for i in range(int(char_value)): board.append(0)
		else:
			var type := " pnbrqk".find(char_value.to_lower())
			board.append(type * (1 if char_value == char_value.to_upper() else -1))
	var ep := -1
	if parts[3] != "-": ep = (8 - int(parts[3][1])) * 8 + "abcdefgh".find(parts[3][0])
	return {"board": board, "turn": 1 if parts[1] == "w" else -1, "rights": parts[2], "ep": ep, "half": 0}

func _initialize() -> void:
	check(perft(Chess.initial(), 3) == 8902, "Chess initial perft(3) must be 8902")
	var castle := from_fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
	check(perft(castle, 2) == 2039, "Kiwipete perft(2) must be 2039")
	var ep := from_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
	check(perft(ep, 3) == 2812, "Endgame perft(3) must be 2812")
	var promotion := from_fen("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	var promotions := 0
	for move in Chess.legal(promotion):
		if move.promo != 0: promotions += 1
	check(promotions == 4, "Four promotion choices")
	var en_passant := from_fen("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	var found_ep := false
	for move in Chess.legal(en_passant):
		if move.from == 28 and move.to == 19:
			found_ep = Chess.apply(en_passant, move).board[27] == 0
	check(found_ep, "En passant removes the passed pawn")
	var mate := from_fen("7k/6Q1/6K1/8/8/8/8/8 b - - 0 1")
	check(Chess.legal(mate).is_empty() and Chess.in_check(mate, -1), "Checkmate detection")
	var stale := from_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	check(Chess.legal(stale).is_empty() and not Chess.in_check(stale, -1), "Stalemate detection")
	var state := Chess.initial()
	state = Chess.apply(state, Chess.legal(state)[0])
	check(Chess.legal(state).has(Chess.ai(state)), "AI returns a legal move")
	var board: Array = [0, 1, 0, 1, -1, 1, 0, 0, 0]
	var capture := Grid.go_move(board, 7, 1, 3, {})
	check(not capture.is_empty() and capture.captured == 1 and capture.board[4] == 0, "Go capture")
	check(Grid.go_move([0, 1, 0, 1, 0, 1, 0, 1, 0], 4, -1, 3, {}).is_empty(), "Go suicide forbidden")
	var repetition := {Grid.key(capture.board): true}
	check(Grid.go_move(board, 7, 1, 3, repetition).is_empty(), "Go positional superko")
	check(Grid.go_score([1, 1, 1, 1, 0, 1, 1, 1, 1], 3) == Vector2(9, 7.5), "Go empty territory flood-fill")
	check(Grid.go_score([0, 0, 0, 0, 0, 0, 0, 0, 0], 3) == Vector2(0, 7.5), "Go neutral region")
	board.resize(225)
	board.fill(0)
	for i in range(4): board[7 * 15 + i + 3] = 1
	var block := Grid.gomoku_ai(board, 15)
	check(block == 7 * 15 + 2 or block == 7 * 15 + 7, "Gomoku AI blocks immediate win")
	for i in range(4): board[5 * 15 + i + 3] = -1
	var win := Grid.gomoku_ai(board, 15)
	board[win] = -1
	check(Grid.five(board, win, -1, 15), "Gomoku AI takes win before defense")
	print("RULE TESTS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
