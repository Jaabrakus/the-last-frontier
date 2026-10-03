class_name ClassicRenownBar
extends Control
## The classic HUD's renown bar: a thin bar over the action bar (ClassicFrames) with the player's standing
## (SurvivalEconomy: the standing with each faction, -100..100, its tier from data/survival/npcs.json standing.tiers; the
## story's {standing: faction, by} effects move the same numbers). It follows one faction: the one whose standing moved
## last, else the one he stands best with. The bar is that faction's place within its tier (filled from the tier's floor
## to its ceiling) in the tier's colour (hostile red, distrusted rust, neutral amber, friendly green, trusted a deep
## teal), "Renown: Friendly  ·  Settlers of the valley" on it; its tooltip lists every faction. No survival game: no
## standing yet ("Renown: Neutral", the bar at the middle of neutral, as the story reads 0).
##   refresh(bridge)   once a second (ClassicFrames)
## Read by the test: label, faction, value, tier.

const H := 14.0
const TIER_COLORS := {"hostile": Color(0.72, 0.17, 0.12), "distrusted": Color(0.7, 0.38, 0.16),
		"neutral": Color(0.8, 0.64, 0.22), "friendly": Color(0.32, 0.62, 0.27), "trusted": Color(0.2, 0.56, 0.52)}

var label := "Renown: Neutral"
var faction := ""
var value := 0.0
var tier := "neutral"
var frac := 0.5
var _last := {}                    ## faction -> standing, the last look (what moved)
var _looked := false


func _init() -> void:
	name = "RenownBar"
	custom_minimum_size = Vector2(300, H)
	mouse_filter = Control.MOUSE_FILTER_PASS        # (its tooltip with the cursor free)
	tooltip_text = "Renown: your standing with the people of the valley"


## The factions' names (npcs.json factions), the part before a bracket ("The traders").
static func faction_name(core: SurvivalCore, id: String) -> String:
	if core != null:
		for f in SurvivalUtil.arr(SurvivalUtil.dict(core.data.raw.get("npcs", {})).get("factions")):
			if f is Dictionary and String(f.get("id", "")) == id:
				return String(f.get("name", id)).get_slice(" (", 0)
	return id.trim_prefix("faction.").replace("_", " ").capitalize()


## The floor and ceiling of tier `t` (npcs.json standing.tiers: [{id, max}], each from the last one's max).
static func tier_span(core: SurvivalCore, t: String) -> Vector2:
	var lo := -100.0
	var rows: Array = SurvivalUtil.arr(core.data.section("npcs", "standing").get("tiers")) if core != null else []
	for row in rows:
		var hi := SurvivalUtil.num(row.get("max"), 100.0)
		if String(row.get("id", "")) == t:
			return Vector2(lo, hi)
		lo = hi
	return Vector2(-15.0, 15.0)


func refresh(b: SurvivalBridge) -> void:
	var core: SurvivalCore = b.core if b != null else null
	var all: Dictionary = {}
	if core != null and core.state.economy.get("standing") is Dictionary:
		all = core.state.economy.standing
	# which faction: the one that moved last, else the best
	var moved := ""
	for f: String in all:
		var v := float(all[f])
		if _looked and f != "faction.none" and (not _last.has(f) or absf(float(_last[f]) - v) > 0.001):
			moved = f                  # (a standing moved, or one begun since the last look)
		_last[f] = v
	_looked = core != null
	if moved != "":
		faction = moved
	elif faction == "" or not all.has(faction):
		faction = ""
		var best := -INF
		for f: String in all:
			if f != "faction.none" and float(all[f]) > best:
				best = float(all[f])
				faction = f
	var v := float(all.get(faction, 0.0))
	var t := SurvivalEconomy.standing_tier(core, faction) if core != null and faction != "" else "neutral"
	var span := tier_span(core, t)
	var fr := clampf((v - span.x) / maxf(span.y - span.x, 1.0), 0.0, 1.0)
	var lb := "Renown: %s" % t.capitalize() + ("  ·  %s" % faction_name(core, faction) if faction != "" else "")
	if lb != label or absf(fr - frac) > 0.001 or t != tier:
		label = lb
		frac = fr
		tier = t
		value = v
		queue_redraw()
	# the tooltip: every faction
	var lines := PackedStringArray(["Renown"])
	for f: String in all:
		if f == "faction.none":
			continue
		lines.append("%s: %d  (%s)" % [faction_name(core, f), roundi(float(all[f])), SurvivalEconomy.standing_tier(core, f).capitalize()])
	if lines.size() == 1:
		lines.append("No standing with anyone yet")
	var tip := "\n".join(lines)
	if tip != tooltip_text:
		tooltip_text = tip


func _draw() -> void:
	var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	var col: Color = TIER_COLORS.get(tier, TIER_COLORS.neutral)
	ClassicSkin.bar(self, r, frac, col)
	# the tier's quarters, faint
	for i in range(1, 4):
		var x := r.position.x + r.size.x * float(i) / 4.0
		draw_line(Vector2(x, r.position.y + 2.0), Vector2(x, r.end.y - 2.0), Color(0, 0, 0, 0.35), 1.0)
	ClassicSkin.text_centred(self, r, label, 12, Color(ClassicSkin.INK.r, ClassicSkin.INK.g, ClassicSkin.INK.b, 0.92))
