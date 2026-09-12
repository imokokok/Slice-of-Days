extends Control
signal closed
signal play_requested(profile: Dictionary)
const UI = preload("res://scripts/ui_bits.gd")
const Memory = preload("res://scripts/elder_memory.gd")
const Rules = preload("res://scripts/teaching_rules.gd")
const AI = preload("res://scripts/teaching_ai.gd")
var messages: Array = []
var candidate: Dictionary = {}
var confirmed_profile: Dictionary = {}
var ready_to_confirm := false
var busy := false
var transcript: RichTextLabel
var summary: RichTextLabel
var input: TextEdit
var pad: Control
var attach: CheckButton
var send_button: Button
var confirm_button: Button
var play_button: Button
var retry_button: Button
var lesson_button: Button
var library: OptionButton
var mode_label: Label
var client: Node
var profiles: Array = []
var file_dialog: FileDialog
var settings: Control
var endpoint_field: LineEdit
var model_field: LineEdit
var key_field: LineEdit
var enable_field: CheckButton
var autosave: Timer
var restoring := false
var last_image := ""

func _ready() -> void:
	size = Vector2(1579, 972)
	var shade := ColorRect.new()
	shade.color = Color("222822")
	shade.size = size
	add_child(shade)
	UI.label(self, "%s · 教老棋友一种棋" % Memory.role, Rect2(55, 26, 800, 50), 36)
	UI.button(self, "模型连接", Rect2(1100, 28, 200, 50), show_settings)
	UI.button(self, "返回", Rect2(1325, 28, 180, 50), leave)
	mode_label = UI.label(self, "", Rect2(55, 90, 1450, 38), 21)
	UI.panel(self, Rect2(40, 140, 710, 790))
	UI.panel(self, Rect2(775, 140, 755, 790))
	transcript = UI.rich(self, Rect2(65, 160, 660, 430), 25)
	transcript.scroll_following = true
	input = TextEdit.new()
	input.position = Vector2(65, 605)
	input.size = Vector2(660, 135)
	input.placeholder_text = "例如：这是井字棋，3×3，横竖斜连成3子就赢，我先下。也可以画在右边。"
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.add_theme_font_size_override("font_size", 24)
	add_child(input)
	input.text_changed.connect(mark_edited)
	send_button = UI.button(self, "告诉老人", Rect2(65, 755, 200, 56), send_message)
	retry_button = UI.button(self, "重试回答", Rect2(285, 755, 200, 56), retry)
	UI.button(self, "试教井字棋", Rect2(505, 755, 220, 56), func():
		if not busy: input.text = "我教您井字棋，3×3，横竖斜连成3子就赢，长连也算，我先下。"
	)
	retry_button.disabled = true
	library = OptionButton.new()
	library.position = Vector2(65, 830)
	library.size = Vector2(420, 55)
	library.add_theme_font_size_override("font_size", 23)
	library.item_selected.connect(load_lesson)
	add_child(library)
	lesson_button = UI.button(self, "教另一种", Rect2(510, 830, 215, 55), new_lesson)
	UI.label(self, "画给老人看 / 导入一张图", Rect2(800, 156, 610, 34), 25)
	pad = preload("res://scripts/sketch_pad.gd").new()
	pad.position = Vector2(805, 205)
	pad.size = Vector2(690, 260)
	add_child(pad)
	pad.changed.connect(func():
		if not restoring: attach.set_pressed_no_signal(true)
		mark_edited()
	)
	UI.button(self, "撤回一笔", Rect2(805, 480, 160, 45), pad.undo)
	UI.button(self, "清空画纸", Rect2(980, 480, 160, 45), pad.clear)
	UI.button(self, "导入图片", Rect2(1155, 480, 160, 45), func(): file_dialog.popup_centered(Vector2i(850, 650)))
	UI.button(self, "换笔颜色", Rect2(1330, 480, 165, 45), func(): pad.ink = Color("b44949") if pad.ink != Color("b44949") else Color("29352d"))
	attach = CheckButton.new()
	attach.text = "发送时带上这张图（网格只是画纸辅助线）"
	attach.position = Vector2(805, 532)
	attach.size = Vector2(690, 40)
	attach.add_theme_font_size_override("font_size", 21)
	add_child(attach)
	UI.label(self, "老人复述的规则 · 确认后才记住", Rect2(805, 582, 680, 35), 25)
	summary = UI.rich(self, Rect2(805, 625, 690, 175), 23)
	confirm_button = UI.button(self, "记对了，记住这套棋", Rect2(805, 830, 400, 55), confirm_lesson)
	play_button = UI.button(self, "下我教的棋", Rect2(1220, 830, 275, 55), play_lesson)
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 图片"])
	file_dialog.file_selected.connect(import_picture)
	add_child(file_dialog)
	client = AI.new()
	add_child(client)
	autosave = Timer.new()
	autosave.one_shot = true
	autosave.wait_time = 1.0
	autosave.timeout.connect(save_draft)
	add_child(autosave)
	refresh_library()
	var draft: Dictionary = Memory.draft()
	if not draft.is_empty(): restore(draft)
	else: new_lesson()
	refresh()

func refresh() -> void:
	mode_label.text = "实时模型教学：点击发送会将本次教学文字与勾选附图交给所配置的服务。" if AI.enabled else "离线练习：可教连线棋；不会识图。任意文字理解和读图需要在「模型连接」启用服务。"
	transcript.text = ""
	for message in messages:
		transcript.text += ("你：" if message.role == "user" else "老棋友：") + str(message.content) + (" [附图]" if not message.get("image", "").is_empty() else "") + "\n\n"
	summary.text = Rules.summary(candidate)
	confirm_button.disabled = busy or not ready_to_confirm
	play_button.disabled = busy or confirmed_profile.is_empty()
	send_button.disabled = busy
	lesson_button.disabled = busy
	library.disabled = busy
	input.editable = not busy
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP
	send_button.text = "老人正在想…" if busy else "告诉老人"

func mark_edited() -> void:
	if restoring: return
	ready_to_confirm = false
	confirmed_profile = {}
	if is_instance_valid(autosave): autosave.start()
	if is_instance_valid(confirm_button): refresh()

func snapshot_draft() -> Dictionary:
	return {"messages": messages, "candidate": candidate, "input": input.text, "strokes": pad.strokes, "last_image": last_image, "ready": ready_to_confirm}

func save_draft() -> bool:
	if not is_instance_valid(pad): return false
	DirAccess.make_dir_recursive_absolute(Memory.directory)
	# The unsent paper is saved separately from immutable sent attachments.
	var draft_image := Memory.directory + "/draft-paper-%s.png" % Memory.role
	if pad.has_art():
		if pad.picture().save_png(draft_image) != OK: return false
		last_image = draft_image
	else: last_image = ""
	return Memory.save_draft(snapshot_draft())

func restore(draft: Dictionary) -> void:
	restoring = true
	messages = draft.get("messages", []).duplicate(true)
	candidate = draft.get("candidate", {}).duplicate(true)
	input.text = draft.get("input", "")
	last_image = draft.get("last_image", "")
	if FileAccess.file_exists(last_image): pad.load_picture(last_image)
	# A saved paper already contains its strokes; avoid drawing them twice.
	ready_to_confirm = draft.get("ready", false) and Rules.validate(candidate).is_empty() and input.text.is_empty()
	restoring = false
	attach.set_pressed_no_signal(false)
	refresh()

func new_lesson() -> void:
	if busy: return
	restoring = true
	messages = [{"role": "assistant", "content": "来，这回我听你的。叫什么棋？\n先摆个棋盘给我看看也行。你说慢点，没跟上的地方我就问，可别嫌我打岔。"}]
	candidate = {}
	confirmed_profile = {}
	ready_to_confirm = false
	input.clear()
	pad.clear()
	last_image = ""
	restoring = false
	attach.set_pressed_no_signal(false)
	retry_button.disabled = true
	refresh()
	save_draft()

func import_picture(path: String) -> void:
	if busy: return
	if pad.load_picture(path) != OK:
		messages.append({"role": "assistant", "content": "这张图没能打开。换一张 PNG、JPG 或 WebP 试试？"})
	refresh()

func send_message() -> void:
	if busy: return
	var words := input.text.strip_edges()
	var include_image: bool = attach.button_pressed and pad.has_art()
	if words.is_empty() and not include_image: return
	if words.length() > 4000:
		messages.append({"role": "assistant", "content": "这一段有点长，咱们分几段讲吧，每段四千字以内。"})
		refresh()
		return
	var message := {"role": "user", "author": Memory.role, "content": words if not words.is_empty() else "请看看这张教学图，哪里不清楚就问我。"}
	if include_image:
		DirAccess.make_dir_recursive_absolute(Memory.directory)
		var path := Memory.directory + "/drawing-%d.png" % Time.get_ticks_usec()
		if pad.picture().save_png(path) != OK:
			messages.append({"role": "assistant", "content": "这张图没有存好，先别急着往下教，再试一次吧。"})
			refresh()
			return
		message.image = path
	messages.append(message)
	input.clear()
	ready_to_confirm = false
	confirmed_profile = {}
	attach.set_pressed_no_signal(false)
	if not save_draft():
		messages.append({"role": "assistant", "content": "棋谱暂时写不进去，这次还没有发出去。检查一下本地存储，再点重试吧。"})
		retry_button.disabled = false
		refresh()
		return
	await request_reply()

func retry() -> void:
	if busy or messages.is_empty(): return
	await request_reply()

func request_reply() -> void:
	busy = true
	retry_button.disabled = true
	refresh()
	var answer: Dictionary = await client.discuss(messages, candidate)
	busy = false
	if answer.has("error"):
		messages.append({"role": "assistant", "content": answer.error})
		ready_to_confirm = false
		retry_button.disabled = false
	else:
		messages.append({"role": "assistant", "content": answer.reply})
		if answer.get("rules") is Dictionary: candidate = answer.rules.duplicate(true)
		ready_to_confirm = answer.get("ready", false) and Rules.validate(candidate).is_empty() and answer.get("questions", []).is_empty() and answer.get("unsupported", []).is_empty()
		if not answer.get("unsupported", []).is_empty():
			messages.append({"role": "assistant", "content": "还不能开局：" + str(answer.unsupported)})
	save_draft()
	refresh()

func confirm_lesson() -> void:
	if busy or not input.text.strip_edges().is_empty() or not ready_to_confirm or not Rules.validate(candidate).is_empty(): return
	var profile := {"id": str(Time.get_unix_time_from_system()) + "-" + str(Time.get_ticks_usec()), "name": candidate.name, "taught_by": Memory.role, "rules": candidate.duplicate(true), "messages": messages.duplicate(true), "confirmed": true}
	if not Memory.remember(profile):
		messages.append({"role": "assistant", "content": "没能写进棋谱，我还不能说已经记住。请再试一次。"})
		refresh()
		return
	confirmed_profile = profile
	ready_to_confirm = false
	messages.append({"role": "assistant", "content": "行，就照这个。我在“%s”旁边写上了你的名字，%s。另一位来了，我也给他摆摆。\n现在试一盘？教归教，下起来可不用让着我。" % [candidate.name, Memory.role]})
	refresh_library()
	refresh()

func refresh_library() -> void:
	profiles = Memory.read().profiles
	library.clear()
	library.add_item("棋谱 · 选择以前教过的棋")
	for profile in profiles:
		library.add_item("%s · %s教的" % [profile.get("name", "未命名"), profile.get("taught_by", "棋友")])

func load_lesson(index: int) -> void:
	if busy or index == 0: return
	var profile: Dictionary = profiles[index - 1]
	var issue := Rules.validate(profile.get("rules"))
	if not issue.is_empty():
		messages.append({"role": "assistant", "content": "这页规则还不完整：" + issue})
		refresh()
		return
	restoring = true
	input.clear()
	pad.clear()
	restoring = false
	candidate = profile.rules.duplicate(true)
	messages = profile.get("messages", []).duplicate(true)
	messages.append({"role": "assistant", "content": "哦，“%s”。%s教我的，记着呢。\n%s，你看看这页，咱们照着下。你要有新下法，再另记一页，原来的我留着。" % [candidate.name, profile.get("taught_by", "一位棋友"), Memory.role]})
	confirmed_profile = profile
	ready_to_confirm = false
	refresh()

func play_lesson() -> void:
	if busy or not input.text.strip_edges().is_empty() or confirmed_profile.is_empty(): return
	play_requested.emit(confirmed_profile.duplicate(true))

func leave() -> void:
	save_draft()
	closed.emit()

func show_settings() -> void:
	if busy or is_instance_valid(settings): return
	settings = Control.new()
	settings.size = size
	add_child(settings)
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0, 0, 0, 0.8)
	settings.add_child(shade)
	UI.panel(settings, Rect2(260, 180, 1050, 650))
	UI.label(settings, "实时教学 · 模型连接", Rect2(305, 210, 950, 45), 32)
	enable_field = CheckButton.new()
	enable_field.text = "启用能看图的模型服务"
	enable_field.position = Vector2(305, 275)
	enable_field.button_pressed = AI.enabled
	settings.add_child(enable_field)
	UI.label(settings, "Chat Completions 完整地址", Rect2(305, 325, 930, 30), 23)
	endpoint_field = make_field(Vector2(305, 365), AI.endpoint)
	UI.label(settings, "模型名称（需支持图片与 JSON 输出）", Rect2(305, 423, 930, 30), 23)
	model_field = make_field(Vector2(305, 463), AI.model)
	UI.label(settings, "API 密钥 · 仅本次运行保存在内存，不写入棋谱", Rect2(305, 520, 930, 30), 23)
	key_field = make_field(Vector2(305, 560), AI.api_key)
	key_field.secret = true
	UI.label(settings, "发送时只上传这次教学的文字与附图。离线也可试教井字棋等连线规则。", Rect2(305, 635, 940, 65), 23)
	UI.button(settings, "取消", Rect2(305, 735, 280, 55), func(): settings.queue_free(); settings = null)
	UI.button(settings, "使用这些设置", Rect2(690, 735, 550, 55), func():
		AI.endpoint = endpoint_field.text.strip_edges()
		AI.model = model_field.text.strip_edges()
		AI.api_key = key_field.text.strip_edges()
		AI.enabled = enable_field.button_pressed
		settings.queue_free()
		settings = null
		refresh()
	)

func make_field(position_value: Vector2, text: String) -> LineEdit:
	var field := LineEdit.new()
	field.position = position_value
	field.size = Vector2(940, 46)
	field.text = text
	field.add_theme_font_size_override("font_size", 23)
	settings.add_child(field)
	return field
