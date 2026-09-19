extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		quit(1)
		return
	var paper: Control = load("res://scripts/residency/paper_overlay.gd").new()
	paper.mode = "dossier"
	paper.tab = "days"
	paper.show_dossier_reference = true
	root.add_child(paper)
	await process_frame
	var preview := paper.find_child("DossierReferencePreview*",true,false) as TextureRect
	check(is_instance_valid(preview), "Supplied dossier page opens as one image")
	if is_instance_valid(preview):
		var viewport := paper.get_viewport_rect().size
		if viewport.x <= 1 or viewport.y <= 1: viewport = Vector2(1600,900)
		check(is_equal_approx(preview.size.x, viewport.x * 0.60), "Dossier artwork uses three fifths of the screen width")
		check(preview.texture.resource_path.ends_with("dossier-seven-days.png"), "Days tab opens the seven-day artwork")
	check(paper.body == null, "Dossier reference does not create the old outer panel")
	var exploration := paper.get_node_or_null("DossierTab_exploration") as Button
	check(is_instance_valid(exploration), "Exploration paper tab is clickable")
	if is_instance_valid(exploration):
		exploration.pressed.emit()
		await process_frame
		await process_frame
		preview = paper.find_child("DossierReferencePreview*",true,false) as TextureRect
		check(paper.tab == "exploration" and is_instance_valid(preview) and preview.texture.resource_path.ends_with("dossier-exploration.png"), "Clicking a paper tab switches to its supplied page")
	paper.queue_free()
	await process_frame
	var dossier: Control = load("res://scripts/residency/paper_overlay.gd").new()
	dossier.mode = "dossier"
	dossier.tab = "packet"
	root.add_child(dossier)
	await process_frame
	check(dossier.find_children("DossierAction_*","Button",true,false).is_empty(), "Dossier rows do not open the duplicate generic form")
	check(dossier.find_children("DossierTab_*","Button",true,false).is_empty(), "Dossier side tabs do not open the duplicate generic form")
	dossier.queue_free()
	await process_frame
	print("V4_DOSSIER_REFERENCE ", checks, " checks / ", failures, " failures")
	quit(0 if failures == 0 else 1)
