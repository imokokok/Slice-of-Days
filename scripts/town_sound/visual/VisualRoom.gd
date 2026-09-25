extends Control
var studio: Control
var model: Arrangement
var audio: AudioStreamWAV
var player: AudioStreamPlayer
var canvas: VisualCanvas
var viewport: SubViewport
var column: VBoxContainer
var status: Label
var prompt_input: LineEdit
var pressing: Control
var submitting := false
var listening_controls: Array[BaseButton] = []

var page: Control
func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
	var bg:=ColorRect.new(); bg.color=Color("e3cbb0"); bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT); bg.mouse_filter=MOUSE_FILTER_IGNORE; add_child(bg)
	page=Control.new(); page.size=Vector2(1600,900); add_child(page)
	resized.connect(_fit_page); _fit_page()
	column=VBoxContainer.new(); column.position=Vector2(250,36); column.size=Vector2(1100,830)
	column.add_theme_constant_override("separation",15); page.add_child(column)
	column.add_child(studio.label("先把这张声音明信片，放给老板听。",30))
	column.add_child(studio.label("接下来：定格封面 → 装标签 → 拉下压机 → 三层包装 → 留在唱片架",19))
	var container:=SubViewportContainer.new(); container.custom_minimum_size=Vector2(960,540); container.stretch=true
	column.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(960,540); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	canvas=VisualCanvas.new(); canvas.size=Vector2(960,540); canvas.model=model
	canvas.configure(audio,model.prompt,model.seed_value); viewport.add_child(canvas)
	player=AudioStreamPlayer.new(); player.bus="Music"; player.stream=audio; add_child(player)
	# Keep project compatibility without exposing seed/prompt/mode configuration.
	prompt_input=LineEdit.new(); prompt_input.text=model.prompt; prompt_input.hide(); add_child(prompt_input)
	var controls:=HBoxContainer.new(); controls.add_theme_constant_override("separation",18); column.add_child(controls)
	var listen:Button=studio.button("▶ 再听一遍",func(): player.play())
	var submit_button:Button=studio.button("请老板试听，开始制作 →",submit)
	controls.add_child(listen); controls.add_child(submit_button)
	controls.add_child(studio.button("回去剪贴",func():
		if not model.save_project(): status.text=model.error; return
		studio.show(); queue_free()))
	listening_controls=[listen,submit_button]
	status=studio.label("一小段声音也能做唱片。委托是额外挑战，不影响自由制作。",19)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(status)
	player.play()

func _fit_page() -> void:
	if page==null: return
	var factor:=minf(size.x/1600.0,size.y/900.0)
	page.scale=Vector2.ONE*factor; page.position=(size-Vector2(1600,900)*factor)*.5

func generate() -> bool:
	model.prompt = prompt_input.text
	var mode := str(canvas.profile.get("mode","pixel"))
	canvas.configure(audio, model.prompt, model.seed_value)
	canvas.profile["mode"]=mode
	if not model.save_project():
		status.text = LocalizationSystem.text(model.error)
		return false
	status.text = LocalizationSystem.text("本地生成完成 · Seed %d" % model.seed_value)
	return true

func _process(_delta: float) -> void:
	if player.playing and not player.stream_paused:
		canvas.time = player.get_playback_position()
		canvas.queue_redraw()

func submit() -> void:
	if preload("res://scripts/town_sound/data/SoundAtlas.gd").audible_kinds(model).is_empty():
		status.text="作品没有可听见的声音，请把声音纸条的音量调大一点，或重新采样。"
		return
	if model.clips.is_empty() or audio==null or audio.get_length()<.25:
		status.text="先留下一小段声音（至少四分之一秒），再来做唱片。"; return
	if pressing != null or submitting: return
	if not generate(): return
	status.text = LocalizationSystem.text("老板：新做的？行，放吧。\n老板正在听。听完这一段，就开始动手……")
	player.stream_paused = false
	player.play()
	# Submission is locked during listening; returning frees this node and cancels the continuation.
	submitting = true
	for button in listening_controls: button.disabled = true
	prompt_input.editable = false
	await get_tree().create_timer(minf(8.0,audio.get_length())).timeout
	player.stop()
	pressing = load("res://scripts/town_sound/record_shop/PressingTable.gd").new()
	pressing.room = self
	pressing.model = model
	pressing.audio = audio
	pressing.profile = canvas.profile
	pressing.seed_value = model.seed_value
	page.add_child(pressing)
	column.hide()
