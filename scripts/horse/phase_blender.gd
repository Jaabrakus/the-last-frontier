class_name HorsePhaseBlender
extends RefCounted
## Cross-fader for clips whose time is set explicitly every frame (the horse owns the
## phase; the rider samples its clip at the same phase). Built on an AnimationTree in
## manual process mode with three slots; each slot blends a clip with its short-stride
## variant and, by curvature, with the curved (turning) variants of both:
##
##   slot i:  anim_i  (clip)       -+
##            animl_i (clip_tl)     +-> cur_i  (Blend3: -1 = clip_tr, 0 = clip, +1 = clip_tl) -+
##            animr_i (clip_tr)    -+                                                          +-> var_i (Blend2:
##            animv_i  (variant)   -+                                                          |   clip / variant)
##            animvl_i (variant_tl) +-> curv_i (Blend3, same curvature)                       -+
##            animvr_i (variant_tr)-+
##   var_0, var_1 -> mix01 (Blend2) ; mix01, var_2 -> mix (Blend2) -> output
##   optional additive layer (with_additive): mix, animadd -> add (Add2) -> output
##
##   var pb := HorsePhaseBlender.new(anim_player, owner_node)
##   pb.show_clip("walk", t, 0.25, rate)                         # new clip: cross-fade over 0.25 s
##   pb.show_clip("walk", t, 0.25, rate, "walk_s", 0.4)          # 40 % of the short-stride walk
##   pb.show_clip("walk", t, 0.25, rate, "walk_s", 0.4, 0.5)     # ... half way into a left turn
##   pb.update(delta)                                            # applies the pose (tree.advance(0))
##   pb.set_additive("lib/clip--add", t, 1.0)                    # additive layer on top (with_additive)
##
## Curved variants are looked up by name (<clip>_tl / <clip>_tr); a clip without them shows
## straight whatever the curvature. The active slot's time is the caller's. Slots that are
## fading out keep advancing on their own, at the playback rate they had when they were
## last shown, so their feet keep their own rhythm. A new clip takes the weakest slot; when
## a clip change arrives while a fade is still running, the older clips fade out together
## instead of being swapped out (no pop). Time is never advanced by the tree itself
## (advance(0) after the seeks), so the pose is exactly the clips at the slot times.

const SLOTS := 3
## Track suffixes per slot: clip, clip turning left / right, variant, variant left / right.
const TRACKS := ["", "l", "r", "v", "vl", "vr"]

var tree: AnimationTree
var library := ""
var player: AnimationPlayer
var _anims: Array = []          ## per slot: Array of 6 AnimationNodeAnimation (TRACKS order)
var _clip: Array[String] = []
var _variant: Array[String] = []
var _vw: Array[float] = []
var _curve: Array[float] = []
var _time: Array[float] = []
var _rate: Array[float] = []
var _len: Array[float] = []
var _loop: Array[bool] = []
var _w: Array[float] = []
var _active := 0
var _fade := 0.25
## Number of clip changes that arrived while another fade was still running, and the last
## one ("from -> to at weight w"), for tests.
var interrupted_fades := 0
var last_interrupt := ""
## Additive layer (with_additive): an additive clip seeked to _add_time, at _add_amount.
## The names of a clip's left and right variants (<clip><suffix>): the horse's curved turns "_tl" / "_tr"; the
## player's two-hand pull has sideways steps "-lt" / "-rt" (LogPull).
var turn_suffix := ["_tl", "_tr"]
var _add_anim: AnimationNodeAnimation
var _add_time := 0.0
var _add_amount := 0.0


func _init(p: AnimationPlayer, parent: Node, lib := "", with_additive := false) -> void:
	player = p
	library = lib
	var bt := AnimationNodeBlendTree.new()
	for i in SLOTS:
		var arr := []
		for k in TRACKS.size():
			var pre: String = TRACKS[k]
			var an := AnimationNodeAnimation.new()
			arr.append(an)
			var y := 480 * i + 70 * k
			bt.add_node("anim%s_%d" % [pre, i], an, Vector2(0, y))
			bt.add_node("seek%s_%d" % [pre, i], AnimationNodeTimeSeek.new(), Vector2(200, y))
			bt.connect_node("seek%s_%d" % [pre, i], 0, "anim%s_%d" % [pre, i])
		_anims.append(arr)
		# Blend3 inputs: 0 = "-blend" (turning right), 1 = "in" (straight), 2 = "+blend" (left)
		for pair in [["cur_%d" % i, ""], ["curv_%d" % i, "v"]]:
			bt.add_node(pair[0], AnimationNodeBlend3.new(), Vector2(400, 480 * i + (0 if pair[1].is_empty() else 210)))
			bt.connect_node(pair[0], 0, "seek%sr_%d" % [pair[1], i])
			bt.connect_node(pair[0], 1, "seek%s_%d" % [pair[1], i])
			bt.connect_node(pair[0], 2, "seek%sl_%d" % [pair[1], i])
		bt.add_node("var_%d" % i, AnimationNodeBlend2.new(), Vector2(600, 480 * i + 100))
		bt.connect_node("var_%d" % i, 0, "cur_%d" % i)
		bt.connect_node("var_%d" % i, 1, "curv_%d" % i)
		_clip.append("")
		_variant.append("")
		_vw.append(0.0)
		_curve.append(0.0)
		_time.append(0.0)
		_rate.append(1.0)
		_len.append(1.0)
		_loop.append(false)
		_w.append(0.0)
	bt.add_node("mix01", AnimationNodeBlend2.new(), Vector2(800, 240))
	bt.connect_node("mix01", 0, "var_0")
	bt.connect_node("mix01", 1, "var_1")
	bt.add_node("mix", AnimationNodeBlend2.new(), Vector2(1000, 480))
	bt.connect_node("mix", 0, "mix01")
	bt.connect_node("mix", 1, "var_2")
	if with_additive:
		# the source graph's additive layers (Add2: base * rest^-1 * add; the Actor_B rest is the
		# additive reference, BindRest)
		_add_anim = AnimationNodeAnimation.new()
		bt.add_node("animadd", _add_anim, Vector2(1000, 700))
		bt.add_node("seekadd", AnimationNodeTimeSeek.new(), Vector2(1100, 700))
		bt.connect_node("seekadd", 0, "animadd")
		bt.add_node("add", AnimationNodeAdd2.new(), Vector2(1200, 480))
		bt.connect_node("add", 0, "mix")
		bt.connect_node("add", 1, "seekadd")
		bt.connect_node("output", 0, "add")
	else:
		bt.connect_node("output", 0, "mix")
	tree = AnimationTree.new()
	tree.name = "PhaseBlender"
	tree.tree_root = bt
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	parent.add_child(tree)
	tree.anim_player = tree.get_path_to(p)
	tree.root_node = tree.get_path_to(p.get_node(p.root_node))
	tree.active = true


func _full(clip: String) -> String:
	return clip if library.is_empty() else "%s/%s" % [library, clip]


## `name` if the player has it, else `fallback`.
func _or(name: String, fallback: String) -> String:
	return name if player.has_animation(_full(name)) else fallback


func _set_tracks(i: int) -> void:
	var c := _clip[i]
	var v := _variant[i]
	var tl: String = turn_suffix[0]
	var tr: String = turn_suffix[1]
	var names := [c, _or(c + tl, c), _or(c + tr, c), v, _or(v + tl, v), _or(v + tr, v)]
	for k in TRACKS.size():
		(_anims[i][k] as AnimationNodeAnimation).animation = StringName(_full(names[k]))


## Shows `clip` at `time` seconds, playing at `rate` (used to advance it while it fades
## out later). `variant` (a clip of the same length and timing) is blended in with weight
## `variant_w`; `curve` (-1 right .. 1 left) blends in the curved variants of both. A
## different clip than the active one starts a cross-fade of `fade` seconds (0 = cut).
func show_clip(clip: String, time: float, fade := 0.25, rate := 1.0, variant := "", variant_w := 0.0,
		curve := 0.0) -> void:
	var i := _active
	var vv := variant if not variant.is_empty() else clip
	if clip != _clip[i]:
		if _fading():
			interrupted_fades += 1
			last_interrupt = "%s -> %s at weight %.2f" % [_clip[_active], clip, _w[_active]]
		# the weakest slot other than the active one takes the new clip
		var best := -1
		for k in SLOTS:
			if k == _active and not _clip[k].is_empty():
				continue
			if best < 0 or _w[k] < _w[best]:
				best = k
		i = best
		_w[i] = 0.0
		_clip[i] = clip
		_variant[i] = vv
		_set_tracks(i)
		var an := player.get_animation(_full(clip)) if player.has_animation(_full(clip)) else null
		_len[i] = an.length if an else 1.0
		_loop[i] = an != null and an.loop_mode != Animation.LOOP_NONE
		_active = i
		_fade = fade
		var total := 0.0
		for k in SLOTS:
			total += _w[k]
		if fade <= 0.0 or total <= 1e-6:
			for k in SLOTS:
				_w[k] = 0.0
			_w[i] = 1.0
	elif vv != _variant[i]:
		_variant[i] = vv
		_set_tracks(i)
	_time[i] = time
	_rate[i] = rate
	_vw[i] = variant_w if not variant.is_empty() else 0.0
	_curve[i] = clampf(curve, -1.0, 1.0)


## Additive layer (with_additive only): `clip` (full library path) at `time` s, weight `amount`.
## A clip the player does not have leaves the layer at 0.
func set_additive(clip: String, time: float, amount: float) -> void:
	if _add_anim == null:
		return
	if String(_add_anim.animation) != clip:
		_add_anim.animation = StringName(clip)
	_add_time = time
	_add_amount = amount if player.has_animation(clip) else 0.0


func _fading() -> bool:
	return _w[_active] < 1.0 - 1e-4


## Time of the strongest fading-out clip (kept for callers that want to drive it).
func set_previous_time(time: float) -> void:
	var p := _strongest_other()
	if p >= 0:
		_time[p] = time


func _strongest_other() -> int:
	var best := -1
	for k in SLOTS:
		if k == _active or _clip[k].is_empty() or _w[k] <= 1e-4:
			continue
		if best < 0 or _w[k] > _w[best]:
			best = k
	return best


## The strongest clip that is fading out ("" when none).
func previous_clip() -> String:
	var p := _strongest_other()
	return _clip[p] if p >= 0 else ""


func active_clip() -> String:
	return _clip[_active]


func active_time() -> float:
	return _time[_active]


## Curvature weight of the active slot (-1 .. 1).
func active_curve() -> float:
	return _curve[_active]


## Weight (0..1) of the active clip against the ones fading out.
func active_weight() -> float:
	return _w[_active]


func blend_weight() -> float:
	return _w[_active]


## Weight of a clip over all slots (0 when not shown).
func clip_weight(clip: String) -> float:
	var s := 0.0
	for k in SLOTS:
		if _clip[k] == clip:
			s += _w[k]
	return s


func update(delta: float) -> void:
	# fading slots advance on their own at the rate they had
	for k in SLOTS:
		if k == _active or _clip[k].is_empty() or _w[k] <= 0.0:
			continue
		_time[k] += delta * _rate[k]
		_time[k] = fposmod(_time[k], _len[k]) if _loop[k] else clampf(_time[k], 0.0, _len[k])
	# the active slot rises to 1, the others share what is left in proportion
	var wa := 1.0 if _fade <= 0.0 else move_toward(_w[_active], 1.0, delta / _fade)
	var rest := 0.0
	for k in SLOTS:
		if k != _active:
			rest += _w[k]
	for k in SLOTS:
		if k == _active:
			_w[k] = wa
		elif rest > 1e-6:
			_w[k] = _w[k] / rest * (1.0 - wa)
		else:
			_w[k] = 0.0
		if _w[k] <= 1e-4 and k != _active:
			_w[k] = 0.0
	for k in SLOTS:
		if _clip[k].is_empty():
			continue
		for pre: String in TRACKS:
			tree.set("parameters/seek%s_%d/seek_request" % [pre, k], _time[k])
		tree.set("parameters/cur_%d/blend_amount" % k, _curve[k])
		tree.set("parameters/curv_%d/blend_amount" % k, _curve[k])
		tree.set("parameters/var_%d/blend_amount" % k, _vw[k])
	var b := _w[2]
	var a := _w[1] / maxf(1.0 - b, 1e-6) if b < 1.0 - 1e-6 else 0.0
	tree.set("parameters/mix01/blend_amount", a)
	tree.set("parameters/mix/blend_amount", b)
	if _add_anim != null:
		tree.set("parameters/seekadd/seek_request", _add_time)
		tree.set("parameters/add/add_amount", _add_amount)
	tree.advance(0.0)
