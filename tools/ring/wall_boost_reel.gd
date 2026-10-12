extends "res://tools/ring/move_reel.gd"
## The walls' boosts filmed for the owner (2026-10-12: "a fire spell going thru a fire wall can boost other fire spells", "water
## wall bigger or faster", "if a boulder hits it ... tears off a piece of the wall and it continues", "ice lance can slice thru
## win walls"), the move reel's own staging, camera and captions: each spell cast through the player's keys, plain first where
## it helps to compare, then through the wall (his own, set up first; the Wind Wall the bot's):
##   GODOT_TIMEOUT=1800 zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 --write-movie <dir>/raw.avi \
##     -s tools/ring/wall_boost_reel.gd -- out=<dir> fps=60 size=1280x720 quality=high upscale=off music=off character_look=soft
##     [cam=behind]
## Cut as the move reel is: python3 tools/ring/move_reel_cut.py <dir> <out>.


func _order() -> Array:
	return ["fire", "water", "earth"]


func _shots_of(el: String) -> Array:
	match el:
		"fire":
			return [
				{"kind": "wb", "key": 1, "id": "fire_blast", "mode": "punch", "wall": "", "label": "Punch", "detail": "plain, to compare"},
				{"kind": "wb", "key": 1, "id": "fire_blast", "mode": "punch", "wall": "fire_own",
						"label": "Punch through your Fire Wall", "detail": "comes out bigger and faster, hits harder"},
			]
		"water":
			return [
				{"kind": "wb", "key": 1, "id": "water_whip", "mode": "whip", "wall": "", "label": "Lash", "detail": "plain, to compare"},
				{"kind": "wb", "key": 1, "id": "water_whip", "mode": "whip", "wall": "ice_own",
						"label": "Lash through your Ice Wall", "detail": "freezes to ice, faster; frost where it lands"},
				{"kind": "wb", "key": 1, "id": "ice", "mode": "spear", "wall": "wind_foe",
						"label": "Ice Spear through their Wind Wall", "detail": "slices straight through"},
				{"kind": "wb", "key": 1, "id": "water_whip", "mode": "whip", "wall": "wind_foe",
						"label": "Lash into their Wind Wall", "detail": "blown aside, as before"},
			]
		"earth":
			return [
				{"kind": "wb", "key": 1, "id": "stone_form", "mode": "cannonball", "wall": "earth_own",
						"label": "Boulder through your Earth Wall", "detail": "tears a piece off, flies on bigger"},
			]
	return []


func _do(sh: Dictionary) -> void:
	if String(sh.kind) != "wb":
		await super._do(sh)
		return
	var ring := mode.ring
	var ax := ring.axis()
	var foe: Node3D = mode.foe
	var bc := BendCaster.of(player)
	var at := FormEffects.ground_at(player, ring.center() + ax * (P_S + 2.6))
	match String(sh.wall):
		"fire_own":
			BendZone.make(player, "fire_wall", at, (SwayMoves.move("fire_wall").bend as Dictionary).wall, ax)
		"ice_own":
			BendEffects.ice_wall(bc, ax, (SwayMoves.move("water_shield").bend as Dictionary).ice_wall)
		"earth_own":
			FormEffects.earth_wall(bc, at, SwayMoves.move("earth_wall"), "earth")
		"wind_foe":
			BendZone.make(foe, "wind_wall", FormEffects.ground_at(player, ring.center() + ax * (B_S - 3.0)),
					(SwayMoves.move("air_wall").bend as Dictionary).wall, -ax)
	if String(sh.wall) != "":
		await _frames(0.9)                             # (the wall up)
	await _cast_one(String(sh.id), String(sh.mode), false)
	await _frames(SHOT_S - 0.6)
