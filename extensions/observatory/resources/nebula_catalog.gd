extends RefCounted

static func entries() -> Array:
	var result := []
	var folder := "res://extensions/observatory/assets/nebulae/"
	result.append(item("pillars", "创生之柱", "M16 · 星尘升起的地方", folder+"pillars.jpg", folder+"pillars.res", "NASA, ESA/Hubble and the Hubble Heritage Team; Model: NASA's Universe of Learning, Leah Hustak (STScI), Ralf Crawford (STScI)", "https://science.nasa.gov/asset/hubble/pillars-of-creation-3d-model/", "官方三维形状 · Solmere 气体着色"))
	result.append(item("eta_carinae", "船底座 η 星", "Homunculus · 两瓣光的回声", "", folder+"eta_carinae.res", "NASA / NASA 3D Resources", "https://science.nasa.gov/3d-resources/eta-carinae-homunculus-nebula/", "官方三维形状 · Solmere 气体着色"))
	result.append(item("crab", "蟹状星云", "M1 · 爆炸留下的脉冲心脏", "", folder+"crab_observed.tscn", "NASA / Francis R. Summers; NASA / Robert L. Hurt; Chandra X-ray Observatory", "https://science.nasa.gov/3d-resources/crab-nebula/", "X 射线观测约束的三维结构 · 中性结构着色"))
	result.append(item("cygnus_loop", "天鹅座环", "Veil Nebula · 爆炸波穿过星际云", "", folder+"cygnus_observed.tscn", "NASA / Salvatore Orlando; Chandra X-ray Observatory", "https://science.nasa.gov/3d-resources/cygnus-loop-supernova/", "观测约束的超新星模拟 · 中性结构着色"))
	result.append(item("casa", "仙后座 A", "Cas A · 逐层展开的爆炸遗迹", "", folder+"casa_observed.tscn", "NASA / Smithsonian Astrophysical Observatory / Chandra X-ray Center / MIT / T. Delaney et al.", "https://chandra.harvard.edu/photo/2013/casa/", "Chandra、Spitzer 与地面观测数据的三维重建 · 颜色按观测层标记"))
	var notes := {
		"pillars": {
			"introduction":"创生之柱是鹰状星云中的冷气体与尘埃。年轻恒星在柱内诞生，附近恒星的辐射又在侵蚀它们。",
			"science":["你在看什么\n这几根柱状云位于约 6,500 光年外的鹰状星云。它们并非固体石柱，而是分子气体与尘埃聚集成的巨大结构。", "诞生也在消散\n密集区域可以孕育恒星，外侧却受到附近年轻恒星的紫外线与恒星风侵蚀。柱顶一些指状突起本身就比太阳系更大。", "一张名画背后的观测\n哈勃 1995 年的照片让它广为人知。可见光凸显尘埃的遮挡，韦布红外观测则揭示更多藏在里面的恒星。两者是在看同一片区域的不同信息。", "怎样知道前后\nNASA 的三维可视化结合观测研究与多波段图像。本游戏使用其公开模型的形状，移除打印底座，并另行制作气体着色；请环绕查看柱体间的距离与遮挡。"],
			"science_source":"https://science.nasa.gov/missions/hubble/new-hubble-webb-pillars-of-creation-visualization/"
		},
		"eta_carinae": {
			"introduction":"船底座 η 星周围的两瓣星云，是猛烈喷发留下的物质。这里展示恒星生命中的一次剧烈变化。",
			"science":["你在看什么\n这对膨胀的叶瓣叫作 Homunculus 星云。与恒星诞生区不同，它主要由船底座 η 星系统喷出的物质形成。", "十九世纪的大喷发\n地球上的观测者在 1840 年代见证它异常变亮，这段历史被称为“大喷发”。大量物质被抛出，在周围形成如今的小星云。", "为何要看不同的光\n可见光、红外与其他波段分别揭示尘埃、气体等不同结构。图像中的颜色帮助我们辨别物理信息，不能简单当作肉眼近距离看见的色彩。", "环绕两瓣光\n试着转到侧面与背面，观察两瓣结构和中间较窄的区域。这里采用 NASA 公开的三维模型；表面颜色与发光由游戏呈现，空间比例并非飞船航行模拟。"],
			"science_source":"https://science.nasa.gov/asset/hubble/eta-carinae-the-great-eruption-of-a-massive-star/"
		},
		"crab": {
			"introduction":"蟹状星云是一次恒星爆炸留下的遗迹。中心的脉冲星像一台高速旋转的发动机，把能量注入环状盘和两束喷流。",
			"science":["这里的三维从哪里来\nNASA 页面说明，这个模型使用钱德拉 X 射线观测建立了蟹状星云的三维表示；环状盘和两极喷流是模型中的独立结构。", "1054 年的天空\n中国和其他地区的观测者记录过那次超新星。今天看到的蟹状星云，是爆炸后仍向外扩张的物质。", "颜色的边界\n模型的层色用于区分结构，不代表肉眼看到的自然颜色；钱德拉的 X 射线信息和不同能段共同说明了物质的分布。", "转到喷流侧面\n从正面看环状盘，转到侧面可以看到喷流轴线。这里显示公开模型的几何，不把照片拉伸成深度。"],
			"science_source":"https://science.nasa.gov/3d-resources/crab-nebula/"
		},
		"cygnus_loop": {
			"introduction":"天鹅座环又叫面纱星云，是超新星爆炸波穿过星际云后留下的巨大遗迹。它在天空中伸展约三度，接近六个满月的宽度。",
			"science":["研究模拟而非照片\nNASA 说明这份模型模拟爆炸波与孤立星际云的相互作用，并结合钱德拉看到的高温物质。它是有观测约束的研究模型。", "一圈很大的遗迹\n天鹅座环的结构很暗却很宽，爆炸冲击波把周围星际物质加热并推开。", "如何阅读它\n请把外缘看作冲击波经过的边界，把内部看作被加热的星际介质。不同角度有助于理解它不是一张平面照片。", "来源与范围\n模型数据来自 Orlando 等人的研究，NASA 页面给出论文 DOI；Solmere 只负责把公开模型放进望远镜观察。"],
			"science_source":"https://science.nasa.gov/3d-resources/cygnus-loop-supernova/"
		},
		"casa": {
			"introduction":"仙后座 A 是一颗大质量恒星爆炸后的碎片场。它把不同观测波段的物质层展开，让我们从各个方向看一场三百年前的恒星死亡。",
			"science":["真正的数据来源\nChandra、Spitzer、NOAO 与地面望远镜的观测共同参与了三维重建。这个模型保留各个元素层的相对位置，不从一张照片猜深度。", "爆炸留下了什么\n不同元素的喷出物在空间中形成层次，外层冲击波和内部碎片共同构成不规则的遗迹。", "颜色不是肉眼色彩\n模型使用层色帮助分辨观测资料；在 Chandra 图像中，低、中、高能 X 射线被分别映射为红、绿、蓝。", "从外到内\n拖动到侧面，可以看到多个物质层的错开。这里展示的是公开的科学可视化数据，不是精确的飞船比例模型。"],
			"science_source":"https://chandra.harvard.edu/photo/2013/casa/"
		}
	}
	for entry: Dictionary in result: entry.merge(notes[entry.id])
	return result

static func item(id: String, title: String, subtitle: String, image: String, model: String, credit: String, source: String, treatment: String) -> Dictionary:
	var row := Dictionary()
	row.id=id; row.title=title; row.subtitle=subtitle; row.image=image; row.credit=credit; row.source=source; row.treatment=treatment
	if not model.is_empty(): row.model=model
	return row
