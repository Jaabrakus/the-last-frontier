extends SceneTree
## Side colours in a mirror match (Tidebreak round 4, HUD; RingSides, data/ring/sides.json, NpcSquad.element_look's away pick,
## PercentBar.side_colour; the owner's FEEL list: "side colours in mirror matches"; like team jerseys, nothing drawn on anyone):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_sides.gd
##   mirrors     in an earth, water, fire and air mirror team 1 (ring_team_b) wears the element's away dress: the same garments,
##               sides.json's colours over each slot's; team 0 (ring_team_a) wears home, exactly round 3's dress
##   unchanged   a match that is no mirror (each element against another) dresses team 1 exactly as round 3 did (pinned to
##               factions.json's element_dress, untouched by this task), and outside a ring match (the duel, the open world)
##               nobody wears away
##   the plates  PercentBar.side_colour is RingSides.colour: the element's home colour, the away colour for team 1 in a mirror
##   the player  PlayerAppearance.ring_dress never changes, mirror or not
##   3v3         mixed elements: team 1's earth and fire away when team 0 wears them, its air home
##   always      sides.json always (false by default): when on, team 1 always away
##   live        a real earth mirror (scenes/ring.tscn, earth against an earth bot): the bot's outfit carries the away colours
## The last line "RING SIDES TEST PASSED" or "RING SIDES TEST FAILED"; exit 0 only on a pass; a watchdog quits with 2.

const NAME := "RING SIDES TEST"
const LIMIT_S := 200.0
const OWN_CFG := "user://ring_sides_test.cfg"

var checks := 0
var fails: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	SwayCaster.free_override = true
	InputSetup.ensure()
	_run.call_deferred()


func _end() -> void:
	RingSides.sides_override = null
	RingSides.always_override = null
	RingRules.rule_set_override = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


## The look element_look gives a fighter of `faction` in `el`: slot -> colors (the ring garments' only).
func _colors(faction: String, el: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1750
	var lk := NpcSquad.element_look(faction, el, rng)
	var out := {}
	for slot: String in (lk.get("outfit", {}) as Dictionary):
		var d: Variant = lk.outfit[slot]
		if d is Dictionary and (d as Dictionary).has("id"):
			out[slot] = {"id": String(d.id), "colors": (d as Dictionary).get("colors", {})}
	return out


## Round 3's dress of `faction` in `el` (factions.json's element_dress, slot -> {id, colors}; "-" slots left out).
func _round3(faction: String, el: String) -> Dictionary:
	var d: Dictionary = (NpcFactions.get_faction(faction).get("element_dress", {}) as Dictionary).get(el, {})
	var out := {}
	for slot: String in d:
		var v: Dictionary = d[slot]
		out[slot] = {"id": String(v.id), "colors": v.get("colors", {})}
	return out


func _same(a: Dictionary, b: Dictionary) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


## Whether look `got` is home dress `home` with sides.json's away colours of `el` over it (the same garments).
func _is_away(got: Dictionary, home: Dictionary, el: String) -> bool:
	var ad: Dictionary = ((RingSides.cfg().elements as Dictionary)[el] as Dictionary).away_dress
	for slot: String in home:
		if not got.has(slot) or String(got[slot].id) != String(home[slot].id):
			return false
		var want: Dictionary = (home[slot].colors as Dictionary).duplicate()
		if String(home[slot].id) != "-" and ad.has(slot):
			for k: String in (ad[slot] as Dictionary):
				want[k] = ad[slot][k]
		if not _same(got[slot].colors, want):
			return false
	return true


func _run() -> void:
	await process_frame
	_expect(RingSides.match_node() == null, "no ring match in this tree yet (a plain SceneTree)")
	# outside a ring match: nobody away (the duel and the open world untouched)
	var none_away := true
	for el: String in Bending.ELEMENTS:
		none_away = none_away and _same(_colors("ring_team_b", el), _round3("ring_team_b", el)) and not RingSides.away(1, el)
	_expect(none_away and not RingSides.mirror(), "outside a ring match every side wears round 3's dress (the duel's foe is ring_team_b)")
	# each mirror: team 1 away, team 0 home
	var player_dress := {}
	for el: String in Bending.ELEMENTS:
		player_dress[el] = PlayerAppearance.ring_dress(el)
	for el: String in Bending.ELEMENTS:
		RingSides.sides_override = [[el], [el]]
		var b := _colors("ring_team_b", el)
		var a := _colors("ring_team_a", el)
		_expect(RingSides.mirror() and RingSides.away(1) and not RingSides.away(0) and _is_away(b, _round3("ring_team_a", el), el)
				and not _same(b, _round3("ring_team_b", el)) and _same(a, _round3("ring_team_a", el)),
				"%s mirror: team 1 wears the away dress (the same garments, the away colours), team 0 home" % el)
		var home_c := RingSides.colour(0, el)
		var away_c := RingSides.colour(1, el)
		var cfg: Dictionary = (RingSides.cfg().elements as Dictionary)[el]
		_expect(PercentBar.side_colour(0, el) == home_c and PercentBar.side_colour(1, el) == away_c
				and away_c.is_equal_approx(Color(cfg.away[0], cfg.away[1], cfg.away[2]))
				and home_c.is_equal_approx(Color(cfg.home[0], cfg.home[1], cfg.home[2])) and not home_c.is_equal_approx(away_c),
				"%s mirror: the plates' rule colour is RingSides.colour (home %s, away %s)" % [el, home_c.to_html(false), away_c.to_html(false)])
		_expect(_same(PlayerAppearance.ring_dress(el), player_dress[el]), "%s mirror: the player's own dress unchanged" % el)
	# no mirror: round 3's dress exactly
	var ok := true
	var what: Array = []
	for el: String in Bending.ELEMENTS:
		for other: String in Bending.ELEMENTS:
			if other == el:
				continue
			RingSides.sides_override = [[other], [el]]
			var same := _same(_colors("ring_team_b", el), _round3("ring_team_b", el)) and not RingSides.mirror() \
					and RingSides.colour(1, el).is_equal_approx(RingSides.home_colour(el))
			ok = ok and same
			if not same:
				what.append("%s v %s" % [other, el])
	_expect(ok, "no mirror (12 pairings): team 1 dressed exactly as round 3, its plate in its home colour %s" % [what])
	# 3v3 mixed
	RingSides.sides_override = [["earth", "water", "fire"], ["earth", "air", "fire"]]
	_expect(RingSides.mirror() and RingSides.away(1, "earth") and RingSides.away(1, "fire") and not RingSides.away(1, "air")
			and not RingSides.away(0, "earth") and _is_away(_colors("ring_team_b", "earth"), _round3("ring_team_a", "earth"), "earth")
			and _same(_colors("ring_team_b", "air"), _round3("ring_team_b", "air")),
			"3v3 mixed: team 1's earth and fire away (worn on team 0 too), its air home; team 0 all home")
	# always
	RingSides.sides_override = [["earth"], ["water"]]
	RingSides.always_override = true
	_expect(RingSides.away(1, "water") and _is_away(_colors("ring_team_b", "water"), _round3("ring_team_a", "water"), "water"),
			"sides.json always on: team 1 away in a match that is no mirror")
	RingSides.always_override = null
	_expect(not bool(RingSides.cfg().get("always", true)), "sides.json always is false by default (mirror matches only)")
	RingSides.sides_override = null
	# the words: none in sides.json a player reads; its colours in the catalog's ring set only
	var tokens_ok := true
	for el: String in Bending.ELEMENTS:
		var ad: Dictionary = ((RingSides.cfg().elements as Dictionary)[el] as Dictionary).away_dress
		for slot: String in ad:
			for k: String in (ad[slot] as Dictionary):
				var tok := String(ad[slot][k])
				tokens_ok = tokens_ok and (tok.begins_with("#") or ClothMaterials.known_hex(tok) != "#808080")
	_expect(tokens_ok, "every away colour is a known cloth palette token (no new garment, no new dye)")
	await _live()
	_end()


## A real earth mirror: the bot of ring_team_b wears the away colours.
func _live() -> void:
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["earth"]
	MatchSetup.difficulty = "easy"
	RingRules.rule_set_override = "stock"
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 900:
		await physics_frame
		var m := RingMode.find(self)
		if m != null and m.foe != null and is_instance_valid(m.foe):
			break
	var mode := RingMode.find(self)
	var foe: NpcFighter = mode.foe if mode != null else null
	_expect(foe != null, "the earth mirror's bot")
	if foe == null:
		return
	var outfit: Dictionary = foe.look.get("outfit", {}) if foe.look is Dictionary else {}
	var shirt: Variant = outfit.get("shirt")
	var ad: Dictionary = ((RingSides.cfg().elements as Dictionary).earth as Dictionary).away_dress
	var ok := shirt is Dictionary and String((shirt as Dictionary).get("id", "")) == "ring_earth_tunic" \
			and String(((shirt as Dictionary).get("colors", {}) as Dictionary).get("0", "")) == String(ad.shirt["0"])
	_expect(ok and RingSides.mirror() and RingSides.away(1, "earth") and not RingSides.away(0, "earth"),
			"a live earth mirror: the bot's tunic in the away colour (%s)" % [shirt])
	var pl := mode.player
	var bar: PercentBar = pl.hud.percent_bar if pl != null and pl.hud != null else null
	if bar != null:
		for i in 30:
			await process_frame
		var lines := bar.lines()
		var p0: Array = lines.plates[0]
		var p1: Array = lines.plates[1]
		_expect(not p0.is_empty() and not p1.is_empty() and (p0[0].side as Color).is_equal_approx(RingSides.colour(0, "earth"))
				and (p1[0].side as Color).is_equal_approx(RingSides.colour(1, "earth")),
				"the live plates: yours in earth's home colour, theirs in its away colour")
