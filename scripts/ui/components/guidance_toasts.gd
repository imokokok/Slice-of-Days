extends Control
## One legible result beside the current direction, held while a modal is open.
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
var card: Button
var words: Label
var heading: Label
var age := 0.0
var entrance_age := 0.0
var lifetime := 14.0
var current: Dictionary={}
func _ready() -> void:
	name="GuidanceToast"; mouse_filter=MOUSE_FILTER_IGNORE
	card=preload("res://scripts/ui/components/solmere_button.gd").new(); card.variant="paper"; add_child(card)
	card.pressed.connect(_open_record)
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
		heading.text=str(current.get("heading","刚刚发生"))
		words.text=str(current.text); age=0; entrance_age=0; card.show()
		var actionable: bool=not current.get("target",{}).is_empty()
		card.focus_mode=FOCUS_ALL if actionable else FOCUS_NONE
		card.mouse_filter=MOUSE_FILTER_STOP if actionable else MOUSE_FILTER_IGNORE
		card.mouse_default_cursor_shape=CURSOR_POINTING_HAND if actionable else CURSOR_ARROW
		card.tooltip_text="打开这份记录" if actionable else ""
		card.accessibility_name=heading.text+"，"+words.text+("，打开这份记录" if actionable else "")
		if actionable: heading.text+="  ·  查看 →"
		card.size=Vector2(390,maxf(96,mini(6,words.get_line_count())*29+64))
		lifetime=reading_seconds(words.text)
	var direction: Control=get_parent().get("next_button")
	var bottom := 35.0
	if is_instance_valid(direction) and direction.visible: bottom=direction.position.y+direction.size.y+12
	card.position=Vector2(get_parent().size.x-card.size.x-36,bottom)
	# Let people finish reading; modal time and hovering do not consume the hold.
	if not card.get_global_rect().has_point(get_global_mouse_position()) and not card.has_focus(): age+=delta
	entrance_age+=delta
	card.modulate.a=minf(1,entrance_age/.16) if not SettingsSystem.reduced_motion() else 1
	card.position.y+=0 if SettingsSystem.reduced_motion() else 3*(1-minf(1,age/.16))
	if age>=lifetime: current={}; card.hide()

static func reading_seconds(value: String) -> float:
	return clampf(value.length()*.2+6,14,26)

func _open_record() -> void:
	var target: Dictionary=current.get("target",{})
	if target.is_empty() or not bool(UIStateSystem.policy().notify): return
	var shell=get_parent()
	if str(target.get("mode",""))=="recipe":
		var book=preload("res://scripts/ui/recipe_book_panel.gd").new()
		book.section="shared"
		for recipe in preload("res://scripts/core/recipe_book.gd").entries("shared"):
			if str(recipe.id)==str(target.recipe_id): book.chosen=recipe; break
		shell.add_child(book)
	else:
		shell.open_paper(str(target.get("mode","fieldbook")))
		if is_instance_valid(shell.overlay) and target.has("material_id"):
			shell.overlay._show_detail(str(target.material_id))
	current={}; card.hide()
func _exit_tree() -> void:
	if not current.is_empty() and age<lifetime-.4:
		for entry in current.entries:
			for text in entry.texts: GuidanceSystem.queue_feedback(str(entry.kind),str(text),entry.get("target",{}))
