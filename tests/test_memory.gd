extends SceneTree

var failures := 0
var game: Control
var victories := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS memory: " + description)
	else:
		push_error("FAIL memory: " + description)
		failures += 1

func run() -> void:
	game = load("res://games/memory.gd").new()
	root.add_child(game)
	game.mismatch_delay = 0.03
	game.completed.connect(func(_data): victories += 1)
	await process_frame
	for count in [6, 10, 15]:
		game.start_game(count)
		check(game.deck.size() == count * 2 and game.cards.size() == count * 2, "%d-pair board size" % count)
		for index in range(game.cards.size()):
			check(game.cards[index].tooltip_text.is_empty() and game.cards[index].accessibility_name == "Hidden card %d" % (index + 1), "hidden card has accessible label without native tooltip")
		for symbol in range(count):
			check(game.deck.count(symbol) == 2, "symbol %d appears exactly twice" % symbol)
	game.start_game(6)
	game.select_card(-1)
	game.select_card(999)
	check(game.moves == 0 and game.first_index == -1, "invalid selection ignored")
	game.select_card(0)
	check(game.cards[0].tooltip_text.is_empty() and game.cards[0].accessibility_name == game.WORDS[game.deck[0]], "revealed card updates accessible label without native tooltip")
	game.select_card(0)
	check(game.moves == 0 and game.first_index == 0, "cannot match card with itself")
	var different := -1
	for i in range(1, game.deck.size()):
		if game.deck[i] != game.deck[0]:
			different = i
			break
	game.select_card(different)
	check(game.moves == 1 and game.locked, "mismatch increments moves and locks input")
	game.select_card(2)
	check(game.first_index == -1, "third flip ignored while mismatch visible")
	await create_timer(0.06).timeout
	check(not game.locked and not game.cards[0].revealed and not game.cards[different].revealed, "mismatch hides both cards and unlocks")
	check(game.cards[0].accessibility_name == "Hidden card 1" and game.cards[0].tooltip_text.is_empty(), "conceal restores hidden label without tooltip")
	game.select_card(0)
	game.select_card(different)
	game.start_game(10)
	game.select_card(0)
	await create_timer(0.06).timeout
	check(game.pair_count == 10 and game.moves == 0 and game.cards[0].revealed and game.first_index == 0, "restart cancels stale mismatch callback")
	game.start_game(6)
	for symbol in range(6):
		var first: int = game.deck.find(symbol)
		var second: int = game.deck.rfind(symbol)
		game.select_card(first)
		game.select_card(second)
		check(game.cards[first].found and game.cards[second].found, "matched cards stay revealed")
		game.select_card(first)
		check(game.first_index == -1, "matched card cannot be selected again")
	check(game.won and game.moves == 6 and game.matched.size() == 12, "complete board produces victory")
	check(victories == 1 and game.best_scores.get("6") == 6, "victory emits once and records best")
	game.select_card(0)
	check(victories == 1 and game.moves == 6, "finished board is stable")
	game.start_game(15)
	check(not game.won and not game.locked and game.moves == 0 and game.matched.is_empty(), "new game resets victory state")
	game.cards[0].grab_focus()
	var key := InputEventAction.new()
	key.action = "ui_accept"
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key = InputEventAction.new()
	key.action = "ui_accept"
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	check(game.first_index == 0 and game.cards[0].revealed, "focused card accepts keyboard activation")
	for count in [10, 15]:
		game.start_game(count)
		for symbol in range(count):
			game.select_card(game.deck.find(symbol))
			game.select_card(game.deck.rfind(symbol))
		check(game.won and game.moves == count and game.matched.size() == count * 2, "%d-pair board can be completed" % count)
	var backs := [0]
	game.back_requested.connect(func(): backs[0] += 1)
	var back_button: Button = game.get_child(0).get_child(0).get_child(0).get_child(0)
	back_button.pressed.emit()
	check(backs[0] == 1, "back button emits navigation signal")
	game.queue_free()
	await process_frame
	print("MEMORY TESTS: %d failure(s)" % failures)
	quit(1 if failures else 0)
