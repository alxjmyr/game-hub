extends Control
## A self-contained, keyboard-accessible memory game. No clock and no penalties.
signal back_requested
signal completed(data: Dictionary)

const INK = Color("23364b")
const TEAL = Color("197f80")
const CREAM = Color("fffaf0")
const PAIR_COUNTS = [6, 10, 15]
const WORDS = ["SUN", "MOON", "STAR", "LEAF", "WAVE", "GEM", "BOLT", "FLOWER", "MOUNTAIN", "PLANET", "HEART", "KITE", "TREE", "CLOUD", "TARGET"]
const COLORS = [Color("e9a334"), Color("7362a5"), Color("d46c57"), Color("4b9369"), Color("368cb0"), Color("9162a5"), Color("cd8541"), Color("bf6682"), Color("547e88"), Color("7a71b2"), Color("c85d66"), Color("3d9892"), Color("658545"), Color("618fac"), Color("af7653")]

class MemoryCard extends Button:
	var symbol: int = 0
	var revealed := false
	var found := false
	func _draw() -> void:
		var center := size * Vector2(0.5, 0.34)
		var radius: float = minf(size.x * 0.15, size.y * 0.18)
		# Draw the caption in its own lower band, independent of Button's text centering.
		var caption: String = WORDS[symbol] if revealed or found else "?"
		var font := get_theme_font("font")
		var caption_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, Vector2((size.x - caption_width) / 2, size.y * 0.82), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK if revealed or found else CREAM)
		if not revealed and not found:
			for x in range(-1, 2):
				for y in range(-1, 2):
					draw_circle(center + Vector2(x, y) * radius * 0.7, 2.3, Color("74aaa7"))
			return
		var color: Color = COLORS[symbol]
		match symbol:
			0:
				draw_circle(center, radius * 0.65, color)
				for i in range(8):
					var direction := Vector2.from_angle(i * TAU / 8)
					draw_line(center + direction * radius * 0.85, center + direction * radius * 1.16, color, 3.0, true)
			1:
				var points := PackedVector2Array()
				for i in range(32):
					var angle: float = -PI / 2 + i * TAU / 32
					points.append(center + Vector2.from_angle(angle) * radius)
				draw_colored_polygon(points, color)
				draw_circle(center + Vector2(radius * 0.45, -radius * 0.2), radius * 0.8, CREAM)
			2:
				var points := PackedVector2Array()
				for i in range(10):
					points.append(center + Vector2.from_angle(-PI / 2 + i * TAU / 10) * radius * (1.0 if i % 2 == 0 else 0.45))
				draw_colored_polygon(points, color)
			3:
				draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)
				draw_line(center + Vector2(0, radius * 0.65), center + Vector2(0, -radius * 0.65), CREAM, 2.0, true)
			4:
				for row in range(3):
					var points := PackedVector2Array()
					for i in range(21):
						var x: float = -radius + 2 * radius * i / 20
						points.append(center + Vector2(x, sin(float(i) / 20 * TAU) * radius * 0.2 + (row - 1) * radius * 0.6))
					draw_polyline(points, color, 3.0, true)
			5: # Gem
				draw_colored_polygon(PackedVector2Array([center + Vector2(-radius, -radius * 0.35), center + Vector2(-radius * 0.5, -radius), center + Vector2(radius * 0.5, -radius), center + Vector2(radius, -radius * 0.35), center + Vector2(0, radius)]), color)
				draw_line(center + Vector2(-radius, -radius * 0.35), center + Vector2(radius, -radius * 0.35), CREAM, 2, true)
				draw_line(center + Vector2(0, radius), center + Vector2(-radius * 0.4, -radius * 0.35), CREAM, 2, true)
			6: # Lightning
				draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(-radius * 0.7, radius * 0.15), center + Vector2(-radius * 0.1, radius * 0.15), center + Vector2(-radius * 0.25, radius), center + Vector2(radius * 0.8, -radius * 0.2), center + Vector2(radius * 0.15, -radius * 0.2)]), color)
			7: # Flower
				for i in range(6):
					draw_circle(center + Vector2.from_angle(i * TAU / 6) * radius * 0.65, radius * 0.4, color)
				draw_circle(center, radius * 0.35, Color("e9a334"))
			8: # Mountain
				draw_colored_polygon(PackedVector2Array([center + Vector2(-radius, radius * 0.8), center + Vector2(0, -radius), center + Vector2(radius, radius * 0.8)]), color)
				draw_colored_polygon(PackedVector2Array([center + Vector2(-radius * 0.3, -radius * 0.45), center + Vector2(0, -radius), center + Vector2(radius * 0.3, -radius * 0.45)]), CREAM)
			9: # Planet
				draw_circle(center, radius * 0.7, color)
				var ring := PackedVector2Array()
				for i in range(33):
					var angle: float = i * TAU / 32
					ring.append(center + Vector2(cos(angle) * radius * 1.2, sin(angle) * radius * 0.35).rotated(-0.3))
				draw_polyline(ring, color.lightened(0.2), 3, true)
			10: # Heart
				draw_circle(center + Vector2(-radius * 0.4, -radius * 0.3), radius * 0.55, color)
				draw_circle(center + Vector2(radius * 0.4, -radius * 0.3), radius * 0.55, color)
				draw_colored_polygon(PackedVector2Array([center + Vector2(-radius * 0.9, -radius * 0.1), center + Vector2(radius * 0.9, -radius * 0.1), center + Vector2(0, radius)]), color)
			11: # Kite
				draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.65, -radius * 0.2), center + Vector2(0, radius * 0.7), center + Vector2(-radius * 0.65, -radius * 0.2)]), color)
				draw_polyline(PackedVector2Array([center + Vector2(0, radius * 0.7), center + Vector2(radius * 0.3, radius), center + Vector2(0, radius * 1.2)]), color, 2, true)
			12: # Tree
				draw_line(center, center + Vector2(0, radius), Color("94704b"), 5, true)
				draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, radius * 0.4), center + Vector2(-radius, radius * 0.4)]), color)
			13: # Cloud
				draw_circle(center + Vector2(-radius * 0.55, radius * 0.15), radius * 0.5, color)
				draw_circle(center + Vector2(0, -radius * 0.2), radius * 0.7, color)
				draw_circle(center + Vector2(radius * 0.65, radius * 0.15), radius * 0.45, color)
				draw_rect(Rect2(center + Vector2(-radius * 0.55, 0), Vector2(radius * 1.2, radius * 0.6)), color)
			14: # Target
				draw_circle(center, radius, color)
				draw_circle(center, radius * 0.7, CREAM)
				draw_circle(center, radius * 0.4, color)

		if found:
			draw_circle(Vector2(size.x - 16, 16), 8, TEAL)
			draw_line(Vector2(size.x - 20, 16), Vector2(size.x - 17, 19), Color.WHITE, 2)
			draw_line(Vector2(size.x - 17, 19), Vector2(size.x - 12, 13), Color.WHITE, 2)

var pair_count := 6
var deck: Array[int] = []
var cards: Array[MemoryCard] = []
var matched: Array[int] = []
var first_index := -1
var moves := 0
var locked := false
var won := false
var generation := 0
var mismatch_delay := 0.85
var best_scores: Dictionary = {}
var grid: GridContainer
var status_label: Label
var moves_label: Label
var pairs_label: Label
var best_label: Label
var difficulty_buttons: Array[Button] = []
var restart_button: Button
var conceal_timer: Timer
var pending_indices: Array[int] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	conceal_timer = Timer.new()
	conceal_timer.one_shot = true
	conceal_timer.timeout.connect(_conceal_mismatch)
	add_child(conceal_timer)
	start_game(pair_count)

func _style(color: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(16)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	return label

func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 46
	button.pressed.connect(action)
	return button

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	column.add_child(header)
	header.add_child(_button("<  Game shelf", func(): back_requested.emit()))
	var title := _label("Memory Match", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	restart_button = _button("New board", func(): start_game(pair_count))
	header.add_child(restart_button)
	column.add_child(_label("Find the matching pairs. Take your time; every flip is a clue.", 20))
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	column.add_child(toolbar)
	for count in PAIR_COUNTS:
		var button := _button("%d pairs" % count, start_game.bind(count))
		button.toggle_mode = true
		difficulty_buttons.append(button)
		toolbar.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	moves_label = _label("", 20)
	toolbar.add_child(moves_label)
	pairs_label = _label("", 20)
	toolbar.add_child(pairs_label)
	grid = GridContainer.new()
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	status_label = _label("", 22)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size.y = 32
	column.add_child(status_label)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var help_label := _label("Click a card  /  Tab or arrows to move  /  Enter or Space to flip", 16)
	help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(help_label)
	best_label = _label("", 16)
	footer.add_child(best_label)

func start_game(count: int = 6) -> void:
	if not count in PAIR_COUNTS:
		return
	generation += 1
	conceal_timer.stop()
	pending_indices.clear()
	pair_count = count
	moves = 0
	first_index = -1
	locked = false
	won = false
	matched.clear()
	deck.clear()
	cards.clear()
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for symbol in range(count):
		deck.append(symbol)
		deck.append(symbol)
	deck.shuffle()
	grid.columns = 4 if count == 6 else (5 if count == 10 else 6)
	for index in range(deck.size()):
		var card := MemoryCard.new()
		card.symbol = deck[index]
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(70, 80)
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_theme_font_size_override("font_size", 17)
		card.add_theme_stylebox_override("normal", _style(TEAL, TEAL))
		card.add_theme_stylebox_override("hover", _style(Color("258f8e"), Color("82c1b5")))
		card.add_theme_stylebox_override("pressed", _style(Color("166a71"), INK))
		var focus := _style(Color(0, 0, 0, 0), Color("e8a72f"), 4)
		card.add_theme_stylebox_override("focus", focus)
		card.add_theme_color_override("font_color", CREAM)
		card.add_theme_color_override("font_hover_color", CREAM)
		card.add_theme_color_override("font_pressed_color", CREAM)
		card.text = ""
		# Native tooltip windows trigger Godot #89657 in release builds.
		# Keep descriptive screen-reader labels without creating popup windows.
		card.accessibility_name = "Hidden card %d" % (index + 1)
		card.pressed.connect(select_card.bind(index))
		grid.add_child(card)
		cards.append(card)
	for index in range(difficulty_buttons.size()):
		difficulty_buttons[index].set_pressed_no_signal(PAIR_COUNTS[index] == count)
	status_label.text = "Pick two cards. Can you remember what you discover?"
	_update_scores()

func select_card(index: int) -> void:
	if locked or won or index < 0 or index >= cards.size() or index in matched or index == first_index:
		return
	_reveal(index, true)
	if first_index == -1:
		first_index = index
		status_label.text = "Now find its partner."
		return
	moves += 1
	var previous := first_index
	first_index = -1
	if deck[previous] == deck[index]:
		matched.append(previous)
		matched.append(index)
		for found_index in [previous, index]:
			cards[found_index].found = true
			cards[found_index].queue_redraw()
		status_label.text = "A match! Keep exploring."
		if matched.size() == deck.size():
			won = true
			var key := str(pair_count)
			var old_best: int = int(best_scores.get(key, 0))
			if old_best == 0 or moves < old_best:
				best_scores[key] = moves
			status_label.text = "All pairs found in %d moves! Try a new board or a bigger challenge." % moves
			completed.emit({"game": "memory", "pairs": pair_count, "moves": moves})
		_update_scores()
	else:
		locked = true
		status_label.text = "Two new clues. Remember where they are!"
		_update_scores()
		pending_indices.assign([previous, index])
		conceal_timer.start(mismatch_delay)

func _conceal_mismatch() -> void:
	for index in pending_indices:
		_reveal(index, false)
	pending_indices.clear()
	locked = false
	status_label.text = "Try another pair. You've got this."

func _reveal(index: int, reveal: bool) -> void:
	var card := cards[index]
	card.revealed = reveal
	card.text = ""
	card.accessibility_name = WORDS[card.symbol] if reveal else "Hidden card %d" % (index + 1)
	card.add_theme_stylebox_override("normal", _style(CREAM if reveal else TEAL, Color("d4e2d9") if reveal else TEAL))
	card.add_theme_stylebox_override("hover", _style(Color("f4f1df") if reveal else Color("258f8e"), Color("82c1b5")))
	card.add_theme_color_override("font_color", INK if reveal else CREAM)
	card.add_theme_color_override("font_hover_color", INK if reveal else CREAM)
	card.queue_redraw()

func _update_scores() -> void:
	moves_label.text = "Moves  %d    " % moves
	pairs_label.text = "Pairs  %d / %d" % [matched.size() / 2, pair_count]
	var best: int = int(best_scores.get(str(pair_count), 0))
	best_label.text = "Personal best: %d moves" % best if best > 0 else "Your first adventure!"

func _exit_tree() -> void:
	generation += 1
	if is_instance_valid(conceal_timer):
		conceal_timer.stop()
