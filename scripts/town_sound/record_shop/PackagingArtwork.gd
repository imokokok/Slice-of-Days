extends RefCounted
## Separate back/content/front passes, all in the same table coordinate system.
const PAPER=Color("eee8d8")
const INK=Color("343a39")
const SHELF_SPINE:=Rect2(446,380,14,121)

static func fitted(c: CanvasItem, text: String, point: int, width: float) -> String:
	var font: Font=c.get_theme_default_font()
	if font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x<=width: return text
	while not text.is_empty():
		text=text.left(text.length()-1)
		if font.get_string_size(text+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,point).x<=width: return text+"…"
	return ""

static func shelf_hit_rect() -> Rect2:
	return Rect2(SHELF_SPINE.position+Vector2(0,125),SHELF_SPINE.size).grow(12)

static func shelf_pose(progress: float, origin: Vector2) -> Dictionary:
	var t:=clampf(progress,0,1)
	var turn:=smoothstep(.08,.78,t)*PI*.5
	var height:=lerpf(282,121,smoothstep(0,.8,t))
	var center:=origin.lerp(SHELF_SPINE.get_center(),smoothstep(0,1,t))-Vector2(0,48*sin(t*PI))
	var face_width:=278*height/282*maxf(0,cos(turn))
	var spine_width:=14*sin(turn)*height/121
	var spine_rect:=Rect2(center-Vector2((face_width+spine_width)*.5,height*.5),Vector2(spine_width,height))
	return {"face_scale":Vector2(face_width/278,height/282),"face_center":center+Vector2(spine_width*.5,0),"spine":spine_rect}

static func spine(c: CanvasItem, rect: Rect2, title: String, number: int, tint: Color) -> void:
	c.draw_rect(rect,tint)
	c.draw_line(rect.position,Vector2(rect.position.x,rect.end.y),Color(0,0,0,.23),1)
	c.draw_line(Vector2(rect.end.x-1,rect.position.y),rect.end-Vector2(1,0),Color(1,1,1,.52),1)
	if rect.size.x<7: return
	var point:=mini(9,int(rect.size.x-5))
	c.draw_set_transform(rect.position+Vector2((rect.size.x-point)*.5,133),PI*.5)
	words(c,Vector2.ZERO,fitted(c,title,point,rect.size.y-33),point)
	c.draw_set_transform(Vector2(0,125))
	words(c,Vector2(rect.position.x+2,rect.end.y-6),"%02d"%number,7)

static func shelve(c: Control, progress: float, origin: Vector2) -> void:
	var pose:=shelf_pose(progress,origin)
	var face_scale: Vector2=pose.face_scale
	if face_scale.x>.001:
		c.draw_set_transform(pose.face_center+Vector2(0,125),0,face_scale)
		packed(c,Vector2.ZERO,c.texture,c.serial,true)
	c.draw_set_transform(Vector2(0,125))
	var record: Dictionary=c.get_meta("album_record",{})
	spine(c,pose.spine,str(record.get("title","今天听见的东西")),c.serial,Color("f6f0df"))

static func words(c: CanvasItem, at: Vector2, value: String, font_size:=16, color:=INK) -> void:
	c.draw_string(c.get_theme_default_font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

static func shadow(c: CanvasItem, rect: Rect2, depth:=6.0) -> void:
	for i in range(5,0,-1):
		c.draw_rect(Rect2(rect.position+Vector2(depth*.6,depth)+Vector2(-i,-i),rect.size+Vector2(i*2,i*2)),Color(0.09,0.10,0.10,.016))

static func label(c: CanvasItem, center: Vector2, radius:=36.0) -> void:
	c.draw_circle(center,radius,Color("ba7356"))
	c.draw_arc(center,radius-3,0,TAU,96,Color("ebc7ac"),.8,true)
	var record: Dictionary=c.get_meta("album_record",{})
	var title:=fitted(c,str(record.get("title","SOLMERE")),9,58)
	var by:=fitted(c,str(record.get("artist","FIELD RECORDINGS")),7,52)
	var font: Font=c.get_theme_default_font()
	words(c,center+Vector2(-font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x*.5,-13),title,9,Color("fff3dd"))
	words(c,center+Vector2(-18,21),"SIDE A",9,Color("fff3dd"))
	words(c,center+Vector2(-font.get_string_size(by,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x*.5,10),by,7,Color("f1d8c3"))
	c.draw_circle(center,2.6,Color("c2ad91"))

static func disc(c: CanvasItem, center: Vector2, shade:=true) -> void:
	if shade:
		for i in 5: c.draw_circle(center+Vector2(2,5),114+i,Color(0,0,0,.018))
	c.draw_circle(center,113,Color("101616"))
	c.draw_arc(center,112,0,TAU,160,Color("555e5a"),1.1,true)
	for i in range(40,110,2):
		c.draw_arc(center,i,0,TAU,144,Color("303835") if i%6==0 else Color("232b29"),.55,true)
	# Specular light follows the radial grooves, not a white circle painted on top.
	for i in range(43,109):
		c.draw_arc(center,i,-1.20,-.85,16,Color(.75,.83,.80,.13),.65,true)
		c.draw_arc(center,i,1.94,2.25,16,Color(.65,.76,.75,.08),.65,true)
	c.draw_arc(center,39,0,TAU,80,Color("525a55"),.6,true)
	label(c,center)

static func paper_back(c: CanvasItem, center: Vector2) -> void:
	var r:=Rect2(center-Vector2(123,125),Vector2(246,250))
	shadow(c,r)
	c.draw_rect(r,Color("c6c1b4"))
	c.draw_rect(Rect2(r.position+Vector2(4,0),Vector2(238,12)),Color("716c61"))

static func paper_front(c: CanvasItem, center: Vector2) -> void:
	# A real transparent die-cut hole: the record remains visible ONLY through it.
	# Each quad joins the circular hole to the rectangular paper boundary.
	for i in 128:
		var a:=TAU*float(i)/128
		var b:=TAU*float(i+1)/128
		var u:=Vector2(cos(a),sin(a)); var v:=Vector2(cos(b),sin(b))
		var ru:=minf(123/maxf(absf(u.x),.0001),121/maxf(absf(u.y),.0001))
		var rv:=minf(123/maxf(absf(v.x),.0001),121/maxf(absf(v.y),.0001))
		c.draw_colored_polygon(PackedVector2Array([center+u*43,center+u*ru,center+v*rv,center+v*43]),PAPER)
	c.draw_arc(center,43,0,TAU,96,Color("b6b0a1"),1,true)
	for side in [-1,1]:
		c.draw_line(center+Vector2(side*116,-111),center+Vector2(side*116,115),Color("d0c9b9"),1)
	c.draw_line(center+Vector2(-119,116),center+Vector2(119,116),Color("d0c9b9"),1)
	c.draw_line(center+Vector2(-123,-121),center+Vector2(123,-121),Color("faf5e9"),2)
	words(c,center+Vector2(-95,101),"PAPER · INNER SLEEVE",10,Color("8a887c"))

static func paper(c: CanvasItem, center: Vector2) -> void:
	paper_back(c,center); disc(c,center,false); paper_front(c,center)

static func jacket_back(c: CanvasItem, center: Vector2) -> void:
	var r:=Rect2(center-Vector2(131,131),Vector2(262,262))
	shadow(c,r)
	c.draw_rect(r,Color("9c927e"))
	c.draw_rect(Rect2(center+Vector2(123,-127),Vector2(9,254)),Color("4c4a40"))

static func jacket_front(c: CanvasItem, center: Vector2, texture: Texture2D) -> void:
	var r:=Rect2(center-Vector2(131,131),Vector2(256,262))
	c.draw_rect(r,Color("eee4d0"))
	if texture!=null: c.draw_texture_rect(texture,r.grow(-7),false)
	c.draw_line(r.position,r.position+Vector2(0,r.size.y),Color("a79a81"),3)
	c.draw_line(r.position+Vector2(3,0),r.position+Vector2(r.size.x,0),Color("fff2d6"),1)
	c.draw_line(center+Vector2(124,-126),center+Vector2(124,126),Color("f7efde"),1.5)
	# Small spine remains a separate, opaque board edge.
	c.draw_line(center+Vector2(-127,-126),center+Vector2(-127,126),Color(0,0,0,.14),1)

static func jacket(c: CanvasItem, center: Vector2, texture: Texture2D) -> void:
	jacket_back(c,center); jacket_front(c,center,texture)

static func plastic_back(c: CanvasItem, center: Vector2, folded:=0.0) -> void:
	var r:=Rect2(center-Vector2(139,141),Vector2(278,282))
	shadow(c,r,2)
	c.draw_rect(r,Color(.78,.88,.87,.06))
	var y:=center.y-141
	var flap_y:=lerpf(y-37,y+32,folded)
	c.draw_colored_polygon(PackedVector2Array([Vector2(center.x-137,y),Vector2(center.x-133,flap_y),Vector2(center.x+133,flap_y),Vector2(center.x+137,y)]),Color(.85,.93,.92,.14))
	c.draw_line(Vector2(center.x-130,flap_y+3),Vector2(center.x+130,flap_y+3),Color(.94,.97,.92,.64),3)

static func plastic_front(c: CanvasItem, center: Vector2, folded:=0.0) -> void:
	var r:=Rect2(center-Vector2(139,141),Vector2(278,282))
	# Transparent polypropylene: retain the cover underneath, with double seams,
	# broad low-opacity reflection, narrow highlights and corner tension wrinkles.
	c.draw_rect(r,Color(.80,.91,.94,.045))
	for inset in [0,3]:
		c.draw_line(r.position+Vector2(inset,0),r.position+Vector2(inset,r.size.y-inset),Color(.96,.99,1,.42),.8,true)
		c.draw_line(r.end-Vector2(inset,inset),Vector2(r.end.x-inset,r.position.y),Color(.98,.99,1,.5),.8,true)
		c.draw_line(r.position+Vector2(inset,r.size.y-inset),r.end-Vector2(inset,inset),Color(.93,.98,1,.55),1,true)
	c.draw_line(r.position,r.position+Vector2(r.size.x,0),Color(.94,.99,1,.65),1.2,true)
	c.draw_colored_polygon(PackedVector2Array([r.position+Vector2(9,14),r.position+Vector2(28,14),r.position+Vector2(136,268),r.position+Vector2(108,268)]),Color(1,1,1,.065))
	c.draw_line(r.position+Vector2(14,24),r.position+Vector2(17,190),Color(1,1,1,.38),1.3,true)
	c.draw_line(r.position+Vector2(254,32),r.position+Vector2(257,166),Color(1,1,1,.26),1.2,true)
	for corner in [r.position+Vector2(4,7),r.end-Vector2(4,7)]:
		var direction:=1 if corner.x<center.x else -1
		for i in 3:
			c.draw_line(corner,corner+Vector2(direction*(12+i*7),direction*(8+i*9)),Color(1,1,1,.19),.8,true)
	if folded>0:
		var y:=center.y-141
		var bottom:=y+32*folded
		c.draw_rect(Rect2(center.x-133,y,266,32*folded),Color(.9,.97,1,.09))
		c.draw_line(Vector2(center.x-130,bottom),Vector2(center.x+130,bottom),Color(1,1,1,.57),1,true)

static func packed(c: CanvasItem, center: Vector2, texture: Texture2D, serial: int, numbered:=false, folded:=1.0) -> void:
	plastic_back(c,center,folded); jacket(c,center,texture); plastic_front(c,center,folded)
	if numbered: serial_label(c,center+Vector2(60,107),serial)

static func serial_label(c: CanvasItem, center: Vector2, serial: int) -> void:
	var r:=Rect2(center-Vector2(59,15),Vector2(118,30))
	shadow(c,r,1); c.draw_rect(r,Color("f6efdb"))
	words(c,center+Vector2(-51,4),"LOCAL-%04d"%serial,13)

static func paint(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO,c.size),Color("ece7db"))
	c.draw_rect(Rect2(28,324,1035,535),Color("b7a081"))
	for i in 40:
		c.draw_line(Vector2(30,330+i*13),Vector2(1061,332+i*13),Color(.28,.23,.18,.055),.7,true)
	if c.step==0:
		var note:=Rect2(126,370,758,395)
		shadow(c,note); c.draw_rect(note,Color("faf0d9"))
		c.draw_rect(Rect2(387,356,210,29),Color("c6b77f",.75))
		words(c,Vector2(170,420),"留给这段声音的话",26)
		words(c,Vector2(1140,426),"一张唱片，慢慢做。",24)
		words(c,Vector2(1140,476),"先写下名字与作者，",19)
		words(c,Vector2(1140,511),"再留下声音里的一个画面。",19)
		disc(c,Vector2(1280,700))
		return
	if c.step==1:
		words(c,Vector2(604,421),"声音里，哪一刻最像今天？",24)
		words(c,Vector2(604,468),"拖动取景条，再点左边画面。",18)
		words(c,Vector2(604,504),"也可以翻开本地相册，选自己拍的照片。",18)
		return
	for i in range(2,11):
		var x:=110.0+(i-2)*105
		if i<10: c.draw_line(Vector2(x,277),Vector2(x+105,277),Color("cec5b4"),2)
		c.draw_circle(Vector2(x,277),15,Color("7d8a74") if i<c.step else (Color("a15f47") if i==c.step else Color("d5cebf")))
		words(c,Vector2(x-4,282),str(i-1),12,Color("fffaef"))
		words(c,Vector2(x-24,311),["封套","装标","压制","内袋","纸套","外袋","封口","编号","入库"][i-2],12)
	var left:=Vector2(320,505); var right:=Vector2(760,505)
	var moving: Vector2=(c.drag_position if c.dragging else c.source_rect().get_center())-Vector2(0,125)
	var origin: Vector2=c.action_origin-Vector2(0,125)
	if c.dragging:
		var destination: Rect2=c.target_rect()
		c.draw_rect(destination,Color(.4,.62,.48,.10))
		c.draw_rect(destination,Color(.28,.47,.33,.65),false,1.5)
	if c.locked:
		if c.step in [5,7]:
			var entry:=right-Vector2(0,170)
			moving=origin.lerp(entry,smoothstep(0,.4,c.progress)) if c.progress<.4 else entry.lerp(right,smoothstep(.4,1,c.progress))
		elif c.step==6: moving=origin.lerp(left,c.progress)
		else: moving=origin.lerp(c.target_rect().get_center()-Vector2(0,125),c.progress)
	c.draw_set_transform(Vector2(0,125))
	match c.step:
		2:
			c.draw_rect(Rect2(180,366,460,120),Color("53645d"))
			c.draw_rect(Rect2(206,465,405,14),Color("202e29"))
			c.draw_circle(Vector2(576,416),23,Color("b4ca8d"))
			words(c,Vector2(220,414),"JACKET PRINT / 20 pt BOARD",23,Color("f5ecdb"))
			if c.locked:
				var h: float=228*c.progress
				c.draw_rect(Rect2(260,479,250,h),PAPER)
				if c.texture!=null and h>1:
					c.draw_texture_rect_region(c.texture,Rect2(263,479,244,h),Rect2(0,0,512,512*c.progress))
			words(c,Vector2(700,430),"印刷与折糊后的纸板封套",18)
			jacket(c,Vector2(803,581),c.texture)
		3:
			c.draw_circle(left+Vector2(0,8),67,Color("332f29"))
			c.draw_circle(left,64,Color("161e1b"))
			c.draw_arc(left,64,0,TAU,90,Color("56625a"),2,true)
			c.draw_circle(left,4,Color("bfb8a5"))
			label(c,moving)
			words(c,Vector2(204,665),"PVC 料饼 · B 面标签已装载",16)
		4:
			c.draw_rect(Rect2(225,354,645,322),Color("65746d"))
			c.draw_rect(Rect2(269,583,470,54),Color("3a4b45"))
			var center:=Vector2(510,522)
			c.draw_circle(center,124,Color("939e95"))
			if c.progress>.38: disc(c,center,false)
			else: c.draw_circle(center,64,Color("151c19")); label(c,center)
			var lid: float=384.0+sin(c.progress*PI)*118
			c.draw_rect(Rect2(370,lid,282,32),Color("adb9b3"))
			c.draw_line(Vector2(511,354),Vector2(511,lid),Color("d0d8d0"),20)
			var pull: float=c.lever_pull if not c.locked else 120.0
			c.draw_line(Vector2(744,450),Vector2(813,388+pull),Color("34443b"),10)
			c.draw_circle(Vector2(813,388+pull),22,Color("a4523b"))
			if not c.locked:
				c.draw_line(Vector2(858,400),Vector2(858,535),Color("eadfc6"),2)
				c.draw_line(Vector2(850,526),Vector2(858,535),Color("eadfc6"),2)
				c.draw_line(Vector2(866,526),Vector2(858,535),Color("eadfc6"),2)
				words(c,Vector2(640,657),"向下拉，再保持半秒",16,Color("fff6dd"))
			words(c,Vector2(270,703),"装载双面标签与料饼 → 压制 → 冷却 → 修边与检视",17)
		5:
			paper_back(c,right); disc(c,moving); paper_front(c,right)
			words(c,Vector2(597,695),"纸袋顶端开口 · 标签从圆窗露出",16)
		6:
			jacket_back(c,left); paper(c,moving); jacket_front(c,left,c.texture)
			words(c,Vector2(192,695),"封套右侧开口 · 内袋开口朝上，避免唱片滑出",16)
		7:
			plastic_back(c,right); jacket(c,moving,c.texture); plastic_front(c,right)
			words(c,Vector2(570,695),"透明 PP 外袋 · 防止封面磨损，唱片不直接接触它",16)
		8:
			var fold: float=c.progress if c.locked else (clampf((moving.y-330)/58,0,1) if c.dragging else 0.0)
			packed(c,right,c.texture,c.serial,false,fold)
			words(c,Vector2(173,464),"揭开离型条，向下折合透明翻盖。",18)
			words(c,Vector2(173,500),"胶条落在保护袋上，不贴封面。",17)
		9:
			packed(c,right,c.texture,c.serial,false)
			serial_label(c,moving,c.serial)
			words(c,Vector2(173,650),"编号贴在保护袋外侧 · 封面保持完整",16)
		10,11:
			c.draw_rect(Rect2(163,363,330,294),Color("695c4c"))
			c.draw_rect(Rect2(173,373,310,131),Color("443f35"))
			var titles: Array[String]=["海风经过","午后电台","小巷里的雨","旧车站","纸上的夏天","晚饭以前","灯还亮着","日落之后"]
			for i in 8:
				spine(c,Rect2(180+i*32,380,24,121),titles[i],i+1,Color("9c9e81") if i%2 else Color("b89a7e"))
			c.draw_rect(Rect2(171,540,314,109),Color("8f7a5e"))
			c.draw_line(Vector2(173,504),Vector2(483,504),Color("ae9778"),4)
			words(c,Vector2(191,528),"LOCAL RECORDINGS",20,Color("f4ecda"))
			if c.step==11 or c.locked:
				var t: float=1 if c.step==11 else c.progress
				shelve(c,t,origin)
			else: packed(c,moving,c.texture,c.serial,true)
			if c.step==11:
				words(c,Vector2(190,579),"已收好 · 点右边的米白色书脊",17,Color("fff4df"))
				words(c,Vector2(190,611),"拿近看看你的唱片",17,Color("fff4df"))
				c.draw_line(Vector2(453,558),Vector2(453,509),Color("fff4df"),1)
				if c.inspecting_record:
					words(c,Vector2(628,342),"封面近看 / YOUR RECORD",19)
					c.draw_set_transform(Vector2(790,633),0,Vector2.ONE*1.12)
					packed(c,Vector2.ZERO,c.texture,c.serial,true)
					c.draw_set_transform(Vector2(0,125))
					words(c,Vector2(628,702),"标题、署名和画面一起留在唱片里。",16)
				else:
					words(c,Vector2(637,442),"留给今天的声音，",25)
					words(c,Vector2(637,484),"在这里有了自己的位置。",25)
					words(c,Vector2(637,554),"点书脊查看封面，或回店里继续听。",17)
	c.draw_set_transform(Vector2.ZERO)
	# The sidebar explains construction while keeping the work surface unobstructed.
	var notes: Array = ["","","先制作印刷封套。\n唱片与包装分别加工。","标签不是贴纸。\n纸标签随 PVC 一起压制。","母版刻录、电铸制成的\n压模已经装入机器。\n冷却后修边，检查唱片。","只握边缘与标签区。\n唱片音槽面不接触手指。","纸内袋保护音槽；\n硬纸封套保护整体。","外袋有独立的透明前片、\n背片、焊缝与翻盖。\n封面在塑料膜下面。","本店使用可重复封口外袋。\n收好翻盖，轻轻抹平。","作品编号与封面分离，\n贴在透明保护袋上。","音频、封面和包装信息\n一起保存在本地唱片架。","唱片已入库。"]
	if c.size.x>1380:
		words(c,Vector2(1135,380),"12-inch / 33⅓ RPM",25)
		words(c,Vector2(1135,414),"180 g · 黑胶 · 单张封套",18)
		var y:=475
		for line in str(notes[c.step]).split("\n"):
			words(c,Vector2(1135,y),line,18); y+=33
		words(c,Vector2(1135,681),"点书脊 → 看封面" if c.step==11 else "拿起 → 对齐开口 → 松手",17)
