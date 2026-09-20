extends RefCounted

const PAGE_SIZE := Vector2i(460, 300)
const FONT_SIZE := 22
const LEFT := 25.0
const RIGHT := 435.0
const BASELINE := 42.0
const LINE_HEIGHT := 34.0
const ROWS := 7

# One layout for acceptance, preview and the cuttable output. Wide fallback
# glyphs (including Chinese) occupy multiple typewriter cells, never half a cell.
static func arrange(text: String, font: Font) -> Dictionary:
	var cell := ceilf(font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var x := LEFT
	var row := 0
	var glyphs: Array = []
	for i in text.length():
		var letter := text[i]
		if letter == "\n":
			row += 1
			x = LEFT
			if row >= ROWS: return {"fits":false,"glyphs":glyphs}
			continue
		var width := font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x
		var advance := maxf(cell,ceilf(width/cell)*cell)
		if x + advance > RIGHT:
			x = LEFT
			row += 1
		if row >= ROWS: return {"fits":false,"glyphs":glyphs}
		glyphs.append({"text":letter,"position":Vector2(x,BASELINE+row*LINE_HEIGHT),"advance":advance,"index":i})
		x += advance
	return {"fits":true,"glyphs":glyphs,"cursor":Vector2(x,BASELINE+row*LINE_HEIGHT)}
