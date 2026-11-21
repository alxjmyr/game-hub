extends SceneTree
# A deterministic playthrough using normal combat, AI, pickups, collision and
# damage. The driver supplies movement/aim only; it never grants health or ammo.
var game: Control
var ticks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return game.navigation.get_id_path(start, goal)
func combat() -> void:
	var nearest := -1
	var distance := 1000.0
	for i in game.enemies.size():
		var enemy: Dictionary = game.enemies[i]
		var d: float = game.player_body.position.distance_to(enemy.node.position)
		if enemy.hp > 0 and d < distance and d < 22 and game._line_clear(game.player_body.position, enemy.node.position):
			nearest = i
			distance = d
	if nearest >= 0 and game.armed:
		var offset: Vector3 = game.enemies[nearest].node.position - game.player_body.position
		game.player_body.rotation.y = atan2(-offset.x, -offset.z)
		game.camera.rotation.x = 0
		game.fire()
func walk_to(goal: Vector2i) -> bool:
	var route := path(game.tile(game.player_body.position), goal)
	if route.is_empty():
		push_error("No route to " + str(goal))
		return false
	for cell in route:
		var destination: Vector3 = game.at(cell)
		var steps := 0
		while game.player_body.position.distance_to(destination) > 0.22:
			await physics_frame
			game._physics_process(1.0 / 120)
			combat()
			var movement: Vector3 = destination - game.player_body.position
			movement.y = 0
			game.player_body.velocity = movement.normalized() * 5.3
			game.player_body.move_and_slide()
			ticks += 1
			steps += 1
			if game.phase != "playing" or steps > 1600:
				push_error("Playthrough stopped: phase=%s health=%d ammo=%d cell=%s destination=%s" % [game.phase, game.health, game.ammo, game.tile(game.player_body.position), cell])
				return false
	return true
func run() -> void:
	game = load("res://games/monster_blast.gd").new()
	root.add_child(game)
	game.start_run()
	game.set_physics_process(false)
	await physics_frame
	for goal in [Vector2i(5, 4), Vector2i(10, 2), Vector2i(14, 3), Vector2i(14, 6), Vector2i(21, 6), Vector2i(20, 12), Vector2i(21, 14), Vector2i(21, 16), Vector2i(10, 12), Vector2i(11, 16), Vector2i(5, 12)]:
		if not await walk_to(goal):
			failures += 1
			break
		print("REACHED %s | health %d ammo %d kills %d" % [goal, game.health, game.ammo, game.kills])
	if not failures:
		game.player_body.rotation.y = PI / 2
		game.interact()
		for goal in [Vector2i(2, 11), Vector2i(2, 12), Vector2i(6, 17)]:
			if not await walk_to(goal): failures += 1
		game.player_body.rotation.y = PI
		game.interact()
		if game.phase != "cleared" or game.won or not game.secret_found or not game.has_key:
			failures += 1
			push_error("Playthrough failed to complete objectives")
	print("MONSTER BLAST PLAYTHROUGH: %d failure(s), %d ticks, %d kills, health %d, ammo %d" % [failures, ticks, game.kills, game.health, game.ammo])
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit(1 if failures else 0)
