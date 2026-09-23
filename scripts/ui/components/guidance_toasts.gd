extends Control
## One legible result beside the current direction, held while a modal is open.
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
var card: Panel
var words: Label
var heading: Label
var age := 0.0
var lifetime := 14.0
var current: Dictionary={}
func _ready() -> void:
	name="GuidanceToast"; mouse_filter=MOUSE_FILTER_IGNORE
	card=Panel.new(); card.mouse_filter=MOUSE_FILTER_IGNORE
	var face := PALETTE.face(PALETTE.CREAM,8,0)
	face.border_width_left=3; face.border_color=PALETTE.SAGE; card.add_theme_stylebox_override("panel",face); add_child(card)
	heading=PALETTE.words(card,"",Vector2(22,15),346,15,PALETTE.MUTED)
	words=PALETTE.words(card,"",Vector2(22,44),346,19,PALETTE.INK)
	words.max_lines_visible=6; words.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	card.hide()
func _process(delta: float) -> void:
	var clear := bool(UIStateSystem.policy().notify)
	visible=clear
	if not clear: return
	if current.is_empty():
		current=GuidanceSystem.take_feedback()
		if current.is_empty(): return
		heading.text=LocalizationSystem.text(str(current.get("heading","刚刚发生")))
		words.text=LocalizationSystem.text(str(current.text)); age=0; card.show()
		card.size=Vector2(390,maxf(96,mini(6,words.get_line_count())*29+64))
		lifetime=reading_seconds(words.text)
	var direction: Control=get_parent().get("next_button")
	var bottom := 35.0
	if is_instance_valid(direction) and direction.visible: bottom=direction.position.y+direction.size.y+12
	card.position=Vector2(get_parent().size.x-card.size.x-36,bottom)
	# Let people finish reading; modal time and hovering do not consume the hold.
	if not card.get_global_rect().has_point(get_global_mouse_position()): age+=delta
	card.modulate.a=1
	card.position.y+=0 if SettingsSystem.reduced_motion() else 3*(1-minf(1,age/.16))
	if age>=lifetime: current={}; card.hide()

static func reading_seconds(value: String) -> float:
	return clampf(value.length()*.2+6,14,26)
func _exit_tree() -> void:
	if not current.is_empty() and age<lifetime-.4:
		for entry in current.entries:
			for text in entry.texts: GuidanceSystem.queue_feedback(str(entry.kind),str(text))
