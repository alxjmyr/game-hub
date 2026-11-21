extends SceneTree
var game: Control
var failures := 0
var wins := 0
var result: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: print("PASS campaign: " + text)
	else:
		push_error("FAIL campaign: " + text)
		failures += 1
func settle() -> void:
	await physics_frame
	await physics_frame
func fresh(difficulty: int = 0) -> void:
	game._set_menu("intro")
	game.set_difficulty(difficulty)
	game.start_run()
	game.set_physics_process(false)
	await settle()
func enter_chapter(index: int) -> void:
	game.level_index = index
	game.checkpoint = {"health": 81, "ammo": 74, "armed": true, "weapons": ["pistol"], "weapon": "pistol"}
	game.restart_level()
	game.set_physics_process(false)
	await settle()
func use_at(cell: Vector2i, from: Vector2i) -> void:
	game.player_body.position = game.at(from)
	var direction: Vector3 = game.at(cell) - game.player_body.position
	game.player_body.rotation.y = atan2(-direction.x, -direction.z)
	game.interact()
func boss_index() -> int:
	for i in game.enemies.size():
		if game.enemies[i].boss: return i
	return -1
func run() -> void:
	game = load("res://games/monster_blast.gd").new()
	root.add_child(game)
	game.completed.connect(func(data): wins += 1; result = data)
	await settle()
	check(game.difficulty == 0 and game.difficulty_buttons.size() == 3, "Easy defaults and three start choices")
	check(game.difficulty_row.visible and game.difficulty_buttons[0].button_pressed, "difficulty visible and selected in briefing")
	var speeds: Array[float] = []
	var timers: Array[float] = []
	for difficulty in 3:
		await fresh(difficulty)
		game.player_body.position = game.at(Vector2i(16,3))
		await settle()
		var enemy: Dictionary = game.enemies[3]
		var before: Vector3 = enemy.node.position
		game._update_enemies(0.1)
		speeds.append(enemy.node.position.distance_to(before))
		timers.append(enemy.cooldown)
		check(enemy.max_hp == 65 and game.health == 100, "difficulty %d leaves health unchanged" % difficulty)
		game.set_difficulty((difficulty + 1) % 3)
		check(game.difficulty == difficulty and not game.difficulty_row.visible, "difficulty locked during active run")
	check(is_equal_approx(speeds[0], 0.135), "Easy preserves original skeleton speed")
	check(absf(speeds[1] / speeds[0] - 1.3) < 0.01 and absf(speeds[2] / speeds[0] - 1.65) < 0.01, "Normal/Hard increase actual movement by 30/65 percent")
	check(absf(timers[0] - 1.1) < 0.001 and absf(timers[1] - 1.065) < 0.001 and absf(timers[2] - 1.02) < 0.001, "attack timers run faster by difficulty")
	await fresh()
	# Every placed entity, secret and exit approach is reachable on both maps.
	for chapter in [1,2]:
		await enter_chapter(chapter)
		check(game.level_index == chapter and game.enemies.size() >= 16 and game.boss_alive(), "chapter %d builds population and boss" % chapter)
		for item in game.pickups:
			var cell: Vector2i = game.tile(item.node.position)
			if cell.x < game.SECRET.x and cell.y < 10: continue
			check(game.walkable(cell) and not game.navigation.get_id_path(game.START, cell).is_empty(), "chapter %d pickup reachable %s %s" % [chapter, item.kind, cell])
		for enemy in game.enemies:
			check(game.walkable(game.tile(enemy.node.position)), "enemy spawns on walkable tile")
		for lever in game.switches:
			check(not game.navigation.get_id_path(game.START, lever.cell).is_empty(), "winch reachable")
		check(not game.navigation.get_id_path(game.START, game.EXIT + Vector2i.DOWN).is_empty(), "exit approach reachable")
		use_at(game.SECRET, game.SECRET + Vector2i.RIGHT)
		check(game.secret_found and not game.navigation.is_point_solid(game.SECRET), "chapter secret opens and updates navigation")
		for item in game.pickups:
			check(not game.navigation.get_id_path(game.START, game.tile(item.node.position)).is_empty(), "all supplies including secret reachable after wall opens")
		use_at(game.EXIT, game.EXIT + Vector2i.DOWN)
		check(game.phase == "playing" and wins == 0, "exit locked before objectives and boss")
	# Iron Warden telegraphs, commits to direction, recovers, and cannot be stun-locked.
	await enter_chapter(1)
	var index := boss_index()
	var warden: Dictionary = game.enemies[index]
	game.player_body.position = warden.node.position + Vector3(0,0,9)
	await settle()
	warden.cooldown = 0.0
	game._update_boss(warden, 0.1, true, 9)
	check(warden.state == "windup" and warden.timer == 1.1, "Warden visibly telegraphs charge")
	var locked: Vector3 = warden.charge_direction
	game.player_body.position.x += 5
	game._update_boss(warden, 1.2, true, 10)
	check(warden.state == "charge" and warden.charge_direction == locked, "charge direction is locked so it can be dodged")
	game.damage_enemy(index, 34)
	check(warden.pain == 0.0 and warden.state == "charge", "boss cannot be indefinitely interrupted by bullets")
	for step in 150: game._update_boss(warden, 1.0/120, true, 10)
	check(warden.state == "recover" and game.health == 81, "dodged Warden charge has a recovery window")
	game._update_boss(warden, 1.8, true, 10)
	check(warden.state == "hunt", "Warden resumes after recovery")
	warden.node.position = game.at(Vector2i(27,14))
	game.player_body.position = game.at(Vector2i(23,14))
	warden.state = "charge"
	warden.timer = 1.2
	warden.charge_direction = Vector3.RIGHT
	await settle()
	for step in 120:
		game._update_boss(warden, 1.0/120, false, 12)
		await physics_frame
	check(warden.node.position.x < 85.0 and warden.state == "recover", "full boss collision shape stops charge at stone walls")
	warden.node.position = game.at(Vector2i(23,12))
	game.player_body.position = warden.node.position + Vector3(0,0,1.0)
	warden.state = "charge"
	warden.timer = 1.0
	warden.charge_direction = Vector3.BACK
	await settle()
	var health_before: int = game.health
	game._update_boss(warden, 0.01, true, 1)
	game._update_boss(warden, 0.01, true, 1)
	check(game.health == health_before - 24 and warden.state == "recover", "charge contact damages once and ends in recovery")
	# Entering the castle does not award a win. Inventory carries; retry rolls back.
	await fresh(1)
	game.armed = true
	game.health = 63
	game.ammo = 51
	game.has_key = true
	use_at(game.EXIT, Vector2i(6,17))
	check(game.phase == "cleared" and wins == 0 and not game.won, "dungeon clear waits for Continue without campaign win")
	game.next_level()
	game.set_physics_process(false)
	await settle()
	check(game.level_index == 1 and game.health == 63 and game.ammo == 51 and game.armed and game.difficulty == 1, "chapter carries exact entry inventory and difficulty")
	game.player_body.position = game.at(Vector2i(3,11))
	game._collect_pickups()
	check("blunderbuss" in game.weapons and game.weapon == "blunderbuss" and game.ammo == 75, "castle awards usable blunderbuss")
	game.ammo = 2
	game.cooldown = 0
	game.fire()
	check(game.weapon == "pistol" and game.ammo == 1, "heavy weapon falls back to pistol for last rounds")
	game.take_damage(100)
	game._primary()
	game.set_physics_process(false)
	await settle()
	check(game.level_index == 1 and game.health == 63 and game.ammo == 51 and game.weapons == ["pistol"], "death retries castle with original entry inventory")
	check(not game.has_key and not game.secret_found and game.kills == 0 and game.stage_results.size() == 1 and game.boss_alive(), "retry resets chapter objectives and boss but preserves previous chapter")
	game.player_body.position = game.at(Vector2i(14,3))
	game._collect_pickups()
	use_at(game.EXIT, game.EXIT + Vector2i.DOWN)
	check(game.phase == "playing", "silver seal alone cannot bypass Warden")
	game.damage_enemy(boss_index(), 10000)
	use_at(game.EXIT, game.EXIT + Vector2i.DOWN)
	check(game.phase == "cleared" and wins == 0, "Warden plus seal unlocks castle, still no campaign win")
	game.next_level()
	game.set_physics_process(false)
	await settle()
	check(game.level_index == 2 and game.switches_on() == 0 and game.difficulty == 1, "grounds checkpoint initializes both winches")
	game.player_body.position = game.at(Vector2i(12,4))
	game._collect_pickups()
	check(game.weapon == "rune" and "rune" in game.weapons, "watchtower awards rune caster")
	use_at(game.switches[0].cell, game.switches[0].cell + Vector2i.DOWN)
	use_at(game.SECRET, game.SECRET + Vector2i.RIGHT)
	game.take_damage(1000)
	game._primary()
	game.set_physics_process(false)
	await settle()
	check(game.level_index == 2 and game.stage_results.size() == 2 and game.difficulty == 1, "grounds death preserves completed castle and chosen difficulty")
	check(game.switches_on() == 0 and not game.secret_found and not game.has_key and game.boss_alive() and "rune" not in game.weapons, "grounds retry resets winches, secret, seal, boss, and newly collected weapon")
	check(game.health == game.checkpoint.health and game.ammo == game.checkpoint.ammo, "grounds retry restores exact checkpoint supplies")
	game.player_body.position = game.at(Vector2i(12,4))
	game._collect_pickups()
	index = boss_index()
	var regent: Dictionary = game.enemies[index]
	game.player_body.position = regent.node.position + Vector3(0,0,6)
	regent.cooldown = 0.0
	game._update_boss(regent, 0.1, true, 6)
	check(regent.state == "windup", "Regent telegraphs spell fan")
	game._update_boss(regent, 1.2, true, 6)
	check(game.projectiles.size() == 3, "Regent opens with three dodgeable projectiles")
	var count: int = game.enemies.size()
	game.damage_enemy(index, 650)
	regent.cooldown = 0.0
	game._update_boss(regent, 0.1, true, 6)
	game._update_boss(regent, 1.2, true, 6)
	check(game.enemies.size() == count + 4 and regent.summoned, "half health summons four gargoyles once")
	check(game.projectiles.size() == 8, "enraged Regent increases fan to five spells")
	game._update_boss(regent, 0.1, true, 6)
	check(game.enemies.size() == count + 4, "summon wave cannot repeat indefinitely")
	game.damage_enemy(index, 10000)
	check(game.has_key and not game.boss_alive(), "defeating Regent grants gate seal")
	use_at(game.EXIT, game.EXIT + Vector2i.DOWN)
	check(game.phase == "playing" and wins == 0, "Regent defeat alone cannot skip drawbridge winches")
	for lever in game.switches:
		use_at(lever.cell, lever.cell + Vector2i.DOWN)
		use_at(lever.cell, lever.cell + Vector2i.DOWN)
	check(game.switches_on() == 2 and game.bridge.rotation.x == 0, "both winches lower drawbridge; repeated use is harmless")
	use_at(game.EXIT, game.EXIT + Vector2i.DOWN)
	check(game.won and game.phase == "won" and wins == 1, "only final exit wins campaign")
	check(result.levels_completed == 3 and result.chapters.size() == 3 and result.difficulty == "Normal", "completion payload includes all chapters and difficulty")
	game.interact()
	check(wins == 1, "final completion emitted once")
	game._primary()
	game.set_physics_process(false)
	check(game.phase == "intro" and game.level_index == 0 and game.stage_results.is_empty() and game.difficulty_row.visible, "new escape returns to difficulty selection and clears campaign")
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("MONSTER CAMPAIGN: %d failure(s)" % failures)
	quit(1 if failures else 0)
