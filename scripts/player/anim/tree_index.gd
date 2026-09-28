class_name TreeIndex
extends RefCounted
## What TreeBuilder built (plan section 6.1): the tree root plus every node / parameter path the
## runtime drives, as cached StringNames, and the metadata the controllers need (clip lengths,
## layer weights and curves, bank leaves, OneShot clips). Nothing here mutates the tree
## resources; set_*() helpers only write AnimationTree parameters.
##
## Timelines. Every lower-body input (L__*), aim input (A__*) and bank leaf plays on a
## normalized custom timeline (length 1, stretch, loop per the graph role), as the graph samples
## every leaf of a state and that leaf's layers at the state's phase. So:
##   - `seek` / `<h>_seek` seek_request takes a normalized phase in [0, 1];
##   - `ts` / `<h>_ts` scale is cycles per second (1 / length plays in real time; defaults do);
##   - `current_position` of a leaf (`clip`, `<h>_c`, `base`) is the normalized phase.
## OneShot clips (X, XA, F, HA, CC) and grip clips (HC__) play in seconds.
##
## Lower input record (lower[id]):
##   {id, node: "L__<id>", kind: "single" | "bank" | "aimmove", group, modes: [..], weapons: [..],
##    keys: ["<w>/<m>/<role>", ...], loop, length (s, base clip), clip,
##    ts, seek (single) | hemis: {fw|bw: HemiRecord}, hemi_prefix ("L__<id>/hemi"), hemi_param,
##    layers: [LayerRecord],
##    instances: [primary id, "<id>__i2", ...] (one-shot banks and heavy hits built with
##    TreeBuilder instance_slots > 1; on the primary only) | instance_of: primary id, slot: k (the extra
##    instances: same content, no keys; input_for() always names the primary)}
## HemiRecord: {bank: bank_roles key, roles: [center, neg, pos], clips: [c, neg, pos],
##    lengths: [s, s, s], loop, ts, seek, kind: "diff" | "blendspace",
##    neg, pos (diff: add_amount params) | position (blendspace: blend_position param),
##    position_node (leaf whose current_position is the hemisphere phase),
##    aim: {up, down, blocked, relaxed: param, clips} (aimmove only), layers: [LayerRecord]}
## LayerRecord: {param, node, weapon, kind: "partial" | "additive", clip, slot, weight,
##    leaf_weights: [c, neg, pos] (bank hemis: the layer's weight on each leaf, 0 = absent),
##    curve: [17] | null, superseded_by, hemi: "" | "fw" | "bw", input,
##    shared: bool (true only with the opt-in carry "shared": param is a node of the per-weapon
##    stack K, shared by every input that uses that layer; slot_index = its place in
##    carry[weapon]), scale_by_weapon: bool}
## Carry amounts: carry_targets() / write_carry() implement the graph weighting (layer weight x
## weapon weight; x input weight for shared layers), for the controllers to call every frame.
## carry_mode "input" (default) is graph-exact through crossfades; "shared" is a performance
## approximation, exact only while one input is weighted (see TreeBuilder).
##
## Exact-grip override (override_exact_hands_grip; off by default = the graph's hands layers
## place the weapons): grip_sources are the H__<w>__<k> nodes in chain order, each filtered to
## the hands bones its clip keys; grip_targets() / write_grip() give their amounts.
##
## Key formats of input_for():
##   "<w>/<m>/<role>"           lower roles (idle, takeoff, land_soft_run, turn_l, ...; bank
##                              roles fw, bw_lt, start_fw, rev_fw_bw, ... map to their bank input)
##   "<w>/<m>/move|start|stop|rev"   bank inputs
##   "<w>/<m>/hit_full/<dir>"   heavy-hit inputs; "<w>/<m>/death/<variant>" death inputs
##   "<w>/<stance>/aimidle"     full-body aim base; "<w>/<stance>/aimmove" aim-walk bank (option)
##   "<w>/<stand_to_crouch|crouch_to_stand>/cchange"   full-body crouch change

var tree_root: AnimationNodeBlendTree
var bank_kind := "diff"
var carry_mode := "input"
var weapons := PackedStringArray()
var modes := PackedStringArray()
var warnings := PackedStringArray()
var errors := PackedStringArray()
var build_ms := 0.0
var bake_ms := 0.0
var node_count := 0
## Skeleton path prefix of the tracks ("Skeleton3D"), used for bone-set filters.
var skeleton_path := "Skeleton3D"

## Selector chains (XFadeSelector inputs in chain order and their re-entry seek paths).
var L_inputs := PackedStringArray()
var L_seek := {}
var A_inputs := PackedStringArray()
var A_seek := {}

var lower := {}            ## input id -> lower input record
var role_input := {}       ## input_for() key -> input id
var aim := {}              ## "<w>/<stance>" -> {input, node, seek, ts, add_up, add_dn, blk, rel, hands, clips, lengths}
var grips := {}            ## weapon -> {clips: {carry, aim_s, aim_c}, source: {kind: index into grip_sources}}
## Exact-grip sources in chain order (farthest from the output first; smallest filter first):
## [{node: "H__<w>__<kind>", param, weapon, kinds: ["carry" | "aim_s" | "aim_c", ...], clip, bones: n,
##   position_node}]
var grip_sources: Array = []
## True when every source's filter is a subset of every later one's (then grip_targets is exact
## on every hands bone, also mid-fade).
var grip_nested := true
## Override amount to pass to grip_targets() at start (1 when the table enables the override).
var grip_override_default := 0.0
## Data issues found at build time (not warnings): clip -> {rot_rad, pos_m, bone} for clips the
## graph loops whose first and last poses differ (metrics loop = false): each wrap pops.
var loop_seams := {}
var oneshots := {}         ## OneShot node name -> {chain, node, request, active, internal_active, scale, seek, clip, length, loop, additive, fade, position_node}
var oneshot_node := {}     ## "<chain>|<clip>" -> OneShot node name (chains X, XA, CC, F, HA)
var fire := {}             ## "<w>/<stance>" -> clip (oneshot("F", clip))
var hit_add := {}          ## "<stance>/<dir>" and "<dir>" -> clip (oneshot("HA", clip))
var actions := {}          ## "<w>/<stance>/<key>" -> {partial (oneshot("X", ..)), twin (oneshot("XA", ..)), loop, start_phase, ...}
var crouch_add := {}       ## "<w>/<direction>" -> clip (oneshot("CC", clip))
var weapon_out := {}       ## clip -> {param, node, weapons: ["<w>/<stance>", ...], applies: {..}}
var weapon_out_by := {}    ## "<w>/<stance>" -> clip
var charge := {}           ## {add, st, seek: {stand, crouch}, ts: {..}, clips: {..}, lengths: {..}}
var carry := {}            ## weapon -> [{param, node: "K__<w>__<i>", clip, kind, index}] (carry "shared")
var params := {}           ## named top-level parameters: U_aim, H, C_add, ...
var bone_sets := {}        ## upper, hands (what the U_aim / H filters were built from)
var missing_roles := PackedStringArray()   ## "<w>/<m>/<role>" with no clip (status missing)
var defaults := {}         ## parameter path -> initial value (apply_defaults)
var filters := {}          ## node path ("A__musket__stand/blk") -> Array[NodePath] it was built with
## weapon -> the first weapon of its clip set (profiles.<w>.clip_set; itself without one). Members of
## a set share the leader's nodes where their content is identical: aim[] / role_input map them to
## the leader's records, and shared LayerRecords / grip sources list them in `group`.
var clip_set_leader := {}
## Thrown weapons (TreeBuilder._build_throw; {} without): {parts: {"<w>/<stance>/<part>": {key, part,
## clip, length, role_state, u: {node, ts, seek, position_node, layers}, l: {...} (not for raise)}},
## inputs_u / inputs_l (selector inputs, "pass" first), seek_u (TU input -> [TU seek, TL seek]),
## chain_l (TL_x<k> blend_amount params), u_bones, l_bones, release (graph throw.release)}.
var throw := {}

var _param_cache := {}
var _carry_written := {}
var _grip_written := {}


## Installs the tree on an AnimationTree: deterministic mode, tree_root, default parameters.
## (PlayerAnim sets anim_player, root_node and the callback mode itself.)
func install(tree: AnimationTree) -> void:
	tree.deterministic = true
	tree.tree_root = tree_root
	apply_defaults(tree)
	reset_carry_cache()


## Writes every default parameter value (play rates 1/length, layer / blend amounts 0, H amount
## per the exact-grip override, OneShot rates 1).
func apply_defaults(tree: AnimationTree) -> void:
	for p in defaults:
		tree.set(p, defaults[p])


## Cached StringName of "parameters/<path>".
func param(path: String) -> StringName:
	var sn: Variant = _param_cache.get(path)
	if sn == null:
		sn = StringName(path if path.begins_with("parameters/") else "parameters/" + path)
		_param_cache[path] = sn
	return sn


## Lower input id for a key (see the header), or &"" when that role has no input.
func input_for(key: String) -> StringName:
	return StringName(role_input.get(key, ""))


## OneShot record of a clip on a chain (X, XA, CC, F, HA); {} when not built.
func oneshot(chain: String, clip: String) -> Dictionary:
	return oneshots.get(oneshot_node.get("%s|%s" % [chain, clip], ""), {})


func has_input(id: StringName) -> bool:
	return lower.has(String(id))


func lower_record(id: StringName) -> Dictionary:
	return lower.get(String(id), {})


## Sets a bank hemisphere's direction weights (graph lerp-scale weights of the negative and
## positive side leaves; at most one is non-zero in the graph). A BlendSpace1D bank can only
## show linear positions: x = 90 * (w_pos - w_neg).
func set_bank_weights(tree: AnimationTree, input_id: StringName, hemi: String, w_neg: float, w_pos: float) -> void:
	var h: Dictionary = lower.get(String(input_id), {}).get("hemis", {}).get(hemi, {})
	if h.is_empty():
		return
	if h.kind == "diff":
		# A side leaf the library lacks has no node (param &""); the chain then stays on the center.
		if h.neg != &"":
			tree.set(h.neg, clampf(w_neg, 0.0, 1.0))
		if h.pos != &"":
			tree.set(h.pos, clampf(w_pos, 0.0, 1.0))
	else:
		tree.set(h.position, clampf(90.0 * (w_pos - w_neg), -90.0, 90.0))


## Normalized phase (current_position) of a lower input: the single clip, or the given / first
## hemisphere's center leaf.
func phase(tree: AnimationTree, input_id: StringName, hemi := "") -> float:
	var rec: Dictionary = lower.get(String(input_id), {})
	if rec.is_empty():
		return 0.0
	if rec.has("position_node"):
		return float(tree.get(rec.position_node))
	var hs: Dictionary = rec.get("hemis", {})
	var h: Dictionary = hs.get(hemi, hs.get("fw", hs.get("bw", {})))
	return float(tree.get(h.position_node)) if h.has("position_node") else 0.0


## Target amount of every carry-layer parameter for the current weights (the graph weighting;
## LocoBrain / UpperBody decide when to call it):
##   input_w   {input_id: L selector weight} (zero entries may be left out)
##   weapon_w  {weapon: carry weapon weight W}
##   hemi_w    {input_id: {"fw": w, "bw": w}}  bank inputs' hemisphere weights (default fw only)
##   dir_w     {input_id: {hemi: [w_neg, w_pos]}}  bank direction weights (default [0, 0])
##   phase     {input_id: normalized phase}  for weight curves (default 0)
## Shared (K) layer: sum over inputs of input weight x hemisphere weight x layer weight. Per-input
## layer: its layer weight (the L chain and hemisphere Blend2 already weight the input). Either is
## x the weapon weight unless the input belongs to one weapon (aim idle / aim walk). A bank layer
## present on only some leaves is weighted by those leaves' direction weights (the graph applies
## layers per leaf). Weight curves are sampled at the phase. Results are clamped to [0, 1].
func carry_targets(input_w: Dictionary, weapon_w: Dictionary, hemi_w := {}, dir_w := {}, phase := {}) -> Dictionary:
	var out := {}
	for id in input_w:
		var wi := float(input_w[id])
		if wi <= 0.0:
			continue
		var rec: Dictionary = lower.get(String(id), {})
		for l: Dictionary in rec.get("layers", []):
			if l.param == &"":
				continue
			var hw := 1.0
			if l.hemi != "":
				var hws: Dictionary = hemi_w.get(id, {})
				hw = float(hws.get(l.hemi, 1.0 if l.hemi == "fw" else 0.0)) if not hws.is_empty() else (1.0 if l.hemi == "fw" else 0.0)
			var lw := float(l.weight)
			var present := 1.0
			if l.has("leaf_weights"):
				var d: Array = dir_w.get(id, {}).get(l.hemi, [0.0, 0.0])
				var dw := [1.0 - float(d[0]) - float(d[1]), float(d[0]), float(d[1])]
				lw = 0.0
				present = 0.0
				for i in 3:
					lw += dw[i] * float(l.leaf_weights[i])
					present += dw[i] * (1.0 if float(l.leaf_weights[i]) > 0.0 else 0.0)
			if l.curve is Array:
				lw = sample_curve(l.curve, float(phase.get(id, 0.0))) * present
			var a := lw
			if l.scale_by_weapon:
				if l.has("group"):
					var gw := 0.0
					for g in l.group:
						gw += float(weapon_w.get(g, 0.0))
					a *= gw
				else:
					a *= float(weapon_w.get(l.weapon, 0.0))
			if l.shared:
				a *= wi * hw
				out[l.param] = float(out.get(l.param, 0.0)) + a
			else:
				out[l.param] = a
	for p in out:
		out[p] = clampf(out[p], 0.0, 1.0)
	return out


## Writes carry_targets() output; shared-stack amounts not in `targets` go to 0. Only changed
## values are written.
func write_carry(tree: AnimationTree, targets: Dictionary) -> void:
	for w in carry:
		for slot: Dictionary in carry[w]:
			if not targets.has(slot.param) and float(_carry_written.get(slot.param, 0.0)) != 0.0:
				tree.set(slot.param, 0.0)
				_carry_written[slot.param] = 0.0
	for p in targets:
		var v := float(targets[p])
		if not _carry_written.has(p) or absf(float(_carry_written[p]) - v) > 1e-6:
			tree.set(p, v)
			_carry_written[p] = v


## Forgets what write_carry() / write_grip() wrote (after the tree was reset or re-installed).
func reset_carry_cache() -> void:
	_carry_written.clear()
	_grip_written.clear()


## Exact-grip amounts (override_exact_hands_grip) for the current weights:
##   override   0..1 (0 = off: the graph's hands layers; 1 = the grip clips on the hands bones)
##   weapon_w   {weapon: W}  weapon weights (sum <= 1)
##   aim_w      {weapon: 0..1}  carry -> aim grip (default 0 = carry)
##   crouch_w   {weapon: 0..1}  standing -> crouched aim grip (default 0)
## Each source k gets the target weight t_k = override x W x (carry 1 - a | aim_s a (1 - c) |
## aim_c a c) summed over the kinds it plays, and the chain amount a_k = t_k / (1 - sum_{j>k} t_j).
## On a hands bone every source whose filter holds it then weighs exactly t_k and the pose below
## (the graph pose) 1 - sum of those t_k, provided the filters are nested (grip_nested). A bone a
## grip does not key is not touched by it. Returns {param: amount} for every source.
func grip_targets(override: float, weapon_w: Dictionary, aim_w := {}, crouch_w := {}) -> Dictionary:
	var o := clampf(override, 0.0, 1.0)
	var n := grip_sources.size()
	var t := PackedFloat64Array()
	t.resize(n)
	for k in n:
		var src: Dictionary = grip_sources[k]
		var a := clampf(float(aim_w.get(src.weapon, 0.0)), 0.0, 1.0)
		var c := clampf(float(crouch_w.get(src.weapon, 0.0)), 0.0, 1.0)
		var kw := 0.0
		for kind in src.kinds:
			match kind:
				"carry":
					kw += 1.0 - a
				"aim_s":
					kw += a * (1.0 - c)
				"aim_c":
					kw += a * c
		var ww := 0.0
		for g in src.get("group", [src.weapon]):
			ww += float(weapon_w.get(g, 0.0))
		t[k] = o * clampf(ww, 0.0, 1.0) * kw
	var out := {}
	var above := 0.0
	for k in range(n - 1, -1, -1):
		var amt := 0.0
		if t[k] > 1e-9:
			amt = clampf(t[k] / maxf(1.0 - above, 1e-9), 0.0, 1.0)
		out[grip_sources[k].param] = amt
		above += t[k]
	return out


## Writes grip_targets() output (only changed values).
func write_grip(tree: AnimationTree, targets: Dictionary) -> void:
	for p in targets:
		var v := float(targets[p])
		if not _grip_written.has(p) or absf(float(_grip_written[p]) - v) > 1e-6:
			tree.set(p, v)
			_grip_written[p] = v


## Linear sample of a 17-point phase curve (weight_curve) at normalized phase u.
static func sample_curve(curve: Array, u: float) -> float:
	if curve.is_empty():
		return 0.0
	var x := clampf(u, 0.0, 1.0) * (curve.size() - 1)
	var i := mini(int(x), curve.size() - 2)
	if curve.size() == 1:
		return float(curve[0])
	return lerpf(float(curve[i]), float(curve[i + 1]), x - i)


## Every parameter path this index names (for the build test).
func all_param_paths() -> PackedStringArray:
	var out := {}
	var add := func(v: Variant) -> void:
		if v is StringName or v is String:
			var s := String(v)
			if s.begins_with("parameters/"):
				out[s] = true
	var walk := func(v: Variant, rec: Callable) -> void:
		if v is Dictionary:
			for k in v:
				rec.call(v[k], rec)
		elif v is Array:
			for x in v:
				rec.call(x, rec)
		else:
			add.call(v)
	for d in [lower, aim, grip_sources, oneshots, weapon_out, charge, params, L_seek, A_seek, carry]:
		walk.call(d, walk)
	for p in defaults:
		add.call(p)
	var keys := PackedStringArray(out.keys())
	keys.sort()
	return keys


## Summary for logs and the debug overlay.
func summary() -> Dictionary:
	var shared := 0
	for w in carry:
		shared += carry[w].size()
	return {"bank_kind": bank_kind, "carry": carry_mode, "carry_exact_in_crossfades": carry_mode != "shared",
			"shared_carry_nodes": shared, "lower_inputs": L_inputs.size(), "aim_inputs": A_inputs.size(),
			"grip_sources": grip_sources.size(), "grip_nested": grip_nested, "oneshots": oneshots.size(),
			"weapon_out": weapon_out.size(), "nodes": node_count, "build_ms": build_ms, "bake_ms": bake_ms,
			"warnings": warnings.size(), "errors": errors.size(), "loop_seams": loop_seams.keys()}
