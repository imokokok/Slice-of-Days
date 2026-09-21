extends RefCounted
## Places the entire reading block, not an unrelated bubble and choice menu.
## Actor silhouettes are hard exclusions; scenery is the next priority.
static func overlap(rect: Rect2, obstacles: Array) -> float:
	var area := 0.0
	for obstacle: Rect2 in obstacles:
		area += rect.intersection(obstacle).get_area()
	return area

static func occlusion_cost(rect: Rect2, actors: Array, scenery: Array) -> float:
	var actor_area := overlap(rect,actors)
	return (1.0e12 if actor_area>0 else 0.0)+actor_area*100000.0+overlap(rect,scenery)*100.0

static func place(view: Rect2, extent: Vector2, actors: Array, scenery: Array, anchor: Vector2, previous := Rect2()) -> Rect2:
	var bounds := view.grow(-32)
	var xs: Array[float] = [bounds.position.x, bounds.end.x-extent.x, anchor.x-extent.x-80, anchor.x+80]
	var ys: Array[float] = [bounds.end.y-extent.y, bounds.position.y+40, anchor.y-extent.y*.5]
	for obstacle: Rect2 in actors+scenery:
		xs.append(obstacle.position.x-extent.x-24); xs.append(obstacle.end.x+24)
		ys.append(obstacle.position.y-extent.y-24); ys.append(obstacle.end.y+24)
	if previous.has_area():
		xs.push_front(previous.position.x); ys.push_front(previous.position.y)
	var best := Rect2(bounds.position,extent)
	var best_score := INF
	for x in xs:
		for y in ys:
			var at := Vector2(clampf(x,bounds.position.x,maxf(bounds.position.x,bounds.end.x-extent.x)),clampf(y,bounds.position.y,maxf(bounds.position.y,bounds.end.y-extent.y)))
			var candidate := Rect2(at,extent)
			var score := occlusion_cost(candidate,actors,scenery)
			score += candidate.get_center().distance_to(anchor)
			# Keep a conversation in the same reading location unless something
			# genuinely occludes it. This also tolerates the camera settling.
			if previous.has_area(): score += at.distance_to(previous.position)*2.0
			if score<best_score: best=candidate; best_score=score
	return best
