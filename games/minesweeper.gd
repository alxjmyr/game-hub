extends MarginContainer

signal back_requested
signal completed(result: Dictionary)

const SIDE := 9
const MINES := 10
const TEAL := Color("167d8d")
const INK := Color("24364b")

var mines: Dictionary[int, bool] = {}
var flags: Dictionary[int, bool] = {}
var opened: Dictionary[int, bool] = {}
var won := false
var hit := -1
var cells: Array[Button] = []
var back_button := Button.new()
var new_button := Button.new()
var flag_mode := CheckButton.new()
var status := Label.new()
var counter := Label.new()

func caption(parent: Control, words: String, font_size: int) -> Label:
	var item := Label.new()
	item.text = words
	item.add_theme_font_size_override("font_size", font_size)
	parent.add_child(item)
	return item

func _ready() -> void:
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 32)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	back_button.text = "<  Game shelf"
	header.add_child(back_button)
	back_button.pressed.connect(func(): back_requested.emit())
	var title := caption(header, "Minesweeper", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(new_button)
	new_button.text = "New board"
	new_button.pressed.connect(start_game)
	var center := CenterContainer.new()
	center.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(center)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 40)
	center.add_child(body)
	var grid := GridContainer.new()
	grid.columns = SIDE
	grid.size_flags_vertical = SIZE_SHRINK_CENTER
	var tile_theme := Theme.new()
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE if state == "normal" else Color("e0edeb")
		style.set_corner_radius_all(5)
		style.border_width_bottom = 2
		style.border_color = Color("aebfbd")
		tile_theme.set_stylebox(state, "Button", style)
	grid.theme = tile_theme
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	body.add_child(grid)
	for i in SIDE * SIDE:
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(52, 52)
		cell.add_theme_font_size_override("font_size", 25)
		cell.pressed.connect(activate.bind(i))
		cell.gui_input.connect(cell_input.bind(i))
		grid.add_child(cell)
		cells.append(cell)
	var guide := VBoxContainer.new()
	guide.custom_minimum_size.x = 320
	guide.alignment = BoxContainer.ALIGNMENT_CENTER
	guide.add_theme_constant_override("separation", 18)
	body.add_child(guide)
	guide.add_child(counter)
	counter.add_theme_color_override("font_color", TEAL)
	caption(guide, "Read the clues", 30)
	var rules := caption(guide, "Open every safe square. Each number counts the mines touching it, even diagonally. A blank opens the safe ground around it.", 20)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_child(flag_mode)
	flag_mode.text = "Flag mode"
	var controls := caption(guide, "Click to open. Right-click or press F to flag. Flag mode lets you flag with a click.\n\nUse arrows to move and Enter or Space to open. Open a number again once its flags are in place to clear its neighbors.", 17)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_game()

func start_game() -> void:
	mines.clear()
	flags.clear()
	opened.clear()
	won = false
	hit = -1
	flag_mode.set_pressed_no_signal(false)
	status.text = "Choose any square. Your first opening is safe."
	refresh()
	cells[0].grab_focus()

func neighbors(index: int) -> Array[int]:
	var result: Array[int] = []
	var x := index % SIDE
	var y := floori(float(index) / SIDE)
	for row in range(maxi(0, y - 1), mini(SIDE, y + 2)):
		for col in range(maxi(0, x - 1), mini(SIDE, x + 2)):
			var other := row * SIDE + col
			if other != index:
				result.append(other)
	return result

func place_mines(first: int) -> void:
	var safe := neighbors(first)
	safe.append(first)
	var candidates: Array[int] = []
	for i in cells.size():
		if i not in safe:
			candidates.append(i)
	candidates.shuffle()
	for i in MINES:
		mines[candidates[i]] = true

func adjacent_count(index: int, marks: Dictionary) -> int:
	var count := 0
	for other in neighbors(index):
		if other in marks:
			count += 1
	return count

func cell_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cells[index].grab_focus()
	elif not (event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo):
		return
	toggle_flag(index)
	cells[index].accept_event()

func toggle_flag(index: int) -> void:
	if won or hit >= 0 or index in opened:
		return
	if index in flags:
		flags.erase(index)
	else:
		flags[index] = true
	refresh()

func activate(index: int) -> void:
	if flag_mode.button_pressed:
		toggle_flag(index)
	else:
		reveal(index)

func reveal(index: int) -> void:
	if won or hit >= 0 or index in flags:
		return
	if mines.is_empty():
		place_mines(index)
	var pending: Array[int] = [index]
	if index in opened:
		if adjacent_count(index, flags) != adjacent_count(index, mines):
			return
		pending = neighbors(index)
	while not pending.is_empty():
		var next: int = pending.pop_back()
		if next in flags or next in opened:
			continue
		if next in mines:
			hit = next
			break
		opened[next] = true
		if adjacent_count(next, mines) == 0:
			pending.append_array(neighbors(next))
	won = hit < 0 and opened.size() == cells.size() - MINES
	if hit >= 0:
		status.text = "You hit a mine. Choose New board to try again."
	elif won:
		status.text = "Field cleared! You found every safe square."
	else:
		status.text = "Follow the numbers to find the next safe square."
	refresh()
	if won:
		completed.emit({"game": "minesweeper", "mines": MINES, "safe_squares": opened.size()})

func refresh() -> void:
	counter.text = "%d mines   /   %d flags" % [MINES, flags.size()]
	for i in cells.size():
		var cell := cells[i]
		var symbol := ""
		var description := "Covered"
		var color := INK
		if hit >= 0 and i in mines:
			symbol = "✹"
			description = "Mine"
			color = Color("a43324") if i == hit else INK
		elif i in flags:
			symbol = "×" if hit >= 0 else "⚑"
			description = "Misplaced flag" if hit >= 0 else "Flagged"
			color = Color("a43324")
		elif i in opened:
			var count := adjacent_count(i, mines)
			symbol = str(count) if count else ""
			description = "%d adjacent mines" % count
			color = TEAL if count == 1 else INK
		cell.text = symbol
		cell.self_modulate = Color("cce9de") if i in opened else Color.WHITE
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			cell.add_theme_color_override(state, color)
		cell.accessibility_name = "Row %d, column %d. %s" % [1 + floori(float(i) / SIDE), 1 + i % SIDE, description]
