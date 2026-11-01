extends Control
## Square-cut picture puzzles, with mouse dragging and a complete keyboard route.
signal back_requested
signal completed(data: Dictionary)

const INK = Color("24364b")
const TEAL = Color("167d8d")
const GRID_SIZES = [3, 4, 5]
const BOARD_ORIGIN = Vector2(30, 45)
const TRAY_ORIGIN = Vector2(550, 45)
const PICTURE_SIZE = 450.0
var difficulty := 0
var grid_size := 3
var pieces: Array = []
var selected := 0
var cursor := Vector2i.ZERO
var drag_index := -1
var drag_offset := Vector2.ZERO
var placed_count := 0
var attempts := 0
var hints_used := 0
var hint_visible := false
var won := false
var picture_index := 0
var texture: ImageTexture
var canvas: PuzzleCanvas
var area: Control
var status_label: Label
var instructions: Label
var difficulty_buttons: Array[Button] = []
var back_button: Button
var rotate_button: Button
var rng := RandomNumberGenerator.new()

class PuzzleCanvas extends Control:
	var game: Control
	func _draw() -> void:
		game.draw_puzzle(self)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			grab_focus()
			game.begin_drag(event.position)
			accept_event()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	back_button = make_button("← Shelf", func(): back_requested.emit())
	top.add_child(back_button)
	var heading := make_label("Jigsaw Studio", 30)
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(heading)
	var group := ButtonGroup.new()
	for i in 3:
		var button := make_button(["9 pieces", "16 pieces", "25 + rotate"][i], change_difficulty.bind(i))
		button.toggle_mode = true
		button.button_group = group
		top.add_child(button)
		difficulty_buttons.append(button)
	instructions = make_label("Drag a piece onto its place in the picture. Correct pieces stay put.", 18)
	column.add_child(instructions)
	area = Control.new()
	area.size_flags_vertical = SIZE_EXPAND_FILL
	area.custom_minimum_size.y = 300
	column.add_child(area)
	canvas = PuzzleCanvas.new()
	canvas.game = self
	canvas.size = Vector2(1040, 525)
	canvas.focus_mode = FOCUS_ALL
	canvas.accessibility_name = "Picture puzzle. N selects next piece, arrows choose a square, Enter places, Q or E rotates."
	area.add_child(canvas)
	area.resized.connect(_fit_canvas)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	controls.add_child(make_button("New picture", new_picture))
	controls.add_child(make_button("Restart", restart))
	controls.add_child(make_button("Next piece [N]", next_piece))
	rotate_button = make_button("Rotate [E]", rotate_selected)
	controls.add_child(rotate_button)
	controls.add_child(make_button("Hint", show_hint))
	status_label = make_label("", 19)
	column.add_child(status_label)
	column.add_child(make_label("Keyboard: N picks a piece · Arrows choose a square · Enter places · Q / E rotate", 17))
	new_puzzle()
	_fit_canvas.call_deferred()

func make_label(value: String, font_size: int) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", INK)
	return result

func make_button(value: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.add_theme_font_size_override("font_size", 17)
	result.add_theme_color_override("font_hover_pressed_color", INK)
	result.pressed.connect(action)
	return result

func _fit_canvas() -> void:
	var factor := minf(area.size.x / 1040.0, area.size.y / 525.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (area.size - canvas.size * factor) / 2

func change_difficulty(index: int) -> void:
	if index < 0 or index >= GRID_SIZES.size(): return
	difficulty = index
	new_puzzle()

func new_picture() -> void:
	picture_index = (picture_index + 1) % 3
	new_puzzle()

func restart() -> void:
	new_puzzle()

func new_puzzle(seed_value: int = -1) -> void:
	if seed_value < 0: rng.randomize()
	else: rng.seed = seed_value
	grid_size = GRID_SIZES[difficulty]
	pieces.clear()
	placed_count = 0
	attempts = 0
	hints_used = 0
	hint_visible = false
	won = false
	drag_index = -1
	cursor = Vector2i.ZERO
	selected = 0
	texture = make_picture(picture_index)
	var order: Array[int] = []
	for i in grid_size * grid_size: order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := order[i]
		order[i] = order[j]
		order[j] = temp
	for i in grid_size * grid_size:
		var slot := order[i]
		pieces.append({"position": TRAY_ORIGIN + Vector2(slot % grid_size, slot / grid_size) * (tile_size() + 6), "turns": rng.randi_range(0, 3) if difficulty == 2 else 0, "placed": false})
	for i in difficulty_buttons.size(): difficulty_buttons[i].set_pressed_no_signal(i == difficulty)
	rotate_button.disabled = difficulty != 2
	_update_status()
	canvas.queue_redraw()

func tile_size() -> float:
	return PICTURE_SIZE / grid_size

func target_position(index: int) -> Vector2:
	return BOARD_ORIGIN + Vector2(index % grid_size, index / grid_size) * tile_size()

func select_piece(index: int) -> void:
	if index < 0 or index >= pieces.size() or pieces[index].placed or won: return
	selected = index
	hint_visible = false
	canvas.queue_redraw()

func next_piece() -> void:
	if won: return
	for step in range(1, pieces.size() + 1):
		var index := (selected + step) % pieces.size()
		if not pieces[index].placed:
			select_piece(index)
			canvas.grab_focus()
			return

func rotate_selected(direction: int = 1) -> void:
	if won or difficulty != 2 or selected < 0 or pieces[selected].placed: return
	pieces[selected].turns = posmod(int(pieces[selected].turns) + direction, 4)
	canvas.queue_redraw()

func show_hint() -> void:
	if won: return
	if pieces[selected].placed: next_piece()
	hints_used += 1
	hint_visible = true
	status_label.text = "Try the glowing square: row %d, column %d. Picture upright?" % [selected / grid_size + 1, selected % grid_size + 1]
	canvas.queue_redraw()

func begin_drag(point: Vector2) -> void:
	if won: return
	var order: Array[int] = []
	for i in pieces.size(): order.append(i)
	order.erase(selected)
	order.append(selected)
	order.reverse()
	for index in order:
		if not pieces[index].placed and Rect2(pieces[index].position, Vector2.ONE * tile_size()).has_point(point):
			select_piece(index)
			drag_index = index
			drag_offset = point - pieces[index].position
			return

func attempt_drop(index: int, point: Vector2) -> bool:
	if won or index < 0 or index >= pieces.size() or pieces[index].placed: return false
	attempts += 1
	if point.distance_to(target_position(index)) <= tile_size() * 0.3 and pieces[index].turns == 0:
		pieces[index].position = target_position(index)
		pieces[index].placed = true
		placed_count += 1
		hint_visible = false
		if placed_count == pieces.size():
			won = true
			completed.emit({"difficulty": difficulty, "pieces": pieces.size(), "attempts": attempts, "hints": hints_used})
		_update_status()
		canvas.queue_redraw()
		return true
	pieces[index].position = point.clamp(Vector2.ZERO, canvas.size - Vector2.ONE * tile_size())
	status_label.text = "Keep experimenting — try another square or turn the piece.  %d / %d placed" % [placed_count, pieces.size()]
	canvas.queue_redraw()
	return false

func place_selected_at(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size or cell.y >= grid_size: return false
	return attempt_drop(selected, BOARD_ORIGIN + Vector2(cell) * tile_size())

func _input(event: InputEvent) -> void:
	if drag_index >= 0:
		if event is InputEventMouseMotion:
			pieces[drag_index].position = (canvas.get_local_mouse_position() - drag_offset).clamp(Vector2.ZERO, canvas.size - Vector2.ONE * tile_size())
			canvas.queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			attempt_drop(drag_index, canvas.get_local_mouse_position() - drag_offset)
			drag_index = -1
			get_viewport().set_input_as_handled()
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
	match event.keycode:
		KEY_N: next_piece()
		KEY_Q: rotate_selected(-1)
		KEY_E: rotate_selected()
		KEY_LEFT: cursor.x = maxi(0, cursor.x - 1)
		KEY_RIGHT: cursor.x = mini(grid_size - 1, cursor.x + 1)
		KEY_UP: cursor.y = maxi(0, cursor.y - 1)
		KEY_DOWN: cursor.y = mini(grid_size - 1, cursor.y + 1)
		KEY_ENTER, KEY_KP_ENTER:
			if not canvas.has_focus(): return
			if place_selected_at(cursor) and not won: next_piece()
		_: return
	canvas.queue_redraw()
	get_viewport().set_input_as_handled()

func _update_status() -> void:
	status_label.text = "Picture complete! Beautiful work. Choose New picture to explore another scene." if won else "%d / %d pieces placed · No rush. Follow the colors and shapes." % [placed_count, pieces.size()]

func draw_puzzle(surface: Control) -> void:
	var font := ThemeDB.fallback_font
	surface.draw_string(font, Vector2(30, 27), "BUILD YOUR PICTURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEAL)
	surface.draw_string(font, Vector2(550, 27), "PIECE TRAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, TEAL)
	surface.draw_rect(Rect2(BOARD_ORIGIN, Vector2.ONE * PICTURE_SIZE), Color("dce5de"))
	if difficulty == 0 and not won:
		surface.draw_texture_rect(texture, Rect2(BOARD_ORIGIN, Vector2.ONE * PICTURE_SIZE), false, Color(1, 1, 1, 0.23))
	for y in grid_size:
		for x in grid_size:
			surface.draw_rect(Rect2(BOARD_ORIGIN + Vector2(x, y) * tile_size(), Vector2.ONE * tile_size()), Color("9bb6b1"), false, 1)
	var order: Array[int] = []
	for i in pieces.size(): order.append(i)
	order.erase(selected)
	order.append(selected)
	for i in order:
		var p: Vector2 = pieces[i].position
		var side := tile_size()
		surface.draw_set_transform(p + Vector2.ONE * side / 2, pieces[i].turns * PI / 2)
		var source := Rect2(Vector2(i % grid_size, i / grid_size) * side, Vector2.ONE * side)
		surface.draw_texture_rect_region(texture, Rect2(-Vector2.ONE * side / 2, Vector2.ONE * side), source)
		surface.draw_rect(Rect2(-Vector2.ONE * side / 2, Vector2.ONE * side), Color("fffaf0"), false, 1)
		surface.draw_set_transform(Vector2.ZERO)
		if i == selected and not pieces[i].placed:
			surface.draw_rect(Rect2(p, Vector2.ONE * side).grow(2), Color("da704a"), false, 4)
	if not won:
		surface.draw_rect(Rect2(BOARD_ORIGIN + Vector2(cursor) * tile_size(), Vector2.ONE * tile_size()).grow(-5), TEAL, false, 3)
		if hint_visible:
			surface.draw_rect(Rect2(target_position(selected), Vector2.ONE * tile_size()).grow(-9), Color("f1ad26"), false, 6)

func make_picture(index: int) -> ImageTexture:
	# Bundled vector art is rasterized locally once per puzzle; no external assets.
	var skies := ["#91cfdf", "#d7b6df", "#f4c799"]
	var hills := ["#719f68", "#718ab1", "#9aab56"]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="450" height="450" viewBox="0 0 450 450"><rect width="450" height="450" fill="%s"/><path d="M192 34 L207 44 L224 30" fill="none" stroke="#4c91a9" stroke-width="4"/><circle cx="365" cy="66" r="40" fill="#ffdb6d"/><path d="M0 235 L105 72 L225 240 L320 125 L450 238 V450 H0Z" fill="#597f99"/><path d="M57 146 L105 72 L158 147 L126 137 L104 155 L86 137Z" fill="#faf6e9"/><path d="M0 255 Q120 173 240 265 T450 230 V450 H0Z" fill="%s"/><path d="M450 285 Q230 240 245 335 T100 450 H260 Q365 363 300 316 T450 305Z" fill="#62bad1"/><rect x="56" y="255" width="108" height="85" rx="3" fill="#f4cd88"/><path d="M38 256 L110 197 L183 256Z" fill="#ce6d58"/><rect x="95" y="286" width="28" height="54" fill="#785c69"/><rect x="65" y="272" width="22" height="25" fill="#91cfdf"/><rect x="133" y="272" width="22" height="25" fill="#91cfdf"/><path d="M58 339 L160 339 L224 450 H10Z" fill="#e5c797"/><rect x="364" y="273" width="15" height="98" fill="#84624e"/><circle cx="367" cy="260" r="46" fill="#326d59"/><circle cx="344" cy="246" r="31" fill="#438362"/><circle cx="385" cy="239" r="31" fill="#4d9268"/><path d="M14 90 Q40 68 64 92 M159 48 Q177 32 194 49" fill="none" stroke="#fffaf0" stroke-width="9" stroke-linecap="round"/><path d="M284 48 L310 79 L286 110 L263 79Z" fill="#d76669"/><path d="M286 110 Q320 142 280 169" fill="none" stroke="#735473" stroke-width="3"/><circle cx="35" cy="391" r="10" fill="#e37981"/><circle cx="183" cy="374" r="11" fill="#f6d965"/><circle cx="406" cy="403" r="12" fill="#e58d9f"/><circle cx="324" cy="425" r="9" fill="#f6d965"/><path d="M35 402 V429 M183 385 V413 M406 415 V443 M324 434 V450" stroke="#376d51" stroke-width="4"/></svg>' % [skies[index], hills[index]]
	if index == 1:
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="450" height="450"><rect width="450" height="450" fill="#26395e"/><path d="M0 400 Q130 260 450 335 V450 H0Z" fill="#8d86a6"/><circle cx="342" cy="99" r="62" fill="#e9ac6e"/><ellipse cx="342" cy="99" rx="99" ry="23" fill="none" stroke="#f2d4a5" stroke-width="12" transform="rotate(-24 342 99)"/><circle cx="82" cy="84" r="38" fill="#8dd0cf"/><circle cx="70" cy="73" r="10" fill="#5ea4af"/><circle cx="94" cy="98" r="15" fill="#5ea4af"/><path d="M180 255 Q139 143 203 99 Q269 160 228 255Z" fill="#f7eee0"/><path d="M180 254 L159 285 L165 220 M228 254 L252 281 L244 218" fill="#d87772"/><circle cx="204" cy="180" r="22" fill="#67b6d0"/><circle cx="204" cy="180" r="27" fill="none" stroke="#7386ab" stroke-width="7"/><path d="M184 258 L205 319 L224 258Z" fill="#f3be5b"/><path d="M197 257 L204 293 L212 257Z" fill="#fff0ae"/><ellipse cx="97" cy="387" rx="46" ry="17" fill="#6d6a88"/><ellipse cx="342" cy="400" rx="64" ry="23" fill="#6d6a88"/><ellipse cx="246" cy="352" rx="25" ry="10" fill="#6d6a88"/><path d="M32 197 h24 M44 185 v24 M359 246 h28 M373 232 v28 M140 40 h18 M149 31 v18 M281 205 h18 M290 196 v18" stroke="#f8dfa0" stroke-width="4"/><circle cx="29" cy="28" r="3" fill="#fff4d9"/><circle cx="245" cy="35" r="5" fill="#fff4d9"/><circle cx="415" cy="208" r="4" fill="#fff4d9"/><circle cx="95" cy="270" r="5" fill="#fff4d9"/><circle cx="295" cy="280" r="3" fill="#fff4d9"/><circle cx="422" cy="37" r="3" fill="#fff4d9"/><circle cx="132" cy="179" r="4" fill="#fff4d9"/><circle cx="21" cy="320" r="4" fill="#fff4d9"/></svg>'
	elif index == 2:
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="450" height="450"><rect width="450" height="450" fill="#5eb2c4"/><path d="M0 72 Q70 35 140 72 T280 72 T450 72 M0 190 Q70 153 140 190 T280 190 T450 190 M0 296 Q70 259 140 296 T280 296 T450 296" fill="none" stroke="#78c5d1" stroke-width="13"/><path d="M0 405 Q160 360 450 393 V450 H0Z" fill="#e8cc94"/><ellipse cx="154" cy="151" rx="69" ry="42" fill="#eea35e"/><path d="M209 150 L262 108 L262 194Z" fill="#e57863"/><circle cx="118" cy="140" r="8" fill="#26395e"/><path d="M145 112 Q125 152 145 190 M170 112 Q150 152 170 190" fill="none" stroke="#fff1d1" stroke-width="10"/><ellipse cx="322" cy="276" rx="50" ry="30" fill="#e3c86f"/><path d="M280 274 L244 241 L244 306Z" fill="#cf9974"/><circle cx="345" cy="268" r="6" fill="#26395e"/><path d="M35 419 Q78 349 38 294 Q15 253 55 225 M71 420 Q115 358 85 326" fill="none" stroke="#3e8277" stroke-width="15"/><path d="M387 422 V345 M387 382 L354 350 M387 370 L420 332 M367 363 V333 M408 345 V317" stroke="#cf7a82" stroke-width="13" stroke-linecap="round"/><path d="M180 390 L189 408 L211 411 L195 425 L198 446 L180 435 L160 446 L163 425 L148 410 L171 407Z" fill="#db8b6a"/><circle cx="65" cy="90" r="13" fill="none" stroke="#c2e7df" stroke-width="4"/><circle cx="83" cy="44" r="8" fill="none" stroke="#c2e7df" stroke-width="3"/><circle cx="344" cy="210" r="10" fill="none" stroke="#c2e7df" stroke-width="3"/><circle cx="363" cy="166" r="16" fill="none" stroke="#c2e7df" stroke-width="4"/><circle cx="335" cy="40" r="9" fill="none" stroke="#c2e7df" stroke-width="3"/><circle cx="190" cy="310" r="12" fill="none" stroke="#c2e7df" stroke-width="3"/><circle cx="177" cy="260" r="7" fill="none" stroke="#c2e7df" stroke-width="3"/></svg>'
	var picture := Image.new()
	picture.load_svg_from_string(svg)
	return ImageTexture.create_from_image(picture)
