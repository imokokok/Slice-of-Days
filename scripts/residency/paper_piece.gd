extends Panel
## A physical paper used for both drag sources and filing destinations.
signal filed
var material_id := ""
var destination := ""
var require_home := false

func _get_drag_data(_at: Vector2) -> Variant:
	if material_id.is_empty(): return null
	var preview := Label.new()
	preview.text = LocalizationSystem.text(str(ResidencySystem.state().materials.get(material_id,{}).get("title","纸张")))
	preview.add_theme_color_override("font_color",Color("4b5146"))
	preview.add_theme_font_size_override("font_size",20)
	set_drag_preview(preview)
	return {"residency_material":material_id}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if destination.is_empty() or not data is Dictionary or not data.has("residency_material"): return false
	var s := ResidencySystem.state()
	if not s.packet or not s.submitted.is_empty() or (require_home and not ResidencySystem.can_organize()): return false
	var item: Dictionary = s.materials.get(str(data.residency_material),{})
	if item.is_empty() or item.get("kind","") == "official": return false
	if destination == "recognition": return item.kind == "recognition"
	if destination.begins_with("day_"):
		var day := int(destination.trim_prefix("day_"))
		if day < 1 or day > mini(7,GameState.current_day): return false
		if item.kind == "recognition": return s.pages[day-1].marks.size() < 2 or s.pages[day-1].marks.has(str(item.get("resident","")))
	if item.kind == "recognition": return destination == "loose" or destination.begins_with("day_")
	return destination in ["proof","personal","loose"] or destination.begins_with("day_")

func _drop_data(_at: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at,data): return
	if ResidencySystem.file_material(str(data.residency_material),destination,require_home): filed.emit()
