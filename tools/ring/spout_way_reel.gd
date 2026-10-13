extends "res://tools/ring/move_reel.gd"
## The Geyser's ways filmed for the owner (2026-10-12: "do the same for geyser allow water from the side of the ring or the
## vents to shoot and attac ksomeone side ways"; BendVariants): up, throw right, throw left, and from the water twice (the bot
## 2.2 m along the deck from a grate; then 1.5 m in from an end's lip, the jet out of the tank under it: across the picture), each
## cast through the player's keys with its way picked as he picks it (key 2 held and a direction), the move reel's staging,
## camera and captions:
##   GODOT_TIMEOUT=1800 zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 --write-movie <dir>/raw.avi \
##     -s tools/ring/spout_way_reel.gd -- out=<dir> fps=60 size=1280x720 quality=high upscale=off music=off character_look=soft
##     [cam=behind]
## Cut as the move reel is: python3 tools/ring/move_reel_cut.py <dir> <out>.

const PICK_KEY := {"up": &"move_forward", "right": &"move_right", "left": &"move_left", "water": &"move_back"}
const WIDE_SIDE := 11.0

var _wide := false


## The move reel's side camera, WIDE_SIDE back (the water, the bot, the player and the column all in it).
func _cam(dt: float) -> Array:
	if not _wide or String(args.get("cam", "")) == "behind":
		return super._cam(dt)
	var ring := mode.ring
	var ax := ring.axis()
	var across := ax.cross(Vector3.UP).normalized()
	return [_cam_mid + across * WIDE_SIDE + Vector3.UP * 1.8 - ax * 0.3, _cam_mid, CAM_FOV]


func _order() -> Array:
	return ["water"]


func _shots_of(_el: String) -> Array:
	return [
		{"kind": "sw", "key": 2, "id": "wave", "mode": "spout", "way": "up", "at": "mid", "label": "Geyser  ·  up", "detail": "as before: the knock-up"},
		{"kind": "sw", "key": 2, "id": "wave", "mode": "spout", "way": "right", "at": "mid", "label": "Geyser  ·  throw right", "detail": "2 held + D: it erupts leaning, throws him right"},
		{"kind": "sw", "key": 2, "id": "wave", "mode": "spout", "way": "left", "at": "mid", "label": "Geyser  ·  throw left", "detail": "2 held + A"},
		{"kind": "sw", "key": 2, "id": "wave", "mode": "spout", "way": "water", "at": "grate", "label": "Geyser  ·  from the water", "detail": "2 held + S: a jet out of the nearest grate"},
		{"kind": "sw", "key": 2, "id": "wave", "mode": "spout", "way": "water", "at": "lip", "label": "Geyser  ·  from the water", "detail": "by the edge: a jet out of the tank"},
	]


## A shot staged by water: {foe, player, src} (world, on the deck), the jet's line across the picture (along the deck's long
## axis, the side camera's left-right): the bot 2.2 m along the deck from a grate, toward the middle; or 1.5 m in from an end's
## lip (the tank behind it); the player 4 m off on the far side, a little toward the middle. {} for the middle (the staging's).
func _spot(where: String) -> Dictionary:
	var ring := mode.ring
	var ax := ring.axis()
	var across := ax.cross(Vector3.UP).normalized()       # (the camera's side: _cam)
	var mid := ring.center()
	var src := Vector3.INF
	var foe_at := Vector3.INF
	if where == "grate":
		for g: Node3D in ring.pools():
			var gp := g.global_position
			var s := (gp - mid).dot(ax)
			if absf(s) > 4.0 and absf(s) < 9.0 and (gp - mid).dot(across) < 0.0:
				src = Vector3(gp.x, mid.y, gp.z)
				foe_at = src - ax * signf(s) * 2.2
				break
	elif where == "lip":
		src = mid + ax * ring.half_l()
		foe_at = mid + ax * (ring.half_l() - 1.5)
	if not foe_at.is_finite():
		return {}
	# (the player on the deck beside the water's end of the line, toward the deck's middle across it: never on the jet's line)
	var inward := signf((mid - foe_at).dot(ax))
	var lat := (foe_at - mid).dot(across)
	var to_mid := -across * signf(lat) if absf(lat) > 0.5 else -across
	return {"foe": foe_at, "player": foe_at + to_mid * 3.5 - ax * inward * 1.0, "src": src}


func _do(sh: Dictionary) -> void:
	if String(sh.kind) != "sw":
		await super._do(sh)
		return
	var ring := mode.ring
	var foe: Node3D = mode.foe
	var sp := _spot(String(sh.get("at", "mid")))
	_wide = true
	if sp.is_empty():
		# (the middle: framed toward the bot, high enough for the column over him)
		_cam_mid = player.global_position.lerp(foe.global_position, 0.62)
		_cam_mid.y = ring.top() + 1.6
	else:
		foe.global_position = (sp.foe as Vector3) + Vector3.UP * 0.05
		player.global_position = (sp.player as Vector3) + Vector3.UP * 0.05
		for b: CharacterBody3D in [player, foe]:
			b.velocity = Vector3.ZERO
		_cam_mid = ((sp.foe as Vector3) + (sp.player as Vector3) + (sp.src as Vector3)) / 3.0
		_cam_mid.y = ring.top() + 1.2
		_cam_from = player.global_position
		_cam_from.y = ring.top()
		await _frames(0.5)
	# (the way picked as a player picks it: the Geyser readied by key 2, key 2 held, the direction tapped, let go)
	await _key(&"weapon_2")
	var sc := SwayCaster.of(player)
	if sc.mode_of("wave") != "spout":
		await _key(&"weapon_2")
	_ctl.set_held(&"weapon_2", true)
	await _frames(0.05)
	_ctl.set_held(PICK_KEY[String(sh.way)], true)
	await _frames(0.05)
	_ctl.release_all()
	if BendVariants.of(player, "wave", "spout") != String(sh.way):
		print("MOVE REEL WAY FALLBACK %s" % sh.way)
		BendVariants.set_to(player, "wave", "spout", String(sh.way))
	await _cast_one("wave", "spout", false)
	await _frames(SHOT_S - 0.6)
