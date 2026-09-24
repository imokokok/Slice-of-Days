extends Control
## Lightweight live feedback drawn above the temporary pan art. It can stay in
## place when final food sprites arrive because it only conveys heat and rhythm.

var layered_pot := false
var pulse_tween: Tween
var simmer_time := 0.0
var wetness := 0.35:
	set(value): wetness=clampf(value,0.0,1.0); queue_redraw()

var heat := 0.0:
	set(value): heat=clampf(value,0.0,1.0); queue_redraw()
var ingredient_count := 0:
	set(value): ingredient_count=value; queue_redraw()
var active := false:
	set(value): active=value; queue_redraw()
var stir_pulse := 0.0:
	set(value): stir_pulse=value; queue_redraw()


func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not active or SettingsSystem.reduced_motion(): return
	simmer_time+=delta*maxf(0.25,heat*1.6)
	queue_redraw()


func pulse() -> void:
	if SettingsSystem.reduced_motion():
		stir_pulse=0.35
		return
	if pulse_tween and pulse_tween.is_valid(): pulse_tween.kill()
	pulse_tween=create_tween()
	stir_pulse=1.0
	pulse_tween.tween_property(self,"stir_pulse",0.0,0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if not active: return
	var center := size*Vector2(0.49,0.39 if layered_pot else 0.54)
	var glow := Color("eed577",clampf((heat-0.18)*0.16,0.0,0.12))
	if not layered_pot: draw_circle(center,155.0+stir_pulse*8.0,glow)
	if ingredient_count <= 0: return
	var bubble_count := roundi((2.0+heat*12.0)*wetness)
	for i in bubble_count:
		var angle := float(i)*2.399+heat*0.7
		var radius := 32.0+float((i*37)%102)
		var drift := sin(simmer_time+float(i)*1.8)*2.0
		var point := center+Vector2(cos(angle)*radius+drift,sin(angle)*(0.12 if layered_pot else 0.68)*radius)
		var bubble_radius := 2.0+float(i%3)+stir_pulse*2.0
		draw_arc(point,bubble_radius,0.0,TAU,12,Color("faf7ee",(0.20+heat*0.36)*wetness),1.5,true)
	if heat > 0.56 and wetness>0.20:
		for i in 3:
			var x := center.x-62.0+i*58.0
			var lift := (heat-0.56)*95.0+sin(simmer_time*1.4+float(i))*5.0
			draw_line(Vector2(x,center.y-(28 if layered_pot else 128)),Vector2(x+8,center.y-(50 if layered_pot else 150)-lift),Color("faf7ee",0.20*wetness),3.0,true)
