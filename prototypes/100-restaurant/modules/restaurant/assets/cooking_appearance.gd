extends RefCounted
## Shared visual interpretation of the same dose used by dish evaluation.
## Heat is accumulated cooking dose in game seconds, not degrees Celsius.
static func state(definition: Dictionary, heat: float) -> Dictionary:
	var id := str(definition.get("id", ""))
	var tags: Array = definition.get("tags", [])
	var profile := 0
	if id in ["chicken", "pork", "beef", "sausage", "shrimp", "squid"] or "meat" in tags:
		profile = 1
	elif id in ["lettuce", "spinach", "cabbage", "broccoli", "seaweed"]:
		profile = 2
	return {"cooked": clampf(heat / 6.0, 0, 1), "browned": clampf((heat - 7.0) / 7.0, 0, 1), "charred": clampf((heat - 14.0) / 16.0, 0, 1), "food_profile": profile}

static func edge_color(definition: Dictionary, heat: float) -> Color:
	var result := Color(str(definition.get("color", "d9b18c"))).lightened(0.28)
	var appearance := state(definition, heat)
	if appearance.food_profile == 1:
		result = result.lerp(Color("d3b28a"), appearance.cooked)
	return result.lerp(Color("9e6335"), appearance.browned * 0.65).lerp(Color("30251c"), appearance.charred)
