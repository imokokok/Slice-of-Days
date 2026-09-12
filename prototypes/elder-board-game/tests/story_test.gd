extends SceneTree
const Memory = preload("res://scripts/elder_memory.gd")
const Story = preload("res://scripts/elder_story.gd")

func _initialize() -> void:
	Memory.directory = "user://story-test-%d" % Time.get_ticks_usec()
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._preview_story()
	await process_frame
	var story = main.story_view
	for chapter in range(5):
		for page in range(3):
			assert(story.chapter == chapter and story.page == page)
			story.choose(0)
			assert(story.words.text == Story.CHAPTERS[chapter][page].replies[0])
			story.refresh()
			story.choose(1)
			assert(story.words.text == Story.CHAPTERS[chapter][page].replies[1])
			story.refresh()
			await process_frame
			assert(story.next.size.x <= 475 and story.alternative.size.x <= 480)
			assert(story.words.get_minimum_size().y <= 205)
			if chapter == 0 and page == 1 and "--capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../story-preview.png")
			story.choose(0)
			story.advance()
	assert(Memory.story_index() == 0)
	await process_frame
	assert(not is_instance_valid(main.story_view))
	main._show_story()
	await process_frame
	main.story_view.closed.emit()
	await process_frame
	assert(Memory.story_index() == 0)
	print("STORY BRANCHES / LAYOUT / PREVIEW / LEAVE: PASS")
	quit()
