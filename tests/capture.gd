extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
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
	app.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit()
