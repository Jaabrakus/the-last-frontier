extends RefCounted
## Rebind imported tandem animation tracks to Frontier's existing Actor_B rig.
## Copies resources; no edits to the shared normal locomotion library.

static func install(player: AnimationPlayer, skeleton: Skeleton3D, source: String, library_name: StringName) -> void:
	if player.has_animation_library(library_name): return
	var instance := (load(source) as PackedScene).instantiate()
	var source_player := instance.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	var library := AnimationLibrary.new()
	for clip_name in source_player.get_animation_list():
		library.add_animation(clip_name, retarget(source_player.get_animation(clip_name), player, skeleton))
	player.add_animation_library(library_name, library)
	instance.free()

static func retarget(source: Animation, player: AnimationPlayer, skeleton: Skeleton3D) -> Animation:
	var clip := source.duplicate(true) as Animation
	var path := player.get_node(player.root_node).get_path_to(skeleton)
	for i in range(clip.get_track_count() - 1, -1, -1):
		var old := clip.track_get_path(i)
		if old.get_subname_count() == 0 or skeleton.find_bone(old.get_subname(0)) < 0:
			clip.remove_track(i)
		else:
			clip.track_set_path(i, NodePath(String(path) + ":" + String(old.get_subname(0))))
	return clip


## The flinch gauge on a clip: `clip` played `fullness` of the way from its first pose to its full extent (1: as
## authored; less: a lighter flinch; more: a fuller one). The scaled copy is made once, in steps of 5 %, and kept in
## the player's animation library as "<clip>@<percent>". Returns the (qualified) name to play.
static func variant(player: AnimationPlayer, library: StringName, clip: String, fullness: float) -> StringName:
	var pct := int(roundf(clampf(fullness, 0.2, 1.6) * 20.0)) * 5
	var full := StringName(clip if library == &"" or clip.contains("/") else String(library) + "/" + clip)
	if pct == 100:
		return full
	var lib_name := StringName(clip.get_slice("/", 0)) if clip.contains("/") else library
	var short := clip.get_slice("/", clip.get_slice_count("/") - 1)
	var lib := player.get_animation_library(lib_name)
	var src := player.get_animation(full)
	if lib == null or src == null:
		return full
	var name := "%s@%d" % [short, pct]
	if not lib.has_animation(name):
		var scaled := scale_clip(src, pct / 100.0)
		scaled.loop_mode = src.loop_mode
		lib.add_animation(name, scaled)
	return StringName(name if lib_name == &"" else String(lib_name) + "/" + name)

## A copy of `src` whose every key is `f` of the way from the clip's first key (its starting pose) to where it was.
static func scale_clip(src: Animation, f: float) -> Animation:
	var a := src.duplicate(true) as Animation
	for i in a.get_track_count():
		var n := a.track_get_key_count(i)
		if n < 2: continue
		var type := a.track_get_type(i)
		var k0 = a.track_get_key_value(i, 0)
		for k in range(1, n):
			var v = a.track_get_key_value(i, k)
			match type:
				Animation.TYPE_ROTATION_3D:
					a.track_set_key_value(i, k, _scale_rotation(k0, v, f))
				Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D:
					a.track_set_key_value(i, k, k0 + (v - k0) * f)
				Animation.TYPE_VALUE, Animation.TYPE_BLEND_SHAPE:
					if typeof(v) in [TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3]:
						a.track_set_key_value(i, k, k0 + (v - k0) * f)
	return a

## q0 turned `f` of the way (beyond 1: further) toward q, the short way round.
static func _scale_rotation(q0: Quaternion, q: Quaternion, f: float) -> Quaternion:
	var a := q0.normalized()
	var d := (a.inverse() * q.normalized()).normalized()
	if d.w < 0.0:
		d = Quaternion(-d.x, -d.y, -d.z, -d.w)
	var axis := Vector3(d.x, d.y, d.z)
	var s := axis.length()
	if s < 1e-6:
		return a
	return (a * Quaternion(axis / s, 2.0 * atan2(s, d.w) * f)).normalized()
