extends SceneTree
var failures := 0
var wins := 0
var game: Control
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL castle maze: " + message)
		failures += 1
	else: print("PASS castle maze: " + message)
func walk(target: Vector2i) -> void:
	var route: Array[Vector2i] = game.path_to(target)
	check(not route.is_empty(), "safe route to " + str(target) + " in " + game.area)
	for cell in route: game.move_player(cell - game.player_cell)
func run() -> void:
	game = load("res://games/caste_maze.gd").new()
	root.add_child(game)
	game.completed.connect(func(_data): wins += 1)
	await process_frame
	check(game.hero == "" and game.chooser.visible, "starts with hero choice")
	seed(20261121)
	var previous := {}
	for round_index in 20:
		game.start("Knight")
		for key_area in ["dungeon", "basement", "towers"]:
			game.level = ["dungeon", "basement", "towers"].find(key_area)
			if game.area != key_area: game.load_area(key_area)
			var key: Vector2i = game.key_cell
			check(not previous.has(key_area) or key != previous[key_area], "new key spot each round in " + key_area)
			check(game.tiles.has(key) and not game.danger(key), "key on safe floor in " + key_area)
			if key_area == "basement":
				check(game.tiles[key] == "secret", "second key stays in secret room")
			if key_area == "towers":
				check(key.x >= 17, "third key stays across both bridges")
			walk(key)
			check(game.has_key and game.key_cell == key, "key stays put during play and can be collected")
			walk(game.exit_cell)
			check(game.next_button.visible or game.won, "random key permits escape")
			previous[key_area] = key
	for character in game.HEROES:
		game.start(character)
		check(game.hero == character, "select " + character)
		var start: Vector2i = game.player_cell
		game.move_player(Vector2i.LEFT)
		check(game.player_cell == start, "walls block movement")
		walk(game.exit_cell)
		check(not game.next_button.visible, "exit requires key")
		walk(game.key_cell)
		check(game.has_key, "box gives dungeon key")
		# Exercise both hazards from a reachable adjacent safe tile.
		for hazard in [game.holes[0], game.guards[0]]:
			var exercised := false
			for cell in game.tiles:
				if game.danger(cell) or game.path_to(cell).is_empty(): continue
				for direction in game.DIRS:
					var destination: Vector2i = cell + direction
					if destination == hazard or (hazard in game.guards and destination.distance_to(hazard) == 1):
						walk(cell)
						game.move_player(direction)
						check(game.player_cell == cell and game.has_key, "hazard hops nearby and preserves key")
						exercised = true
						break
				if exercised: break
			check(exercised, "hazard exercised")
		walk(game.exit_cell)
		check(game.exit_found and game.next_button.visible, "hidden exit discovered and unlocked")
		game.next_level()
		check(game.area == "hall", "castle begins upstairs")
		walk(game.exit_cell)
		check(game.area == "basement", "stairs lead to basement")
		walk(game.key_cell)
		check(game.secret_found and game.has_key, "secret room yields second key")
		walk(game.exit_cell)
		game.next_level()
		check(game.area == "towers", "third level begins in back tower")
		var route: Array[Vector2i] = game.path_to(game.key_cell)
		var bridges := 0
		for cell in route:
			if game.tiles[cell] == "bridge": bridges += 1
		check(bridges >= 6, "key route crosses both rope bridges")
		walk(game.key_cell)
		walk(game.exit_cell)
		check(game.won and game.area == "courtyard", "trapdoor stairs reach winning courtyard")
		var count := wins
		game.move_player(Vector2i.RIGHT)
		check(wins == count, "win is emitted only once")
	check(wins == 23, "randomized rounds and all three heroes can complete adventure")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
