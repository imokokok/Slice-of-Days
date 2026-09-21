extends Panel
## Shared native dialogue presentation. Story ownership remains with its caller.
const Layout = preload("res://scripts/ui/components/dialogue_layout.gd")
var speaker_label: Label
var text_label: Label
var hint_label: Label
var choices: VBoxContainer
var stage: Control
var target_id := ""
var previous := Rect2()
var transition: Tween
var content: Control
var settled := false
var layout_elapsed := 0.0
var body_width := 430.0
var minimum_body_height := 0.0
var side_by_side := false
var additional_obstacles: Array[Rect2]=[]
var layout_signature := 0

func _ready() -> void:
	add_to_group("scene_speech")
	mouse_filter=MOUSE_FILTER_IGNORE
	var face := StyleBoxFlat.new()
	face.bg_color=Color("faf9f2")
	face.set_corner_radius_all(6)
	face.border_width_top=2; face.border_color=Color("eed577")
	add_theme_stylebox_override("panel",face)
	content=Control.new(); content.mouse_filter=MOUSE_FILTER_IGNORE; add_child(content)
	speaker_label=_label(17,Color("31658b"))
	text_label=_label(23,Color("283b43"))
	hint_label=_label(13,Color("657981"))
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
	label.add_theme_constant_override("line_spacing",5)
	content.add_child(label)
	return label

func configure(world: Control, npc_id := "") -> void:
	stage=world; target_id=npc_id

func _height(label: Label, width: float) -> float:
	if label.text.is_empty(): return 0
	# Godot 4.7 wraps against custom_maximum_size. Measure the actual shaped
	# Label instead of carrying a one-character-wide initial minimum height.
	label.custom_maximum_size.x=width
	label.size.x=width
	var fs := label.get_theme_font_size("font_size")
	return maxf(fs+8,label.get_line_count()*(label.get_line_height()+5))

func _measure(column: float, split: bool) -> Vector2:
	var y := 22.0
	speaker_label.custom_maximum_size.x=column
	speaker_label.position=Vector2(26,y); speaker_label.size=Vector2(column,25)
	if not speaker_label.text.is_empty(): y+=33
	text_label.position=Vector2(26,y)
	text_label.size=Vector2(column,maxf(minimum_body_height,_height(text_label,column)))
	y+=text_label.size.y
	var choices_bottom := 0.0
	var total_width := column+52
	if is_instance_valid(choices):
		var choice_width := 340.0 if split else column+16
		var choice_height := 0.0
		for button: Button in choices.get_children():
			button.custom_maximum_size.x=choice_width
			var font := button.get_theme_font("font")
			var fs := button.get_theme_font_size("font_size")
			var measured := font.get_multiline_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,choice_width-40,fs,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND)
			button.custom_minimum_size=Vector2(0,maxf(46,measured.y+24))
			choice_height+=button.custom_minimum_size.y+3
		if split:
			choices.position=Vector2(column+58,22)
			total_width=column+58+choice_width+18
		else:
			y+=18
			choices.position=Vector2(18,y)
		choices.size=Vector2(choice_width,maxf(0,choice_height-3))
		choices_bottom=choices.position.y+choices.size.y
		if not split: y=choices_bottom
	if hint_label.visible and not hint_label.text.is_empty():
		y+=18; hint_label.position=Vector2(26,y)
		hint_label.size=Vector2(column,_height(hint_label,column)); y+=hint_label.size.y
	return Vector2(total_width,maxf(y,choices_bottom)+20)

func layout(animate := false) -> void:
	if not is_instance_valid(content): return
	var available := get_viewport_rect()
	var actors: Array=[]; var scenery: Array=[]
	var anchor := available.get_center()
	if is_instance_valid(stage) and stage.has_method("dialogue_obstacles"):
		var context: Dictionary=stage.dialogue_obstacles(target_id)
		actors=context.actors; scenery=context.scenery; anchor=context.anchor
	scenery+=additional_obstacles
	var option_texts: Array=[]
	if is_instance_valid(choices):
		for button: Button in choices.get_children(): option_texts.append(button.text)
	var signature := hash([available,text_label.text,speaker_label.text,hint_label.text,hint_label.visible,option_texts,actors,scenery,body_width,minimum_body_height])
	if settled and signature==layout_signature and not animate: return
	layout_signature=signature
	var best_score := INF
	var result := Rect2()
	var best_column := body_width
	var best_split := false
	for split in [false,true]:
		if split and not is_instance_valid(choices): continue
		for width in [body_width,380.0,330.0]:
			var column := minf(width,maxf(240,available.size.x-112))
			var extent := _measure(column,split)
			if extent.x>available.size.x-64 or extent.y>available.size.y-64: continue
			var candidate := Layout.place(available,extent,actors,scenery,anchor,previous)
			var score := Layout.occlusion_cost(candidate,actors,scenery)
			score+=candidate.get_center().distance_to(anchor)
			score+=(body_width-column)*2+ (200 if split else 0)
			if previous.has_area(): score+=candidate.position.distance_to(previous.position)*2
			if score<best_score:
				best_score=score; result=candidate; best_column=column; best_split=split
	# The supported dialogue catalog fits within these measured layouts.
	if not result.has_area():
		var extent := _measure(330,false)
		result=Layout.place(available,extent,actors,scenery,anchor,previous)
		best_column=330
	size=_measure(best_column,best_split)
	side_by_side=best_split
	content.size=size
	var moving := previous.has_area() and previous.position.distance_to(result.position)>24
	previous=result
	position=result.position
	if animate or moving or not settled: reveal()
	settled=true
	queue_redraw()

func _draw() -> void:
	if side_by_side and is_instance_valid(choices):
		var x := choices.position.x-16
		draw_line(Vector2(x,24),Vector2(x,size.y-24),Color("31658b",.16),1,true)

func reveal() -> void:
	if transition: transition.kill()
	if SettingsSystem.reduced_motion(): modulate.a=1; content.position=Vector2.ZERO; return
	modulate.a=0; content.position=Vector2(0,4)
	transition=create_tween().set_parallel(true)
	transition.tween_property(self,"modulate:a",1.0,.16)
	transition.tween_property(content,"position",Vector2.ZERO,.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func dismiss() -> void:
	# A detached, input-transparent copy carries only the outgoing visual.
	# The actual conversation can free immediately, restoring walking on Esc.
	if SettingsSystem.reduced_motion() or not visible: return
	var ghost := duplicate(0) as Panel
	ghost.set_script(null)
	ghost.add_to_group("scene_speech")
	ghost.mouse_filter=MOUSE_FILTER_IGNORE
	for node in ghost.find_children("*","Control",true,false):
		node.set_script(null)
		node.mouse_filter=MOUSE_FILTER_IGNORE; node.focus_mode=Control.FOCUS_NONE
	get_tree().current_scene.add_child(ghost)
	ghost.global_position=global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost,"modulate:a",0.0,.12)
	tween.tween_callback(ghost.queue_free)

func attach_choices(box: VBoxContainer) -> void:
	choices=box; content.add_child(box)
	box.add_theme_constant_override("separation",3)
	layout(true)
	# Native containers finish wrapping before the second placement pass.
	layout.call_deferred()

func clear_choices() -> void:
	if is_instance_valid(choices):
		choices.get_parent().remove_child(choices)
		choices.queue_free()
	choices=null

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	layout_elapsed+=delta
	if layout_elapsed>.15:
		layout_elapsed=0
		layout()
