extends RefCounted
## Shared pixel score for live capture, saved samples, arrangements and records.
## 240 x 135 logical pixels; every frame is a pure function of audio/time/seed.
const PALETTES := {
	"fire":["261f30","c45b42","f2a65a","ffe2a1"], "wind":["233e46","62998c","a6c5a6","efe9c9"],
	"water":["1d354d","377792","79b6b4","d2e8cf"], "rain":["252e47","5c6b95","9ba8bb","d5dddf"],
	"bird":["33403d","72947b","d8b870","f2dec4"], "paper":["453c43","af9078","dec59c","f4e7cb"],
	"wood":["3c3034","926048","c39464","f0d2a0"], "metal":["2b3541","5c8492","d5a66d","e7e8ce"],
	"voice":["393147","9a6781","d59c98","f4d3b1"], "pulse":["293849","527f91","d49b59","f1d5ac"]}

static func paint(canvas: CanvasItem, extent: Vector2, seconds: float, energy: float, bands: PackedFloat32Array, kind: String, seed_value: int) -> void:
	var colors: Array = PALETTES.get(kind, PALETTES.pulse)
	var e := clampf(energy * 4.0, 0, 1)
	var bass := bands[0] if bands.size()>0 else e
	var high := bands[-1] if bands.size()>0 else e
	canvas.draw_set_transform(Vector2.ZERO, 0, extent / Vector2(240,135))
	canvas.draw_rect(Rect2(0,0,240,135), Color(colors[0]))
	# Stable terrain anchors make this a miniature scene, not floating UI confetti.
	for x in range(0,240,4):
		var ridge := 118 + int(sin(x * .04 + float(seed_value % 17)) * 4)
		canvas.draw_rect(Rect2(x,ridge,4,135-ridge), Color(colors[1],.26))
	var tick := floorf(seconds * 12) / 12.0
	# Coherent silhouettes underneath the seeded fragments preserve source identity.
	if kind=="fire":
		for layer in range(3):
			for x in range(68+layer*12,172-layer*12,4):
				var distance:=absf(float(x-120))/52.0
				var height: float=(1-distance)*(22+e*45)*(1-layer*.2)+sin(x*.17+tick*5)*e*8
				canvas.draw_rect(Rect2(x,116-height,4,height),Color(colors[layer+1]))
	elif kind in ["water","rain"]:
		for row in range(8):
			for x in range(0,240,4):
				var y:=84+row*5+int(sin(x*.055+tick*e*2+row)*3)
				canvas.draw_rect(Rect2(x,y,4,2),Color(colors[1+row%2],.5))
	elif kind=="wind":
		for x in range(0,240,6):
			var lean:=int(sin(tick*e*3+x*.1)*(2+e*7))
			canvas.draw_line(Vector2(x,121),Vector2(x+lean,106-x%11),Color(colors[2]),1)
	for i in 52:
		var h := float(posmod(seed_value + i * 7919, 997)) / 997.0
		var x := float(posmod(i * 37 + seed_value, 226) + 7)
		var y := float(posmod(i * 23 + seed_value / 7, 105) + 12)
		var color := Color(colors[1 + i % 3])
		var moving := tick * e
		match kind:
			"fire":
				x = 120 + sin(i * 2.3 + moving) * (12 + h * 65)
				y = 115 - fposmod(h * 80 + moving * (18+h*25), 90)
				canvas.draw_rect(Rect2(floorf(x),floorf(y),2+i%3,3+(1-h)*e*9), color)
			"wind":
				x = fposmod(x + moving * (15 + h * 30),240)
				y += sin(x*.05 + h*TAU)* (3 + bass*10)
				canvas.draw_rect(Rect2(floorf(x),floorf(y),4+e*18,1+i%2),color)
			"rain":
				y = fposmod(y+moving*(25+h*40),118)
				x = fposmod(x+moving*7,240)
				canvas.draw_line(Vector2(floorf(x),floorf(y)),Vector2(floorf(x)-2,floorf(y)+3+high*6),color,1)
			"water":
				y = 40+h*75+sin(tick*1.8+x*.04)*e*4
				canvas.draw_rect(Rect2(floorf(x),floorf(y),3+h*10+e*10,1),color)
			"bird":
				x = fposmod(x+moving*13,240)
				y += sin(tick*2+h*20)*e*9
				canvas.draw_line(Vector2(x-3,y-1-high*3).floor(),Vector2(x,y).floor(),color,1)
				canvas.draw_line(Vector2(x,y).floor(),Vector2(x+3,y-1-high*3).floor(),color,1)
			"paper":
				y = fposmod(y+moving*6,118)
				canvas.draw_rect(Rect2(floorf(x+sin(tick+h*20)*e*8),floorf(y),4+i%4,2+i%3),color)
			"wood":
				var height := 2 + absf(sin(i+tick*2)) * e * 40 + bass*8
				canvas.draw_rect(Rect2(x,116-height,2+i%4,height),color)
			"metal":
				var radius := 2+fposmod(h*15+moving*6,18)
				canvas.draw_rect(Rect2(Vector2(x,y)-Vector2.ONE*radius,Vector2.ONE*radius*2),color,false,1)
			"voice":
				y = 68+sin(x*.045+tick)*e*32+sin(x*.13)*high*9
				canvas.draw_rect(Rect2(x,y,3,2+e*10),color)
			_:
				var width := 2+float(i%4)+bass*7
				if i%3==0: canvas.draw_rect(Rect2(x,y+sin(tick+i)*e*5,width,width),color,false,1)
				else: canvas.draw_rect(Rect2(x,y+sin(tick+i)*e*5,width,width),color)
	# The ink horizon acts as an actual amplitude meter.
	canvas.draw_rect(Rect2(8,128,224*e,2),Color(colors[3]))
	canvas.draw_set_transform(Vector2.ZERO)
