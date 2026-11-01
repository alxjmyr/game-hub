extends Control
## Offline construction puzzle. Coordinates inside the board are 860 x 530.
signal back_requested
signal completed(data: Dictionary)

const INK := Color("24364b")
const TEAL := Color("168c83")
const GOLD := Color("edae49")
const CORAL := Color("e87862")
const BOARD_SIZE := Vector2(860, 530)
const LENGTHS := [260.0, 180.0, 120.0]

class Plank extends StaticBody2D:
	var length: float = 180.0
	var bent: bool = false
	var selected: bool = false
	var tint: Color = Color("168c83")
	func _ready() -> void:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(length, 16)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		add_child(collision)
		if bent:
			var end := CollisionShape2D.new()
			var end_shape := RectangleShape2D.new()
			end_shape.size = Vector2(16, 56)
			end.shape = end_shape
			end.position = Vector2(length / 2 - 8, -20)
			add_child(end)
	func _draw() -> void:
		draw_style_box(_style(tint, 8), Rect2(-length / 2, -8, length, 16))
		if bent:
			draw_style_box(_style(tint, 6), Rect2(length / 2 - 16, -48, 16, 56))
		draw_circle(Vector2.ZERO, 3, Color.WHITE)
		if selected:
			draw_rect(Rect2(-length / 2 - 5, -13, length + 10, 26), Color("edae49"), false, 3)
	static func _style(color: Color, radius: int) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		return style

class Ball extends RigidBody2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 12, Color("e87862"))
		draw_circle(Vector2(-3, -4), 4, Color("ffd4b4"))

class Board extends Node2D:
	var game: Control
	func _draw() -> void:
		draw_style_box(Plank._style(Color("e9f0eb"), 18), Rect2(Vector2.ZERO, BOARD_SIZE))
		for x in range(20, 860, 30):
			for y in range(20, 530, 30):
				draw_circle(Vector2(x, y), 1.2, Color("cbd9d1"))
		var p: Vector2 = game.drop_point
		draw_style_box(Plank._style(INK, 6), Rect2(p.x - 26, 0, 52, 24))
		draw_line(Vector2(p.x, 25), Vector2(p.x, 44), INK, 3)
		if game.state == "editing":
			draw_circle(p, 12, CORAL)
		var b: Vector2 = game.bucket_center
		var w: float = game.bucket_width
		draw_style_box(Plank._style(TEAL, 6), Rect2(b.x-w/2-8, b.y-38, 8, 48))
		draw_style_box(Plank._style(TEAL, 6), Rect2(b.x+w/2, b.y-38, 8, 48))
		draw_style_box(Plank._style(TEAL, 6), Rect2(b.x-w/2-8, b.y+2, w+16, 10))
		draw_line(Vector2(b.x-12, b.y-14), Vector2(b.x-3, b.y-5), Color.WHITE, 3)
		draw_line(Vector2(b.x-3, b.y-5), Vector2(b.x+14, b.y-25), Color.WHITE, 3)

var board: Node2D
var blocks: Array = []
var ball: RigidBody2D
var bucket_body: StaticBody2D
var drop_point := Vector2(200, 55)
var bucket_center := Vector2(480, 490)
var bucket_width: float = 110
var state: String = "editing"
var attempts: int = 0
var difficulty: int = 0
var puzzle_seed: int = 0
var selected: int = -1
var dragging := false
var drag_offset := Vector2.ZERO
var elapsed: float = 0.0
var caught_time: float = 0.0
var solution_position := Vector2.ZERO
var solution_rotation: float = 0.0
var hint_used := false
var status_label: Label
var stats_label: Label
var selected_label: Label
var drop_button: Button
var retry_button: Button
var difficulty_buttons: Array[Button] = []
var layout: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	new_puzzle()
	resized.connect(_fit_layout)
	_fit_layout()

func _fit_layout() -> void:
	if not is_instance_valid(layout):
		return
	var factor := minf(size.x / 1200.0, size.y / 800.0)
	layout.scale = Vector2.ONE * factor
	layout.position = (size - Vector2(1200, 800) * factor) / 2

func _label(text: String, pos: Vector2, width: float, font_size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size.x = width
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", font_size)
	layout.add_child(label)
	return label

func _button(text: String, pos: Vector2, width: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(width, 44)
	button.pressed.connect(action)
	layout.add_child(button)
	return button

func _build_ui() -> void:
	layout = Control.new()
	layout.size = Vector2(1200, 800)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	_button("<  Game shelf", Vector2(32, 24), 170, func(): back_requested.emit())
	_label("THE INVENTOR'S WORKSHOP", Vector2(228, 23), 600, 16)
	_label("Ball & Bucket", Vector2(228, 46), 600, 38)
	_label("Build a path. Drop the ball. Try a new idea.", Vector2(40, 111), 850, 20)
	# Avoid PopupMenu's release-template focus connection bug (Godot #89657).
	# All choices remain visible and keyboard-accessible without a popup window.
	var group := ButtonGroup.new()
	var titles := ["Explorer · 3", "Inventor · 2", "Engineer · 1"]
	for index in range(titles.size()):
		var choice := _button(titles[index], Vector2(646 + index * 174, 36), 166, change_difficulty.bind(index))
		choice.add_theme_font_size_override("font_size", 17)
		choice.add_theme_color_override("font_hover_pressed_color", INK)
		choice.toggle_mode = true
		choice.button_group = group
		difficulty_buttons.append(choice)
	board = Board.new()
	board.game = self
	board.position = Vector2(40, 160)
	layout.add_child(board)
	_label("YOUR TOOLBOX", Vector2(925, 120), 240, 18)
	_label("Drag a piece into position.\nClick a piece to select it.", Vector2(925, 150), 240, 17)
	selected_label = _label("Select a piece", Vector2(925, 220), 240, 19)
	_button("Left [Q]", Vector2(925, 260), 112, func(): rotate_selected(-15)).add_theme_font_size_override("font_size", 17)
	_button("Right [E]", Vector2(1045, 260), 115, func(): rotate_selected(15)).add_theme_font_size_override("font_size", 17)
	_label("Q / E: rotate  •  Shift: finer\nArrow keys: move selection\nMouse wheel: rotate", Vector2(925, 315), 240, 16)
	_button("Return piece", Vector2(925, 395), 235, return_selected)
	drop_button = _button("Drop ball  [Space]", Vector2(925, 459), 235, drop_ball)
	retry_button = _button("Retry same puzzle", Vector2(925, 515), 235, retry)
	_button("New puzzle", Vector2(925, 571), 235, func(): new_puzzle())
	_button("Show a hint", Vector2(925, 627), 235, show_hint)
	status_label = _label("", Vector2(40, 705), 1120, 20)
	stats_label = _label("", Vector2(40, 748), 1120, 16)

func change_difficulty(index: int) -> void:
	if index < 0 or index > 2:
		return
	difficulty = index
	new_puzzle()

func new_puzzle(seed_value: int = -1) -> void:
	for index in range(difficulty_buttons.size()):
		difficulty_buttons[index].set_pressed_no_signal(index == difficulty)
	_clear_ball()
	for block in blocks:
		block.free()
	blocks.clear()
	if is_instance_valid(bucket_body):
		bucket_body.free()
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
		puzzle_seed = int(rng.randi() % 999999)
	else:
		puzzle_seed = seed_value
	rng.seed = puzzle_seed
	var mirrored := rng.randf() < 0.5
	var direction := -1.0 if mirrored else 1.0
	var start_x := rng.randf_range(155, 290)
	if mirrored:
		start_x = BOARD_SIZE.x - start_x
	drop_point = Vector2(start_x, 55)
	solution_position = Vector2(start_x + direction * 70, 220)
	solution_rotation = direction * deg_to_rad(30)
	bucket_center = Vector2(start_x + direction * 340, 490)
	bucket_width = [120.0, 95.0, 72.0][difficulty]
	_build_bucket()
	for index in range(3 - difficulty):
		var plank := Plank.new()
		plank.length = LENGTHS[index]
		plank.bent = index == 2
		plank.tint = [TEAL, Color("627bc1"), GOLD][index]
		board.add_child(plank)
		blocks.append(plank)
		plank.position = _home(index)
	state = "editing"
	attempts = 0
	selected = -1
	dragging = false
	hint_used = false
	_set_status("Arrange your pieces, then drop the ball. You can retry as often as you like.")
	_refresh()

func _home(index: int) -> Vector2:
	return Vector2(180 + index * 245, 430)

func _build_bucket() -> void:
	bucket_body = StaticBody2D.new()
	board.add_child(bucket_body)
	for rect in [Rect2(bucket_center.x-bucket_width/2-8, bucket_center.y-38, 8, 48), Rect2(bucket_center.x+bucket_width/2, bucket_center.y-38, 8, 48), Rect2(bucket_center.x-bucket_width/2-8, bucket_center.y+2, bucket_width+16, 10)]:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		bucket_body.add_child(collision)

func _clear_ball() -> void:
	if is_instance_valid(ball):
		ball.free()
	ball = null

func select_block(index: int) -> void:
	selected = index
	for i in range(blocks.size()):
		blocks[i].selected = i == selected
		blocks[i].queue_redraw()
	_refresh()

func rotate_selected(degrees: float) -> void:
	if state != "editing" or selected < 0:
		return
	blocks[selected].rotation += deg_to_rad(degrees)
	_constrain(blocks[selected])
	_refresh()

func return_selected() -> void:
	if state == "editing" and selected >= 0:
		blocks[selected].position = _home(selected)
		blocks[selected].rotation = 0
		_refresh()

func _constrain(block: Node2D) -> void:
	# Include the raised end of the L-shaped block at every rotation.
	var min_corner := Vector2(INF, INF)
	var max_corner := Vector2(-INF, -INF)
	var top: float = -48.0 if block.bent else -8.0
	for corner in [Vector2(-block.length / 2, top), Vector2(block.length / 2, top), Vector2(-block.length / 2, 8), Vector2(block.length / 2, 8)]:
		var rotated: Vector2 = corner.rotated(block.rotation)
		min_corner = min_corner.min(rotated)
		max_corner = max_corner.max(rotated)
	block.position.x = clampf(block.position.x, 4 - min_corner.x, BOARD_SIZE.x - 4 - max_corner.x)
	block.position.y = clampf(block.position.y, 85 - min_corner.y, BOARD_SIZE.y - 4 - max_corner.y)

func _input(event: InputEvent) -> void:
	# Space is always the advertised drop/retry shortcut, even after a toolbar
	# button receives keyboard focus. Enter continues to activate focused buttons.
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if state == "editing": drop_ball()
		elif state in ["missed", "won"]: retry()
		get_viewport().set_input_as_handled()
		return
	if not visible or state != "editing":
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				dragging = false
			elif Rect2(Vector2.ZERO, BOARD_SIZE).has_point(board.get_local_mouse_position()):
				for index in range(blocks.size()-1, -1, -1):
					var local: Vector2 = blocks[index].get_local_mouse_position()
					var hit := Rect2(-blocks[index].length/2-8, -20, blocks[index].length+16, 40).has_point(local)
					if blocks[index].bent:
						hit = hit or Rect2(blocks[index].length/2-24, -56, 32, 64).has_point(local)
					if hit:
						select_block(index)
						dragging = true
						drag_offset = blocks[index].position - board.get_local_mouse_position()
						get_viewport().set_input_as_handled()
						break
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			rotate_selected(-5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 5)
	elif event is InputEventMouseMotion and dragging and selected >= 0:
		blocks[selected].position = board.get_local_mouse_position() + drag_offset
		_constrain(blocks[selected])
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_Q, KEY_E]:
			rotate_selected((-1 if event.keycode == KEY_Q else 1) * (2 if event.shift_pressed else 15))
			get_viewport().set_input_as_handled()
		elif selected >= 0 and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			var direction := Vector2.ZERO
			if event.keycode == KEY_LEFT: direction.x = -1
			if event.keycode == KEY_RIGHT: direction.x = 1
			if event.keycode == KEY_UP: direction.y = -1
			if event.keycode == KEY_DOWN: direction.y = 1
			blocks[selected].position += direction * (2 if event.shift_pressed else 10)
			_constrain(blocks[selected])
			get_viewport().set_input_as_handled()

func drop_ball() -> void:
	if state != "editing":
		return
	_clear_ball()
	dragging = false
	ball = Ball.new()
	ball.position = drop_point
	ball.gravity_scale = 0.75
	ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	ball.linear_damp = 0.1
	var material := PhysicsMaterial.new()
	material.friction = 0.15
	material.bounce = 0.05
	ball.physics_material_override = material
	var shape := CircleShape2D.new()
	shape.radius = 12
	var collision := CollisionShape2D.new()
	collision.shape = shape
	ball.add_child(collision)
	board.add_child(ball)
	state = "running"
	attempts += 1
	elapsed = 0
	caught_time = 0
	_set_status("Let's see where it goes…")
	_refresh()

func retry() -> void:
	_clear_ball()
	state = "editing"
	dragging = false
	_set_status("Your arrangement is saved. Adjust a piece and try again!")
	_refresh()

func apply_solution() -> void:
	retry()
	blocks[0].position = solution_position
	blocks[0].rotation = solution_rotation
	for index in range(1, blocks.size()):
		blocks[index].position = Vector2(110 if solution_rotation > 0 else 750, 330 + index * 60)
		blocks[index].rotation = 0
	select_block(0)

func show_hint() -> void:
	if state != "editing":
		retry()
	hint_used = true
	_set_status("Hint: use the longest piece as a downhill ramp. Aim its low end toward the bucket.")
	select_block(0)

func _physics_process(delta: float) -> void:
	if state != "running" or not is_instance_valid(ball):
		return
	elapsed += delta
	var p := ball.position
	if absf(p.x-bucket_center.x) < bucket_width/2-10 and p.y > bucket_center.y-38 and p.y < bucket_center.y+6 and ball.linear_velocity.length() < 70:
		caught_time += delta
	else:
		caught_time = 0
	if caught_time > 0.45:
		state = "won"
		_set_status("Caught it! Great engineering. Try a new puzzle or invent another solution.")
		completed.emit({"game": "ball_bucket", "difficulty": difficulty, "attempts": attempts, "seed": puzzle_seed, "hint_used": hint_used})
		_refresh()
	elif p.y > 580 or p.x < -40 or p.x > 900 or elapsed > 12:
		state = "missed"
		_set_status("Not quite! Retry keeps your pieces in place. What could you change?")
		_refresh()

func _set_status(text: String) -> void:
	status_label.text = text

func _refresh() -> void:
	drop_button.disabled = state != "editing"
	retry_button.disabled = state == "editing"
	stats_label.text = "PUZZLE %06d    •    %d pieces    •    Attempts: %d    •    No timer. No lost lives." % [puzzle_seed, blocks.size(), attempts]
	selected_label.text = "Piece %d · %d°" % [selected+1, roundi(rad_to_deg(blocks[selected].rotation))] if selected >= 0 else "Select a piece"
	board.queue_redraw()
