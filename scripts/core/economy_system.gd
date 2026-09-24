extends Node
## Resource-chain orchestration; GameState remains the currency/inventory/time authority.
signal changed
const CONFIG_PATH := "res://data/economy/economy_config.json"
const SUPPLIED_KITCHEN_ART = preload("res://scripts/ui/components/kitchen_art_catalog.gd")
var config: Dictionary = {}
var catalog: Dictionary = {}
var mutating := false

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy/shops.json"))
	for shop in data.shops: catalog[str(shop.id)] = shop
	_apply_work_prices()

func _apply_work_prices() -> void:
	if GameplayModuleSystem.modules.has("ghostwriting"):
		var module: Dictionary = GameplayModuleSystem.modules.ghostwriting
		module.direct_time_minutes = int(config.work.letter.minutes)
		module.external_results.erase("money")
		for entry in module.external_results.get("journal_entries",[]): entry.text = "纸张、停顿和没有说满的话被装进同一只信封；报酬记录在账本里。"
	for module_id in ["cooking","ghostwriting","sound_sampling"]:
		var work: Dictionary = config.work["restaurant" if module_id == "cooking" else "letter" if module_id == "ghostwriting" else "sound"]
		for choice in GameplayModuleSystem.prototypes.get(module_id,{}).get("choices",[]):
			choice.cost.minutes = int(work.minutes)
			choice.detail = "需要%d分钟。%s" % [work.minutes,"交付后收入%d元。" % work.pay if module_id != "cooking" else "采购班次出餐后统一结算。"]
			if module_id != "cooking" and int(choice.results.get("money",0)) > 0: choice.results.money = int(work.pay)

func state() -> Dictionary:
	if not GameState.artifacts.has("economy"):
		GameState.artifacts.economy = {"version":3,"receipts":{},"procurement":{},"stock_sold":{},"collections":{},"knowledge_events":{},"appointments":{}}
	return GameState.artifacts.economy

func _save(message := "物品和账目保存失败") -> bool:
	GameState.commit_active_role_state()
	changed.emit()
	return SaveManager.save_or_report(message)

func active_order() -> Dictionary:
	return state().procurement.get(str(GameState.current_day), {})

func stock(shop_id: String) -> Array:
	var result: Array = []
	for raw in catalog.get(shop_id,{}).get("items",[]):
		var item: Dictionary = raw.duplicate(true)
		var days: Array = item.get("days",[])
		var sold_today := false
		for listed_day in days:
			if int(listed_day) == GameState.current_day:
				sold_today = true
				break
		if not days.is_empty() and not sold_today: continue
		var key := "%s:%d:%s" % [shop_id,GameState.current_day,str(item.id)]
		item["remaining"] = maxi(0,int(item.get("stock",99))-int(state().stock_sold.get(key,0)))
		item["shop_id"] = shop_id
		item["shop_name"] = catalog[shop_id].name
		result.append(item)
	return result

func shop_open(shop_id: String) -> bool:
	return bool(WorldGraph.location_status(str(catalog.get(shop_id,{}).get("location_id",""))).open)


func cart(shop_id: String) -> Dictionary:
	if not state().has("carts"): state().carts={}
	return state().carts.get(shop_id,{}).duplicate(true)

func set_cart_quantity(shop_id: String, item_id: String, quantity: int) -> Dictionary:
	if mutating: return {"ok":false,"message":"请等这一笔结算完。"}
	if not catalog.has(shop_id): return {"ok":false,"message":"找不到这个柜台。"}
	var basket := cart(shop_id)
	if quantity>0:
		var listed := false
		for item in stock(shop_id):
			if item.id==item_id and quantity<=int(item.remaining): listed=true
		if not listed or quantity>99: return {"ok":false,"message":"货架上没有这么多，可以减少数量。"}
	var before := GameState.to_save_data().duplicate(true)
	if quantity<=0: basket.erase(item_id)
	else: basket[item_id]=quantity
	state().carts[shop_id]=basket
	if not _save("购物篮保存失败"):
		GameState.load_save_data(before)
		return {"ok":false,"message":"购物篮没能保存，请重试。"}
	return {"ok":true,"message":"已放进购物篮。" if quantity>0 else "已从篮子取出。"}

func cart_quote(shop_id: String) -> Dictionary:
	var lines: Array=[]
	var categories: Array=[]
	var total := 0
	var minutes := 0
	var available: Dictionary={}
	for item in stock(shop_id): available[item.id]=item
	for id in cart(shop_id):
		var count := int(cart(shop_id)[id])
		if not available.has(id) or count<1 or count>int(available[id].remaining):
			return {"ok":false,"message":"货架已变化，请取出缺货的商品后再结账。"}
		var item: Dictionary=available[id]
		var category := str(item.get("category","household"))
		if not categories.has(category): categories.append(category)
		lines.append({"item_id":id,"name":item.name,"quantity":count,"unit_price":int(item.price),"total":count*int(item.price),"category":category})
		total+=count*int(item.price); minutes+=count*int(item.get("minutes",0))
	return {"ok":not lines.is_empty(),"lines":lines,"categories":categories,"total":total,"minutes":minutes,"message":"篮子还是空的。" if lines.is_empty() else ""}

func purchase_cart(shop_id: String) -> Dictionary:
	if mutating: return {"ok":false,"message":"这一笔正在结算。"}
	if not shop_open(shop_id): return {"ok":false,"message":"柜台已经收好了，篮子会替你保留。"}
	var quote := cart_quote(shop_id)
	if not quote.ok: return quote
	if GameState.money<int(quote.total): return {"ok":false,"message":"还差 %d 元，先从篮子取出一些物品。" % (int(quote.total)-GameState.money)}
	if not GameState.can_fit_now(int(quote.minutes)): return {"ok":false,"message":"时间不够，篮子会替你保留。"}
	mutating=true
	var before := GameState.to_save_data().duplicate(true)
	GameState.spend_money(int(quote.total),str(catalog[shop_id].name)+" · 购物篮结账")
	var receipt := record_service_receipt(shop_id,quote.lines,str(quote.categories[0]) if quote.categories.size()==1 else "mixed",GameState.money_ledger.back(),false)
	receipt["categories"]=quote.categories.duplicate()
	ResidencySystem.ingest_receipt(receipt)
	for line in quote.lines:
		var id := str(line.item_id)
		GameState.inventory[id]=int(GameState.inventory.get(id,0))+int(line.quantity)
		var key := "%s:%d:%s" % [shop_id,GameState.current_day,id]
		state().stock_sold[key]=int(state().stock_sold.get(key,0))+int(line.quantity)
		for item in catalog[shop_id].items:
			if item.id==id and item.get("category","")=="collection":
				var collection_id := str(receipt.id)+"_"+id
				state().collections[collection_id]={"id":collection_id,"item_id":id,"name":item.name,"nickname":"","note":"","slot":item.get("display_slot","shelf"),"day":GameState.current_day,"form":item.get("form","card"),"color":item.get("color","819c9b"),"purpose":item.get("purpose","private")}
	state().carts[shop_id]={}
	GameState.use_free_time(int(quote.minutes))
	GameState.add_journal_entry({"id":receipt.id,"kind":"purchase","text":"在%s买下 %d 种物品 · %d 元，小票已收好。" % [catalog[shop_id].name,quote.lines.size(),quote.total]})
	if not _save():
		GameState.load_save_data(before); mutating=false
		return {"ok":false,"message":"保存失败，钱款、库存和篮子已恢复，可重新结账。"}
	mutating=false
	GameState.message_posted.emit("小票已收入生活记录 · 物品已放进随身包")
	if GameState.current_role=="B": MetaExperience.queue_important("b_purchase_receipt",{"text":"小票留好了。","receipt_id":receipt.id})
	return {"ok":true,"message":"买好了，带上小票。","receipt":receipt}

func purchase(shop_id: String, item_id: String) -> Dictionary:
	if mutating: return {"ok":false,"message":"这一笔正在结算。"}
	if not shop_open(shop_id): return {"ok":false,"message":"柜台已经收好了，明天再来。"}
	var item: Dictionary = {}
	for row in stock(shop_id):
		if str(row.id) == item_id: item = row; break
	if item.is_empty() or int(item.remaining) <= 0: return {"ok":false,"message":"今天这一件已经卖完了。"}
	mutating = true
	var before := GameState.to_save_data().duplicate(true)
	var result := GameState.buy_item(item)
	if not bool(result.get("ok",false)):
		mutating = false
		return result
	var receipt := record_service_receipt(shop_id,[{"item_id":item_id,"name":str(item.name),"quantity":1,"unit_price":int(item.price),"total":int(item.price)}],str(item.get("category","household")),GameState.money_ledger.back(),false)
	var key := "%s:%d:%s" % [shop_id,GameState.current_day,item_id]
	state().stock_sold[key] = int(state().stock_sold.get(key,0))+1
	if str(item.get("category","")) == "collection":
		state().collections[str(receipt.id)] = {"id":str(receipt.id),"item_id":item_id,"name":str(item.name),"nickname":"","note":"","slot":str(item.get("display_slot","shelf")),"day":GameState.current_day,"form":str(item.get("form","card")),"color":str(item.get("color","ad775b")),"purpose":str(item.get("purpose","private"))}
	if not _save():
		GameState.load_save_data(before)
		mutating = false
		return {"ok":false,"message":"存档暂时没能写入，这笔购买已撤回。"}
	mutating = false
	GameState.message_posted.emit("小票已收好 · 可放进生活记录" + ("，回餐厅带上它报销。" if bool(receipt.reimbursable) else "。"))
	if GameState.current_role == "B": MetaExperience.queue_important("b_purchase_receipt",{"text":"小票留好了。", "receipt_id":receipt.id})
	result.receipt = receipt
	return result

func record_service_receipt(merchant_id: String, line_items: Array, category: String, transaction: Dictionary, persist := true) -> Dictionary:
	var source := str(transaction.get("transaction_id",""))
	if source.is_empty() or int(transaction.get("amount",0)) >= 0: return {}
	var id := "receipt_"+source
	if state().receipts.has(id): return state().receipts[id]
	var order := active_order()
	var eligible := false
	if not order.is_empty() and not bool(order.get("delivered",false)) and merchant_id in ["produce_stall","grocery"]:
		for line in line_items:
			if str(line.get("item_id","")) in config.procurement.items or str(line.get("item_id","")) in config.procurement.strange_options: eligible = true
	var receipt := {"id":id,"kind":"receipt","title":str(catalog.get(merchant_id,{}).get("name",merchant_id))+" · 小票","merchant_id":merchant_id,"day":int(transaction.get("day",GameState.current_day)),"minute":int(transaction.get("minute",GameState.current_minute)),"time":int(transaction.get("minute",GameState.current_minute)),"line_items":line_items.duplicate(true),"total":-int(transaction.amount),"amount":int(transaction.amount),"balance":int(transaction.balance),"category":category,"valid_for_living_record":true,"reimbursable":eligible,"reimbursement_source":"night_market" if eligible else "","reimbursed":false,"reimbursed_day":0,"stamp":"","notes":"","source":source,"source_transaction_id":source,"procurement_id":str(order.get("id","")) if eligible else ""}
	state().receipts[id] = receipt
	ResidencySystem.ingest_receipt(receipt)
	if persist: _save()
	return receipt

func accept_procurement() -> Dictionary:
	if GameState.current_location != "night_market" or SceneRouter.active_space_id != "restaurant": return {"ok":false,"message":"到餐厅出餐口和店主确认清单。"}
	if not active_order().is_empty(): return {"ok":true,"message":"今天的清单已经夹在随身本里。"}
	var before := GameState.to_save_data().duplicate(true)
	state().procurement[str(GameState.current_day)] = {"id":"restaurant_%s_%d" % [GameState.current_role,GameState.current_day],"day":GameState.current_day,"minute":GameState.current_minute,"accepted":true,"delivered":false,"completed":false,"paid":false,"items":[],"receipt_ids":[]}
	GameplayModuleSystem.unlock("cooking")
	KnowledgeSystem.learn({"id":"restaurant_procurement","subject_id":"produce_stall","predicate":"procurement","value":["tomato","herbs","strange"],"source_npc_id":"shi_yongqi","confidence":1.0,"status":"Confirmed","text":"餐厅需要番茄、香草和一份奇怪食材。菜摊更便宜；杂货店开得晚。带小票回餐厅报销，再上台做菜。"})
	GameState.add_journal_entry({"id":str(active_order().id),"kind":"procurement","text":"番茄 + 香草 + 奇怪食材。去菜摊或杂货店采购，带小票回餐厅报销。"})
	if not _save(): GameState.load_save_data(before); return {"ok":false,"message":"清单暂时没能保存，稍后再接。"}
	return {"ok":true,"message":"清单收好：番茄、香草、奇怪食材各一份。采购先垫钱，回来凭小票报销。"}

func procurement_summary() -> Dictionary:
	var order := active_order()
	if order.is_empty(): return {"status":"available","next":"到餐厅领取采购清单","source_locations":["night_market"]}
	if bool(order.get("completed",false)): return {"status":"completed","next":"到店主处领取收入证明","source_locations":["night_market"]}
	if bool(order.get("delivered",false)): return {"status":"ready","next":"用交来的材料完成今天的料理","source_locations":["night_market"]}
	var missing: Array[String] = []
	for id in config.procurement.items:
		if int(GameState.inventory.get(id,0)) < 1: missing.append(str(id))
	if not config.procurement.strange_options.any(func(id: String) -> bool: return int(GameState.inventory.get(id,0)) > 0): missing.append("strange")
	return {"status":"buy" if not missing.is_empty() else "deliver","next":"采购番茄、香草和奇怪食材；保留小票" if not missing.is_empty() else "回餐厅交材料并报销","needed":missing,"source_locations":config.procurement.locations if not missing.is_empty() else ["night_market"]}

func deliver_procurement() -> Dictionary:
	if GameState.current_location != "night_market" or SceneRouter.active_space_id != "restaurant": return {"ok":false,"message":"回餐厅出餐口交材料。"}
	var order := active_order()
	if order.is_empty(): return {"ok":false,"message":"先和店主确认今天的采购清单。"}
	if bool(order.get("delivered",false)): return {"ok":false,"message":"这份清单已经交过，报销已记在原小票上。"}
	if str(procurement_summary().status) != "deliver": return {"ok":false,"message":"还缺清单上的食材。可以去菜摊或杂货店补齐。"}
	var before := GameState.to_save_data().duplicate(true)
	var selected: Array = config.procurement.items.duplicate()
	for id in config.procurement.strange_options:
		if int(GameState.inventory.get(id,0)) > 0: selected.append(id); break
	var needed := selected.duplicate()
	var total := 0
	var receipts: Array = []
	for id in state().receipts:
		var receipt: Dictionary = state().receipts[id]
		if not bool(receipt.reimbursable) or bool(receipt.reimbursed) or str(receipt.get("procurement_id","")) != str(order.id): continue
		var covered := 0
		for line in receipt.line_items:
			if str(line.item_id) in needed:
				covered += int(line.unit_price)
				needed.erase(str(line.item_id))
		if covered <= 0: continue
		receipt.merge({"reimbursed":true,"reimbursed_day":GameState.current_day,"reimbursed_amount":covered,"stamp":"已报销 · 石泳琪","notes":"原小票保留，可继续用于生活记录。"},true)
		ResidencySystem.ingest_receipt(receipt)
		total += covered
		receipts.append(id)
	order.merge({"delivered":true,"items":selected,"receipt_ids":receipts,"reimbursed_total":total},true)
	if total > 0: GameState.earn_money(total,"餐厅采购报销",{"kind":"reimbursement","issuer":"night_market","source":str(order.id)})
	RelationshipSystem.add_flags("shi_yongqi",["按清单采购并保留小票"])
	if not _save(): GameState.load_save_data(before); return {"ok":false,"message":"本次交货和报销已撤回，稍后重试。"}
	return {"ok":true,"message":"材料已放到操作台，报销 %d 元。小票盖好章，仍留在资料袋里。" % total}

func ingredient_available(id: String) -> bool:
	return int(GameState.inventory.get(id,0)) > 0 or SUPPLIED_KITCHEN_ART.is_supplied_ingredient(id) or (active_order().is_empty() and id in config.procurement.pantry)

func cooking_check(tokens: Array) -> Dictionary:
	for id in tokens:
		if not ingredient_available(str(id)): return {"ok":false,"message":"手边没有%s，先去采购。" % ingredient_name(str(id))}
	var order := active_order()
	if not order.is_empty() and not bool(order.get("completed",false)):
		if not bool(order.get("delivered",false)): return {"ok":false,"message":"先带材料和小票到出餐口交货。"}
		for id in order.items:
			if not tokens.has(id): return {"ok":false,"message":"今天的班次请使用交来的番茄、香草和奇怪食材。"}
	return {"ok":true}

func ingredient_name(id: String) -> String:
	if SUPPLIED_KITCHEN_ART.is_supplied_ingredient(id): return SUPPLIED_KITCHEN_ART.ingredient_name(id)
	for shop: Dictionary in catalog.values():
		for item: Dictionary in shop.get("items",[]):
			if str(item.id)==id: return str(item.name)
	return {"sardine":"欧洲沙丁鱼","sea_bream":"金头鲷"}.get(id,"这种食材")

func cooking_cost(original: Dictionary) -> Dictionary:
	var order := active_order()
	return {"minutes":int(config.work.restaurant.minutes)} if not order.is_empty() and bool(order.get("delivered",false)) and not bool(order.get("completed",false)) else original

func finish_cooking(outcome: Dictionary, tokens: Array) -> void:
	var typed: Array[String] = []
	for token in tokens: typed.append(str(token))
	GameState.consume_inventory(typed)
	var order := active_order()
	if order.is_empty() or not bool(order.get("delivered",false)) or bool(order.get("paid",false)): return
	order.merge({"completed":true,"accepted":true,"paid":true,"placed_contribution":true,"outcome":outcome.duplicate(true)},true)
	GameState.earn_money(int(config.work.restaurant.pay),"料理班次工资",{"work_minutes":int(config.work.restaurant.minutes),"kind":"income","issuer":"night_market","source":str(order.id)})
	RelationshipSystem.record_encounter("shi_yongqi",str(order.id)+"_served",["一起完成采购和出餐"])
	var index := maxi(0,GameState.module_states.get("cooking",{}).get("outcomes",[]).size()-1)
	ResidencySystem.accept_contribution("module_cooking_%d" % index,"night_market",{"accepted":true,"source":"restaurant_served"})
	GameState.message_posted.emit("班次完成 · 工资 +%d · 工作记录已入袋，营业时间可向店主领取证明。" % int(config.work.restaurant.pay))
	changed.emit()

func name_collection(id: String, nickname: String, note: String, slot: String) -> bool:
	if not state().collections.has(id) or not config.collection_slots.has(slot): return false
	state().collections[id].merge({"nickname":nickname.left(32),"note":note.left(240),"slot":slot},true)
	return _save()

func collage_materials() -> Array:
	var result: Array = []
	for item in state().collections.values():
		if str(item.purpose) != "collage": continue
		var sheet := {"id":1000+result.size(),"collection_id":str(item.id),"title":str(item.nickname) if not str(item.nickname).is_empty() else str(item.name),"category":"日常","kicker":"从杂货店带回的纸片","rows":["留下   远处   明天","海风   车票   等待","另一边   忘记   回来"],"layout":3}
		result.append(sheet)
	for item in GameState.artifacts.get("collage_materials",[]):
		result.append({"id":1000+result.size(),"collection_id":str(item.id),"title":str(item.title),"category":"日常","kicker":"BEETMAN 留下的旧标签","rows":["海盐   柠檬   傍晚","等一会儿   回来了","下次见面   留在这里"],"layout":2})
	return result

func knowledge_for(location: String) -> Array:
	var result: Array = []
	for fact in KnowledgeSystem.facts():
		if str(fact.get("subject_id","")) == location: result.append(str(fact.get("text","")))
	var summary := procurement_summary()
	if summary.get("source_locations",[]).has(location) and not active_order().is_empty(): result.append(str(summary.next))
	return result

func notebook_text() -> String:
	var lines: Array[String] = ["余额 %d 元" % GameState.money]
	if GameState.current_role == "B":
		lines.append("带来 1600 元；房租已预付。下面是可调整的私人预算。")
		for category in config.b_budget: lines.append("%s  %d 元" % [category, config.b_budget[category]])
		var work := GameState.next_commitment()
		if not work.is_empty(): lines.append("接下来：%02d:%02d 工作，预计收入 %d 元" % [int(work.start)/60,int(work.start)%60,int(work.get("pay",0))])
	lines.append("采购："+str(procurement_summary().next))
	lines.append("最近的账目")
	for row in GameState.money_ledger.slice(maxi(0,GameState.money_ledger.size()-8)):
		lines.append("第%d天 %02d:%02d  %s  %+d 元" % [row.day,int(row.minute)/60,int(row.minute)%60,row.reason,row.amount])
	return "\n".join(lines)

func chat_completed(npc: String) -> void:
	if npc == "beetman":
		MetaExperience.queue_important("beetman_aftermath", {"npc_id":npc})
		KnowledgeSystem.learn({"id":"beetman_shopping","subject_id":"produce_stall","predicate":"hours","value":[630,1110],"source_npc_id":npc,"confidence":1.0,"status":"Confirmed","text":"BEETMAN 的菜摊 10:30—18:30。番茄8元、香草6元、海盐豆15元；背后的巷子到餐厅只要一分钟。"})
		for appointment in state().appointments.values():
			if int(appointment.day) == GameState.current_day and GameState.current_minute-15 >= int(appointment.start) and GameState.current_minute-15 < int(appointment.end) and not GameState.has_event(str(appointment.id)):
				GameState.mark_event(str(appointment.id))
				RelationshipSystem.add_flags(npc,["傍晚回来一起挑过旧标签"])
				GameState.add_journal_entry({"id":str(appointment.id)+"_keepsake","kind":"memory","text":"按约回来挑了旧标签。BEETMAN 留了一张有海盐印子的纸给我。"})
				GameState.add_artifact("collage_materials",{"id":"beetman_label_"+str(GameState.current_day),"title":"沾着海盐的旧标签","kind":"paper","source":"beetman","day":GameState.current_day},false)
				GameState.message_posted.emit("赴约已记下 · 留下一张旧标签。")
	elif npc == "grocery":
		KnowledgeSystem.learn({"id":"grocery_hours","subject_id":"cafe","predicate":"hours","value":[480,1320],"source_npc_id":npc,"confidence":1.0,"status":"Confirmed","text":"杂货店 08:00—22:00；番茄12元、香草10元、星形盐片22元。日用品、每日旧物和摄影柜台都在这里。"})
	GameState.commit_active_role_state()

func book_vendor_visit() -> Dictionary:
	var day := GameState.current_day + (1 if GameState.current_minute >= 1050 else 0)
	if day > 7: return {"ok":false,"message":"最后一天的摊子快收好了，有空再来坐坐。"}
	var id := "beetman_label_visit_%s_%d" % [GameState.current_role,day]
	if state().appointments.has(id): return {"ok":true,"message":"约定已经记着了。"}
	var appointment := {"id":id,"npc_id":"beetman","label":"和 BEETMAN 挑旧标签","location":"produce_stall","day":day,"start":1050,"end":1095,"minutes":15,"source":"beetman"}
	state().appointments[id] = appointment.duplicate(true)
	GameState.add_appointment(appointment)
	_save()
	return {"ok":true,"message":"约好第%d天 17:30—18:15，回菜摊聊一会儿。" % day}

func remembered_line(npc: String) -> String:
	if npc == "beetman":
		GameState.refresh_appointments()
		for id in state().appointments:
			if GameState.appointment_status(str(id)) == "missed": return "那天你没赶回来，我把标签压在罐头下面了。今天也可以坐一会儿。"
	if npc == "grocery":
		for item in state().collections.values():
			if str(item.item_id) == "hotel_307_tag": return "你带走的307号钥匙牌，我想起来了。那间房的窗户一直朝着海。"
	return ""

func open_counter(parent: Node, mode := "restaurant") -> void:
	if not get_tree().get_nodes_in_group("economy_paper").is_empty(): return
	var panel = load("res://scripts/ui/economy_paper.gd").new()
	panel.mode = mode
	parent.add_child(panel)
