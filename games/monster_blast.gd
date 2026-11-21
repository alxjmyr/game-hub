extends Control

signal back_requested
signal completed(data: Dictionary)

const Levels = preload("res://games/monster_blast/levels.gd")
const Art = preload("res://games/monster_blast/art.gd")
const CELL := 3.0
var WIDTH := 25
var HEIGHT := 21
var START := Vector2i(2, 4)
var EXIT := Vector2i(6, 18)
var SECRET := Vector2i(4, 12)
const GOLD := Color("dfb666")
const PALE := Color("dfdac4")

const DIFFICULTIES := ["Easy", "Normal", "Hard"]
const MOVE_MULTIPLIERS := [1.0, 1.3, 1.65]
const ATTACK_MULTIPLIERS := [1.0, 1.35, 1.8]
var difficulty := 0
var level_index := 0
var level_data: Dictionary = {}
var stage_results: Array[Dictionary] = []
var checkpoint := {"health": 100, "ammo": 0, "armed": false, "weapons": ["pistol"], "weapon": "pistol"}
var weapons: Array = ["pistol"]
var weapon := "pistol"
var switches: Array[Dictionary] = []
var bridge: Node3D
var difficulty_row: HBoxContainer
var difficulty_note: Label
var difficulty_buttons: Array[Button] = []
var chapter_label: Label
var phase := "intro"
var won := false
var health := 100
var ammo := 0
var armed := false
var has_key := false
var secret_found := false
var kills := 0
var shots := 0
var hits := 0
var elapsed := 0.0
var cooldown := 0.0
var flash := 0.0
var hurt_flash := 0.0
var hit_flash := 0.0
var bob := 0.0
var melee_swing := false
var message := ""
var message_time := 0.0
var show_map := false
var sensitivity := 0.0024
var grid: Array[String] = []
var discovered: Dictionary = {}
var enemies: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var textures: Dictionary = {}
var world: Node3D
var view: SubViewport
var player_body: CharacterBody3D
var camera: Camera3D
var secret_body: StaticBody3D
var menu: CenterContainer
var menu_title: Label
var menu_copy: Label
var primary_button: Button
var restart_button: Button
var back_button: Button
var hud: Control
var sounds: Dictionary = {}
var audio_players: Array[AudioStreamPlayer] = []
var ambience: AudioStreamPlayer
var torches: Array[OmniLight3D] = []
var blood_particles: Array[Dictionary] = []
var navigation := AStarGrid2D.new()
var wake_clock := 0.0
var map_title := "THE HOLDING CELLS"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_audio()
	for kind in ["stone", "floor", "ceiling", "door", "secret", "guard", "skeleton", "caster", "corpse", "pistol", "ammo", "health", "key", "torch", "grass", "blunderbuss", "rune", "warden", "regent", "gargoyle"]:
		textures[kind] = Art.texture(kind)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = 2
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	view = SubViewport.new()
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(view)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	add_child(hud)
	_make_menu()
	_build_level()
	_set_menu("intro")
	get_window().focus_exited.connect(_focus_lost)

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _make_menu() -> void:
	menu = CenterContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151b20f5")
	style.border_color = Color("78644b")
	style.set_border_width_all(2)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)
	menu.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 570
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var eyebrow := Label.new()
	chapter_label = eyebrow
	eyebrow.text = "MONSTER BLAST  /  CHAPTER I"
	eyebrow.add_theme_color_override("font_color", GOLD)
	eyebrow.add_theme_font_size_override("font_size", 17)
	column.add_child(eyebrow)
	menu_title = Label.new()
	menu_title.add_theme_font_size_override("font_size", 40)
	menu_title.add_theme_color_override("font_color", PALE)
	column.add_child(menu_title)
	menu_copy = Label.new()
	menu_copy.custom_minimum_size = Vector2(570, 0)
	menu_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_copy.add_theme_color_override("font_color", Color("b3baaf"))
	menu_copy.add_theme_font_size_override("font_size", 19)
	column.add_child(menu_copy)
	difficulty_row = HBoxContainer.new()
	difficulty_row.add_theme_constant_override("separation", 8)
	column.add_child(difficulty_row)
	var group := ButtonGroup.new()
	for i in 3:
		var button := _menu_button(difficulty_row, DIFFICULTIES[i], set_difficulty.bind(i))
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		difficulty_buttons.append(button)
	difficulty_note = Label.new()
	difficulty_note.add_theme_font_size_override("font_size", 16)
	difficulty_note.add_theme_color_override("font_color", GOLD)
	column.add_child(difficulty_note)
	set_difficulty(0)
	primary_button = _menu_button(column, "Enter the dungeon", _primary)
	restart_button = _menu_button(column, "Restart level", restart_level)
	back_button = _menu_button(column, "Game shelf", _back)
	var controls := Label.new()
	controls.text = "WASD / Arrows  Move    •    Mouse  Aim    •    Left click  Fire\nE  Use / search    •    F / right click  Melee\n1 / 2 / 3  Weapons    •    Tab  Map    •    Esc  Pause\n[ / ]  Mouse sensitivity"
	controls.add_theme_font_size_override("font_size", 16)
	controls.add_theme_color_override("font_color", Color("8f9b99"))
	column.add_child(controls)

func _menu_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 45
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("29352f") if state in ["hover", "pressed"] else Color("202a2c")
		style.border_color = GOLD if state == "focus" else Color("746348")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, PALE)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _set_menu(state: String) -> void:
	phase = state
	menu.visible = state != "playing"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if state == "playing" else Input.MOUSE_MODE_VISIBLE
	show_map = false
	restart_button.visible = state == "paused"
	difficulty_row.visible = state == "intro"
	difficulty_note.visible = state == "intro"
	chapter_label.text = "MONSTER BLAST  /  CHAPTER %s OF III  /  %s" % [["I", "II", "III"][level_index], DIFFICULTIES[difficulty].to_upper()]
	match state:
		"intro":
			menu_title.text = "The guard fell asleep."
			menu_copy.text = "Take the sleeping guard’s pistol. Find the brass key.\nEscape the dungeon, the castle, and its cursed grounds.\n\nThree chapters. Two bosses. One way out.\nRetro monster violence, blood, and mild horror."
			primary_button.text = "Enter the dungeon"
		"paused":
			menu_title.text = "Catching your breath."
			menu_copy.text = "%s • %s difficulty\n" % [chapter_name(), DIFFICULTIES[difficulty]] + objective()
			primary_button.text = "Resume escape"
		"dead":
			menu_title.text = "Back to the cold stone."
			menu_copy.text = "Restart %s with your equipment and health from the start of this chapter. Enemies, supplies, and objectives reset.\n\nKeep moving. Dodge the windup before an attack." % chapter_name()
			primary_button.text = "Retry this chapter"
		"cleared":
			menu_title.text = "Dungeon escaped." if level_index == 0 else "The portcullis falls."
			menu_copy.text = "%s\n\n%d / %d monsters  •  %s\n\nNEXT: %s\n%s" % [chapter_name(), kills, enemies.size(), "Secret found" if secret_found else "Secret missed", Levels.get_level(level_index + 1).name, Levels.get_level(level_index + 1).brief]
			primary_button.text = "Continue to the " + ("castle" if level_index == 0 else "grounds")
		"won":
			menu_title.text = "The night is yours."
			var totals := campaign_totals()
			menu_copy.text = "The drawbridge crashes down. You step beyond the walls as the castle’s last bell falls silent.\n\nYOU ESCAPED THE CASTLE\nAll 3 chapters complete • %s\n%d monsters defeated • %d / 3 secrets\n%d:%02d • Accuracy %d%%\n\nSomewhere behind you, a guard is still looking for his pistol." % [DIFFICULTIES[difficulty], totals.kills, totals.secrets, int(totals.seconds) / 60, int(totals.seconds) % 60, int(100.0 * totals.hits / maxi(1, totals.shots))]
			primary_button.text = "New escape / choose difficulty"
	if state != "playing": primary_button.grab_focus()

func set_difficulty(value: int) -> void:
	if phase != "intro": return
	difficulty = clampi(value, 0, 2)
	if is_instance_valid(chapter_label): chapter_label.text = "MONSTER BLAST  /  CHAPTER I OF III  /  " + DIFFICULTIES[difficulty].to_upper()
	for i in difficulty_buttons.size(): difficulty_buttons[i].set_pressed_no_signal(i == difficulty)
	difficulty_note.text = ["Original pace. Time to explore and line up shots.", "Monsters move 30% faster and attack 35% faster.", "Monsters move 65% faster and attack 80% faster."][difficulty]

func chapter_name() -> String:
	return "The Dungeon" if level_index == 0 else str(level_data.name)

func key_name() -> String:
	return "BRASS KEY" if level_index == 0 else str(level_data.key_name)

func _primary() -> void:
	match phase:
		"paused": _set_menu("playing")
		"dead": restart_level()
		"cleared": next_level()
		"won":
			start_run()
			_set_menu("intro")
		_: start_run()

func next_level() -> void:
	if phase != "cleared" or level_index >= 2: return
	level_index += 1
	checkpoint = {"health": health, "ammo": ammo, "armed": armed, "weapons": weapons.duplicate(), "weapon": weapon}
	restart_level()

func campaign_totals() -> Dictionary:
	var totals := {"kills": 0, "secrets": 0, "seconds": 0, "shots": 0, "hits": 0}
	for result in stage_results:
		for field in totals: totals[field] += int(result[field])
	return totals

func finish_level() -> void:
	if phase != "playing": return
	stage_results.append({"chapter": level_index, "kills": kills, "secrets": int(secret_found), "seconds": int(elapsed), "shots": shots, "hits": hits})
	_sound("door")
	if level_index < 2:
		_set_menu("cleared")
	else:
		won = true
		_set_menu("won")
		var result := campaign_totals()
		result["difficulty"] = DIFFICULTIES[difficulty]
		result["chapters"] = stage_results.duplicate(true)
		result["levels_completed"] = 3
		completed.emit(result)

func _back() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_requested.emit()

func _focus_lost() -> void:
	if phase == "playing": _set_menu("paused")

func start_run() -> void:
	level_index = 0
	stage_results.clear()
	checkpoint = {"health": 100, "ammo": 0, "armed": false, "weapons": ["pistol"], "weapon": "pistol"}
	restart_level()

func restart_level() -> void:
	health = checkpoint.health
	ammo = checkpoint.ammo
	armed = checkpoint.armed
	weapons = checkpoint.weapons.duplicate()
	weapon = checkpoint.weapon
	has_key = false
	secret_found = false
	won = false
	kills = 0
	shots = 0
	hits = 0
	elapsed = 0.0
	cooldown = 0.0
	flash = 0.0
	hurt_flash = 0.0
	hit_flash = 0.0
	bob = 0.0
	wake_clock = 0.0
	discovered.clear()
	_build_level()
	_set_menu("playing")
	announce("A sleeping guard. An unattended pistol. Your chance." if level_index == 0 else "CHECKPOINT  •  " + chapter_name() + "  •  Supplies near the stairs.", 6.0)

func _build_grid() -> void:
	WIDTH = 25
	HEIGHT = 21
	START = Vector2i(2, 4)
	EXIT = Vector2i(6, 18)
	SECRET = Vector2i(4, 12)
	level_data = {}
	if level_index > 0:
		level_data = Levels.get_level(level_index)
		WIDTH = level_data.width
		HEIGHT = level_data.height
		START = level_data.start
		EXIT = level_data.exit
		SECRET = level_data.secret
	grid.clear()
	for z in HEIGHT: grid.append("#".repeat(WIDTH))
	if level_index > 0:
		for room in level_data.rooms:
			for z in range(room.position.y, room.end.y):
				for x in range(room.position.x, room.end.x): grid[z][x] = "."
		for pillar in level_data.pillars: grid[pillar.y][pillar.x] = "O"
		grid[SECRET.y][SECRET.x] = "S"
		grid[EXIT.y][EXIT.x] = "X"
		return
	for room in [Rect2i(1, 3, 3, 3), Rect2i(4, 4, 1, 1), Rect2i(5, 2, 6, 5), Rect2i(11, 4, 2, 2), Rect2i(13, 2, 9, 6), Rect2i(9, 7, 2, 4), Rect2i(5, 11, 8, 7), Rect2i(13, 13, 2, 2), Rect2i(15, 11, 8, 6), Rect2i(18, 8, 2, 3), Rect2i(6, 18, 2, 2), Rect2i(1, 10, 3, 4)]:
		for z in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x): grid[z][x] = "."
	for pillar in [Vector2i(16, 5), Vector2i(18, 5), Vector2i(8, 13), Vector2i(10, 15), Vector2i(20, 14)]: grid[pillar.y][pillar.x] = "O"
	grid[SECRET.y][SECRET.x] = "S"
	grid[EXIT.y][EXIT.x] = "X"
	grid[18][7] = "#"

func _build_level() -> void:
	if is_instance_valid(world):
		view.remove_child(world)
		world.queue_free()
	enemies.clear()
	pickups.clear()
	projectiles.clear()
	switches.clear()
	bridge = null
	torches.clear()
	blood_particles.clear()
	_build_grid()
	navigation.region = Rect2i(0, 0, WIDTH, HEIGHT)
	navigation.cell_size = Vector2.ONE
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for z in HEIGHT:
		for x in WIDTH: navigation.set_point_solid(Vector2i(x, z), not walkable(Vector2i(x, z)))
	world = Node3D.new()
	view.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("131921") if level_index < 2 else Color("253249")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8b3bf")
	env.ambient_light_energy = 0.65 if level_index < 2 else 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	world.add_child(environment)
	var stone := _material("stone")
	var crypt_stone := _material("stone")
	crypt_stone.albedo_color = Color("a5bba9")
	var chapel_stone := _material("stone")
	chapel_stone.albedo_color = Color("b8a5b6")
	if level_index == 1: stone.albedo_color = Color("c3b5a3")
	var floor_mat := _material("grass" if level_index == 2 else "floor")
	floor_mat.uv1_scale = Vector3(WIDTH, HEIGHT, 1)
	var ceiling_mat := _material("ceiling")
	ceiling_mat.uv1_scale = Vector3(WIDTH, HEIGHT, 1)
	_box(Vector3(WIDTH * CELL / 2 - CELL / 2, -0.15, HEIGHT * CELL / 2 - CELL / 2), Vector3(WIDTH * CELL, 0.3, HEIGHT * CELL), floor_mat, false)
	if level_index < 2:
		_box(Vector3(WIDTH * CELL / 2 - CELL / 2, 3.2 if level_index == 0 else 4.3, HEIGHT * CELL / 2 - CELL / 2), Vector3(WIDTH * CELL, 0.3, HEIGHT * CELL), ceiling_mat, false)
	for z in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, z)
			if grid[z][x] == "O":
				var altar := level_index == 0 and cell == Vector2i(20, 14)
				if level_index == 2:
					_box(at(cell) + Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 0.6), crypt_stone)
					_box(at(cell) + Vector3(0, 0.2, 0.8), Vector3(1.4, 0.4, 2.0), crypt_stone, false)
				else:
					_box(at(cell) + Vector3(0, 0.55 if altar else 2.0, 0), Vector3(2.1, 1.1 if altar else 4.0, 2.1), chapel_stone if altar else crypt_stone)
				if altar: _box(at(cell) + Vector3(0, 1.13, 0), Vector3(2.3, 0.12, 2.3), _color_material(Color("713e48")), false)
			if grid[z][x] == "#":
				var exposed := false
				for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = cell + delta
					if inside(n) and grid[n.y][n.x] != "#": exposed = true
				if exposed: _box(at(cell) + Vector3(0, 2.1 if level_index == 1 else 1.5, 0), Vector3(CELL, 4.2 if level_index == 1 else 3.0, CELL), (chapel_stone if z >= 10 else crypt_stone) if x >= 13 else stone)
	secret_body = _box(at(SECRET) + Vector3(0, 1.5, 0), Vector3(CELL, 3, CELL), _material("secret"))
	_box(at(EXIT) + Vector3(0, 1.5, 0), Vector3(CELL, 3, 0.45), _material("door"))
	if level_index == 0:
		# Cell bars frame the open doorway without blocking its center.
		for z in [3, 5]:
			for offset in [-0.9, 0.0, 0.9]:
				_box(at(Vector2i(4, z)) + Vector3(-1.55, 1.4, offset), Vector3(0.12, 2.8, 0.12), _color_material(Color("4b5559")), false)
		_box(at(Vector2i(1, 3)) + Vector3(0, 0.23, 0), Vector3(1.8, 0.4, 0.8), _color_material(Color("625440")), false)
		_box(at(Vector2i(5, 4)) + Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.7), _material("door"), false)
		_sign(Vector2i(7, 2), "HOLDING CELLS\nKEEP QUIET", Vector3(0, 2.15, -1.42))
		_sign(Vector2i(15, 2), "THE OSSUARY", Vector3(0, 2.25, -1.42))
		_sign(Vector2i(16, 11), "WARDEN’S CHAPEL", Vector3(0, 2.3, -1.42))
		_sign(Vector2i(6, 17), "STAIRS TO THE CASTLE\nBRASS KEY REQUIRED", Vector3(0, 2.4, 1.4), PI)
		_sign(Vector2i(5, 12), "A DRAFT THROUGH\nTHE CRACKED STONE…", Vector3(-1.42, 2.0, 0), PI / 2)
		for cell in [Vector2i(6, 2), Vector2i(10, 6), Vector2i(14, 2), Vector2i(21, 6), Vector2i(9, 9), Vector2i(6, 11), Vector2i(12, 16), Vector2i(16, 11), Vector2i(22, 16), Vector2i(18, 9), Vector2i(2, 10)]: _torch(cell)
		_spawn_pickup("pistol", Vector2i(5, 4), 0.85)
		for cell in [Vector2i(10, 2), Vector2i(14, 6), Vector2i(20, 12), Vector2i(11, 16), Vector2i(2, 11)]: _spawn_pickup("ammo", cell)
		for cell in [Vector2i(14, 3), Vector2i(10, 12), Vector2i(21, 16), Vector2i(2, 12)]: _spawn_pickup("health", cell)
		_spawn_pickup("key", Vector2i(21, 14))
		_spawn_enemy("guard", Vector2i(6, 4), true)
		for cell in [Vector2i(9, 3), Vector2i(14, 5), Vector2i(18, 3), Vector2i(20, 6), Vector2i(10, 11), Vector2i(6, 14), Vector2i(11, 16), Vector2i(16, 14), Vector2i(21, 15)]: _spawn_enemy("skeleton", cell)
		for cell in [Vector2i(20, 3), Vector2i(19, 12), Vector2i(17, 16)]: _spawn_enemy("caster", cell)
	else:
		_build_chapter_content()
	player_body = CharacterBody3D.new()
	player_body.collision_layer = 4
	player_body.collision_mask = 3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.5
	shape.shape = capsule
	shape.position.y = 0.85
	player_body.add_child(shape)
	world.add_child(player_body)
	player_body.position = at(START)
	camera = Camera3D.new()
	camera.position.y = 1.48
	camera.fov = 78
	camera.far = 85
	camera.near = 0.06
	player_body.add_child(camera)
	player_body.rotation.y = -PI / 2 if level_index == 0 else float(level_data.yaw)
	camera.current = true
	_discover()

func at(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0, cell.y * CELL)

func tile(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / CELL), roundi(pos.z / CELL))

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < HEIGHT

func walkable(cell: Vector2i) -> bool:
	return inside(cell) and grid[cell.y][cell.x] == "."

func _material(kind: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = textures[kind]
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	return m

func _color_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

func _box(pos: Vector3, dimensions: Vector3, mat: Material, solid: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1 if solid else 0
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = dimensions
	mesh.mesh = cube
	mesh.material_override = mat
	body.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)
	world.add_child(body)
	return body

func _sprite(kind: String, pos: Vector3, scale_pixels: float = 0.03) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = textures[kind]
	sprite.pixel_size = scale_pixels
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = pos
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	world.add_child(sprite)
	return sprite

func _sign(cell: Vector2i, text: String, offset: Vector3, yaw: float = 0.0) -> void:
	var sign_label := Label3D.new()
	sign_label.text = text
	sign_label.font_size = 42
	sign_label.pixel_size = 0.003
	sign_label.modulate = GOLD
	sign_label.outline_size = 7
	sign_label.position = at(cell) + offset
	sign_label.rotation.y = yaw
	world.add_child(sign_label)

func _torch(cell: Vector2i) -> void:
	_sprite("torch", at(cell) + Vector3(0, 2.1, -1.25), 0.018)
	var light := OmniLight3D.new()
	light.position = at(cell) + Vector3(0, 2.2, -0.8)
	light.light_color = Color("ffa65c")
	light.light_energy = 1.4
	light.omni_range = 7.5
	world.add_child(light)
	torches.append(light)

func _spawn_pickup(kind: String, cell: Vector2i, elevation: float = 0.55) -> void:
	var sprite := _sprite(kind, at(cell) + Vector3(0, elevation, 0), 0.023)
	pickups.append({"kind": kind, "node": sprite, "base_y": elevation, "taken": false})

func _spawn_enemy(kind: String, cell: Vector2i, asleep: bool = false) -> void:
	var boss := kind in ["warden", "regent"]
	var max_hp: int = {"warden": 850, "regent": 1250, "gargoyle": 80, "caster": 90}.get(kind, 65)
	var body := StaticBody3D.new()
	body.position = at(cell)
	body.collision_layer = 2
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.64 if boss else 0.42
	capsule.height = 2.8 if boss else 1.9
	collision.shape = capsule
	collision.position.y = 1.4 if boss else 0.95
	body.add_child(collision)
	world.add_child(body)
	var sprite := _sprite(kind, Vector3.ZERO, 0.047 if boss else 0.033)
	world.remove_child(sprite)
	body.add_child(sprite)
	sprite.position = Vector3(0, 1.04, 0)
	var sleep_sign := Label3D.new()
	sleep_sign.text = "z  Z  z"
	sleep_sign.font_size = 48
	sleep_sign.pixel_size = 0.006
	sleep_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sleep_sign.position.y = 2.3
	sleep_sign.modulate = GOLD
	sleep_sign.visible = asleep
	body.add_child(sleep_sign)
	if asleep:
		sprite.modulate = Color("81948a")
	var enemy := {"kind": kind, "node": body, "sprite": sprite, "hp": max_hp, "max_hp": max_hp, "boss": boss, "state": "hunt", "timer": 0.0, "charge_direction": Vector3.ZERO, "summoned": false, "volley": 0, "sleeping": asleep, "active": false, "cooldown": 1.2, "pain": 0.0, "windup": 0.0, "last_seen": at(cell), "sleep_sign": sleep_sign, "path": [], "path_timer": 0.0}
	body.set_meta("enemy_index", enemies.size())
	enemies.append(enemy)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if phase == "playing": _set_menu("paused")
			elif phase == "paused": _set_menu("playing")
			else: _back()
			return
		if phase == "playing":
			match event.physical_keycode:
				KEY_E: interact()
				KEY_F: fire(true)
				KEY_1: select_weapon("pistol")
				KEY_2: select_weapon("blunderbuss")
				KEY_3: select_weapon("rune")
				KEY_TAB: show_map = not show_map
				KEY_BRACKETLEFT:
					sensitivity = maxf(0.0006, sensitivity - 0.0003)
					announce("Mouse sensitivity: %d" % roundi(sensitivity * 10000))
				KEY_BRACKETRIGHT:
					sensitivity = minf(0.006, sensitivity + 0.0003)
					announce("Mouse sensitivity: %d" % roundi(sensitivity * 10000))
			get_viewport().set_input_as_handled()
	if phase != "playing": return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player_body.rotation.y -= event.relative.x * sensitivity
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, -0.45, 0.45)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: fire()
		elif event.button_index == MOUSE_BUTTON_RIGHT: fire(true)

func _physics_process(delta: float) -> void:
	if phase != "playing": return
	elapsed += delta
	cooldown = maxf(0, cooldown - delta)
	flash = maxf(0, flash - delta)
	hurt_flash = maxf(0, hurt_flash - delta)
	hit_flash = maxf(0, hit_flash - delta)
	message_time = maxf(0, message_time - delta)
	var right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var backward := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var forward := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var move := Vector2(float(right) - float(left), float(backward) - float(forward)).normalized()
	var direction := player_body.transform.basis * Vector3(move.x, 0, move.y)
	player_body.velocity = direction * 5.3
	player_body.move_and_slide()
	player_body.position.y = 0
	if move.length() > 0: bob += delta * 10
	camera.position.y = 1.48 + sin(bob) * 0.025 * move.length()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): fire()
	_collect_pickups()
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_blood(delta)
	wake_clock += delta
	if wake_clock > 0.2:
		wake_clock = 0
		_discover()
	for i in torches.size(): torches[i].light_energy = 1.25 + sin(elapsed * 7 + i * 1.7) * 0.15
	for item in pickups:
		if not item.taken: item.node.position.y = item.base_y + sin(elapsed * 2.5) * 0.055

func _process(_delta: float) -> void:
	if is_instance_valid(hud): hud.queue_redraw()
	if is_instance_valid(ambience):
		ambience.volume_db = -27 if phase == "playing" and _sound_enabled() else -80

func objective() -> String:
	if level_index == 1:
		if not has_key: return "Find the silver seal in the forbidden library."
		if boss_alive(): return "Defeat the Iron Warden in the throne hall."
		return "Unlock the portcullis in the northeast."
	if level_index == 2:
		if switches_on() < 2: return "Raise the two watchtower winches (%d / 2)." % switches_on()
		if boss_alive(): return "Defeat the Grave Regent. Take the gate seal."
		return "Open the northern gate. Cross the drawbridge."
	if not armed: return "Take the guard’s pistol outside your cell."
	if not has_key: return "Find the brass key in the Warden’s Chapel."
	return "Use the brass key at the castle stair gate."

func announce(text: String, seconds: float = 3.0) -> void:
	message = text
	message_time = seconds

func _collect_pickups() -> void:
	for item in pickups:
		if item.taken: continue
		var position_3d: Vector3 = item.node.position
		position_3d.y = 0
		if player_body.position.distance_to(position_3d) > 1.25: continue
		if item.kind == "health" and health == 100: continue
		item.taken = true
		item.node.visible = false
		match item.kind:
			"pistol":
				armed = true
				ammo += 24
				announce("GUARD’S PISTOL  +24 rounds  •  Left click to fire", 5)
			"blunderbuss", "rune":
				if item.kind not in weapons: weapons.append(item.kind)
				weapon = item.kind
				armed = true
				ammo += 24
				announce(weapon_name() + "  +24 rounds  •  1 / 2 / 3 to switch", 5)
			"ammo":
				ammo += 16
				announce("AMMUNITION  +16 rounds")
			"health":
				health = mini(100, health + 35)
				announce("FIELD DRESSING  +35 health")
			"key":
				has_key = true
				announce("BRASS KEY  •  Return to the stair gate in the southwest." if level_index == 0 else key_name() + " ACQUIRED  •  " + objective(), 6)
		_sound("pickup")

func interaction_target() -> String:
	var pos := player_body.position
	var forward := -player_body.global_basis.z
	var entries := [{"cell": SECRET, "id": "secret"}, {"cell": EXIT, "id": "exit"}]
	for i in switches.size(): entries.append({"cell": switches[i].cell, "id": "switch:" + str(i)})
	for entry in entries:
		var offset: Vector3 = at(entry.cell) - pos
		if offset.length() < 3.3 and forward.dot(offset.normalized()) > 0.45:
			if entry.id == "secret" and secret_found: continue
			return entry.id
	return ""

func interact() -> void:
	if phase != "playing": return
	var target := interaction_target()
	if target.begins_with("switch:"):
		var index := int(target.get_slice(":", 1))
		if not switches[index].on:
			switches[index].on = true
			switches[index].node.rotation.z = -0.8
			_sound("door")
			announce(switches[index].name + " RAISED  •  %d / 2 winches" % switches_on(), 4)
			if switches_on() == 2 and is_instance_valid(bridge): bridge.rotation.x = 0
		else: announce("This winch is already raised.")
		return
	match target:
		"secret":
			secret_found = true
			grid[SECRET.y][SECRET.x] = "."
			navigation.set_point_solid(SECRET, false)
			secret_body.collision_layer = 0
			secret_body.visible = false
			announce("SECRET FOUND  •  The guard’s private supply stash.", 5)
			_sound("door")
		"exit":
			if not has_key or boss_alive() or (level_index == 2 and switches_on() < 2):
				announce(objective(), 4)
				_sound("empty")
			else: finish_level()
		_:
			announce("Nothing to use here. Search cracked stone for secrets.", 2)

func select_weapon(id: String) -> void:
	if id in weapons:
		weapon = id
		announce(weapon_name())
	else: announce("You haven’t found that weapon yet.")

func weapon_name() -> String:
	return {"pistol": "GUARD’S PISTOL", "blunderbuss": "BLUNDERBUSS", "rune": "RUNE CASTER"}[weapon]

func fire(force_melee: bool = false) -> void:
	if phase != "playing" or cooldown > 0: return
	var cost := 1 if weapon == "pistol" else 3
	# A nearly empty heavy weapon still leaves the last rounds usable in the pistol.
	if not force_melee and ammo > 0 and ammo < cost: weapon = "pistol"; cost = 1
	var melee := force_melee or not armed or ammo <= 0
	melee_swing = melee
	cooldown = 0.52 if melee else {"pistol": 0.29, "blunderbuss": 0.85, "rune": 0.65}[weapon]
	flash = 0.22 if melee else 0.12
	if not melee:
		ammo -= cost
		shots += 1
		_sound("magic" if weapon == "rune" else "shot")
	else:
		_sound("swing")
		if armed and ammo == 0: announce("OUT OF AMMO  •  Get close to strike. Search for ammo crates.", 2)
	var from := camera.global_position
	var reach := 2.15 if melee else (18.0 if weapon == "blunderbuss" else 65.0)
	var pellets := 5 if weapon == "blunderbuss" and not melee else 1
	var connected := false
	for pellet in pellets:
		var direction := -camera.global_basis.z
		if pellets > 1: direction = direction.rotated(Vector3.UP, (pellet - 2) * 0.035)
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * reach, 3)
		var result := world.get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty() and result.collider.has_meta("enemy_index"):
			var index: int = result.collider.get_meta("enemy_index")
			damage_enemy(index, 40 if melee else {"pistol": 34, "blunderbuss": 28, "rune": 115}[weapon])
			connected = true
			hit_flash = 0.14
	if connected and not melee: hits += 1
	# Gunfire wakes nearby monsters, even when the first shot misses.
	for enemy in enemies:
		if enemy.hp > 0 and enemy.node.position.distance_to(player_body.position) < (6.0 if melee else 18.0):
			enemy.sleeping = false
			enemy.active = true
			enemy.last_seen = player_body.position

func damage_enemy(index: int, damage: int) -> void:
	var enemy := enemies[index]
	if enemy.hp <= 0: return
	enemy.hp -= damage
	enemy.pain = 0.0 if enemy.boss else 0.18
	enemy.sleeping = false
	enemy.active = true
	enemy.last_seen = player_body.position
	enemy.sprite.modulate = Color("ff8172")
	enemy.sleep_sign.visible = false
	_blood(enemy.node.position + Vector3(0, 1.2, 0))
	_sound("hit")
	if enemy.hp <= 0:
		kills += 1
		enemy.node.collision_layer = 0
		enemy.sprite.texture = textures.corpse
		enemy.sprite.position.y = 0.88
		enemy.sprite.pixel_size = 0.03
		enemy.sprite.modulate = Color.WHITE
		enemy.sprite.rotation.z = 0
		enemy.sprite.scale = Vector3.ONE
		_sound("death")
		if enemy.boss:
			if enemy.kind == "regent": has_key = true
			announce(("GATE SEAL CLAIMED  •  " if enemy.kind == "regent" else "IRON WARDEN DEFEATED  •  ") + objective(), 6)

func _line_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP, to + Vector3.UP, 1)
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		if enemy.hp <= 0: continue
		var body: StaticBody3D = enemy.node
		var distance := body.position.distance_to(player_body.position)
		var sees := distance < 23 and _line_clear(body.position, player_body.position)
		if enemy.sleeping:
			if distance < 1.9: enemy.sleeping = false
			else: continue
		enemy.sleep_sign.visible = false
		enemy.sprite.rotation.z = 0
		enemy.path_timer -= delta
		enemy.sprite.position.y = 1.48 if enemy.boss else 1.04
		if sees:
			if not enemy.active: _sound("alert")
			enemy.active = true
			enemy.last_seen = player_body.position
		if not enemy.active: continue
		enemy.cooldown = maxf(0, enemy.cooldown - delta * ATTACK_MULTIPLIERS[difficulty])
		enemy.pain = maxf(0, enemy.pain - delta)
		enemy.sprite.modulate = Color("ff8172") if enemy.pain > 0 else Color.WHITE
		if enemy.pain > 0: continue
		if enemy.boss:
			_update_boss(enemy, delta, sees, distance)
			continue
		if enemy.kind == "caster" and sees and distance < 20:
			# Visible windup gives a fair chance to dodge before a projectile flies.
			if enemy.cooldown <= 0:
				enemy.windup += delta * ATTACK_MULTIPLIERS[difficulty]
				enemy.sprite.modulate = Color("b8ff99")
				if enemy.windup > 0.65:
					_spawn_projectile(body.position + Vector3(0, 1.25, 0))
					enemy.windup = 0.0
					enemy.cooldown = 2.3
			if distance > 7 and enemy.windup == 0: _move_enemy(enemy, enemy.last_seen, 1.05 * delta)
		elif distance < 1.35 and sees:
			if enemy.cooldown <= 0:
				take_damage(10)
				enemy.cooldown = 1.1
				enemy.sprite.scale = Vector3(1.14, 1.05, 1)
		else:
			enemy.sprite.scale = Vector3.ONE
			_move_enemy(enemy, enemy.last_seen, (2.35 if enemy.kind == "gargoyle" else (1.6 if enemy.kind == "guard" else 1.35)) * delta)
		if phase != "playing": break

func _move_enemy(enemy: Dictionary, destination: Vector3, step: float) -> void:
	# Route around pillars and corners toward the last seen/heard location.
	if enemy.path_timer <= 0:
		enemy.path_timer = 0.45
		var goal := tile(destination)
		if walkable(goal): enemy.path = navigation.get_id_path(tile(enemy.node.position), goal)
	var waypoint := destination
	if enemy.path.size() > 1:
		waypoint = at(enemy.path[1])
		if enemy.node.position.distance_to(waypoint) < 0.25:
			enemy.path.pop_front()
			if enemy.path.size() > 1: waypoint = at(enemy.path[1])
	var direction: Vector3 = waypoint - enemy.node.position
	direction.y = 0
	if direction.length() < 0.5: return
	var motion: Vector3 = direction.normalized() * step * MOVE_MULTIPLIERS[difficulty]
	var pos: Vector3 = enemy.node.position
	for axis in [0, 2]:
		var candidate := pos
		candidate[axis] += motion[axis]
		var clear := true
		for dx in [-0.43, 0.43]:
			for dz in [-0.43, 0.43]:
				if not walkable(tile(candidate + Vector3(dx, 0, dz))): clear = false
		for other in enemies:
			if other != enemy and other.hp > 0 and candidate.distance_to(other.node.position) < 0.85: clear = false
		if clear: pos = candidate
	enemy.node.position = pos
	enemy.sprite.position.y = (1.48 if enemy.boss else 1.04) + sin(elapsed * 8 + pos.x) * 0.045

func _spawn_projectile(origin: Vector3, angle: float = 0.0, damage: int = 14) -> void:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	sphere.radial_segments = 8
	sphere.rings = 4
	orb.mesh = sphere
	var material := _color_material(Color("b6f77a"))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb.material_override = material
	world.add_child(orb)
	orb.position = origin
	var aim := (player_body.position + Vector3(0, 1, 0) - origin).normalized()
	projectiles.append({"node": orb, "velocity": aim.rotated(Vector3.UP, angle) * 6.2, "life": 5.0, "damage": damage})
	_sound("magic")

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var bolt := projectiles[i]
		var old: Vector3 = bolt.node.position
		var next: Vector3 = old + bolt.velocity * delta
		var query := PhysicsRayQueryParameters3D.create(old, next, 5)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		bolt.life -= delta
		if not hit.is_empty() or bolt.life <= 0:
			if not hit.is_empty() and hit.collider == player_body: take_damage(bolt.damage)
			bolt.node.queue_free()
			projectiles.remove_at(i)
		else: bolt.node.position = next

func _blood(origin: Vector3) -> void:
	for i in 7:
		var fleck := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * (0.04 + i * 0.008)
		fleck.mesh = mesh
		var material := _color_material(Color("ad4039") if i % 2 else Color("6e292d"))
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fleck.material_override = material
		world.add_child(fleck)
		fleck.position = origin
		blood_particles.append({"node": fleck, "velocity": Vector3(sin(i * 2.3) * 2.1, 1.0 + i * 0.15, cos(i * 2.3) * 2.1), "life": 0.55})

func _update_blood(delta: float) -> void:
	for i in range(blood_particles.size() - 1, -1, -1):
		var fleck := blood_particles[i]
		fleck.life -= delta
		fleck.velocity.y -= delta * 7
		fleck.node.position += fleck.velocity * delta
		if fleck.life <= 0:
			fleck.node.queue_free()
			blood_particles.remove_at(i)

func take_damage(amount: int) -> void:
	if phase != "playing": return
	health = maxi(0, health - amount)
	hurt_flash = 0.3
	_sound("hurt")
	if health == 0: _set_menu("dead")

func _discover() -> void:
	var here := tile(player_body.position)
	for z in range(here.y - 3, here.y + 4):
		for x in range(here.x - 3, here.x + 4):
			if inside(Vector2i(x, z)): discovered[Vector2i(x, z)] = true
	if level_index > 0:
		map_title = chapter_name()
		for zone in level_data.zones:
			if zone[0].has_point(here): map_title = zone[1]; break
		return
	if here.x >= 15 and here.y >= 11: map_title = "WARDEN’S CHAPEL"
	elif here.x >= 13 and here.y <= 8: map_title = "THE OSSUARY"
	elif here.y >= 10: map_title = "THE LOWER CISTERN"
	else: map_title = "THE HOLDING CELLS"

func _sound_enabled() -> bool:
	var parent := get_parent()
	return bool(parent.get("sound_enabled")) if parent != null and "sound_enabled" in parent else true

func _make_audio() -> void:
	for kind in ["shot", "swing", "hit", "death", "pickup", "hurt", "magic", "alert", "door", "empty", "ambient"]:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var duration := 0.2
		if kind in ["death", "door", "alert"]: duration = 0.45
		if kind == "ambient": duration = 4.0
		var count := int(22050 * duration)
		var data := PackedByteArray()
		data.resize(count * 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 381
		for i in count:
			var t := float(i) / 22050
			var progress := float(i) / count
			var noise := rng.randf_range(-1, 1)
			var sample := 0.0
			match kind:
				"shot": sample = (noise * 0.65 + sin(t * TAU * 65) * 0.35) * pow(1 - progress, 3)
				"swing": sample = noise * sin(progress * PI) * 0.2
				"hit", "hurt": sample = (noise * 0.3 + sin(t * TAU * 110) * 0.5) * (1 - progress)
				"pickup": sample = sin(t * TAU * (660 if progress < 0.5 else 880)) * sin(progress * PI) * 0.3
				"magic": sample = sin(t * TAU * (350 - progress * 180)) * (1 - progress) * 0.4
				"death", "alert": sample = (sin(t * TAU * (80 - progress * 30)) + noise * 0.25) * sin(progress * PI) * 0.4
				"door": sample = noise * 0.25 * sin(progress * PI) + sin(t * TAU * 45) * 0.2 * (1 - progress)
				"empty": sample = noise * pow(1 - progress, 12) * 0.3
				"ambient": sample = sin(t * TAU * 55) * 0.2 + sin(t * TAU * 82.5) * 0.07 + sin(t * TAU * 110) * 0.04
			data.encode_s16(i * 2, int(clampf(sample, -1, 1) * 20000))
		wav.data = data
		if kind == "ambient":
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = count
		sounds[kind] = wav
	for i in 8:
		var audio := AudioStreamPlayer.new()
		audio.volume_db = -10
		add_child(audio)
		audio_players.append(audio)
	ambience = AudioStreamPlayer.new()
	ambience.stream = sounds.ambient
	ambience.volume_db = -80
	add_child(ambience)
	ambience.play()

func _sound(kind: String) -> void:
	if not _sound_enabled(): return
	for audio in audio_players:
		if not audio.playing:
			audio.stream = sounds[kind]
			audio.play()
			break

func _text(text: String, pos: Vector2, font_size: int, color: Color = PALE) -> void:
	hud.draw_string(ThemeDB.fallback_font, pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("0a1014"))
	hud.draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_hud() -> void:
	if not is_instance_valid(player_body): return
	hud.draw_set_transform(Vector2.ZERO, 0, size / Vector2(1200, 800))
	# Thin letterbox, chapter identifier, and a heavy brass-edged status strip.
	hud.draw_rect(Rect2(0, 0, 1200, 70), Color("0c131ae8"))
	_text("MONSTER BLAST", Vector2(28, 32), 23, GOLD)
	_text(["I", "II", "III"][level_index] + " / " + map_title + " / " + DIFFICULTIES[difficulty].to_upper(), Vector2(28, 55), 14, Color("9fa99f"))
	_text(objective(), Vector2(430, 35), 18)
	_text("TAB  map     ESC  pause", Vector2(944, 59), 15, Color("929c99"))
	if phase in ["playing", "paused"]:
		_draw_weapon()
		var cross := Color("fff2d1") if hit_flash <= 0 else Color("f29e73")
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			hud.draw_line(Vector2(600, 400) + direction * 5, Vector2(600, 400) + direction * 12, cross, 2)
		var target := interaction_target()
		if target != "":
			var prompt := "E  Search cracked stone" if target == "secret" else ("E  Use winch" if target.begins_with("switch:") else "E  Open exit gate")
			_text(prompt, Vector2(440, 490), 22, GOLD)
		if message_time > 0:
			hud.draw_rect(Rect2(80, 636, 1040, 42), Color("101820dd"))
			_text(message, Vector2(100, 665), 21, GOLD)
	hud.draw_rect(Rect2(0, 700, 1200, 100), Color("141c23"))
	hud.draw_rect(Rect2(0, 700, 1200, 3), Color("7d6646"))
	for x in [260, 510, 790, 1010]: hud.draw_line(Vector2(x, 722), Vector2(x, 781), Color("39413e"), 2)
	_text("HEALTH", Vector2(30, 731), 15, Color("9fa99f"))
	_text("%03d" % health, Vector2(30, 775), 40, Color("da8273") if health < 35 else PALE)
	hud.draw_rect(Rect2(131, 752, 100, 10), Color("343732"))
	hud.draw_rect(Rect2(131, 752, health, 10), Color("a34a43"))
	_text("ROUNDS", Vector2(290, 731), 15, Color("9fa99f"))
	_text("%03d" % ammo, Vector2(290, 775), 40, GOLD)
	_text("F  melee", Vector2(392, 766), 16)
	_text("EQUIPPED", Vector2(540, 731), 15, Color("9fa99f"))
	_text(weapon_name() if armed else "BARE KNUCKLES", Vector2(540, 769), 22)
	_text(key_name(), Vector2(820, 731), 15, Color("9fa99f"))
	_text("ACQUIRED" if has_key else "MISSING", Vector2(820, 769), 22, GOLD if has_key else Color("687674"))
	_text("MONSTERS", Vector2(1040, 731), 15, Color("9fa99f"))
	_text("%02d / %02d" % [kills, enemies.size()], Vector2(1040, 769), 25)
	_draw_boss_hud()
	if hurt_flash > 0: hud.draw_rect(Rect2(0, 70, 1200, 630), Color(0.6, 0.05, 0.04, hurt_flash * 0.8))
	if show_map and phase == "playing": _draw_map()
	if phase != "playing": hud.draw_rect(Rect2(0, 0, 1200, 800), Color(0.01, 0.02, 0.03, 0.55))

func _draw_weapon() -> void:
	var sway := sin(bob) * 6
	var kick := flash * 125
	var origin := Vector2(600 + sway, 705 + kick)
	if melee_swing and flash > 0 or not armed:
		origin += Vector2(90 - flash * 300, -flash * 350)
		hud.draw_rect(Rect2(origin + Vector2(-24, -83), Vector2(105, 100)), Color("493b35"))
		hud.draw_rect(Rect2(origin + Vector2(-33, -145), Vector2(87, 82)), Color("b58869"))
		for x in 4: hud.draw_rect(Rect2(origin + Vector2(-28 + x * 21, -151), Vector2(17, 37)), Color("c49a76"))
		return
	if weapon != "pistol":
		_draw_heavy_weapon(origin)
		return
	# Hand and pistol silhouette. All hard edges deliberately retain the retro look.
	hud.draw_colored_polygon(PackedVector2Array([origin + Vector2(-85, 0), origin + Vector2(-47, -100), origin + Vector2(34, -120), origin + Vector2(100, 0)]), Color("513e34"))
	hud.draw_rect(Rect2(origin + Vector2(-41, -103), Vector2(88, 102)), Color("ae8061"))
	hud.draw_rect(Rect2(origin + Vector2(-29, -133), Vector2(60, 93)), Color("3a3330"))
	hud.draw_rect(Rect2(origin + Vector2(-21, -128), Vector2(18, 76)), Color("72513a"))
	hud.draw_colored_polygon(PackedVector2Array([origin + Vector2(-43, -87), origin + Vector2(-29, -230), origin + Vector2(29, -230), origin + Vector2(43, -87)]), Color("202b32"))
	hud.draw_rect(Rect2(origin + Vector2(-25, -225), Vector2(50, 120)), Color("637375"))
	hud.draw_rect(Rect2(origin + Vector2(-17, -215), Vector2(34, 105)), Color("85918b"))
	hud.draw_rect(Rect2(origin + Vector2(-12, -201), Vector2(24, 70)), Color("38464c"))
	hud.draw_rect(Rect2(origin + Vector2(-4, -239), Vector2(8, 20)), Color("b5b79d"))
	hud.draw_rect(Rect2(origin + Vector2(-29, -118), Vector2(58, 14)), Color("a2a997"))
	if flash > 0 and not melee_swing:
		hud.draw_colored_polygon(PackedVector2Array([origin + Vector2(-12, -238), origin + Vector2(-50, -272), origin + Vector2(-16, -267), origin + Vector2(0, -318), origin + Vector2(18, -265), origin + Vector2(48, -282), origin + Vector2(13, -233)]), Color("ffba58"))
		hud.draw_rect(Rect2(origin + Vector2(-9, -276), Vector2(18, 43)), Color("fff2bb"))

func _draw_map() -> void:
	hud.draw_rect(Rect2(335, 105, 530, 555), Color("0b131bf2"))
	_text(["DUNGEON MAP", "CASTLE MAP", "GROUNDS MAP"][level_index], Vector2(360, 140), 25, GOLD)
	_text("Explore to reveal  •  You are the red arrow", Vector2(360, 166), 16)
	var offset := Vector2(375, 188)
	var cell_size := minf(18.0, 450.0 / WIDTH)
	for cell in discovered:
		var c := Color("48534f") if walkable(cell) else Color("252e32")
		if cell == EXIT: c = GOLD
		if cell == SECRET and secret_found: c = Color("77a58a")
		hud.draw_rect(Rect2(offset + Vector2(cell) * cell_size, Vector2.ONE * (cell_size - 1)), c)
	for item in pickups:
		if not item.taken and item.kind == "key" and discovered.has(tile(item.node.position)):
			hud.draw_circle(offset + Vector2(tile(item.node.position)) * cell_size + Vector2.ONE * 8, 5, GOLD)
	for lever in switches:
		if discovered.has(lever.cell): hud.draw_circle(offset + Vector2(lever.cell) * cell_size + Vector2.ONE * cell_size / 2, 4, Color("76d0ab") if lever.on else Color("cc754e"))
	var p := offset + Vector2(player_body.position.x, player_body.position.z) / CELL * cell_size + Vector2.ONE * 8
	var forward := Vector2(-sin(player_body.rotation.y), -cos(player_body.rotation.y))
	hud.draw_circle(p, 5, Color("ef846d"))
	hud.draw_line(p, p + forward * 14, Color("ef846d"), 3)
	_text("Gold: exit / key   Orange: winch   TAB close", Vector2(360, 620), 16, GOLD)

func _build_chapter_content() -> void:
	for cell in level_data.torches: _torch(cell)
	for item in level_data.pickups: _spawn_pickup(item[0], Vector2i(item[1], item[2]))
	for enemy in level_data.enemies: _spawn_enemy(enemy[0], Vector2i(enemy[1], enemy[2]))
	for sign_data in level_data.signs:
		_sign(Vector2i(sign_data[0], sign_data[1]), sign_data[2], Vector3(0, 2.5, -1.40))
	_sign(SECRET + Vector2i.RIGHT, "A DRAFT THROUGH\nTHE CRACKED STONE…", Vector3(-1.42, 2.0, 0), PI / 2)
	for lever in level_data.switches:
		var pos: Vector3 = at(lever[0])
		_box(pos + Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 0.7), _material("stone"), false)
		var handle := _box(pos + Vector3(0, 1.3, 0), Vector3(0.16, 1.1, 0.16), _color_material(GOLD), false)
		switches.append({"cell": lever[0], "name": lever[1], "on": false, "node": handle})
		_sign(lever[0], lever[1] + "\nE  RAISE", Vector3(0, 2.3, 0))
	if level_index == 1:
		# Banners, shelves, feasting tables and a raised throne distinguish rooms.
		for cell in [Vector2i(18,9),Vector2i(27,9),Vector2i(22,2)]:
			_box(at(cell) + Vector3(0, 2.5, -1.35), Vector3(1.2, 2.7, 0.07), _color_material(Color("713847")), false)
			_box(at(cell) + Vector3(0, 2.7, -1.29), Vector3(0.2, 1.3, 0.08), _color_material(GOLD), false)
		for x in range(9, 15):
			_box(at(Vector2i(x,2)) + Vector3(0, 1.2, -1.15), Vector3(2.8, 2.4, 0.4), _material("door"), false)
			for book in 7:
				_box(at(Vector2i(x,2)) + Vector3(-1.1 + book * 0.35, 1.4, -0.89), Vector3(0.2, 0.65, 0.15), _color_material([Color("71534d"), Color("637667"), Color("9a8a64")][book % 3]), false)
		for cell in [Vector2i(16,22),Vector2i(23,22)]:
			_box(at(cell) + Vector3(0, 1.1, 0), Vector3(2.8, 0.2, 2.8), _material("door"), false)
		_box(at(Vector2i(23,9)) + Vector3(0, 0.3, -0.6), Vector3(3.0, 0.6, 1.8), _material("stone"), false)
		_box(at(Vector2i(23,9)) + Vector3(0, 1.7, -0.8), Vector3(1.4, 2.8, 0.5), _color_material(Color("7b414b")), false)
	else:
		var moon := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 3.0
		sphere.height = 6.0
		moon.mesh = sphere
		var moon_mat := _color_material(Color("d0d8b8"))
		moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon.material_override = moon_mat
		moon.position = Vector3(55, 27, -15)
		world.add_child(moon)
		var moonlight := DirectionalLight3D.new()
		moonlight.rotation_degrees = Vector3(-45, -30, 0)
		moonlight.light_color = Color("8fa8ca")
		moonlight.light_energy = 0.45
		world.add_child(moonlight)
		for cell in [Vector2i(8,2),Vector2i(15,2),Vector2i(17,26),Vector2i(24,26),Vector2i(29,2),Vector2i(35,2)]:
			_box(at(cell) + Vector3(0, 3.5, 0), Vector3(3.0, 7, 3), _material("stone"), false)
			for x in [-1, 1]: _box(at(cell) + Vector3(x, 7.4, 0), Vector3(0.8, 1.2, 3), _material("stone"), false)
		bridge = Node3D.new()
		world.add_child(bridge)
		bridge.position = at(EXIT) + Vector3(0, 0.05, -1.6)
		var plank := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(3.0, 0.25, 10)
		plank.mesh = plank_mesh
		plank.material_override = _material("door")
		plank.position.z = -5
		bridge.add_child(plank)
		bridge.rotation.x = PI / 2

func switches_on() -> int:
	var count := 0
	for lever in switches:
		if lever.on: count += 1
	return count

func boss_alive() -> bool:
	for enemy in enemies:
		if enemy.boss and enemy.hp > 0: return true
	return false

func _update_boss(enemy: Dictionary, delta: float, sees: bool, distance: float) -> void:
	var rate: float = ATTACK_MULTIPLIERS[difficulty]
	var enraged: bool = enemy.hp <= enemy.max_hp / 2
	var body: StaticBody3D = enemy.node
	if enemy.kind == "warden":
		match enemy.state:
			"windup":
				enemy.sprite.modulate = Color("ffc575")
				enemy.timer -= delta * rate
				if enemy.timer <= 0:
					enemy.state = "charge"
					enemy.timer = 1.2
					_sound("alert")
			"charge":
				enemy.sprite.modulate = Color("ff9875")
				enemy.timer -= delta
				var motion: Vector3 = enemy.charge_direction * 9.0 * MOVE_MULTIPLIERS[difficulty] * delta
				var sweep := PhysicsShapeQueryParameters3D.new()
				sweep.shape = body.get_child(0).shape
				sweep.transform = body.get_child(0).global_transform
				sweep.motion = motion
				sweep.collision_mask = 1
				sweep.margin = 0.02
				var travel := world.get_world_3d().direct_space_state.cast_motion(sweep)
				body.position += motion * travel[0]
				if travel[0] < 1.0: enemy.timer = 0.0
				if body.position.distance_to(player_body.position) < 1.55:
					take_damage(24)
					enemy.timer = 0.0
				if enemy.timer <= 0:
					enemy.state = "recover"
					enemy.timer = 1.7
			"recover":
				enemy.sprite.modulate = Color("8eaaa3")
				enemy.timer -= delta * rate
				if enemy.timer <= 0:
					enemy.state = "hunt"
					enemy.cooldown = 0.6 if enraged else 1.2
			_:
				if sees and distance < 18 and enemy.cooldown <= 0:
					enemy.state = "windup"
					enemy.timer = 0.8 if enraged else 1.1
					enemy.charge_direction = (player_body.position - body.position).normalized()
					announce("IRON WARDEN  •  Sidestep the charge. Strike while he recovers.", 3)
				else: _move_enemy(enemy, enemy.last_seen, 1.5 * delta)
	else:
		if enraged and not enemy.summoned:
			enemy.summoned = true
			for cell in level_data.summons: _spawn_enemy("gargoyle", cell)
			announce("THE REGENT CALLS HIS GARGOYLES  •  Keep moving!", 4)
			_sound("alert")
		if enemy.state == "windup":
			enemy.sprite.modulate = Color("9fffe0")
			enemy.timer -= delta * rate
			if enemy.timer <= 0:
				var count := 5 if enraged else 3
				for i in count:
					_spawn_projectile(body.position + Vector3(0, 1.3, 0), (i - (count - 1) / 2.0) * 0.19, 18)
				enemy.volley += 1
				enemy.state = "hunt"
				enemy.cooldown = 1.5 if enraged else 2.4
		elif sees and distance < 28 and enemy.cooldown <= 0:
			enemy.state = "windup"
			enemy.timer = 0.8 if enraged else 1.15
		else:
			if distance > 9 or not sees: _move_enemy(enemy, enemy.last_seen, 1.1 * delta)

func _draw_boss_hud() -> void:
	if phase != "playing": return
	for enemy in enemies:
		if not enemy.boss or enemy.hp <= 0 or not enemy.active: continue
		if enemy.node.position.distance_to(player_body.position) > 35: continue
		var name_text := "IRON WARDEN" if enemy.kind == "warden" else "GRAVE REGENT"
		if enemy.hp <= enemy.max_hp / 2: name_text += "  /  ENRAGED"
		_text(name_text, Vector2(400, 103), 19, GOLD)
		hud.draw_rect(Rect2(400, 112, 400, 12), Color("1d242b"))
		hud.draw_rect(Rect2(400, 112, 400.0 * maxf(0, enemy.hp) / enemy.max_hp, 12), Color("a9544e"))
		var hint := "Orange: dodge the charge. Blue: recovery window." if enemy.kind == "warden" else "Dodge the fan of spells. Watch for gargoyles at half health."
		_text(hint, Vector2(360, 146), 16)
		break

func _draw_heavy_weapon(origin: Vector2) -> void:
	hud.draw_colored_polygon(PackedVector2Array([origin + Vector2(-95, 0), origin + Vector2(-60, -110), origin + Vector2(55, -110), origin + Vector2(100, 0)]), Color("9f775c"))
	if weapon == "blunderbuss":
		hud.draw_rect(Rect2(origin + Vector2(-42, -150), Vector2(84, 160)), Color("6a4636"))
		hud.draw_colored_polygon(PackedVector2Array([origin + Vector2(-48,-80),origin + Vector2(-68,-210),origin + Vector2(68,-210),origin + Vector2(48,-80)]), Color("8f805e"))
		hud.draw_rect(Rect2(origin + Vector2(-58, -210), Vector2(116, 22)), Color("c8b27a"))
		hud.draw_rect(Rect2(origin + Vector2(-44, -205), Vector2(88, 12)), Color("222d30"))
		for y in [-150,-110]: hud.draw_rect(Rect2(origin + Vector2(-52,y),Vector2(104,10)),Color("beb48b"))
	else:
		hud.draw_rect(Rect2(origin + Vector2(-26,-160),Vector2(52,160)),Color("816348"))
		hud.draw_rect(Rect2(origin + Vector2(-36,-175),Vector2(72,90)),Color("5e5470"))
		for y in [-160,-125]: hud.draw_rect(Rect2(origin + Vector2(-30,y),Vector2(60,8)),GOLD)
		hud.draw_colored_polygon(PackedVector2Array([origin + Vector2(0,-270),origin + Vector2(-30,-210),origin + Vector2(0,-175),origin + Vector2(30,-210)]), Color("97ebd3"))
	if flash > 0 and not melee_swing:
		hud.draw_colored_polygon(PackedVector2Array([origin + Vector2(-40,-225),origin + Vector2(-80,-300),origin + Vector2(-10,-260),origin + Vector2(0,-345),origin + Vector2(25,-265),origin + Vector2(80,-310),origin + Vector2(45,-225)]),Color("b7ffde") if weapon == "rune" else Color("ffcf74"))
