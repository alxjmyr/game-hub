extends SceneTree
var failures := 0
var checks := 0
var game: Control
var victories := 0
var last_result: Dictionary

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL maze: " + message)

# Independent breadth-first oracle, reading raw passages rather than game pathfinding.
func oracle(start: Vector2i, goal: Vector2i, locked: bool) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var previous := {start: start}
	var head := 0
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	while head < queue.size():
		var p := queue[head]
		head += 1
		for i in range(4):
			if not game.passages[p.y * game.dimensions.x + p.x] & (1 << i): continue
			var next: Vector2i = p + directions[i]
			if locked and next == game.door_cell: continue
			if previous.has(next): continue
			previous[next] = p
			queue.append(next)
	var result: Array[Vector2i] = []
	if not previous.has(goal): return result
	var p := goal
	while p != start:
		result.push_front(p)
		p = previous[p]
	result.push_front(start)
	return result

func walk(route: Array[Vector2i]) -> void:
	for i in range(1, route.size()):
		game.move_player(route[i] - game.player_cell)
		check(game.player_cell == route[i], "walk follows each valid corridor")

func keypress(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	root.size = Vector2i(1200, 800)
	game = load("res://games/maze.gd").new()
	root.add_child(game)
	game.completed.connect(func(data):
		victories += 1
		last_result = data)
	await process_frame
	var fingerprints := {}
	for level in range(3):
		game.change_difficulty(level)
		check(game.dimensions == [Vector2i(7,5), Vector2i(11,7), Vector2i(15,9)][level], "difficulty dimensions")
		for seed_value in range(40):
			game.new_maze(seed_value)
			fingerprints[hash(game.passages)] = true
			check(not game.won and game.steps == 0 and not game.has_key and not game.door_open, "new maze resets state")
			var corridor_count := 0
			for y in range(game.dimensions.y):
				for x in range(game.dimensions.x):
					var cell := Vector2i(x, y)
					check(not oracle(Vector2i.ZERO, cell, false).is_empty(), "all cells reachable")
					for direction in range(4):
						if not game.passages[game.index_of(cell)] & (1 << direction): continue
						var next: Vector2i = cell + game.DIRECTIONS[direction]
						check(game.in_bounds(next), "no passages outside maze")
						check(bool(game.passages[game.index_of(next)] & (1 << ((direction + 2) % 4))), "corridors reciprocal")
						corridor_count += 1
			check(corridor_count / 2 == game.passages.size() - 1, "maze is a connected tree")
			var before: int = victories
			if level > 0:
				check(game.key_cell != Vector2i.ZERO and game.key_cell != game.door_cell and game.key_cell != game.exit_cell, "key distinct from start door exit")
				check(oracle(Vector2i.ZERO, game.exit_cell, true).is_empty(), "door blocks only exit route")
				var key_route := oracle(Vector2i.ZERO, game.key_cell, true)
				check(not key_route.is_empty(), "key reachable with door locked")
				var exit_route := oracle(Vector2i.ZERO, game.exit_cell, false)
				check(not game.key_cell in exit_route, "key requires a detour off the exit route")
				check(not key_route[key_route.size() - 2] in exit_route, "key is at least two steps into its side branch")
				var delta: Vector2i = game.key_cell - game.door_cell
				var minimum := 4 if level == 1 else 5
				check(absi(delta.x) + absi(delta.y) >= minimum, "key visually separated from door")
				check(oracle(game.key_cell, game.door_cell, false).size() - 1 >= minimum * 2, "retrieval requires a substantial walk back to door")
				game.show_hint()
				check(game.hint_cells == key_route.slice(1, mini(key_route.size(), 5)), "hint leads toward reachable key")
				walk(key_route)
				check(game.has_key and not game.door_open and game.hint_cells.is_empty(), "pickup carries key without opening door")
				check("Carrying key" in game.counter_label.text, "inventory shows carried key")
				var door_route := oracle(game.player_cell, game.door_cell, false)
				walk(door_route.slice(0, door_route.size() - 1))
				check(game.has_key and not game.door_open, "key held and door closed for entire approach")
				game.move_player(game.door_cell - game.player_cell)
				check(game.door_open and not game.has_key, "entering door uses key and opens it")
				check("Door open" in game.counter_label.text, "inventory updates after unlocking")
				# An opened door stays traversable; a consumed key never respawns.
				walk(oracle(game.player_cell, game.key_cell, false))
				check(game.door_open and not game.has_key, "revisiting key cannot collect it again")
				game.show_hint()
				check(game.hint_cells == oracle(game.player_cell, game.exit_cell, false).slice(1, 5), "after unlocking hints still lead to exit")
			var route := oracle(game.player_cell, game.exit_cell, false)
			game.show_hint()
			check(game.hint_cells == route.slice(1, mini(route.size(), 5)), "hint leads toward exit")
			walk(route)
			check(game.won and victories == before + 1, "full playable victory emits once")
			check(last_result.game == "maze" and last_result.difficulty == level and last_result.steps == game.steps and last_result.seed == seed_value, "completion payload records result")
			var steps_before: int = game.steps
			game.move_player(Vector2i.LEFT)
			game.show_hint()
			check(victories == before + 1 and game.steps == steps_before and game.hint_cells.is_empty(), "won state ignores movement and hints")
			var layout: Array = game.passages.duplicate()
			var door: Vector2i = game.door_cell
			var key: Vector2i = game.key_cell
			game.restart()
			check(game.passages == layout and game.door_cell == door and game.key_cell == key, "restart preserves puzzle")
			check(not game.won and not game.has_key and not game.door_open and game.steps == 0 and game.hints_used == 0 and game.player_cell == Vector2i.ZERO, "restart resets play")
			game.new_maze(seed_value)
			check(game.passages == layout and game.key_cell == key and game.door_cell == door, "seed reproduces puzzle")
	check(fingerprints.size() == 120, "all 120 seeded mazes distinct")
	game.change_difficulty(1)
	game.new_maze(40)
	# Approach the locked door without touching the key, where necessary set player
	# at the neighboring cell to isolate collision from collection.
	var route := oracle(Vector2i.ZERO, game.door_cell, false)
	game.player_cell = route[route.size() - 2]
	var previous: Vector2i = game.player_cell
	game.move_player(game.door_cell - previous)
	check(game.player_cell == previous and game.steps == 0 and not game.has_key, "locked door denies entry")
	game.has_key = true
	game.move_player(game.door_cell - previous)
	check(game.player_cell == game.door_cell and game.steps == 1 and game.door_open and not game.has_key, "key opens door on entry and is consumed")
	game.restart()
	game.move_player(Vector2i.UP)
	game.move_player(Vector2i(-1, -1))
	game.move_player(Vector2i.ZERO)
	check(game.player_cell == Vector2i.ZERO and game.steps == 0, "wall and invalid moves ignored")
	# Every wall, not only the outside boundary, must reject movement.
	for y in range(game.dimensions.y):
		for x in range(game.dimensions.x):
			var cell := Vector2i(x, y)
			for i in range(4):
				if game.passages[game.index_of(cell)] & (1 << i): continue
				game.player_cell = cell
				game.move_player(game.DIRECTIONS[i])
				check(game.player_cell == cell, "interior walls reject movement")
	game.restart()
	var next: Vector2i = game.neighbors(Vector2i.ZERO, false)[0]
	var direction_index: int = game.DIRECTIONS.find(next)
	game.new_button.grab_focus()
	await keypress([KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT][direction_index])
	check(game.player_cell == next and game.steps == 1, "arrow key moves even while toolbar focused")
	await keypress([KEY_S, KEY_A, KEY_W, KEY_D][direction_index])
	check(game.player_cell == Vector2i.ZERO and game.steps == 2, "WASD reverses movement")
	game.movement_buttons[direction_index].pressed.emit()
	check(game.player_cell == next and game.steps == 3, "on-screen direction button moves")
	game.hint_button.pressed.emit()
	check(not game.hint_cells.is_empty(), "hint button works")
	game.restart_button.pressed.emit()
	check(game.steps == 0 and game.player_cell == Vector2i.ZERO, "start over button works")
	var original: Array = game.passages.duplicate()
	game.new_button.pressed.emit()
	check(game.passages != original, "new maze button generates another maze")
	game.difficulty_buttons[2].pressed.emit()
	check(game.difficulty == 2 and game.dimensions == Vector2i(15,9) and game.difficulty_buttons[2].button_pressed, "difficulty button resets and highlights selected level")
	var original_level: int = game.difficulty
	game.change_difficulty(-1)
	game.change_difficulty(9)
	check(game.difficulty == original_level, "invalid difficulties ignored")
	var backs := [0]
	game.back_requested.connect(func(): backs[0] += 1)
	game.back_button.pressed.emit()
	check(backs[0] == 1, "back button emits navigation")
	game.queue_free()
	await process_frame
	print("MAZE TESTS: %d checks, 120 solved mazes, %d failure(s)" % [checks, failures])
	quit(1 if failures else 0)
