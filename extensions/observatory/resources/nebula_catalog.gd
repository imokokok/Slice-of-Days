extends RefCounted

static func entries() -> Array:
	var result := []
	var folder := "res://extensions/observatory/assets/nebulae/"
	result.append(item("orion", "猎户座星云", "M42 · 光在这里孕育", folder+"orion.jpg", "", "NASA, ESA, M. Robberto (Space Telescope Science Institute/ESA) and the Hubble Space Telescope Orion Treasury Project Team", "https://esahubble.org/images/heic0601a/", "CC BY 4.0 · 照片深度由 Solmere 艺术化重建"))
	result.append(item("pillars", "创生之柱", "M16 · 星尘升起的地方", folder+"pillars.jpg", folder+"pillars.res", "NASA, ESA/Hubble and the Hubble Heritage Team; Model: NASA's Universe of Learning, Leah Hustak (STScI), Ralf Crawford (STScI)", "https://science.nasa.gov/asset/hubble/pillars-of-creation-3d-model/", "官方三维形状 · Solmere 气体着色"))
	result.append(item("eta_carinae", "船底座 η 星", "Homunculus · 两瓣光的回声", "", folder+"eta_carinae.res", "NASA / NASA 3D Resources", "https://science.nasa.gov/3d-resources/eta-carinae-homunculus-nebula/", "官方三维形状 · Solmere 气体着色"))
	return result

static func item(id: String, title: String, subtitle: String, image: String, model: String, credit: String, source: String, treatment: String) -> Dictionary:
	var row := Dictionary()
	row.id=id; row.title=title; row.subtitle=subtitle; row.image=image; row.credit=credit; row.source=source; row.treatment=treatment
	if not model.is_empty(): row.model=model
	return row
