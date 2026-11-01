extends Control
## Perfect mazes: each cell is reachable, and the key is always before its door.
signal back_requested
signal completed(data: Dictionary)

const INK = Color("24364b")
const TEAL = Color("167d8d")
const DIRECTIONS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIMENSIONS = [Vector2i(7, 5), Vector2i(11, 7), Vector2i(15, 9)]
const LEVEL_NAMES = ["Explorer", "Pathfinder", "Trailblazer"]
var difficulty := 0
var dimensions := Vector2i(7, 5)
var passages: Array[int] = []
var player_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var key_cell := Vector2i(-1, -1)
var door_cell := Vector2i(-1, -1)
var has_key := false
var won := false
var steps := 0
var hints_used := 0
var puzzle_seed := 0
var hint_cells: Array[Vector2i] = []
var visited: Array[Vector2i] = []
var board: MazeBoard
var status_label: Label
var counter_label: Label
var difficulty_buttons: Array[Button] = []
var back_button: Button
var restart_button: Button
var new_button: Button
var hint_button: Button
var movement_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	new_maze()

func _label(text: String, font_size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.add_theme_color_override("font_hover_pressed_color", INK)
	button.pressed.connect(action)
	return button

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	back_button = _button("< Game shelf", func(): back_requested.emit())
	header.add_child(back_button)
	var title := _label("Maze Explorer", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	restart_button = _button("Start over", restart)
	header.add_child(restart_button)
	new_button = _button("New maze", new_maze)
	header.add_child(new_button)
	column.add_child(_label("Find the flag. Follow a new trail, or retrace your steps!", 20))
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	var group := ButtonGroup.new()
	for i in range(3):
		var button := _button(LEVEL_NAMES[i], change_difficulty.bind(i))
		button.toggle_mode = true
		button.button_group = group
		difficulty_buttons.append(button)
		toolbar.add_child(button)
	counter_label = _label("")
	counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toolbar.add_child(counter_label)
	board = MazeBoard.new()
	board.game = self
	board.custom_minimum_size = Vector2(400, 240)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(board)
	status_label = _label("", 20)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 48
	column.add_child(status_label)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	for i in range(4):
		var button := _button(["↑", "→", "↓", "←"][i], move_player.bind(DIRECTIONS[i]))
		button.custom_minimum_size.x = 52
		button.accessibility_name = ["Move up", "Move right", "Move down", "Move left"][i]
		movement_buttons.append(button)
		controls.add_child(button)
	hint_button = _button("Show a hint", show_hint)
	controls.add_child(hint_button)
	var help := _label("Arrows or WASD to move · Esc for shelf", 16)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_child(help)

func index_of(cell: Vector2i) -> int:
	return cell.y * dimensions.x + cell.x

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < dimensions.x and cell.y < dimensions.y

func change_difficulty(level: int) -> void:
	if level < 0 or level >= DIMENSIONS.size(): return
	difficulty = level
	new_maze()

func new_maze(seed_value: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value == -1:
		rng.randomize()
		puzzle_seed = rng.randi()
	else:
		puzzle_seed = seed_value
	rng.seed = puzzle_seed
	dimensions = DIMENSIONS[difficulty]
	exit_cell = dimensions - Vector2i.ONE
	passages.clear()
	passages.resize(dimensions.x * dimensions.y)
	passages.fill(0)
	var explored := {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var choices: Array[int] = []
		for i in range(4):
			var next: Vector2i = current + DIRECTIONS[i]
			if in_bounds(next) and not explored.has(next): choices.append(i)
		if choices.is_empty():
			stack.pop_back()
			continue
		var direction: int = choices[rng.randi_range(0, choices.size() - 1)]
		var neighbor: Vector2i = current + DIRECTIONS[direction]
		passages[index_of(current)] |= 1 << direction
		passages[index_of(neighbor)] |= 1 << ((direction + 2) % 4)
		explored[neighbor] = true
		stack.append(neighbor)
	door_cell = Vector2i(-1, -1)
	key_cell = Vector2i(-1, -1)
	if difficulty > 0:
		var solution := find_path(Vector2i.ZERO, exit_cell, true)
		door_cell = solution[clampi(int(solution.size() * 0.65), 2, solution.size() - 2)]
		# BFS with the door blocked finds a distant key on the start side.
		var reachable := {Vector2i.ZERO: true}
		var queue: Array[Vector2i] = [Vector2i.ZERO]
		var head := 0
		while head < queue.size():
			var cell := queue[head]
			head += 1
			for neighbor in neighbors(cell, false):
				if not reachable.has(neighbor):
					reachable[neighbor] = true
					queue.append(neighbor)
		key_cell = queue.back()
	restart()

func restart() -> void:
	player_cell = Vector2i.ZERO
	has_key = false
	won = false
	steps = 0
	hints_used = 0
	hint_cells.clear()
	visited.assign([Vector2i.ZERO])
	for i in range(difficulty_buttons.size()):
		difficulty_buttons[i].set_pressed_no_signal(i == difficulty)
	status_label.text = "Find the golden key to open the striped door, then reach the flag." if difficulty > 0 else "You are the coral explorer. Reach the teal flag!"
	_refresh()

func neighbors(cell: Vector2i, unlocked: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not in_bounds(cell): return result
	for direction in range(4):
		if passages[index_of(cell)] & (1 << direction):
			var next: Vector2i = cell + DIRECTIONS[direction]
			if in_bounds(next) and (unlocked or next != door_cell): result.append(next)
	return result

func find_path(start: Vector2i, target: Vector2i, unlocked: bool = false) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var previous := {start: start}
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		if current == target: break
		for next in neighbors(current, unlocked):
			if not previous.has(next):
				previous[next] = current
				queue.append(next)
	var route: Array[Vector2i] = []
	if not previous.has(target): return route
	var cursor := target
	while cursor != start:
		route.push_front(cursor)
		cursor = previous[cursor]
	route.push_front(start)
	return route

func move_player(direction: Vector2i) -> void:
	if won or not direction in DIRECTIONS: return
	var destination := player_cell + direction
	if not destination in neighbors(player_cell, true):
		status_label.text = "A wall here. Try another way!"
		return
	if destination == door_cell and not has_key:
		status_label.text = "This door needs the golden key. Look for the key first."
		return
	player_cell = destination
	steps += 1
	hint_cells.clear()
	if not destination in visited: visited.append(destination)
	if destination == key_cell and not has_key:
		has_key = true
		status_label.text = "Key found! The striped door is open. Head for the flag."
	else:
		status_label.text = "Keep exploring. Your little dots show where you've been."
	if player_cell == exit_cell:
		won = true
		status_label.text = "You found the flag in %d steps! Try a new maze or a bigger adventure." % steps
		completed.emit({"game": "maze", "difficulty": difficulty, "steps": steps, "hints": hints_used, "seed": puzzle_seed})
	_refresh()

func show_hint() -> void:
	if won: return
	var target := key_cell if difficulty > 0 and not has_key else exit_cell
	var route := find_path(player_cell, target, has_key)
	hint_cells.clear()
	for i in range(1, mini(route.size(), 5)):
		hint_cells.append(route[i])
	hints_used += 1
	status_label.text = "Follow the golden dots toward %s. The hint fades after your next step." % ("the key" if difficulty > 0 and not has_key else "the flag")
	board.queue_redraw()

func _refresh() -> void:
	counter_label.text = "Steps  %d%s" % [steps, "  ·  Key ✓" if has_key else ""]
	for button in movement_buttons: button.disabled = won
	hint_button.disabled = won
	board.queue_redraw()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	var direction := Vector2i.ZERO
	match event.keycode:
		KEY_UP, KEY_W: direction = Vector2i.UP
		KEY_RIGHT, KEY_D: direction = Vector2i.RIGHT
		KEY_DOWN, KEY_S: direction = Vector2i.DOWN
		KEY_LEFT, KEY_A: direction = Vector2i.LEFT
	if direction != Vector2i.ZERO:
		move_player(direction)
		get_viewport().set_input_as_handled()

class MazeBoard extends Control:
	var game: Control
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		if game.passages.is_empty(): return
		var cell_size := minf((size.x - 20) / game.dimensions.x, (size.y - 20) / game.dimensions.y)
		var origin: Vector2 = (size - Vector2(game.dimensions) * cell_size) / 2
		draw_rect(Rect2(origin, Vector2(game.dimensions) * cell_size), Color("fffdf6"))
		for cell in game.visited:
			draw_circle(origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size, cell_size * 0.06, Color("a4beb0"))
		for cell in game.hint_cells:
			draw_circle(origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size, cell_size * 0.13, Color("e6ad37"))
		for y in range(game.dimensions.y):
			for x in range(game.dimensions.x):
				var cell := Vector2i(x, y)
				var p := origin + Vector2(cell) * cell_size
				var walls: int = game.passages[game.index_of(cell)]
				if not walls & 1: draw_line(p, p + Vector2(cell_size, 0), INK, 3, true)
				if not walls & 8: draw_line(p, p + Vector2(0, cell_size), INK, 3, true)
				if y == game.dimensions.y - 1: draw_line(p + Vector2(0, cell_size), p + Vector2.ONE * cell_size, INK, 3, true)
				if x == game.dimensions.x - 1: draw_line(p + Vector2(cell_size, 0), p + Vector2.ONE * cell_size, INK, 3, true)
		var finish: Vector2 = origin + (Vector2(game.exit_cell) + Vector2(0.5, 0.5)) * cell_size
		draw_line(finish + Vector2(-0.18, 0.3) * cell_size, finish + Vector2(-0.18, -0.3) * cell_size, TEAL, 3, true)
		draw_colored_polygon(PackedVector2Array([finish + Vector2(-0.18, -0.3) * cell_size, finish + Vector2(0.3, -0.12) * cell_size, finish + Vector2(-0.18, 0.05) * cell_size]), TEAL)
		if game.difficulty > 0:
			var door: Vector2 = origin + (Vector2(game.door_cell) + Vector2(0.5, 0.5)) * cell_size
			if not game.has_key:
				draw_rect(Rect2(door - Vector2.ONE * cell_size * 0.32, Vector2.ONE * cell_size * 0.64), Color("b97937"))
				for stripe in range(3):
					draw_line(door + Vector2(-0.23 + stripe * 0.23, -0.25) * cell_size, door + Vector2(-0.23 + stripe * 0.23, 0.25) * cell_size, Color("fff1c6"), 2, true)
				var key: Vector2 = origin + (Vector2(game.key_cell) + Vector2(0.5, 0.5)) * cell_size
				draw_arc(key + Vector2(-0.13, -0.12) * cell_size, cell_size * 0.14, 0, TAU, 24, Color("c28b14"), 3, true)
				draw_line(key, key + Vector2(0.27, 0.27) * cell_size, Color("c28b14"), 3, true)
				draw_line(key + Vector2(0.18, 0.18) * cell_size, key + Vector2(0.28, 0.08) * cell_size, Color("c28b14"), 3, true)
		var player: Vector2 = origin + (Vector2(game.player_cell) + Vector2(0.5, 0.5)) * cell_size
		draw_circle(player, cell_size * 0.25, Color("ed805c"))
		draw_circle(player + Vector2(-0.08, -0.04) * cell_size, cell_size * 0.035, INK)
		draw_circle(player + Vector2(0.08, -0.04) * cell_size, cell_size * 0.035, INK)
