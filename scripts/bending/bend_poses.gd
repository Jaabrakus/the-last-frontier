class_name BendPoses
extends RefCounted
## The body clip each bending move is cast with, and the moment its strike leaves (data/bending/poses.json;
## docs/bending_design.md "Animations": "a stance per element and about one clip per move ... built a little at a time").
## The owner, 2026-10-04: the animations are our own (docs/animation_provenance.md, animations/SOURCE.md): no clip imported
## from a video or a game, nothing measured off a reference clip (tools/anim_author/fit_ref.gd). So a pose names only clips
## of our own libraries (LIBRARIES: the Form casts, the own key-posed swings, the forage grab, and Frontier_Bend.res once
## the own bending clips are installed), never an excluded one (the file's "exclude", and NEVER whatever the file says).
## The one exception is the owner's own pick (2026-10-11): Frontier tech, the game's own pistol aim for Lightning
## (FRONTIER_LIBRARY, named frontier-, listed by name in the file's "frontier_tech"; frontier_tech()).
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
## A FIGHTING STYLE, per body (B1 of the Advancement window; data/bending/style_poses.json, docs/tidebreak/loadouts_live.md): a
## body whose meta `fighting_style` names a live style (BendLoadout.style_ok: switched on, animated, of that element) is picked
## from that style first: pick(move, mode, element, body) tries the style's mode entry before the element's own (a move or mode
## the style leaves out is the element's own), stance_pose / guard_hold_pose give its stance and held guard. The style's clips
## live in its own library (style_poses.json "library"), loaded the first time one of its clips is asked for (a body that wears
## no style never loads it: LIBRARIES is not changed). Every pick of a style carries the element's own cast timings (hold_s,
## strike_s, back_s, and end_s where the cast roots the caster), written in the style's entries: the style is animation only.
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
## Frontier tech the owner picked for the ring's casts (2026-10-11: "use our musket and pistol tech that we built in frontiers
## over"; tools/anim_author/bake_bend_aim.gd: Lightning on the pistol's standing aim): built from the game's own aims, so not
## our key-posed clips (the base library's lineage: animations/SOURCE.md). In a library of its own, named frontier-, and a pose
## only as the file's "frontier_tech" lists it by name.
const FRONTIER_LIBRARY := "res://animations_extra/Frontier_Bend_Aim.res"
const FRONTIER_PREFIX := "frontier-"
## The fighting styles' poses (a style's library, stance, held guard and the modes it re-poses), and their clips' name prefix.
const STYLES_PATH := "res://data/bending/style_poses.json"
const STYLE_PREFIX := "own-style-"
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
static var _styles: Dictionary = {}     ## style_poses.json "styles" (empty: not read yet)


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
	var sp := _style_library_of(name)
	if sp != "":
		var sl := _library(sp)
		if sl != null and sl.has_animation(name):
			return sl.get_animation(name)
	if name.begins_with(FRONTIER_PREFIX):
		var fl := _library(FRONTIER_LIBRARY)
		if fl != null and fl.has_animation(name):
			return fl.get_animation(name)
	return null


## The library clip `name` comes from ("extra" a test's; "" none).
static func library_of(name: String) -> String:
	if extra_library != null and extra_library.has_animation(name):
		return "extra"
	for path: String in LIBRARIES:
		var lib := _library(path)
		if lib != null and lib.has_animation(name):
			return path
	var sp := _style_library_of(name)
	if sp != "":
		var sl := _library(sp)
		if sl != null and sl.has_animation(name):
			return sp
	if name.begins_with(FRONTIER_PREFIX):
		var fl := _library(FRONTIER_LIBRARY)
		if fl != null and fl.has_animation(name):
			return FRONTIER_LIBRARY
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


## A clip a pose may play: ours (own-) or Frontier tech the owner picked (frontier_tech), in a library, not excluded.
static func usable(name: String) -> bool:
	return (name.begins_with(OWN_PREFIX) or frontier_tech(name)) and not excluded(name) and clip_exists(name)


## Whether clip `name` is Frontier tech the owner picked for a pose (FRONTIER_PREFIX, listed in the file's "frontier_tech").
static func frontier_tech(name: String) -> bool:
	return name.begins_with(FRONTIER_PREFIX) and name in (data().get("frontier_tech", []) as Array)


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


# ---------------------------------------------------------------- the fighting styles
## The fighting styles' poses by id (style_poses.json "styles").
static func styles() -> Dictionary:
	if _styles.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(STYLES_PATH)) if FileAccess.file_exists(STYLES_PATH) else null
		var st: Variant = (d as Dictionary).get("styles", {}) if d is Dictionary else {}
		_styles = st if st is Dictionary and not (st as Dictionary).is_empty() else {"_none": {}}
	return _styles


## Style `style`'s poses ({} none): element, library, stance, guard_hold, modes, clips.
static func style_data(style: String) -> Dictionary:
	var s: Variant = styles().get(style, {})
	return s if s is Dictionary else {}


## The library path of the style clip `name` ("" not a style clip): own-style-<style>-<clip> names its style's library.
static func _style_library_of(name: String) -> String:
	if not name.begins_with(STYLE_PREFIX):
		return ""
	for id: String in styles():
		if name.begins_with(STYLE_PREFIX + id.replace("_", "-") + "-"):
			return String(style_data(id).get("library", ""))
	return ""


## The fighting style `body` plays now as a caster of `element` ("" none: the element's own clips): its meta, when that style is
## live (BendLoadout.style_ok) and has poses. A bot is never given one.
static func style_of(body: Node, element: String) -> String:
	var st := BendLoadout.style_meta(body)
	if st == "" or not BendLoadout.style_ok(st, element):
		return ""
	return st


## The stance pose for `element` ("" none), the body's style's when it has one.
static func stance_pose(element: String, body: Node = null) -> Variant:
	var st := style_of(body, element)
	if st != "" and style_data(st).has("stance") and usable(String(_as_pose(style_data(st).stance).get("clip", ""))):
		return style_data(st).stance
	return (data().get("stance", {}) as Dictionary).get(element, "")


## The held guard's pose for `element` ({clip, stand_in} or a name; "" none), the body's style's when it has one.
static func guard_hold_pose(element: String, body: Node = null) -> Variant:
	var st := style_of(body, element)
	if st != "" and style_data(st).has("guard_hold") and usable(String(_as_pose(style_data(st).guard_hold).get("clip", ""))):
		return style_data(st).guard_hold
	var gh: Variant = data().get("guard_hold", {})
	return (gh as Dictionary).get(element, "") if gh is Dictionary else ""


## Move `m` at `mode` of an `element` caster as style `st` poses it ({} when the style leaves it out, its clip is not usable, or
## the element itself has no pose for it: a style never poses what the element's does not). The style's entry with its own clips
## table and the clip's metas filling what it leaves out, then timed as the element's own pick (_timed_as): the same hold,
## strike and back, the same end and the same root, so a cast takes the same time whichever clips show it. Its alt (the other
## hand) is timed as the element's alt the same way, and dropped when the element has none.
static func _style_pick(st: String, m: String, mode: String, element: String) -> Dictionary:
	var sd := style_data(st)
	var modes: Variant = (sd.get("modes", {}) as Dictionary).get(m, {})
	if not (modes is Dictionary and (modes as Dictionary).has(mode)):
		return {}
	var table: Dictionary = {"clips": sd.get("clips", {})}
	var p := _as_pose((modes as Dictionary)[mode])
	if p.is_empty() or not usable(String(p.clip)):
		return {}
	var ep := pick(m, mode, element)
	if ep.is_empty():
		return {}
	var out := _timed_as(_filled(p, table), ep)
	if out.is_empty():
		return {}
	out["from"] = "style"
	out.erase("alt")
	var alt := _as_pose(p.get("alt", ""))
	var ealt := _as_pose(ep.get("alt", ""))
	if not alt.is_empty() and not ealt.is_empty() and usable(String(alt.clip)):
		var ta := _timed_as(_filled(alt, table), _filled(ealt, data()))
		if not ta.is_empty():
			out["alt"] = ta
	return out


## A worn twist's own pose for move `m` at `mode` (BendLoadout.pose_of: a node's pose change, the Lightning Pistol's
## frontier-pistol-lightning), filled as any pick; {} when the body wears none for it or its clip is not usable. Before the
## fighting style's: the twist is the move's own choice, the style its look.
static func _node_pick(body: Node, m: String, mode: String, element := "") -> Dictionary:
	var pa := String(BendLoadout.new_mode(body, m, mode).get("pose_as", ""))
	if pa != "" and pa != mode:
		return pick(m, pa, element, body)       # (a new mode a worn talent adds, cast with another mode's pose: Mire, the Ice Wall's)
	var nm := BendLoadout.pose_of(body, m, mode)
	if nm == "" or not usable(nm):
		return {}
	var p := _filled({"clip": nm}, data())
	p["from"] = "node"
	return p


## Style pose `b` (a filled pose dictionary) timed as the element's pose `e`: e's hold_s, strike_s, back_s and root, end_s its
## clip's length, and a warp ([[time on e's timeline, time on b's clip], ...]) that puts b's own hold, strike, back and end on
## those, so SwayPose shows b's clip with its strike where e's is. {} when e is timed by a release clip of its own (then,
## press_s: a floor cast) or b has no times of its own.
static func _timed_as(b: Dictionary, e: Dictionary) -> Dictionary:
	if e.has("then") or e.has("press_s"):
		return {}
	var ba := animation(String(b.clip))
	var ea := animation(String(e.clip))
	if ba == null or ea == null:
		return {}
	var bt := []
	var et := []
	for k: String in ["hold_s", "strike_s", "back_s"]:
		if not b.has(k) or not e.has(k):
			return {}
		bt.append(float(b[k]))
		et.append(float(e[k]))
	bt.append(ba.length)
	# (an element pick timed as another clip itself, the gun-style Embers: its end is that clip's, end_s)
	var e_end := float(e.get("end_s", ea.length))
	et.append(e_end)
	var warp: Array = [[0.0, 0.0]]
	for i in et.size():
		var last: Array = warp[warp.size() - 1]
		if float(et[i]) > float(last[0]) + 0.001 and float(bt[i]) >= float(last[1]):
			warp.append([float(et[i]), float(bt[i])])
	var out := b.duplicate(true)
	out["hold_s"] = et[0]
	out["strike_s"] = et[1]
	out["back_s"] = et[2]
	out["end_s"] = e_end
	var root: Variant = e.get("root", false)
	out["root"] = root if root is String else bool(root)    # ("strike": held up to the strike only, SwayPose.rooting)
	out["warp"] = warp
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


## The pose move `m` in `mode` is cast with by an `element` caster ({} none: the tier clip). See the header. `body`: the caster's
## body, for its fighting style (null: the element's own).
static func pick(m: String, mode: String, element: String, body: Node = null) -> Dictionary:
	if body != null:
		mode = BendLoadout.pose_mode(body, m, mode)      # (a worn new skill's mode cast with its move's own pose; else mode)
		var np := _node_pick(body, m, mode, element)
		if not np.is_empty():
			return np
		var st := style_of(body, element)
		if st != "":
			var sp := _style_pick(st, m, mode, element)
			if not sp.is_empty():
				return sp
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
	if p.has("timed_as"):
		# (a new look on the move's own timing: the gun-style Embers and Ice Spear on the sweep's and the overhand throw's)
		var e := _as_pose(p.timed_as)
		e.erase("timed_as")
		var ta := _timed_as(p, _filled(e, d)) if not e.is_empty() and clip_exists(String(e.clip)) else {}
		if not ta.is_empty():
			ta.erase("timed_as")
			return ta
		p.erase("timed_as")
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
	if p.has("warp"):
		# (a pose timed as another's: played straight through, its strike is its own clip's, not the warped timeline's)
		var aw := animation(String(p.clip))
		if aw != null and aw.has_meta(&"strike_s"):
			return float(aw.get_meta(&"strike_s"))
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
