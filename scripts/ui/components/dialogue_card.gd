extends Panel
## A compact speech surface and independently placed native responses.
## The panel bounds describe the speech only: choices never inflate the bubble.
const Layout = preload("res://scripts/ui/components/dialogue_layout.gd")
const Palette = preload("res://scripts/ui/components/interface_palette.gd")
var speaker_label: Label
var text_label: Label
var hint_label: Label
var choices: VBoxContainer
var stage: Control
var target_id := ""
var previous := Rect2()
var previous_choices := Rect2()
var transition: Tween
var content: Control
var body_scroll: ScrollContainer
var last_body := ""
var settled := false
var layout_elapsed := 0.0
var body_width := 350.0
var minimum_body_height := 156.0
var additional_obstacles: Array[Rect2]=[]
var layout_signature := 0

func _ready() -> void:
	add_to_group("scene_speech")
	mouse_filter=MOUSE_FILTER_IGNORE
	var face := Palette.face(Palette.SPEECH,12,0)
	face.set_border_width_all(1)
	face.border_color=Color("91a7ad")
	add_theme_stylebox_override("panel",face)
	content=Control.new(); content.mouse_filter=MOUSE_FILTER_IGNORE; add_child(content)
	speaker_label=_label(17,Palette.SEA)
	speaker_label.add_theme_font_override("font",PaperLanguage.handwriting)
	text_label=_label(22,Palette.SPEECH_INK)
	body_scroll=ScrollContainer.new(); body_scroll.name="DialogueReadingArea"
	body_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(body_scroll); text_label.reparent(body_scroll)
	text_label.size_flags_horizontal=SIZE_EXPAND_FILL
	hint_label=_label(14,Palette.SPEECH_MUTED)
	set_process(true)

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter=MOUSE_FILTER_IGNORE
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.custom_maximum_size.x=body_width
	label.visible_characters_behavior=TextServer.VC_CHARS_AFTER_SHAPING
	label.add_theme_font_override("font",PaperLanguage.body_font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_constant_override("outline_size",0)
	label.add_theme_constant_override("line_spacing",4)
	content.add_child(label)
	return label

func configure(world: Control, npc_id := "") -> void:
	stage=world; target_id=npc_id

func _height(label: Label, width: float) -> float:
	if label.text.is_empty(): return 0
	label.custom_maximum_size.x=width
	label.size.x=width
	var fs := label.get_theme_font_size("font_size")
	return maxf(fs+6,label.get_line_count()*(label.get_line_height()+4))

func _measure(column: float) -> Vector2:
	var y := 17.0
	for label in [speaker_label,text_label,hint_label]:
		# Reserve a comfortable reading area before revealing a single character.
		# Dialogue is paginated by its owner; punctuation and speaker changes
		# must not resize the backing or move the controls.
		var height := maxf(156.0,minimum_body_height) if label==text_label else 25.0
		label.custom_maximum_size.x=column
		if label==text_label:
			body_scroll.position=Vector2(22,y); body_scroll.size=Vector2(column,height)
			label.position=Vector2.ZERO; label.size.x=column-18
			if last_body!=label.text:
				body_scroll.scroll_vertical=0; last_body=label.text
		else:
			label.position=Vector2(22,y); label.size=Vector2(column,height)
		if height>0: y+=height+(11 if label==text_label else 6)
	return Vector2(column+44,y+11)

func _choice_extent(width: float) -> Vector2:
	var height := 0.0
	for button: Button in choices.get_children():
		button.custom_maximum_size.x=width
		var font := button.get_theme_font("font")
		var fs := button.get_theme_font_size("font_size")
		var measured := font.get_multiline_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,width-42,fs,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND)
		button.custom_minimum_size=Vector2(0,maxf(44,measured.y+20))
		height+=button.custom_minimum_size.y+8
	return Vector2(width,maxf(0,height-8))

func layout(animate := false) -> void:
	if not is_instance_valid(content): return
	var available := get_viewport_rect()
	var actors: Array=[]; var scenery: Array=[]
	var anchor := available.get_center()
	if is_instance_valid(stage) and stage.has_method("dialogue_obstacles"):
		var context: Dictionary=stage.dialogue_obstacles(target_id)
		actors=context.actors; scenery=context.scenery; anchor=context.anchor
	# Draggable memories and faces are hard exclusions, not aesthetic suggestions.
	actors+=additional_obstacles
	var option_texts: Array=[]
	if is_instance_valid(choices):
		for button: Button in choices.get_children(): option_texts.append(button.text)
	var signature := hash([available,text_label.text,speaker_label.text,hint_label.text,hint_label.visible,option_texts,actors,scenery,body_width,minimum_body_height])
	if settled and signature==layout_signature and not animate: return
	layout_signature=signature
	var column := minf(body_width,maxf(220,available.size.x-96))
	size=_measure(column)
	content.size=size
	var result := Layout.place(available,size,actors,scenery,anchor,previous)
	if not settled:
		var reserved := Layout.place(available,Vector2(size.x,size.y+288),actors,scenery,anchor)
		if Layout.occlusion_cost(reserved,actors,scenery)==0: result.position=reserved.position
	elif available.grow(-32).encloses(previous) and Layout.overlap(previous,actors)==0:
		result.position=previous.position
	if is_instance_valid(choices):
		var extent := _choice_extent(minf(326,available.size.x-64))
		# Reflow the two distinct surfaces together when a free side column
		# exists, so choices cannot silently jump ABOVE the line they answer.
		var combined := Vector2(maxf(size.x,extent.x),size.y+16+extent.y)
		var prior_stack := Rect2()
		if previous_choices.has_area() and absf(previous_choices.position.y-previous.end.y-16)<1:
			prior_stack=Rect2(previous.position,combined)
		var stacked := Layout.place(available,combined,actors,scenery,anchor,prior_stack)
		var use_stack := Layout.occlusion_cost(stacked,actors,scenery)==0 and stacked.position.y>=available.size.y*.28
		if use_stack and not settled: result.position=stacked.position
		use_stack=Layout.occlusion_cost(Rect2(result.position,combined),actors,scenery)==0 and available.grow(-32).encloses(Rect2(result.position,combined))
		var preferred := Vector2(result.position.x,result.end.y+16)
		var exclusions := actors.duplicate()
		exclusions.append(result.grow(12))
		var placed := Rect2(preferred,extent) if use_stack else Layout.place(available,extent,exclusions,scenery,anchor,previous_choices,preferred)
		previous_choices=placed
		choices.position=placed.position-result.position; choices.size=extent
	else: previous_choices=Rect2()
	previous=result; position=result.position
	if animate or not settled: reveal()
	settled=true

func reading_rects() -> Array[Rect2]:
	var result: Array[Rect2]=[get_global_rect()]
	if is_instance_valid(choices):
		for button: Button in choices.get_children(): result.append(button.get_global_rect())
	return result

func reveal() -> void:
	if transition: transition.kill()
	# The backing and ink stay opaque even during the restrained entrance.
	modulate=Color.WHITE; content.modulate=Color.WHITE
	content.position=Vector2.ZERO
	if SettingsSystem.reduced_motion(): return
	content.position.y=2
	transition=create_tween()
	transition.tween_property(content,"position:y",0.0,.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func dismiss() -> void:
	# No translucent outgoing copy over the next line or the newly freed scene.
	if transition: transition.kill()
	hide()

func attach_choices(box: VBoxContainer) -> void:
	choices=box; add_child(box)
	box.add_theme_constant_override("separation",8)
	layout(true)
	layout.call_deferred()

func clear_choices() -> void:
	if is_instance_valid(choices):
		choices.get_parent().remove_child(choices)
		choices.queue_free()
	choices=null; previous_choices=Rect2()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	layout_elapsed+=delta
	if layout_elapsed>.15:
		layout_elapsed=0
		layout()
