extends Control
const Art = preload("res://extensions/elder_board/scripts/table_art.gd")

func _ready() -> void:
	size = Vector2(1579, 972)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	Art.tabletop(self)
	Art.grid(self, 9)
	for row in [[2, 2, 1], [3, 2, -1], [5, 5, 1], [5, 4, -1], [4, 4, 1]]:
		Art.stone(self, Art.ORIGIN + Vector2(row[0], row[1]) * 76, 24, row[2])
