extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")

func run() -> void:
	root.size = Vector2i(1200, 800)
	var app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	await capture("shelf")
	app.open_game("memory")
	await capture("memory")
	app.current_game.select_card(0)
	await capture("memory-revealed")
	app.current_game.start_game(15)
	await capture("memory-hard")
	for symbol in range(15):
		app.current_game.select_card(app.current_game.deck.find(symbol))
		app.current_game.select_card(app.current_game.deck.rfind(symbol))
	await capture("memory-win")
	app.show_shelf()
	if FileAccess.file_exists("res://games/ball_bucket.gd"):
		app.open_game("ball_bucket")
		await capture("physics")
		app.current_game.new_puzzle(42)
		app.current_game.apply_solution()
		await capture("physics-solution")
		app.current_game.drop_ball()
		while app.current_game.state == "running":
			await physics_frame
		await capture("physics-win")
		if app.current_game.state != "won":
			push_error("Rendered physics solution did not win")
			quit(1)
			return
	for id in ["jigsaw", "maze", "letter_hunt"]:
		app.open_game(id)
		for level in range(3):
			app.current_game.change_difficulty(level)
			await capture(id + "-level-" + str(level))
		var game: Control = app.current_game
		if id == "jigsaw":
			for piece in game.pieces.size():
				game.select_piece(piece)
				while game.pieces[piece].turns != 0: game.rotate_selected()
				game.attempt_drop(piece, game.target_position(piece))
		elif id == "maze":
			for destination in game.find_path(game.player_cell, game.key_cell, false).slice(1):
				game.move_player(destination - game.player_cell)
			for destination in game.find_path(game.player_cell, game.exit_cell, true).slice(1):
				game.move_player(destination - game.player_cell)
		else:
			while not game.won: game.type_character(game.expected_character())
		await capture(id + "-win")
		if not game.won:
			push_error("Rendered game did not win: " + id)
			quit(1)
			return
	app.show_shelf()
	await capture("shelf-completions")
	app.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit()
