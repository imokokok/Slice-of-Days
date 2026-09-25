extends SceneTree
const Thermal = preload("res://modules/restaurant/domain/food_thermal.gd")
const Sauce = preload("res://modules/restaurant/domain/sauce_state.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var source := {"volume_ml": 9.0, "composition_ml": {}}
	for i in 9: source.composition_ml[str(i)] = 1.0
	var target := {"volume_ml": 0.0, "composition_ml": {}}
	Sauce.transfer(source, target, 9.0)
	expect(is_equal_approx(Sauce.total_components(target), 9.0), "more than eight components cannot disappear in transfer")
	var thick := Sauce.make_batch({"id":"ketchup", "viscosity":0.9},90.0,"a",1.0)
	Sauce.merge_into(thick, Sauce.make_batch({"id":"soy_sauce", "viscosity":0.1},10.0,"b",1.0))
	expect(is_equal_approx(float(thick.viscosity),0.82),"viscosity uses actual volume ratio")
	var whole := Thermal.make_state({"id":"carrot"},0.2)
	var slice := Thermal.make_state({"id":"carrot"},0.02,0.1)
	for i in 900:
		Thermal.advance(whole, {"id":"carrot"},1.0/60.0,190.0,22.0,false,0.2)
		Thermal.advance(slice, {"id":"carrot"},1.0/60.0,190.0,22.0,false,0.02)
	expect(float(slice.core_c)>float(whole.core_c)+10.0,"thin pieces heat internally faster")
	expect(float(whole.faces_c[0])>float(whole.core_c),"contact surface and core stay distinct")
	var boiled := Thermal.make_state({"id":"potato"},0.1)
	for i in 1800: Thermal.advance(boiled,{"id":"potato"},1.0/60.0,100.0,100.0,true,0.1)
	expect(float(boiled.cooked)>0.3 and float(boiled.brown[0])==0.0,"wet cooking softens without dry browning")
	for id in ["butter","cheese","tomato","rock"]:
		var state := Thermal.make_state({"id":id},0.1)
		for i in 2400:
			if i%60==0: Thermal.stir(state, 0.2, false)
			Thermal.advance(state,{"id":id},1.0/60.0,190.0,22.0,false,0.1-float(state.evaporated_kg))
		var native := 0.1-float(state.evaporated_kg)
		expect(float(state.liquid_kg)<=native+0.000001,"phase mass bounded: "+id)
		if id in ["butter","cheese","tomato"]:
			expect(float(state.liquid_kg)>0.01,"finite material phase conversion: "+id)
			var melted := float(state.converted_kg)
			for i in 600: Thermal.advance(state,{"id":id},1.0/60.0,22.0,22.0,false,native)
			expect(float(state.converted_kg)>=melted,"cooling retains shape history: "+id)
		else: expect(float(state.liquid_kg)==0 and float(state.cooked)==0,"stone does not become cooked food or melt")
	var cold := Thermal.make_state({"id":"tomato"},0.1)
	for i in 600: Thermal.advance(cold,{"id":"tomato"},1.0/60.0,22.0,22.0,false,0.1)
	expect(float(cold.cooked)==0 and float(cold.evaporated_kg)==0,"cold food does not cook or emit steam")
	var a := Thermal.make_state({"id":"mushroom"},0.1)
	var b := a.duplicate(true)
	for i in 600: Thermal.advance(a,{"id":"mushroom"},1.0/60.0,180.0,22.0,false,0.1-float(a.evaporated_kg))
	for i in 1200: Thermal.advance(b,{"id":"mushroom"},1.0/120.0,180.0,22.0,false,0.1-float(b.evaporated_kg))
	expect(absf(float(a.core_c)-float(b.core_c))<0.8,"time-step refinement remains stable")
	var saved_brown: Array = a.brown.duplicate()
	Thermal.stir(a,0.4,true)
	expect(a.contact_face==1 and a.brown==saved_brown,"turning changes contact without erasing face history")
	var session=preload("res://modules/restaurant/domain/kitchen_session.gd").new()
	session.setup()
	var seared:=Thermal.make_state({"id":"chicken"},0.2)
	seared.cooked=0.05;seared.brown=[1.0,1.0]
	session.dish=[{"id":"chicken","heat":11.0,"thermal":seared}]
	var dish: Dictionary=session.plate()
	expect(dish.raw_count==1 and float(dish.quality)<0.5,"brown surface cannot give a cold-core ingredient a cooked quality score")
	for failure in failures: push_error(failure)
	print("%s: thermal reactions, %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
func expect(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
