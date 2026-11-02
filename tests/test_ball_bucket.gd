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
			root.push_input(event, true)
			await process_frame
			event = event.duplicate()
			event.pressed = false
			root.push_input(event, true)
			await process_frame
			check(game.difficulty == level and (game.blocks.size() >= 1 and game.blocks.size() <= 4 if level == 2 else game.blocks.size() == 3 - level), "Mouse difficulty control sets correct piece budget")
			check(game.state == "editing" and game.ball == null and game.attempts == 0, "Difficulty change resets active attempt")
			for index in range(3):
				check(game.difficulty_buttons[index].button_pressed == (index == level), "Exactly the current difficulty is highlighted")
	for level in range(3):
		game.difficulty = level
		for seed_value in range(1, 25):
			game.new_puzzle(seed_value)
			check((game.blocks.size() >= 1 and game.blocks.size() <= 4 if level == 2 else game.blocks.size() == 3 - level), "Difficulty piece budget")
			for index in range(game.blocks.size()):
				check(game._dock_slot(index).has_point(game.blocks[index].position), "Every difficulty starts pieces in separate dock slots")
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
	# Broad seeded coverage of randomized heights, toolbox composition and mirroring.
	game.difficulty = 2
	var budgets := {}
	var drop_heights := {}
	var bucket_heights := {}
	var barrier_shapes := {}
	var barrier_angles := {}
	for seed_value in range(1000, 1250):
		game.new_puzzle(seed_value)
		budgets[game.blocks.size()] = true
		barrier_shapes[str(game.barriers[0].curved) + str(game.barriers[0].bent)] = true
		barrier_angles[roundi(rad_to_deg(game.barriers[0].rotation))] = true
		for index in range(game.blocks.size()):
			var piece = game.blocks[index]
			check(piece.docked and piece.collision_layer == 0, "Unused dock pieces cannot collide with ball")
			var bounds: Rect2 = piece.bounds()
			for corner in [bounds.position, bounds.end, Vector2(bounds.end.x, bounds.position.y), Vector2(bounds.position.x, bounds.end.y)]:
				check(game._dock_slot(index).has_point(piece.position + corner * piece.scale), "Dock preview fits its own slot below board")
		drop_heights[int(game.drop_point.y)] = true
		bucket_heights[int(game.bucket_center.y)] = true
		check(game.barriers.size() == 1 and game.barriers[0].fixed, "Engineer has fixed barrier")
		check(game.blocks[0].curved, "Engineer includes a curved ramp")
		var drop = game.drop_point
		var bucket = game.bucket_center
		var budget = game.blocks.size()
		game.new_puzzle(seed_value)
		check(game.drop_point == drop and game.bucket_center == bucket and game.blocks.size() == budget, "Engineer seed reproduces puzzle")
		game.apply_solution()
		await physics_frame
		game.drop_ball()
		while game.state == "running": await physics_frame
		check(game.state == "won", "Engineer randomized solution failed: seed %d" % seed_value)
	check(barrier_shapes.size() == 3 and barrier_angles.size() >= 7, "Engineer varies fixed barrier shapes and orientations")
	check(budgets.size() == 4, "Engineer varies between one and four pieces")
	check(drop_heights.size() > 20 and bucket_heights.size() > 20, "Engineer varies both heights")
	game.new_puzzle(101)
	# Use viewport mouse events at the fitted layout scale, including dock return.
	var dock_point = game.board.get_global_transform_with_canvas() * game._dock_slot(0).get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = dock_point
	root.push_input(press, true)
	check(game.selected == 0 and game.dragging and not game.blocks[0].docked, "Mouse picks up shape from dock")
	var motion := InputEventMouseMotion.new()
	motion.position = game.board.get_global_transform_with_canvas() * Vector2(300, 300)
	root.push_input(motion, true)
	var release = press.duplicate()
	release.pressed = false
	release.position = motion.position
	root.push_input(release, true)
	check(not game.dragging and game.blocks[0].position.distance_to(Vector2(300, 300)) < 0.01, "Mouse places full size shape on board")
	press.position = motion.position
	root.push_input(press, true)
	motion.position = dock_point
	root.push_input(motion, true)
	release.position = dock_point
	root.push_input(release, true)
	check(game.blocks[0].docked and game.blocks[0].collision_layer == 0, "Dragging back to dock disables collisions")
	game.select_block(-1)
	press.position = game.barriers[0].get_global_transform_with_canvas() * Vector2.ZERO
	root.push_input(press, true)
	check(game.selected == -1 and not game.dragging, "Fixed barriers cannot be picked up")
	release.position = press.position
	root.push_input(release, true)
	var curve = game.blocks[0]
	check(curve.hit(curve._curve_point(0.8) + Vector2(0, 8)), "Curve surface is selectable")
	check(not curve.hit(Vector2(0, -50)), "Empty space above curve is not selectable")
	for degrees in range(0, 360, 15):
		curve.rotation = deg_to_rad(degrees)
		curve.position = Vector2(-200, 900)
		game._constrain(curve)
		for t in [0.0, 0.5, 1.0]:
			for offset in [Vector2.ZERO, Vector2(0, 16)]:
				var point = curve.position + ((curve._curve_point(t) + offset) * curve.scale).rotated(curve.rotation)
				check(point.x >= 3.99 and point.x <= 856.01 and point.y >= 84.99 and point.y <= 526.01, "Rotated curve stays within board")
	game.difficulty = 0
	game.new_puzzle(101)
	check(game.barriers.is_empty(), "Leaving Engineer removes barriers")
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
	check(game.blocks[0].docked and game.blocks[0].collision_layer == 0, "Return disables dock collisions")
	game.rotate_selected(15)
	check(not game.blocks[0].docked and game.blocks[0].collision_layer == 1 and game.blocks[0].scale == Vector2.ONE, "Keyboard deploys dock piece at full size")
	game.return_selected()
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
	print("Ball & Bucket: %d assertions, 322 solved physics layouts, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
