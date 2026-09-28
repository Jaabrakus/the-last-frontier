class_name LoadoutClipPoser
extends RefCounted
## Poses the Actor_B skeleton from clips of its AnimationPlayer, channel by channel, the way the
## deterministic mixer composes them (and the loadout survey measured them,
## tools/loadout/measure_body_fit.gd _pose): every bone starts at its rest (= the bind pose null-add),
## a full-body clip overwrites the channels it keys, a partial ("--part", "--arm-r") overwrites its
## channels on top of a base clip, and an additive twin ("--add") composes as base * rest^-1 * add.
## The clips are read from the AnimationPlayer's library as they are (native asset ids untouched).
##
##   var poser := LoadoutClipPoser.new(skeleton, anim_player)    # anim_player.active is set false
##   poser.pose([["actor_b-p-stealth-idle", 1.2], ["actor_b-p-stealth-draw-p^idle--arm-r--no-pack", 0.3, "partial"],
##               ["actor_b-p-stealth-draw-p^idle--add--no-pack", 0.3, "add"]])

const LIB := "actor_b/"

var skeleton: Skeleton3D
var player: AnimationPlayer
## Keep the root's horizontal position at the rest value (clips that walk off stay in place).
var in_place := true
var _bone := {}
var _tracks := {}


func _init(sk: Skeleton3D, ap: AnimationPlayer) -> void:
	skeleton = sk
	player = ap
	if ap:
		ap.active = false
	for b in sk.get_bone_count():
		_bone[sk.get_bone_name(b)] = b


static func full_name(clip: String) -> String:
	return clip if "/" in clip else LIB + clip


func has_clip(clip: String) -> bool:
	return player != null and player.has_animation(full_name(clip))


func length(clip: String) -> float:
	return player.get_animation(full_name(clip)).length if has_clip(clip) else 0.0


## layers: [[clip, t, mode]] with mode "" (full body / overwrite, the default), "partial" (same:
## overwrites its channels) or "add" (additive twin). Starts from the rest pose.
func pose(layers: Array) -> void:
	skeleton.reset_bone_poses()
	for l: Array in layers:
		var clip: String = l[0]
		if clip == "" or not has_clip(clip):
			continue
		var a := player.get_animation(full_name(clip))
		var t := clampf(float(l[1]), 0.0, a.length)
		var w := float(l[3]) if l.size() > 3 else 1.0
		_apply(a, t, l.size() > 2 and String(l[2]) == "add", w)
	if in_place and _bone.has("root"):
		var r: int = _bone["root"]
		var p := skeleton.get_bone_pose_position(r)
		var rest := skeleton.get_bone_rest(r).origin
		skeleton.set_bone_pose_position(r, Vector3(rest.x, p.y, rest.z))


func _tracks_of(anim: Animation) -> Array:
	if not _tracks.has(anim):
		var tr: Array = []
		for t in anim.get_track_count():
			if not anim.track_is_enabled(t):
				continue
			var bn := str(anim.track_get_path(t).get_concatenated_subnames())
			if not _bone.has(bn):
				continue
			tr.append([t, int(_bone[bn]), anim.track_get_type(t)])
		_tracks[anim] = tr
	return _tracks[anim]


## Applies a clip at time t: overwrite (weight blends from the current pose) or additive (weight scales
## the delta).
func _apply(anim: Animation, t: float, additive: bool, w := 1.0) -> void:
	for e: Array in _tracks_of(anim):
		var tr: int = e[0]
		var b: int = e[1]
		match int(e[2]):
			Animation.TYPE_POSITION_3D:
				var p := anim.position_track_interpolate(tr, t)
				var cur := skeleton.get_bone_pose_position(b)
				if additive:
					skeleton.set_bone_pose_position(b, cur + (p - skeleton.get_bone_rest(b).origin) * w)
				else:
					skeleton.set_bone_pose_position(b, cur.lerp(p, w))
			Animation.TYPE_ROTATION_3D:
				var q := anim.rotation_track_interpolate(tr, t).normalized()
				var cur := skeleton.get_bone_pose_rotation(b)
				if additive:
					var rq := skeleton.get_bone_rest(b).basis.get_rotation_quaternion()
					var dq := rq.inverse() * q
					if w < 1.0:
						dq = Quaternion.IDENTITY.slerp(dq, w)
					skeleton.set_bone_pose_rotation(b, (cur * dq).normalized())
				else:
					skeleton.set_bone_pose_rotation(b, cur.slerp(q, w).normalized() if w < 1.0 else q)
			Animation.TYPE_SCALE_3D:
				if not additive and w >= 0.5:
					skeleton.set_bone_pose_scale(b, anim.scale_track_interpolate(tr, t))


## The twin additive of a partial draw clip ("--arm-r" / "--part" -> "--add"), "" when the library has none.
func twin_of(clip: String) -> String:
	for suf in ["--arm-r", "--part"]:
		if clip.contains(suf):
			var c := clip.replace(suf, "--add")
			if has_clip(c):
				return c
	return ""
