extends "res://tests/playthrough_monster_blast.gd"
# Continuous campaign traversal. Inventory is earned and carried normally;
# the driver supplies movement and aim, with no teleport, invulnerability,
# direct damage, or health/ammo grants.
var campaign_wins := 0
func path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	# A physical player can stand in the margin around a pillar. Route from a
	# visible neighboring floor tile rather than trying to center inside stone.
	if not game.walkable(start):
		var closest := Vector2i(-1,-1)
		var distance := INF
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var candidate: Vector2i = start + offset
			var d: float = game.player_body.position.distance_to(game.at(candidate))
			if game.walkable(candidate) and d < distance and game._line_clear(game.player_body.position,game.at(candidate)):
				closest = candidate
				distance = d
		if closest.x < 0: return []
		return game.navigation.get_id_path(closest,goal)
	var route: Array[Vector2i] = game.navigation.get_id_path(start,goal)
	return route.slice(1) if route.size() > 1 else route

func combat() -> void:
	var nearest := -1
	var distance := 1000.0
	for i in game.enemies.size():
		var enemy: Dictionary = game.enemies[i]
		var d: float = game.player_body.position.distance_to(enemy.node.position)
		if enemy.hp > 0 and d < distance and d < 25 and game._line_clear(game.player_body.position, enemy.node.position):
			nearest = i
			distance = d
	if nearest >= 0 and game.armed:
		var offset: Vector3 = game.enemies[nearest].node.position - game.player_body.position
		game.player_body.rotation.y = atan2(-offset.x, -offset.z)
		game.camera.rotation.x = 0
		game.weapon = "rune" if "rune" in game.weapons else ("blunderbuss" if "blunderbuss" in game.weapons and distance < 10 else "pistol")
		game.fire()
func use(cell: Vector2i) -> void:
	var offset: Vector3 = game.at(cell) - game.player_body.position
	game.player_body.rotation.y = atan2(-offset.x, -offset.z)
	game.interact()
func battle() -> bool:
	var count := 0
	while game.boss_alive():
		await physics_frame
		game._physics_process(1.0/120)
		combat()
		var boss: Dictionary
		for enemy in game.enemies:
			if enemy.boss: boss = enemy
		var toward: Vector3 = boss.node.position - game.player_body.position
		toward.y = 0
		var direction := Vector3(-toward.z,0,toward.x).normalized()
		if toward.length() < 6: direction -= toward.normalized()
		if toward.length() > 12: direction += toward.normalized()
		game.player_body.velocity = direction.normalized() * 5.3
		game.player_body.move_and_slide()
		count += 1
		ticks += 1
		if game.phase != "playing" or count > 12000:
			push_error("Boss fight failed: %s hp=%d ammo=%d" % [game.phase,game.health,game.ammo])
			return false
	return true
func run() -> void:
	game = load("res://games/monster_blast.gd").new()
	root.add_child(game)
	game.completed.connect(func(_data): campaign_wins += 1)
	var setting := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--difficulty="): setting = int(arg.get_slice("=",1))
	game.set_difficulty(setting)
	game.start_run()
	game.set_physics_process(false)
	await physics_frame
	var dungeon := [Vector2i(5,4),Vector2i(10,2),Vector2i(14,3),Vector2i(14,6),Vector2i(21,6),Vector2i(20,12),Vector2i(21,14),Vector2i(21,16),Vector2i(10,12),Vector2i(11,16),Vector2i(5,12)]
	for chapter in 3:
		var route: Array = dungeon if chapter == 0 else game.level_data.route
		for goal in route:
			if not await walk_to(goal): failures += 1; break
			print("CHAPTER %d REACHED %s | health %d ammo %d kills %d" % [chapter+1,goal,game.health,game.ammo,game.kills])
			if chapter == 1 and goal == Vector2i(23,13):
				if not await battle(): failures += 1; break
			if chapter == 2:
				if goal == Vector2i(10,5): use(Vector2i(10,4))
				if goal == Vector2i(22,24): use(Vector2i(22,25))
				if goal == Vector2i(29,21):
					if not await battle(): failures += 1; break
		if failures: break
		if chapter == 0:
			use(game.SECRET)
			for goal in [Vector2i(2,11),Vector2i(2,12),Vector2i(6,17)]:
				if not await walk_to(goal): failures += 1
		elif chapter == 1:
			if not await walk_to(game.SECRET + Vector2i.RIGHT): failures += 1
			use(game.SECRET)
			if not await walk_to(Vector2i(4,4)): failures += 1
			if not await walk_to(game.EXIT + Vector2i.DOWN): failures += 1
		else:
			if not await walk_to(game.SECRET + Vector2i.RIGHT): failures += 1
			use(game.SECRET)
			if not await walk_to(Vector2i(5,7)): failures += 1
			if not await walk_to(game.EXIT + Vector2i.DOWN): failures += 1
		use(game.EXIT)
		if chapter < 2:
			if game.phase != "cleared" or game.won or campaign_wins != 0:
				push_error("Invalid intermediate campaign state")
				failures += 1
				break
			game.next_level()
			game.set_physics_process(false)
			await physics_frame
	if not game.won or campaign_wins != 1 or game.stage_results.size() != 3:
		failures += 1
		push_error("Campaign did not reach final victory")
	print("MONSTER CAMPAIGN PLAYTHROUGH: %d failure(s), %d ticks, health %d, ammo %d, results %s" % [failures,ticks,game.health,game.ammo,game.stage_results])
	game.queue_free()
	await process_frame
	# Fixed-FPS accelerates simulation; let the audio mixer release real-time references.
	var drain_until := Time.get_ticks_msec() + 750
	while Time.get_ticks_msec() < drain_until: await process_frame
	quit(1 if failures else 0)
