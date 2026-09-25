extends CanvasLayer

var world: Node2D
var copies: Dictionary = {}

func _ready() -> void :
	layer = 2

func _process(_delta: float) -> void :
	var wanted: Array[Node2D] = []
	if world.controls_enabled:
		if world.pan.active or world.pan.falling:
			wanted.append(world.pan.pan_back)
			wanted.append(world.pan.pan_front)
			wanted.append(world.pan.pan_surface)
			for body in world._foods.get_children():
				if body == world._held or body.is_queued_for_deletion(): continue
				if world.pan.is_carrying(body) or (body.get_meta("poured", false) and not body.get_meta("plated", false)):
					var art: Node2D = body.get_node_or_null("FoodArt")
					if art == null: art = body.get_node_or_null("SauceBlob")
					if art: wanted.append(art)
		for tool in world.utensils:
			if tool.active:
				wanted.append(tool)
				if tool.kind == "spoon":
					for body in tool.bowl_contents():
						var art: Node2D = body.get_node_or_null("FoodArt")
						if art: wanted.append(art)
					if is_instance_valid(tool._rim_visual): wanted.append(tool._rim_visual)
	for id in copies.keys():
		var entry: Dictionary = copies[id]
		if not is_instance_valid(entry.source) or not wanted.has(entry.source):
			if is_instance_valid(entry.source): entry.source.visible = true
			entry.proxy.queue_free()
			copies.erase(id)
	for source in wanted:
		var id: = source.get_instance_id()
		if not copies.has(id):
			var proxy: = Node2D.new()
			if world.utensils.has(source) or source.has_method("paint"):
				proxy.set_script(preload("res://modules/restaurant/world/utensil_proxy.gd"))
				proxy.source = source
			else:
				proxy.set_script(source.get_script())
				for property in source.get_property_list():
					if str(property.name) in ["controller", "definition", "cut", "heat", "softness", "thermal", "coating", "compression", "shadows", "polygon", "art_offset", "dispense_mode", "liquid_state", "cut_style", "cut_variant", "source_fraction"]:
						proxy.set(property.name, source.get(property.name))
			add_child(proxy)
			copies[id] = {"source": source, "proxy": proxy}
		var visual: Node2D = copies[id].proxy
		visual.transform = source.get_global_transform_with_canvas()
		# Proxies remain views of the live food, including while it keeps cooking.
		for property_name in ["cut", "heat", "softness", "thermal", "coating", "compression", "liquid_state"]:
			if property_name in source and property_name in visual: visual.set(property_name, source.get(property_name))
		var spoon_rim: = source.name == "SpoonFrontRim"
		var spoon_food: = source.get_parent() is RigidBody2D and _spoon_holds(source.get_parent())
		visual.z_index = 0 if source == world.pan.pan_back else (7 if spoon_rim else (6 if spoon_food else (5 if world.utensils.has(source) else (4 if source == world.pan.pan_front else (3 if source == world.pan.pan_surface else (1 if source.name == "SauceBlob" else 2))))))
	# Keep overlapping carried pieces in the same depth order as the kitchen.
	var ordered := copies.values()
	ordered.sort_custom(func(a, b): return a.source.get_global_transform_with_canvas().origin.y < b.source.get_global_transform_with_canvas().origin.y)
	for index in ordered.size(): move_child(ordered[index].proxy, index)
	for entry in copies.values():
		entry.proxy.queue_redraw()
		entry.source.visible = false

func _exit_tree() -> void :
	for entry in copies.values():
		if is_instance_valid(entry.source): entry.source.visible = true
	copies.clear()

func _spoon_holds(body: RigidBody2D) -> bool:
	for tool in world.utensils:
		if tool.kind == "spoon" and tool.bowl_contains(body): return true
	return false
