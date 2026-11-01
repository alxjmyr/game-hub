extends SceneTree
var failures := 0
var assertions := 0
var victories := 0
var game: Control
var results: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		push_error("FAIL letter_hunt: " + description)
		failures += 1
func key(character: String, echo_event := false, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = echo_event
	event.ctrl_pressed = ctrl
	event.unicode = character.unicode_at(0)
	event.keycode = character.to_upper().unicode_at(0)
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func special(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	root.size = Vector2i(1200, 800)
	game = load("res://games/letter_hunt.gd").new()
	root.add_child(game)
	game.completed.connect(func(data): victories += 1; results.append(data))
	await process_frame
	for level in 3:
		game.change_difficulty(level)
		for seed_value in 30:
			game.start_round(seed_value)
			check(game.prompts.size() == game.ROUND_LENGTHS[level], "correct round length")
			var saw_number := false
			for prompt in game.prompts:
				if level == 2:
					check(prompt in game.WORDS and prompt.length() >= 3, "known age-appropriate words")
				else:
					check(prompt.length() == 1 and prompt in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", "valid key targets")
					if prompt in "0123456789": saw_number = true
			check(saw_number == (level == 1), "digits only in mixed level and guaranteed")
			var same: Array = game.prompts.duplicate()
			game.start_round(seed_value)
			check(game.prompts == same, "seed deterministic")
	game.change_difficulty(0)
	var initial: String = game.expected_character()
	await key(initial, true)
	await key(initial, false, true)
	check(game.prompt_index == 0 and game.correct_keys == 0, "held and modifier shortcuts ignored")
	await key("Z" if initial != "Z" else "A")
	check(game.prompt_index == 0 and game.correct_keys == 0 and not game.won, "wrong key keeps progress")
	game.restart_button.grab_focus()
	await key(initial.to_lower())
	check(game.prompt_index == 1, "lowercase input works while toolbar focused")
	await special(KEY_BACKSPACE)
	check(game.prompt_index == 1, "backspace never removes earned stars")
	await special(KEY_LEFT)
	check(game.prompt_index == 1, "navigation keys do not count as guesses")
	game.change_difficulty(2)
	await key(game.expected_character())
	check(game.typed.length() == 1, "word builds one character at a time")
	await special(KEY_BACKSPACE)
	check(game.typed.is_empty() and game.correct_keys == 0, "backspace undoes partial word")
	game.toggle_hints()
	check(not game.hints_enabled and game.hint_button.text.ends_with("off"), "hints toggle off")
	game.start_round(123)
	check(not game.hints_used and not game.hints_enabled, "hint preference survives restart")
	game.toggle_hints()
	check(game.hints_enabled and game.hints_used, "hint usage records")
	await key(game.expected_character())
	game.change_difficulty(0)
	check(game.typed.is_empty() and game.prompt_index == 0 and game.correct_keys == 0, "difficulty cancels partial word")
	var original_level: int = game.difficulty
	game.change_difficulty(-1)
	game.change_difficulty(3)
	check(game.difficulty == original_level, "invalid difficulty ignored")
	for level in 3:
		game.change_difficulty(level)
		var expected_count := 0
		for prompt in game.prompts: expected_count += prompt.length()
		var safety := 0
		while not game.won and safety < 100:
			await key(game.expected_character())
			safety += 1
		check(game.won and game.prompt_index == game.prompts.size(), "full real-input round won level %d" % level)
		check(game.correct_keys == expected_count and victories == level + 1, "accurate tally and one victory")
		check(results[-1].difficulty == level and results[-1].stars == game.prompts.size(), "completion payload")
		await key("A")
		await special(KEY_BACKSPACE)
		check(victories == level + 1 and game.correct_keys == expected_count, "victory stable")
		game.restart_button.pressed.emit()
		check(not game.won and game.prompt_index == 0 and game.typed.is_empty(), "new round after win")
	var backs := [0]
	game.back_requested.connect(func(): backs[0] += 1)
	game.back_button.pressed.emit()
	check(backs[0] == 1, "back emits navigation")
	check(game.board.tooltip_text.is_empty() and game.board.accessibility_name.begins_with("Type "), "accessible prompt without native tooltip")
	game.queue_free()
	await process_frame
	print("LETTER HUNT: %d assertions, 3 full keyboard rounds, %d failure(s)" % [assertions, failures])
	quit(1 if failures else 0)
