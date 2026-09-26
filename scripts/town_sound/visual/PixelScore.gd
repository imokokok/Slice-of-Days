extends RefCounted
## Original, seekable pixel animation. No RedSkill templates or CDN images used.
## Every frame depends only on source time, signal and seed, including after cuts.
const BOARD := Vector2(384,216)
const PAPER := Color("eee6d4")
const PAPER_EDGE = preload("res://art/town_sound_cc0/card.png")
# Pigments share the surrounding game's paper, sea green and clay palette.
# A sound changes the drawing, rather than opening a separate dark display.
const PALETTES := {
	"fire":["ddc9ae","99775f","be875e","f5e6bf"], "wind":["cfd8c9","8d9e83","517c70","f7efd6"],
	"water":["abc3b8","729a90","4d7c78","f5ecd3"], "rain":["bcc8bf","8d9f97","567979","f3ead3"],
	"bird":["e3d9bc","b2bda2","47797a","fff8df"], "paper":["e8dfc7","bf9f7a","987563","fff8e4"],
	"wood":["ddd1b0","ac9972","65775e","faf1d7"], "metal":["c2c7b8","87968c","718274","f6ebc9"],
	"voice":["ded0c9","b18486","776f8e","fff0d5"], "pulse":["e8dfc8","b98965","537a82","f9f2dc"]}

static func unit(seed_value:int,index:int) -> float:
	return float(posmod(seed_value*31+index*7919+index*index*17,1009))/1009.0

static func response(raw:float) -> float:
	return sqrt(clampf((raw-.00008)*6.0,0,1))

static func paint(c:CanvasItem,extent:Vector2,seconds:float,energy:float,bands:PackedFloat32Array,kind:String,seed_value:int) -> void:
	if extent.x<=0 or extent.y<=0: return
	var colors:Array[Color]=[]
	for hex in PALETTES.get(kind,PALETTES.pulse): colors.append(Color(hex))
	var e:=response(energy)
	var bass:=response(bands[0]) if bands.size()>0 else e
	var high:=response(bands[-1]) if bands.size()>0 else e
	var t:=floorf(maxf(0,seconds)*24)/24.0
	if e<=.01: t=0.0
	c.draw_set_transform(Vector2.ZERO,0,extent/BOARD)
	c.draw_rect(Rect2(Vector2.ZERO,BOARD),colors[0])
	# Fixed fibres and broad landscape washes leave a calm, coherent backdrop.
	for layer in 3:
		var silhouette:=PackedVector2Array([Vector2(0,216)])
		for x in range(0,389,4):
			var y:=91+layer*43+sin(x*.013+layer*1.7+unit(seed_value,3)*3)*13
			silhouette.append(Vector2(x,floorf(y)))
		silhouette.append(Vector2(384,216))
		c.draw_colored_polygon(silhouette,Color(colors[1],.12+layer*.06))
	for i in 180:
		c.draw_rect(Rect2(unit(seed_value,i)*384,unit(seed_value,i+503)*216,1,1),Color(colors[3],.06))
	match kind:
		"fire": fire(c,t,e,bass,high,seed_value,colors)
		"wind","wood": meadow(c,t,e,bass,high,seed_value,colors,kind=="wood")
		"water": water(c,t,e,bass,high,seed_value,colors)
		"rain","metal": hanging(c,t,e,bass,high,seed_value,colors,kind=="metal")
		"bird": birds(c,t,e,bass,high,seed_value,colors)
		"paper": paper(c,t,e,bass,high,seed_value,colors)
		"voice": voice(c,t,e,bass,high,seed_value,colors)
		_: geometry(c,t,e,bass,high,seed_value,colors)
	paper_mount(c,seed_value)
	c.draw_set_transform(Vector2.ZERO)

static func paper_mount(c:CanvasItem,seed_value:int) -> void:
	# Fixed paper fibres sit above every pigment, including the moving strokes.
	# This is the same CC0 material edge used by the surrounding guidance cards.
	for i in 260:
		var at:=Vector2(unit(seed_value,i+991)*384,unit(seed_value,i+1301)*216).floor()
		c.draw_line(at,at+Vector2(1+i%3,0),Color(PAPER,.11))
	# The wash fades into the paper; there is no black bezel or glowing border.
	for inset in 12:
		var ink:=Color(PAPER,1.0 if inset<5 else pow((12-inset)/8.0,2)*.6)
		c.draw_rect(Rect2(inset,inset,384-inset*2,1),ink)
		c.draw_rect(Rect2(inset,215-inset,384-inset*2,1),ink)
		c.draw_rect(Rect2(inset,inset+1,1,214-inset*2),ink)
		c.draw_rect(Rect2(383-inset,inset+1,1,214-inset*2),ink)
	var edge:=StyleBoxTexture.new(); edge.texture=PAPER_EDGE; edge.modulate_color=Color(PAPER,.42); edge.draw_center=false
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: edge.set_texture_margin(side,4)
	c.draw_style_box(edge,Rect2(Vector2.ZERO,BOARD))

static func line(c:CanvasItem,points:PackedVector2Array,color:Color,width:=1.0) -> void:
	for i in points.size(): points[i]=points[i].floor()
	if points.size()>1: c.draw_polyline(points,color,width,false)

static func orb(c:CanvasItem,at:Vector2,r:float,color:Color,phase:=0.0) -> void:
	if r<3:
		c.draw_rect(Rect2(at.floor()-Vector2.ONE,Vector2.ONE*maxf(1,floorf(r))),color); return
	var p:=PackedVector2Array()
	for i in 12:
		var angle:=i*TAU/12
		p.append((at+Vector2(cos(angle),sin(angle))*r*(1+.07*sin(i*2.3+phase))).floor())
	if r>=1: c.draw_colored_polygon(p,color)

static func spark(c:CanvasItem,at:Vector2,r:float,color:Color) -> void:
	if r<5:
		var center:=at.floor()
		c.draw_line(center-Vector2(r,0),center+Vector2(r,0),color)
		c.draw_line(center-Vector2(0,r),center+Vector2(0,r),color); return
	var p:=PackedVector2Array()
	for i in 8:
		var angle:=i*TAU/8
		p.append((at+Vector2(cos(angle),sin(angle))*(r if i%2==0 else r*.19)).floor())
	if r>=1: c.draw_colored_polygon(p,color)

static func meadow(c:CanvasItem,t:float,e:float,b:float,h:float,s:int,p:Array[Color],woody:bool) -> void:
	for i in 22:
		var u:=unit(s,i); var x:=70+u*229
		var height:=24+unit(s,i+41)*118
		var sway:=sin(t*.85+u*6)*(3+e*18)
		var tip:=Vector2(x+sway,196-height*(.85+b*.15))
		var points:=PackedVector2Array()
		for j in 16:
			var f:=j/15.0
			points.append(Vector2(x+sway*f*f+sin(f*PI)*e*4,196+(tip.y-196)*f))
		line(c,points,Color(p[2],.6),2 if woody else 1)
		orb(c,tip,2.2+u*2.8+e*3,p[3],u*9)
		if h>.2 and i%4==0: spark(c,tip+Vector2(3,-3),2+h*4,Color(p[3],.75))
		if woody:
			for j in [7,10,13]:
				var end:=points[j]+Vector2((9+u*12)*(1 if (i+j)%2 else -1),-9-e*8)
				line(c,PackedVector2Array([points[j],end]),p[2])
				orb(c,end,2+e*3,p[1])
		elif i%3==0: orb(c,tip+Vector2(-1,1),2+e,p[1])
	for i in 9:
		var x:=fposmod(unit(s,i+90)*380+t*17,410)-13
		var y:=45+unit(s,i+140)*112+sin(x*.027)*e*8
		line(c,PackedVector2Array([Vector2(x,y),Vector2(x+4+e*8,y-1)]),Color(p[3],e*.7))

static func water(c:CanvasItem,t:float,e:float,b:float,h:float,s:int,p:Array[Color]) -> void:
	orb(c,Vector2(284,49),18,p[3])
	for row in 17:
		var points:=PackedVector2Array()
		for x in range(17,370,3):
			points.append(Vector2(x,98+row*6+sin(x*.032+t*1.2+row*.7)*e*(2+b*8)))
		line(c,points,Color(p[3] if row%4==0 else p[2],.14+row*.02))
	for i in 16:
		var u:=unit(s,i); var phase:=fposmod(t*.28+u,1)
		var at:=Vector2(60+u*267,120+unit(s,i+19)*72)
		var points:=PackedVector2Array()
		for j in 33:
			var a:=j*TAU/32
			points.append(at+Vector2(cos(a),sin(a)*.24)*(3+phase*19)*e)
		line(c,points,Color(p[3],(1-phase)*e*.8))
		if i%4==0: spark(c,at,2+h*4,Color(p[3],e))

static func hanging(c:CanvasItem,t:float,e:float,b:float,h:float,s:int,p:Array[Color],metal:bool) -> void:
	if metal:
		for i in 2:
			var center:=Vector2(158+i*73,47+i*9)
			var points:=PackedVector2Array()
			for j in 50: points.append(center+Vector2(cos(j*TAU/49),sin(j*TAU/49))*(28-i*9+b*2))
			line(c,points,Color(p[3],.85))
	for i in 23:
		var u:=unit(s,i); var x:=83+i*9.8 if metal else 52+i*12.3
		var start:=72+sin(i*.24)*8 if metal else 23.0
		var length:=47+u*96 if metal else 76+u*100
		var points:=PackedVector2Array()
		for j in 16:
			var f:=j/15.0
			points.append(Vector2(x+sin(t*.8+u*8-f)*f*f*(3+e*14),start+f*length))
		line(c,points,Color(p[2],.18+.22*e))
		if metal:
			spark(c,points[-1],2+(.5+.5*sin(t*1.3+u*7))*3+h*6,Color(p[3],.4+e*.6))
			if i%3==0: orb(c,points[9],1+e*2,p[2])
		else:
			for bead in 3:
				var at:=fposmod(u+bead*.31+t*.14,1)
				var pos:=Vector2(x+sin(t*.8+u*8-at)*at*at*(3+e*14),start+at*length)
				orb(c,pos,1+e*(1+u*2),Color(p[3],.25+e*.7))
			if i%4==0: spark(c,points[-1],1+h*5,Color(p[3],e))

static func fire(c:CanvasItem,t:float,e:float,b:float,h:float,s:int,p:Array[Color]) -> void:
	for layer in 3:
		var shape:=PackedVector2Array([Vector2(116+layer*17,194)])
		for x in range(116+layer*17,270-layer*17,2):
			var distance:=absf(x-193.0)/(77-layer*17)
			var height:=pow(maxf(0,1-distance),.7)*(36+e*83)*(1-layer*.15)
			shape.append(Vector2(x,minf(193,194-height+(sin(x*.17+t*3)+sin(x*.07-t*2))*e*8)).floor())
		shape.append(Vector2(270-layer*17,194))
		c.draw_colored_polygon(shape,Color(p[layer+1],.7))
	for i in 24:
		var u:=unit(s,i); var life:=fposmod(t*(.19+u*.14)+u,1)
		var x:=191+sin(u*13+life*4)*(12+life*67)
		var y:=192-life*161
		line(c,PackedVector2Array([Vector2(x,y+3+e*6),Vector2(x+1,y)]),Color(p[2],(1-life)*e*.65))
		if i%3==0: spark(c,Vector2(x,y),1+h*3,Color(p[3],(1-life)*e))
	orb(c,Vector2(189,184),6+b*8,Color(p[3],e*.75))

static func birds(c:CanvasItem,t:float,e:float,b:float,h:float,s:int,p:Array[Color]) -> void:
	orb(c,Vector2(99,57),22,Color(p[3],.8))
	for i in 14:
		var u:=unit(s,i); var x:=fposmod(380+u*440-t*19,458)-37
		var y:=64+u*82+sin(x*.012+u*5)*29*e
		var wing:=(2+u*6)*(sin(t*(3+u)+u*6)*e)
		var at:=Vector2(x,y)
		line(c,PackedVector2Array([at+Vector2(-9-u*3,-wing),at+Vector2(-4,-1),at,at+Vector2(4,-2),at+Vector2(10+u*3,-wing)]),p[2])
		line(c,PackedVector2Array([at+Vector2(-1,1),at+Vector2(2,4+h*3),at+Vector2(4,2)]),Color(p[2],.7))
		if i%5==0: line(c,PackedVector2Array([at+Vector2(15,2),at+Vector2(30+b*13,4)]),Color(p[1],e*.8))

static func paper(c:CanvasItem,t:float,e:float,b:float,h:float,s:int,p:Array[Color]) -> void:
	for i in 17:
		var u:=unit(s,i); var at:=Vector2(77+u*225,40+unit(s,i+81)*140)
		at+=Vector2(sin(t*.7+u*5)*e*8,cos(t*.6+u*8)*e*11)
		var r:=5+unit(s,i+14)*12+b*3
		var angle:=u*2+sin(t*.6+u)*e*.2
		var points:=PackedVector2Array()
		for v in [Vector2(-1,-.7),Vector2(.7,-1),Vector2(1,.7),Vector2(-.7,1)]: points.append((at+v.rotated(angle)*r).floor())
		c.draw_colored_polygon(points,p[3] if i%3 else p[1])
		line(c,PackedVector2Array([points[0],points[2]]),Color(p[2],.4))
		if i%4==0: line(c,PackedVector2Array([points[0],points[0]-Vector2(5+h*8,12)]),Color(p[2],.3))

static func voice(c:CanvasItem,t:float,e:float,b:float,h:float,s:int,p:Array[Color]) -> void:
	for row in 12:
		var points:=PackedVector2Array()
		for x in range(38,351,3):
			var envelope:=sin((x-38)/313.0*PI)
			var y:=83+row*5+sin(x*.027+t*1.6+row*.3)*envelope*(7+e*32)+sin(x*.11+t*2)*h*6
			points.append(Vector2(x,y))
		line(c,points,Color(p[2] if row%3 else p[1],.28+row*.035))
	for i in 9:
		var x:=71+unit(s,i)*235
		orb(c,Vector2(x,79+sin(x*.027+t*1.6)*e*32),2+b*5,Color(p[3],.8))

static func geometry(c:CanvasItem,t:float,e:float,b:float,h:float,s:int,p:Array[Color]) -> void:
	var center:=Vector2(123+unit(s,1)*35,88)
	orb(c,center,29+b*8,p[2]); orb(c,center+Vector2(-8,2),17,p[0])
	line(c,PackedVector2Array([Vector2(74,171),Vector2(305,59)]),p[2])
	for i in 9:
		var x:=174+i*11.5; var at:=Vector2(x,150-(x-174)*.47)
		line(c,PackedVector2Array([at-Vector2(6,12),at+Vector2(9,18+e*14)]),Color(p[2],.8))
	c.draw_colored_polygon(PackedVector2Array([Vector2(217,78),Vector2(182,165),Vector2(247,160)]),Color(p[1],.7))
	for i in 12:
		var u:=unit(s,i); var at:=Vector2(67+u*247,57+unit(s,i+17)*111)
		at.y+=sin(t+u*7)*e*4
		if i%3: orb(c,at,2+u*4+h*3,p[2])
		else: spark(c,at,3+h*5,p[3])
