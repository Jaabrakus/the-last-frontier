class_name XFadeSelector
extends RefCounted
## Script-weighted crossfade over a Blend2 chain (plan section 6.2, decision D2).
##
## The player tree has no AnimationNodeStateMachine and no AnimationNodeTransition: every choice
## between inputs is one of these selectors. The inputs hang off a chain of sync=false Blend2
## nodes named <prefix>_x1 .. <prefix>_x<N-1>:
##
##   x1.in0 = input0, x1.in1 = input1, x2.in0 = x1, x2.in1 = input2, ...  (output = x<N-1>)
##
## and the selector writes amount_k = w_k / sum_{j<=k} w_j, which gives input k exactly the
## weight w_k. A request never queues and never pops: the target's weight rises linearly at
## 1/fade per second and every other input shrinks in proportion, so retargeting in the middle of
## a fade is continuous (sum w = 1, per-step change <= dt/fade). A zero-weight input is frozen by
## the sync=false chain (engine contract ec_blend2_freeze), so a request that brings an input back
## from weight 0 may seek it (seek_to >= 0 writes every seek path registered for that input).
##
## Virtual selectors (tree == null, or no chain) keep weights only; UpperBody uses them for the
## carry weapon weights (W) and the stance weight.
##
##   var L := XFadeSelector.new(anim_tree, "L", index.L_inputs, index.L_seek)
##   L.request(&"move__run", 0.2, 0.0)
##   L.update(dt); L.write()

## Non-target weights below this are dropped to 0 (their mass goes to the other non-targets, so
## the target never moves faster than its rate).
const SNAP := 1e-4
## write() skips a chain amount that changed by less than this (except to exactly 0 or 1).
const WRITE_EPS := 1e-5

var tree: AnimationTree
var prefix := ""
var inputs := PackedStringArray()

var _names: Array[StringName] = []
var _index := {}                        ## StringName -> int
var _w := PackedFloat64Array()
var _seek := {}                         ## StringName -> Array[StringName] (seek_request paths)
var _chain: Array[StringName] = []      ## chain node k (1..N-1) -> parameters/<prefix>_x<k>/blend_amount
var _written := PackedFloat64Array()    ## last amount written per chain node (NAN = never)
var _target := 0
var _rate := INF
var _fade := 0.0
var _since := 0.0
var _warned := {}


## tree: the AnimationTree whose parameters are written (null for a virtual selector).
## prefix: chain node prefix, possibly nested ("L", "L__move__run/hemi").
## seek_params: input -> Array of seek_request parameter paths ("parameters/..." or relative).
func _init(p_tree: AnimationTree, p_prefix: String, p_inputs: PackedStringArray, seek_params := {}) -> void:
	tree = p_tree
	prefix = p_prefix
	inputs = p_inputs.duplicate()
	for i in inputs.size():
		var n := StringName(inputs[i])
		_names.append(n)
		_index[n] = i
	_w.resize(inputs.size())
	_w.fill(0.0)
	if not inputs.is_empty():
		_w[0] = 1.0
	for k in seek_params:
		var paths: Array[StringName] = []
		for p in seek_params[k]:
			var s := String(p)
			paths.append(StringName(s if s.begins_with("parameters/") else "parameters/" + s))
		_seek[StringName(k)] = paths
	if tree != null and prefix != "":
		for k in range(1, inputs.size()):
			_chain.append(StringName("parameters/%s_x%d/blend_amount" % [prefix, k]))
	_written.resize(maxi(inputs.size(), 1))
	_written.fill(NAN)


## Fades to `input` over `fade` seconds (<= 0: at the next update). No-op when `input` is already
## the target, except that a shorter fade speeds the running one up. When the input has weight 0
## and seek_to >= 0, its seek paths are written now (they apply at the next advance, together
## with the first non-zero weight).
func request(input: StringName, fade: float, seek_to: float = -1.0) -> void:
	var i := _idx(input)
	if i < 0:
		return
	var rate := INF if fade <= 0.0 else 1.0 / fade
	if i == _target:
		if rate > _rate:
			_rate = rate
			_fade = maxf(fade, 0.0)
		return
	if _w[i] <= 0.0 and seek_to >= 0.0:
		seek(input, seek_to)
	_target = i
	_rate = rate
	_fade = maxf(fade, 0.0)
	_since = 0.0


## Jumps to `input` at full weight (no fade). seek_to >= 0 seeks it whatever its weight.
func set_immediate(input: StringName, seek_to: float = -1.0) -> void:
	var i := _idx(input)
	if i < 0:
		return
	_w.fill(0.0)
	_w[i] = 1.0
	_target = i
	_rate = INF
	_fade = 0.0
	_since = 0.0
	if seek_to >= 0.0:
		seek(input, seek_to)


## Writes `t` to every seek path of `input` (applied at the next advance).
func seek(input: StringName, t: float) -> void:
	if tree == null:
		return
	for p: StringName in _seek.get(input, []):
		tree.set(p, t)


## Advances the fade: w_t' = min(1, w_t + rate*dt), others *= (1 - w_t') / (1 - w_t).
func update(dt: float) -> void:
	_since += dt
	var n := _w.size()
	if n == 0:
		return
	var t := _target
	var wt := _w[t]
	if wt >= 1.0:
		if wt != 1.0:
			_w[t] = 1.0
		return
	var nt := 1.0 if is_inf(_rate) else minf(1.0, wt + _rate * maxf(dt, 0.0))
	if nt >= 1.0 - 1e-12:
		_w.fill(0.0)
		_w[t] = 1.0
		return
	var s := (1.0 - nt) / (1.0 - wt)
	var rem := 0.0
	var largest := -1
	for i in n:
		if i == t:
			continue
		_w[i] *= s
		if largest < 0 or _w[i] > _w[largest]:
			largest = i
	for i in n:
		if i != t and _w[i] > 0.0 and _w[i] < SNAP and i != largest:
			_w[i] = 0.0
	for i in n:
		if i != t:
			rem += _w[i]
	if rem > 0.0:
		var k := (1.0 - nt) / rem
		for i in n:
			if i != t:
				_w[i] *= k
		_w[t] = nt
	else:
		_w.fill(0.0)
		_w[t] = 1.0


## Writes the chain amounts (only the ones that changed by more than WRITE_EPS, or to 0 / 1).
func write() -> void:
	if tree == null or _chain.is_empty():
		return
	var cum := _w[0]
	for k in range(1, _w.size()):
		cum += _w[k]
		var a := 0.0 if cum < 1e-9 else clampf(_w[k] / cum, 0.0, 1.0)
		var last := _written[k]
		if is_nan(last) or absf(a - last) > WRITE_EPS or (a != last and (a == 0.0 or a == 1.0)):
			tree.set(_chain[k - 1], a)
			_written[k] = a


## Forces the next write() to set every chain amount (e.g. after the tree was reset).
func invalidate() -> void:
	_written.fill(NAN)


func weight(input: StringName) -> float:
	var i: int = _index.get(input, -1)
	return _w[i] if i >= 0 else 0.0


## input -> weight (every input).
func weights() -> Dictionary:
	var out := {}
	for i in _w.size():
		out[_names[i]] = _w[i]
	return out


func target() -> StringName:
	return _names[_target] if not _names.is_empty() else &""


## The input with the largest weight (the target on ties).
func dominant() -> StringName:
	if _names.is_empty():
		return &""
	var best := _target
	for i in _w.size():
		if _w[i] > _w[best]:
			best = i
	return _names[best]


## True once the target has the full weight.
func settled() -> bool:
	return _w.size() > 0 and _w[_target] >= 1.0


## Seconds since the last target change.
func since() -> float:
	return _since


func has_input(input: StringName) -> bool:
	return _index.has(input)


func seek_paths(input: StringName) -> Array:
	return _seek.get(input, [])


## The chain amount parameter paths, in chain order (x1 .. x<N-1>).
func chain_params() -> Array[StringName]:
	return _chain


## {inputs, weights (non-zero only), target, rate, fade, since_s}
func snapshot() -> Dictionary:
	var ws := {}
	for i in _w.size():
		if _w[i] > 0.0:
			ws[String(_names[i])] = _w[i]
	return {"prefix": prefix, "inputs": inputs.size(), "weights": ws, "target": String(target()),
			"rate": _rate, "fade": _fade, "since_s": _since}


func _idx(input: StringName) -> int:
	var i: int = _index.get(input, -1)
	if i < 0 and not _warned.has(input):
		_warned[input] = true
		push_error("XFadeSelector(%s): unknown input '%s'" % [prefix, input])
	return i
