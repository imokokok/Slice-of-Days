extends Control
## A printed sleeve, baked into the saved cover PNG rather than a UI-only caption.
const PAPER:=Color("f6f0df")
const BLUE:=Color("315675")
var picture: Texture2D
var album_title := ""
var artist := ""
var serial := 1
var print_font: Font

static func lines_for(text: String, font: Font, point: int, width: float) -> Array[String]:
	var result: Array[String]=[]
	var line:=""
	for letter in text:
		if letter=="\n" or (not line.is_empty() and font.get_string_size(line+letter,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x>width):
			result.append(line.strip_edges()); line=""
		if letter!="\n": line+=letter
	if not line.is_empty(): result.append(line.strip_edges())
	return result

static func bake(host: Control, source: Image, title: String, by: String, number: int) -> Image:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(512,512); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var art=load("res://scripts/town_sound/record_shop/AlbumCover.gd").new()
	art.size=Vector2(512,512); art.picture=ImageTexture.create_from_image(source)
	art.album_title=title; art.artist=by; art.serial=number; art.print_font=host.get_theme_default_font()
	viewport.add_child(art)
	await RenderingServer.frame_post_draw
	var result:=viewport.get_texture().get_image()
	viewport.queue_free()
	return result

func _draw() -> void:
	draw_rect(Rect2(0,0,512,512),PAPER)
	var font:Font=print_font if print_font!=null else get_theme_default_font()
	draw_string(font,Vector2(32,30),"SOLMERE  /  FIELD RECORDINGS",HORIZONTAL_ALIGNMENT_LEFT,448,11,BLUE)
	var point:=48
	var lines:=lines_for(album_title,font,point,448)
	while lines.size()*(point+4)>92 and point>18:
		point-=2; lines=lines_for(album_title,font,point,448)
	var baseline:=float(56+point)
	for line in lines:
		draw_string(font,Vector2(32,baseline),line,HORIZONTAL_ALIGNMENT_LEFT,448,point,BLUE)
		baseline+=point+4
	var by:=artist
	while font.get_string_size(by,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x>448 and by.length()>1: by=by.left(by.length()-2)+"…"
	draw_string(font,Vector2(33,161),by,HORIZONTAL_ALIGNMENT_LEFT,448,14,BLUE)
	if picture!=null:
		# A centered crop preserves image proportions in the printed image panel.
		var source_size:=picture.get_size()
		var source_height:=source_size.x*282.0/448.0
		draw_texture_rect_region(picture,Rect2(32,178,448,282),Rect2(0,(source_size.y-source_height)*.5,source_size.x,source_height))
	draw_line(Vector2(32,474),Vector2(480,474),Color(BLUE,.3),1)
	draw_string(font,Vector2(32,495),"LOCAL-%04d    •    12-inch / 33⅓ RPM"%serial,HORIZONTAL_ALIGNMENT_LEFT,448,11,BLUE)
