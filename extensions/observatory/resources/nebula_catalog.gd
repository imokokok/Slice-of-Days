extends RefCounted

static func entries() -> Array:
	var result := []
	var folder := "res://extensions/observatory/assets/nebulae/"
	result.append(item("pillars", "创生之柱", "M16 · 星尘升起的地方", folder+"pillars.jpg", folder+"pillars.res", "NASA, ESA/Hubble and the Hubble Heritage Team; Image: NASA/ESA/STScI", "https://science.nasa.gov/asset/hubble/pillars-of-creation-3d-model/", "NASA 公开观测照片；单张不透明图像的镜头查看，不重建实体模型"))
	result.append(item("eta_carinae", "船底座 η 星", "Homunculus · 两瓣光的回声", folder+"eta_carinae.jpg", folder+"eta_carinae.res", "NASA / ESA / Hubble; Processing: Judy Schmidt", "https://science.nasa.gov/image-detail/etacarinae-hubbleschmidt-1764/", "NASA 公开观测照片；单张不透明图像的轻微镜头视差，不重建实体模型"))
	result.append(item("crab", "蟹状星云", "M1 · 爆炸留下的脉冲心脏", folder+"crab.jpg", folder+"crab_observed.tscn", "NASA / ESA / STScI / William Blair (JHU); Image Processing: Joseph DePasquale", "https://science.nasa.gov/asset/hubble/crab-nebula-2024/", "NASA Hubble 公开观测照片；保持原始细节，只允许镜头式查看"))
	result.append(item("cygnus_loop", "天鹅座环", "Veil Nebula · 爆炸波穿过星际云", folder+"cygnus_loop.jpg", folder+"cygnus_observed.tscn", "NASA / ESA / Ravi Sankrit (STScI); Image Processing: Joseph DePasquale", "https://science.nasa.gov/asset/hubble/cygnus-loop/", "NASA Hubble 公开观测照片；不叠加模糊图层或装饰星场"))
	result.append(item("casa", "仙后座 A", "Cas A · 逐层展开的爆炸遗迹", folder+"casa.jpg", folder+"casa_observed.tscn", "X-ray: NASA/CXC/Meiji Univ./T. Sato et al.; Processing: NASA/CXC/SAO/N. Wolk", "https://www.chandra.harvard.edu/photo/2025/casa/", "Chandra 公开观测照片；原图保持清晰，空间感只来自观看镜头"))
	var notes := {
		"pillars": {
			"introduction":"创生之柱是鹰状星云中的冷气体与尘埃。年轻恒星在柱内诞生，附近恒星的辐射又在侵蚀它们。",
			"science":["你在看什么\n这几根柱状云位于约 6,500 光年外的鹰状星云。它们并非固体石柱，而是分子气体与尘埃聚集成的巨大结构。", "诞生也在消散\n密集区域可以孕育恒星，外侧却受到附近年轻恒星的紫外线与恒星风侵蚀。柱顶一些指状突起本身就比太阳系更大。", "一张名画背后的观测\n哈勃 1995 年的照片让它广为人知。可见光凸显尘埃的遮挡，韦布红外观测则揭示更多藏在里面的恒星。两者是在看同一片区域的不同信息。", "怎样观看\n画面来自公开观测照片本身。鼠标拖动与滚轮改变的是观看镜头，帮助你从不同角度检查构图；不会把照片涂抹成放射状的假三维。"],
			"science_source":"https://science.nasa.gov/missions/hubble/new-hubble-webb-pillars-of-creation-visualization/"
		},
		"eta_carinae": {
			"introduction":"船底座 η 星周围的两瓣星云，是猛烈喷发留下的物质。这里展示恒星生命中的一次剧烈变化。",
			"science":["你在看什么\n这对膨胀的叶瓣叫作 Homunculus 星云。与恒星诞生区不同，它主要由船底座 η 星系统喷出的物质形成。", "十九世纪的大喷发\n地球上的观测者在 1840 年代见证它异常变亮，这段历史被称为“大喷发”。大量物质被抛出，在周围形成如今的小星云。", "为何要看不同的光\n可见光、红外与其他波段分别揭示尘埃、气体等不同结构。图像中的颜色帮助我们辨别物理信息，不能简单当作肉眼近距离看见的色彩。", "观看两瓣光\n试着轻轻转动镜头，观察两瓣结构和中间较窄的区域。你始终看到的是 NASA 公开照片，空间变化是观看角度而非飞船航行模拟。"],
			"science_source":"https://science.nasa.gov/asset/hubble/eta-carinae-the-great-eruption-of-a-massive-star/"
		},
		"crab": {
			"introduction":"蟹状星云是一次恒星爆炸留下的遗迹。中心的脉冲星像一台高速旋转的发动机，把能量注入环状盘和两束喷流。",
			"science":["这里的图像从哪里来\nNASA 的 Hubble 观测记录了蟹状星云中复杂的气体丝状结构。望远镜把不同滤镜映射成蓝、青、黄与红，颜色是数据的读法。", "1054 年的天空\n中国和其他地区的观测者记录过那次超新星。今天看到的蟹状星云，是爆炸后仍向外扩张的物质。", "颜色的边界\n不同能段共同说明物质的分布；颜色帮助我们区分结构，不代表肉眼看到的自然颜色。", "转动观看镜头\n旋转不会凭空生成新的物理深度。它只让你像检查一张天文照片一样改变视角，照片的细丝与颜色保持清楚。"],
			"science_source":"https://science.nasa.gov/3d-resources/crab-nebula/"
		},
		"cygnus_loop": {
			"introduction":"天鹅座环又叫面纱星云，是超新星爆炸波穿过星际云后留下的巨大遗迹。它在天空中伸展约三度，接近六个满月的宽度。",
			"science":["一张观测图\nNASA 的 Hubble 图像捕捉了天鹅座环边缘细长的发光气体丝。它不是游戏生成的星云，而是来自公开观测资料的图像。", "一圈很大的遗迹\n天鹅座环的结构很暗却很宽，爆炸冲击波把周围星际物质加热并推开。", "如何阅读它\n请把外缘看作冲击波经过的边界，把内部看作被加热的星际介质。拖动时只是观看角度改变，不会把一张照片伪装成模型。", "来源与范围\n图像由 NASA、ESA 与 STScI 发布；Solmere 不修改原图，只提供清晰的镜头查看。"],
			"science_source":"https://science.nasa.gov/3d-resources/cygnus-loop-supernova/"
		},
		"casa": {
			"introduction":"仙后座 A 是一颗大质量恒星爆炸后的碎片场。它把不同观测波段的物质层展开，让我们从各个方向看一场三百年前的恒星死亡。",
			"science":["真正的数据来源\nChandra 的 X 射线图像显示了仙后座 A 的爆炸遗迹与元素分布。这里使用公开照片，不从照片猜一个实体深度。", "爆炸留下了什么\n不同元素的喷出物在空间中形成层次，外层冲击波和内部碎片共同构成不规则的遗迹。", "颜色不是肉眼色彩\n在 Chandra 图像中，低、中、高能 X 射线被分别映射为红、绿、蓝，颜色用于阅读数据。", "从不同角度观看\n拖动镜头可以检查照片的构图与范围，但不会把公开科学图像做成粗糙模型。"],
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
