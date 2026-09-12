extends "res://main.gd"
## Dialogue-first version. The player intervenes in conversational pauses.

const NPC_AREAS := [Rect2(190, 268, 290, 304), Rect2(800, 268, 290, 304)]
const TALK_BOX := Rect2(100, 634, 1080, 220)
const NPC_RESET := Rect2(1080, 40, 128, 42)
const PAIRS := [[0, 5], [1, 4], [2, 3]]
const NAMES := ["阿禾", "陈川"]
const CHAPTERS := ["肉摊前", "画面的来处", "没说出口的话"]
const INTRO := [
	[
		[1, "这块肉看着不错。买一点吧，晚上做我爸教的那道菜。", false],
		[0, "你买你想吃的就好。我去挑点青菜，我不吃肉的。", false],
		[1, "一起做嘛。你就尝一小口？这家摊我常来的。", true],
		[0, "我已经说过不吃了。你为什么还一直劝？", true],
		[1, "……我只是想一起买菜、一起做顿饭。怎么就吵起来了？", true],
	],
	[
		[0, "我知道你喜欢那道菜。可站在肉摊前，我就没办法只想着晚饭。", true],
		[1, "这句话我还不太明白。对我来说，它一直都是家里常吃的东西。", true],
	],
	[
		[1, "刚才你转身走开的时候，我以为……你连菜都不想和我一起买了。", true],
		[0, "没有。我想和你一起逛。只是看见摊上的肉，有些画面就会冒出来。", true],
	],
]
const REPLIES := [
	[[1, "原来你先想到的，是你自己养过的那只小猪。", false], [0, "嗯。它认得我的脚步声。我听到这个词，会先想起它。", false]],
	[[1, "所以你会一直想到……盘子里的食物，曾经是活着的。", false], [0, "对。第一次明白这件事以后，我就很难把这两个画面分开了。", false]],
	[[1, "你刚才不是在嫌弃我。是那种难过又回来了，对吗？", false], [0, "是。我还没找到一个不让人误会的说法。", false]],
	[[0, "你说好吃的时候，想到的还有被照顾的感觉。", false], [1, "是啊。小时候闻到这个味道，就知道有人在家里等我。", false]],
	[[0, "你一直提这道菜，是因为它也让你想起爸爸？", false], [1, "嗯。他不太会说好听的话，就总想着给人做点吃的。我也学成这样了。", false]],
	[[0, "原来你眼前先出现的，是平常吃饭的样子。", false], [1, "对。饭菜、味道、坐在一起的人……我吃的时候，不一定会继续想到它的来处。", false]],
]
const ENDING := [
	[1, "对不起。我刚才只顾着劝你，没听见你已经说了不愿意。", false],
	[0, "我刚才也急了。原来是这样……你想分享的，还有家的味道。", false],
	[1, "我不劝了。隔壁的青菜挺新鲜，我们一起去挑？", false],
	[0, "好。我买青菜，你买你想吃的，回去一起做。", false],
	[1, "那我跟你讲讲，我爸第一次教我做饭的时候……", false],
]

var market_texture: Texture2D
var emoji_font: SystemFont
var clock_time := 0.0
var chapter := 0
var lines: Array = []
var current_line: Array = []
var typed := 0.0
var waiting := false
var finished := false
var closing := false
var hovering := -1
var focus_side := -1
var notify_text := ""
var notify_seconds := 0.0
var last_speech: Array[String] = ["", ""]
var speech_age: Array[float] = [99.0, 99.0]
var tense: Array[bool] = [false, false]


func _ready() -> void:
	super._ready()
	market_texture = load("res://assets/market-painted.png")
	emoji_font = SystemFont.new()
	emoji_font.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"])
	emoji_font.disable_embedded_bitmaps = false
	_reset()


func _reset() -> void:
	super._reset()
	chapter = 0
	lines = INTRO[0].duplicate(true)
	current_line = []
	typed = 0.0
	waiting = false
	finished = false
	closing = false
	hovering = -1
	focus_side = -1
	notify_text = ""
	notify_seconds = 0.0
	last_speech.assign(["", ""])
	speech_age.assign([99.0, 99.0])
	tense.assign([false, false])
	_next_line()


func _process(delta: float) -> void:
	clock_time += delta
	typed += delta * 25.0
	for i in range(6):
		reveal[i] = move_toward(reveal[i], 1.0 if decoded[i] else 0.0, delta * 3.0)
	for side in range(2):
		speech_age[side] += delta
		pulse[side] = move_toward(pulse[side], 0.0, delta * 1.5)
	hovering = _thought_at(get_global_mouse_position()) if waiting else -1
	if notify_seconds > 0:
		notify_seconds -= delta
		if notify_seconds <= 0:
			notify_text = ""
	if return_index >= 0:
		return_time = minf(1.0, return_time + delta * 5.0)
		return_position = return_origin.lerp(_thought_rect(return_index).get_center(), 1.0-pow(1.0-return_time,3))
		if return_time >= 1:
			return_index = -1
	var hand := hovering >= 0 or TALK_BOX.has_point(get_global_mouse_position()) or NPC_RESET.has_point(get_global_mouse_position())
	Input.set_default_cursor_shape(Input.CURSOR_DRAG if drag_index >= 0 else (Input.CURSOR_POINTING_HAND if hand else Input.CURSOR_ARROW))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0,0,1280,960), PAPER)
	_text("听懂你", Vector2(70,73), 32, INK, title_font)
	_text("语言与语境", Vector2(185,71), 13, MUTED)
	_center_text("一起逛早市", 71, 17, MUTED)
	_button(NPC_RESET,"重新开始")
	_draw_room()
	_draw_npc(0)
	_draw_npc(1)

	for side in range(2):
		_draw_thought(side)
	_draw_dialogue()
	_text("鼠标点击 / 空格：继续    ·    拖动头顶的记忆给对方    ·    Esc：取消    ·    R：重来", Vector2(100,904), 12, MUTED)
	_center_text("各自的选择，仍然属于自己。" if finished else "同一个菜市场，两种看待食物的方式。", 939, 12, MUTED)
	if drag_index >= 0:
		_draw_token(drag_index,drag_position)
	if return_index >= 0:
		_draw_token(return_index,return_position)


func _draw_room() -> void:
	var stage := Rect2(100,110,1080,488)
	if market_texture:
		var source_size := market_texture.get_size()
		var visible_height := source_size.x * stage.size.y / stage.size.x
		var source := Rect2(0,(source_size.y-visible_height)/2.0,source_size.x,visible_height)
		draw_texture_rect_region(market_texture,stage,source)
	_box(Rect2(524,555,232,32),Color("f7f0de"),Color("d5ccac"),14)
	_center_text("%02d / %s" % [chapter+1,CHAPTERS[chapter]],577,12,Color("566e64"))


func _draw_npc(side: int) -> void:
	var center := Vector2(330 if side==0 else 950,432)
	var active := not waiting and not finished and not current_line.is_empty() and int(current_line[0])==side
	var angry := tense[side] and not finished
	center.y += sin(clock_time*(3.0 if active else 1.6))*(3.0 if active else 1.2)
	var target := drag_index>=0 and int(MEMORIES[drag_index].side)!=side
	if target:
		var inside := _recipient_at(get_global_mouse_position())==side
		_box(NPC_AREAS[side].grow(4),Color(1,1,1,0.1),Color("ab8359") if inside else Color("c7b89d"),40,2)
		_center_text("松开，让"+NAMES[side]+"看见" if inside else "交给"+NAMES[side],560,13,INK,NPC_AREAS[side].position.x,NPC_AREAS[side].size.x)
	draw_ellipse_shadow(center+Vector2(0,95))
	var expression := ("😟" if side==0 else "😠") if angry else ("🙂" if side==0 else "😊")
	if active and not angry and typed<str(current_line[1]).length():
		expression="😮"
	var font_size:=142
	var width:=emoji_font.get_string_size(expression,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(emoji_font,center+Vector2(-width/2.0,46),expression,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
	# Small grocery bags make both emoji characters read as shoppers.
	var bagx:=center.x+82 if side==0 else center.x-120
	draw_arc(Vector2(bagx+20,center.y+38),15,PI,TAU,18,Color("a08860"),4,true)
	_box(Rect2(bagx,center.y+37,40,48),Color("c8ac7a"),Color("ac8c5f"),6)
	if side==0:
		for n in range(3):
			draw_line(Vector2(bagx+10+n*9,center.y+43),Vector2(bagx+7+n*12,center.y+23),Color("6e945a"),7,true)
	else:
		_box(Rect2(bagx+6,center.y+25,28,20),Color("f0e4cf"),Color.TRANSPARENT,4)
	if active:
		draw_circle(Vector2(center.x-33,606),3,RED if angry else INK)
	_center_text(NAMES[side],610,17,INK,center.x-70,140,title_font)


func draw_ellipse_shadow(center: Vector2) -> void:
	var pts:=PackedVector2Array()
	for n in range(33):
		var angle:=TAU*n/32.0
		pts.append(center+Vector2(cos(angle)*66,sin(angle)*10))
	draw_colored_polygon(pts,Color(0.34,0.30,0.20,0.1))


func _thought_rect(index: int) -> Rect2:
	return Rect2(211 if int(MEMORIES[index].side)==0 else 831,153,238,100)


func _draw_thought(side: int) -> void:
	var index: int = PAIRS[chapter][side]
	var rect := _thought_rect(index)
	if not waiting and not decoded[index]:
		return
	var color := INK if decoded[index] else RED
	var fill := Color("f8f4ec")
	_box(rect,fill,color.lightened(0.55),22)
	draw_circle(Vector2(rect.get_center().x,269),7,fill)
	draw_circle(Vector2(rect.get_center().x+9,283),4,fill)
	if drag_index != index and return_index != index:
		draw_texture_rect(textures[index],Rect2(rect.position+Vector2(20,19),Vector2(55,55)),false,color)
	_text(str(MEMORIES[index].title),rect.position+Vector2(91,43),17,color)
	_text("已经听见" if decoded[index] else "拖给对方",rect.position+Vector2(91,69),12,MUTED)


func _draw_dialogue() -> void:
	_box(Rect2(TALK_BOX.position+Vector2(0,5),TALK_BOX.size),Color(0.3,0.25,0.15,0.04),Color.TRANSPARENT,22)
	_box(TALK_BOX,WHITE,LINE,22)
	if finished:
		_text("菜买好了，对话继续。",Vector2(137,688),26,INK,title_font)
		_wrapped_text("阿禾把青菜放进购物袋，陈川拎起自己的菜。他们继续往前逛，聊起回家要怎么做饭。",Vector2(137,736),22,INK,976,36)
		_text("点击这里，再聊一次  ↵",Vector2(886,824),15,MUTED)
	elif waiting:
		var index := drag_index if drag_index>=0 else hovering
		if index >= 0:
			_text(NAMES[int(MEMORIES[index].side)]+"想起……",Vector2(137,679),16,MUTED)
			_wrapped_text(str(MEMORIES[index].memory),Vector2(137,724),23,INK,980,37)
		else:
			_text("他们停了一下。",Vector2(137,679),16,MUTED)
			_wrapped_text("同一句“吃肉”，让两个人想到了不同的画面。把头顶的记忆拖给另一个人，让话接着说下去。",Vector2(137,724),23,INK,980,37)
		_text(notify_text if not notify_text.is_empty() else "悬停图形可以阅读记忆；拖到对方身上或头顶后松开。",Vector2(137,824),13,MUTED)
	else:
		var side := int(current_line[0])
		var color := RED if bool(current_line[2]) else INK
		_text(NAMES[side],Vector2(137,679),19,color,title_font)
		var visible_text := str(current_line[1]).substr(0,int(typed))
		_wrapped_text(visible_text,Vector2(137,730),27,color,980,42)
		_text("点击，继续听  ↵" if typed>=str(current_line[1]).length() else "点击显示整句",Vector2(956,824),14,MUTED)


func _next_line() -> void:
	if not lines.is_empty():
		current_line = lines.pop_front()
		tense[int(current_line[0])] = bool(current_line[2])
		typed = 0.0
		waiting = false
		return
	if closing:
		finished = true
		waiting = false
		current_line = []
		return
	var pair: Array = PAIRS[chapter]
	if decoded[int(pair[0])] and decoded[int(pair[1])]:
		if chapter < 2:
			chapter += 1
			lines = INTRO[chapter].duplicate(true)
		else:
			closing = true
			lines = ENDING.duplicate(true)
		_next_line()
	else:
		waiting = true
		current_line = []


func _continue() -> void:
	if drag_index>=0:
		return
	if finished:
		_reset()
	elif not waiting:
		if typed<str(current_line[1]).length():
			typed=float(str(current_line[1]).length())
		else:
			_next_line()


func _thought_at(point: Vector2) -> int:
	for index: int in PAIRS[chapter]:
		if not decoded[index] and _thought_rect(index).has_point(point):
			return index
	return -1


func _recipient_at(point: Vector2) -> int:
	for side in range(2):
		if NPC_AREAS[side].has_point(point) or Rect2(190 if side==0 else 810,130,280,155).has_point(point):
			return side
	return -1


func _give(index: int, side: int) -> bool:
	if not waiting or index<0 or index>=6 or side<0 or side>1:
		return false
	if not index in PAIRS[chapter] or decoded[index] or int(MEMORIES[index].side)==side:
		return false
	decoded[index]=true
	completed_count+=1
	pulse[side]=1.0
	lines=REPLIES[index].duplicate(true)
	_play_tone()
	_next_line()
	return true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and drag_index>=0:
		drag_position=get_global_mouse_position()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var point:=get_global_mouse_position()
		if event.pressed:
			if NPC_RESET.has_point(point):
				_reset()
			elif waiting:
				var index:=_thought_at(point)
				if index>=0:
					drag_index=index
					drag_position=point
					return_index=-1
			elif TALK_BOX.has_point(point):
				_continue()
		elif drag_index>=0:
			var index:=drag_index
			drag_index=-1
			if not _give(index,_recipient_at(point)):
				return_index=index
				return_origin=point
				return_position=point
				return_time=0.0
				notify_text="把这段记忆交给另一位正在听的人。"
				notify_seconds=3.0
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_R:
			_reset()
		elif event.keycode==KEY_ESCAPE:
			_cancel_drag()
		elif event.keycode in [KEY_SPACE,KEY_ENTER]:
			_continue()
		elif waiting and drag_index<0 and event.keycode in [KEY_1,KEY_2]:
			var side:=0 if event.keycode==KEY_1 else 1
			_give(int(PAIRS[chapter][side]),1-side)


func _draw_token(index: int, center: Vector2) -> void:
	var rect:=Rect2(center-Vector2(42,42),Vector2(84,84))
	_box(Rect2(rect.position+Vector2(0,6),rect.size),Color(0.2,0.15,0.1,0.12),Color.TRANSPARENT,18)
	_box(rect,WHITE,RED,18,2)
	draw_texture_rect(textures[index],rect.grow(-14),false,RED)


func _run_qa() -> void:
	await get_tree().process_frame
	typed=999
	await _qa_capture("npc-start")
	for round_index in range(3):
		_drain_lines()
		assert(waiting and chapter==round_index)
		var pair: Array=PAIRS[chapter]
		var first: int=pair[1] if round_index%2==0 else pair[0]
		var second: int=pair[0] if round_index%2==0 else pair[1]
		assert(not _give(first,int(MEMORIES[first].side)))
		assert(not _give(first,-1))
		if round_index==0:
			await _qa_capture("npc-thoughts")
		assert(_give(first,1-int(MEMORIES[first].side)))
		assert(not waiting and not current_line.is_empty())
		assert(not _give(first,1-int(MEMORIES[first].side)))
		typed=999
		if round_index==0:
			await _qa_capture("npc-reply")
		_drain_lines()
		assert(waiting and chapter==round_index)
		assert(_give(second,1-int(MEMORIES[second].side)))
	_drain_lines()
	assert(finished and completed_count==6)
	await _qa_capture("npc-end")
	_reset()
	assert(chapter==0 and completed_count==0 and not finished and not waiting)
	print("QA PASS: both sharing orders, conversation gates, NPC responses, wrong target, duplicates, three chapters, ending, replay")
	get_tree().quit(0)


func _drain_lines() -> void:
	var guard:=0
	while not waiting and not finished:
		typed=999
		_continue()
		guard+=1
		assert(guard<40)



