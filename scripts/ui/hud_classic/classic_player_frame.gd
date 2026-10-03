class_name ClassicPlayerFrame
extends Control
## The classic HUD's player frame, top left (ClassicFrames): the round portrait in its brass ring (ClassicPortrait: the
## player's face pictured once from his look), on a leather plate his name, his health bar (the blood still to lose dark red
## behind it, what a lasting harm holds it under shaded at its end, "84 / 100" on it) and the Sway's motes in gold, a segment
## a mote (only once the Sway is his: a SwayCaster on him); under it a row of small status icons from the body's state,
## those that do the player good first in a green rim, then those that harm him amber or red, each with its tooltip (the
## cursor free): well rested (the hours left under it), merry, the held torch (its burn left), bleeding, a lasting harm
## (festering, the ague, the flux, sore feet, wasted, chilled to the bone), cold, wet, hungry, thirsty, tired. The survival
## rules off: only what the player's own body says (bleeding, the torch).
##   refresh(p, bridge)        the bars (ClassicFrames, ten times a second); the bars ease toward it every frame
##   refresh_status(p, bridge) the icons (twice a second)
## Read by the test: health_frac, health_text, motes, belt_max, motes_shown, status_ids(), status(id).

const W := 304.0
const H := 124.0
const PORTRAIT := 88.0
const PLATE := Rect2(46, 12, 258, 66)
const NAME_AT := Vector2(98, 33)
const HEALTH_BAR := Rect2(96, 39, 196, 15)
const MOTES_BAR := Rect2(96, 58, 196, 10)
const ICONS_AT := Vector2(96, 82)
const ICON := 24.0
const HURT_FADE := 1.4
## [id, icon (assets/ui/icons; "" a drawn glyph), does the player good].
const STATUSES := [["rested", "need_rest", true], ["merry", "vice_cup", true], ["torch", "hud_torch", true],
		["bleeding", "", false], ["wounded", "need_festering", false], ["cold", "need_warmth", false],
		["wet", "need_wetness", false], ["hungry", "need_food", false], ["thirsty", "need_wetness", false],
		["tired", "need_rest", false]]

var hud: FrontierHUD
var portrait: ClassicPortrait
var display_name := "You"
var health_frac := 1.0
var bleed_frac := 1.0
var cap_frac := 0.0
var health_text := ""
var motes := 0
var belt_max := 0
var motes_shown := false
var _shown_h := 1.0
var _shown_b := 1.0
var _last_health := -1.0
var _row: HBoxContainer
var _icons := {}                  ## id -> StatusIcon


func _init() -> void:
	name = "PlayerFrame"
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	portrait = ClassicPortrait.new()
	portrait.name = "Portrait"
	portrait.position = Vector2.ZERO
	portrait.size = Vector2(PORTRAIT, PORTRAIT)
	_row = HBoxContainer.new()
	_row.name = "Status"
	_row.position = ICONS_AT
	_row.add_theme_constant_override("separation", 4)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	add_child(portrait)            # (over the plate's left end)
	for s: Array in STATUSES:
		var ic := StatusIcon.new()
		ic.id = String(s[0])
		ic.good = bool(s[2])
		ic.texture = hud.icon_texture(String(s[1])) if hud != null and String(s[1]) != "" else null
		ic.visible = false
		_row.add_child(ic)
		_icons[ic.id] = ic


## The look's name (the creator's), else "You".
static func name_of(p: Node) -> String:
	var app: Variant = p.get("appearance") if p != null else null
	if app is PlayerAppearance:
		var n := String((app as PlayerAppearance).look.get("name", "")).strip_edges()
		if n != "":
			return n
	return "You"


func refresh(p: FrontierPlayer, b: SurvivalBridge) -> void:
	var mh := maxf(float(p.max_health), 1.0)
	health_frac = clampf(p.health / mh, 0.0, 1.0)
	bleed_frac = clampf((p.health + (p.wounds.pool if p.wounds else 0.0)) / mh, 0.0, 1.0)
	cap_frac = clampf(1.0 - (b.health_cap() if b else mh) / mh, 0.0, 1.0)
	var t := "%d / %d" % [int(ceil(p.health)), int(mh)] if not p.is_dead else "Dead"
	if t != health_text:
		health_text = t
		queue_redraw()
	if _last_health >= 0.0 and p.health < _last_health - 0.5:
		portrait.hurt = 1.0
	_last_health = p.health
	var c := SwayCaster.of(p)
	var shown := c != null
	var m := c.motes if c else 0
	var bm := c.belt_max if c else 0
	if shown != motes_shown or m != motes or bm != belt_max:
		motes_shown = shown
		motes = m
		belt_max = bm
		queue_redraw()
	var nm := name_of(p)
	if nm != display_name:
		display_name = nm
		queue_redraw()


func _process(delta: float) -> void:
	var was := Vector2(_shown_h, _shown_b)
	_shown_h = move_toward(_shown_h, health_frac, delta * 1.6)
	_shown_b = move_toward(_shown_b, bleed_frac, delta * 1.6)
	if was != Vector2(_shown_h, _shown_b):
		queue_redraw()
	if portrait.hurt > 0.0:
		portrait.hurt = maxf(0.0, portrait.hurt - delta / HURT_FADE)
		portrait.queue_redraw()


func _draw() -> void:
	ClassicSkin.panel(self, PLATE)
	ClassicSkin.text(self, NAME_AT, display_name, 17, ClassicSkin.INK, HEALTH_BAR.size.x)
	ClassicSkin.bar(self, HEALTH_BAR, _shown_h, ClassicSkin.HEALTH, health_text, _shown_b, ClassicSkin.HEALTH_LOST, cap_frac, 12)
	if motes_shown:
		_draw_motes(MOTES_BAR)
	else:
		ClassicSkin.bar(self, MOTES_BAR, 0.0, ClassicSkin.MOTES)


## The motes: the gold bar in a segment a mote, the empty ones the dark track.
func _draw_motes(r: Rect2) -> void:
	var n := maxi(belt_max, 1)
	ClassicSkin.bar(self, r, float(motes) / float(n), ClassicSkin.MOTES)
	for i in range(1, n):
		var x := r.position.x + r.size.x * float(i) / float(n)
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.05, 0.035, 0.02, 0.95), 2.0)


## The icons from the body's state (see the header).
func refresh_status(p: FrontierPlayer, b: SurvivalBridge) -> void:
	var core: SurvivalCore = b.core if b != null else null
	var st: Dictionary = core.need_stages() if core != null else {}
	# well rested: the sleep's boost, its hours left
	var left := b.rested_hours_left() if b != null else 0.0
	_show("rested", left > 0.0, 0, "Well rested\n%d h left: you heal and learn quicker" % maxi(ceili(left - 0.01), 1),
			"%dh" % maxi(ceili(left - 0.01), 1))
	# merry (nothing past merry is ever shown: Vices.shown_drink_stage)
	var v: Vices = b.vices if b != null else null
	_show("merry", v != null and core != null and v.shown_drink_stage() == "merry", 0,
			"Merry\nA little bolder; no well-rested boost while it lasts")
	# the torch in the hand: its burn left
	var t: PlayerTorch = p.torch
	var held: TorchState = t.held if t else null
	if held != null:
		var s := int(ceil(held.burn_left))
		var n := t.count()
		_show("torch", true, 0, "Torch%s\n%d:%02d of burning left%s" % ["" if held.lit else " (out)", s / 60, s % 60,
				"  ·  ×%d spare" % n if n > 0 else ""], "%d:%02d" % [s / 60, s % 60])
	else:
		var n := t.count() if t else 0               # (none in the hand: the spares, as the minimal HUD's "Torches ×3  (T)")
		_show("torch", n > 0, 0, "Torches ×%d\nT: take one out and light it" % n, "×%d" % n)
	# bleeding: the wound's pool still draining (PlayerWounds)
	_show("bleeding", p.wounds != null and p.wounds.bleeding(), 2, "Bleeding\nRest (Z) or dress the wound")
	# a lasting harm (LastingConditions, LastingChill)
	var harms := PackedStringArray()
	var effects := PackedStringArray()
	if b != null and b.lasting != null and core != null:
		for id: String in b.lasting.active():
			var d: Dictionary = LastingConditions.DEFS.get(id, {})
			harms.append(String(d.get("name", id.capitalize())))
			effects.append(String(d.get("effect", "")))
	if b != null and b.chill != null and core != null and b.chill.is_on():
		harms.append("Chilled to the bone")
		effects.append("heal no higher than %d%%" % roundi(LastingChill.HEALTH_CAP * 100.0))
	_show("wounded", not harms.is_empty(), 2, "%s\n%s" % [", ".join(harms), "; ".join(effects)])
	# the needs: amber once they bite, red as they worsen
	_need("cold", st, "need.warmth", core, "Find a fire, a shelter or warmer clothes")
	_need("wet", st, "need.wetness", core, "Dry off by a fire or under a roof")
	_need("hungry", st, "need.food", core, "Eat something (V)")
	_need("thirsty", st, "need.thirst", core, "Drink something (hold U)")
	_need("tired", st, "need.rest", core, "Rest (Z) or sleep (hold Z)")


func _need(id: String, st: Dictionary, need: String, core: SurvivalCore, how: String) -> void:
	if core == null or not st.has(need):
		_show(id, false)
		return
	var stage := String(st[need])
	var sev := SurvivalNeeds.stage_severity(core, need, stage)
	_show(id, sev >= 1, 1 if sev == 1 else 2, "%s\n%s" % [stage.capitalize(), how])


func _show(id: String, on: bool, sev := 0, tip := "", dur := "") -> void:
	var ic: StatusIcon = _icons.get(id)
	if ic == null:
		return
	if ic.visible != on:
		ic.visible = on
	if not on:
		return
	if ic.tooltip_text != tip:
		ic.tooltip_text = tip
	if ic.sev != sev or ic.duration != dur:
		ic.sev = sev
		ic.duration = dur
		ic.queue_redraw()


## The status icons shown, in their order.
func status_ids() -> Array[String]:
	var out: Array[String] = []
	for c in _row.get_children():
		if (c as Control).visible:
			out.append(String((c as StatusIcon).id))
	return out


func status(id: String) -> StatusIcon:
	return _icons.get(id)


## One status icon: a small sunk square, its picture, a rim in green (good), amber or red (harm), the time left under it.
class StatusIcon:
	extends Control
	var id := ""
	var good := false
	var sev := 0
	var duration := ""
	var texture: Texture2D

	func _init() -> void:
		custom_minimum_size = Vector2(ClassicPlayerFrame.ICON, ClassicPlayerFrame.ICON + 12.0)
		mouse_filter = Control.MOUSE_FILTER_PASS      # (its tooltip with the cursor free; a click goes on through)

	func rim() -> Color:
		if good:
			return ClassicSkin.BUFF
		return ClassicSkin.WARN if sev <= 1 else ClassicSkin.BAD

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(ClassicPlayerFrame.ICON, ClassicPlayerFrame.ICON))
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.6))
		ClassicSkin.socket(self, r)
		var col := rim()
		if texture != null:
			ClassicSkin.fit_texture(self, texture, r, 3.0, Color(1.0, 0.95, 0.85) if good else col.lerp(Color.WHITE, 0.35))
		elif id == "bleeding":
			drop(self, r.get_center() + Vector2(0, 1), 7.0, col.lerp(Color(0.85, 0.08, 0.05), 0.6))
		draw_rect(r, col, false, 1.5)
		if duration != "":
			ClassicSkin.text_centred(self, Rect2(0, ClassicPlayerFrame.ICON, ClassicPlayerFrame.ICON, 12.0), duration, 11, ClassicSkin.TEXT)

	## A drop of blood (the bleeding's glyph).
	static func drop(ci: CanvasItem, c: Vector2, k: float, col: Color) -> void:
		var pts := PackedVector2Array()
		pts.append(c + Vector2(0, -k * 1.15))
		for i in 13:
			var a := -PI * 0.15 + PI * 1.3 * float(i) / 12.0
			pts.append(c + Vector2(cos(a), sin(a)) * k * 0.62 + Vector2(0, k * 0.28))
		ci.draw_colored_polygon(pts, col)
		ci.draw_circle(c + Vector2(-k * 0.2, k * 0.15), k * 0.14, Color(1, 0.8, 0.75, 0.55))
