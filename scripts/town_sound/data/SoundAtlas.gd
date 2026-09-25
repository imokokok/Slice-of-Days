extends RefCounted
## Source identity comes from gameplay, never guessed from a waveform.
const KINDS := ["wind", "fire", "water", "rain", "bird", "paper", "wood", "metal", "voice", "pulse"]
const LABELS := ["风 / 流线", "火 / 余烬", "水 / 涟漪", "雨 / 斜点", "鸟 / 跃点", "纸 / 折片", "木 / 节拍", "金属 / 光环", "人声 / 山脊", "抽象 / 色块"]
const PLACES := {
	"park":["water","wind","bird"], "port":["water","wind","metal"],
	"night_market":["fire","metal","wood"], "cafeteria":["fire","water","metal"],
	"cafe":["water","metal","paper"], "library":["paper","wood"],
	"handcraft_shop":["paper","wood","metal"], "print_shop":["paper","metal"],
	"record_store":["paper","wood","pulse"], "residence":["wood","paper","rain"],
	"bus_stop":["wind","metal"], "old_station":["wind","metal","bird"]}
const QUESTS := [
	{"id":"first_postcard","title":"01 · 小镇声音明信片", "brief":"两种声音，至少 8 秒。做出你的第一张唱片。", "kinds":2,"seconds":8.0,"required":[]},
	{"id":"hearth_and_air","title":"02 · 炉火与晚风", "brief":"去饭店采火声、公交站采风声；把两者编成 12 秒的作品。", "kinds":2,"seconds":12.0,"required":["fire","wind"]},
	{"id":"paper_city","title":"03 · 纸上的节奏", "brief":"收集纸、木、金属。让三种质地在 16 秒内轮流出现。", "kinds":3,"seconds":16.0,"required":["paper","wood","metal"]},
	{"id":"river_letter","title":"04 · 海边来信", "brief":"水、风、鸟声组成至少 20 秒的海边记忆。", "kinds":3,"seconds":20.0,"required":["water","wind","bird"]}]

static func at(place: String) -> Array:
	return PLACES.get(place, ["wind","wood"])

static func label(kind: String) -> String:
	var index := KINDS.find(kind)
	return LABELS[index] if index >= 0 else LABELS[-1]

static func stream(kind: String) -> AudioStream:
	if kind == "fire": return load("res://art/town_sound_cc0/fire.wav")
	if kind == "wind": return load("res://art/town_sound_cc0/wind.wav")
	if kind == "water": return load("res://art/town_sound_cc0/water.wav")
	if kind == "pulse": return load("res://art/town_sound_cc0/wood.ogg")
	if kind in ["paper","metal","wood","bird","rain"]: return load("res://art/town_sound_cc0/"+kind+".ogg")
	var key: String = {"water":"foley_water_1","rain":"ambience_rain","bird":"bird_1","paper":"foley_paper_1","wood":"foley_wood_1","metal":""}.get(kind, "")
	var sound := preload("res://scripts/ui/production_assets.gd").sound(key)
	if sound != null: return sound
	# Existing authored Foley is the offline fallback, with an explicit source label.
	var place: String = {"paper":"library","metal":"cafe","water":"park"}.get(kind,"record_store")
	return load("res://scripts/town_sound/audio/WorldSound.gd").make_detail(place)

static func kinds_in(clips: Array) -> Array:
	var found: Array = []
	for clip in clips:
		var kind := str(clip.get("sound_kind", "pulse"))
		if not found.has(kind): found.append(kind)
	return found

static func meets(quest: Dictionary, record: Dictionary) -> bool:
	var kinds: Array = record.get("sound_kinds", [])
	if float(record.get("duration",0)) < float(quest.seconds) or kinds.size() < int(quest.kinds): return false
	for kind in quest.required:
		if not kinds.has(kind): return false
	return not str(record.get("record_id", "")).is_empty()

static func audible_kinds(model: Arrangement) -> Array:
	var kinds: Array=[]
	for clip in model.clips:
		var track:=int(clip.track)
		if model.muted[track] or float(model.gains[track])*float(clip.volume)<=0: continue
		var source:=model.load_pcm(str(clip.sample_id))
		if source.is_empty(): continue
		var pcm: PackedFloat32Array=source.pcm
		var events:Array=clip.get("mv_events",[]).duplicate(true)
		if events.is_empty() or float(events[0].time)>0: events.push_front({"time":0.0,"kind":str(clip.get("sound_kind","pulse"))})
		for e in events.size():
			var from:=maxf(float(clip.source_start),float(events[e].time))
			var until:=minf(float(clip.source_end),float(events[e+1].time) if e+1<events.size() else float(clip.source_end))
			var kind:=str(events[e].kind)
			if kinds.has(kind) or until<=from: continue
			for i in range(maxi(0,int(from*float(source.rate))),mini(pcm.size(),int(until*float(source.rate))),16):
				if absf(pcm[i])>.0001: kinds.append(kind); break
	return kinds
