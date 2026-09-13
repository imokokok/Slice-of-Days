extends RefCounted
## A data-only interpreter: never evaluates model-generated code.
static func validate(raw: Variant) -> String:
	if not raw is Dictionary: return "还缺一份完整规则。"
	var allowed := ["name", "kind", "width", "height", "target", "directions", "exact", "first", "moves", "capture", "goal", "start_rows"]
	for key in raw:
		if key not in allowed: return "还有未能执行的规则：" + str(key)
	if not raw.get("name") is String or raw.name.strip_edges().is_empty() or raw.name.length() > 40: return "这棋叫什么名字？"
	for field in ["width", "height"]:
		if not (raw.get(field) is int or raw.get(field) is float): return "棋盘有几行、几列？"
		if raw[field] != int(raw[field]) or int(raw[field]) < 3 or int(raw[field]) > 19: return "当前能摆 3 到 19 行、列的棋盘。"
	if raw.get("first") not in ["player", "elder"]: return "第一手由你下，还是我下？"
	if raw.get("kind") == "line":
		for field in ["moves", "capture", "goal", "start_rows"]:
			if raw.has(field): return "落子连线之外还有规则没确认：" + field
		if not (raw.get("target") is int or raw.get("target") is float): return "连成几个才算赢？"
		if raw.target != int(raw.target) or raw.target < 3 or raw.target > maxi(int(raw.width), int(raw.height)): return "连子数与棋盘大小对不上。"
		if not raw.get("exact") is bool: return "超过规定的连子数，也算赢吗？"
		if not raw.get("directions") is Array or raw.directions.is_empty(): return "横、竖、斜，哪些方向算赢？"
		for direction in raw.directions:
			if direction not in ["horizontal", "vertical", "diagonal"]: return "这个连线方向我还摆不出来。"
	elif raw.get("kind") == "capture":
		for field in ["target", "directions", "exact"]:
			if raw.has(field): return "移动棋之外还有规则没确认：" + field
		if not raw.get("moves") is Array or raw.moves.is_empty(): return "棋子可以往哪儿移动？"
		for move in raw.moves:
			if not move is Array or move.size() != 2: return "走法要说清横、竖各移动几格。"
			for value in move:
				if not (value is int or value is float) or value != int(value) or absi(int(value)) > 2: return "当前支持每步最多两格的固定走法。"
			if move[0] == 0 and move[1] == 0: return "一步不能停在原地。"
		if raw.get("capture") not in ["landing", "jump", "none"]: return "吃子是落到对方格子、跳过对方，还是不能吃？"
		if raw.get("goal") not in ["capture_all", "reach_edge"]: return "怎样才算赢：吃光对方，还是到达对面底线？"
		if not (raw.get("start_rows") is int or raw.get("start_rows") is float): return "开局时，双方各摆几排棋子？"
		if raw.start_rows != int(raw.start_rows) or raw.start_rows < 1 or raw.start_rows * 2 >= raw.height: return "双方开局之间得留出空行。"
		if raw.goal == "capture_all" and raw.capture == "none": return "不能吃子，就没办法以吃光对方取胜。"
		if raw.capture == "jump":
			for move in raw.moves:
				if absi(int(move[0])) > 1 or absi(int(move[1])) > 1: return "跳吃使用一步方向，再跳过相邻对方棋子。"
	else: return "这种棋还需要新的走棋规则支持；我不能假装已经学会。"
	return ""

static func summary(rule: Dictionary) -> String:
	if rule.is_empty(): return "先告诉我棋盘怎么摆、棋子怎么下、怎样才算赢。"
	if not validate(rule).is_empty(): return validate(rule)
	var text := "%s\n棋盘：%d 列 × %d 行\n先手：%s\n" % [rule.name, rule.width, rule.height, "你" if rule.first == "player" else "老人"]
	if rule.kind == "line":
		var names := {"horizontal": "横", "vertical": "竖", "diagonal": "斜"}
		var directions: Array[String] = []
		for d in rule.directions: directions.append(names[d])
		text += "轮流在空点落一子，不移动、不吃子。\n%s方向连成%d子获胜；%s。\n棋盘满且无人获胜则和棋。" % ["、".join(directions), rule.target, "必须恰好相连，长连不算" if rule.exact else "达到或超过都算"]
	else:
		text += "双方底部各摆%d整排。\n走法（横,前进）：%s\n吃子：%s；目标：%s。\n一步一动，无连续跳吃与升变。无合法走法的一方输；200步未分胜负和棋。" % [rule.start_rows, str(rule.moves), {"landing": "走到敌子格", "jump": "跳过相邻敌子", "none": "不吃子"}[rule.capture], "吃光对方" if rule.goal == "capture_all" else "任一棋子到达对方底线"]
	return text

static func initial(rule: Dictionary) -> Array:
	var board: Array = []
	board.resize(int(rule.width) * int(rule.height))
	board.fill(0)
	if rule.kind == "capture":
		for y in range(int(rule.start_rows)):
			for x in range(int(rule.width)):
				board[y * int(rule.width) + x] = -1
				board[(int(rule.height) - 1 - y) * int(rule.width) + x] = 1
	return board

static func legal(board: Array, side: int, rule: Dictionary) -> Array:
	var out: Array = []
	var w := int(rule.width)
	var h := int(rule.height)
	for i in range(board.size()):
		if rule.kind == "line":
			if board[i] == 0: out.append({"from": -1, "to": i, "take": -1})
			continue
		if board[i] != side: continue
		var p := Vector2i(i % w, i / w)
		for step in rule.moves:
			var d := Vector2i(int(step[0]), -side * int(step[1]))
			var q := p + d
			if q.x < 0 or q.x >= w or q.y < 0 or q.y >= h: continue
			var j := q.y * w + q.x
			if board[j] == 0 or (board[j] == -side and rule.capture == "landing"):
				out.append({"from": i, "to": j, "take": j if board[j] == -side else -1})
			elif board[j] == -side and rule.capture == "jump":
				q += d
				if q.x >= 0 and q.x < w and q.y >= 0 and q.y < h and board[q.y * w + q.x] == 0:
					out.append({"from": i, "to": q.y * w + q.x, "take": j})
	return out

static func apply(board: Array, move: Dictionary, side: int) -> Array:
	var next := board.duplicate()
	if move.from >= 0: next[move.from] = 0
	if move.take >= 0: next[move.take] = 0
	next[move.to] = side
	return next

static func won(board: Array, side: int, rule: Dictionary) -> bool:
	var w := int(rule.width)
	var h := int(rule.height)
	if rule.kind == "capture":
		if rule.goal == "capture_all": return not board.has(-side)
		for x in range(w):
			if board[(0 if side == 1 else h - 1) * w + x] == side: return true
		return false
	var mapping := {"horizontal": Vector2i(1, 0), "vertical": Vector2i(0, 1), "diagonal": Vector2i(1, 1)}
	var directions: Array = []
	for name in rule.directions:
		directions.append(mapping[name])
		if name == "diagonal": directions.append(Vector2i(1, -1))
	for i in range(board.size()):
		if board[i] != side: continue
		for d in directions:
			var p := Vector2i(i % w, i / w)
			var previous: Vector2i = p - d
			if previous.x >= 0 and previous.y >= 0 and previous.x < w and previous.y < h and board[previous.y * w + previous.x] == side: continue
			var count := 0
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and board[p.y * w + p.x] == side:
				count += 1
				p += d
			if count == int(rule.target) or (count > int(rule.target) and not rule.exact): return true
	return false

static func ai(board: Array, rule: Dictionary) -> Dictionary:
	var moves := legal(board, -1, rule)
	var best: Dictionary = {}
	var best_score := -INF
	var threats: Dictionary = {}
	for move in legal(board, 1, rule):
		if won(apply(board, move, 1), 1, rule): threats[move.to] = true
	for move in moves:
		var next := apply(board, move, -1)
		if won(next, -1, rule): return move
		var score := 20.0 if move.take >= 0 else 0.0
		if threats.has(move.to): score += 1000
		var w := int(rule.width)
		var p := Vector2(move.to % w, int(move.to / w))
		score -= p.distance_to(Vector2((w - 1) / 2.0, (int(rule.height) - 1) / 2.0))
		if rule.kind == "capture" and rule.goal == "reach_edge": score += p.y * 3
		if score > best_score:
			best_score = score
			best = move
	return best
