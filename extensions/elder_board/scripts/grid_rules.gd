extends RefCounted
## Go uses positional superko; pass is exempt. Area scoring with 7.5 komi.
static func neighbors(i: int, n: int) -> Array[int]:
	var out: Array[int] = []
	if i % n > 0: out.append(i - 1)
	if i % n < n - 1: out.append(i + 1)
	if i >= n: out.append(i - n)
	if i < n * (n - 1): out.append(i + n)
	return out

static func group(board: Array, start: int, n: int) -> Dictionary:
	var stones: Array[int] = [start]
	var liberties: Dictionary = {}
	var seen: Dictionary = {start: true}
	var cursor := 0
	while cursor < stones.size():
		for j in neighbors(stones[cursor], n):
			if board[j] == board[start]:
				if not seen.has(j):
					seen[j] = true
					stones.append(j)
			elif board[j] == 0: liberties[j] = true
		cursor += 1
	return {"stones": stones, "liberties": liberties}

static func key(board: Array) -> String:
	return str(board)

static func go_move(board: Array, i: int, side: int, n: int, history: Dictionary) -> Dictionary:
	if i < 0 or i >= board.size() or board[i] != 0: return {}
	var next := board.duplicate()
	next[i] = side
	var captured := 0
	for j in neighbors(i, n):
		if next[j] != -side: continue
		var enemy := group(next, j, n)
		if enemy.liberties.is_empty():
			for stone in enemy.stones:
				next[stone] = 0
				captured += 1
	var own := group(next, i, n)
	if own.liberties.is_empty() or history.has(key(next)): return {}
	return {"board": next, "captured": captured, "liberties": own.liberties.size()}

static func go_score(board: Array, n: int) -> Vector2:
	var score := Vector2(0, 7.5)
	var seen: Dictionary = {}
	for i in range(board.size()):
		if board[i] == 1: score.x += 1
		elif board[i] == -1: score.y += 1
		elif not seen.has(i):
			var region := group(board, i, n)
			var borders: Dictionary = {}
			for stone in region.stones:
				seen[stone] = true
				for j in neighbors(stone, n):
					if board[j] != 0: borders[board[j]] = true
			if borders.size() == 1:
				if borders.has(1): score.x += region.stones.size()
				else: score.y += region.stones.size()
	return score

static func five(board: Array, i: int, side: int, n: int) -> bool:
	for direction in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var count := 1
		for sign_value in [-1, 1]:
			var p: Vector2i = Vector2i(i % n, i / n) + direction * sign_value
			while p.x >= 0 and p.y >= 0 and p.x < n and p.y < n and board[p.y * n + p.x] == side:
				count += 1
				p += direction * sign_value
		if count >= 5: return true
	return false

static func threat(board: Array, i: int, side: int, n: int) -> float:
	var value := 0.0
	for direction in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var count := 1
		var open := 0
		for sign_value in [-1, 1]:
			var p: Vector2i = Vector2i(i % n, i / n) + direction * sign_value
			while p.x >= 0 and p.y >= 0 and p.x < n and p.y < n and board[p.y * n + p.x] == side:
				count += 1
				p += direction * sign_value
			if p.x >= 0 and p.y >= 0 and p.x < n and p.y < n and board[p.y * n + p.x] == 0: open += 1
		if count >= 5: value += 1000000
		elif open > 0:
			value += pow(12.0, count) * (5.0 if open == 2 else 1.0)
	return value

static func gomoku_ai(board: Array, n: int) -> int:
	var best := -1
	var best_value := -INF
	for i in range(board.size()):
		if board[i] != 0: continue
		board[i] = -1
		var win := five(board, i, -1, n)
		board[i] = 0
		if win: return i
	for i in range(board.size()):
		if board[i] != 0: continue
		board[i] = 1
		var block := five(board, i, 1, n)
		board[i] = 0
		if block: return i
		var center := Vector2(i % n, i / n).distance_to(Vector2(n / 2, n / 2))
		var value := threat(board, i, -1, n) + threat(board, i, 1, n) * 1.1 - center
		if value > best_value:
			best_value = value
			best = i
	return best

static func go_ai(board: Array, n: int, history: Dictionary, human_passed: bool) -> int:
	var best := -1
	var best_value := -INF
	for i in range(board.size()):
		var move := go_move(board, i, -1, n, history)
		if move.is_empty(): continue
		var adjacent := neighbors(i, n)
		var own := 0
		var enemy := 0
		var save := 0
		for j in adjacent:
			if board[j] == -1:
				own += 1
				if group(board, j, n).liberties.size() == 1: save += 1
			elif board[j] == 1: enemy += 1
		# Avoid filling own eyes, unless necessary to capture or save a group.
		if own == adjacent.size() and move.captured == 0 and save == 0: continue
		var value: float = move.captured * 22 + save * 15 + mini(move.liberties, 5) * 1.3
		value += enemy * 1.2 + own * 0.6
		if move.liberties == 1: value -= 20
		var x := i % n
		var y := int(i / n)
		value -= absf(x - (n - 1) / 2.0) * 0.12 + absf(y - (n - 1) / 2.0) * 0.12
		if human_passed and move.captured == 0 and save == 0: continue
		if value > best_value:
			best_value = value
			best = i
	return best
