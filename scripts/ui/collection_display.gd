extends Control
## Original geometric room props, drawn from the actually owned collection.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EconomySystem.changed.connect(queue_redraw)
	GameState.state_changed.connect(queue_redraw)

func _draw() -> void:
	var counts := {}
	for item in EconomySystem.state().collections.values():
		var slot := str(item.slot)
		var used := int(counts.get(slot,0))
		counts[slot] = used+1
		var coordinates: Array = EconomySystem.config.collection_slots.get(slot,[375,430])
		var at := Vector2(float(coordinates[0])+used*64,float(coordinates[1]))
		var color := Color(str(item.color))
		draw_rect(Rect2(at+Vector2(-24,14),Vector2(66,5)),Color("684c3a"))
		match str(item.form):
			"cup":
				draw_colored_polygon(PackedVector2Array([at+Vector2(-20,-30),at+Vector2(22,-24),at+Vector2(15,14),at+Vector2(-15,10)]),color)
				draw_arc(at+Vector2(23,-9),13,-PI*.5,PI*.5,14,color,7)
				draw_line(at+Vector2(-16,-22),at+Vector2(18,-19),Color("e9dcc4"),5)
			"tag":
				draw_arc(at+Vector2(0,-36),8,0,TAU,18,Color("b79860"),3)
				draw_rect(Rect2(at+Vector2(-18,-26),Vector2(36,38)),color)
				draw_string(ThemeDB.fallback_font,at+Vector2(-14,-4),"307",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("efe2c1"))
			"can":
				draw_rect(Rect2(at+Vector2(-19,-36),Vector2(38,48)),color)
				draw_rect(Rect2(at+Vector2(-22,-39),Vector2(44,5)),Color("b8bba7"))
				draw_circle(at+Vector2(0,-12),10,Color("e2cc8d"))
			_:
				draw_rect(Rect2(at+Vector2(-24,-37),Vector2(48,49)),Color("e9dcc4"))
				draw_rect(Rect2(at+Vector2(-19,-31),Vector2(38,30)),color)
				draw_line(at+Vector2(-15,-13),at+Vector2(16,-19),Color("739199"),8)
		var title := str(item.nickname) if not str(item.nickname).is_empty() else str(item.name)
		draw_string(ThemeDB.fallback_font,at+Vector2(-30,32),title.left(10),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("39483f"))
