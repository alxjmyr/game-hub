extends Control
## A gentle keyboard adventure: collect stars by finding keys and spelling words.
signal back_requested
signal completed(data: Dictionary)

const INK = Color("24364b")
const TEAL = Color("167d8d")
const CREAM = Color("fffaf0")
const WORDS = ["SUN", "MOON", "STAR", "KITE", "FROG", "BIRD", "TREE", "WAVE", "ROBOT", "CLOUD", "PLANET", "ROCKET", "GARDEN", "PUZZLE", "DRAGON", "CASTLE"]
const ROUND_LENGTHS = [12, 16, 8]
var difficulty := 0
var prompts: Array[String] = []
var prompt_index := 0
var typed := ""
var won := false
var hints_enabled := true
var hints_used := false
var correct_keys := 0
var status := "Find the glowing key on your keyboard."
var rng := RandomNumberGenerator.new()
var board: HuntBoard
var status_label: Label
var progress_label: Label
var hint_button: Button
var restart_button: Button
var back_button: Button
var difficulty_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.randomize()
	_build_ui()
	start_round()

func _label(value: String, font_size: int) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", INK)
	return item

func _button(value: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = 46
	item.pressed.connect(action)
	return item

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	back_button = _button("<  Game shelf", func(): back_requested.emit())
	header.add_child(back_button)
	var title := _label("Letter Hunt", 34)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	restart_button = _button("New round", start_round)
	header.add_child(restart_button)
	column.add_child(_label("Collect a constellation, one key at a time. No rush!", 20))
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	column.add_child(toolbar)
	var group := ButtonGroup.new()
	var names := ["Letters", "Letters + numbers", "Words"]
	for i in 3:
		var button := _button(names[i], change_difficulty.bind(i))
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_color_override("font_hover_pressed_color", INK)
		difficulty_buttons.append(button)
		toolbar.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	hint_button = _button("Key hints: on", toggle_hints)
	toolbar.add_child(hint_button)
	progress_label = _label("", 20)
	column.add_child(progress_label)
	board = HuntBoard.new()
	board.game = self
	board.custom_minimum_size = Vector2(0, 360)
	board.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(board)
	status_label = _label("", 20)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)
	column.add_child(_label("Type on your keyboard  •  Backspace: undo a letter  •  Esc: game shelf", 16))

func change_difficulty(index: int) -> void:
	if index < 0 or index > 2: return
	difficulty = index
	start_round()

func start_round(seed_value: int = -1) -> void:
	if seed_value >= 0: rng.seed = seed_value
	prompts.clear()
	var pool: Array[String] = []
	if difficulty == 2:
		pool.assign(WORDS)
	else:
		for character in "ABCDEFGHIJKLMNOPQRSTUVWXYZ": pool.append(character)
		if difficulty == 1:
			for character in "0123456789": pool.append(character)
	# Fisher-Yates with a local RNG, deterministic for verification.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	prompts.assign(pool.slice(0, ROUND_LENGTHS[difficulty]))
	# Always include number practice in the mixed round.
	if difficulty == 1:
		for i in 4: prompts[i * 4] = str(rng.randi_range(i * 2, i * 2 + 1))
	prompt_index = 0
	typed = ""
	won = false
	correct_keys = 0
	hints_used = hints_enabled
	status = "Type the word from left to right." if difficulty == 2 else "Find this key on your keyboard. Uppercase or lowercase both work."
	_refresh()

func current_prompt() -> String:
	return "" if won or prompts.is_empty() else prompts[prompt_index]

func expected_character() -> String:
	var target := current_prompt()
	return "" if target.is_empty() else target.substr(typed.length(), 1)

func toggle_hints() -> void:
	hints_enabled = not hints_enabled
	if hints_enabled: hints_used = true
	_refresh()

func type_character(character: String) -> void:
	if won or character.length() != 1: return
	var normalized := character.to_upper()
	if normalized != expected_character():
		status = "Keep exploring! Look for %s. Your stars are safe." % expected_character()
		_refresh()
		return
	typed += normalized
	correct_keys += 1
	if typed == current_prompt():
		prompt_index += 1
		typed = ""
		if prompt_index == prompts.size():
			won = true
			status = "Constellation complete! Try another round or a new challenge."
			_refresh()
			completed.emit({"difficulty": difficulty, "stars": prompts.size(), "correct_keys": correct_keys, "hints_used": hints_used})
			return
		status = "Star collected! Keep your constellation growing."
	else:
		status = "Great start! Next letter: %s" % expected_character() if hints_enabled else "Great start! Keep spelling."
	_refresh()

func undo_letter() -> void:
	if won: return
	if not typed.is_empty():
		typed = typed.left(typed.length() - 1)
		correct_keys -= 1
		status = "One letter back. You can try it again."
		_refresh()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
	if event.keycode == KEY_BACKSPACE:
		undo_letter()
		get_viewport().set_input_as_handled()
		return
	var character := String.chr(event.unicode) if event.unicode > 0 else ""
	# Logical keycode fallback also supports synthetic input and non-text key events.
	if character.is_empty() and event.keycode >= KEY_A and event.keycode <= KEY_Z:
		character = String.chr(event.keycode)
	if character.is_empty() and event.keycode >= KEY_0 and event.keycode <= KEY_9:
		character = String.chr(event.keycode)
	if character.to_upper() in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" and character.length() == 1:
		type_character(character)
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	if not is_instance_valid(board): return
	for i in difficulty_buttons.size(): difficulty_buttons[i].set_pressed_no_signal(i == difficulty)
	hint_button.text = "Key hints: on" if hints_enabled else "Key hints: off"
	progress_label.text = "%d / %d stars collected" % [prompt_index, prompts.size()]
	status_label.text = status
	board.accessibility_name = "Constellation complete" if won else "Type " + current_prompt()
	board.queue_redraw()

class HuntBoard extends Control:
	var game: Control
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func text_at(text: String, center: Vector2, font_size: int, color: Color) -> void:
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, center - Vector2(width / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	func star(center: Vector2, radius: float, color: Color) -> void:
		var points := PackedVector2Array()
		for i in 10: points.append(center + Vector2.from_angle(-PI / 2 + i * PI / 5) * radius * (1.0 if i % 2 == 0 else 0.45))
		draw_colored_polygon(points, color)
	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("e7edf7")
		bg.set_corner_radius_all(20)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		var total: int = game.prompts.size()
		var spacing: float = minf(52, (size.x - 70) / maxf(total, 1))
		for i in total:
			var center := Vector2(size.x / 2 + (i - (total - 1) / 2.0) * spacing, 40 + sin(i * 1.5) * 9)
			star(center, 14, Color("df9b30") if i < game.prompt_index else Color("becbdd"))
		if game.won:
			star(Vector2(size.x / 2, size.y / 2 - 5), 65, Color("df9b30"))
			text_at("You found every star!", Vector2(size.x / 2, size.y / 2 + 100), 36, INK)
			return
		var target: String = game.current_prompt()
		text_at("SPELL THE WORD" if game.difficulty == 2 else "FIND THIS KEY", Vector2(size.x / 2, 91), 16, TEAL)
		var font_size := 54
		var advance := 47.0
		for i in target.length():
			var x := size.x / 2 + (i - (target.length() - 1) / 2.0) * advance
			text_at(target[i], Vector2(x, 155), font_size, TEAL if i < game.typed.length() else INK)
			if i == game.typed.length(): draw_line(Vector2(x - 17, 164), Vector2(x + 17, 164), Color("df9b30"), 4)
		var rows := ["1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
		var key_size := Vector2(minf(51, (size.x - 100) / 10), 34)
		var keyboard_y := maxf(183, size.y - 178)
		for row in rows.size():
			var keys: String = rows[row]
			for i in keys.length():
				var p := Vector2(size.x / 2 + (i - keys.length() / 2.0) * (key_size.x + 5), keyboard_y + row * 40)
				var active: bool = game.hints_enabled and keys[i] == game.expected_character()
				var key := StyleBoxFlat.new()
				key.bg_color = Color("f4d79b") if active else CREAM
				key.set_corner_radius_all(6)
				if active:
					key.set_border_width_all(2)
					key.border_color = TEAL
				draw_style_box(key, Rect2(p, key_size))
				text_at(keys[i], p + Vector2(key_size.x / 2, 25), 22, INK)
