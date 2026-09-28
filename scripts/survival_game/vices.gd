class_name Vices
extends Node
## Drink and tobacco (user 2026-09-27: "alcohol, a little bit is an enhancement but stops well rested; too much drink is
## when aiming sways; if a user abuses it, addiction ... tobacco in moderation enhances skills and makes reloading
## faster a little bit"; "we will know when we are merry, but we will never know when tipsy, too much and senseless
## happens"; "for the addicted, stats not capped unless they drink or smoke again"; "the drinking should be like a
## gauge, they can take long drinks or short drinks, they won't know what got them to merry, and same with smoking").
## SurvivalBridge.vices.
##
##   drinking   hold U: a pull from the bottle for as long as it is held (GILL_S a gill; a tap a sip), a new gill from
##              the pack's rum when the last is gone. Only G (user: "no right-click").
##   smoking    hold Y: a draw on the pipe (PIPEFUL_S a pipeful, packed from the tobacco when the bowl is out; the clay
##              pipe needed). Only Y.
##   the gauge  while held, a thin line at the bottom of the screen shows the size of the pull, never how drunk: what is
##              drunk goes to the gut and soaks into the core's drink meter over ABSORB_MIN game minutes (smoke over
##              SMOKE_ABSORB_MIN), so no one pull can be told apart from the rest when merry comes.
##   drink      the core's meter (cond.drunk): merry is an enhancement (blunt force goes on the bleed pool: PlayerWounds)
##              and stops the well-rested boost; drunk: the aim sways and the shots spread (the core's spread_mult /
##              aim_sway_mult, on the player); senseless: the player passes out (SurvivalSleep.pass_out_now). "You feel
##              merry" is said when it comes; nothing past it ever is (shown_drink_stage).
##   tobacco    the pipe meter (cond.tobacco, down TOBACCO_DECAY_H an hour): steady: skill checks +0.05 (the core) and
##              reloads RELOAD_MULT quicker (FrontierPlayer.reload_time_mult); heavy (too much close together): queasy
##   the habit  each on its own: dependence rises with what is taken (DEP_USE a gill or a pipeful; twice when already
##              under the influence) and falls on sober hours (DEP_DECAY_DAY a game day). At ADDICTED_AT the player is
##              addicted: sober, nothing is capped (a craving now and then); taking it again while addicted is a
##              RELAPSE: no well-rested boost for RELAPSE_H game hours, and the dependence jumps. Below RECOVERED_AT they
##              are free of it.
## The rest of the time's vices (user 2026-09-27: "weed ... whiskey, snuff, chewing tobacco, laudanum, kinnikinnick";
## picked with jimsonweed; each with its trade-off, "keeping to our disaplcine nothing effect aim", "no aim sway only for
## drunkenness"). None touches the aim but the drink (drunk: the sway, as ever) or the movement speed:
##   whiskey    U, on the one drink meter: twice rum's strength a gill, the habit quicker, a little warmth
##   cider      U: hard cider, a third of rum's strength, the habit slow, a little food. Pressed from crabapples at the
##              workbench as sweet cider (a little food, no drink), it turns hard in CIDER_WORK_DAYS in the pack
##   laudanum   right-click, a few drops: for LAUD_H the pain of every wound gone (LastingConditions: their costs set
##              aside) and the flux stayed; a sleep on it rests deep (x CALM_REST_MULT). But skills grow LAUD_SKILL_MULT
##              as fast while it is in you, its habit is the strongest, and a second dose within LAUD_OVERDOSE_H knocks
##              you out and hurts you
##   snuff      right-click, a pinch: the pipe's steadiness at once, about an hour of it (on the tobacco habit)
##   chew       right-click, a quid: the steadiness held CHEW_H; a meal nourishes CHEW_FOOD_MULT while chewing
##   kinnikinnick  Y: bearberry leaves and red-osier bark (the alchemy table): half the pipe's steadiness and no habit;
##              with tobacco in it, most of the steadiness for less than half the habit
##   hemp tops  Y: calm while its meter is up: a sleep rests CALM_REST_MULT longer, the cravings for the rest go quiet;
##              but the stomach empties faster and skills grow HEMP_SKILL_MULT as fast; a mild habit of its own
##   jimsonweed Y: a leaf eases the ague (half a day of its cure); more and it is madness: DELIRIUM_H of it, told in words
##              when it comes and when it goes and shown in the Condition tab, nothing on the screen (user: "just a word
##              notification of that and the user checks there conditions"); skill checks fail (the core's
##              cond.delirium), no well-rested boost; a lot and you collapse and are hurt. No habit
## Right-click a drink or a pipe fill in the pack to take it in hand (U, Y use it); laudanum, snuff and a quid are used
## from the pack. The state is in the core's flags ("vices"), so it is saved with the core.

const DRINK_PER_GILL := 25.0    ## = conditions.json cond.drunk meter per_serving (a gill: merry about an hour)
## The drinks (U), each by the gill on the one drink meter: `per` on it, `dep` the drink habit (a gill), `warm` on the
## warmth need, `kcal` in the stomach. Sweet cider is the press's before it has worked: food, not drink.
const DRINKS := {
	"rum": {"per": 25.0, "dep": 5.0, "warm": 0.0, "kcal": 0.0},
	"whiskey": {"per": 50.0, "dep": 8.0, "warm": 6.0, "kcal": 0.0},
	"cider": {"per": 8.0, "dep": 3.0, "warm": 0.0, "kcal": 40.0},
	"sweet_cider": {"per": 0.0, "dep": 0.0, "warm": 0.0, "kcal": 50.0},
}
const DRINK_ORDER := ["rum", "whiskey", "cider", "sweet_cider"]
## The pipe's fills (Y), by the pipeful: `pipe` on the pipe meter (steady), `hemp` / `jimson` on theirs, `habit` whose
## habit and `dep` how much of it.
const FILLS := {
	"tobacco": {"pipe": 25.0, "habit": "tobacco", "dep": 4.0},
	"kinnikinnick_mix": {"pipe": 20.0, "habit": "tobacco", "dep": 1.5},
	"kinnikinnick": {"pipe": 12.5},
	"hemp_tops": {"hemp": 25.0, "habit": "hemp", "dep": 3.0},
	"jimsonweed": {"jimson": 20.0},
}
const FILL_ORDER := ["tobacco", "kinnikinnick_mix", "kinnikinnick", "hemp_tops", "jimsonweed"]
## Hemp: its meter's fall an hour, calm over HEMP_CALM; the stomach's extra kcal an hour while calm, the skills' growth.
const HEMP_DECAY_H := 5.0
const HEMP_CALM := 10.0
const HEMP_HUNGER_H := 30.0
const HEMP_SKILL_MULT := 0.85
## A sleep while calm (hemp) or on laudanum: the boost x this.
const CALM_REST_MULT := 1.25
## Laudanum: game hours a dose lasts, a second dose within this is too much (and what it costs), the skills' growth, the
## flux's cure a dose.
const LAUD_H := 12.0
const LAUD_OVERDOSE_H := 6.0
const LAUD_OVERDOSE_HURT := 20.0
const LAUD_SKILL_MULT := 0.75
const LAUD_FLUX_MIN := 12.0 * 60.0
## Snuff: a pinch on the pipe meter (steady about an hour), its habit; chew: the hours a quid holds the steadiness, a
## meal's worth while chewing, its habit.
const SNUFF_PIPE := 16.0
const SNUFF_DEP := 1.5
const CHEW_H := 4.0
const CHEW_FOOD_MULT := 0.8
const CHEW_DEP := 3.0
## Jimsonweed: its meter's fall an hour; up to JIMSON_SAFE a leaf eases the ague (JIMSON_AGUE_MIN of its cure, once an
## hour); over it DELIRIUM_H of madness; over JIMSON_COLLAPSE the player collapses (JIMSON_HURT off the health).
const JIMSON_DECAY_H := 4.0
const JIMSON_SAFE := 25.0
const JIMSON_COLLAPSE := 60.0
const JIMSON_AGUE_MIN := 12.0 * 60.0
const JIMSON_HURT := 25.0
const DELIRIUM_H := 6.0
## Sweet cider turns hard in this many game days (in the pack).
const CIDER_WORK_DAYS := 2.0
## The workbench's work from the vices' stuff (CampStation): snuff ground and a quid twisted from the pack's tobacco;
## crabapples pressed into sweet cider (it turns hard in the pack: pressed_cider). `n` made.
const BENCH := {
	"snuff": {"inputs": {"tobacco": 1}, "n": 3, "seconds": 5.0, "fire": false, "verb": "Drying and grinding tobacco",
			"detail": "1 tobacco, dried and ground: 3 pinches of snuff (no pipe, no fire)"},
	"chew": {"inputs": {"tobacco": 1}, "n": 2, "seconds": 4.0, "fire": false, "verb": "Twisting a quid",
			"detail": "1 tobacco, sweetened and twisted: 2 quids to chew"},
	"sweet_cider": {"inputs": {"crabapples": 6}, "n": 1, "seconds": 8.0, "fire": false, "verb": "Pressing crabapples",
			"detail": "6 crabapples, crushed and pressed: a jug of sweet cider, hard in two days in the pack"},
}
## What each does for the player, told as it comes on and in the Condition tab and the pack (user 2026-09-27: "let them
## now the postivtve effect each one gives the user like reload faster and etc"). The pipe's steadiness on the core's
## checks (conditions.json cond.tobacco check_mod).
const STEADY_CHECK := 0.05


## "reloads 8% faster, your work 5% surer": the steadiness in words.
static func steady_words() -> String:
	return "reloads %d%% faster, your work %d%% surer" % [roundi((1.0 - RELOAD_MULT) * 100.0), roundi(STEADY_CHECK * 100.0)]


## The merry stage in words.
static func merry_words() -> String:
	return "a blow or a fall only bruises you, later and %d%% less" % roundi((1.0 - PlayerWounds.DRUNK_BLUNT) * 100.0)


## The craving's lines for `what`: the withdrawal's pains and the talk of one more (CRAVE_LINES), and the good it would do,
## argued with its numbers (user 2026-09-27: "for the cravings it lets the user know like remember the faster reload and
## etc all the other things"; then "make it convincing and persusiavie not just like rememebr").
static func crave_lines(what: String) -> Array:
	var out: Array = (CRAVE_LINES.get(what, []) as Array).duplicate()
	var reload := roundi((1.0 - RELOAD_MULT) * 100.0)
	var surer := roundi(STEADY_CHECK * 100.0)
	var deeper := roundi((CALM_REST_MULT - 1.0) * 100.0)
	match what:
		"drink":
			out.append_array(["One dram and a fall wouldn't hurt half as much. Out here, that's only good sense.",
					"It's bitter out. Whiskey would warm you through, and who'd say no to that?",
					"A gill in you and you'd shrug off a blow like nothing. %d%% less, later. Why take it full?" % roundi((1.0 - PlayerWounds.DRUNK_BLUNT) * 100.0)])
		"tobacco":
			out.append_array(["You'd reload %d%% faster with a pipe in you. Out here that could be your life." % reload,
					"A pipe steadies the hands and your work goes %d%% surer. It's not a vice, it's a tool." % surer,
					"Wolves about, and your hands like this? A pinch of snuff would steady them in a moment.",
					"Every hunter in the woods smokes. They know what steady hands are worth."])
		"hemp":
			out.append_array(["A pipe of hemp and you'd sleep %d%% deeper tonight. You need the rest." % deeper,
					"The hemp would quiet all of this. You'd finally sleep properly."])
		"laudanum":
			out.append_array(["A few drops and no wound would hold you back. You'd be whole again, for a while.",
					"The drops would stop the flux. It's medicine. Take your medicine.",
					"You'd sleep %d%% deeper and wake with nothing hurting. Why suffer?" % deeper])
	return out


## Hemp's calm in words.
static func calm_words() -> String:
	return "a sleep rests %d%% deeper, the cravings go quiet" % roundi((CALM_REST_MULT - 1.0) * 100.0)


## Laudanum in words.
static func laudanum_words() -> String:
	return "no wound holds you back, the flux stops, a sleep rests %d%% deeper" % roundi((CALM_REST_MULT - 1.0) * 100.0)


## The habits' names and what is craved.
const HABIT_WORDS := {"drink": ["drink", "a drink"], "tobacco": ["pipe", "a pipe"], "hemp": ["hemp", "a pipe of hemp"],
		"laudanum": ["laudanum", "laudanum"]}
const TOBACCO_PER_PIPE := 25.0
const TOBACCO_DECAY_H := 6.0
const TOBACCO_STEADY := 10.0
const TOBACCO_HEAVY := 60.0
const RELOAD_MULT := 0.92
## Seconds of holding to drink a gill, to smoke a pipeful.
const GILL_S := 3.0
const PIPEFUL_S := 8.0
## Game minutes for the drink to soak in (the time constant), the smoke.
const ABSORB_MIN := 12.0
const SMOKE_ABSORB_MIN := 3.0
const DEP_USE := {"drink": 5.0, "tobacco": 4.0, "hemp": 3.0, "laudanum": 12.0}
const DEP_DECAY_DAY := {"drink": 10.0, "tobacco": 8.0, "hemp": 10.0, "laudanum": 5.0}
const ADDICTED_AT := 50.0
const RECOVERED_AT := 15.0
const RELAPSE_H := 48.0
const RELAPSE_DEP := 10.0
## Withdrawal (user 2026-09-27: "we want it to be annoying where the notification keeps coming up during the withdrawals
## like telling the user like its inner consequence"; "for alcohol you are having withdrawls drink now, or use psychology
## to get the user to withdrawl like its just one sip, or you can always make more its easy"): addicted and sober, an
## inner voice speaks up every CRAVE_GAP_H[0] game hours at the hold's start, down to every CRAVE_GAP_H[1] at its worst
## (a game hour is about two real minutes); laudanum's the most often. A line at a time from crave_lines, never the
## same twice running: the withdrawal's pains, the talk that argues for one more, and the good it did remembered.
const CRAVE_GAP_H := [1.5, 0.5]
const CRAVE_LINES := {
	"drink": ["Your hands won't stop shaking. A drink would steady them.", "Just one sip. One sip never hurt anyone.",
			"You've earned a dram, after the day you've had.", "There's drink in the pack. You know there is.",
			"One gill, then you'll stop. You can always stop.", "A little something to take the edge off, that's all.",
			"You'll quit tomorrow. Tonight, just the one.", "You can always press more cider. It's easy.",
			"Your head pounds. A drink would make it stop.", "It's cold, and a dram warms a man. Everyone says so."],
	"tobacco": ["Just one pipe. It steadies the hands, doesn't it?", "Your fingers keep reaching for the pipe.",
			"One draw and this itch goes away.", "Everything grates on you. A pipe would settle it.",
			"There's twist in the pack. What's it for, if not this?", "You can always grind more snuff. It's easy.",
			"A pinch, only a pinch. Where's the harm?"],
	"hemp": ["Everything's so loud. The hemp would quiet it.", "Just a little hemp, to sleep.",
			"It grows wild by the fort. There's always more.", "You can't settle. You know what settles you."],
	"laudanum": ["Your bones ache for the drops.", "Just a few drops. The bottle says a few drops.",
			"Cold sweat again. The laudanum would stop it.", "Your gut cramps. Only the drops will help.",
			"It's physick, not a vice. A doctor would give it you.", "Every old hurt is awake and begging for the drops.",
			"You'll only need it one more day."],
}
## Jimsonweed's madness in words (it shows nothing on the screen): a line every DELIRIUM_GAP_MIN game minutes or so.
const DELIRIUM_LINES := ["Something moves at the edge of your sight.", "The trees are whispering your name.",
		"Your hands are not your own.", "There are faces in the bark, watching you.", "A drum is beating that no one plays.",
		"The ground tilts. Or does it?", "Someone is standing just behind you."]
const DELIRIUM_GAP_MIN := [20.0, 40.0]
## What a new character carries (gills, pipefuls).
const KIT := {"rum": 6, "tobacco": 6, "clay_pipe": 1, "whiskey": 2, "laudanum": 3}
## Aim sway at the core's aim_sway_mult (degrees per 1.0 over 1).
const SWAY_DEG := 2.0
const ACTIONS := {"drink": &"drink", "tobacco": &"smoke"}

var bridge: SurvivalBridge
var _last_min := -1.0
## The pull being taken now (seconds held), and the one before it fading on the gauge.
var holding := ""
var pull_s := 0.0
var _gauge_a := 0.0
var _layer: CanvasLayer
var _gauge: Control


static func find(tree: SceneTree) -> Vices:
	var b := SurvivalBridge.find(tree)
	return b.vices if b else null


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_layer = CanvasLayer.new()
	_layer.layer = 3
	add_child(_layer)
	_gauge = Control.new()
	_gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	_layer.add_child(_gauge)


func _st() -> Dictionary:
	var fl: Dictionary = bridge.core.state.flags
	if not (fl.get("vices") is Dictionary):
		fl["vices"] = {}
	var v: Dictionary = fl["vices"]
	for k in ["dep", "addicted", "relapse_until", "crave_at"]:
		if not (v.get(k) is Dictionary):
			v[k] = {}
	for k in ["pipe", "gut", "smoke_in", "flask", "bowl", "hemp", "hemp_in", "jimson", "jimson_in"]:
		if not v.has(k):
			v[k] = 0.0
	for k in ["laud_until", "laud_at", "quid_until", "delirium_until", "collapsed_at", "eased_ague_at"]:
		if not v.has(k):
			v[k] = -1e9
	for k in ["flask_kind", "bowl_kind", "drink_pick", "pipe_pick"]:
		if not v.has(k):
			v[k] = ""
	if not (v.get("ciders") is Array):
		v["ciders"] = []
	return v


# --- The kit and the pulls ------------------------------------------------------------------------------------

## A new character's bottle, twist and pipe (SurvivalBridge.new_game).
func give_kit() -> void:
	var p := bridge.player
	if p == null:
		return
	var inv := InventoryState.from_player(p)
	for k: String in KIT:
		inv.add(k, int(KIT[k]))
	p.inventory_pack = inv.pack.duplicate(true)


## Why the player cannot drink ("drink") or smoke ("tobacco") now ("" when they can), with `inv` (null: the pack).
func why_not(what: String, inv: InventoryState = null) -> String:
	var p := bridge.player
	if bridge.core == null or p == null or p.is_dead:
		return "."
	if bridge.core.state.asleep or (bridge.sleeper and bridge.sleeper.passed_out):
		return "."
	if inv == null:
		inv = InventoryState.from_player(p)
	var v := _st()
	if what == "drink":
		if float(v.flask) <= 0.0 and drink_kind(inv) == "":
			return "Nothing to drink"
	else:
		if inv.pack_count("clay_pipe") <= 0:
			return "You need a clay pipe to smoke"
		if float(v.bowl) <= 0.0 and fill_kind(inv) == "":
			return "Nothing to smoke"
	return ""


## What the next gill comes from: the one taken in hand (right-click in the pack) while there is some, else the first in
## the pack ("" none). The bottle already open is drunk first.
func drink_kind(inv: InventoryState = null) -> String:
	return _pick(DRINK_ORDER, "drink_pick", inv)


## What the next pipeful is packed with (as drink_kind).
func fill_kind(inv: InventoryState = null) -> String:
	return _pick(FILL_ORDER, "pipe_pick", inv)


func _pick(order: Array, key: String, inv: InventoryState) -> String:
	if inv == null:
		inv = InventoryState.from_player(bridge.player)
	var want := String(_st()[key])
	if want != "" and inv.pack_count(want) > 0:
		return want
	for k: String in order:
		if inv.pack_count(k) > 0:
			return k
	return ""


## A drink or a pipe fill right-clicked in the pack: the next gill or pipeful is of it.
static func can_choose(kind: String) -> bool:
	return DRINKS.has(kind) or FILLS.has(kind)


func choose(kind: String) -> String:
	if DRINKS.has(kind):
		_st()["drink_pick"] = kind
		return "The %s in hand: hold U to drink it." % InventoryState.name_of(kind).to_lower()
	if FILLS.has(kind):
		_st()["pipe_pick"] = kind
		return "Your pipe packed with %s next: hold Y to smoke it." % InventoryState.name_of(kind).to_lower()
	return ""


## Takes `amount` of a gill ("drink") or a pipeful ("tobacco"): from the bottle or the bowl, a new one from `inv` (null:
## the pack) when it runs out. What is taken goes to the gut (or the lungs) and soaks in later. Returns how much was taken.
func take(what: String, amount: float, inv: InventoryState = null) -> float:
	var own := inv == null
	if own:
		inv = InventoryState.from_player(bridge.player)
	if why_not(what, inv) != "":
		return 0.0
	var v := _st()
	var drink := what == "drink"
	var key := "flask" if drink else "bowl"
	var kind_key := "flask_kind" if drink else "bowl_kind"
	if float(v[key]) <= 0.0001 or String(v[kind_key]) == "":
		v[kind_key] = drink_kind(inv) if drink else fill_kind(inv)
	var kind := String(v[kind_key])
	var d: Dictionary = DRINKS.get(kind, {}) if drink else FILLS.get(kind, {})
	var habit := "drink" if drink else String(d.get("habit", ""))
	# a binge: already under the influence before this pull (what the pull itself adds does not count)
	var binge := habit != "" and _under_influence(habit, 40.0 if drink else TOBACCO_STEADY + TOBACCO_PER_PIPE * 0.5)
	var taken := 0.0
	var want := amount
	while want > 0.0001:
		if float(v[key]) <= 0.0001:
			if kind == "" or inv.pack_count(kind) <= 0:
				break
			inv.take(kind, 1)
			v[key] = 1.0
		var t := minf(want, float(v[key]))
		v[key] = float(v[key]) - t
		taken += t
		want -= t
	if taken <= 0.0:
		return 0.0
	if drink:
		v["gut"] = float(v.gut) + taken * float(d.per)
		var n := bridge.core.state.needs
		if float(d.warm) > 0.0:
			n["warmth"] = minf(100.0, float(n.get("warmth", 100.0)) + taken * float(d.warm))
		if float(d.kcal) > 0.0:
			n["stomach"] = float(n.get("stomach", 0.0)) + taken * float(d.kcal)
		# what it does for you, told once in a while as you drink (whiskey warms, cider feeds)
		var told := "told_" + kind
		if (float(d.warm) > 0.0 or float(d.kcal) > 0.0) and bridge.core.state.minutes - float(v.get(told, -1e9)) > 60.0:
			v[told] = bridge.core.state.minutes
			bridge._notice("The whiskey burns going down and warms you" if float(d.warm) > 0.0
					else "The %s is a little food as well" % InventoryState.name_of(kind).to_lower())
	else:
		v["smoke_in"] = float(v.smoke_in) + taken * float(d.get("pipe", 0.0))
		v["hemp_in"] = float(v.hemp_in) + taken * float(d.get("hemp", 0.0))
		v["jimson_in"] = float(v.jimson_in) + taken * float(d.get("jimson", 0.0))
	if habit != "" and float(d.get("dep", 0.0)) > 0.0:
		_habit(habit, taken * float(d.dep) / float(DEP_USE[habit]), binge)
	if own:
		bridge.player.inventory_pack = inv.pack.duplicate(true)
	return taken


# --- From the pack: laudanum, snuff, a quid --------------------------------------------------------------------

static func can_use(kind: String) -> bool:
	return kind in ["laudanum", "snuff", "chew"]


## Uses one `kind` from `inv` (the pack screen's copy): the line to show.
func use_item(kind: String, inv: InventoryState) -> String:
	if not can_use(kind) or bridge.core == null or bridge.player == null:
		return ""
	if inv.pack_count(kind) <= 0:
		return "No %s in the pack." % InventoryState.name_of(kind).to_lower()
	var v := _st()
	var now := bridge.core.state.minutes
	inv.take(kind, 1)
	match kind:
		"laudanum":
			var again := now - float(v.laud_at) < LAUD_OVERDOSE_H * 60.0
			v["laud_at"] = now
			v["laud_until"] = now + LAUD_H * 60.0
			_habit("laudanum", 1.0, again)
			if bridge.lasting and bridge.lasting.is_on("flux"):
				var fx := bridge.lasting.state("flux")
				fx["recover"] = float(fx.get("recover", 0.0)) + LAUD_FLUX_MIN
			bridge.needs_changed.emit()
			if again:
				# too much: down where they stand, and hurt by it
				var p := bridge.player
				p.health = maxf(1.0, p.health - LAUD_OVERDOSE_HURT)
				bridge.core.state.needs["health"] = p.health
				bridge._health = bridge.core.health()
				if bridge.sleeper:
					bridge.sleeper.pass_out_now.call_deferred()
				return "Too much laudanum: the world goes dark."
			return "A few drops of laudanum in water: %s for %d hours (you learn slower while it is in you)." % [laudanum_words(), roundi(LAUD_H)]
		"snuff":
			v["pipe"] = minf(100.0, float(v.pipe) + SNUFF_PIPE)
			_habit("tobacco", SNUFF_DEP / float(DEP_USE.tobacco), _under_influence("tobacco", TOBACCO_STEADY + TOBACCO_PER_PIPE * 0.5))
			_pipe_stage()
			return "A pinch of snuff: steady hands at once, %s, for about an hour." % steady_words()
		"chew":
			v["quid_until"] = now + CHEW_H * 60.0
			v["pipe"] = maxf(float(v.pipe), TOBACCO_STEADY + 4.0)
			_habit("tobacco", CHEW_DEP / float(DEP_USE.tobacco), _under_influence("tobacco", TOBACCO_STEADY + TOBACCO_PER_PIPE * 0.5))
			_pipe_stage()
			return "A quid in your cheek: steady hands for %d hours, %s (food nourishes %d%% less while you chew)." % [
					roundi(CHEW_H), steady_words(), roundi((1.0 - CHEW_FOOD_MULT) * 100.0)]
	return ""


# --- What they do (SurvivalBridge and LastingConditions ask) ----------------------------------------------------

func laudanum_on() -> bool:
	return bridge.core != null and bridge.core.state.minutes < float(_st().laud_until)


func laudanum_h() -> float:
	return maxf(0.0, float(_st().laud_until) - bridge.core.state.minutes) / 60.0 if bridge.core else 0.0


func calm() -> bool:
	return bridge.core != null and float(_st().hemp) >= HEMP_CALM


func chewing() -> bool:
	return bridge.core != null and bridge.core.state.minutes < float(_st().quid_until)


func delirious() -> bool:
	return bridge.core != null and bridge.core.state.minutes < float(_st().delirium_until)


## A sleep's boost: deeper while calm or on laudanum.
func rest_mult() -> float:
	return CALM_REST_MULT if calm() or laudanum_on() else 1.0


## The skills' growth: slower while calm (hemp) or on laudanum (the lower of them).
func skill_mult() -> float:
	return minf(HEMP_SKILL_MULT if calm() else 1.0, LAUD_SKILL_MULT if laudanum_on() else 1.0)


## What a meal nourishes: less while chewing.
func food_mult() -> float:
	return CHEW_FOOD_MULT if chewing() else 1.0


# --- What the player knows --------------------------------------------------------------------------------------

## "merry" while merry; "" otherwise, sober or past merry (the player never learns tipsy, drunk or senseless).
func shown_drink_stage() -> String:
	var st := SurvivalConditions.stage_of(bridge.core, "cond.drunk") if bridge.core else ""
	return "merry" if st == "merry" else ""


func tobacco_stage() -> String:
	return SurvivalConditions.stage_of(bridge.core, "cond.tobacco") if bridge.core else ""


func pipe_meter() -> float:
	return float(_st().pipe) if bridge.core else 0.0


func dependence(what: String) -> float:
	return float((_st().dep as Dictionary).get(what, 0.0)) if bridge.core else 0.0


func addicted(what: String) -> bool:
	return bool((_st().addicted as Dictionary).get(what, false)) if bridge.core else false


## Game hours a relapse still keeps the well-rested boost away (0: none).
func relapse_h_left() -> float:
	if bridge.core == null:
		return 0.0
	var ru: Dictionary = _st().relapse_until
	var left := 0.0
	for k in ru:
		left = maxf(left, (float(ru[k]) - bridge.core.state.minutes) / 60.0)
	return left


## A relapse keeps the well-rested boost away (SurvivalBridge.rest_cap_h).
func blocks_rest() -> bool:
	return relapse_h_left() > 0.0 or delirious()


# --- The habit ------------------------------------------------------------------------------------------------

func _habit(what: String, units: float, binge: bool) -> void:
	var v := _st()
	var dep: Dictionary = v.dep
	var add := float(DEP_USE[what]) * units * (2.0 if binge else 1.0)
	if bool((v.addicted as Dictionary).get(what, false)):
		# a relapse: the boost stays away, and the hold tightens (once for the pull that starts it)
		var ru: Dictionary = v.relapse_until
		if bridge.core.state.minutes >= float(ru.get(what, -1.0)) - RELAPSE_H * 60.0 + 30.0:
			add += RELAPSE_DEP
		ru[what] = bridge.core.state.minutes + RELAPSE_H * 60.0
	dep[what] = minf(100.0, float(dep.get(what, 0.0)) + add)
	if float(dep[what]) >= ADDICTED_AT and not bool((v.addicted as Dictionary).get(what, false)):
		(v.addicted as Dictionary)[what] = true
		(v.crave_at as Dictionary)[what] = bridge.core.state.minutes + _crave_gap_min(what)
		bridge._notice("The %s has a hold on you now" % HABIT_WORDS[what][0])


## Under the influence of `what` (drink: the meter or what is still soaking in, over `above`).
func _under_influence(what: String, above := 0.0) -> bool:
	var v := _st()
	match what:
		"drink":
			return float(bridge.core.state.needs.get("drunk", 0.0)) + float(v.gut) > above
		"hemp":
			return float(v.hemp) + float(v.hemp_in) > maxf(above, HEMP_CALM * 0.5)
		"laudanum":
			return laudanum_on()
	return float(v.pipe) + float(v.smoke_in) > maxf(above, TOBACCO_STEADY * 0.5)


func _pipe_stage() -> void:
	var core := bridge.core
	var m := float(_st().pipe)
	var st := "heavy" if m >= TOBACCO_HEAVY else ("steady" if m >= TOBACCO_STEADY else "")
	var before := SurvivalConditions.stage_of(core, "cond.tobacco")
	if st != before:
		SurvivalConditions._set_stage(core, "cond.tobacco", st)
		core.invalidate_modifiers()
		if st == "steady" and before == "":
			bridge._notice("Your hands feel steady: " + steady_words())
		if st == "heavy" and not core.state.conditions.has("cond.queasy"):
			SurvivalConditions.add(core, "cond.queasy", {"cause": "tobacco"})
			var rec: Dictionary = core.state.conditions.get("cond.queasy", {})
			if not rec.is_empty():
				rec["cause"] = "tobacco"
				rec["dur_h"] = 2.0
			bridge._notice("Too much smoke: your head swims and your stomach turns")
		bridge.needs_changed.emit()


# --- The frame ------------------------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if bridge == null or bridge.core == null or bridge.player == null:
		return
	# hold U to drink, Y to smoke (not while the pack or a menu has the game paused, not aiming)
	var now := ""
	if not get_tree().paused and not bridge.player.is_dead:
		var aiming := bridge.player.weapon != null and bridge.player.weapon.active and bridge.player.weapon.wants_aim()
		for what: String in ACTIONS:
			if Input.is_action_pressed(ACTIONS[what]) and not aiming:
				now = what
				break
	if now != "" and now != holding:
		var why := why_not(now)
		if why != "":
			if why != "." and Input.is_action_just_pressed(ACTIONS[now]):
				bridge._notice(why)
			now = ""
	if now != holding:
		if now != "":
			pull_s = 0.0     # a new pull; the last one's length stays on the gauge as it fades
		holding = now
	if holding != "":
		var per := GILL_S if holding == "drink" else PIPEFUL_S
		if take(holding, dt / per) > 0.0:
			pull_s += dt
		else:
			holding = ""
	_gauge_a = move_toward(_gauge_a, 1.0 if holding != "" else 0.0, dt * (6.0 if holding != "" else 1.5))
	if _gauge:
		_gauge.queue_redraw()



func _process(_dt: float) -> void:
	if bridge == null or bridge.core == null or bridge.player == null:
		return
	var core := bridge.core
	var m := core.state.minutes + float(core.state.world.get("clock_acc", 0.0))
	var dm := m - _last_min if _last_min >= 0.0 else 0.0
	_last_min = m
	if dm <= 0.0 or dm > 24.0 * 60.0 * 3.0:
		_apply_player()
		return
	var h := dm / 60.0
	var v := _st()
	# what was drunk soaks in: no single pull shows on its own
	if float(v.gut) > 0.0:
		var a := float(v.gut) * (1.0 - exp(-dm / ABSORB_MIN))
		if float(v.gut) - a < 0.05:
			a = float(v.gut)
		v["gut"] = float(v.gut) - a
		var was := shown_drink_stage()
		var n := core.state.needs
		n["drunk"] = minf(100.0, float(n.get("drunk", 0.0)) + a)
		n["drunk_peak"] = maxf(float(n.get("drunk_peak", 0.0)), float(n.drunk))
		SurvivalConditions.update_driven(core)
		core.invalidate_modifiers()
		if was == "" and shown_drink_stage() == "merry" and float(n.drunk) < 40.0:
			bridge._notice("You feel merry: " + merry_words())
	# and the smoke
	if float(v.smoke_in) > 0.0:
		var s := float(v.smoke_in) * (1.0 - exp(-dm / SMOKE_ABSORB_MIN))
		if float(v.smoke_in) - s < 0.05:
			s = float(v.smoke_in)
		v["smoke_in"] = float(v.smoke_in) - s
		v["pipe"] = minf(100.0, float(v.pipe) + s)
	# the pipe wears off (a quid in the cheek holds it steady)
	if float(v.pipe) > 0.0:
		v["pipe"] = maxf(0.0, float(v.pipe) - TOBACCO_DECAY_H * h)
	if chewing():
		v["pipe"] = maxf(float(v.pipe), TOBACCO_STEADY + 4.0)
	_pipe_stage()
	_tick_hemp(v, dm)
	_tick_jimson(v, dm)
	_tick_cider(v)
	# the habit fades on sober hours; free of it below RECOVERED_AT
	for what: String in DEP_DECAY_DAY:
		var dep: Dictionary = v.dep
		if float(dep.get(what, 0.0)) > 0.0 and not _under_influence(what):
			dep[what] = maxf(0.0, float(dep[what]) - float(DEP_DECAY_DAY[what]) * h / 24.0)
		var add: Dictionary = v.addicted
		if bool(add.get(what, false)):
			if float(dep.get(what, 0.0)) < RECOVERED_AT and core.state.minutes >= float((v.relapse_until as Dictionary).get(what, -1.0)):
				add[what] = false
				bridge._notice("You are free of the %s" % HABIT_WORDS[what][0])
			elif not _under_influence(what) and not core.state.asleep:
				# sober: nothing capped, only the craving now and then (quiet while hemp calms: its own still speaks)
				var ca: Dictionary = v.crave_at
				if core.state.minutes >= float(ca.get(what, 0.0)):
					ca[what] = core.state.minutes + _crave_gap_min(what)
					if not (calm() and what != "hemp"):
						bridge._notice(_line(crave_lines(what), "crave_" + what))
	_apply_player()


## Game minutes to the next craving of `what`: sooner the deeper the hold; laudanum's sooner still.
func _crave_gap_min(what: String) -> float:
	var t := clampf((dependence(what) - ADDICTED_AT) / (100.0 - ADDICTED_AT), 0.0, 1.0)
	var h := lerpf(float(CRAVE_GAP_H[0]), float(CRAVE_GAP_H[1]), t) * (0.7 if what == "laudanum" else 1.0)
	return h * 60.0 * randf_range(0.8, 1.2)


## A line of `lines`, not the one said last under `key`.
func _line(lines: Array, key: String) -> String:
	var v := _st()
	if not (v.get("said") is Dictionary):
		v["said"] = {}
	var last := int((v.said as Dictionary).get(key, -1))
	var i := randi() % lines.size()
	if i == last and lines.size() > 1:
		i = (i + 1) % lines.size()
	(v.said as Dictionary)[key] = i
	return String(lines[i])


## Hemp's smoke soaks in and wears off; while calm the stomach empties faster.
func _tick_hemp(v: Dictionary, dm: float) -> void:
	var was := calm()
	if float(v.hemp_in) > 0.0:
		var s := float(v.hemp_in) * (1.0 - exp(-dm / SMOKE_ABSORB_MIN))
		if float(v.hemp_in) - s < 0.05:
			s = float(v.hemp_in)
		v["hemp_in"] = float(v.hemp_in) - s
		v["hemp"] = minf(100.0, float(v.hemp) + s)
	if float(v.hemp) > 0.0:
		v["hemp"] = maxf(0.0, float(v.hemp) - HEMP_DECAY_H * dm / 60.0)
	if calm():
		var n := bridge.core.state.needs
		n["stomach"] = maxf(0.0, float(n.get("stomach", 0.0)) - HEMP_HUNGER_H * dm / 60.0)
	if calm() and not was:
		bridge._notice("A slow calm comes over you: " + calm_words())


## Jimsonweed's smoke soaks in: a little eases the ague; more is madness; a lot, a collapse.
func _tick_jimson(v: Dictionary, dm: float) -> void:
	var core := bridge.core
	var now := core.state.minutes
	if float(v.jimson_in) > 0.0:
		var s := float(v.jimson_in) * (1.0 - exp(-dm / SMOKE_ABSORB_MIN))
		if float(v.jimson_in) - s < 0.05:
			s = float(v.jimson_in)
		v["jimson_in"] = float(v.jimson_in) - s
		v["jimson"] = minf(100.0, float(v.jimson) + s)
		var m := float(v.jimson)
		if m <= JIMSON_SAFE and float(v.jimson_in) < 1.0 and now - float(v.eased_ague_at) >= 60.0:
			v["eased_ague_at"] = now
			if bridge.lasting and bridge.lasting.is_on("ague"):
				bridge.lasting.remedy("jimsonweed")
				bridge._notice("The harsh smoke eases the fever: the ague half a day nearer mended")
		if m > JIMSON_SAFE:
			if not delirious():
				bridge._notice("The world swims and whispers: jimsonweed madness")
				v["delirium_said_at"] = now
				v["visions_at"] = now + randf_range(float(DELIRIUM_GAP_MIN[0]), float(DELIRIUM_GAP_MIN[1]))
			v["delirium_until"] = maxf(float(v.delirium_until), now + DELIRIUM_H * 60.0)
		if m > JIMSON_COLLAPSE and now - float(v.collapsed_at) > 120.0:
			v["collapsed_at"] = now
			var p := bridge.player
			p.health = maxf(1.0, p.health - JIMSON_HURT)
			core.state.needs["health"] = p.health
			bridge._health = core.health()
			bridge._notice("You collapse, raving")
			if bridge.sleeper:
				bridge.sleeper.pass_out_now.call_deferred()
	if float(v.jimson) > 0.0:
		v["jimson"] = maxf(0.0, float(v.jimson) - JIMSON_DECAY_H * dm / 60.0)
	# the madness in words now and then (nothing on the screen)
	if delirious() and now >= float(v.get("visions_at", 0.0)):
		v["visions_at"] = now + randf_range(float(DELIRIUM_GAP_MIN[0]), float(DELIRIUM_GAP_MIN[1]))
		if now - float(v.get("delirium_said_at", -1e9)) > 5.0:
			bridge._notice(_line(DELIRIUM_LINES, "delirium"))
	# the madness on the core: skill checks fail (cond.delirium)
	var st := "delirious" if delirious() else ""
	if SurvivalConditions.stage_of(core, "cond.delirium") != st:
		SurvivalConditions._set_stage(core, "cond.delirium", st)
		core.invalidate_modifiers()
		if st == "":
			bridge._notice("Your head clears")
		bridge.needs_changed.emit()


## Sweet cider pressed at the workbench turns hard in the pack after CIDER_WORK_DAYS (the batches in the order pressed; what
## was drunk sweet meanwhile is gone from them).
func _tick_cider(v: Dictionary) -> void:
	var cs: Array = v.ciders
	if cs.is_empty() or get_tree().paused:
		return
	var now := bridge.core.state.minutes
	var inv: InventoryState = null
	var turned := 0
	while not cs.is_empty() and now - float(cs[0][0]) >= CIDER_WORK_DAYS * 24.0 * 60.0:
		if inv == null:
			inv = InventoryState.from_player(bridge.player)
		var n := mini(int(cs[0][1]), inv.pack_count("sweet_cider"))
		if n > 0:
			inv.take("sweet_cider", n)
			inv.add("cider", n)
			turned += n
		cs.remove_at(0)
	if turned > 0:
		bridge.player.inventory_pack = inv.pack.duplicate(true)
		bridge._notice("The cider has worked: %d jug%s hard" % [turned, "" if turned == 1 else "s"])


## Sweet cider pressed (the workbench): its batch starts working.
func pressed_cider(n: int) -> void:
	(_st().ciders as Array).append([bridge.core.state.minutes, n])


## The player's side of it: the reload (the pipe; an arm wound the other way, LastingConditions), the spread and the sway
## (drink, the core's modifiers).
func _apply_player() -> void:
	var p := bridge.player
	var mods := bridge.core.get_modifiers()
	p.reload_time_mult = (RELOAD_MULT if tobacco_stage() != "" else 1.0) * (bridge.lasting.reload_mult() if bridge.lasting else 1.0)
	p.aim_spread_mult = float(mods.get("spread_mult", 1.0))
	p.aim_sway = maxf(0.0, float(mods.get("aim_sway_mult", 1.0)) - 1.0) * SWAY_DEG


## The pull's gauge: a thin line at the bottom centre that grows while the key is held (a gill, a pipeful at full
## length), over a soft shade; it says how big the pull is, never how drunk.
func _draw_gauge() -> void:
	if _gauge_a <= 0.01:
		return
	var vp := _gauge.get_viewport_rect().size
	var w := 160.0
	var at := Vector2(vp.x * 0.5 - w * 0.5, vp.y - 118.0)
	var per := GILL_S if holding == "drink" else PIPEFUL_S
	var f := clampf(pull_s / per, 0.0, 1.0)
	var col := Color(0.95, 0.74, 0.38, _gauge_a) if holding == "drink" or holding == "" else Color(0.86, 0.82, 0.72, _gauge_a)
	_gauge.draw_texture_rect(FrontierHUD.shade(), Rect2(at - Vector2(40, 16), Vector2(w + 80, 34)), false, Color(1, 1, 1, _gauge_a * 0.8))
	_gauge.draw_line(at, at + Vector2(w, 0), Color(0, 0, 0, 0.45 * _gauge_a), 4.0)
	_gauge.draw_line(at, at + Vector2(w * f, 0), col, 2.0)
