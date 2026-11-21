extends SceneTree
var app: Control
var game: Control
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/monster-campaign-" + name + ".png")
func run() -> void:
	root.size = Vector2i(1200,800)
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	app.open_game("monster_blast")
	game = app.current_game
	await capture("difficulty")
	root.size = Vector2i(900,600)
	await capture("difficulty-small")
	root.size = Vector2i(1200,800)
	game.start_run()
	game.set_physics_process(false)
	game.armed = true
	game.ammo = 60
	game.has_key = true
	game.finish_level()
	await capture("dungeon-cleared")
	game.next_level()
	game.set_physics_process(false)
	game.player_body.position = game.at(Vector2i(9,5))
	game.player_body.rotation.y = 0
	game._discover()
	game.message_time = 0
	await capture("library")
	game.player_body.position = game.at(Vector2i(23,15))
	game.player_body.rotation.y = 0
	game.weapon = "blunderbuss"
	game.weapons.append("blunderbuss")
	game._discover()
	for enemy in game.enemies:
		if enemy.boss: enemy.active = true; enemy.state = "windup"; enemy.sprite.modulate = Color("ffc575")
	await capture("warden")
	game.show_map = true
	game._discover()
	await capture("castle-map")
	game.show_map = false
	game.finish_level()
	await capture("castle-cleared")
	game.next_level()
	game.set_physics_process(false)
	game.message_time = 0
	await capture("grounds")
	game.player_body.position = game.at(Vector2i(29,21))
	game.player_body.rotation.y = 0
	game.weapon = "rune"
	game.weapons.append("rune")
	game._discover()
	for enemy in game.enemies:
		if enemy.boss: enemy.active = true
	await capture("regent")
	game.player_body.position = game.at(Vector2i(10,5))
	game.player_body.rotation.y = 0
	game._discover()
	await capture("winch")
	game.finish_level()
	await capture("victory")
	root.size = Vector2i(900,600)
	await capture("victory-small")
	app.queue_free()
	await process_frame
	await create_timer(0.6).timeout
	quit()
