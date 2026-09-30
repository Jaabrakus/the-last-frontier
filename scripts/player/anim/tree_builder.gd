class_name TreeBuilder
extends RefCounted
## Builds the player's AnimationTree root from AnimGraphData (plan section 6.1, WP3). One
## BlendTree per PlayerAnim; the result is a TreeIndex (tree_root + every parameter path).
##
## Layout, from the output down:
##
##   output
##    <- HA__<clip>   OneShot ADD per light-hit additive (runtime_clips.hit_add[_by_stance])
##    <- TU / TL      thrown weapons (graph throw-object-* states, THROW): two script-weighted Blend2
##                    chains over the pose below, TU_x<k> filtered to the upper-body / hands bones the
##                    throw clips key and TL_x<k> to their other keyed bones (root, pelvis, legs,
##                    holsters: the full-body throw of a stationary throw); inputs TU__<clip> /
##                    TL__<clip> are nested BlendTrees like single lower inputs (UpperBody's ThrowChain)
##    <- X__<clip>    OneShot per action partial, filtered to that clip's keyed bones except the
##                    weapon prop bones (PROP_BONES: PropFlipGuard crossfades the partials on them)
##                    (<p>__ <- <p>T__ TimeScale <- <p>S__ TimeSeek, holster clips only <- <p>C__)
##    <- F__<clip>    OneShot ADD per fire additive (runtime_clips.fire; the charge weapon's fire
##                    clips fade with tuning charge_fire_fade, the handoff from the held draw)
##    <- CC__<clip>   OneShot ADD per crouch-change additive (crouch_change.*.add)
##    <- XA__<clip>   OneShot ADD per action twin (actions.*.twin), filtered to the bones its
##                    partial does not key when they share bones
##    <- C_add        Add2 bow charge: C_st Blend2(stand, crouch) <- C_seek_<s> <- C_ts_<s> (scale 0)
##    <- H__<w>__<k>  exact-grip override (override_exact_hands_grip; amounts 0 by default): one
##                    Blend2 per distinct grip clip of each weapon (k = carry | aim_s | aim_c) over
##                    HC__<w>__<k>, filtered to bone_sets.hands AND the bones that clip keys, so a
##                    hands bone the grip does not key keeps the graph pose (a grip that keys one
##                    hand leaves the other hand free). Chained smallest filter first (nested
##                    filters: TreeIndex.grip_targets gives every hands bone its exact weights).
##    <- U_aim        Blend2 filtered to bone_sets.upper, amount = upper aim weight, over the
##                    A chain of A__<w>__<s>: base (+ hands layer hl) -> add_up -> add_dn -> blk
##                    -> rel -> seek -> ts (the graph aim-idle tree order)
##    <- WO__<clip>   Blend2 filtered per weapon-out finger clip (graph idle-pistol-out-part)
##    <- K__<w>__<i>  shared carry-layer stack per weapon (only with the opt-in carry "shared")
##    <- L chain      Blend2 chain (sync=false) over the lower inputs L__<id>
##
##   Action partials sit above the additives (WP6 review): a partial is the authored pose of the
##   bones it keys, so an additive under it (fire kick, held draw, twin) does not move those
##   bones while the action plays. The bow's nock twins (bow-reload--add, crouch-bow-reload--add)
##   key 14 of the partial's arm bones with deltas up to 3.1 rad from the bind pose: added on top
##   they put the arrow hand 0.7-1.5 m from the bow, and they pop the wrists at 90-170 rad/s; the
##   bow's fire additive (2.2 rad at the drawing shoulder) did the same over the nock that
##   follows each shot.
##
## Lower inputs (nested BlendTrees, one per distinct content; see TreeIndex for the records):
##   single   output <- ts <- seek <- carry stack <- clip
##   bank     output <- hemi_x1 (Blend2 fw/bw) <- <h>_ts <- <h>_seek <- <h> carry stack <- bank
##            bank (bank_kind "diff", default): Add2(Add2(<h>_c, <h>_dneg, w_neg), <h>_dpos, w_pos)
##              with difference clips rest * center^-1 * side baked on the normalized timeline:
##              Add2 gives center * (center^-1 side)^w = slerp(center, side, w), the graph's
##              direction chain exactly (ec_bank_gap); bank_kind "blendspace": <h>_bs
##              BlendSpace1D (sync) with points -90 / 0 / +90 (plan 6.1; rest-relative blend).
##   aimmove  bank of the aim-walk clips, then per hemisphere add_up / add_dn / blk / rel.
## Carry layers (the role's overlay layers: arms, arms / spine additives, hands, finger sets):
##   input (default)   every layer inside its input: cw_<w>_<i> / ca_<w>_<i> over lc_<w>_<i>
##                     (plan 6.1 / D4); amount = layer weight x weapon weight. Each input carries
##                     its own layers through every crossfade: the graph's
##                     crossfade(A + layers_A, B + layers_B), as Godot accumulates it.
##   shared (opt-in performance option, a FIDELITY APPROXIMATION)  single-frame pose layers
##                     (942 of the 967 layer uses) live in one stack per weapon above the L
##                     chain, K__<w>__<i> over KC__<w>__<i>; amount = sum(input weight x layer
##                     weight) x weapon weight (TreeIndex.carry_targets). Exact only while one
##                     input is weighted: mid-crossfade a layer of one input is applied to the
##                     other input as well (measured up to 0.56 rad at 50 % idle -> aim idle, vs
##                     <= 0.13 rad for "input"; test_tree_build). About half the per-frame cost.
##   none              no carry layer nodes.
## Clip sets (graph profiles.<w>.clip_set, the thrown weapons): weapons of one set share the nodes
## of its first weapon (the leader) wherever their content is identical: carry layers (amount x the
## summed weapon weights; LayerRecord.group), aim trees and aim-idle inputs (TreeIndex.aim /
## role_input map the others to the leader's), grips and throw inputs. The graph's crossfade of
## identical content is that content, so this is exact.
## Every node inside an input is sync=true, so layer clips and bank leaves stay on the input's
## phase; the selector chains are sync=false (frozen inputs).
## Sampled pose layers (graph carry_overrides, THROW2: a layer with `sample_s` and a bone mask
## `bones`, status "frontier"; and a grip with carry_sample_s / carry_bones): the source clip's pose
## at that time on those bones is baked once into the frontier_bank library (_pose_clip(); the
## clip's native_asset_id and source_attribution are kept in its metadata) and plays as a
## single-frame pose layer; its filter is its bone mask.
##
## Rules (plan D2, D5): no AnimationNodeStateMachine / AnimationNodeTransition anywhere; filters
## are read from each clip's own tracks at build time; nothing is changed after the build (no
## filter, animation or loop edits at runtime); loops use per-node custom timelines. A clip the
## library lacks plays frontier/none (one warning per clip).
##
## The baked difference clips (library frontier_bank) are derived from the source clips and carry
## their source_attribution and native_asset_id in their metadata.

const NONE := &"frontier/none"
## The weapon prop bones (the weapon models hang off them, BoneAttachment3D). An action partial
## (X) leaves them out of its filter, so the tree's pose of these bones is the pose under the
## partials; PropFlipGuard (a SkeletonModifier3D, UpperBody.attach_stabilizer) crossfades the
## playing partials' clips over it along each clip's own continuous path. Several action clips
## turn these bones through half a turn from the bind pose and from the carry pose, and Godot's
## rest-relative blend (or any shortest-arc crossfade) flips the weapon round by up to 180 deg in
## one frame when that happens mid-fade (musket draw: 168-180 rad/s; WP6 reviews). The records of
## those X OneShots list the bones in `prop_bones`.
const PROP_BONES := ["l_hand_prop_attachment", "r_hand_prop_attachment"]
const NONE_LIB := &"frontier"
const BANK_LIB := &"frontier_bank"
## Layer statuses the tree plays: graph layers ("resolved"), layers of another graph profile standing in for a
## target without an Actor_B action ("substitute") and Frontier-composed poses ("frontier"; carry_overrides, THROW2).
const PLAYABLE_LAYER_STATUS := ["resolved", "substitute", "frontier"]
## Prefix of the names under which sampled pose clips are known to this builder and its records
## (_pose_clip()): their frontier_bank library path, so every AnimationPlayer lookup resolves them.
const POSE_PREFIX := "frontier_bank/"
const HEMIS := ["fw", "bw"]
## Difference-clip bake rate (Hz of each clip's own time).
const BAKE_HZ := 60.0
const OPT_DEFAULTS := {"bank_kind": "diff", "carry": "input", "aim_move": null, "weapons": [], "lib": "actor_b",
		"instance_slots": 2, "instance_groups": ["start", "stop", "rev", "hit"]}
## Lower chain order: groups listed first sit farthest from the output (a Blend2 chain costs one
## node visit per chain link above the active input, so the common inputs go last).
const GROUP_RANK := ["death", "land_death", "land_damage", "hit", "cchange", "quick_turn", "turn", "pre_fall",
		"land", "takeoff", "jump", "fall", "aimmove", "rev", "stop", "start", "move", "aimidle", "idle"]

## Cached difference clips per actor library: library instance id -> AnimationLibrary.
static var _bank_libs := {}
static var _bank_ms := {}
## Loop-seam data issues already pushed as engine warnings (once per clip per process).
static var _seam_warned := {}

var data: AnimGraphData
var ap: AnimationPlayer
var sk: Skeleton3D
var opts := {}
var idx: TreeIndex
var weapons := PackedStringArray()
var modes := PackedStringArray()
var stances := PackedStringArray()

var _lib_name := "actor_b"
var _tracks := {}          ## clip -> Array[NodePath]
var _warned := {}
var _bank_lib: AnimationLibrary
var _clipkeys := {}        ## clip -> key
var _keys_used := {}       ## key -> clip
var _nodes := 0
var _shared_lists := {}    ## weapon -> Array of LayerRecord lists (one per input / hemisphere)
var _partials_build := []  ## _oneshots() arguments of the X chain (built above the fire additives)
var _leader := {}          ## weapon -> the first weapon of its clip set (itself without one; THROW)
var _pose_names := {}      ## sampled pose name (POSE_PREFIX..., its library path) -> that path (_pose_clip())


## Builds the tree. opts:
##   bank_kind  "diff" (default; graph-exact direction chains) | "blendspace" (plan 6.1 BS1D)
##   carry      "input" (default; every layer in its input, plan 6.1 / D4, graph-exact through
##              crossfades) | "shared" (opt-in performance option: pose layers in one per-weapon
##              stack K, exact only while one input is weighted) | "none" (no carry layer nodes)
##   aim_move   build the aim-walk inputs (graph aim-run-*); default: the table's options.aim_walk
##              (off). Toggling that option at runtime needs a rebuild.
##   weapons    subset (default all); lib (default "actor_b").
##   instance_slots / instance_groups   (WP4) inputs per one-shot bank of these groups (default 2
##              for start / stop / rev and the heavy hits): identical content under L__<id>__i<k>, no role keys,
##              records `instance_of` / `slot` (the primary lists `instances`). The graph starts a
##              new state instance at its entry phase on every entry, fading over the old one
##              still on screen; with one input a still-weighted one-shot could only continue its
##              phase, so LocoBrain alternates between the slots (plan D12's instance stack,
##              without Transition nodes). 1 builds one input per bank.
## Godot 4.7 does per-frame work for every node reachable from the output, weighted or not: a
## zero-weight sync=false input is frozen, not skipped, and every node pays a pass over the
## mixer's track weights (about 0.37 us per node on Actor_B's 873 tracks, 0.04 us on a 4-bone
## rig). TreeIndex.summary() has the node count. The default favours graph fidelity (carry
## "input"); "shared" roughly halves the per-frame cost at a fidelity cost.
static func build(p_data: AnimGraphData, p_ap: AnimationPlayer, p_sk: Skeleton3D, p_opts := {}) -> TreeIndex:
	var b := TreeBuilder.new()
	b.data = p_data
	b.ap = p_ap
	b.sk = p_sk
	b.opts = OPT_DEFAULTS.duplicate()
	b.opts.merge(p_opts, true)
	return b._build()


## Adds the frontier/none fallback animation (1 s, empty, looping) when missing.
static func ensure_none(p_ap: AnimationPlayer) -> void:
	if p_ap.has_animation(NONE):
		return
	var lib: AnimationLibrary
	if p_ap.has_animation_library(NONE_LIB):
		lib = p_ap.get_animation_library(NONE_LIB)
	else:
		lib = AnimationLibrary.new()
		p_ap.add_animation_library(NONE_LIB, lib)
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation(&"none", a)


## Drops the cached difference clips: the next build on an AnimationPlayer without a
## frontier_bank library bakes them again. Players that already have one keep it.
static func clear_cache() -> void:
	_bank_libs.clear()
	_bank_ms.clear()


## "actor_b-p-run-fw" -> "actor_b_p_run_fw" (every character outside [A-Za-z0-9_] -> "_").
static func clip_key(clip: String) -> String:
	var out := ""
	for ch in clip:
		var c := ch.unicode_at(0)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
		out += ch if ok else "_"
	return out


func _build() -> TreeIndex:
	var t0 := Time.get_ticks_usec()
	idx = TreeIndex.new()
	idx.bank_kind = String(opts.bank_kind)
	if not idx.bank_kind in ["diff", "blendspace"]:
		idx.errors.append("unknown bank_kind '%s' (diff | blendspace); using diff" % idx.bank_kind)
		idx.bank_kind = "diff"
	_lib_name = String(opts.lib)
	var extra := data.override_libraries()
	for l: String in extra:
		if not ap.has_animation_library(l):
			ap.add_animation_library(l, load(String(extra[l])) as AnimationLibrary)
	idx.carry_mode = String(opts.carry)
	if not idx.carry_mode in ["shared", "input", "none"]:
		idx.errors.append("unknown carry '%s' (input | shared | none); using input" % idx.carry_mode)
		idx.carry_mode = "input"
		opts.carry = "input"
	if data == null or ap == null or sk == null:
		idx.errors.append("TreeBuilder.build needs AnimGraphData, AnimationPlayer and Skeleton3D")
		return idx
	if not ap.has_animation_library(StringName(_lib_name)):
		idx.errors.append("AnimationPlayer has no library '%s'" % _lib_name)
		return idx
	ensure_none(ap)
	idx.skeleton_path = _skeleton_path()
	var only := Array(opts.weapons) if opts.weapons != null else []
	for w in data.weapons():
		if only.is_empty() or only.has(w):
			weapons.append(w)
	modes = data.modes()
	stances = data.stances()
	idx.weapons = weapons
	idx.modes = modes
	var set_first := {}
	for w in weapons:
		var cs := String(data.graph.get("profiles", {}).get(w, {}).get("clip_set", ""))
		if cs != "" and bool(opts.get("share_clip_sets", true)):
			if not set_first.has(cs):
				set_first[cs] = w
			_leader[w] = set_first[cs]
		else:
			_leader[w] = w
	idx.clip_set_leader = _leader.duplicate()
	if weapons.is_empty() or modes.is_empty():
		idx.errors.append("graph table has no weapons or modes")
		return idx
	if idx.bank_kind == "diff":
		_bank_lib = _bank_library()

	var root := AnimationNodeBlendTree.new()
	var top := _build_lower(root)
	if top == "":
		idx.errors.append("no lower-body input could be built")
		return idx
	top = _build_shared_carry(root, top)
	top = _build_weapon_out(root, top)
	top = _build_aim(root, top)
	top = _build_grip(root, top)
	top = _build_charge(root, top)
	top = _build_actions(root, top)
	top = _build_runtime_oneshots(root, top)
	root.connect_node("output", 0, top)
	idx.tree_root = root
	idx.node_count = _nodes
	idx.build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return idx


# --- lower body ---------------------------------------------------------------------------

## Collects every lower input spec, dedupes by content, orders and builds the L chain.
func _build_lower(root: AnimationNodeBlendTree) -> String:
	var specs: Array = []
	specs.append_array(_single_specs())
	specs.append_array(_bank_specs())
	specs.append_array(_aimidle_specs())
	var aim_move: Variant = opts.aim_move
	if aim_move == null:
		aim_move = bool(data.option("aim_walk", false))
	if bool(aim_move):
		specs.append_array(_aimmove_specs())
	specs = _dedupe(specs)
	specs.append_array(_instance_specs(specs))
	specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.rank != b.rank:
			return a.rank < b.rank
		if a.order != b.order:
			return a.order < b.order
		return int(a.get("slot", 1)) < int(b.get("slot", 1)))
	var names: Array[String] = []
	for s: Dictionary in specs:
		var bt := AnimationNodeBlendTree.new()
		var rec := {"id": s.id, "node": "L__" + s.id, "kind": s.kind, "group": s.group, "modes": s.modes,
				"keys": s.keys, "weapons": s.get("weapons", weapons), "layers": []}
		if s.has("instance_of"):
			rec["instance_of"] = s.instance_of
			rec["slot"] = s.slot
		match s.kind:
			"single":
				_build_single(bt, s, rec)
			"bank", "aimmove":
				_build_bank_input(bt, s, rec)
		root.add_node(rec.node, bt)
		_nodes += 1
		idx.lower[s.id] = rec
		idx.L_inputs.append(s.id)
		idx.L_seek[s.id] = rec.get("seeks", [])
		for k in s.keys:
			idx.role_input[k] = s.id
		names.append(rec.node)
	for id in idx.lower:
		var r: Dictionary = idx.lower[id]
		if r.has("instance_of") and idx.lower.has(r.instance_of):
			var pr: Dictionary = idx.lower[r.instance_of]
			if not pr.has("instances"):
				pr["instances"] = [pr.id]
			pr.instances.append(id)
	return _chain(root, "L", names)


## Extra instances of the one-shot bank inputs (opts.instance_slots x opts.instance_groups; see
## build()): the same content with its own nodes and phase, no role keys. A group names bank
## groups (start / stop / rev) or single-clip families (hit: the heavy hits hit_<dir>).
func _instance_specs(specs: Array) -> Array:
	var out: Array = []
	var n := int(opts.get("instance_slots", 1))
	var groups: Array = Array(opts.get("instance_groups", []))
	if n < 2 or groups.is_empty():
		return out
	for s: Dictionary in specs:
		var g := String(s.group)
		if not (g in groups or (s.kind == "single" and g.get_slice("_", 0) in groups and g.contains("_"))):
			continue
		for k in range(2, n + 1):
			var d: Dictionary = s.duplicate(true)
			d.id = "%s__i%d" % [s.id, k]
			d.keys = []
			d["instance_of"] = s.id
			d["slot"] = k
			out.append(d)
	return out


## Single-clip lower roles (idle, air, landings, turns, ...), heavy hits, deaths, crouch change.
func _single_specs() -> Array:
	var specs: Array = []
	var order := 0
	for r in data.role_names():
		# death: the runtime death roles below (front = this role's state and clip).
		if data.is_bank_role(r) or r in ["hit_full", "hit_add", "death"]:
			continue
		for m in modes:
			var s := {"kind": "single", "group": r, "modes": [m], "keys": [], "layers": {}, "clip": "",
					"loop": false, "order": order}
			for w in weapons:
				var role := data.role(w, m, r)
				var clip := data.role_clip(w, m, r)
				if clip == "":
					if not role.is_empty():
						idx.missing_roles.append("%s/%s/%s" % [w, m, r])
					continue
				if s.clip == "":
					s.clip = clip
					s.loop = bool(role.get("loop", false))
				elif s.clip != clip:
					idx.warnings.append("role %s/%s/%s clip %s differs from the other weapons' %s (using %s)" % [w, m, r, clip, s.clip, s.clip])
				s.layers[w] = _layers(role)
				s.keys.append("%s/%s/%s" % [w, m, r])
			if s.clip != "":
				specs.append(s)
			order += 1
	for kind in ["hit_full", "death"]:
		var rr: Dictionary = data.graph.get("runtime_roles", {}).get(kind, {})
		var variants := {}
		for k in rr:
			variants[String(k).get_slice("/", 2)] = true
		var vs := variants.keys()
		vs.sort()
		for v in vs:
			for m in modes:
				var s := {"kind": "single", "group": ("hit_%s" if kind == "hit_full" else "death_%s") % v, "modes": [m],
						"keys": [], "layers": {}, "clip": "", "loop": false, "order": order}
				for w in weapons:
					var role := data.runtime_role(kind, "%s/%s/%s" % [w, m, v])
					if role.is_empty() or role.get("clip") == null:
						continue
					if s.clip == "":
						s.clip = String(role.clip)
						s.loop = bool(role.get("loop", false))
					s.layers[w] = _layers(role)
					s.keys.append("%s/%s/%s/%s" % [w, m, kind, v])
					if kind == "death" and v == "front":
						s.keys.append("%s/%s/death" % [w, m])
				if s.clip != "":
					specs.append(s)
				order += 1
	for dir in ["stand_to_crouch", "crouch_to_stand"]:
		var s := {"kind": "single", "group": "cchange_" + dir, "modes": [data.graph.get("crouch_change", {}).get(
				"%s/%s" % [weapons[0], dir], {}).get("mode", "crouch")], "keys": [], "layers": {}, "clip": "", "loop": false,
				"order": order}
		for w in weapons:
			var cc := data.crouch_change(w, dir)
			var full: Dictionary = cc.get("full", {})
			if full.is_empty() or full.get("clip") == null or String(full.get("status", "")) in ["missing", "disabled"]:
				continue
			if s.clip == "":
				s.clip = String(full.clip)
				s.loop = bool(full.get("loop", false))
			s.layers[w] = _layers(full)
			s.keys.append("%s/%s/cchange" % [w, dir])
		if s.clip != "":
			specs.append(s)
		order += 1
	return specs


## move / start / stop / rev banks per mode.
func _bank_specs() -> Array:
	var specs: Array = []
	var order := 10000
	for g in AnimGraphData.BANK_GROUPS:
		for m in modes:
			var s := {"kind": "bank", "group": g, "modes": [m], "keys": [], "hemis": {}, "order": order}
			for h in HEMIS:
				var bank: String = AnimGraphData.BANK_GROUPS[g][h]
				var rs := data.bank_roles(bank)
				if rs.size() < 3:
					continue
				# rs = [center, lt, rt]; fw chain: -90 = rt, +90 = lt; bw chain: -90 = lt, +90 = rt.
				var leaf_roles: Array = [rs[0], rs[2], rs[1]] if h == "fw" else [rs[0], rs[1], rs[2]]
				var hs := {"bank": bank, "roles": leaf_roles, "clips": ["", "", ""], "loop": false, "layers": {}}
				for w in weapons:
					var leaf_layers: Array = []
					for i in 3:
						var role := data.role(w, m, leaf_roles[i])
						var clip := data.role_clip(w, m, leaf_roles[i])
						if clip == "":
							if not role.is_empty() and i == 0:
								idx.missing_roles.append("%s/%s/%s" % [w, m, leaf_roles[i]])
							leaf_layers.append([])
							continue
						if hs.clips[i] == "":
							hs.clips[i] = clip
							if i == 0:
								hs.loop = bool(role.get("loop", false))
						elif hs.clips[i] != clip:
							# One bank serves every weapon (plan D1: locomotion leaves are weapon-invariant).
							idx.warnings.append("bank leaf %s/%s/%s clip %s differs from the other weapons' %s (using %s)" % [
									w, m, leaf_roles[i], clip, hs.clips[i], hs.clips[i]])
						leaf_layers.append(_layers(role))
						s.keys.append("%s/%s/%s" % [w, m, leaf_roles[i]])
					hs.layers[w] = _union_layers(leaf_layers)
				if hs.clips[0] == "":
					continue
				s.hemis[h] = hs
			if s.hemis.is_empty():
				continue
			for w in weapons:
				s.keys.append("%s/%s/%s" % [w, m, g])
			specs.append(s)
			order += 1
	return specs


## Full-body aim base per weapon and stance (graph aim-idle), with the aim tree's own hands layer.
func _aimidle_specs() -> Array:
	var specs: Array = []
	var order := 20000
	for w in weapons:
		for st in stances:
			var at := data.aim_tree(w, st)
			var base: Dictionary = at.get("base", {})
			if base.is_empty() or base.get("clip") == null:
				continue
			var lw: String = _leader.get(w, w)
			if lw != w:
				var joined := false
				for ls: Dictionary in specs:
					if ls.id == "aimidle__%s__%s" % [lw, st] and ls.clip == String(base.clip) \
							and JSON.stringify(ls.layers[lw]) == JSON.stringify(_layers(base)):
						ls.keys.append("%s/%s/aimidle" % [w, st])
						ls.weapons.append(w)
						ls.layers[w] = _layers(base)    # identical: _stack shares the leader's nodes (group)
						joined = true
				if joined:
					continue
			specs.append({"kind": "single", "group": "aimidle", "modes": data.modes_of_stance(st), "weapons": [w],
					"keys": ["%s/%s/aimidle" % [w, st]], "clip": String(base.clip), "loop": bool(base.get("loop", true)),
					"layers": {w: _layers(base)}, "order": order, "id": "aimidle__%s__%s" % [w, st], "own_weapon": true})
			order += 1
	return specs


## Aim-walk banks (graph aim-run-forward / aim-run-backward; options.aim_walk, WP10).
func _aimmove_specs() -> Array:
	var specs: Array = []
	var order := 30000
	for w in weapons:
		for st in stances:
			var am := data.aim_move(w, st)
			if am.is_empty():
				continue
			var lw: String = _leader.get(w, w)
			if lw != w and JSON.stringify(am) == JSON.stringify(data.aim_move(lw, st)):
				var joined := false
				for ls: Dictionary in specs:
					if ls.id == "aimmove__%s__%s" % [lw, st]:
						ls.keys.append("%s/%s/aimmove" % [w, st])
						ls.weapons.append(w)
						for h in ls.hemis:
							ls.hemis[h].layers[w] = ls.hemis[h].layers[lw]    # identical (same aim_move rows)
						joined = true
				if joined:
					continue
			var s := {"kind": "aimmove", "group": "aimmove", "modes": data.modes_of_stance(st), "weapons": [w],
					"keys": ["%s/%s/aimmove" % [w, st]], "hemis": {}, "order": order, "id": "aimmove__%s__%s" % [w, st],
					"own_weapon": true}
			for h in HEMIS:
				var leaf_roles: Array = ["fw", "fw_rt", "fw_lt"] if h == "fw" else ["bw", "bw_lt", "bw_rt"]
				var hs := {"bank": "aim_move_" + h, "roles": leaf_roles, "clips": ["", "", ""], "loop": true, "layers": {}, "aim": {}}
				var leaf_layers: Array = []
				for i in 3:
					var role: Dictionary = am.get(leaf_roles[i], {})
					if role.is_empty() or role.get("clip") == null:
						leaf_layers.append([])
						continue
					hs.clips[i] = String(role.clip)
					if i == 0:
						hs.loop = bool(role.get("loop", true))
					leaf_layers.append(_layers(role))
				if hs.clips[0] == "":
					continue
				hs.layers[w] = _union_layers(leaf_layers)
				for part in ["up", "down", "blocked", "arms_relaxed"]:
					var pr: Dictionary = am.get("%s_%s" % [part, h], {})
					if not pr.is_empty() and pr.get("clip") != null:
						hs.aim[part] = String(pr.clip)
				s.hemis[h] = hs
			if not s.hemis.is_empty():
				specs.append(s)
			order += 1
	return specs


## Merges specs with identical content (clips, loop flags, per-weapon layers) and names them.
func _dedupe(specs: Array) -> Array:
	var by_sig := {}
	var out: Array = []
	for s: Dictionary in specs:
		var sig := _signature(s)
		if by_sig.has(sig):
			var into: Dictionary = by_sig[sig]
			for m in s.modes:
				if not into.modes.has(m):
					into.modes.append(m)
			for k in s.keys:
				if not into.keys.has(k):
					into.keys.append(k)
			if not into.groups.has(s.group):
				into.groups.append(s.group)
			continue
		s["groups"] = [s.group]
		by_sig[sig] = s
		out.append(s)
	# Names: <group> when one input serves the group; per stance when the inputs split exactly
	# by stance; else <group>__<first mode>.
	var per_group := {}
	for s: Dictionary in out:
		var g: String = s.group
		if not per_group.has(g):
			per_group[g] = []
		per_group[g].append(s)
	var used := {}
	for g in per_group:
		var list: Array = per_group[g]
		var by_stance := list.size() > 1
		var seen_st := {}
		for s: Dictionary in list:
			var sts := {}
			for m in s.modes:
				sts[data.stance_of(m)] = true
			if sts.size() != 1 or seen_st.has(sts.keys()[0]):
				by_stance = false
			else:
				seen_st[sts.keys()[0]] = true
		for s: Dictionary in list:
			if s.has("id"):
				pass
			elif list.size() == 1:
				s.id = g
			elif by_stance:
				s.id = "%s__%s" % [g, data.stance_of(s.modes[0])]
			else:
				s.id = "%s__%s" % [g, s.modes[0]]
			var base: String = s.id
			var n := 2
			while used.has(s.id):
				s.id = "%s_%d" % [base, n]
				n += 1
			used[s.id] = true
			s["rank"] = _rank(g)
	return out


func _rank(group: String) -> int:
	for i in GROUP_RANK.size():
		var g: String = GROUP_RANK[i]
		if group == g or group.begins_with(g + "_") or (g == "land" and group.begins_with("land")) \
				or (g == "turn" and group.begins_with("turn")):
			return i
	return 0


func _signature(s: Dictionary) -> String:
	var c := {"kind": s.kind, "own": s.get("id", "") if s.get("own_weapon", false) else ""}
	if s.kind == "single":
		c["clip"] = s.clip
		c["loop"] = s.loop
		c["layers"] = s.layers
	else:
		var hs := {}
		for h in s.hemis:
			var x: Dictionary = s.hemis[h]
			hs[h] = [x.clips, x.loop, x.layers, x.get("aim", {})]
		c["hemis"] = hs
		c["group"] = s.group
	return JSON.stringify(c, "", true)


## Carry layers of a role: resolved partial / additive layers with a clip (all slots, including
## hands and move-set finger layers: the graph applies them; the exact-grip override is H).
func _layers(role: Dictionary) -> Array:
	var out: Array = []
	for l in role.get("layers", []):
		if not String(l.get("status", "resolved")) in PLAYABLE_LAYER_STATUS or l.get("clip") == null or l.has("excluded"):
			continue
		var kind := String(l.get("kind", ""))
		if not kind in ["partial", "additive"] or String(l.get("slot", "")) == "full_body":
			continue
		if not _has(String(l.clip)):
			_warn_once("layer:" + String(l.clip), "layer clip %s is not in the library; layer skipped" % l.clip)
			continue
		var clip := String(l.clip)
		if l.get("sample_s") != null:
			# A pose sampled from the clip at one time on a bone mask (carry_overrides, THROW2).
			clip = _pose_clip(clip, float(l.sample_s), PackedStringArray(l.get("bones", [])))
			if clip == "":
				continue
		var curve: Variant = l.get("weight_curve")
		out.append({"clip": clip, "kind": kind, "slot": String(l.get("slot", "")),
				"weight": float(l.get("weight", 1.0)), "curve": curve if curve is Array else null,
				"superseded_by": l.get("superseded_by")})
	return out


## Union of the three leaves' layers of a bank hemisphere, with each leaf's weight (0 = the leaf
## has no such layer; the graph applies layers per leaf, the runtime scales by the leaf weights).
func _union_layers(leaf_layers: Array) -> Array:
	var out: Array = []
	var at := {}
	for i in leaf_layers.size():
		for l: Dictionary in leaf_layers[i]:
			var key: String = l.clip + "|" + l.kind
			if not at.has(key):
				var u := l.duplicate()
				u["leaf_weights"] = [0.0, 0.0, 0.0]
				at[key] = u
				out.append(u)
			var rec: Dictionary = at[key]
			rec.leaf_weights[i] = l.weight
			rec.weight = maxf(rec.weight, l.weight)
	return out


func _build_single(bt: AnimationNodeBlendTree, s: Dictionary, rec: Dictionary) -> void:
	var p: String = rec.node
	bt.add_node("clip", _anim(s.clip, "norm", s.loop))
	var top := _stack(bt, "clip", s.layers, "", s.loop, p, rec.layers, "", not s.get("own_weapon", false))
	bt.add_node("seek", AnimationNodeTimeSeek.new())
	bt.connect_node("seek", 0, top)
	bt.add_node("ts", AnimationNodeTimeScale.new())
	bt.connect_node("ts", 0, "seek")
	bt.connect_node("output", 0, "ts")
	_nodes += 3
	var length := _length(s.clip)
	rec["clip"] = s.clip
	rec["loop"] = s.loop
	rec["length"] = length
	rec["ts"] = idx.param("%s/ts/scale" % p)
	rec["seek"] = idx.param("%s/seek/seek_request" % p)
	rec["position_node"] = idx.param("%s/clip/current_position" % p)
	rec["seeks"] = [rec.seek]
	idx.defaults[rec.ts] = 1.0 / maxf(length, 1e-3)


func _build_bank_input(bt: AnimationNodeBlendTree, s: Dictionary, rec: Dictionary) -> void:
	var p: String = rec.node
	var tops: Array[String] = []
	rec["hemis"] = {}
	rec["seeks"] = []
	var hemi_seeks := {}
	for h in HEMIS:
		if not s.hemis.has(h):
			continue
		var hs: Dictionary = s.hemis[h]
		var hr := {"bank": hs.bank, "roles": hs.roles, "clips": hs.clips, "loop": hs.loop, "layers": [],
				"lengths": [_length(hs.clips[0]), _length(hs.clips[1]), _length(hs.clips[2])]}
		var top := _bank(bt, h, hs, p, hr)
		# Aim-walk layers precede the aim additives / blends of the hemisphere: keep them inside.
		top = _stack(bt, top, hs.layers, h + "_", hs.loop, p, hr.layers, h, not s.get("own_weapon", false), s.kind != "aimmove")
		if s.kind == "aimmove":
			top = _aim_parts(bt, top, h + "_", hs.aim, p, hr)
		bt.add_node(h + "_seek", AnimationNodeTimeSeek.new())
		bt.connect_node(h + "_seek", 0, top)
		bt.add_node(h + "_ts", AnimationNodeTimeScale.new())
		bt.connect_node(h + "_ts", 0, h + "_seek")
		_nodes += 2
		hr["ts"] = idx.param("%s/%s_ts/scale" % [p, h])
		hr["seek"] = idx.param("%s/%s_seek/seek_request" % [p, h])
		idx.defaults[hr.ts] = 1.0 / maxf(hr.lengths[0], 1e-3)
		rec.hemis[h] = hr
		rec.seeks.append(hr.seek)
		hemi_seeks[h] = [hr.seek]
		for l in hr.layers:
			rec.layers.append(l)
		tops.append(h + "_ts")
	if tops.size() == 2:
		var hemi := AnimationNodeBlend2.new()
		hemi.sync = false
		bt.add_node("hemi_x1", hemi)
		bt.connect_node("hemi_x1", 0, tops[0])
		bt.connect_node("hemi_x1", 1, tops[1])
		bt.connect_node("output", 0, "hemi_x1")
		_nodes += 1
		rec["hemi_param"] = idx.param("%s/hemi_x1/blend_amount" % p)
		idx.defaults[rec.hemi_param] = 0.0
	else:
		bt.connect_node("output", 0, tops[0])
	rec["hemi_prefix"] = "%s/hemi" % p
	rec["hemi_inputs"] = PackedStringArray(rec.hemis.keys())
	rec["hemi_seek"] = hemi_seeks
	var first: Dictionary = rec.hemis.values()[0]
	rec["clip"] = first.clips[0]
	rec["loop"] = first.loop
	rec["length"] = first.lengths[0]


## The direction bank of one hemisphere; returns its top node name.
func _bank(bt: AnimationNodeBlendTree, h: String, hs: Dictionary, p: String, hr: Dictionary) -> String:
	var c: String = hs.clips[0]
	hr["kind"] = idx.bank_kind
	if idx.bank_kind == "blendspace":
		var bs := AnimationNodeBlendSpace1D.new()
		bs.sync = true
		bs.min_space = -90.0
		bs.max_space = 90.0
		bs.snap = 0.01
		# Center first, as the plan layout and ec_bank_gap: Godot accumulates the points
		# rest-relative in index order, so the order changes the pose off the center.
		var pts := [["c", 0, 0.0], ["neg", 1, -90.0], ["pos", 2, 90.0]]
		for pt in pts:
			var clip: String = hs.clips[pt[1]] if hs.clips[pt[1]] != "" else c
			bs.add_blend_point(_anim(clip, "norm", hs.loop), pt[2], -1, StringName(pt[0]))
		bt.add_node(h + "_bs", bs)
		_nodes += 4
		hr["position"] = idx.param("%s/%s_bs/blend_position" % [p, h])
		hr["position_node"] = idx.param("%s/%s_bs/c/current_position" % [p, h])
		idx.defaults[hr.position] = 0.0
		return h + "_bs"
	bt.add_node(h + "_c", _anim(c, "norm", hs.loop))
	_nodes += 1
	hr["position_node"] = idx.param("%s/%s_c/current_position" % [p, h])
	var top := h + "_c"
	for side in [["neg", 1], ["pos", 2]]:
		var sc: String = hs.clips[side[1]]
		if sc == "" or not _has(sc) or not _has(c):
			hr[side[0]] = &""
			continue
		var dname := _bank_diff(c, sc)
		if hs.loop:
			_note_loop(sc)
		var dn := "%s_d%s" % [h, side[0]]
		var an := "%s_a%s" % [h, side[0]]
		var leaf := AnimationNodeAnimation.new()
		leaf.animation = dname
		_timeline(leaf, 1.0, true, hs.loop)
		bt.add_node(dn, leaf)
		var add := AnimationNodeAdd2.new()
		add.sync = true
		bt.add_node(an, add)
		bt.connect_node(an, 0, top)
		bt.connect_node(an, 1, dn)
		_nodes += 2
		hr[side[0]] = idx.param("%s/%s/add_amount" % [p, an])
		idx.defaults[hr[side[0]]] = 0.0
		top = an
	return top


## Aim-walk hemisphere: add_up / add_dn (Add2), blk / rel (Blend2 filtered), as aim-run-*.
func _aim_parts(bt: AnimationNodeBlendTree, top: String, pre: String, aim: Dictionary, p: String, hr: Dictionary) -> String:
	hr["aim"] = {}
	for part in [["up", "add_up", true], ["down", "add_dn", true], ["blocked", "blk", false], ["arms_relaxed", "rel", false]]:
		var clip: String = aim.get(part[0], "")
		if clip == "":
			continue
		var name: String = pre + part[1]
		var leaf: String = pre + part[1] + "_c"
		bt.add_node(leaf, _anim(clip, "plain", false))
		var n: AnimationNode
		var prm: String
		if part[2]:
			n = AnimationNodeAdd2.new()
			prm = "add_amount"
		else:
			n = AnimationNodeBlend2.new()
			_filter_clip(n, clip, "%s/%s" % [p, name])
			prm = "blend_amount"
		n.sync = true
		bt.add_node(name, n)
		bt.connect_node(name, 0, top)
		bt.connect_node(name, 1, leaf)
		_nodes += 2
		hr.aim[part[1]] = idx.param("%s/%s/%s" % [p, name, prm])
		idx.defaults[hr.aim[part[1]]] = 0.0
		top = name
	hr.aim["clips"] = aim.duplicate()
	return top


## Carry stack of one input / hemisphere. carry "shared" (default): a weapon's layers are recorded
## as references into the per-weapon shared stack K (built later by _build_shared_carry) when they
## are all single-frame poses and nothing but seek / rate nodes follows them in the input
## (`can_share`); otherwise they stay here as nodes on the input's phase, in their order. carry
## "input": every layer is a node here (plan 6.1 layout). carry "none": no layer nodes.
## Returns the top node name; appends LayerRecords to `out`.
func _stack(bt: AnimationNodeBlendTree, below: String, layers_by_w: Dictionary, pre: String, loop: bool,
		p: String, out: Array, hemi: String, scale_by_weapon: bool, can_share := true) -> String:
	var top := below
	var mode := String(opts.carry)
	if mode == "none":
		return top
	# Clip-set members whose layers here equal their leader's share the leader's nodes (the
	# leader's LayerRecords list them in `group`; carry amounts use the summed weapon weights).
	# With carry "input", a member whose layers only begin like its leader's (THROW2: the spear's and
	# the tomahawk's own arm layers after the pick-up base's finger layers) shares the nodes of that
	# common prefix the same way (those leader records list it in `group`) and adds nodes for the rest
	# only. The leader's stack comes first in the input, and its other layers are at 0 while the member
	# is carried, so the member's layers still apply in their order: exact, as the whole-list merge.
	var group := {}
	var merged := {}
	var prefix := {}
	for w in weapons:
		var lw: String = _leader.get(w, w)
		if lw != w and layers_by_w.has(w) and layers_by_w.has(lw):
			if JSON.stringify(layers_by_w[w]) == JSON.stringify(layers_by_w[lw]):
				merged[w] = true
				if not group.has(lw):
					group[lw] = [lw]
				group[lw].append(w)
			elif mode == "input":
				var a: Array = layers_by_w[w]
				var b: Array = layers_by_w[lw]
				var n := 0
				while n < mini(a.size(), b.size()) and JSON.stringify(a[n]) == JSON.stringify(b[n]):
					n += 1
				if n > 0:
					prefix[w] = n
	var lead_recs := {}
	for w in weapons:
		if merged.has(w):
			continue
		var ls: Array = layers_by_w.get(w, [])
		var shared_list: Array = []
		var share := mode == "shared" and can_share
		for l: Dictionary in ls:
			if share and not _static(l.clip):
				share = false
		var skip := int(prefix.get(w, 0))
		if skip > 0:
			var recs: Array = lead_recs.get(_leader.get(w, w), [])
			for i in mini(skip, recs.size()):
				var r: Dictionary = recs[i]
				if not r.has("group"):
					r["group"] = [r.weapon]
				(r.group as Array).append(w)
			skip = mini(skip, recs.size())
		for i in range(skip, ls.size()):
			var l: Dictionary = ls[i]
			var lr := {"param": &"", "node": "", "weapon": w, "kind": l.kind, "clip": l.clip, "slot": l.slot,
					"weight": l.weight, "curve": l.curve, "superseded_by": l.superseded_by, "hemi": hemi,
					"scale_by_weapon": scale_by_weapon, "input": p.trim_prefix("L__"), "shared": false}
			if l.has("leaf_weights"):
				lr["leaf_weights"] = l.leaf_weights
			if group.has(w):
				lr["group"] = (group[w] as Array).duplicate()
			out.append(lr)
			if not lead_recs.has(w):
				lead_recs[w] = []
			(lead_recs[w] as Array).append(lr)
			if share:
				lr.shared = true
				shared_list.append(lr)
				continue
			var lc := "%slc_%s_%d" % [pre, w, i]
			bt.add_node(lc, _anim(l.clip, "norm", loop))
			var nn: String
			var prm: String
			if l.kind == "additive":
				nn = "%sca_%s_%d" % [pre, w, i]
				var a := AnimationNodeAdd2.new()
				a.sync = true
				bt.add_node(nn, a)
				prm = "add_amount"
			else:
				nn = "%scw_%s_%d" % [pre, w, i]
				var b := AnimationNodeBlend2.new()
				b.sync = true
				_filter_clip(b, l.clip, "%s/%s" % [p, nn])
				bt.add_node(nn, b)
				prm = "blend_amount"
			bt.connect_node(nn, 0, top)
			bt.connect_node(nn, 1, lc)
			_nodes += 2
			lr.param = idx.param("%s/%s/%s" % [p, nn, prm])
			lr.node = "%s/%s" % [p, nn]
			# Weapon-owned inputs (aim idle / aim walk) play their layers at the graph weight.
			idx.defaults[lr.param] = 0.0 if scale_by_weapon else l.weight
			top = nn
		if not shared_list.is_empty():
			if not _shared_lists.has(w):
				_shared_lists[w] = []
			_shared_lists[w].append(shared_list)
	return top


## True when a clip is a single pose (at most one frame, or every track holds one key): its
## phase does not matter, so it can sit in the shared stack.
func _static(clip: String) -> bool:
	var p := _godot(clip)
	if not ap.has_animation(p):
		return true
	var a := ap.get_animation(p)
	if a.length <= 1.5 / 30.0:
		return true
	for t in a.get_track_count():
		if a.track_get_key_count(t) > 1:
			return false
	return true


## Shared carry stack K: per weapon, one node per pose layer instance, in an order that contains
## every input's layer order as a subsequence (shortest common supersequence; a clip appears
## twice when two roles order it differently, e.g. the bow's crouch arms vs hands). Each input's
## LayerRecords point at their instances; the runtime writes amount = sum over the weighted
## inputs of input weight x layer weight (x weapon weight): exact whenever one input is weighted.
func _build_shared_carry(root: AnimationNodeBlendTree, top: String) -> String:
	for w in weapons:
		var lists: Array = _shared_lists.get(w, [])
		if lists.is_empty():
			continue
		var seq: Array = []
		for l in lists:
			var keys: Array = []
			for lr: Dictionary in l:
				keys.append(lr.clip + "|" + lr.kind)
			seq = _scs(seq, keys)
		var slots: Array = []
		for i in seq.size():
			var clip := String(seq[i]).get_slice("|", 0)
			var kind := String(seq[i]).get_slice("|", 1)
			var n := "K__%s__%d" % [w, i]
			var leaf := "KC__%s__%d" % [w, i]
			root.add_node(leaf, _anim(clip, "plain", false))
			var prm: String
			if kind == "additive":
				var a := AnimationNodeAdd2.new()
				a.sync = false
				root.add_node(n, a)
				prm = "add_amount"
			else:
				var b := AnimationNodeBlend2.new()
				b.sync = false
				_filter_clip(b, clip, n)
				root.add_node(n, b)
				prm = "blend_amount"
			root.connect_node(n, 0, top)
			root.connect_node(n, 1, leaf)
			_nodes += 2
			var rec := {"param": idx.param("%s/%s" % [n, prm]), "node": n, "clip": clip, "kind": kind, "index": i}
			idx.defaults[rec.param] = 0.0
			slots.append(rec)
			top = n
		idx.carry[w] = slots
		for l in lists:
			var j := 0
			for lr: Dictionary in l:
				var key: String = lr.clip + "|" + lr.kind
				while j < seq.size() and seq[j] != key:
					j += 1
				if j >= seq.size():
					idx.errors.append("shared carry: %s not embedded for %s" % [key, w])
					break
				lr.param = slots[j].param
				lr.node = slots[j].node
				lr["slot_index"] = j
				j += 1
	return top


## Shortest common supersequence of two sequences (LCS based; a's order first on ties).
func _scs(a: Array, b: Array) -> Array:
	var n := a.size()
	var m := b.size()
	var dp: Array = []
	for i in n + 1:
		var row := PackedInt32Array()
		row.resize(m + 1)
		dp.append(row)
	for i in range(n - 1, -1, -1):
		for j in range(m - 1, -1, -1):
			dp[i][j] = dp[i + 1][j + 1] + 1 if a[i] == b[j] else maxi(dp[i + 1][j], dp[i][j + 1])
	var out: Array = []
	var i := 0
	var j := 0
	while i < n and j < m:
		if a[i] == b[j]:
			out.append(a[i])
			i += 1
			j += 1
		elif dp[i + 1][j] >= dp[i][j + 1]:
			out.append(a[i])
			i += 1
		else:
			out.append(b[j])
			j += 1
	out.append_array(a.slice(i))
	out.append_array(b.slice(j))
	return out


# --- weapon-out fingers, aim, grip, charge -------------------------------------------------

func _build_weapon_out(root: AnimationNodeBlendTree, top: String) -> String:
	for w in weapons:
		for st in stances:
			var wo := data.weapon_out(w, st)
			if wo.is_empty() or wo.get("clip") == null or not _has(String(wo.clip)):
				continue
			var clip := String(wo.clip)
			var key := "%s/%s" % [w, st]
			idx.weapon_out_by[key] = clip
			if idx.weapon_out.has(clip):
				idx.weapon_out[clip].keys.append(key)
				idx.weapon_out[clip].applies[key] = bool(wo.get("applies", false))
				continue
			var ck := _ck(clip)
			var n := "WO__" + ck
			var leaf := "WOC__" + ck
			root.add_node(leaf, _anim(clip, "secs", true))
			var b := AnimationNodeBlend2.new()
			b.sync = false
			_filter_clip(b, clip, n)
			root.add_node(n, b)
			root.connect_node(n, 0, top)
			root.connect_node(n, 1, leaf)
			_nodes += 2
			var prm := idx.param("%s/blend_amount" % n)
			idx.weapon_out[clip] = {"param": prm, "node": n, "clip": clip, "keys": [key], "applies": {key: bool(wo.get("applies", false))},
					"position_node": idx.param("%s/current_position" % leaf)}
			idx.defaults[prm] = 0.0
			top = n
	return top


func _build_aim(root: AnimationNodeBlendTree, top: String) -> String:
	var names: Array[String] = []
	for w in weapons:
		for st in stances:
			var at := data.aim_tree(w, st)
			var base: Dictionary = at.get("base", {})
			if base.is_empty() or base.get("clip") == null:
				continue
			var lw: String = _leader.get(w, w)
			if lw != w and idx.aim.has("%s/%s" % [lw, st]) and _aim_sig(at) == _aim_sig(data.aim_tree(lw, st)):
				idx.aim["%s/%s" % [w, st]] = idx.aim["%s/%s" % [lw, st]]
				continue
			var id := "A__%s__%s" % [w, st]
			var bt := AnimationNodeBlendTree.new()
			var base_clip := String(base.clip)
			bt.add_node("base", _anim(base_clip, "norm", true))
			var t := "base"
			var rec := {"input": id, "node": id, "clips": {"base": base_clip}, "length": _length(base_clip)}
			var hands: Dictionary = at.get("hands", {})
			if hands.get("clip") is String and _has(String(hands.clip)):
				var hc := String(hands.clip)
				bt.add_node("hl_c", _anim(hc, "norm", true))
				var hb := AnimationNodeBlend2.new()
				hb.sync = true
				_filter_clip(hb, hc, id + "/hl")
				bt.add_node("hl", hb)
				bt.connect_node("hl", 0, t)
				bt.connect_node("hl", 1, "hl_c")
				_nodes += 2
				t = "hl"
				rec.clips["hands"] = hc
				rec["hands"] = idx.param("%s/hl/blend_amount" % id)
				var hw := 1.0
				if hands.get("layer") is Dictionary:
					hw = float(hands.layer.get("weight", 1.0))
				rec["hands_weight"] = hw
				idx.defaults[rec.hands] = hw
			for part in [["up", "add_up", true], ["down", "add_dn", true], ["blocked", "blk", false], ["arms_relaxed", "rel", false]]:
				var pr: Dictionary = at.get(part[0], {})
				if pr.is_empty() or pr.get("clip") == null:
					continue
				var clip := String(pr.clip)
				var name: String = part[1]
				bt.add_node(name + "_c", _anim(clip, "plain", false))
				var n: AnimationNode
				var prm: String
				if part[2]:
					n = AnimationNodeAdd2.new()
					prm = "add_amount"
				else:
					n = AnimationNodeBlend2.new()
					_filter_clip(n, clip, "%s/%s" % [id, name])
					prm = "blend_amount"
				n.sync = true
				bt.add_node(name, n)
				bt.connect_node(name, 0, t)
				bt.connect_node(name, 1, name + "_c")
				_nodes += 2
				rec[name] = idx.param("%s/%s/%s" % [id, name, prm])
				rec.clips[part[0]] = clip
				idx.defaults[rec[name]] = 0.0
				t = name
			bt.add_node("seek", AnimationNodeTimeSeek.new())
			bt.connect_node("seek", 0, t)
			bt.add_node("ts", AnimationNodeTimeScale.new())
			bt.connect_node("ts", 0, "seek")
			bt.connect_node("output", 0, "ts")
			_nodes += 3
			rec["seek"] = idx.param("%s/seek/seek_request" % id)
			rec["ts"] = idx.param("%s/ts/scale" % id)
			rec["position_node"] = idx.param("%s/base/current_position" % id)
			idx.defaults[rec.ts] = 1.0 / maxf(rec.length, 1e-3)
			root.add_node(id, bt)
			_nodes += 1
			idx.aim["%s/%s" % [w, st]] = rec
			idx.A_inputs.append(id)
			idx.A_seek[id] = [rec.seek]
			names.append(id)
	if names.is_empty():
		idx.warnings.append("no aim tree could be built; U_aim omitted")
		return top
	var a_top := _chain(root, "A", names)
	var u := AnimationNodeBlend2.new()
	u.sync = false
	var upper := data.bone_set("upper")
	if upper.is_empty():
		upper = _upper_fallback()
		idx.warnings.append("metrics bone_sets.upper missing; U_aim mask computed from the aim clips (%d bones)" % upper.size())
	_filter_bones(u, upper, "U_aim")
	idx.bone_sets["upper"] = upper
	root.add_node("U_aim", u)
	root.connect_node("U_aim", 0, top)
	root.connect_node("U_aim", 1, a_top)
	_nodes += 1
	idx.params["U_aim"] = idx.param("U_aim/blend_amount")
	idx.defaults[idx.params.U_aim] = 0.0
	return "U_aim"


## The clips and hands weight of an aim tree (clip-set sharing).
static func _aim_sig(at: Dictionary) -> String:
	var s := []
	for k in ["base", "up", "down", "blocked", "arms_relaxed", "hands"]:
		var r: Variant = at.get(k)
		s.append(r.get("clip") if r is Dictionary else null)
	var hl: Variant = at.get("hands", {}).get("layer") if at.get("hands") is Dictionary else null
	s.append(hl.get("weight") if hl is Dictionary else null)
	return JSON.stringify(s)


## Exact-grip override (override_exact_hands_grip): one filtered Blend2 per distinct grip clip
## of each weapon, H__<w>__<k> over HC__<w>__<k> (k = the first of carry / aim_s / aim_c that
## plays the clip). Filter = bone_sets.hands AND the bones the clip keys, so a hands bone the
## grip does not key keeps the pose below (the graph's hands layers): e.g. the pistol's carry
## grip (actor_b-r-hand-revolver) keys only the right hand, and the left hand stays free instead
## of falling to the rest pose. The sources are chained smallest filter first; with nested
## filters (each a subset of every later one; checked here) TreeIndex.grip_targets() gives every
## hands bone exactly its target weights, also through weapon and carry / aim fades.
func _build_grip(root: AnimationNodeBlendTree, top: String) -> String:
	var hands := data.bone_set("hands")
	if hands.is_empty():
		hands = _hands_fallback()
		idx.warnings.append("metrics bone_sets.hands missing; grip masks from bone names (%d bones)" % hands.size())
	idx.bone_sets["hands"] = hands
	var in_hands := {}
	for b in hands:
		in_hands[b] = true
	var sources: Array = []
	for w in weapons:
		var g := data.grip(w)
		if g.is_empty():
			continue
		var lw: String = _leader.get(w, w)
		if lw != w and idx.grips.has(lw) and JSON.stringify([g.get("carry"), g.get("aim_stand"), g.get("aim_crouch")]) \
				== JSON.stringify([data.grip(lw).get("carry"), data.grip(lw).get("aim_stand"), data.grip(lw).get("aim_crouch")]):
			idx.grips[w] = idx.grips[lw]
			for src: Dictionary in sources:
				if src.weapon == lw:
					if not src.has("group"):
						src["group"] = [lw]
					src.group.append(w)
			continue
		var clips := {"carry": String(g.get("carry", "")), "aim_s": String(g.get("aim_stand", "")), "aim_c": String(g.get("aim_crouch", ""))}
		if clips.carry != "" and g.get("carry_sample_s") != null and _has(clips.carry):
			# a grip pose sampled from a clip (carry_overrides, THROW2)
			clips.carry = _pose_clip(clips.carry, float(g.carry_sample_s), PackedStringArray(g.get("carry_bones", [])))
		if clips.carry == "" or not _has(clips.carry):
			idx.warnings.append("grip %s: no carry clip; no exact grip for %s" % [w, w])
			continue
		for k in ["aim_s", "aim_c"]:
			if clips[k] == "" or not _has(clips[k]):
				clips[k] = clips.carry
		var by_clip := {}
		var rec := {"clips": clips, "source": {}}
		for k in ["carry", "aim_s", "aim_c"]:
			var c: String = clips[k]
			if by_clip.has(c):
				by_clip[c].kinds.append(k)
				continue
			var bones := PackedStringArray()
			for tp in _track_paths(c):
				var b := String(tp.get_concatenated_subnames())
				if in_hands.has(b) and not bones.has(b):
					bones.append(b)
			bones.sort()
			var src := {"weapon": w, "kinds": [k], "clip": c, "bones": bones, "order": sources.size()}
			by_clip[c] = src
			if bones.is_empty():
				idx.warnings.append("grip %s/%s: %s keys no hands bone; no exact grip for it" % [w, k, c])
				continue
			sources.append(src)
		idx.grips[w] = rec
	if sources.is_empty():
		return top
	# Smallest filter first (stable: weapon order, then carry / aim_s / aim_c).
	sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.bones.size() != b.bones.size():
			return a.bones.size() < b.bones.size()
		return a.order < b.order)
	idx.grip_nested = true
	for i in sources.size():
		for j in range(i + 1, sources.size()):
			for b in sources[i].bones:
				if not sources[j].bones.has(b):
					idx.grip_nested = false
	if not idx.grip_nested:
		idx.warnings.append("grip filters are not nested: exact-grip fades between them are approximate (steady states stay exact)")
	for i in sources.size():
		var src: Dictionary = sources[i]
		var n := "H__%s__%s" % [src.weapon, src.kinds[0]]
		var leaf := "HC__%s__%s" % [src.weapon, src.kinds[0]]
		root.add_node(leaf, _anim(src.clip, "secs", true))
		var b := AnimationNodeBlend2.new()
		b.sync = false
		_filter_bones(b, src.bones, n)
		root.add_node(n, b)
		root.connect_node(n, 0, top)
		root.connect_node(n, 1, leaf)
		_nodes += 1
		var gs := {"node": n, "param": idx.param("%s/blend_amount" % n), "weapon": src.weapon, "kinds": src.kinds,
				"clip": src.clip, "bones": src.bones.size(), "position_node": idx.param("%s/current_position" % leaf)}
		if src.has("group"):
			gs["group"] = src.group
		idx.defaults[gs.param] = 0.0
		for k in src.kinds:
			idx.grips[src.weapon].source[k] = i
		idx.grip_sources.append(gs)
		top = n
	idx.grip_override_default = 1.0 if data.override_enabled("override_exact_hands_grip") else 0.0
	return top


func _build_charge(root: AnimationNodeBlendTree, top: String) -> String:
	var rc: Dictionary = data.graph.get("runtime_clips", {}).get("charge", {})
	var clips := {}
	for st in stances:
		for w in weapons:
			var c: String = String(rc.get("%s/%s" % [w, st], ""))
			if c != "" and _has(c):
				clips[st] = c
	if clips.is_empty():
		return top
	var st_nodes: Array[String] = []
	idx.charge = {"clips": clips, "seek": {}, "ts": {}, "lengths": {}}
	for st in stances:
		if not clips.has(st):
			continue
		var cn := "C_c_" + st
		root.add_node(cn, _anim(clips[st], "plain", false))
		root.add_node("C_ts_" + st, AnimationNodeTimeScale.new())
		root.connect_node("C_ts_" + st, 0, cn)
		root.add_node("C_seek_" + st, AnimationNodeTimeSeek.new())
		root.connect_node("C_seek_" + st, 0, "C_ts_" + st)
		_nodes += 3
		idx.charge.seek[st] = idx.param("C_seek_%s/seek_request" % st)
		idx.charge.ts[st] = idx.param("C_ts_%s/scale" % st)
		idx.charge.lengths[st] = _length(clips[st])
		idx.defaults[idx.charge.ts[st]] = 0.0
		st_nodes.append("C_seek_" + st)
	var src := st_nodes[0]
	if st_nodes.size() == 2:
		var b := AnimationNodeBlend2.new()
		b.sync = true
		root.add_node("C_st", b)
		root.connect_node("C_st", 0, st_nodes[0])
		root.connect_node("C_st", 1, st_nodes[1])
		_nodes += 1
		idx.charge["st"] = idx.param("C_st/blend_amount")
		idx.defaults[idx.charge.st] = 0.0
		src = "C_st"
	var add := AnimationNodeAdd2.new()
	add.sync = false
	root.add_node("C_add", add)
	root.connect_node("C_add", 0, top)
	root.connect_node("C_add", 1, src)
	_nodes += 1
	idx.charge["add"] = idx.param("C_add/add_amount")
	idx.defaults[idx.charge.add] = 0.0
	return "C_add"


# --- OneShots ----------------------------------------------------------------------------------

func _build_actions(root: AnimationNodeBlendTree, top: String) -> String:
	var partials: Array[String] = []
	var twins: Array[String] = []
	var loops := {}
	var acts: Dictionary = data.graph.get("actions", {})
	var keys := acts.keys()
	# Weapon order first (a later profile's clips never move an earlier weapon's OneShots in the
	# chain: the chain order is the blend order of overlapping partials), then the key.
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ia := weapons.find(String(a).get_slice("/", 0))
		var ib := weapons.find(String(b).get_slice("/", 0))
		if ia != ib:
			return ia < ib
		return String(a) < String(b))
	for k in keys:
		var w := String(k).get_slice("/", 0)
		if not weapons.has(w):
			continue
		var a: Dictionary = acts[k]
		var rec := {"partial": "", "twin": "", "loop": bool(a.get("loop", false)),
				"start_phase": float(a.get("start_phase", 0.0)), "frontier_key": a.get("frontier_key"),
				"state": a.get("state", ""), "status": a.get("status", "")}
		if a.get("partial") is String and _has(String(a.partial)):
			rec.partial = String(a.partial)
			if not partials.has(rec.partial):
				partials.append(rec.partial)
			loops[rec.partial] = bool(loops.get(rec.partial, false)) or rec.loop
		if a.get("twin") is String and _has(String(a.twin)):
			rec.twin = String(a.twin)
			if not twins.has(rec.twin):
				twins.append(rec.twin)
			loops[rec.twin] = bool(loops.get(rec.twin, false)) or rec.loop
		idx.actions[k] = rec
	# A TimeSeek only where an action starts inside its clip (holster: the draw clip backwards).
	var seek := {}
	for k in idx.actions:
		var a: Dictionary = idx.actions[k]
		if a.start_phase > 0.0:
			seek[a.partial] = true
			seek[a.twin] = true
	var fade: Array = data.tuning("oneshot_fade", [0.1, 0.15])
	# A twin additive that keys bones of its own partial leaves them to the partial (see the
	# header): its filter is its tracks minus the tracks of every partial it is paired with.
	var excl := {}
	for k in idx.actions:
		var a: Dictionary = idx.actions[k]
		if a.twin == "" or a.partial == "":
			continue
		if not excl.has(a.twin):
			excl[a.twin] = {}
		for tp in _track_paths(a.partial):
			excl[a.twin][String(tp)] = true
	top = _oneshots(root, top, "XA", twins, true, false, loops, seek, true, fade, excl)
	_partials_build = [partials, loops, seek, fade]
	var cc: Array[String] = []
	for w in weapons:
		for dir in ["stand_to_crouch", "crouch_to_stand"]:
			var add: Dictionary = data.crouch_change(w, dir).get("add", {})
			if add.get("clip") is String and _has(String(add.clip)):
				idx.crouch_add["%s/%s" % [w, dir]] = String(add.clip)
				if not cc.has(String(add.clip)):
					cc.append(String(add.clip))
	var ccf := float(data.transition_use("crouch_change_add_loop").get("fade_s", 0.2))
	top = _oneshots(root, top, "CC", cc, true, false, {}, {}, false, [ccf, ccf])
	return top


func _build_runtime_oneshots(root: AnimationNodeBlendTree, top: String) -> String:
	var fire: Array[String] = []
	var rc: Dictionary = data.graph.get("runtime_clips", {})
	for k in rc.get("fire", {}):
		if not weapons.has(String(k).get_slice("/", 0)):
			continue
		var c := String(rc.fire[k])
		if _has(c):
			idx.fire[k] = c
			if not fire.has(c):
				fire.append(c)
	# The charge weapon's fire clips start from the held draw (bow-fire--add at 0 is 0.7 rad from
	# the held draw at the drawing shoulder, 2.2 rad from the bind pose): UpperBody hands the draw
	# over to them during their fade-in, so they fade slower (proposed values).
	var charge_fire := {}
	for k in idx.fire:
		if _charge_weapon(String(k).get_slice("/", 0)):
			charge_fire[idx.fire[k]] = true
	var plain_fire: Array[String] = []
	var slow_fire: Array[String] = []
	for c in fire:
		if charge_fire.has(c):
			slow_fire.append(c)
		else:
			plain_fire.append(c)
	top = _oneshots(root, top, "F", plain_fire, true, false, {}, {}, false, data.tuning("fire_fade", [0.02, 0.1]))
	top = _oneshots(root, top, "F", slow_fire, true, false, {}, {}, false, data.tuning("charge_fire_fade", [0.08, 0.2]))
	top = _build_throw(root, top)
	if not _partials_build.is_empty():
		top = _oneshots(root, top, "X", _partials_build[0], false, true, _partials_build[1], _partials_build[2], true, _partials_build[3])
	var hits: Array[String] = []
	for sect in ["hit_add_by_stance", "hit_add"]:
		for k in rc.get(sect, {}):
			var c := String(rc[sect][k])
			if _has(c):
				idx.hit_add[k] = c
				if not hits.has(c):
					hits.append(c)
	top = _oneshots(root, top, "HA", hits, true, false, {}, {}, false, data.tuning("hit_add_fade", [0.0, 0.2]))
	return top


## Thrown weapons (graph `throw`, THROW; UpperBody's ThrowChain drives it): the graph's
## throw-object-aim (raise), -start, -end and ^idle (recover) states of each clip-set leader and
## stance as inputs of two script-weighted Blend2 chains over the pose below (input 0 "pass"):
##   TU  TU_x<k> filtered to the bones the throw inputs key that are in bone_sets.upper or hands;
##       inputs TU__<clip>: the state's clip on a normalized timeline plus its graph layers
##       (brick-fingers, the recover's 1h carry arm), then seek and ts (as a single lower input);
##   TL  TL_x<k> filtered to the throw clips' other keyed bones (root, pelvis, legs, holsters): the
##       full-body throw of a stationary throw (the graph's throw states are full-body states);
##       inputs TL__<clip>: the clip only (no raise: the wind-up raise is upper-body only).
## TL sits under TU; both sit above the fire / twin additives and below the action partials (a
## draw of the next weapon covers the recover on the bones it keys). Members of a clip set whose
## throw rows equal the leader's map to the leader's inputs (TreeIndex.throw.parts).
func _build_throw(root: AnimationNodeBlendTree, top: String) -> String:
	var rows: Dictionary = data.graph.get("throw", {}).get("rows", {})
	if rows.is_empty():
		return top
	var in_u := {}
	for b in idx.bone_sets.get("upper", PackedStringArray()):
		in_u[String(b)] = true
	for b in idx.bone_sets.get("hands", PackedStringArray()):
		in_u[String(b)] = true
	var parts := {}
	var u_specs: Array = []     # [node, part key, clip, role]
	var built := {}             # "<leader>/<st>" -> true
	for w in weapons:
		for st in stances:
			var row: Dictionary = rows.get("%s/%s" % [w, st], {})
			if row.is_empty():
				continue
			var lw: String = _leader.get(w, w)
			var own := w
			if lw != w and built.has("%s/%s" % [lw, st]) and JSON.stringify(_throw_sig(row)) == JSON.stringify(_throw_sig(rows.get("%s/%s" % [lw, st], {}))):
				own = lw
			for part in ["raise", "start", "end", "recover"]:
				var role: Dictionary = row.get("parts", {}).get(part, {})
				if role.is_empty() or not role.get("clip") is String or not _has(String(role.clip)):
					continue
				var key := "%s/%s/%s" % [own, st, part]
				if own == w:
					u_specs.append([String(role.clip), key, role, part])
				parts["%s/%s/%s" % [w, st, part]] = key
			built["%s/%s" % [w, st]] = true
	if u_specs.is_empty():
		return top
	# Bone sets of the two chains.
	var ub := {}
	var lb := {}
	for sp: Array in u_specs:
		var clips: Array = [sp[0]]
		for l: Dictionary in _layers(sp[2]):
			clips.append(l.clip)
		for c: String in clips:
			for tp in _track_paths(c):
				var bn := String(tp).get_slice(":", 1)
				if in_u.has(bn):
					ub[bn] = true
		for tp in _track_paths(sp[0]):
			var bn := String(tp).get_slice(":", 1)
			if not in_u.has(bn) and not bn in PROP_BONES:
				lb[bn] = true
	var u_bones := PackedStringArray(ub.keys())
	var l_bones := PackedStringArray(lb.keys())
	u_bones.sort()
	l_bones.sort()
	var rec_by_key := {}
	var u_names: Array[String] = []
	var l_names: Array[String] = []
	var seek_u := {}
	for sp: Array in u_specs:
		var clip: String = sp[0]
		var ck := _ck(clip)
		var r := {"key": sp[1], "part": sp[3], "clip": clip, "length": _length(clip), "role_state": sp[2].get("state", "")}
		for half in ["u", "l"]:
			if half == "l" and sp[3] == "raise":
				continue
			var node := "%s__%s__%s" % ["TU" if half == "u" else "TL", String(sp[1]).get_slice("/", 0), ck]
			var bt := AnimationNodeBlendTree.new()
			var s := {"clip": clip, "loop": false, "layers": {String(sp[1]).get_slice("/", 0): _layers(sp[2])} if half == "u" else {},
					"own_weapon": true}
			var lrec := {"node": node, "layers": []}
			_build_single(bt, s, lrec)
			root.add_node(node, bt)
			_nodes += 1
			r[half] = {"node": node, "ts": lrec.ts, "seek": lrec.seek, "position_node": lrec.position_node, "layers": lrec.layers}
			if half == "u":
				u_names.append(node)
			else:
				l_names.append(node)
		seek_u[r.u.node] = [r.u.seek] + ([r.l.seek] if r.has("l") else [])
		rec_by_key[sp[1]] = r
	top = _throw_chain(root, "TL", top, l_names, l_bones)
	top = _throw_chain(root, "TU", top, u_names, u_bones)
	var out_parts := {}
	for k in parts:
		out_parts[k] = rec_by_key[parts[k]]
	var inputs_u := PackedStringArray(["pass"])
	inputs_u.append_array(PackedStringArray(u_names))
	var inputs_l := PackedStringArray(["pass"])
	inputs_l.append_array(PackedStringArray(l_names))
	var chain_l: Array[StringName] = []
	for k in range(1, inputs_l.size()):
		chain_l.append(idx.param("TL_x%d/blend_amount" % k))
	idx.throw = {"parts": out_parts, "inputs_u": inputs_u, "inputs_l": inputs_l, "seek_u": seek_u, "chain_l": chain_l,
			"u_bones": u_bones, "l_bones": l_bones, "release": data.graph.get("throw", {}).get("release", {})}
	idx.bone_sets["throw_upper"] = u_bones
	idx.bone_sets["throw_lower"] = l_bones
	return top


## Clips and layers of a throw row (clip-set sharing).
func _throw_sig(row: Dictionary) -> Array:
	var s := []
	for part in ["raise", "start", "end", "recover"]:
		var r: Dictionary = row.get("parts", {}).get(part, {})
		s.append([r.get("clip"), _layers(r) if not r.is_empty() else []])
	return s


## Blend2 chain <prefix>_x1.. over `names` on top of `below`, every link filtered to `bones`
## (XFadeSelector layout: input 0 is `below`).
func _throw_chain(root: AnimationNodeBlendTree, prefix: String, below: String, names: Array[String],
		bones: PackedStringArray) -> String:
	var t := below
	for k in names.size():
		var x := "%s_x%d" % [prefix, k + 1]
		var b := AnimationNodeBlend2.new()
		b.sync = false
		_filter_bones(b, bones, x)
		root.add_node(x, b)
		root.connect_node(x, 0, t)
		root.connect_node(x, 1, names[k])
		_nodes += 1
		idx.defaults[idx.param("%s/blend_amount" % x)] = 0.0
		t = x
	return t


## True when weapon w has a held-draw additive (runtime_clips.charge, the bow).
func _charge_weapon(w: String) -> bool:
	for k in data.graph.get("runtime_clips", {}).get("charge", {}):
		if String(k).get_slice("/", 0) == w:
			return true
	return false


## One OneShot per clip on the chain `pre` (X, XA, CC, F, HA): <pre>__ <- <pre>T__ TimeScale (when
## `scaled`) <- <pre>S__ TimeSeek (clips in `seek`) <- <pre>C__ clip.
## excl: clip -> {track path String: true} left out of an additive clip's filter (twins).
func _oneshots(root: AnimationNodeBlendTree, top: String, pre: String, clips: Array, add: bool, filter: bool,
		loops: Dictionary, seek: Dictionary, scaled: bool, fade: Array, excl := {}) -> String:
	for clip: String in clips:
		var ck := _ck(clip)
		var loop := bool(loops.get(clip, false))
		var cn := "%sC__%s" % [pre, ck]
		var sn := "%sS__%s" % [pre, ck]
		var tn := "%sT__%s" % [pre, ck]
		var on := "%s__%s" % [pre, ck]
		root.add_node(cn, _anim(clip, "secs" if loop else "plain", loop))
		var below := cn
		var seekable := seek.has(clip)
		if seekable:
			root.add_node(sn, AnimationNodeTimeSeek.new())
			root.connect_node(sn, 0, cn)
			below = sn
			_nodes += 1
		if scaled:
			root.add_node(tn, AnimationNodeTimeScale.new())
			root.connect_node(tn, 0, below)
			below = tn
			_nodes += 1
		var os := AnimationNodeOneShot.new()
		os.mix_mode = AnimationNodeOneShot.MIX_MODE_ADD if add else AnimationNodeOneShot.MIX_MODE_BLEND
		os.fadein_time = float(fade[0])
		os.fadeout_time = float(fade[1])
		os.break_loop_at_end = false
		var excluded := []
		var props := []
		if filter:
			props = _filter_clip(os, clip, on, PROP_BONES if pre == "X" else [])
		elif excl.has(clip):
			var keep: Array[NodePath] = []
			for tp in _track_paths(clip):
				if excl[clip].has(String(tp)):
					if not excluded.has(String(tp).get_slice(":", 1)):
						excluded.append(String(tp).get_slice(":", 1))
				else:
					keep.append(tp)
			if not excluded.is_empty():
				os.filter_enabled = true
				for tp in keep:
					os.set_filter_path(tp, true)
				idx.filters[on] = keep
		root.add_node(on, os)
		root.connect_node(on, 0, top)
		root.connect_node(on, 1, below)
		_nodes += 1
		var rec := {"chain": pre, "node": on, "clip": clip, "loop": loop, "length": _length(clip), "additive": add,
				"request": idx.param("%s/request" % on), "active": idx.param("%s/active" % on),
				"internal_active": idx.param("%s/internal_active" % on), "scale": &"", "seek": &"",
				"position_node": idx.param("%s/current_position" % cn), "fade": [float(fade[0]), float(fade[1])],
				"excluded_bones": excluded, "prop_bones": props}
		if seekable:
			rec.seek = idx.param("%s/seek_request" % sn)
		if scaled:
			rec.scale = idx.param("%s/scale" % tn)
			idx.defaults[rec.scale] = 1.0
		idx.oneshots[on] = rec
		idx.oneshot_node["%s|%s" % [pre, clip]] = on
		top = on
	return top


# --- helpers ----------------------------------------------------------------------------------

## Blend2 chain <pre>_x1 .. over the named nodes; returns the chain's top node.
func _chain(root: AnimationNodeBlendTree, pre: String, names: Array[String]) -> String:
	if names.is_empty():
		return ""
	var top := names[0]
	for k in range(1, names.size()):
		var x := "%s_x%d" % [pre, k]
		var b := AnimationNodeBlend2.new()
		b.sync = false
		root.add_node(x, b)
		root.connect_node(x, 0, top)
		root.connect_node(x, 1, names[k])
		_nodes += 1
		idx.defaults[idx.param("%s/blend_amount" % x)] = 0.0
		top = x
	return top


## AnimationNodeAnimation for a clip. mode: "norm" (custom timeline length 1, stretched; the
## graph's normalized phase), "secs" (custom timeline = clip length, looping), "plain" (none).
func _anim(clip: String, mode: String, loop: bool) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = _anim_path(clip)
	_nodes += 1
	if loop:
		_note_loop(clip)
	match mode:
		"norm":
			_timeline(n, 1.0, true, loop)
		"secs":
			_timeline(n, maxf(_length(clip), 1e-3), false, loop)
	return n


func _timeline(n: AnimationNodeAnimation, length: float, stretch: bool, loop: bool) -> void:
	n.use_custom_timeline = true
	n.timeline_length = length
	n.stretch_time_scale = stretch
	n.start_offset = 0.0
	n.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


func _anim_path(clip: String) -> StringName:
	var p := _godot(clip)
	if ap.has_animation(p):
		return p
	_warn_once("clip:" + clip, "missing clip '%s' -> %s" % [clip, NONE])
	return NONE


func _godot(clip: String) -> StringName:
	if _pose_names.has(clip):
		return _pose_names[clip]
	var p := data.godot_anim(clip)
	if not String(p).begins_with(_lib_name + "/") and not data.override_libraries().has(String(p).get_slice("/", 0)):
		p = StringName("%s/%s" % [_lib_name, data.resolve_alias(clip)])
	return p


func _has(clip: String) -> bool:
	return clip != "" and ap.has_animation(_godot(clip))


func _length(clip: String) -> float:
	var p := _godot(clip)
	if ap.has_animation(p):
		return ap.get_animation(p).length
	return data.clip_length(clip) if data.clip_length(clip) > 0.0 else 1.0


## Unique track paths of a clip (every track type), in track order.
func _track_paths(clip: String) -> Array[NodePath]:
	if _tracks.has(clip):
		return _tracks[clip]
	var out: Array[NodePath] = []
	var p := _godot(clip)
	if ap.has_animation(p):
		var a := ap.get_animation(p)
		var seen := {}
		for t in a.get_track_count():
			var tp := a.track_get_path(t)
			if not seen.has(tp):
				seen[tp] = true
				out.append(tp)
	_tracks[clip] = out
	return out


## Filters `n` to the clip's track paths, less the bones named in `drop`; returns the dropped
## bones the clip keys.
func _filter_clip(n: AnimationNode, clip: String, node_path: String, drop: Array = []) -> Array:
	n.filter_enabled = true
	var paths := _track_paths(clip)
	var dropped := []
	if not drop.is_empty():
		var keep: Array[NodePath] = []
		for tp in paths:
			var bn := String(tp).get_slice(":", 1)
			if bn in drop:
				if not dropped.has(bn):
					dropped.append(bn)
			else:
				keep.append(tp)
		paths = keep
	for tp in paths:
		n.set_filter_path(tp, true)
	idx.filters[node_path] = paths
	return dropped


func _filter_bones(n: AnimationNode, bones: PackedStringArray, node_path: String) -> void:
	n.filter_enabled = true
	var paths: Array[NodePath] = []
	for b in bones:
		var tp := NodePath("%s:%s" % [idx.skeleton_path, b])
		n.set_filter_path(tp, true)
		paths.append(tp)
	idx.filters[node_path] = paths


func _ck(clip: String) -> String:
	if _clipkeys.has(clip):
		return _clipkeys[clip]
	var k := clip_key(clip)
	var base := k
	var i := 2
	while _keys_used.has(k) and _keys_used[k] != clip:
		k = "%s_%d" % [base, i]
		i += 1
	_keys_used[k] = clip
	_clipkeys[clip] = k
	return k


func _skeleton_path() -> String:
	var root_node := ap.get_node_or_null(ap.root_node)
	if root_node and root_node.is_ancestor_of(sk):
		return String(root_node.get_path_to(sk))
	return "Skeleton3D"


## Data issue (not a build warning): the graph loops a clip whose first and last poses differ
## (metrics loop = false, measured by WP2), so every wrap pops. Recorded in idx.loop_seams for
## WP1 / WP4 to decide (e.g. hold the last frame, or restart through a second input with a
## short fade); single-pose clips never pop.
func _note_loop(clip: String) -> void:
	if idx.loop_seams.has(clip) or not data.has_metrics():
		return
	var m := data.clip_metrics(clip)
	if m.is_empty() or m.get("loop", true) != false or _static(clip):
		return
	var e: Dictionary = m.get("loop_err", {})
	idx.loop_seams[clip] = {"rot_rad": float(e.get("rot_rad", 0.0)), "pos_m": float(e.get("pos_m", 0.0)), "bone": e.get("bone")}
	if not _seam_warned.has(clip):
		_seam_warned[clip] = true
		push_warning("TreeBuilder: data issue: %s loops in the graph but its first and last poses differ (%.2f rad at %s): it pops at every wrap" % [
				clip, float(e.get("rot_rad", 0.0)), e.get("bone")])


func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	idx.warnings.append(msg)
	push_warning("TreeBuilder: " + msg)


## metrics bone_sets.upper recomputed: bones keyed by any aim-tree clip that lie under
## upper_base or are root children named *_offset, plus upper_base.
func _upper_fallback() -> PackedStringArray:
	var keyed := {}
	for w in weapons:
		for st in stances:
			var at := data.aim_tree(w, st)
			for part in at:
				var c: Variant = at[part].get("clip") if at[part] is Dictionary else null
				if c is String:
					for tp in _track_paths(String(c)):
						keyed[String(tp.get_concatenated_subnames())] = true
	var ub := sk.find_bone("upper_base")
	var root := sk.find_bone("root")
	var out := PackedStringArray()
	if ub >= 0:
		out.append("upper_base")
	for b in keyed:
		var bi := sk.find_bone(b)
		if bi < 0 or b == "upper_base":
			continue
		var p := sk.get_bone_parent(bi)
		var under := false
		while p >= 0:
			if p == ub:
				under = true
				break
			p = sk.get_bone_parent(p)
		if under or (sk.get_bone_parent(bi) == root and b.contains("_offset")):
			out.append(b)
	out.sort()
	return out


func _hands_fallback() -> PackedStringArray:
	var out := PackedStringArray()
	for i in sk.get_bone_count():
		var b := sk.get_bone_name(i)
		for part in ["_index", "_middle", "_ring", "_pinky", "_thumb", "_palm", "_hand_prop_attachment"]:
			if (b.begins_with("l_") or b.begins_with("r_")) and b.contains(part):
				out.append(b)
				break
	return out


# --- difference clips (bank_kind "diff") ------------------------------------------------------

## The AnimationPlayer's frontier_bank library: the one it already has (never replaced, so trees
## built earlier keep their clips), else the cached one of its actor library, else a new one.
func _bank_library() -> AnimationLibrary:
	var src := ap.get_animation_library(StringName(_lib_name))
	var key := src.get_instance_id()
	if ap.has_animation_library(BANK_LIB):
		var have := ap.get_animation_library(BANK_LIB)
		if not _bank_libs.has(key):
			_bank_libs[key] = have
		return have
	var lib: AnimationLibrary = _bank_libs.get(key)
	if lib == null:
		lib = AnimationLibrary.new()
		_bank_libs[key] = lib
		_bank_ms[key] = 0.0
	ap.add_animation_library(BANK_LIB, lib)
	return lib


## Sampled pose (carry_overrides, THROW2): the pose of `clip` at `t` seconds on the bones in `bones`
## (every one of its channels the clip keys), baked once per library into frontier_bank as a
## single-frame clip. Returns its builder name (POSE_PREFIX...: the library path; _godot() maps it to itself),
## "" when the clip or every masked bone is missing. The clip's asset ids and attribution are kept.
func _pose_clip(clip: String, t: float, bones: PackedStringArray) -> String:
	var src := _godot(clip)
	if not ap.has_animation(src):
		return ""
	var mask := Array(bones)
	mask.sort()
	var key := "p__%s__%d__%s" % [clip_key(data.resolve_alias(clip)), roundi(t * 1000.0),
			String("|".join(PackedStringArray(mask))).md5_text().substr(0, 8)]
	var name := POSE_PREFIX + key
	if _pose_names.has(name):
		return name
	if _bank_lib == null:
		_bank_lib = _bank_library()
	if not _bank_lib.has_animation(StringName(key)):
		var t0 := Time.get_ticks_usec()
		var a := ap.get_animation(src)
		var d := Animation.new()
		d.length = 1.0 / 30.0
		d.loop_mode = Animation.LOOP_NONE
		var keep := {}
		for b in mask:
			keep[String(b)] = true
		var tt := clampf(t, 0.0, a.length)
		for tr in a.get_track_count():
			var tp := a.track_get_path(tr)
			if not keep.has(String(tp.get_concatenated_subnames())):
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
					d.position_track_insert_key(nt, 0.0, a.position_track_interpolate(tr, tt))
				Animation.TYPE_SCALE_3D:
					d.scale_track_insert_key(nt, 0.0, a.scale_track_interpolate(tr, tt))
		if d.get_track_count() == 0:
			_warn_once("pose:" + key, "sampled pose of %s keys none of %s" % [clip, mask])
			return ""
		for m in [&"source_attribution", &"native_asset_id", &"original_name"]:
			if a.has_meta(m):
				d.set_meta(m, a.get_meta(m))
		# As the library's difference clips list theirs: the source clip's asset id and name.
		d.set_meta(&"native_asset_ids", [a.get_meta(&"native_asset_id", "")])
		d.set_meta(&"original_names", [a.get_meta(&"original_name", "")])
		d.set_meta(&"derived_from", [data.resolve_alias(clip)])
		d.set_meta(&"sample_s", tt)
		d.set_meta(&"bones", mask)
		d.set_meta(&"derivation", "TreeBuilder pose sample: the source clip's channels on the listed bones at sample_s (carry_overrides, THROW2)")
		d.set_meta(&"additive_source", false)
		_bank_lib.add_animation(StringName(key), d)
		idx.bake_ms += (Time.get_ticks_usec() - t0) / 1000.0
	_pose_names[name] = StringName(name)
	return name


## Library path of the difference clip rest * center^-1 * side (baked once per library).
func _bank_diff(center: String, side: String) -> StringName:
	var name := StringName("d__%s__%s" % [clip_key(data.resolve_alias(center)), clip_key(data.resolve_alias(side))])
	if not _bank_lib.has_animation(name):
		var t0 := Time.get_ticks_usec()
		var c := ap.get_animation(_godot(center))
		var s := ap.get_animation(_godot(side))
		_bank_lib.add_animation(name, _bake_diff(c, s, [data.resolve_alias(center), data.resolve_alias(side)]))
		var us := (Time.get_ticks_usec() - t0) / 1000.0
		idx.bake_ms += us
		var key := ap.get_animation_library(StringName(_lib_name)).get_instance_id()
		_bank_ms[key] = float(_bank_ms.get(key, 0.0)) + us
	return StringName("%s/%s" % [BANK_LIB, name])


## Difference pose on the normalized timeline: at every normalized key time u of either clip,
## rotation rest * c(u Tc)^-1 * s(u Ts), position / scale rest + s - c, per channel either clip
## keys (a channel one clip does not key is its rest).
func _bake_diff(c: Animation, s: Animation, names: Array) -> Animation:
	var chans := {}
	for pair in [[c, 0], [s, 1]]:
		var a: Animation = pair[0]
		for t in a.get_track_count():
			var ty := a.track_get_type(t)
			if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D and ty != Animation.TYPE_SCALE_3D:
				continue
			var key := "%d|%s" % [ty, a.track_get_path(t)]
			if not chans.has(key):
				chans[key] = [-1, -1, ty, a.track_get_path(t)]
			chans[key][pair[1]] = t
	var us := _grid(c)
	us.append_array(_grid(s))
	us.sort()
	var grid := PackedFloat64Array()
	for u in us:
		if grid.is_empty() or u - grid[grid.size() - 1] > 1e-5:
			grid.append(u)
	var d := Animation.new()
	d.length = 1.0
	d.loop_mode = Animation.LOOP_NONE
	var keys := chans.keys()
	keys.sort()
	for key in keys:
		var ch: Array = chans[key]
		var tp: NodePath = ch[3]
		var bi := sk.find_bone(String(tp.get_concatenated_subnames()))
		var rest := sk.get_bone_rest(bi) if bi >= 0 else Transform3D()
		var tr := d.add_track(ch[2])
		d.track_set_path(tr, tp)
		var tc: int = ch[0]
		var ts: int = ch[1]
		# Both sides constant (at most one key): the difference is constant too.
		var g := grid
		if (tc < 0 or c.track_get_key_count(tc) <= 1) and (ts < 0 or s.track_get_key_count(ts) <= 1):
			g = PackedFloat64Array([0.0])
		match int(ch[2]):
			Animation.TYPE_ROTATION_3D:
				var rq := rest.basis.get_rotation_quaternion()
				for u in g:
					var qc: Quaternion = c.rotation_track_interpolate(tc, u * c.length) if tc >= 0 else rq
					var qs: Quaternion = s.rotation_track_interpolate(ts, u * s.length) if ts >= 0 else rq
					d.rotation_track_insert_key(tr, u, (rq * qc.inverse() * qs).normalized())
			Animation.TYPE_POSITION_3D:
				for u in g:
					var pc: Vector3 = c.position_track_interpolate(tc, u * c.length) if tc >= 0 else rest.origin
					var ps: Vector3 = s.position_track_interpolate(ts, u * s.length) if ts >= 0 else rest.origin
					d.position_track_insert_key(tr, u, rest.origin + ps - pc)
			Animation.TYPE_SCALE_3D:
				var rs := rest.basis.get_scale()
				for u in g:
					var sc: Vector3 = c.scale_track_interpolate(tc, u * c.length) if tc >= 0 else rs
					var ss: Vector3 = s.scale_track_interpolate(ts, u * s.length) if ts >= 0 else rs
					d.scale_track_insert_key(tr, u, rs + ss - sc)
	d.set_meta(&"source_attribution", c.get_meta(&"source_attribution", ""))
	d.set_meta(&"derived_from", names)
	d.set_meta(&"native_asset_ids", [c.get_meta(&"native_asset_id", ""), s.get_meta(&"native_asset_id", "")])
	d.set_meta(&"original_names", [c.get_meta(&"original_name", ""), s.get_meta(&"original_name", "")])
	d.set_meta(&"derivation", "TreeBuilder difference pose rest*center^-1*side (rotation), rest+side-center (position, scale) on the normalized timeline; rest = null-add")
	d.set_meta(&"additive_source", false)
	return d


## Normalized bake times of a clip: a BAKE_HZ grid of its own time (the library keys sit on a 30 Hz
## grid, so every key is on it), including 0 and 1. Between bake times the difference pose is
## interpolated: exact at the bake times, a second-order error in between (<= 0.004 rad on the
## lower banks at 60 Hz, 0.03 at 30 Hz; test_tree_build checks it).
func _grid(a: Animation) -> PackedFloat64Array:
	var rate := maxf(float(a.get_meta(&"sample_rate", BAKE_HZ)), BAKE_HZ)
	var n := maxi(1, roundi(a.length * rate))
	var out := PackedFloat64Array()
	for k in n + 1:
		out.append(float(k) / float(n))
	return out
