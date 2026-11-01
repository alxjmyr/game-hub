extends Control

const INK = Color("24364b")
const TEAL = Color("167d8d")
const CREAM = Color("f6f3e9")
const SAVE_PATH = "user://progress.cfg"
var current_game: Control
var shelf: Control
var progress := ConfigFile.new()
var sound_enabled := true
var sound_button: Button
var player: AudioStreamPlayer
var last_game := ""

func _ready() -> void:
	progress.load(SAVE_PATH)
	sound_enabled = progress.get_value("settings", "sound", true)
	theme = _make_theme()
	player = AudioStreamPlayer.new()
	add_child(player)
	show_shelf()
	for arg in OS.get_cmdline_user_args():
		if arg == "--memory":
			open_game("memory")
		elif arg == "--physics":
			open_game("ball_bucket")
		elif arg in ["--jigsaw", "--maze", "--letter-hunt"]:
			open_game(arg.trim_prefix("--").replace("-", "_"))

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", INK)
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("ffffff") if state == "normal" else Color("deeee8")
			if state == "disabled": style.bg_color = Color("e4e5df")
			style.set_corner_radius_all(12)
			style.content_margin_left = 20
			style.content_margin_right = 20
			style.content_margin_top = 12
			style.content_margin_bottom = 12
			if state == "focus":
				style.bg_color = Color.TRANSPARENT
				style.border_color = TEAL
				style.set_border_width_all(3)
			t.set_stylebox(state, type, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(state, type, INK)
		t.set_color("font_disabled_color", type, Color("6b777b"))
	return t

func label(text: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func show_shelf() -> void:
	if is_instance_valid(current_game):
		remove_child(current_game)
		current_game.queue_free()
		current_game = null
	if is_instance_valid(shelf):
		remove_child(shelf)
		shelf.queue_free()
	shelf = MarginContainer.new()
	shelf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		shelf.add_theme_constant_override("margin_" + side, 32)
	add_child(shelf)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	shelf.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var brand := label("THE LITTLE LOCAL ARCADE", 16, TEAL)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	sound_button = Button.new()
	_update_sound_button()
	sound_button.pressed.connect(_toggle_sound)
	top.add_child(sound_button)
	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(func(): get_tree().quit())
	top.add_child(quit_button)
	column.add_child(label("Your game shelf", 44))
	column.add_child(label("A little curiosity. A lot of possibility. Pick something to play.", 21))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var row := GridContainer.new()
	row.columns = 3
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 16)
	scroll.add_child(row)
	_game_card(row, "memory", "01 / OBSERVE + REMEMBER", "Memory Match", "Turn a card. Find its twin.\nHow much can you remember?", Color("cce9de"))
	_game_card(row, "ball_bucket", "02 / BUILD + EXPERIMENT", "Ball & Bucket", "Build a path for a falling ball.\nTry an idea. See where it goes.", Color("f4d79b"))
	_game_card(row, "jigsaw", "03 / LOOK + CONNECT", "Jigsaw Puzzles", "Piece together a colorful scene.\nTurn a little chaos into a picture.", Color("dce3f7"))
	_game_card(row, "maze", "04 / EXPLORE + PLAN", "Maze Explorer", "Find a path. Collect a key.\nWhere will the next turn lead?", Color("f4d7d3"))
	_game_card(row, "letter_hunt", "05 / FIND + TYPE", "Letter Hunt", "Meet the keys on your keyboard.\nBuild your way up to words.", Color("e4ebc5"))
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var note := label("ALL PLAY. ALL LOCAL.     •     No timers. Take your time.", 16)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(note)
	footer.add_child(label("Tab to explore  /  Enter to choose", 15))

func _game_card(parent: Control, id: String, eyebrow: String, title: String, description: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(22)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(label(eyebrow, 15, TEAL))
	var art := ShelfArt.new()
	art.game_id = id
	art.custom_minimum_size = Vector2(0, 48)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(art)
	v.add_child(label(title, 28))
	panel.accessibility_description = description.replace("\n", " ")
	var record := "Ready for a new adventure."
	if progress.has_section(id):
		record = "%d games completed." % int(progress.get_value(id, "wins", 0))
	v.add_child(label(record, 15))
	var play := Button.new()
	play.text = "Play  →"
	play.custom_minimum_size.y = 44
	play.pressed.connect(open_game.bind(id))
	v.add_child(play)
	if last_game == id: _focus_if_present.call_deferred(play)

func _focus_if_present(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree(): button.grab_focus()

func open_game(id: String) -> void:
	last_game = id
	if is_instance_valid(current_game):
		remove_child(current_game)
		current_game.queue_free()
	if is_instance_valid(shelf):
		remove_child(shelf)
		shelf.queue_free()
		shelf = null
	current_game = load("res://games/%s.gd" % id).new()
	if id == "memory":
		current_game.best_scores = progress.get_value("memory", "best_scores", {}).duplicate()
	current_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_game.back_requested.connect(show_shelf)
	current_game.completed.connect(_on_completed.bind(id))
	add_child(current_game)
	play_tone(440.0, 0.09)

func _on_completed(data: Dictionary, id: String) -> void:
	progress.set_value(id, "wins", int(progress.get_value(id, "wins", 0)) + 1)
	progress.set_value(id, "last_result", data)
	if id == "memory" and is_instance_valid(current_game):
		progress.set_value(id, "best_scores", current_game.best_scores.duplicate())
	_save()
	play_tone(660.0, 0.35)

func _save() -> void:
	var result := progress.save(SAVE_PATH)
	if result != OK: push_warning("Could not save progress: %s" % error_string(result))

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	if not sound_enabled: player.stop()
	progress.set_value("settings", "sound", sound_enabled)
	_save()
	_update_sound_button()
	play_tone(520.0, 0.12)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(current_game):
			show_shelf()
			get_viewport().set_input_as_handled()

func _update_sound_button() -> void:
	sound_button.text = "Sound: on" if sound_enabled else "Sound: off"

func play_tone(hz: float, duration: float) -> void:
	if not sound_enabled: return
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var bytes := PackedByteArray()
	var count := int(duration * 22050)
	bytes.resize(count * 2)
	for i in count:
		var envelope := sin(PI * float(i) / count)
		bytes.encode_s16(i * 2, int(sin(TAU * hz * i / 22050.0) * 4000 * envelope))
	wav.data = bytes
	player.stream = wav
	player.play()

class ShelfArt extends Control:
	var game_id := "memory"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var center := size / 2
		draw_set_transform(center, 0, Vector2(0.43, 0.43))
		center = Vector2.ZERO
		if game_id == "ball_bucket":
			draw_dashed_line(center + Vector2(-105, -65), center + Vector2(-105, -20), Color("167d8d"), 3, 7)
			draw_circle(center + Vector2(-105, -60), 15, Color("ed805c"))
			draw_line(center + Vector2(-130, -5), center + Vector2(-10, 35), Color("24364b"), 12, true)
			draw_line(center + Vector2(15, 50), center + Vector2(105, 20), Color("24364b"), 12, true)
			draw_polyline(PackedVector2Array([center + Vector2(80, 35), center + Vector2(88, 70), center + Vector2(130, 70), center + Vector2(138, 35)]), Color("167d8d"), 7, true)
		elif game_id == "jigsaw":
			for i in 6:
				var p := Vector2((i % 3) * 66 - 95, (i / 3) * 60 - 55)
				draw_rect(Rect2(p, Vector2(60, 54)), [Color("167d8d"), Color("ed805c"), Color("e9b94e")][i % 3])
				draw_circle(p + Vector2(60, 27), 10, Color("fffdf6"))
		elif game_id == "maze":
			draw_polyline(PackedVector2Array([Vector2(-110, 50), Vector2(-110, -50), Vector2(100, -50), Vector2(100, 50), Vector2(-30, 50), Vector2(-30, 0), Vector2(50, 0)]), Color("167d8d"), 12, true)
			draw_circle(Vector2(-110, 50), 15, Color("ed805c"))
			draw_circle(Vector2(50, 0), 15, Color("e9b94e"))
		elif game_id == "letter_hunt":
			for i in 3:
				var p := Vector2(i * 85 - 120, -32)
				draw_style_box(_card(), Rect2(p, Vector2(72, 64)))
				draw_string(ThemeDB.fallback_font, p + Vector2(20, 46), ["A", "B", "C"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("167d8d"))
		else:
			for i in 4:
				var p := center + Vector2((i % 2) * 100 - 90, (i / 2) * 75 - 66)
				draw_style_box(_card(), Rect2(p, Vector2(80, 64)))
				if i == 0 or i == 3:
					draw_circle(p + Vector2(40, 32), 16, Color("ed805c"))
				else:
					draw_line(p + Vector2(25, 24), p + Vector2(55, 40), Color("167d8d"), 5, true)
	func _card() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("fffdf6")
		s.set_corner_radius_all(10)
		return s
