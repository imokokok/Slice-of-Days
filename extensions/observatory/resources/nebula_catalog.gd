extends RefCounted

static func entries() -> Array:
	var result := []
	var folder := "res://extensions/observatory/assets/nebulae/"
	result.append(item("orion", "猎户座星云", "M42 · 光在这里孕育", folder+"orion.jpg", "", "NASA, ESA, M. Robberto (Space Telescope Science Institute/ESA) and the Hubble Space Telescope Orion Treasury Project Team", "https://esahubble.org/images/heic0601a/", "CC BY 4.0 · 照片深度由 Solmere 艺术化重建"))
	result.append(item("pillars", "创生之柱", "M16 · 星尘升起的地方", folder+"pillars.jpg", folder+"pillars.res", "NASA, ESA/Hubble and the Hubble Heritage Team; Model: NASA's Universe of Learning, Leah Hustak (STScI), Ralf Crawford (STScI)", "https://science.nasa.gov/asset/hubble/pillars-of-creation-3d-model/", "官方三维形状 · Solmere 气体着色"))
	result.append(item("eta_carinae", "船底座 η 星", "Homunculus · 两瓣光的回声", "", folder+"eta_carinae.res", "NASA / NASA 3D Resources", "https://science.nasa.gov/3d-resources/eta-carinae-homunculus-nebula/", "官方三维形状 · Solmere 气体着色"))
	var notes := {
		"orion": {
			"introduction":"M42 是一片正在形成恒星的气体与尘埃云。明亮的年轻恒星，把周围照成一道发光的空腔。",
			"science":["你在看什么\n猎户座星云是邻近的恒星诞生区，距我们约 1,400 光年。明亮中心的四颗梯形星向外发出紫外线，塑造周围气体。", "光亮与暗处\n暗色不是画面损坏：尘埃会遮挡后方的光。部分年轻恒星周围还有原行星盘，行星系统可能从这些物质中形成。", "这张图怎样诞生\n这幅哈勃拼图汇集了 2004–2005 年的观测，包含数百张照片与多个波段，能看见三千多颗恒星。它并非人眼一次看到的颜色。", "换一个角度\n试着绕到侧面，看近处亮云与远处暗带分开。本游戏根据照片建立空间深度；这些前后距离是艺术重建，不是由照片直接测得。"],
			"science_source":"https://esahubble.org/images/heic0601a/"
		},
		"pillars": {
			"introduction":"创生之柱是鹰状星云中的冷气体与尘埃。年轻恒星在柱内诞生，附近恒星的辐射又在侵蚀它们。",
			"science":["你在看什么\n这几根柱状云位于约 6,500 光年外的鹰状星云。它们并非固体石柱，而是分子气体与尘埃聚集成的巨大结构。", "诞生也在消散\n密集区域可以孕育恒星，外侧却受到附近年轻恒星的紫外线与恒星风侵蚀。柱顶一些指状突起本身就比太阳系更大。", "一张名画背后的观测\n哈勃 1995 年的照片让它广为人知。可见光凸显尘埃的遮挡，韦布红外观测则揭示更多藏在里面的恒星。两者是在看同一片区域的不同信息。", "怎样知道前后\nNASA 的三维可视化结合观测研究与多波段图像。本游戏使用其公开模型的形状，移除打印底座，并另行制作气体着色；请环绕查看柱体间的距离与遮挡。"],
			"science_source":"https://science.nasa.gov/missions/hubble/new-hubble-webb-pillars-of-creation-visualization/"
		},
		"eta_carinae": {
			"introduction":"船底座 η 星周围的两瓣星云，是猛烈喷发留下的物质。这里展示恒星生命中的一次剧烈变化。",
			"science":["你在看什么\n这对膨胀的叶瓣叫作 Homunculus 星云。与恒星诞生区不同，它主要由船底座 η 星系统喷出的物质形成。", "十九世纪的大喷发\n地球上的观测者在 1840 年代见证它异常变亮，这段历史被称为“大喷发”。大量物质被抛出，在周围形成如今的小星云。", "为何要看不同的光\n可见光、红外与其他波段分别揭示尘埃、气体等不同结构。图像中的颜色帮助我们辨别物理信息，不能简单当作肉眼近距离看见的色彩。", "环绕两瓣光\n试着转到侧面与背面，观察两瓣结构和中间较窄的区域。这里采用 NASA 公开的三维模型；表面颜色与发光由游戏呈现，空间比例并非飞船航行模拟。"],
			"science_source":"https://science.nasa.gov/asset/hubble/eta-carinae-the-great-eruption-of-a-massive-star/"
		}
	}
	for entry: Dictionary in result: entry.merge(notes[entry.id])
	return result

static func item(id: String, title: String, subtitle: String, image: String, model: String, credit: String, source: String, treatment: String) -> Dictionary:
	var row := Dictionary()
	row.id=id; row.title=title; row.subtitle=subtitle; row.image=image; row.credit=credit; row.source=source; row.treatment=treatment
	if not model.is_empty(): row.model=model
	return row
