extends RefCounted

# Visual mini-stories describe the card, never the hidden case solution.
const GUIDES := {
	"01": ["相等、对应、交换", "天使把水从一个杯子倒入另一个杯子，一脚在水中，一脚在岸上。画面讲的是在两边之间寻找协调。你可以关注两个对象是否对应，数量、比例或交换是否重要。"],
	"02": ["秩序、结构、权威", "人物端坐在石制王座上，台阶有高低，建筑保持对称。画面强调一个稳定、有层次的结构。你可以关注先后、大小、位置或谁掌握控制权。"],
	"03": ["变化、轮换、位置", "轮盘上有不同物件，它们会随着转动改变位置。画面讲的是变化之中是否仍有不变的规律。你可以关注交换位置、顺序变化以及结果是否改变。"],
	"04": ["突变、反例、条件缺失", "闪电击中高塔，原本稳固的结构开始崩塌。画面提醒我们，看起来可靠的判断也可能缺少条件。你可以用一个具体反例，检验现在的猜测是否充分。"],
	"05": ["比较、证据、判断", "人物一手持天平，一手持剑，既比较两边，也作出判断。画面讲的是判断需要依据。你可以关注证据能否支持结论，或两个条件之间有什么差别。"],
	"06": ["操作、工具、主动行动", "人物站在摆有四件工具的桌前，一手向上，一手向下。画面把想法转成了具体操作。你可以关注谁使用了什么、改变了什么，以及怎样测试一个条件。"],
	"07": ["移动、来访、先后", "两匹马与车辆沿道路前进，行动有明确方向。画面讲的是从一个地方主动走向另一个地方。你可以关注谁来过、谁离开、何时到达，或进入的先后。"],
	"08": ["希望、发现、援助", "星光下的人把水倒入水流与土地，像是在给两边重新带来生机。画面讲的是困境中仍有可寻找的方向。你可以关注发现、求助，或怎样确认一条生路。"],
	"09": ["两人关系、对应、连接", "两个人面对彼此，各举一个杯子，中间有连接的意象。画面讲的是双方建立联系。你可以关注两个人是否有关联，或两组对象是否形成对应。"],
	"10": ["失去、结束、未被注意的部分", "几只杯子已经倒下，仍有杯子站立，人物却把注意力放在损失上。画面讲的是失去之后如何理解剩下的东西。你可以关注关系是否结束，或失败是否意味着一切都失败。"],
	"11": ["关系、选择、转移", "两个人物与分岔的道路共同出现，关系与选择交织在一起。画面不只关于爱情，也关于选择会改变什么。你可以关注关系是否转移，或不同选择是否影响结果。"],
	"12": ["束缚、占有、限制", "人物被链条牵连，看似不能自由行动。画面讲的是欲望、依赖或规则怎样限制人。你可以关注无法放下的关系、控制，或一个结果必须满足的约束。"],
	"13": ["冲突、差异、相互作用", "几个人举着木杖，动作彼此交错，没有形成统一方向。画面讲的是多个力量发生碰撞。你可以关注是否出现争执、差异或竞争，以及它们是否改变结果。"],
	"14": ["结束、死亡、转变", "骑行者经过倒下的人物，旧状态不能继续保持。画面表示一个明确的终点，也可能意味着转变。你可以关注死亡或失败由什么造成，哪个过程在此结束。"],
	"15": ["表象、不确定、误读", "月光照着道路、动物与远处的塔，能看到东西，却未必能看清全部。画面提醒我们区分所见与推断。你可以关注某个表象是否足以证明结论。"],
	"16": ["换位观察、边界、暂停", "悬挂的人物用不同于平常的角度面对世界。画面讲的是停下来，重新看待位置关系。你可以关注门里与门外、先与后，或换一个位置会不会改变判断。"],
	"17": ["发现、回应、重新审视", "号角响起，人们作出回应。画面讲的是某件事被发现或传达后，引发新的行动。你可以关注谁发现、谁报告，或一个判断是否需要重新作出。"],
	"18": ["隐情、边界、未显露的规则", "人物坐在两根柱子之间，帷幕与卷轴提示还有未被看见的内容。画面讲的是表面背后可能存在信息。你可以关注隐藏影响或尚未明确的规则，但不要把象征当成证据。"]
}

const MURDER := {
	"01": ["old_relationship", "ended_relationship"],
	"02": ["detective_first"],
	"03": ["detective_first", "seeing_proves_entry"],
	"04": ["conflict", "seeing_proves_entry", "reporter_killer"],
	"05": ["reporter_killer", "hidden_killer", "weapon", "seeing_proves_entry"],
	"06": ["weapon", "knife_bin", "visitor"],
	"07": ["visitor", "reporter_entered", "detective_first"],
	"08": ["reporter_report", "reporter_saw"],
	"09": ["old_relationship", "lover"],
	"10": ["ended_relationship", "obsession"],
	"11": ["lover", "old_relationship", "ended_relationship"],
	"12": ["obsession", "possession", "supernatural", "possession_plan"],
	"13": ["conflict"],
	"14": ["weapon", "hidden_killer", "conflict"],
	"15": ["seeing_proves_entry", "reporter_saw", "reporter_killer", "mislead"],
	"16": ["reporter_entered", "seeing_proves_entry", "detective_first", "door_outward"],
	"17": ["reporter_report", "reporter_saw", "detective_first"],
	"18": ["supernatural", "possession", "possession_plan", "mislead"]
}

const DOORS := {
	"01": ["equal_part", "equal_sufficient", "all_distinct_failure", "some_different_failure", "all_equal_sufficient", "middle_equal"],
	"02": ["relative_order", "middle_equal", "exact_structure", "sum"],
	"03": ["door_position", "door_number"],
	"04": ["equal_sufficient", "all_distinct_failure", "some_different_failure", "all_equal_sufficient", "largest_safe"],
	"05": ["middle_equal", "relative_order", "exact_structure", "equal_sufficient"],
	"06": ["equal_sufficient", "door_position", "sum", "exact_structure", "all_distinct_failure"],
	"07": ["door_position", "door_number", "largest_safe"],
	"08": ["largest_safe", "equal_sufficient", "all_distinct_failure"],
	"09": ["equal_part", "middle_equal", "some_different_failure"],
	"10": ["equal_sufficient", "all_distinct_failure", "all_equal_sufficient"],
	"11": ["door_position", "door_number", "largest_safe"],
	"12": ["equal_part", "middle_equal", "exact_structure"],
	"13": ["relative_order", "all_distinct_failure", "some_different_failure"],
	"14": ["equal_sufficient", "all_distinct_failure", "some_different_failure", "all_equal_sufficient"],
	"15": ["door_number", "door_position", "largest_safe"],
	"16": ["door_position", "relative_order", "middle_equal"],
	"17": ["equal_sufficient", "middle_equal", "largest_safe"],
	"18": ["middle_equal", "exact_structure", "door_number"]
}

static func allows(case_id: String, card_id: String, fact_id: String) -> bool:
	if fact_id.begins_with("experiment:"):
		return case_id == "doors" and card_id in ["01", "02", "03", "04", "05", "06", "08", "10", "12", "13", "14", "17", "18"]
	var mapping: Dictionary = MURDER if case_id == "murder" else DOORS
	return mapping.get(card_id, []).has(fact_id)

static func allowed_facts(case_id: String, card_id: String) -> Array:
	return (MURDER if case_id == "murder" else DOORS).get(card_id, [])

static func introduction(card_id: String, name: String) -> String:
	return "这是正位的「%s」。\n%s" % [name, GUIDES[card_id][1]]
