extends SceneTree

var failures := 0
var wins := 0
var game := preload("res://games/minesweeper.gd").new()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL minesweeper: " + message)

func fixture() -> void:
	game.start_game()
	# A solid middle row isolates the two blank regions. The corner mine
	# gives the upper region a diagonal 1 and a numbered flood boundary.
	for i in [0, 36, 37, 38, 39, 40, 41, 42, 43, 44]:
		game.mines[i] = true

func oracle_count(index: int) -> int:
	var count := 0
	for mine in game.mines:
		if mine != index and absi(mine % 9 - index % 9) <= 1 and absi(mine / 9 - index / 9) <= 1:
			count += 1
	return count

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func click(button: Control, mouse: MouseButton) -> void:
	var pos := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.button_index = mouse
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func run() -> void:
	root.size = Vector2i(1200, 800)
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.completed.connect(func(_result): wins += 1)
	await process_frame
	await process_frame
	seed(4711)
	var layouts := {}
	for first in 81:
		game.start_game()
		game.reveal(first)
		check(game.mines.size() == 10 and oracle_count(first) == 0 and first in game.opened, "safe opening %d" % first)
		var positions := game.mines.keys()
		positions.sort()
		layouts[str(positions)] = true
		for i in 81:
			check(game.adjacent_count(i, game.mines) == oracle_count(i), "clue %d on board %d" % [i, first])
			if i in game.opened:
				var clue := oracle_count(i)
				check(i not in game.mines and game.cells[i].text == (str(clue) if clue else ""), "visible clue")
	check(layouts.size() > 1, "boards vary")

	# Force rare high clues as well as the everyday ones.
	for count in range(1, 9):
		game.start_game()
		for i in [30, 31, 32, 39, 41, 48, 49, 50].slice(0, count):
			game.mines[i] = true
		for i in range(10 - count):
			game.mines[i] = true
		game.reveal(40)
		check(game.opened.size() == 1 and game.cells[40].text == str(count), "numbered reveal %d" % count)

	game.start_game()
	await click(game.cells[0], MOUSE_BUTTON_RIGHT)
	await key(KEY_ENTER)
	check(game.flags.has(0) and game.mines.is_empty(), "flag protects first move")
	await key(KEY_F)
	await key(KEY_RIGHT)
	check(game.flags.is_empty() and game.cells[1].has_focus(), "keyboard flag and arrow")
	await key(KEY_SPACE)
	check(1 in game.opened and game.hit == -1, "keyboard first reveal")
	await click(game.new_button, MOUSE_BUTTON_LEFT)
	check(game.mines.is_empty() and game.opened.is_empty(), "restart while playing")
	await click(game.flag_mode, MOUSE_BUTTON_LEFT)
	await click(game.cells[0], MOUSE_BUTTON_LEFT)
	check(0 in game.flags and game.mines.is_empty(), "single-button flag mode")

	fixture()
	game.toggle_flag(12)
	game.reveal(8)
	check(12 not in game.opened and game.opened.size() == 34 and 45 not in game.opened, "flood stops at flags and numbered boundary")
	game.toggle_flag(8)
	check(8 not in game.flags, "open square cannot be flagged")
	game.toggle_flag(12)
	game.reveal(12)
	game.reveal(80)
	check(game.won and wins == 1 and game.flags.is_empty(), "win requires only safe cells")
	game.reveal(0)
	game.toggle_flag(0)
	check(wins == 1 and game.hit < 0 and game.flags.is_empty(), "win is final")

	fixture()
	game.reveal(10)
	game.reveal(10)
	check(game.opened.size() == 1 and game.cells[10].text == "1", "diagonal clue and mismatched chord")
	game.toggle_flag(0)
	game.reveal(10)
	check(game.hit < 0 and game.opened.size() == 35 and 0 not in game.opened, "correct chord")
	fixture()
	game.reveal(10)
	game.toggle_flag(1)
	game.reveal(10)
	check(game.hit == 0 and game.cells[1].text == "×" and wins == 1, "wrong chord loses and marks incorrect flag")
	var total := game.opened.size()
	game.reveal(80)
	game.toggle_flag(80)
	check(game.opened.size() == total and game.flags.size() == 1, "loss is final")
	for mine in game.mines:
		check(game.cells[mine].text == "✹", "loss reveals mines")
	await click(game.new_button, MOUSE_BUTTON_LEFT)
	check(game.hit < 0 and not game.won and game.flags.is_empty() and not game.flag_mode.button_pressed, "clean restart after loss")
	fixture()
	await click(game.cells[0], MOUSE_BUTTON_LEFT)
	check(game.hit == 0 and not game.won and wins == 1, "direct hit loses")
	game.queue_free()
	await process_frame
	print("MINESWEEPER TESTS: %d failure(s)" % failures)
	quit(1 if failures else 0)
