extends RefCounted
## Frequency magnitudes/dB normalization adapted from Godot's official
## audio/spectrum/show_spectrum.gd at a3b5c113112f77291d5f3d1360f33a882fdc52f7.
## MIT: third_party/licenses/godot_demos/LICENSE.md. No demo music/UI copied.
const EDGES := [40.0,160.0,400.0,1000.0,2500.0,6000.0,12000.0]
const MIN_DB := 60.0

static func read(instance: AudioEffectSpectrumAnalyzerInstance, gain := 1.0) -> PackedFloat32Array:
	var data := PackedFloat32Array(); data.resize(6)
	if instance==null: return data
	for i in 6:
		var magnitude := instance.get_magnitude_for_frequency_range(EDGES[i],EDGES[i+1]).length()*gain
		data[i]=clampf((MIN_DB+linear_to_db(maxf(magnitude,0.000001)))/MIN_DB,0.0,1.0)
	return data

static func from_wav(wav: AudioStreamWAV, seconds: float) -> PackedFloat32Array:
	# Analyze saved PCM during playback, including completely offline sessions.
	var data := PackedFloat32Array(); data.resize(6)
	if wav==null or wav.format!=AudioStreamWAV.FORMAT_16_BITS: return data
	var stride := 4 if wav.stereo else 2
	var start := int(seconds*wav.mix_rate)*stride
	var count := mini(512,(wav.data.size()-start)/stride)
	if count<16: return data
	for band in 6:
		var frequency := sqrt(EDGES[band]*EDGES[band+1])
		var coefficient := 2.0*cos(TAU*frequency/wav.mix_rate)
		var a := 0.0; var b := 0.0
		for i in count:
			var value := wav.data.decode_s16(start+i*stride)/32768.0
			value*=.5-.5*cos(TAU*i/float(count-1))
			var c := value+coefficient*a-b; b=a; a=c
		var magnitude := sqrt(maxf(0,a*a+b*b-coefficient*a*b))/count
		data[band]=clampf((MIN_DB+linear_to_db(maxf(magnitude,0.000001)))/MIN_DB,0,1)
	return data
