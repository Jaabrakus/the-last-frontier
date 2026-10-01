extends RefCounted
## The frozen pose the crouched aim idle holds (bow, rifle, pistol; AnimGraphData.apply_aim_idle_poses): one frame of an
## aim clip on the torso and arms over one frame of another clip on the legs, hips and root, the torso turned so it keeps
## the aim clip's facing over legs that keep theirs. TreeBuilder bakes it into the aim tree's base;
## tools/anim_author/measure_aim_idle_trim.gd measures the barrel through the same pose.

## From an aim tree's base entry (sample_clip / sample_s, legs_clip / legs_s, lift, upper_base_rest: the rig's rest of
## upper_base, for a clip that leaves it unkeyed). `get_anim` maps a clip name to its Animation.
static func from_base(base: Dictionary, get_anim: Callable, bones_lower: PackedStringArray) -> Animation:
	return build(get_anim.call(String(base.sample_clip)), float(base.get("sample_s", 0.0)), get_anim.call(String(base.legs_clip)),
			float(base.get("legs_s", 0.0)), bones_lower, float(base.get("lift", 0.0)), base.get("upper_base_rest"))


## `bones_lower`: metrics bone_sets.lower (legs, pelvis, root). Keys are at t = 0, one frame long.
static func build(src: Animation, src_s: float, legs: Animation, legs_s: float, bones_lower: PackedStringArray,
		lift: float, upper_base_rest: Variant = null) -> Animation:
	var d := Animation.new()
	d.length = 1.0 / 30.0
	_copy(d, src, src_s, bones_lower, false, 0.0)
	_copy(d, legs, legs_s, bones_lower, true, lift)
	# The legs and the root are the legs' clip's alone; the aim's torso (upper_base and the *_offset arm drivers, the root's
	# children on the upper side) is turned by the difference of the two roots, so it keeps the aim clip's facing over legs that
	# keep theirs (user 2026-09-30: the shooting pose must not turn the legs).
	var delta := (_root_q(legs, legs_s).inverse() * _root_q(src, src_s)).normalized()
	# (a clip that leaves upper_base unkeyed holds it at the rest: key the rest, so it can turn)
	var has_ub := false
	for i in d.get_track_count():
		if String(d.track_get_path(i).get_concatenated_subnames()) == "upper_base" and d.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			has_ub = true
	if not has_ub and upper_base_rest != null:
		var rt := d.add_track(Animation.TYPE_ROTATION_3D)
		d.track_set_path(rt, NodePath("Skeleton3D:upper_base"))
		d.rotation_track_insert_key(rt, 0.0, (upper_base_rest as Transform3D).basis.get_rotation_quaternion())
		var pt := d.add_track(Animation.TYPE_POSITION_3D)
		d.track_set_path(pt, NodePath("Skeleton3D:upper_base"))
		d.position_track_insert_key(pt, 0.0, (upper_base_rest as Transform3D).origin)
	for i in d.get_track_count():
		var b := String(d.track_get_path(i).get_concatenated_subnames())
		if b != "upper_base" and not b.ends_with("_offset"):
			continue
		if d.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			d.rotation_track_insert_key(i, 0.0, (delta * d.rotation_track_interpolate(i, 0.0)).normalized())
		elif d.track_get_type(i) == Animation.TYPE_POSITION_3D:
			d.position_track_insert_key(i, 0.0, delta * d.position_track_interpolate(i, 0.0))
	for m in [&"source_attribution", &"native_asset_id", &"original_name"]:
		if src.has_meta(m):
			d.set_meta(m, src.get_meta(m))
	d.set_meta(&"native_asset_ids", [src.get_meta(&"native_asset_id", ""), legs.get_meta(&"native_asset_id", "")])
	d.set_meta(&"original_names", [src.get_meta(&"original_name", ""), legs.get_meta(&"original_name", "")])
	d.set_meta(&"additive_source", false)
	return d


static func _root_q(a: Animation, t: float) -> Quaternion:
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D and String(a.track_get_path(i)).ends_with(":root"):
			return a.rotation_track_interpolate(i, clampf(t, 0.0, a.length))
	return Quaternion.IDENTITY


static func _copy(d: Animation, a: Animation, t: float, lower: PackedStringArray, want_lower: bool, lift: float) -> void:
	var tt := clampf(t, 0.0, a.length)
	for tr in a.get_track_count():
		var tp := a.track_get_path(tr)
		var b := String(tp.get_concatenated_subnames())
		if b == "" or lower.has(b) != want_lower:
			continue
		var ty := a.track_get_type(tr)
		if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D and ty != Animation.TYPE_SCALE_3D:
			continue
		var nt := d.add_track(ty)
		d.track_set_path(nt, tp)
		match ty:
			Animation.TYPE_ROTATION_3D:
				d.rotation_track_insert_key(nt, 0.0, a.rotation_track_interpolate(tr, tt))
			Animation.TYPE_POSITION_3D:
				var p := a.position_track_interpolate(tr, tt)
				if want_lower and b == "root":
					p.y += lift
				d.position_track_insert_key(nt, 0.0, p)
			Animation.TYPE_SCALE_3D:
				d.scale_track_insert_key(nt, 0.0, a.scale_track_interpolate(tr, tt))
