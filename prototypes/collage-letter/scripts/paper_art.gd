extends Node2D

var kind: int = 0
var sheet_data: Dictionary
var font: Font
var asset_root: String = "res://assets/open_pack/"
var art: Texture2D

func _ready() -> void:
	art = load(asset_root + sheet_data.asset)
	queue_redraw()

func _draw() -> void:
	var material_kind: String = sheet_data.kind
	draw_rect(Rect2(0,0,300,240), Color("f7efdc"))
	if material_kind == "decoration":
		var fit := minf(170.0 / art.get_width(), 165.0 / art.get_height())
		var size := art.get_size() * fit
		draw_texture_rect(art, Rect2(Vector2(150,119)-size*0.5,size), false)
		return
	var bounds := Rect2(12,12,276,216)
	draw_rect(bounds, Color(sheet_data.get("color", "#faf2df")))
	if material_kind == "art":
		var fit := minf(250.0 / art.get_width(), 179.0 / art.get_height())
		var size := art.get_size() * fit
		draw_texture_rect(art, Rect2(Vector2(150,111)-size*0.5,size),false)
		draw_string(font,Vector2(24,218),sheet_data.title,HORIZONTAL_ALIGNMENT_LEFT,248,10,Color("344c50"))
		return
	draw_texture_rect(art,bounds,false,Color(1,1,1,0.10))
	var ink := Color("344c50")
	if material_kind == "paper":
		match sheet_data.pattern:
			"grid", "ruled":
				for y in range(30,216,18): draw_line(Vector2(20,y),Vector2(280,y),Color(0.32,0.49,0.5,0.2))
				if sheet_data.pattern == "grid":
					for x in range(30,282,18): draw_line(Vector2(x,20),Vector2(x,221),Color(0.32,0.49,0.5,0.2))
			"dot":
				for x in range(30,281,18):
					for y in range(30,217,18): draw_circle(Vector2(x,y),0.8,Color(0.3,0.4,0.4,0.3))
	elif material_kind == "score":
		for staff in 3:
			for row in 5: draw_line(Vector2(29,58+staff*53+row*6),Vector2(271,58+staff*53+row*6),Color(ink,0.5))
			if sheet_data.seed > 0:
				for n in 7:
					var p := Vector2(44+n*32,64+staff*53+posmod(n*7+int(sheet_data.seed)*3,5)*4)
					draw_circle(p,3,ink);draw_line(p,p-Vector2(0,21),ink,1.3)
	else:
		draw_string(font,Vector2(27,59),sheet_data.headline,HORIZONTAL_ALIGNMENT_LEFT,246,21,ink)
		draw_line(Vector2(26,73),Vector2(275,73),ink,1)
		var words := str(sheet_data.body).split(" ")
		var line := ""
		var y := 106.0
		for word in words:
			if font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x > 237:
				draw_string(font,Vector2(27,y),line,HORIZONTAL_ALIGNMENT_LEFT,245,15,ink)
				y += 24;line = ""
			line += word + " "
		draw_string(font,Vector2(27,y),line,HORIZONTAL_ALIGNMENT_LEFT,245,15,ink)
		if material_kind == "ticket":
			for x in range(22,280,9): draw_line(Vector2(x,183),Vector2(x+4,183),Color(ink,0.45))
			draw_string(font,Vector2(27,211),"KEEP THIS LITTLE MOMENT",HORIZONTAL_ALIGNMENT_LEFT,244,10,ink)
