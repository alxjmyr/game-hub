extends SceneTree
var app: Control
var game: Control
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/monster-blast-" + name + ".png")
func run() -> void:
	root.size = Vector2i(1200, 800)
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	app.open_game("monster_blast")
	game = app.current_game
	await capture("intro")
	game.start_run()
	game.set_physics_process(false)
	await capture("cell")
	game.player_body.position = game.at(Vector2i(5, 4))
	game._collect_pickups()
	await capture("pistol")
	game.player_body.position = game.at(Vector2i(14, 4))
	game.player_body.rotation.y = -PI / 2
	game.message_time = 0
	await capture("ossuary")
	game.player_body.position = game.at(Vector2i(18, 14))
	game.player_body.rotation.y = -PI / 2
	game.message_time = 0
	await capture("chapel")
	game.show_map = true
	game._discover()
	await capture("map")
	game._set_menu("paused")
	await capture("pause")
	game._set_menu("playing")
	game.take_damage(100)
	await capture("death")
	game.start_run()
	game.set_physics_process(false)
	game.player_body.position = game.at(Vector2i(21, 14))
	game._collect_pickups()
	game.player_body.position = game.at(Vector2i(6, 17))
	game.player_body.rotation.y = PI
	game.interact()
	await capture("escape")
	root.size = Vector2i(900, 600)
	game._set_menu("intro")
	await capture("small-briefing")
	app.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit()
