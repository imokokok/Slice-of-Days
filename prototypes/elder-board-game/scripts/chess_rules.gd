extends RefCounted
const VALUES := [0, 100, 320, 330, 500, 900, 20000]

static func initial() -> Dictionary:
	var board: Array = []
	board.resize(64)
	board.fill(0)
	var row := [4, 2, 3, 5, 6, 3, 2, 4]
	for x in range(8):
		board[x] = -row[x]
		board[8 + x] = -1
		board[48 + x] = 1
		board[56 + x] = row[x]
	return {"board": board, "turn": 1, "rights": "KQkq", "ep": -1, "half": 0}

static func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < 8 and p.y >= 0 and p.y < 8

static func attacked(board: Array, square: int, by: int) -> bool:
	var target := Vector2i(square % 8, square / 8)
	for i in range(64):
		if board[i] * by <= 0: continue
		var piece: int = absi(board[i])
		var source := Vector2i(i % 8, i / 8)
		var delta := target - source
		if piece == 1:
			if delta.y == -by and absi(delta.x) == 1: return true
		elif piece == 2:
			if absi(delta.x) * absi(delta.y) == 2: return true
		elif piece == 6:
			if maxi(absi(delta.x), absi(delta.y)) == 1: return true
		else:
			var diagonal := absi(delta.x) == absi(delta.y) and delta.x != 0
			var straight := (delta.x == 0) != (delta.y == 0)
			if not ((piece == 3 and diagonal) or (piece == 4 and straight) or (piece == 5 and (diagonal or straight))): continue
			var step := Vector2i(signi(delta.x), signi(delta.y))
			var p := source + step
			var blocked := false
			while p != target:
				if board[p.y * 8 + p.x] != 0:
					blocked = true
					break
				p += step
			if not blocked: return true
	return false

static func in_check(state: Dictionary, side: int) -> bool:
	var king: int = state.board.find(6 * side)
	return king < 0 or attacked(state.board, king, -side)

static func add_move(out: Array, a: int, b: int, pawn: bool = false) -> void:
	if pawn and (b < 8 or b >= 56):
		for promo in [5, 4, 3, 2]: out.append({"from": a, "to": b, "promo": promo})
	else: out.append({"from": a, "to": b, "promo": 0})

static func pseudo(state: Dictionary) -> Array:
	var board: Array = state.board
	var side: int = state.turn
	var out: Array = []
	for i in range(64):
		if board[i] * side <= 0: continue
		var type: int = absi(board[i])
		var p := Vector2i(i % 8, i / 8)
		if type == 1:
			var q := p + Vector2i(0, -side)
			if inside(q) and board[q.y * 8 + q.x] == 0:
				add_move(out, i, q.y * 8 + q.x, true)
				if p.y == (6 if side == 1 else 1):
					q.y -= side
					if board[q.y * 8 + q.x] == 0: add_move(out, i, q.y * 8 + q.x)
			for dx in [-1, 1]:
				q = p + Vector2i(dx, -side)
				if not inside(q): continue
				var j := q.y * 8 + q.x
				if (board[j] * side < 0 and absi(board[j]) != 6) or (j == state.ep and board[j + side * 8] == -side): add_move(out, i, j, true)
			continue
		var directions: Array = []
		if type == 2: directions = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)]
		else:
			if type in [3, 5, 6]: directions.append_array([Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)])
			if type in [4, 5, 6]: directions.append_array([Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)])
		for direction in directions:
			var q: Vector2i = p + direction
			while inside(q):
				var j := q.y * 8 + q.x
				if board[j] * side > 0 or absi(board[j]) == 6: break
				add_move(out, i, j)
				if board[j] != 0 or type in [2, 6]: break
				q += direction
		if type == 6 and i == (60 if side == 1 else 4) and not in_check(state, side):
			var short_right := "K" if side == 1 else "k"
			var long_right := "Q" if side == 1 else "q"
			if state.rights.contains(short_right) and board[i + 3] == 4 * side and board[i + 1] == 0 and board[i + 2] == 0:
				if not attacked(board, i + 1, -side) and not attacked(board, i + 2, -side): add_move(out, i, i + 2)
			if state.rights.contains(long_right) and board[i - 4] == 4 * side and board[i - 1] == 0 and board[i - 2] == 0 and board[i - 3] == 0:
				if not attacked(board, i - 1, -side) and not attacked(board, i - 2, -side): add_move(out, i, i - 2)
	return out

static func apply(state: Dictionary, move: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var a: int = move.from
	var b: int = move.to
	var piece: int = next.board[a]
	var side: int = state.turn
	var capture: bool = next.board[b] != 0
	if absi(piece) == 1 and b == state.ep and next.board[b] == 0:
		next.board[b + side * 8] = 0
		capture = true
	next.board[b] = side * move.promo if move.promo != 0 else piece
	next.board[a] = 0
	if absi(piece) == 6:
		if absi(b - a) == 2:
			var rook_from := a + 3 if b > a else a - 4
			var rook_to := a + 1 if b > a else a - 1
			next.board[rook_to] = next.board[rook_from]
			next.board[rook_from] = 0
		for right in (["K", "Q"] if side == 1 else ["k", "q"]): next.rights = next.rights.replace(right, "")
	for pair in [[0, "q"], [7, "k"], [56, "Q"], [63, "K"]]:
		if a == pair[0] or b == pair[0]: next.rights = next.rights.replace(pair[1], "")
	next.ep = int((a + b) / 2) if absi(piece) == 1 and absi(b - a) == 16 else -1
	next.half = 0 if capture or absi(piece) == 1 else state.half + 1
	next.turn = -side
	return next

static func legal(state: Dictionary) -> Array:
	var out: Array = []
	for move in pseudo(state):
		if not in_check(apply(state, move), state.turn): out.append(move)
	return out

static func key(state: Dictionary) -> String:
	var ep := -1
	if state.ep >= 0:
		for move in legal(state):
			if move.to == state.ep and absi(state.board[move.from]) == 1:
				ep = state.ep
				break
	return str(state.board) + str(state.turn) + state.rights + str(ep)

static func insufficient(board: Array) -> bool:
	var minor: Array = []
	var colors: Dictionary = {}
	for i in range(64):
		var type: int = absi(board[i])
		if type in [1, 4, 5]: return false
		if type in [2, 3]:
			minor.append(type)
			colors[(i % 8 + int(i / 8)) % 2] = true
	if minor.size() <= 1: return true
	return not minor.has(2) and colors.size() == 1

static func evaluate(state: Dictionary) -> float:
	var score := 0.0
	for i in range(64):
		var piece: int = state.board[i]
		if piece == 0: continue
		var type := absi(piece)
		var side := signi(piece)
		var center := 7.0 - absf(i % 8 - 3.5) - absf(int(i / 8) - 3.5)
		var bonus := center * (5.0 if type in [2, 3] else 1.0)
		if type == 1: bonus += (6 - int(i / 8) if side == 1 else int(i / 8) - 1) * 7.0
		score += side * (VALUES[type] + bonus)
	return score

static func search(state: Dictionary, depth: int, alpha: float, beta: float) -> float:
	var moves := legal(state)
	if moves.is_empty(): return -state.turn * (100000.0 + depth) if in_check(state, state.turn) else 0.0
	if insufficient(state.board) or state.half >= 100: return 0.0
	if depth == 0: return evaluate(state)
	var value := -INF if state.turn == 1 else INF
	for move in moves:
		var candidate := search(apply(state, move), depth - 1, alpha, beta)
		if state.turn == 1:
			value = maxf(value, candidate)
			alpha = maxf(alpha, value)
		else:
			value = minf(value, candidate)
			beta = minf(beta, value)
		if beta <= alpha: break
	return value

static func ai(state: Dictionary) -> Dictionary:
	var moves := legal(state)
	var best: Dictionary = {}
	var value := INF
	for move in moves:
		var result := search(apply(state, move), 1, -INF, value)
		if result < value:
			value = result
			best = move
	return best
