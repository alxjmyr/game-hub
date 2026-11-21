extends RefCounted
# Original pixel art, generated deterministically; no external assets required.
static func texture(kind: String) -> ImageTexture:
	var im := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	if kind in ["stone", "floor", "ceiling", "door", "secret", "grass"]:
		for y in 64:
			for x in 64:
				var noise := float((x * 73 + y * 157 + x * y * 13) % 19) / 255.0
				var c := Color(0.27 + noise, 0.28 + noise, 0.30 + noise)
				if kind == "grass":
					c = Color(0.10 + noise, 0.16 + noise, 0.13 + noise)
				elif kind == "floor":
					c = Color(0.19 + noise, 0.20 + noise, 0.19 + noise)
					if x % 32 == 0 or y % 32 == 0: c *= 0.55
				elif kind == "ceiling": c = Color(0.13 + noise, 0.14 + noise, 0.16 + noise)
				elif kind == "door":
					c = Color(0.27 + noise, 0.16 + noise, 0.09 + noise)
					if x % 12 < 2: c *= 0.4
					if y in range(10, 15) or y in range(48, 53): c = Color("3d4347")
				else:
					var offset := 16 if (y / 16) % 2 == 0 else 0
					if y % 16 < 2 or (x + offset) % 32 < 2: c = Color("171d22")
					elif y % 16 == 2: c *= 1.3
				im.set_pixel(x, y, c)
		if kind == "secret":
			for y in range(12, 52):
				var x := 32 + int(sin(y * 0.35) * 4)
				im.set_pixel(x, y, Color("79aa82"))
	else:
		match kind:
			"skeleton", "guard", "caster", "corpse", "gargoyle", "warden", "regent": _monster(im, kind)
			"pistol":
				box(im, 12, 25, 41, 9, "263039")
				box(im, 13, 23, 38, 5, "a4aa9e")
				box(im, 21, 33, 11, 17, "744735")
				box(im, 24, 35, 4, 13, "a57450")
				box(im, 38, 28, 15, 5, "515f61")
			"blunderbuss":
				box(im, 9, 23, 48, 13, "343b43")
				box(im, 10, 22, 47, 5, "c2aa73")
				box(im, 14, 35, 13, 16, "97614c")
				box(im, 45, 20, 12, 19, "927e55")
			"rune":
				box(im, 17, 29, 31, 8, "6c5d80")
				box(im, 24, 35, 8, 17, "b19a68")
				box(im, 35, 18, 15, 15, "73c9c3")
				box(im, 39, 13, 7, 24, "b6f1d0")
			"ammo":
				box(im, 13, 25, 39, 28, "4a593e")
				box(im, 13, 25, 39, 5, "899462")
				for x in [21, 30, 39]:
					box(im, x, 33, 5, 14, "d7ac58")
					box(im, x + 1, 30, 3, 4, "f2d287")
			"health":
				box(im, 13, 24, 38, 29, "999c8f")
				box(im, 16, 26, 32, 24, "d8d3b7")
				box(im, 27, 29, 9, 19, "963f3c")
				box(im, 22, 34, 19, 9, "963f3c")
			"key":
				box(im, 24, 13, 18, 17, "e4b652")
				box(im, 29, 17, 8, 8, "635535")
				box(im, 30, 30, 6, 23, "e4b652")
				box(im, 35, 43, 8, 5, "e4b652")
				box(im, 35, 50, 8, 4, "e4b652")
			"torch":
				box(im, 28, 32, 8, 26, "655041")
				box(im, 23, 20, 18, 19, "b64c29")
				box(im, 27, 12, 11, 22, "fba94b")
				box(im, 31, 19, 5, 14, "ffe8a0")
	return ImageTexture.create_from_image(im)

static func box(im: Image, x: int, y: int, w: int, h: int, color: String) -> void:
	im.fill_rect(Rect2i(x, y, w, h), Color(color))

static func _monster(im: Image, kind: String) -> void:
	if kind == "corpse":
		box(im, 5, 52, 53, 8, "692b32")
		box(im, 12, 51, 22, 5, "8f3b3b")
		box(im, 23, 46, 15, 10, "959784")
		box(im, 26, 48, 4, 3, "252c30")
		return
	var robe := "57466b" if kind == "caster" else "4e5d50"
	# Outline, then bones/cloth, then lit edges: intentionally chunky 64px art.
	box(im, 21, 4, 23, 22, "20262b")
	box(im, 23, 6, 19, 15, "c3bf99")
	box(im, 25, 6, 15, 3, "eee0ad")
	box(im, 22, 11, 7, 7, "20262b")
	box(im, 35, 11, 7, 7, "20262b")
	box(im, 24, 13, 4, 3, "ed7553")
	box(im, 36, 13, 4, 3, "ed7553")
	box(im, 30, 17, 3, 3, "45483e")
	box(im, 25, 21, 14, 4, "ada982")
	for x in [27, 31, 35]: box(im, x, 21, 2, 3, "45483e")
	box(im, 18, 27, 28, 24, "20262b")
	if kind == "skeleton":
		box(im, 30, 26, 4, 24, "c3bf99")
		for y in [29, 35, 41]:
			box(im, 22, y, 20, 3, "bbb88f")
		box(im, 22, 47, 20, 6, "b0ad8d")
	else:
		box(im, 20, 27, 24, 26, robe)
		box(im, 23, 28, 5, 21, "7b7390" if kind == "caster" else "7d8262")
		box(im, 20, 44, 24, 4, "302d30")
		box(im, 30, 44, 5, 4, "ba9851")
	for x in [13, 46]:
		box(im, x, 29, 5, 19, "c3bf99")
		box(im, x - 1, 44, 7, 6, "dfcca2")
	for x in [23, 36]:
		box(im, x, 52, 5, 9, "aaa784")
		box(im, x - 2, 60, 9, 3, "555b50")
	if kind == "caster":
		box(im, 20, 2, 25, 6, "57466b")
		box(im, 18, 8, 5, 17, "57466b")
		box(im, 42, 8, 5, 17, "57466b")
		box(im, 19, 51, 27, 9, "57466b")
		box(im, 51, 18, 3, 43, "836343")
		box(im, 47, 13, 11, 11, "6da588")
		box(im, 50, 15, 5, 6, "b5efab")
	elif kind == "guard":
		box(im, 20, 3, 25, 8, "66746e")
		box(im, 19, 10, 28, 3, "8a9687")

	if kind == "gargoyle":
		# Stone wings, pointed ears, and ember eyes.
		for x in range(4, 18):
			box(im, x, 18 + (x - 4), 3, 20 - (x - 4), "665f73")
			box(im, 60 - x, 18 + (x - 4), 3, 20 - (x - 4), "665f73")
		box(im, 19, 1, 5, 12, "958d98")
		box(im, 42, 1, 5, 12, "958d98")
		box(im, 22, 28, 21, 18, "756b80")
		box(im, 26, 31, 12, 12, "aaa1a3")
	elif kind == "warden":
		box(im, 17, 3, 30, 21, "485259")
		box(im, 20, 5, 24, 7, "a2a491")
		box(im, 19, 14, 26, 5, "202b31")
		box(im, 22, 15, 7, 2, "ef9e54")
		box(im, 36, 15, 7, 2, "ef9e54")
		box(im, 12, 26, 41, 9, "9b936f")
		box(im, 19, 34, 27, 18, "737e78")
		box(im, 28, 34, 7, 18, "b4a571")
		box(im, 4, 27, 7, 35, "79674c")
		box(im, 0, 24, 16, 14, "b8b5a0")
		box(im, 19, 52, 12, 11, "566267")
		box(im, 35, 52, 12, 11, "566267")
	elif kind == "regent":
		box(im, 18, 26, 30, 35, "623b57")
		box(im, 24, 29, 6, 30, "ac776f")
		box(im, 33, 27, 6, 32, "c2a06b")
		box(im, 19, 2, 27, 6, "c2a06b")
		for x in [19, 30, 41]: box(im, x, 0, 5, 9, "ead397")
		box(im, 21, 11, 9, 5, "50c8b4")
		box(im, 35, 11, 8, 5, "50c8b4")
		box(im, 51, 13, 4, 49, "9f8359")
		box(im, 46, 8, 14, 15, "478d8b")
		box(im, 49, 11, 8, 8, "c4f5c5")
