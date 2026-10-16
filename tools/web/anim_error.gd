extends RefCounted
## How far an animation is from its original, clip by clip: the one measure tools/web/compress_anims.gd (the check on each clip it
## compresses) and tools/web/anim_check.gd (the same check on the finished snapshot) share, so both mean the same by "off".
## The two animations are sampled side by side every 1/hz s and at the end; each rotation, position, scale and blend shape track
## of `a` is read from both and the largest difference of each kind kept. Their tracks, length, loop mode, step, name and metadata
## are compared as well (a web copy has to keep the clip's source attribution and sample rate).

const HZ := 120.0
## The limits a web copy has to stay within (a compressed clip's usual error: 0.36 degrees, 0.02 mm, 0.00001 in scale).
const MAX_ROT_DEG := 2.0
const MAX_POS_MM := 10.0
const MAX_SCALE := 0.01
const MAX_SHAPE := 0.02
## Metadata compress_anims.gd puts on a clip it left uncompressed: not a difference.
const KEPT := &"web_kept_uncompressed"


## `b` measured against `a` (the original): {rot (degrees), rot_at (s), rot_bone, pos_mm, pos_at, pos_bone, scale, shape,
## over_frames (samples where some rotation is beyond over_deg), same_layout (track count, types and paths, length, loop mode,
## step, name and, with_meta, metadata), compressed (b has a compressed track)}.
static func measure(a: Animation, b: Animation, hz := HZ, over_deg := MAX_ROT_DEG, with_meta := true) -> Dictionary:
	var r := {"rot": 0.0, "rot_at": 0.0, "rot_bone": "", "pos_mm": 0.0, "pos_at": 0.0, "pos_bone": "", "scale": 0.0, "shape": 0.0,
			"over_frames": 0, "same_layout": true, "compressed": false}
	if a.get_track_count() != b.get_track_count() or absf(a.length - b.length) > 1e-4 or a.loop_mode != b.loop_mode \
			or absf(a.step - b.step) > 1e-6 or a.resource_name != b.resource_name or (with_meta and not _same_meta(a, b)):
		r.same_layout = false
	var rot: PackedInt32Array = []
	var pos: PackedInt32Array = []
	var scl: PackedInt32Array = []
	var shp: PackedInt32Array = []
	for t in mini(a.get_track_count(), b.get_track_count()):
		if b.track_is_compressed(t):
			r.compressed = true
		var ty := a.track_get_type(t)
		# (a track's interpolation type is not compared: compress() turns a one-key track's nearest into linear, which changes
		# nothing; the sampled values show a real change)
		if ty != b.track_get_type(t) or a.track_get_path(t) != b.track_get_path(t):
			r.same_layout = false
			continue
		match ty:
			Animation.TYPE_ROTATION_3D: rot.append(t)
			Animation.TYPE_POSITION_3D: pos.append(t)
			Animation.TYPE_SCALE_3D: scl.append(t)
			Animation.TYPE_BLEND_SHAPE: shp.append(t)
	var length := a.length
	var frames := int(floor(length * hz + 1e-6)) + 1                 # (the grid's last step, then the end itself)
	for k in frames + 1:
		var tm := minf(float(k) / hz, length)
		var over := false
		for t in rot:
			var qa: Quaternion = a.rotation_track_interpolate(t, tm)
			var qb: Quaternion = b.rotation_track_interpolate(t, tm)
			var ang := rad_to_deg(2.0 * acos(clampf(absf(qa.dot(qb)), 0.0, 1.0)))
			if ang > r.rot:
				r.rot = ang
				r.rot_at = tm
				r.rot_bone = String(a.track_get_path(t)).get_slice(":", 1)
			over = over or ang > over_deg
		for t in pos:
			var d: float = (a.position_track_interpolate(t, tm) - b.position_track_interpolate(t, tm)).length() * 1000.0
			if d > r.pos_mm:
				r.pos_mm = d
				r.pos_at = tm
				r.pos_bone = String(a.track_get_path(t)).get_slice(":", 1)
		for t in scl:
			r.scale = maxf(r.scale, (a.scale_track_interpolate(t, tm) - b.scale_track_interpolate(t, tm)).length())
		for t in shp:
			r.shape = maxf(r.shape, absf(a.blend_shape_track_interpolate(t, tm) - b.blend_shape_track_interpolate(t, tm)))
		if over:
			r.over_frames += 1
		if tm >= length:
			break
	return r


static func _same_meta(a: Animation, b: Animation) -> bool:
	var kb := b.get_meta_list()
	if kb.has(KEPT):
		kb.erase(KEPT)
	var ka := a.get_meta_list()
	if ka.size() != kb.size():
		return false
	for k in ka:
		if not b.has_meta(k) or b.get_meta(k) != a.get_meta(k):
			return false
	return true


## Whether a measure() result is past a limit (or the copy's layout differs).
static func beyond(m: Dictionary, deg := MAX_ROT_DEG, mm := MAX_POS_MM, scale := MAX_SCALE, shape := MAX_SHAPE) -> bool:
	return m.rot > deg or m.pos_mm > mm or m.scale > scale or m.shape > shape or not m.same_layout


## One line for a log: "rot 5.20 deg at 0.31 s (r_wrist), pos 0.01 mm, scale 0.0000".
static func describe(m: Dictionary) -> String:
	var s := "rot %.2f deg at %.2f s (%s), pos %.2f mm at %.2f s (%s)" % [m.rot, m.rot_at, m.rot_bone, m.pos_mm, m.pos_at, m.pos_bone]
	if m.scale > 0.0001:
		s += ", scale %.4f" % m.scale
	if m.shape > 0.0001:
		s += ", blend shape %.4f" % m.shape
	if not m.same_layout:
		s += ", LAYOUT DIFFERS"
	return s
