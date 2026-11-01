extends SceneTree

var failures := 0
var app: Control
var original_save := PackedByteArray()
var had_save := false
const SAVE = "user://progress.cfg"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS hub: " + description)
	else:
		push_error("FAIL hub: " + description)
		failures += 1

func find_buttons(node: Node, text: String) -> Array[Button]:
	var results: Array[Button] = []
	if node is Button and node.text == text:
		results.append(node)
	for child in node.get_children():
		results.append_array(find_buttons(child, text))
	return results

func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func activate(button: Button) -> void:
	button.grab_focus()
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func create_app() -> void:
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1200, 800)
	had_save = FileAccess.file_exists(SAVE)
	if had_save:
		original_save = FileAccess.get_file_as_bytes(SAVE)
		DirAccess.remove_absolute(SAVE)
	await create_app()
	check(is_instance_valid(app.shelf) and app.current_game == null, "launch opens shelf")
	var play := find_buttons(app.shelf, "Play  →")
	check(play.size() == 2, "shelf exposes both game launch buttons")
	await click(app.sound_button)
	check(not app.sound_enabled and app.sound_button.text == "Sound: off", "mouse toggles sound off")
	await activate(play[0])
	check(is_instance_valid(app.current_game) and app.last_game == "memory" and app.shelf == null, "keyboard launches Memory Match")
	var memory: Control = app.current_game
	memory.mismatch_delay = 0.08
	var different := -1
	for i in range(1, memory.deck.size()):
		if memory.deck[i] != memory.deck[0]:
			different = i
			break
	await click(memory.cards[0])
	check(memory.first_index == 0, "real mouse event reveals card")
	memory.select_card(different)
	check(memory.locked, "pending mismatch before navigation")
	await click(find_buttons(memory, "<  Game shelf")[0])
	await create_timer(0.12).timeout
	check(not is_instance_valid(memory) and app.current_game == null and is_instance_valid(app.shelf), "back frees game safely during mismatch timer")
	play = find_buttons(app.shelf, "Play  →")
	await click(play[0])
	memory = app.current_game
	for symbol in range(6):
		memory.select_card(memory.deck.find(symbol))
		memory.select_card(memory.deck.rfind(symbol))
	check(memory.won, "memory victory reached through full game")
	check(app.progress.get_value("memory", "wins", 0) == 1, "shell records completed game")
	await click(find_buttons(memory, "<  Game shelf")[0])
	app.queue_free()
	await process_frame
	await create_app()
	check(not app.sound_enabled and app.sound_button.text == "Sound: off", "sound setting persists across new shell instance")
	check(app.progress.get_value("memory", "wins", 0) == 1, "completion count survives reload from disk")
	play = find_buttons(app.shelf, "Play  →")
	await click(play[0])
	check(app.current_game.best_scores.get("6", 0) == 6, "memory best score restored on game launch")
	await click(find_buttons(app.current_game, "<  Game shelf")[0])
	play = find_buttons(app.shelf, "Play  →")
	await activate(play[1])
	check(is_instance_valid(app.current_game) and app.last_game == "ball_bucket" and app.shelf == null, "keyboard launches Ball & Bucket")
	var physics_game: Control = app.current_game
	var backs := find_buttons(physics_game, "<  Game shelf")
	if backs.is_empty():
		backs = find_buttons(physics_game, "Game shelf")
	if backs.is_empty():
		backs = find_buttons(physics_game, "← Shelf")
	check(not backs.is_empty(), "physics game has a visible shelf button")
	if not backs.is_empty():
		await click(backs[0])
	else:
		physics_game.back_requested.emit()
		await process_frame
	check(not is_instance_valid(physics_game) and is_instance_valid(app.shelf), "physics back returns to shelf and frees scene")
	await click(app.sound_button)
	check(app.sound_enabled and app.player.playing, "sound on produces feedback audio stream")
	await click(app.sound_button)
	check(not app.sound_enabled and not app.player.playing, "muting stops active feedback sound")
	play = find_buttons(app.shelf, "Play  →")
	await click(play[1])
	physics_game = app.current_game
	physics_game.drop_ball()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	check(not is_instance_valid(physics_game) and is_instance_valid(app.shelf), "Escape returns safely during physics simulation")
	app.queue_free()
	await process_frame
	# Allow SceneTree timers and audio mixing references to settle before exit.
	await create_timer(1.0).timeout
	if had_save:
		var file := FileAccess.open(SAVE, FileAccess.WRITE)
		file.store_buffer(original_save)
		file.close()
	else:
		DirAccess.remove_absolute(SAVE)
	print("HUB TESTS: %d failure(s)" % failures)
	quit(1 if failures else 0)
