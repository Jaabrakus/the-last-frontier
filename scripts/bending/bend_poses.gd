class_name BendPoses
extends RefCounted
## The body clip each bending move is cast with, and the moment its strike leaves (data/bending/poses.json;
## docs/bending_design.md "Animations": "a stance per element and about one clip per move ... built a little at a time").
## The owner, 2026-10-04: the animations are our own (docs/animation_provenance.md, animations/SOURCE.md): no clip imported
## from a video or a game, nothing measured off a reference clip (tools/anim_author/fit_ref.gd). So a pose names only clips
## of our own libraries (LIBRARIES: the Form casts, the own key-posed swings, the forage grab, and Frontier_Bend.res once
## the own bending clips are installed), never an excluded one (the file's "exclude", and NEVER whatever the file says).
##
##   pick(move, mode, element)   {clip, mask, hand, root, alt, hold_s, strike_s, back_s, legs_always, then, press_s, from};
##                               (round 3: a pose may name a stand_in pose, played while its own clip is in no library yet; the
##                               file's pending_clips are the names the CLIPS lane has still to author: all_clips leaves one
##                               out until it lands)
##                               {} when none (the caller plays SwayPose.clip_for, the mastery tier's clip). In order:
##                                 moves[move].modes[mode]   the variation's own
##                                 moves[move].pose          the skill's
##                                 cast[element]             the element's default, only for a move with a bend spec for
##                                                           `mode` (the Sway's old spells, gust push or the stone spike,
##                                                           keep their tier clip unless mapped by name)
##                               A clip missing from every library, or excluded, is passed over to the next. What a pose
##                               leaves out comes from the file's clips[clip] (the interim clips were made before strike_s),
##                               then the clip's own metas
##   element_of(body)            the element a body casts as now ("" none: the open world, where SwayPose keeps the tier
##                               clips exactly as tests/sway/test_form.gd and test_sway.gd have them): a fighter's own
##                               element, the Bending node's, else the duel's (DuelMode.element) for its player. Read
##                               untyped: the element field comes with the caster-agnostic bending (T1) and the bots (T7)
##   animation(name), clip_exists(name), library_of(name), excluded(name), usable(name), all_clips()
##   strike_s(pick)              the strike on the release's clip (-1 none); body_strike_s(pick) where it falls when the
##                               clip plays straight through (a bot: NpcBody.play_cast)
## Tests: `override` is merged over the file (moves, cast, clips and stance by key; exclude added to), `extra_library` holds
## clips a test injects (a synthetic strike_s clip). Neither is set by the game.

const PATH := "res://data/bending/poses.json"
## Our own clip libraries (Frontier_Bend.res from the own bending clip pipeline: absent until it is installed).
const LIBRARIES := [
	"res://animations_extra/Frontier_Form.res",
	"res://animations_extra/Frontier_Own.res",
	"res://animations_extra/Frontier_Forage.res",
	"res://animations_extra/Frontier_Bend.res",
]
const OWN_PREFIX := "own-"
## Never a pose, whatever the file says: the felling axe's D, W and A swings (and their intros), measured off reference
## swings by fit_ref.gd (data/anim_author/axe_swings.json "fit"; A is D mirrored).
const NEVER := ["own-axe-d", "own-axe-w", "own-axe-a"]
## The pick's keys a clip's own metas may give.
const META_KEYS := ["hold_s", "strike_s", "back_s", "hand", "mask", "root", "legs_always", "press_s", "then", "alt"]

## Tests only: merged over the file.
static var override: Dictionary = {}
## Tests only: clips injected beside the libraries (looked up first).
static var extra_library: AnimationLibrary = null

static var _file: Dictionary = {}
static var _libs: Dictionary = {}       ## path -> AnimationLibrary (null: missing)


# ---------------------------------------------------------------- the data
static func data() -> Dictionary:
	if _file.is_empty():
		reload()
	if override.is_empty():
		return _file
	var d := _file.duplicate(true)
	for k: String in override:
		var v: Variant = override[k]
		if k == "exclude" and v is Array:
			var ex: Array = (d.get("exclude", []) as Array).duplicate()
			ex.append_array(v)
			d["exclude"] = ex
		elif v is Dictionary and d.get(k) is Dictionary:
			var merged := (d[k] as Dictionary).duplicate(true)
			merged.merge(v, true)
			d[k] = merged
		else:
			d[k] = v
	return d


static func reload() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	_file = d if d is Dictionary else {"cast": {}, "moves": {}, "clips": {}, "exclude": [], "stance": {}}


## The seconds within which a second cast of the same skill takes its pose's alt (the next hand).
static func combo_window_s() -> float:
	return float(data().get("combo_window_s", 0.6))


# ---------------------------------------------------------------- the clips
static func _library(path: String) -> AnimationLibrary:
	if not _libs.has(path):
		_libs[path] = load(path) as AnimationLibrary if ResourceLoader.exists(path) else null
	return _libs[path]


## The clip named `name` from the test's extra clips or our own libraries (null: none).
static func animation(name: String) -> Animation:
	if name == "":
		return null
	if extra_library != null and extra_library.has_animation(name):
		return extra_library.get_animation(name)
	for path: String in LIBRARIES:
		var lib := _library(path)
		if lib != null and lib.has_animation(name):
			return lib.get_animation(name)
	return null


## The library clip `name` comes from ("extra" a test's; "" none).
static func library_of(name: String) -> String:
	if extra_library != null and extra_library.has_animation(name):
		return "extra"
	for path: String in LIBRARIES:
		var lib := _library(path)
		if lib != null and lib.has_animation(name):
			return path
	return ""


static func clip_exists(name: String) -> bool:
	return animation(name) != null


## Whether clip `name` may never be a pose: in the file's exclude, or one of NEVER (or its intro).
static func excluded(name: String) -> bool:
	if name in (data().get("exclude", []) as Array):
		return true
	for n: String in NEVER:
		if name == n or name.begins_with(n + "-"):
			return true
	return false


## A clip a pose may play: ours (own-), in a library, not excluded.
static func usable(name: String) -> bool:
	return name.begins_with(OWN_PREFIX) and not excluded(name) and clip_exists(name)


## Every clip the file names (the poses and their alts, the element defaults and stances, the clips table's own and a
## release's "then").
static func all_clips() -> Array[String]:
	var out: Array[String] = []
	var d := data()
	var pending: Array = d.get("pending_clips", [])
	var add := func(v: Variant) -> void:
		var p := _as_pose(v)
		while not p.is_empty():
			for nm: String in [String(p.get("clip", "")), String(_as_pose(p.get("alt", "")).get("clip", ""))]:
				if nm != "" and not nm in out and not (nm in pending and not clip_exists(nm)):
					out.append(nm)
			p = _as_pose(p.get("stand_in", ""))          # (round 3: a pose's stand-in is a clip the file names too)
	for el: String in (d.get("cast", {}) as Dictionary):
		add.call(d.cast[el])
	for el: String in (d.get("stance", {}) as Dictionary):
		add.call(d.stance[el])
	var moves: Dictionary = d.get("moves", {})
	for m: String in moves:
		var e: Dictionary = moves[m] if moves[m] is Dictionary else {}
		if e.has("pose"):
			add.call(e.pose)
		for md: String in (e.get("modes", {}) as Dictionary):
			add.call(e.modes[md])
	var gh: Variant = d.get("guard_hold", {})
	if gh is Dictionary:
		for el: String in (gh as Dictionary):
			add.call(gh[el])
	var clips: Dictionary = d.get("clips", {})
	for nm: String in clips:
		add.call(nm)
		var row: Dictionary = clips[nm] if clips[nm] is Dictionary else {}
		add.call(row.get("then", ""))
		add.call(row.get("alt", ""))
	return out


# ---------------------------------------------------------------- the pick
## A pose as a dictionary ({clip, ...}; {} none).
static func _as_pose(v: Variant) -> Dictionary:
	if v is String or v is StringName:
		return {"clip": String(v)} if String(v) != "" else {}
	if v is Dictionary and String((v as Dictionary).get("clip", "")) != "":
		return (v as Dictionary).duplicate(true)
	return {}


## Whether move `m` has a bend spec for `mode` (a bending move, not one of the Sway's old spells).
static func has_spec(m: String, mode: String) -> bool:
	var b: Variant = SwayMoves.move(m).get("bend", {})
	return b is Dictionary and (b as Dictionary).has(mode)


## The pose move `m` in `mode` is cast with by an `element` caster ({} none: the tier clip). See the header.
static func pick(m: String, mode: String, element: String) -> Dictionary:
	var d := data()
	var e: Variant = (d.get("moves", {}) as Dictionary).get(m, {})
	var entry: Dictionary = e if e is Dictionary else {}
	var tries: Array = []
	var modes: Variant = entry.get("modes", {})
	if modes is Dictionary and (modes as Dictionary).has(mode):
		tries.append(["mode", modes[mode]])
	if entry.has("pose"):
		tries.append(["move", entry.pose])
	if element != "" and has_spec(m, mode):
		tries.append(["cast", (d.get("cast", {}) as Dictionary).get(element, "")])
	for tr: Array in tries:
		var p := _as_pose(tr[1])
		while not p.is_empty() and not usable(String(p.clip)):
			p = _as_pose(p.get("stand_in", ""))          # (round 3: a clip not yet authored: its stand-in plays)
		if p.is_empty():
			continue
		p["from"] = tr[0]
		return _filled(p, d)
	return {}


## `p` with what it leaves out from the file's clips table, then the clip's own metas. A meta in the clips' own words is put
## the game's (round 5, CLIPWIRE): its limb (HANDS: "r" the right palm, "foot_l" the left foot, ...), and its "root" only
## when it is a yes or no (the lane's root "place" says where the clip's root sits, not that the caster is held still).
static func _filled(p: Dictionary, d: Dictionary) -> Dictionary:
	var nm := String(p.clip)
	var table: Dictionary = (d.get("clips", {}) as Dictionary).get(nm, {})
	for k: String in table:
		if not p.has(k):
			p[k] = table[k]
	var a := animation(nm)
	if a != null:
		for k: String in META_KEYS:
			if p.has(k) or not a.has_meta(k):
				continue
			var v: Variant = a.get_meta(k)
			if k == "root" and not (v is bool or v is int or v is float):
				continue
			if k == "legs_always" and (v is int or v is float):
				v = float(v) > 0.0
			p[k] = v
	if p.has("hand"):
		p["hand"] = HANDS.get(String(p.hand), String(p.hand))
	return p


## The clips' own limb words (their meta "hand") as the game names the limbs (SwayPose.strike_point, NpcBody.strike_point).
const HANDS := {"r": "r_palm", "l": "l_palm", "both": "both", "foot_r": "r_foot", "foot_l": "l_foot"}


## The strike's moment on the release's clip (s; -1 none known).
static func strike_s(p: Dictionary) -> float:
	return float(p.get("strike_s", -1.0))


## Where the strike falls when the pick's clip plays straight through from its start (a bot's cast: no hold, no release
## clip of its own): a floor cast's press_s (its release is another clip), else strike_s, else the clip's push_s. -1 none.
static func body_strike_s(p: Dictionary) -> float:
	if p.is_empty():
		return -1.0
	if String(p.get("then", "")) != "":
		var a := animation(String(p.clip))
		return float(p.get("press_s", a.get_meta(&"press_s", -1.0) if a != null else -1.0))
	if p.has("strike_s"):
		return float(p.strike_s)
	var a2 := animation(String(p.clip))
	return float(a2.get_meta(&"push_s", -1.0)) if a2 != null else -1.0


# ---------------------------------------------------------------- element mode
static func _is_element(v: Variant) -> bool:
	return (v is String or v is StringName) and String(v) in Bending.ELEMENTS


## The element `body` casts as now ("" none: the open world). Untyped reads: a fighter's `element` (the bots), the
## Bending node's `element` (the player's loadout in a ring or a duel), else the duel's own for its player.
static func element_of(body: Node) -> String:
	if body == null or not is_instance_valid(body):
		return ""
	var own: Variant = body.get(&"element")
	if _is_element(own):
		return String(own)
	var b := body.get_node_or_null(NodePath(String(Bending.NODE_NAME)))
	if b != null:
		var be: Variant = b.get(&"element")
		if _is_element(be):
			return String(be)
	if not body.is_inside_tree():
		return ""
	var duel := DuelMode.find(body.get_tree())
	if duel != null and duel.player == body and _is_element(DuelMode.element):
		return DuelMode.element
	return ""
