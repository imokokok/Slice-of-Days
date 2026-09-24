extends Node
## Small authored encounters, rather than a greeting counter, reveal character.
const SCENES := {
	"xanni":["留着半边的工作台","Xanni 把自己的耳机移到左边，右边的插孔空着。她说：带来的声音先原样放一遍。","给别人的声音留空间","先放原声，再一起听哪里需要改。","先把它改得像店里的唱片。","她在意先听到创作者自己的声音，再一起修改。"],
	"mossner":["没有擦掉的铅笔字","信稿有一行很轻的铅笔字。Mossner 说：这是写信的人自己添的，还没有问过他。","保留写信人的意思","先圈出疑问，等写信的人来决定。","替他改成更漂亮的话。","他宁愿多问一次，也不替写信的人决定。"],
	"shi_yongqi":["一只空的小碟","Shi 把新菜放在小碟里：先尝一口，不喜欢也可以说，别为了客气硬吃。","愿意听真实的味道","尝过再说具体哪里太咸或太淡。","没尝就说肯定很好吃。","她珍惜认真尝菜的人，也愿意听具体的不同意见。"],
	"maya":["窗边的书","Maya 把窗边的书挪开，只把植物留在光里。她说：书页晒久了会褪色。","照看书，也照看植物","帮忙把书移到阴凉处，植物留在窗边。","把书和植物一起搬到太阳下。","她为不同的东西留不同的位置，安静里也有细心。"],
	"chenyuan":["没递出去的点心","晨鸢端着一碟点心停住：我还不知道对方吃不吃这个。她把盘子放回桌上。","先问一句的好意","先问对方想不想尝，再递过去。","替对方拿一大份，显得热情。","她正在学着让好意先征得同意。"],
	"mingming":["没喝完的水","明明握着水杯说昨晚又醒了几次，随后把椅子拉开一点：坐一会儿就好。","陪伴不一定要建议","陪她坐会儿，让她决定要不要说。","马上列一串必须早睡的方法。","她需要的有时只是有人陪着，而不是立刻解决问题。"],
	"zhou_xiaoliu":["走到路口的停顿","周小六在路口停了一下：我记得是这边，不过不敢保证。她重新看了看路牌。","不把模糊记忆当保证","一起看路牌，按确认过的方向走。","催她凭印象快点指一个方向。","她愿意承认记不清，也愿意慢慢确认。"],
	"beetman":["切开的一小块","Beetman 把奇怪食材切开一小块：闻着怪也没关系，先看看里面，再决定买不买。","给陌生食材一次机会","先看切面、闻一闻，再问怎么做。","只看名字就说肯定不能吃。","他希望陌生食材先被认真了解，而不是被名字判定。"],
	"xia_touming":["翻到一半的书","夏透明在书页夹了张纸：刚下班脑子还没转过来，你刚才那句话能慢点再说吗？","疲惫时仍认真听","慢一点复述，也问她要不要先歇会儿。","说她既然没听懂就算了。","疲惫不代表不在意，她会主动确认自己有没有听懂。"],
	"yuxingqing":["没有补满的星图","余星晴的星图还留着一小块空白：那边我没有看清，先别补上去。","允许暂时不知道","保留空白，等有机会再观察。","为了完整，照想象补满它。","她允许答案暂时空着，不把想象冒充观察。"],
	"naonao":["收在一边的计时器","闹闹把棋钟推到旁边：今天不计时，走慢一点也可以。她把一枚棋子扶正。","相处不只为了赢","一起慢慢走一步，不催她作决定。","把棋钟打开，输了才有压力。","她想让一起下棋的人自在一点，胜负可以放在后面。"],
	"wu_wu":["牵绳留出的一步","Cici 把牵绳收短一点：它要先闻闻你。别一下伸到头上，它会紧张。","尊重小动物的边界","停在原处，让它先闻闻。","直接伸手摸头，表示喜欢。","喜欢小动物，也包括尊重它们想不想靠近。"]
}

func album() -> Dictionary:
	return GameState.artifacts.get_or_add("people_puzzle",{})

func page(npc: String) -> Dictionary:
	return album().get_or_add(npc,{"facets":[],"details":false})

func present(npc: String) -> bool:
	return DialogueSystem.people_at(GameState.current_location,SceneRouter.active_space_id).has(npc)

func offer(npc: String) -> Dictionary:
	if not SCENES.has(npc) or not present(npc): return {}
	var p := page(npc)
	var scene: Array=SCENES[npc]
	if p.facets.is_empty(): return {"kind":"observe","text":scene[1],"choices":[["留意一下："+str(scene[0])+"（5分钟）","observe"],["先不打扰。","later"]]}
	if p.facets.size()==1:
		var first: Dictionary=p.facets[0]
		if int(first.day)==GameState.current_day and GameState.current_minute<int(first.minute)+30: return {}
		if LifeSystem.value("clarity")<35 and not bool(p.details): return {"kind":"detail","text":"刚才那个细节记得不太清了。再留意一下对方正在做的事？","choices":[["花5分钟看清楚，再问一句。","detail"],["下次再说。","later"]]}
		var options: Array=[[str(scene[3]),"help"],[str(scene[4]),"wrong"],["今天先到这里。","later"]]
		if npc.hash()%2==0: options=[options[1],options[0],options[2]]
		return {"kind":"help","text":str(scene[1])+"\n这次想怎样回应？","choices":options}
	if GameState.confirmed_residents.has(npc): return {}
	var last: Dictionary=p.facets[-1]
	if int(last.day)==GameState.current_day and GameState.current_minute<int(last.minute)+30: return {}
	return {"kind":"signature","text":"又碰面了。可以一起翻翻这几次留下的记录，问问对方愿不愿意在人物页写个名字。","choices":[["一起看看记录，再请你写下名字。（5分钟）","signature"],["下次带来。","later"]]}

func act(npc: String, action: String) -> Dictionary:
	var current := offer(npc)
	if current.is_empty() or not current.choices.any(func(c: Array) -> bool: return str(c[1])==action): return LifeSystem.fail("现在不适合继续这件事。")
	if action=="later": return {"ok":true,"message":"好，下次再聊。"}
	if not GameState.can_fit_now(5): return LifeSystem.fail("至少留五分钟，下次慢慢说。")
	var snapshot := GameState.to_save_data().duplicate(true)
	GameState.spend_time(5)
	var p := page(npc)
	var scene: Array=SCENES[npc]
	var words := ""
	match action:
		"observe":
			p.facets.append({"id":"observation","title":scene[0],"text":scene[1],"source":"亲眼留意 · "+TravelSystem.location_name(GameState.current_location),"role":GameState.current_role,"day":GameState.current_day,"minute":GameState.current_minute})
			words=str(scene[1])+"\n记在人物页里了。等一会儿再见面，可以接着做点什么。"
		"detail": p.details=true; words=str(scene[1])
		"wrong":
			words="对方摇了摇头，指了指刚才提到的细节。也许先听清楚，再决定怎么帮忙。"
			LifeSystem.change({"clarity":-2},"一次回应没有接上对方的意思。")
		"help":
			p.facets.append({"id":"consideration","title":scene[2],"text":scene[5],"source":"回应并一起做完 · "+str(scene[3]),"role":GameState.current_role,"day":GameState.current_day,"minute":GameState.current_minute})
			RelationshipSystem.record_encounter(npc,"puzzle_"+npc+"_consideration",["understood_specific_need"])
			LifeSystem.change({"engagement":4,"security":3},"和"+GuidanceSystem.source_name(npc)+"一起做了一件小事。")
			words=str(scene[5])+"\n这件事已经留在人物页。"
		"signature":
			# Shared knowledge never substitutes for this role's own two encounters.
			if p.facets.filter(func(f: Dictionary) -> bool: return str(f.role)==GameState.current_role).size()<2: GameState.load_save_data(snapshot); return LifeSystem.fail("听来的故事还不等于自己经历过的相处。")
			RelationshipSystem.set_confirmation(npc,"granted")
			p.signed={"day":GameState.current_day,"minute":GameState.current_minute,"role":GameState.current_role}
			words="一起翻过那些记录，对方在人物页写下了名字。"
	GameState.meet_resident(npc)
	return LifeSystem.persist(snapshot,words)

func exchange() -> void:
	if not CharacterSystem.switch_unlocked(): return
	GameState.commit_active_role_state()
	var shared: Dictionary=GameState.shared_state.get_or_add("shared_people_facets",{})
	for role in ["A","B"]:
		var book: Dictionary=GameState.role_states.get(role,{}).get("artifacts",{}).get("people_puzzle",{})
		for npc in book:
			var facets: Array=shared.get_or_add(npc,[])
			for facet in book[npc].get("facets",[]):
				if not facets.any(func(f: Dictionary) -> bool: return str(f.id)==str(facet.id) and str(f.role)==str(facet.role)): facets.append(facet.duplicate(true))

func text_for(npc: String) -> String:
	var rows: Array=page(npc).facets.duplicate(true)
	if CharacterSystem.switch_unlocked():
		for facet in GameState.shared_state.get("shared_people_facets",{}).get(npc,[]):
			if str(facet.role)!=GameState.current_role: rows.append(facet)
	var lines: Array[String]=[]
	for f in rows:
		lines.append("%s\n%s\n— %s · 第%d天 %s%s"%[f.title,f.text,f.source,int(f.day),GuidanceSystem.time_text(int(f.minute))," · "+str(f.role)+" 的经历" if CharacterSystem.switch_unlocked() else ""])
	lines.append("已经留下签名。" if GameState.confirmed_residents.has(npc) else "还留着一页空白，等下一次实际相处。")
	return "\n\n".join(lines)
