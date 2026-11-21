extends SceneTree

var failures := 0
var game: Control
var completions := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: print("PASS Monster Blast: " + description)
	else:
		push_error("FAIL Monster Blast: " + description)
		failures += 1
func settle() -> void:
	await physics_frame
	await physics_frame
func place(cell: Vector2i, yaw: float = -PI / 2) -> void:
	game.player_body.position = game.at(cell)
	game.player_body.rotation.y = yaw
	game.camera.rotation.x = 0
	await settle()
func aim(index: int) -> void:
	var delta: Vector3 = game.enemies[index].node.position - game.player_body.position
	game.player_body.rotation.y = atan2(-delta.x, -delta.z)
	game.camera.rotation.x = 0
func shot(melee: bool = false) -> void:
	game.cooldown = 0
	game.fire(melee)
	await settle()
func fresh() -> void:
	game.start_run()
	game.set_physics_process(false)
	await settle()
func route(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var previous := {start: start}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal: break
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + delta
			if game.walkable(next) and not previous.has(next):
				previous[next] = cell
				queue.append(next)
	var result: Array[Vector2i] = []
	if not previous.has(goal): return result
	var current := goal
	while current != start:
		result.push_front(current)
		current = previous[current]
	return result
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await physics_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await physics_frame
func run() -> void:
	game = load("res://games/monster_blast.gd").new()
	root.add_child(game)
	game.completed.connect(func(_data): completions += 1)
	await settle()
	check(game.phase == "intro" and not game.armed and game.health == 100, "opening waits for player and starts unarmed")
	await fresh()
	check(game.enemies.size() == 13 and game.enemies[0].sleeping, "13 monsters with sleeping opening guard")
	for item in game.pickups:
		var cell: Vector2i = game.tile(item.node.position)
		if cell.x > 4: check(not route(game.START, cell).is_empty(), "reachable pickup: " + item.kind + " at " + str(cell))
	check(route(game.START, Vector2i(2, 11)).is_empty(), "secret supplies sealed before discovery")
	await place(Vector2i(5, 4))
	game._collect_pickups()
	check(game.armed and game.ammo == 24, "walking over stool collects pistol and starting ammo")
	game._collect_pickups()
	check(game.ammo == 24, "pickup cannot duplicate ammunition")
	var initial_hp: int = game.enemies[0].hp
	await shot()
	check(game.ammo == 23 and game.enemies[0].hp == initial_hp - 34, "real physics ray hits guard and consumes a round")
	var last_ammo: int = game.ammo
	game.fire()
	check(game.ammo == last_ammo, "weapon cooldown prevents extra shot")
	await shot()
	check(game.kills == 1 and game.enemies[0].node.collision_layer == 0, "two pistol hits kill guard and disable body collision")
	check(game.enemies[1].active, "gunshot alerts nearby skeletons")
	# Walls stop both bullets and vision.
	await place(Vector2i(9, 8))
	aim(2)
	var enemy_hp: int = game.enemies[2].hp
	await shot()
	check(game.enemies[2].hp == enemy_hp, "stone walls block gunfire")
	check(not game._line_clear(game.player_body.position, game.enemies[2].node.position), "monsters cannot see through walls")
	# Melee must be close enough and never consumes ammo.
	await place(Vector2i(9, 3))
	game.player_body.position.x -= 1.5
	await settle()
	aim(1)
	game.ammo = 0
	await shot()
	check(game.enemies[1].hp == 25 and game.ammo == 0 and game.melee_swing, "empty pistol automatically falls back to melee")
	await shot(true)
	check(game.enemies[1].hp <= 0 and game.kills == 2, "explicit melee finishes close enemy")
	await place(Vector2i(14, 3))
	game._collect_pickups()
	var medicine: Dictionary
	for item in game.pickups:
		if item.kind == "health" and game.tile(item.node.position) == Vector2i(14, 3): medicine = item
	check(not medicine.taken, "full health preserves dressing for later")
	game.take_damage(50)
	game._collect_pickups()
	check(game.health == 85 and medicine.taken, "dressing restores 35 health once")
	await place(Vector2i(10, 2))
	game._collect_pickups()
	check(game.ammo == 16, "ammo crate refills empty weapon")
	await place(Vector2i(5, 12), PI / 2)
	await key(KEY_E)
	check(game.secret_found and game.walkable(game.SECRET) and game.secret_body.collision_layer == 0, "E opens cracked wall and disables its collision")
	check(not route(game.START, Vector2i(2, 11)).is_empty(), "secret stash reachable after opening")
	await place(Vector2i(6, 17), PI)
	await key(KEY_E)
	check(not game.won and completions == 0, "stair gate refuses exit without key")
	await key(KEY_ESCAPE)
	check(game.phase == "paused" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape pauses and frees mouse")
	var clock: float = game.elapsed
	var hp: int = game.health
	game._physics_process(3)
	game.fire()
	game.take_damage(10)
	check(game.elapsed == clock and game.health == hp, "pause freezes simulation and prevents damage")
	await key(KEY_ESCAPE)
	check(game.phase == "playing", "Escape resumes")
	game._focus_lost()
	check(game.phase == "paused", "focus loss automatically pauses")
	game._primary()
	await key(KEY_TAB)
	check(game.show_map, "Tab toggles exploration map")
	await place(Vector2i(21, 14))
	game._collect_pickups()
	check(game.has_key, "chapel key collected")
	await place(Vector2i(6, 17), PI)
	await key(KEY_E)
	check(not game.won and game.phase == "cleared" and completions == 0 and game.stage_results.size() == 1, "key unlocks gate and records chapter without awarding campaign win")
	game.interact()
	check(completions == 0 and game.stage_results.size() == 1, "chapter clear cannot be recorded twice")
	await fresh()
	check(not game.armed and not game.has_key and not game.secret_found and game.kills == 0 and game.ammo == 0 and game.health == 100, "replay restores full level checkpoint")
	check(game.projectiles.is_empty() and game.enemies[0].hp == 65, "replay clears projectiles and restores enemies")
	game.take_damage(100)
	check(game.phase == "dead" and not game.won, "zero health ends run without victory")
	game._primary()
	game.set_physics_process(false)
	await settle()
	check(game.phase == "playing" and game.health == 100 and not game.armed, "death retry restarts current dungeon")
	# Exercise pursuing AI and caster windup/projectiles in the actual physics world.
	await place(Vector2i(16, 3))
	var before: Vector3 = game.enemies[3].node.position
	game._update_enemies(0.3)
	check(game.enemies[3].node.position.distance_to(before) > 0, "visible skeleton pursues player")
	var caster: Dictionary = game.enemies[10]
	caster.cooldown = 0.0
	game._update_enemies(0.4)
	check(game.projectiles.is_empty() and caster.windup > 0, "caster telegraphs attack before firing")
	game._update_enemies(0.4)
	check(not game.projectiles.is_empty(), "caster releases visible projectile after windup")
	var bolt_count: int = game.projectiles.size()
	game.player_body.position.z += 3.0
	for i in 100:
		game._update_projectiles(1.0 / 60)
		await physics_frame
	check(game.health == 100, "moving sideways dodges aimed projectile")
	# Direct projectile collision and intervening wall absorption.
	game._spawn_projectile(game.player_body.position + Vector3(0, 1.25, -3))
	for i in 50:
		game._update_projectiles(1.0 / 60)
		await physics_frame
	check(game.health == 86, "projectile damages player once on collision")
	await fresh()
	await place(Vector2i(9, 8))
	game._spawn_projectile(game.at(Vector2i(14, 5)) + Vector3(0, 1.25, 0))
	for i in 220:
		game._update_projectiles(1.0 / 60)
		await physics_frame
	check(game.health == 100 and game.projectiles.is_empty(), "walls absorb hostile projectiles")
	# Real input-driven movement and wall collision.
	await fresh()
	game.set_physics_process(true)
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	w.keycode = KEY_W
	w.pressed = true
	Input.parse_input_event(w)
	for i in 110: await physics_frame
	w.pressed = false
	Input.parse_input_event(w)
	game.set_physics_process(false)
	check(game.player_body.position.x > game.at(game.START).x + 4, "W moves player through open cell doorway")
	await place(Vector2i(2, 3), 0)
	game.set_physics_process(true)
	w.pressed = true
	Input.parse_input_event(w)
	for i in 100: await physics_frame
	w.pressed = false
	Input.parse_input_event(w)
	game.set_physics_process(false)
	check(game.tile(game.player_body.position).y == 3, "solid dungeon walls stop player movement")
	# Arrow alternatives go through the same real input and physics path as WASD.
	for mapping in [[KEY_UP, Vector3.RIGHT], [KEY_DOWN, Vector3.LEFT], [KEY_LEFT, Vector3.FORWARD], [KEY_RIGHT, Vector3.BACK]]:
		await place(game.START)
		var origin: Vector3 = game.player_body.position
		var arrow := InputEventKey.new()
		arrow.physical_keycode = mapping[0]
		arrow.keycode = mapping[0]
		arrow.pressed = true
		Input.parse_input_event(arrow)
		game.set_physics_process(true)
		for frame in 30: await physics_frame
		var release: InputEventKey = arrow.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
		game.set_physics_process(false)
		var displacement: Vector3 = game.player_body.position - origin
		check(displacement.dot(mapping[1]) > 0.8, "arrow %s moves in expected player-relative direction" % OS.get_keycode_string(mapping[0]))
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "leaving game releases captured pointer")
	print("MONSTER BLAST TESTS: %d failure(s)" % failures)
	quit(1 if failures else 0)
