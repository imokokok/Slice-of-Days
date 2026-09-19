extends SceneTree

class FakeStage extends Control:
	var velocity := 0.0
	var indoor := false

class FakeHost extends Control:
	var stage: Control

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := FakeHost.new()
	var stage := FakeStage.new()
	host.stage = stage
	root.add_child(host)
	host.add_child(stage)
	var shell = load("res://scripts/residency/gameplay_shell.gd").new()
	host.add_child(shell)
	shell.set_process(false)

	var expected_color := Color("173b63")
	check(shell.next_button.get_theme_constant("outline_size") == 4, "Next/Today prompt has a four-pixel outline")
	check(shell.next_button.get_theme_color("font_outline_color").is_equal_approx(expected_color), "Next/Today prompt uses the dark-blue outline")
	check(shell.hint_label.get_theme_constant("outline_size") == 4, "Context key prompts have a four-pixel outline")
	check(shell.hint_label.get_theme_color("font_outline_color").is_equal_approx(expected_color), "Context key prompts use the dark-blue outline")

	host.queue_free()
	print("Key prompt outline checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
