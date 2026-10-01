class_name TravMoveMirror
extends RefCounted
## Moves for the other hand (user 2026-09-30: the right-hand vault in the traversal table): the left-right mirror of a move, made
## when the table loads (TravMoveLibrary) and its clips when an actor sets up its AnimationPlayer (ensure_clips), so neither the
## table's builder nor the clip libraries carry them. The sprint vault plants the left hand and sweeps the legs to the right; its
## mirror plants the right hand and sweeps them to the left. Which one plays is chosen by the foot the body is on
## (TravMoveSelector: the move whose `lead` foot is the one forward when the move is planned).
##   move:  every lateral thing negated (track points, contacts, the anchor, the end align, the entry and exit velocities), the
##          limbs' sides swapped, the gait phases it matches half a cycle on (the other foot), the clips renamed (clip_name()).
##   clips: each bone takes its partner's rotation away from the rest pose, reflected in the skeleton's YZ plane (the rig is
##          symmetric at rest); positions reflected likewise. Made from whatever the actor plays for the original part (our own
##          clip, or the source's with --source-traversal), added to its LIB library.

## mirror move id -> {of: the move mirrored, lead: the foot it takes off from}; the original's lead is the other foot.
const MIRRORS := {"vault_sprint_r": {"of": "vault_sprint", "lead": "r"}}
const SUFFIX := "-mirror"
## Samples per second of a mirrored clip.
const HZ := 60.0


static func clip_name(c: String) -> String:
	return c + SUFFIX


## Adds the mirrored moves to a loaded table's moves (and marks the originals' lead foot).
static func add_moves(moves: Dictionary) -> void:
	for id: String in MIRRORS:
		var spec: Dictionary = MIRRORS[id]
		if not moves.has(spec.of) or moves.has(id):
			continue
		var src: Dictionary = moves[spec.of]
		src["lead"] = "l" if spec.lead == "r" else "r"
		var m := mirror_move(src)
		m["lead"] = spec.lead
		m["mirror_of"] = spec.of
		moves[id] = m


static func _side(s: String) -> String:
	if s.begins_with("l_"):
		return "r_" + s.substr(2)
	if s.begins_with("r_"):
		return "l_" + s.substr(2)
	return s


static func _mx(v: Variant) -> Variant:
	if v is Array and (v as Array).size() == 3:
		return [-float(v[0]), v[1], v[2]]
	return v


static func mirror_move(src: Dictionary) -> Dictionary:
	var m: Dictionary = src.duplicate(true)
	for k in ["end_align", "entry_velocity", "exit_velocity"]:
		if m.has(k):
			m[k] = _mx(m[k])
	var parts: Array = m.get("parts", [])
	for p: Dictionary in parts:
		p["clip"] = clip_name(String(p.clip))
	for c: Dictionary in m.get("contacts", []):
		c["limb"] = _side(String(c.get("limb", "")))
		c["pos"] = _mx(c.get("pos"))
	for c: Dictionary in m.get("contacts_annotated", []):
		c["limb"] = _side(String(c.get("limb", "")))
	var an: Dictionary = m.get("anchor", {})
	if an.has("primary") and an.primary is Dictionary:
		an.primary["limb"] = _side(String(an.primary.get("limb", "")))
		an.primary["pos"] = _mx(an.primary.get("pos"))
	# the world effector tracks: flat [x, y, z, ...] per point, sides swapped
	var tr: Dictionary = m.get("track", {})
	var out := {}
	for k: String in tr:
		var v: Variant = tr[k]
		if v is Array:
			var a: Array = (v as Array).duplicate()
			for i in range(0, a.size() - 2, 3):
				a[i] = -float(a[i])
			out[_side(k)] = a
		else:
			out[k] = v
	m["track"] = out
	# the gait it is entered from and handed back to: the same step on the other foot, half a cycle on
	var lm: Dictionary = m.get("loco_match", {})
	for end: String in lm:
		for g: String in lm[end]:
			var e: Dictionary = lm[end][g]
			if e.has("phase"):
				e["phase"] = fposmod(float(e.phase) + 0.5, 1.0)
	return m


## The mirrored clips of every mirrored move, made from what `anim_name` (original clip -> the AnimationPlayer's name) plays and
## added to `lib_name` (as clip_name(original)). Clips already there are kept.
static func ensure_clips(ap: AnimationPlayer, sk: Skeleton3D, lib: TravMoveLibrary, anim_name: Callable, lib_name: StringName) -> void:
	if ap == null or sk == null or lib == null or not ap.has_animation_library(lib_name):
		return
	var al := ap.get_animation_library(lib_name)
	for id: String in MIRRORS:
		var of: Dictionary = lib.move(String(MIRRORS[id].of))
		for p: Dictionary in of.get("parts", []):
			var cn := clip_name(String(p.clip))
			if al.has_animation(StringName(cn)):
				continue
			var a := ap.get_animation(String(anim_name.call(String(p.clip))))
			if a != null:
				al.add_animation(StringName(cn), mirror_clip(a, sk))


## The left-right mirror of a clip on `sk`'s rig.
static func mirror_clip(src: Animation, sk: Skeleton3D) -> Animation:
	var n := sk.get_bone_count()
	var partner := PackedInt32Array()
	partner.resize(n)
	var rest_l: Array[Quaternion] = []
	var grest: Array[Quaternion] = []
	rest_l.resize(n)
	grest.resize(n)
	for i in n:
		var pi := sk.find_bone(_side(sk.get_bone_name(i)))
		partner[i] = pi if pi >= 0 else i
		rest_l[i] = sk.get_bone_rest(i).basis.get_rotation_quaternion()
	var order := _order(sk)
	for i in order:
		var par := sk.get_bone_parent(i)
		grest[i] = rest_l[i] if par < 0 else (grest[par] * rest_l[i]).normalized()
	# the tracks: each keyed bone's and its partner's
	var rot_t := {}
	var pos_t := {}
	for ti in src.get_track_count():
		var b := sk.find_bone(String(src.track_get_path(ti).get_concatenated_subnames()))
		if b < 0:
			continue
		match src.track_get_type(ti):
			Animation.TYPE_ROTATION_3D:
				rot_t[b] = ti
			Animation.TYPE_POSITION_3D:
				pos_t[b] = ti
	var out_bones := {}
	for b: int in rot_t:
		out_bones[b] = true
		out_bones[partner[b]] = true
	var prefix := String(src.track_get_path(0)).get_slice(":", 0)
	var a := Animation.new()
	a.length = src.length
	a.loop_mode = src.loop_mode
	for m in src.get_meta_list():
		a.set_meta(m, src.get_meta(m))
	a.set_meta(&"authored", "Frontier: the left-right mirror of %s (TravMoveMirror)" % src.resource_name)
	var out_rot := {}
	for b: int in out_bones:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath(prefix + ":" + sk.get_bone_name(b)))
		out_rot[b] = t
	var out_pos := {}
	for b: int in pos_t:
		var t := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(t, NodePath(prefix + ":" + sk.get_bone_name(partner[b])))
		out_pos[b] = t
	var frames := int(ceil(src.length * HZ))
	var g: Array[Quaternion] = []
	var gm: Array[Quaternion] = []
	g.resize(n)
	gm.resize(n)
	for f in frames + 1:
		var tm := minf(float(f) / HZ, src.length)
		for i in order:
			var lq: Quaternion = src.rotation_track_interpolate(rot_t[i], tm) if rot_t.has(i) else rest_l[i]
			var par := sk.get_bone_parent(i)
			g[i] = lq.normalized() if par < 0 else (g[par] * lq).normalized()
		for i in n:
			var pn := partner[i]
			var d := g[pn] * grest[pn].inverse()
			var dm := Quaternion(d.x, -d.y, -d.z, d.w)
			gm[i] = (dm * grest[i]).normalized()
		for b: int in out_rot:
			var par := sk.get_bone_parent(b)
			var lq := gm[b] if par < 0 else (gm[par].inverse() * gm[b]).normalized()
			a.rotation_track_insert_key(out_rot[b], tm, lq)
		for b: int in pos_t:
			# the position in the skeleton's space (the parent's rotation on it), reflected, back under the mirrored parent
			var par := sk.get_bone_parent(b)
			var p: Vector3 = src.position_track_interpolate(pos_t[b], tm)
			var ps := p if par < 0 else g[par] * p
			ps.x = -ps.x
			var pp := partner[b]
			var ppar := sk.get_bone_parent(pp)
			a.position_track_insert_key(out_pos[b], tm, ps if ppar < 0 else gm[ppar].inverse() * ps)
	return a


## The bones parents first.
static func _order(sk: Skeleton3D) -> PackedInt32Array:
	var out := PackedInt32Array()
	var stack: Array = Array(sk.get_parentless_bones())
	while not stack.is_empty():
		var b: int = stack.pop_back()
		out.append(b)
		for c in sk.get_bone_children(b):
			stack.append(c)
	return out
