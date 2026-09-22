extends RefCounted
## Schedules own interaction availability. The camera owns visual retirement.
## Keep the old pose/location while visible, including both market disputants.
var residents: Dictionary = {}
const MARGIN := 160.0

func reconcile(hotspots: Array, camera_x: float, width := 1600.0) -> Array[Dictionary]:
	var desired: Dictionary = {}
	for item: Dictionary in hotspots:
		if str(item.get("kind", "")) in ["person", "shopkeeper", "npc", "resident"]:
			if not ResidentProfileSystem.is_core(str(item.get("id", ""))): continue
			desired[str(item.id)] = item.duplicate(true)
			desired[str(item.id)].kind="shopkeeper" if item.kind=="shopkeeper" else "person"
	# The authored pair takes precedence over its scheduled solo appearances.
	for item: Dictionary in hotspots:
		if str(item.get("kind", "")) == "argument":
			for id in ["chenyuan", "wu_wu"]:
				desired[id] = {"kind":"person", "id":id, "x":float(item.x) + (-70 if id == "chenyuan" else 70), "pose_facing":1.0 if id == "chenyuan" else -1.0}
	for id in residents.keys():
		var old: Dictionary = residents[id]
		var visible := float(old.x) + MARGIN >= camera_x and float(old.x) - MARGIN <= camera_x + width
		if not visible:
			residents.erase(id)
		elif desired.has(id):
			# Do not teleport an on-camera person when their schedule advances.
			desired.erase(id)
	for id in desired:
		residents[id] = desired[id]
	var result: Array[Dictionary] = []
	for item: Dictionary in residents.values(): result.append(item)
	return result
