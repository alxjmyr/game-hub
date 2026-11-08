extends Control
## A child's three-part adventure. All hazards have a safe route around them.
signal back_requested
signal completed(data: Dictionary)

const DIRS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const TITLES = ["The Black Dungeon", "White Castle", "The Three Brown Towers"]
const HEROES = ["Knight", "Princess", "Explorer"]
const KEY_COLORS = [Color("f5c65d"), Color("9ce5f5"), Color("edab79")]
var hero := ""
var level := 0
var area := "dungeon"
var tiles := {}
var player_cell := Vector2i.ZERO
var safe_cell := Vector2i.ZERO
var key_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var guards: Array[Vector2i] = []
var holes: Array[Vector2i] = []
var visited := {}
var has_key := false
var secret_found := false
var exit_found := false
var won := false
var bumps := 0
var awake := 0.0
var hint: Array[Vector2i] = []
var board: AdventureBoard
var title: Label
var status: Label
var key_label: Label
var chooser: VBoxContainer
var play_ui: VBoxContainer
var back_button: Button
var next_button: Button

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	back_button = button("< Game shelf", func(): back_requested.emit())
	header.add_child(back_button)
	var name_label := label("Castle Maze", 34)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	header.add_child(button("Choose hero", choose_again))
	chooser = VBoxContainer.new()
	chooser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(chooser)
	chooser.add_child(label("Three escapes. One brave you.", 28))
	chooser.add_child(label("Find hidden keys, sneak past guards, and reach the courtyard!", 20))
	var portraits := HBoxContainer.new()
	portraits.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chooser.add_child(portraits)
	for character in HEROES:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portraits.add_child(card)
		var portrait := HeroPortrait.new()
		portrait.character = character
		portrait.custom_minimum_size.y = 180
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(portrait)
		card.add_child(button("Play as " + character, start.bind(character)))
	chooser.add_child(label("Everyone can win. Pick your favorite!", 22))
	play_ui = VBoxContainer.new()
	play_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(play_ui)
	title = label("", 26)
	play_ui.add_child(title)
	key_label = label("", 18)
	play_ui.add_child(key_label)
	board = AdventureBoard.new()
	board.game = self
	board.custom_minimum_size = Vector2(400, 250)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_ui.add_child(board)
	status = label("", 20)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 52
	play_ui.add_child(status)
	var controls := HBoxContainer.new()
	play_ui.add_child(controls)
	for i in 4:
		controls.add_child(button(["↑", "→", "↓", "←"][i], move_player.bind(DIRS[i])))
	controls.add_child(button("A little hint", show_hint))
	next_button = button("Next level →", next_level)
	controls.add_child(next_button)
	play_ui.add_child(label("Arrows / WASD to move  •  Walk onto boxes and doors to search  •  Esc: shelf", 16))
	choose_again()

func label(text: String, font_size: int) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	return item

func button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(52, 44)
	item.pressed.connect(action)
	return item

func choose_again() -> void:
	hero = ""
	chooser.show()
	play_ui.hide()

func start(character: String) -> void:
	hero = character
	level = 0
	won = false
	bumps = 0
	chooser.hide()
	play_ui.show()
	load_area("dungeon")

func carve(x: int, y: int, width: int, height: int, kind: String = ".") -> void:
	for row in range(y, y + height):
		for col in range(x, x + width): tiles[Vector2i(col, row)] = kind

func load_area(new_area: String) -> void:
	area = new_area
	tiles.clear()
	guards.clear()
	holes.clear()
	visited.clear()
	hint.clear()
	has_key = false
	secret_found = false
	exit_found = false
	awake = 0
	next_button.hide()
	if area == "dungeon":
		carve(1, 1, 7, 3)
		carve(6, 3, 2, 7)
		carve(1, 6, 7, 2)
		carve(1, 7, 2, 3)
		carve(7, 8, 14, 2)
		carve(10, 1, 2, 8)
		carve(10, 1, 11, 2)
		carve(14, 2, 2, 4)
		carve(19, 2, 2, 5)
		player_cell = Vector2i(1, 1)
		key_cell = Vector2i(1, 9)
		exit_cell = Vector2i(20, 6)
		holes.assign([Vector2i(7, 5), Vector2i(17, 8)])
		guards.assign([Vector2i(5, 1), Vector2i(14, 4)])
		status.text = "Search the wooden box for a key. The exit is hidden in the dungeon walls!"
	elif area == "hall":
		carve(2, 2, 19, 7)
		for x in [7, 13]:
			for y in range(2, 7): tiles.erase(Vector2i(x, y))
		player_cell = Vector2i(3, 3)
		key_cell = Vector2i(-1, -1)
		exit_cell = Vector2i(19, 3)
		guards.assign([Vector2i(10, 3)])
		holes.assign([Vector2i(5, 6), Vector2i(16, 7)])
		status.text = "Find the stairs and go down to the castle basement."
	elif area == "basement":
		carve(1, 2, 10, 7)
		carve(10, 7, 5, 2)
		carve(14, 2, 7, 7)
		carve(11, 2, 3, 2, "secret")
		carve(11, 1, 3, 1, "secret")
		player_cell = Vector2i(2, 7)
		key_cell = Vector2i(12, 1)
		exit_cell = Vector2i(19, 3)
		carve(18, 2, 3, 3, "room")
		for cell in [Vector2i(18, 2), Vector2i(19, 2), Vector2i(20, 2), Vector2i(18, 3), Vector2i(20, 3), Vector2i(20, 4)]: tiles.erase(cell)
		guards.assign([Vector2i(6, 3), Vector2i(16, 6)])
		holes.assign([Vector2i(8, 7), Vector2i(15, 3)])
		status.text = "Look for a crack in the wall. A secret room holds a silver star key!"
	elif area == "towers":
		carve(1, 2, 5, 7)
		carve(9, 2, 5, 7)
		carve(17, 2, 5, 7)
		carve(6, 4, 3, 2, "bridge")
		carve(14, 6, 3, 2, "bridge")
		player_cell = Vector2i(3, 7)
		key_cell = Vector2i(20, 3)
		exit_cell = Vector2i(2, 3)
		guards.assign([Vector2i(11, 3), Vector2i(19, 7)])
		holes.assign([Vector2i(4, 5), Vector2i(10, 7), Vector2i(18, 4)])
		status.text = "Start in the back tower. Cross both rope bridges, then bring the key back here!"
	else:
		carve(2, 2, 19, 7, "garden")
		player_cell = Vector2i(3, 5)
		key_cell = Vector2i(-1, -1)
		exit_cell = Vector2i(19, 5)
		status.text = "Down the stairs... into the courtyard! You escaped all three levels!"
		won = true
		next_button.text = "Play again"
		next_button.show()
		completed.emit({"game": "caste_maze", "hero": hero, "gentle_hops": bumps})
	safe_cell = player_cell
	visited[player_cell] = true
	refresh()

func danger(cell: Vector2i) -> bool:
	if cell in holes: return true
	for guard in guards:
		if absi(cell.x - guard.x) + absi(cell.y - guard.y) <= 1: return true
	return false

func move_player(direction: Vector2i) -> void:
	if hero == "" or won or next_button.visible or direction not in DIRS: return
	var destination := player_cell + direction
	if not tiles.has(destination):
		status.text = "A wall! Turn around and try another path."
		return
	hint.clear()
	if danger(destination):
		bumps += 1
		awake = 1.2
		player_cell = safe_cell
		status.text = ("Whoops, a hole!" if destination in holes else "That guard woke up!") + " Hop back to safety. You keep your key!"
		refresh()
		return
	player_cell = destination
	safe_cell = destination
	visited[destination] = true
	if tiles[destination] == "secret" and not secret_found:
		secret_found = true
		status.text = "You found the secret room! Search its sparkling box."
	if destination == key_cell and not has_key:
		has_key = true
		status.text = ["A golden round key! Now find the hidden exit.", "A silver star key! Find the little room with the locked door.", "A copper diamond key! Return to the trapdoor in the back tower."][level]
	if area == "dungeon" and destination.distance_to(exit_cell) <= 2:
		exit_found = true
	if destination == exit_cell:
		if area == "hall":
			load_area("basement")
			return
		if not has_key:
			status.text = "This door is locked. Find the key first!"
		elif area == "towers":
			load_area("courtyard")
			return
		else:
			status.text = "You unlocked the exit! Ready for the next level?"
			next_button.text = "Next level →"
			next_button.show()
	refresh()

func next_level() -> void:
	if won:
		choose_again()
	elif next_button.visible:
		level += 1
		load_area("hall" if level == 1 else "towers")

func path_to(target: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [player_cell]
	var previous := {player_cell: player_cell}
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell == target: break
		for direction in DIRS:
			var next: Vector2i = cell + direction
			if tiles.has(next) and not danger(next) and not previous.has(next):
				previous[next] = cell
				queue.append(next)
	var route: Array[Vector2i] = []
	if not previous.has(target): return route
	var cursor := target
	while cursor != player_cell:
		route.push_front(cursor)
		cursor = previous[cursor]
	return route

func show_hint() -> void:
	if won or next_button.visible: return
	var target := exit_cell if has_key or area == "hall" else key_cell
	hint.assign(path_to(target).slice(0, 5))
	status.text = "Follow the little golden dots. They go around the dangers!"
	board.queue_redraw()

func refresh() -> void:
	title.text = "%d / 3   %s%s" % [level + 1, TITLES[level], "  •  Basement" if area == "basement" else ""]
	key_label.text = "%s  •  %s  •  Give sleepy guards a little space!" % [hero, "Key found!" if has_key else "Find the key" if area != "hall" else "Find the stairs"]
	if won: key_label.text = hero + "  •  All three escapes complete!"
	board.queue_redraw()

func _process(delta: float) -> void:
	if awake > 0:
		awake = maxf(0, awake - delta)
		board.queue_redraw()

func _input(event: InputEvent) -> void:
	if hero == "" or not event is InputEventKey or not event.pressed: return
	var direction := Vector2i.ZERO
	match event.keycode:
		KEY_UP, KEY_W: direction = Vector2i.UP
		KEY_RIGHT, KEY_D: direction = Vector2i.RIGHT
		KEY_DOWN, KEY_S: direction = Vector2i.DOWN
		KEY_LEFT, KEY_A: direction = Vector2i.LEFT
	if direction != Vector2i.ZERO:
		move_player(direction)
		get_viewport().set_input_as_handled()

class HeroPortrait extends Control:
	var character := "Knight"
	func _draw() -> void:
		AdventureBoard.draw_hero(self, size / 2, minf(size.x, size.y) * 0.6, character)

class AdventureBoard extends Control:
	var game: Control
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	static func draw_hero(canvas: Control, p: Vector2, s: float, character: String) -> void:
		var color := Color("78bac9") if character == "Knight" else Color("d88bca") if character == "Princess" else Color("6bb697")
		canvas.draw_circle(p + Vector2(0, 0.12) * s, s * 0.27, color)
		canvas.draw_circle(p + Vector2(0, -0.15) * s, s * 0.21, Color("f5d3ac"))
		if character == "Knight":
			canvas.draw_rect(Rect2(p + Vector2(-0.23, -0.38) * s, Vector2(0.46, 0.18) * s), Color("b9d5e0"))
			canvas.draw_line(p + Vector2(0, -0.38) * s, p + Vector2(0.1, -0.53) * s, Color("e78470"), s * 0.08)
		elif character == "Princess":
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.23, -0.3) * s, p + Vector2(-0.26, -0.49) * s, p + Vector2(-0.07, -0.36) * s, p + Vector2(0, -0.53) * s, p + Vector2(0.08, -0.36) * s, p + Vector2(0.25, -0.49) * s, p + Vector2(0.22, -0.3) * s]), Color("f5c65d"))
		else:
			canvas.draw_rect(Rect2(p + Vector2(-0.22, -0.43) * s, Vector2(0.44, 0.18) * s), Color("bd8e51"))
			canvas.draw_line(p + Vector2(-0.32, -0.25) * s, p + Vector2(0.32, -0.25) * s, Color("bd8e51"), s * 0.08)
		for x in [-0.08, 0.08]: canvas.draw_circle(p + Vector2(x, -0.14) * s, s * 0.025, Color("24364b"))
	func _draw() -> void:
		var s := minf((size.x - 20) / 23, (size.y - 20) / 11)
		var origin := (size - Vector2(23, 11) * s) / 2
		var wall: Color = [Color("222c3d"), Color("a5b7c6"), Color("6b4839")][game.level]
		draw_style_box(panel(wall), Rect2(origin - Vector2(6, 6), Vector2(23, 11) * s + Vector2(12, 12)))
		for y in 11:
			for x in 23:
				var cell := Vector2i(x, y)
				var p := origin + Vector2(cell) * s
				if not game.tiles.has(cell):
					draw_rect(Rect2(p + Vector2(2, 2), Vector2(s - 4, s - 4)), wall.lightened(0.05))
					continue
				var kind: String = game.tiles[cell]
				var floor_color: Color = [Color("536175"), Color("f3eee0"), Color("c69765")][game.level]
				if kind == "secret" and not game.secret_found:
					floor_color = wall
				if kind == "bridge": floor_color = Color("b18b59")
				if kind == "garden": floor_color = Color("90bb86")
				draw_rect(Rect2(p + Vector2.ONE, Vector2.ONE * (s - 2)), floor_color)
				if kind == "bridge":
					for offset in [0.1, 0.9]: draw_line(p + Vector2(0, offset) * s, p + Vector2(1, offset) * s, Color("f4dcaa"), 2)
				if kind == "secret" and not game.secret_found:
					draw_line(p + Vector2(0.5, 0.1) * s, p + Vector2(0.3, 0.8) * s, Color("dfd3ab"), 2)
				if game.visited.has(cell): draw_circle(p + Vector2.ONE * s * 0.5, s * 0.045, Color("94b8b5"))
		for cell in game.hint: draw_circle(origin + (Vector2(cell) + Vector2.ONE * 0.5) * s, s * 0.12, Color("ffd872"))
		for cell in game.holes:
			var p := origin + (Vector2(cell) + Vector2.ONE * 0.5) * s
			draw_circle(p, s * 0.37, Color("d4ad77"))
			draw_circle(p, s * 0.29, Color("101827"))
		for cell in game.guards:
			var p := origin + (Vector2(cell) + Vector2.ONE * 0.5) * s
			draw_arc(p, s * 1.05, 0, TAU, 32, Color(0.85, 0.43, 0.33, 0.4), 2)
			draw_hero(self, p, s * 0.8, "Knight")
			draw_string(ThemeDB.fallback_font, p + Vector2(0.15, -0.2) * s, "!" if game.awake > 0 else "zZ", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.4), Color("fff1bd"))
		if not game.has_key and game.key_cell.x >= 0 and (game.area != "basement" or game.secret_found):
			var p := origin + (Vector2(game.key_cell) + Vector2.ONE * 0.5) * s
			draw_rect(Rect2(p - Vector2.ONE * s * 0.32, Vector2.ONE * s * 0.64), Color("8b583a"))
			draw_line(p + Vector2(-0.3, 0.1) * s, p + Vector2(0.3, 0.1) * s, Color("e2b577"), 2)
			var color: Color = KEY_COLORS[game.level]
			if game.level == 0:
				draw_arc(p + Vector2(0, -0.12) * s, s * 0.13, 0, TAU, 20, color, 2)
			else:
				var points := PackedVector2Array()
				var count := 10 if game.level == 1 else 4
				for i in count:
					var radius := s * (0.09 if count == 10 and i % 2 else 0.18)
					points.append(p + Vector2(0, -s * 0.12) + Vector2.from_angle(TAU * i / count - PI / 2) * radius)
				draw_colored_polygon(points, color)
			draw_line(p, p + Vector2(0, 0.26) * s, color, 3)
			draw_line(p + Vector2(0, 0.21) * s, p + Vector2(0.14, 0.21) * s, color, 3)
		if game.area != "dungeon" or game.exit_found:
			var p := origin + Vector2(game.exit_cell) * s
			draw_rect(Rect2(p + Vector2.ONE * s * 0.1, Vector2.ONE * s * 0.8), Color("744e3e"))
			if game.area in ["hall", "towers", "courtyard"]:
				for i in 4: draw_line(p + Vector2(0.2, 0.2 + i * 0.18) * s, p + Vector2(0.8, 0.2 + i * 0.18) * s, Color("f7dfb2"), 2)
			else:
				draw_circle(p + Vector2(0.65, 0.55) * s, s * 0.08, Color("f5c65d"))
		draw_hero(self, origin + (Vector2(game.player_cell) + Vector2.ONE * 0.5) * s, s * 0.85, game.hero)
		if game.area == "towers":
			for i in 3: draw_string(ThemeDB.fallback_font, origin + Vector2(1 + i * 8, 1.5) * s, ["BACK TOWER", "MIDDLE TOWER", "FAR TOWER"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.38), Color("fff1d9"))
		if game.won:
			draw_string(ThemeDB.fallback_font, origin + Vector2(5, 5.6) * s, "YOU MADE IT!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.9), Color("24364b"))
	static func panel(color: Color) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(12)
		return style
