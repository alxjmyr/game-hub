extends SceneTree
var failures := 0
var checks := 0
var victories := 0
var game: Control

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		push_error("FAIL jigsaw: " + description)
		failures += 1

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	root.size = Vector2i(1200, 800)
	game = load("res://games/jigsaw.gd").new()
	root.add_child(game)
	game.completed.connect(func(_data): victories += 1)
	await process_frame
	await process_frame
	for difficulty in 3:
		game.change_difficulty(difficulty)
		for seed_value in range(10):
			game.picture_index = seed_value % 3
			game.new_puzzle(seed_value)
			check(game.reference_panel.visible == (difficulty > 0), "reference shown only on harder levels")
			check(game.reference_image.texture == game.texture, "reference matches current puzzle picture")
			check(game.pieces.size() == [9, 16, 25][difficulty], "difficulty piece count")
			var initial_positions: Array = []
			for piece in game.pieces:
				check(not initial_positions.has(piece.position), "every piece starts in distinct tray slot")
				initial_positions.append(piece.position)
				check(Rect2(Vector2.ZERO, game.canvas.size).encloses(Rect2(piece.position, Vector2.ONE * game.tile_size())), "tray piece remains in canvas")
				check(piece.turns >= 0 and piece.turns <= 3, "valid quarter turn")
			var before := victories
			for index in game.pieces.size():
				game.select_piece(index)
				if difficulty == 2:
					while game.pieces[index].turns != 0: game.rotate_selected()
				check(game.attempt_drop(index, game.target_position(index)), "piece snaps to correct position")
				check(game.pieces[index].placed, "placed piece locks")
				check(not game.attempt_drop(index, Vector2.ZERO), "placed piece cannot move")
			check(game.won and game.placed_count == game.pieces.size(), "all difficulties and seeds completable")
			check(victories == before + 1, "victory emits exactly once")
			game.attempt_drop(0, game.target_position(0))
			check(victories == before + 1, "post-win placement cannot emit again")
	game.change_difficulty(0)
	check(not game.attempt_drop(0, game.target_position(0) + Vector2(game.tile_size() * 0.3 + 0.1, 0)), "drop just beyond snap radius rejected")
	check(game.attempt_drop(0, game.target_position(0) + Vector2(game.tile_size() * 0.3 - 0.1, 0)), "drop just inside snap radius accepted")
	check(game.pieces[0].position == game.target_position(0), "nearby drop snaps exactly onto board")
	game.change_difficulty(2)
	game.new_puzzle(45)
	game.select_piece(0)
	game.pieces[0].turns = 1
	check(not game.attempt_drop(0, game.target_position(0)), "wrong rotation rejects correct square")
	check(game.placed_count == 0, "incorrect drop does not increase completion")
	game.rotate_selected(-1)
	check(game.pieces[0].turns == 0, "reverse rotation")
	check(not game.attempt_drop(0, game.target_position(1)), "wrong square rejected")
	check(not game.attempt_drop(-1, Vector2.ZERO) and not game.attempt_drop(999, Vector2.ZERO), "invalid piece ignored")
	game.attempt_drop(0, Vector2(-999, -999))
	check(game.pieces[0].position == Vector2.ZERO, "offscreen drop clamped")
	game.show_hint()
	check(game.hint_visible and game.hints_used == 1 and game.placed_count == 0, "hint reveals destination without solving")
	game.new_puzzle(99)
	var positions: Array = []
	for piece in game.pieces: positions.append(piece.duplicate())
	game.new_puzzle(99)
	check(game.pieces == positions, "seeded scramble reproducible")
	game.drag_index = 1
	game.change_difficulty(0)
	check(game.drag_index == -1 and not game.won and game.attempts == 0 and game.hints_used == 0 and not game.hint_visible, "difficulty reset clears active drag and puzzle state")
	game.select_piece(0)
	game.rotate_selected()
	check(game.pieces[0].turns == 0 and game.rotate_button.disabled, "beginner mode does not rotate")
	await process_frame
	game.canvas.grab_focus()
	await key(KEY_N)
	check(game.selected == 1, "keyboard selects next piece")
	await key(KEY_RIGHT)
	check(game.cursor == Vector2i(1, 0), "keyboard moves target cursor")
	await key(KEY_ENTER)
	check(game.pieces[1].placed, "keyboard places correct piece")
	check(game.selected == 2, "keyboard advances past locked piece")
	await key(KEY_UP)
	check(game.cursor.y == 0, "cursor bounded at edge")
	game.change_difficulty(2)
	game.select_piece(2)
	var turns: int = game.pieces[2].turns
	await key(KEY_E)
	check(game.pieces[2].turns == (turns + 1) % 4, "keyboard rotates clockwise")
	await key(KEY_Q)
	check(game.pieces[2].turns == turns, "keyboard rotates anticlockwise")
	# Finish a hard puzzle exclusively through dispatched keyboard events.
	game.change_difficulty(2)
	game.canvas.grab_focus()
	var keyboard_victories := victories
	for index in game.pieces.size():
		check(game.selected == index, "keyboard auto-selection follows remaining pieces")
		while game.pieces[index].turns != 0: await key(KEY_E)
		while game.cursor.x > index % game.grid_size: await key(KEY_LEFT)
		while game.cursor.x < index % game.grid_size: await key(KEY_RIGHT)
		while game.cursor.y < index / game.grid_size: await key(KEY_DOWN)
		await key(KEY_ENTER)
		check(game.pieces[index].placed, "keyboard-only hard puzzle places next piece")
	check(game.won and victories == keyboard_victories + 1, "full hard keyboard-only victory")
	game.change_difficulty(0)
	await process_frame
	var source: Vector2 = game.canvas.global_position + (game.pieces[0].position + Vector2.ONE * game.tile_size() / 2) * game.canvas.scale
	var destination: Vector2 = game.canvas.global_position + (game.target_position(0) + Vector2.ONE * game.tile_size() / 2) * game.canvas.scale
	await mouse(source, true)
	check(game.drag_index == 0, "real mouse press picks piece")
	var motion := InputEventMouseMotion.new()
	motion.position = destination
	motion.global_position = destination
	Input.parse_input_event(motion)
	await process_frame
	await mouse(destination, false)
	check(game.drag_index == -1 and game.pieces[0].placed, "real mouse release snaps piece")
	var picture_before: int = game.picture_index
	game.new_picture()
	check(game.picture_index == (picture_before + 1) % 3 and game.placed_count == 0, "new picture cycles artwork and resets")
	check(game.texture.get_width() == 450 and game.texture.get_height() == 450, "local SVG rasterizes successfully")
	var backs := [0]
	game.back_requested.connect(func(): backs[0] += 1)
	game.back_button.pressed.emit()
	check(backs[0] == 1, "back button navigation")
	game.queue_free()
	await process_frame
	print("JIGSAW TESTS: %d checks, %d failure(s); 31 complete puzzles" % [checks, failures])
	quit(1 if failures else 0)
