extends Control
var wav: AudioStreamWAV
var markers: Array = []
var peaks := PackedFloat32Array()
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if wav == null: return
	var data := wav.data
	var bytes_per_sample := 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
	var count := data.size()/bytes_per_sample
	for i in 240:
		var peak := 0.0
		var start := int(i*count/240.0)
		var end := int((i+1)*count/240.0)
		for sample in range(start,end,maxi(1,(end-start)/24)):
			var amplitude := absf(float(data.decode_s16(sample*2))/32768.0) if bytes_per_sample == 2 else absf((float(data[sample])-128)/128.0)
			peak = maxf(peak,amplitude)
		peaks.append(peak)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("e5e9dd"))
	draw_line(Vector2(0,size.y*.5),Vector2(size.x,size.y*.5),Color("9fae9c"),1)
	for i in peaks.size():
		var x := (i+.5)*size.x/maxi(1,peaks.size())
		var height := maxf(1,peaks[i]*size.y*.45)
		draw_line(Vector2(x,size.y*.5-height),Vector2(x,size.y*.5+height),Color("688d95"),2)
	if wav != null and wav.get_length()>0:
		for time in markers:
			var x := float(time)/wav.get_length()*size.x
			draw_line(Vector2(x,8),Vector2(x,size.y-8),Color("b87653"),2)
