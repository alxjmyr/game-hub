extends SceneTree
## Actual rigid-body simulation plus public-control/state regression checks.
var game
var failures := 0
var assertions := 0
var wins := 0
func _initialize():
	call_deferred("run")
func check(ok: bool, message: String):
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func run():
	root.size = Vector2i(1200, 800)
	game = load("res://games/ball_bucket.gd").new()
	root.add_child(game)
	game.completed.connect(func(_data): wins += 1)
	await process_frame
	# Exercise the actual difficulty controls, including switching mid-drop.
	for cycle in range(3):
		for level in range(3):
			game.drop_ball()
			var button: Button = game.difficulty_buttons[level]
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = button.get_global_rect().get_center()
			event.pressed = true
			Input.parse_input_event(event)
			await process_frame
			event = event.duplicate()
			event.pressed = false
			Input.parse_input_event(event)
			await process_frame
			check(game.difficulty == level and game.blocks.size() == 3 - level, "Mouse difficulty control sets correct piece budget")
			check(game.state == "editing" and game.ball == null and game.attempts == 0, "Difficulty change resets active attempt")
			for index in range(3):
				check(game.difficulty_buttons[index].button_pressed == (index == level), "Exactly the current difficulty is highlighted")
	for level in range(3):
		game.difficulty = level
		for seed_value in range(1, 25):
			game.new_puzzle(seed_value)
			check(game.blocks.size() == 3 - level, "Difficulty piece budget")
			game.apply_solution()
			var arrangement = game.blocks[0].position
			var angle = game.blocks[0].rotation
			await physics_frame
			game.drop_button.pressed.emit()
			check(game.state == "running" and game.attempts == 1, "Drop button starts attempt")
			game.select_block(0)
			game.rotate_selected(15)
			check(game.blocks[0].rotation == angle, "Cannot edit during simulation")
			while game.state == "running":
				await physics_frame
			check(game.state == "won", "Known solution failed: level %d seed %d" % [level, seed_value])
			game.retry_button.pressed.emit()
			check(game.state == "editing" and game.ball == null, "Retry clears ball")
			check(game.blocks[0].position == arrangement and game.blocks[0].rotation == angle, "Retry preserves layout")
	check(wins == 72, "Win signal exactly once per solution")
	game.difficulty = 0
	game.new_puzzle(101)
	game.select_block(0)
	var angle = game.blocks[0].rotation
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	game._input(key)
	check(is_equal_approx(game.blocks[0].rotation, angle + deg_to_rad(15)), "E key rotates")
	key.keycode = KEY_RIGHT
	var start = game.blocks[0].position
	game._input(key)
	check(game.blocks[0].position.x > start.x, "Arrow key moves selected piece")
	game.return_selected()
	check(game.blocks[0].rotation == 0 and game.blocks[0].position == game._home(0), "Return piece restores home")
	game.show_hint()
	check(game.hint_used and game.selected == 0, "Hint selects useful piece")
	# Remove all ramps from the falling ball's path: failure must remain retryable.
	for index in range(game.blocks.size()):
		game.blocks[index].position = Vector2(100, 180 + index * 100)
	game.drop_ball()
	while game.state == "running":
		await physics_frame
	check(game.state == "missed", "Missing bucket produces retry state")
	game.retry()
	check(game.attempts == 1, "Retry retains attempt count")
	game.drop_ball()
	game.new_puzzle(202)
	check(game.ball == null and game.state == "editing" and game.attempts == 0, "New puzzle safely resets active attempt")
	game.select_block(2)
	for degrees in range(0, 360, 15):
		game.blocks[2].rotation = deg_to_rad(degrees)
		game.blocks[2].position = Vector2(-200, -200)
		game._constrain(game.blocks[2])
		for corner in [Vector2(-60, -48), Vector2(60, -48), Vector2(-60, 8), Vector2(60, 8)]:
			var world_corner = game.blocks[2].position + corner.rotated(game.blocks[2].rotation)
			check(world_corner.x >= 3.99 and world_corner.y >= 84.99, "Rotated bent block stays inside board")
	game.drop_button.grab_focus()
	key.keycode = KEY_SPACE
	game._input(key)
	check(game.state == "running", "Space starts ball even with button focus")
	game.retry()
	var back_count := [0]
	game.back_requested.connect(func(): back_count[0] += 1)
	for child in game.layout.get_children():
		if child is Button and child.text == "<  Game shelf": child.pressed.emit()
	check(back_count[0] == 1, "Shelf button emits navigation signal")
	game.queue_free()
	await process_frame
	print("Ball & Bucket: %d assertions, 72 solved physics layouts, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
