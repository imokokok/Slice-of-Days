extends Button
## Shared functional button. Selection is distinct from transient pressed/focus.
var selected := false:
	set(value):
		selected=value
		if is_inside_tree(): refresh()
func _ready() -> void:
	focus_mode=FOCUS_ALL
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	refresh()
func refresh() -> void:
	PaperLanguage.button_style(self,false)
	if selected:
		var face := StyleBoxFlat.new()
		face.bg_color=PaperLanguage.YELLOW; face.set_corner_radius_all(6)
		face.set_content_margin_all(10)
		add_theme_stylebox_override("normal",face)
