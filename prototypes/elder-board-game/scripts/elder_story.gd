extends Control
signal closed
signal teach_requested
const UI = preload("res://scripts/ui_bits.gd")
const Memory = preload("res://scripts/elder_memory.gd")
# Each response is a real conversational beat, including choosing to sit quietly.
const CHAPTERS := [
	[
		{"action": "他拢起棋子，忽然又摊开了手。", "text": "先别收，我数数……还少一颗。\n哦，在我手里。我刚才一直攥着。\n你看，都攥热了。", "choices": ["那就再坐一会儿。", "（把棋罐往他那边挪了挪）"], "replies": ["好。也不急着下下一盘。你喝口水，我把这些收好。", "谢谢。白子放这边……对，就这样。你收得比我仔细。"]},
		{"action": "他把白子一颗颗放回罐里，没有抬头。", "text": "以前在家下棋，我老伴一喊吃饭，我就说，最后一步。\n有一回饭都热第二遍了，我还说最后一步。后来，饭碗直接给我端到棋盘边上来了。", "choices": ["后来您吃了吗？", "听起来，您那时候挺赖的。"], "replies": ["吃了。不敢再拖。筷子拿在手里，眼睛还往棋盘上瞟。现在倒记不清那盘谁赢了。", "可不。还觉得自己占理呢，说棋下到一半，哪能走。老伴也不跟我争，就把棋罐盖上。我就知道，得吃饭了。"]},
		{"action": "罐盖合上了。他的手还搭在上面。", "text": "现在没人催我了。\n有时候坐久了，还会往旁边看一下。\n……不说这个。你刚才那一步，我想明白了。原来你是这么打算的。", "choices": ["嗯，我给您再摆一遍。", "（陪他坐着，没有接话）"], "replies": ["行，摆吧。我看着。这回不赶饭点。", "……坐一会儿也好。风有点大，你往里面挪挪，那边背风。"]}
	],
	[
		{"action": "他挑出一颗边缘磨旧的黑子，用拇指蹭了蹭。", "text": "我家孩子小时候，总要拿黑的。也不管该谁先。\n输了就把棋盘一搅，说这盘没开始。\n我说你这跟谁学的。老伴在旁边看着我笑。", "choices": ["大概是跟您学的。", "您会让着孩子吗？"], "replies": ["你也看出来了？我有时候眼看要输，就说该吃饭了。孩子可记仇，下一回一坐下，先把门关上。", "嘴上不让。真把孩子赢急了，又偷偷把刚吃的子放回去。还以为人家没看见，其实都知道。"]},
		{"action": "他把那颗黑子放在布上，手指松开了。", "text": "我们就这一个孩子。\n后来，孩子走在我们前头了。\n这副棋就一直留着。我和老伴后来还用它下，谁执黑，也照样得争一争。", "choices": ["您还留着。", "（轻轻放下棋子，没有追问）"], "replies": ["嗯。用惯了。哪颗边上有个小缺口，手一摸就知道。来，你摸摸这颗，是不是？", "……这几颗放在里面吧，免得滚下去。刚才说到哪儿了？哦，孩子小时候下棋。"]},
		{"action": "他把黑子放进罐里，轻轻转了一下罐口。", "text": "后来有一天，老伴说，今天买的橘子酸。\n我顺口就说，孩子爱吃酸的。\n说完，屋里一下就静了。我以为自己又说错话了。老伴却说，是，小时候牙都酸倒了，还要吃。", "choices": ["那天，你们聊起孩子了。", "您还记得孩子这些小事。"], "replies": ["聊了几句。后来又聊了几句。才发现，我们都怕对方难受，谁也不敢先说。其实谁都没忘。", "大事反而不常想。就是买东西、走路，忽然碰见一样，就想起来了。今天这颗黑子也是。"]}
	],
	[
		{"action": "他低头理了理棋盘布卷起的边。", "text": "后来，老伴也不在了。\n一开始我还照旧做饭。菜洗好了，切好了，一下锅才发现，又切多了。\n第二天想着少切点，手上还是照旧。", "choices": ["两个人的分量，做惯了。", "那您现在怎么吃饭？"], "replies": ["是啊。一起过了那么久，买多少、做多少，都不用想。后来才知道，一个人的饭，也得重新学。", "有时候自己煮点，有时候在外头吃。现在记着先拿个小碗量一量。也有做多的时候，留着下一顿。"]},
		{"action": "他提起棋袋，掂了掂，又放在膝头。", "text": "刚开始带棋出门，我什么都往袋里装，重得很。\n后来才换成这些布，卷起来就走。这个扣子是我自己缝的，缝歪了一点。\n老伴要看见，准得拆了重缝。", "choices": ["我看还挺结实的。", "您还会缝这个？"], "replies": ["就是。结实就行。我也这么想。……不过下回还得把线头剪一剪。", "现学的。线穿了半天，倒比摆一盘棋还费功夫。好歹用到现在，没散。"]},
		{"action": "他把布角抚平，往长凳另一头让了让。", "text": "我现在出门，先看看哪儿背风。风一吹，布卷起来，棋都没法摆。\n这地方不错，坐得住。路过的人也愿意停一停。\n今天碰上你，下得还挺痛快。", "choices": ["那我下次还来这儿找您。", "今天先下到这儿吧。"], "replies": ["行。你要看见这几块布，我多半就在。下回来可别让我了，我看得出来。", "好，你去忙。棋我来收。路上慢点，咱们回头见。"]}
	],
	[
		{"action": "他从围棋布后面，抽出另一块折好的布。", "text": "我原来真只会围棋。第一次有人说下五子棋，我还问，能提子吗？\n那位棋友笑了，给我摆了五颗，说你先看这一排。\n我倒好，还在找这几颗棋的气。", "choices": ["下惯了，一时改不过来。", "后来是谁先赢的？"], "replies": ["对。手上是新棋，脑子里还是老一套。人家也不烦，把我刚摆的子挪回来，再说一遍。", "当然是人家。我输了还问，这就算赢啦？才坐下没多久呢。人家说，那就再来一盘。"]},
		{"action": "说到马，他用手指在布上拐了一个弯。", "text": "国际象棋学得更慢。这个马怎么偏要拐着走，我总记错。\n教我的人拿纸画了几个点，让我把手指放上去，一格、两格，这么走。\n那张纸我夹在棋谱里，边都磨软了。", "choices": ["您还留着那张纸？", "画出来，确实容易记。"], "replies": ["留着。现在不用看了，有时翻到，还是会看两眼。纸上有一处画错了，划掉重画的。我没舍得换。", "嗯。比光听有用。那天人家画得急，还把笔帽落我这儿了。我一直收在棋袋的小兜里。"]},
		{"action": "他把几块棋盘布叠在一起，最旧的那块仍放在上面。", "text": "他们教完，也都有自己的事要忙。后来有的又碰到过，有的没有。\n我现在摆这几种棋，还会想，哦，这一步，当时是那个人教我的。\n你问我怎么学会这么多。就是这么一点点学的。", "choices": ["那下次碰见，就能再下一局。", "也有人记得是和您下过的。"], "replies": ["是。我得多练练。总不能下回碰上，还在问马往哪儿拐。", "会吗？……也可能。那天有个棋友走老远了，又回头冲我摆摆手。我还记着。"]}
	],
	[
		{"action": "他翻开棋谱，找到一页空白，用手压住。", "text": "还有一页。\n你会不会一种我没下过的棋？自己想的也成。\n前几次都是我摆棋，这回，我想跟你学学。", "choices": ["好，这回我教您。", "我怕自己讲不清。"], "replies": ["行。笔给你。先告诉我叫什么，我写在上头。字不好看，别笑话。", "没事。你讲一段，咱们摆一段。讲岔了就重来。我也不是头一回学得慢了。"]},
		{"action": "他把笔横着放在你面前，没有催。", "text": "你说也行，画也行。\n我听完先照着摆一下，你看看对不对。别我这边点着头，其实记成了另一回事。\n真没明白的地方，我可要多问两句。", "choices": ["您问就是，我再讲。", "那我先画给您看。"], "replies": ["那就好。我最怕人家问懂了没有，我不好意思说没懂。跟你说倒不怕。", "好，我把这儿腾出来。你画慢点，我跟着看。哪儿是第一步，你给我指一指。"]},
		{"action": "他在页角留出一点地方，指给你看。", "text": "这里，我写上是谁教的。\n往后另一位棋友来，我就给他摆摆你教的这一种。\n等你再来，没准我已经练出点本事了。", "choices": ["那我可得认真教。", "先学会，可不许偷改规则。"], "replies": ["可得认真。我学会了，要赢老师的。", "你把规则写清楚，我照着来。真输了也认，不赖账。"]}
	],
]
var chapter := 0
var page := 0
var reacting := false
var preview_mode := false
var words: Label
var gesture: Label
var next: Button
var alternative: Button

func _ready() -> void:
	size = Vector2(1579, 972)
	chapter = 0 if preview_mode else mini(Memory.story_index(), CHAPTERS.size() - 1)
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0, 0, 0, 0.58)
	add_child(shade)
	UI.panel(self, Rect2(250, 205, 1080, 560))
	UI.label(self, "老棋友" if not preview_mode else "老棋友 · 对话试看", Rect2(300, 240, 920, 45), 32)
	gesture = UI.label(self, "", Rect2(300, 300, 980, 55), 22)
	gesture.add_theme_color_override("font_color", Color("acb4aa"))
	words = UI.label(self, "", Rect2(300, 375, 980, 205), 29)
	next = UI.button(self, "", Rect2(300, 605, 475, 60), func(): choose(0))
	alternative = UI.button(self, "", Rect2(800, 605, 480, 60), func(): choose(1))
	UI.button(self, "今天先到这里", Rect2(950, 695, 330, 45), func(): closed.emit())
	refresh()

func refresh() -> void:
	var beat: Dictionary = CHAPTERS[chapter][page]
	gesture.text = beat.action
	words.text = beat.text
	next.text = beat.choices[0]
	alternative.text = beat.choices[1]
	alternative.show()
	reacting = false

func choose(index: int) -> void:
	if reacting:
		advance()
		return
	var beat: Dictionary = CHAPTERS[chapter][page]
	words.text = beat.replies[index]
	gesture.text = "他听完你的话，轻轻点了点头。" if "（" not in beat.choices[index] else "你们安静地坐了一会儿。他又开了口。"
	next.text = "（听他说下去）" if page < 2 else ("把纸笔接过来" if chapter == 4 else "（帮他把棋收好）")
	alternative.hide()
	reacting = true

func advance() -> void:
	if not reacting:
		choose(0)
		return
	if page < 2:
		page += 1
		refresh()
		return
	if preview_mode:
		if chapter < CHAPTERS.size() - 1:
			chapter += 1
			page = 0
			refresh()
		else: closed.emit()
		return
	if not Memory.finish_chapter(chapter):
		gesture.text = "本地记录暂时未保存，可重试或稍后离开。"
		return
	if chapter == 4: teach_requested.emit()
	else: closed.emit()
