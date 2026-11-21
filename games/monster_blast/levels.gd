extends RefCounted
# Hand-authored layouts. Room rectangles and entity cells share a 3m grid.
# Every chapter has a loop, readable landmarks, a secret and a distinct exit.
static func get_level(index: int) -> Dictionary:
	if index == 1:
		return {
			"name": "THE HOLLOW CROWN", "short": "Castle", "width": 33, "height": 27,
			"start": Vector2i(3, 22), "exit": Vector2i(29, 3), "secret": Vector2i(7, 5), "yaw": 0.0,
			"key_name": "SILVER SEAL", "boss": "THE IRON WARDEN",
			"brief": "The guards have raised the portcullis. Find the silver seal in the library and defeat the Iron Warden in the throne hall. The armory holds something louder than a pistol.",
			"rooms": [Rect2i(2, 20, 6, 5), Rect2i(4, 15, 2, 5), Rect2i(2, 10, 9, 5), Rect2i(8, 5, 3, 5), Rect2i(8, 2, 8, 4), Rect2i(11, 11, 6, 2), Rect2i(14, 6, 2, 5), Rect2i(17, 9, 12, 7), Rect2i(18, 16, 2, 4), Rect2i(13, 20, 16, 5), Rect2i(8, 22, 5, 2), Rect2i(27, 16, 2, 4), Rect2i(23, 5, 2, 4), Rect2i(21, 2, 10, 3), Rect2i(16, 3, 5, 2), Rect2i(3, 3, 4, 4)],
			"pillars": [Vector2i(5, 12), Vector2i(8, 12), Vector2i(20, 11), Vector2i(25, 11), Vector2i(20, 14), Vector2i(25, 14), Vector2i(16, 22), Vector2i(23, 22)],
			"torches": [Vector2i(3, 20), Vector2i(6, 10), Vector2i(10, 2), Vector2i(15, 8), Vector2i(18, 9), Vector2i(27, 9), Vector2i(14, 20), Vector2i(27, 20), Vector2i(22, 2), Vector2i(29, 2), Vector2i(4, 3)],
			"pickups": [["ammo",3,21],["health",5,21],["health",6,21],["blunderbuss",3,11],["ammo",9,14],["ammo",10,3],["key",14,3],["health",14,5],["ammo",18,10],["health",27,15],["ammo",14,23],["ammo",27,23],["health",28,21],["ammo",22,3],["ammo",4,4],["health",5,5]],
			"enemies": [["skeleton",5,17],["guard",8,13],["skeleton",9,10],["caster",10,4],["skeleton",13,4],["gargoyle",15,10],["caster",18,12],["skeleton",21,10],["gargoyle",26,14],["warden",23,12],["guard",14,21],["caster",20,23],["skeleton",26,21],["gargoyle",28,18],["skeleton",23,6],["caster",27,3],["guard",29,4]],
			"signs": [[3,20,"CASTLE STAIR\nARMORY AHEAD"],[3,10,"THE ARMORY"],[11,2,"THE FORBIDDEN LIBRARY\nSILVER SEAL"],[22,9,"THRONE HALL\nTHE WARDEN KEEPS WATCH"],[19,20,"BANQUET GALLERY"],[27,2,"COURTYARD PORTCULLIS"]],
			"zones": [[Rect2i(0,19,33,8),"BANQUET GALLERY"],[Rect2i(0,9,12,10),"THE ARMORY"],[Rect2i(0,0,17,9),"FORBIDDEN LIBRARY"],[Rect2i(17,8,16,12),"THE THRONE HALL"],[Rect2i(17,0,16,8),"THE PORTCULLIS"]],
			"switches": [],
			"route": [Vector2i(3,21),Vector2i(5,21),Vector2i(3,11),Vector2i(9,14),Vector2i(10,3),Vector2i(14,3),Vector2i(18,10),Vector2i(23,13),Vector2i(27,15),Vector2i(27,23),Vector2i(14,23),Vector2i(8,5),Vector2i(22,3),Vector2i(29,4)]
		}
	return {
		"name": "THE LAST DRAWBRIDGE", "short": "Grounds", "width": 37, "height": 29,
		"start": Vector2i(3,24), "exit": Vector2i(32,3), "secret": Vector2i(8,9), "yaw": 0.0,
		"key_name": "GATE SEAL", "boss": "THE GRAVE REGENT",
		"brief": "Moonlight, at last. Raise both winches to lower the drawbridge. The Grave Regent carries the gate seal—and has no intention of letting you leave.",
		"rooms": [Rect2i(2,21,8,6),Rect2i(4,14,3,7),Rect2i(2,10,12,5),Rect2i(10,15,3,7),Rect2i(10,22,7,3),Rect2i(17,19,7,7),Rect2i(18,14,3,5),Rect2i(14,11,7,3),Rect2i(9,3,6,7),Rect2i(15,5,8,3),Rect2i(23,3,11,7),Rect2i(26,10,3,4),Rect2i(23,14,12,9),Rect2i(24,21,3,3),Rect2i(33,8,2,7),Rect2i(4,6,4,4)],
		"pillars": [Vector2i(5,12),Vector2i(8,12),Vector2i(11,12),Vector2i(11,6),Vector2i(19,21),Vector2i(21,24),Vector2i(25,6),Vector2i(30,6),Vector2i(26,16),Vector2i(31,16),Vector2i(26,20),Vector2i(31,20)],
		"torches": [Vector2i(3,21),Vector2i(3,10),Vector2i(13,10),Vector2i(10,3),Vector2i(18,19),Vector2i(23,14),Vector2i(34,14),Vector2i(24,3),Vector2i(32,3),Vector2i(6,6)],
		"pickups": [["ammo",3,23],["health",4,23],["health",5,23],["ammo",3,11],["health",13,13],["rune",12,4],["ammo",13,8],["ammo",18,23],["health",22,24],["ammo",24,15],["ammo",34,21],["health",24,21],["health",34,15],["ammo",24,4],["health",33,9],["ammo",5,7],["health",6,8]],
		"enemies": [["gargoyle",5,18],["skeleton",4,11],["caster",12,11],["skeleton",7,14],["gargoyle",11,8],["caster",13,4],["guard",18,22],["skeleton",22,22],["caster",21,25],["gargoyle",19,12],["guard",24,4],["caster",31,8],["gargoyle",28,4],["skeleton",24,18],["skeleton",33,20],["regent",29,18]],
		"signs": [[3,21,"THE CASTLE GROUNDS\nFREEDOM LIES NORTH"],[6,10,"THE OLD GRAVEYARD"],[10,3,"NORTH WATCHTOWER\nWINCH I"],[18,19,"SOUTH WATCHTOWER\nWINCH II"],[27,14,"THE REGENT’S COURT"],[29,3,"THE LAST DRAWBRIDGE"]],
		"zones": [[Rect2i(0,20,17,9),"THE OUTER COURTYARD"],[Rect2i(0,9,17,11),"THE OLD GRAVEYARD"],[Rect2i(0,0,23,9),"NORTH WATCHTOWER"],[Rect2i(17,18,7,11),"SOUTH WATCHTOWER"],[Rect2i(23,11,14,18),"THE REGENT’S COURT"],[Rect2i(23,0,14,11),"THE LAST DRAWBRIDGE"]],
		"switches": [[Vector2i(10,4),"NORTH WINCH"],[Vector2i(22,25),"SOUTH WINCH"]],
		"route": [Vector2i(3,23),Vector2i(4,23),Vector2i(3,11),Vector2i(13,13),Vector2i(12,4),Vector2i(10,5),Vector2i(13,8),Vector2i(18,23),Vector2i(22,24),Vector2i(24,15),Vector2i(29,21),Vector2i(34,21),Vector2i(24,4),Vector2i(32,4)],
		"summons": [Vector2i(24,17),Vector2i(34,17),Vector2i(24,21),Vector2i(34,21)]
	}
