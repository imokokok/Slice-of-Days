extends RefCounted
## Non-destructive presentation of supplied artwork on white paper.
## Only border-connected paper is transparent; enclosed whites (e.g. shoes)
## retain their original RGB and opacity. Cache across street/room changes.
static var textures: Dictionary = {}

static func cutout(source: Texture2D, crop := false, paper_openings: Array[Vector2i] = []) -> Texture2D:
	var key := source.resource_path + (":cropped" if crop else ":canvas") + str(paper_openings.hash())
	if textures.has(key): return textures[key]
	var original := source.get_image()
	original.convert(Image.FORMAT_RGBA8)
	var w := original.get_width()
	var h := original.get_height()
	var pixels := original.get_data()
	var paper := PackedByteArray()
	paper.resize(w * h)
	for p in w * h:
		var i := p * 4
		var low := mini(pixels[i], mini(pixels[i + 1], pixels[i + 2]))
		var high := maxi(pixels[i], maxi(pixels[i + 1], pixels[i + 2]))
		paper[p] = 1 if low >= 240 and high - low <= 16 else 0
	# Scanline flood fill avoids queuing every individual background pixel.
	var queue := PackedInt32Array()
	# Authored open railings can enclose white paper without connecting to an
	# image edge. Explicit image coordinates distinguish them from white paint.
	for opening in paper_openings:
		if opening.x >= 0 and opening.x < w and opening.y >= 0 and opening.y < h:
			queue.append(opening.y * w + opening.x)
	for x in w:
		if paper[x] == 1: queue.append(x)
		if paper[(h - 1) * w + x] == 1: queue.append((h - 1) * w + x)
	for y in range(1, h - 1):
		if paper[y * w] == 1: queue.append(y * w)
		if paper[y * w + w - 1] == 1: queue.append(y * w + w - 1)
	var next := 0
	while next < queue.size():
		var point := queue[next]
		next += 1
		if paper[point] != 1: continue
		var row := point / w
		var left := point
		var right := point
		while left > row * w and paper[left - 1] == 1: left -= 1
		while right < (row + 1) * w - 1 and paper[right + 1] == 1: right += 1
		var above := false
		var below := false
		for p in range(left, right + 1):
			paper[p] = 2
			pixels[p * 4 + 3] = 0
			if row > 0:
				var eligible := paper[p - w] == 1
				if eligible and not above: queue.append(p - w)
				above = eligible
			if row < h - 1:
				var eligible := paper[p + w] == 1
				if eligible and not below: queue.append(p + w)
				below = eligible
	# Soften the near-white JPEG fringe only along the removed paper boundary.
	# This never keys interior white clothing or pale walls by their color alone.
	for y in range(1, h-1):
		for x in range(1, w-1):
			var p := y*w+x
			if paper[p] == 2: continue
			if paper[p-1] != 2 and paper[p+1] != 2 and paper[p-w] != 2 and paper[p+w] != 2: continue
			var i := p*4
			var low := mini(pixels[i],mini(pixels[i+1],pixels[i+2]))
			if low >= 220: pixels[i+3] = int(clampf((255.0-low)/35.0,0,1)*255)
	var result := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, pixels)
	if crop:
		var bounds := result.get_used_rect().grow(2).intersection(Rect2i(0, 0, w, h))
		result = result.get_region(bounds)
	result.generate_mipmaps()
	var texture := ImageTexture.create_from_image(result)
	textures[key] = texture
	return texture
