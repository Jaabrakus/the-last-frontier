extends "res://tools/ring/move_reel.gd"
## Earth's Column's ways filmed for the owner (2026-10-12: "the column ramp left to shoot them right"; BendVariants): up, throw
## right, throw left, and from a wall (an Earth Wall raised beside the bot first), each cast through the player's keys with
## its way picked as he picks it (key 2 held and a direction), the move reel's staging, camera and captions:
##   GODOT_TIMEOUT=1800 zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 --write-movie <dir>/raw.avi \
##     -s tools/ring/column_way_reel.gd -- out=<dir> fps=60 size=1280x720 quality=high upscale=off music=off character_look=soft
##     [cam=behind]
## Cut as the move reel is: python3 tools/ring/move_reel_cut.py <dir> <out>.

const PICK_KEY := {"up": &"move_forward", "right": &"move_right", "left": &"move_left", "wall": &"move_back"}


func _order() -> Array:
	return ["earth"]


func _shots_of(_el: String) -> Array:
	return [
		{"kind": "cw", "key": 2, "id": "earth_shove", "mode": "column", "way": "up", "label": "Column  ·  up", "detail": "as before: the knock-up"},
		{"kind": "cw", "key": 2, "id": "earth_shove", "mode": "column", "way": "right", "label": "Column  ·  throw right", "detail": "2 held + D: it rises leaning, throws him right"},
		{"kind": "cw", "key": 2, "id": "earth_shove", "mode": "column", "way": "left", "label": "Column  ·  throw left", "detail": "2 held + A"},
		{"kind": "cw", "key": 2, "id": "earth_shove", "mode": "column", "way": "wall", "label": "Column  ·  from a wall", "detail": "2 held + S: out of the nearest Earth Wall's face"},
	]


func _do(sh: Dictionary) -> void:
	if String(sh.kind) != "cw":
		await super._do(sh)
		return
	var ring := mode.ring
	var ax := ring.axis()
	var foe: Node3D = mode.foe
	if String(sh.way) == "wall":
		var right := ax.cross(Vector3.UP).normalized()
		var ew := FormEffects.earth_wall(BendCaster.of(foe), FormEffects.ground_at(player, foe.global_position - right * 1.4),
				SwayMoves.move("earth_wall"), "earth")
		if ew != null:
			ew.global_basis = Basis(ax, Vector3.UP, -right)
		await _frames(0.9)
	# (the way picked as a player picks it: key 2 held, the direction tapped, let go)
	await _key(&"weapon_2")
	var sc := SwayCaster.of(player)
	if sc.mode_of("earth_shove") != "column":
		await _key(&"weapon_2")
	_ctl.set_held(&"weapon_2", true)
	await _frames(0.05)
	_ctl.set_held(PICK_KEY[String(sh.way)], true)
	await _frames(0.05)
	_ctl.release_all()
	if BendVariants.of(player, "earth_shove", "column") != String(sh.way):
		print("MOVE REEL WAY FALLBACK %s" % sh.way)
		BendVariants.set_to(player, "earth_shove", "column", String(sh.way))
	await _cast_one("earth_shove", "column", false)
	await _frames(SHOT_S - 0.6)
