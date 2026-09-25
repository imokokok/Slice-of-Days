extends RefCounted
## Deterministic compressed thermal stepping; rigid poses are those reached by play.
static func cook(game: Node,seconds: float) -> void:
	game.world.set_cooking(game.session.heating)
	game.world.set_heat_level(game.session.heat_level)
	game.world.reactions.advance(seconds)
	for entry in game.session.dish:
		var key:=int(entry.get("physics_id",0))
		if key>0 and is_instance_id_valid(key): game.world.synchronize_body_state(instance_from_id(key),entry)
	game.world.set_dish(game.session.dish,game.session.ingredients)
