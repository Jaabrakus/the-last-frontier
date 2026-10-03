class_name ClassicTargetFrame
extends Control
## The classic HUD's target frame, beside the player frame (ClassicFrames picks the target: what the Sway's lock is on,
## else what the crosshair is on, else what E would use, else what the player last hit): the player frame turned round. A
## leather plate with the target's name on a strip in its stance's colour (hostile red, neutral amber, friendly green), its
## health bar ("64%"), what it is and how far under it; at the right the round frame with its kind's mark in the brass ring (a
## person's head and shoulders, an animal's paw, a horseshoe). Hidden when there is nothing; it fades in and out.
##   NpcFighter      its contact's name or its faction's ("French marine"); hostile to the player: red; on its knees: amber
##                   ("Yielded"); dead: "Dead" and an empty bar
##   WildAnimal      its species' name ("Wolf"); a predator red, game amber; its health
##   StoryWalker     its name (or its contact's), friendly; never hurt: a full bar
##   StoryContact    its name, friendly; "Talk  (E)"; no bar
##   Horse           "Horse", friendly; a full bar
##   describe(node) -> {name, caption, stance, kind, health (0..1, -1 no bar), dead}; subject_of(collider) the one of these
##   a collider belongs to (its first such parent), null none.
## Read by the test: subject, info, health_frac.

const W := 304.0
const H := 88.0
const PLATE := Rect2(0, 12, 258, 66)
const STRIP := Rect2(6, 16, 204, 20)
const HEALTH_BAR := Rect2(12, 40, 196, 15)
const CAPTION_AT := Vector2(12, 71)
const DISC_C := Vector2(260, 44)
const DISC_R := 40.0
const FADE_S := 0.15

var subject: Node = null
var info := {}
var health_frac := 0.0
var distance := -1.0
var _shown_h := 0.0
var _want := false


func _init() -> void:
	name = "TargetFrame"
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false


## The one of the frame's kinds `n` belongs to (it or a parent), null none.
static func subject_of(n: Node) -> Node:
	var i := 0
	while n != null and i < 8:
		if n is NpcFighter or n is WildAnimal or n is StoryWalker or n is Horse or n is StoryContact:
			return n
		n = n.get_parent()
		i += 1
	return null


## A contact on a person (StoryContact.at_person): its name for the person.
static func _contact_name(n: Node) -> String:
	for c in n.get_children():
		if c is StoryContact and (c as StoryContact).who != "":
			return (c as StoryContact).who
	return ""


static func describe(n: Node) -> Dictionary:
	var d := {"name": "", "caption": "", "stance": "neutral", "kind": "person", "health": -1.0, "dead": false}
	if n == null or not is_instance_valid(n):
		return d
	if n is NpcFighter:
		var f := n as NpcFighter
		var who := _contact_name(f)
		d.name = who if who != "" else f.label.capitalize() if f.label == f.label.to_lower() else f.label
		d.dead = f.is_dead()
		d.health = 0.0 if d.dead else clampf(f.health / maxf(f.health_max, 1.0), 0.0, 1.0)
		var hostile := NpcFactions.hostile(f.faction, NpcFactions.PLAYER)
		d.stance = "neutral" if f.surrendered() else ("hostile" if hostile else "friendly")
		d.caption = "Dead" if d.dead else ("Yielded" if f.surrendered() else (f.label if who != "" else ("Hostile" if hostile else "Friendly")))
	elif n is WildAnimal:
		var a := n as WildAnimal
		d.kind = "animal"
		d.name = String(a.data.get("name", a.species.replace("_", " "))).capitalize()
		d.dead = a.is_dead()
		d.health = 0.0 if d.dead else clampf(a.health / maxf(float(a.data.get("health", 100.0)), 1.0), 0.0, 1.0)
		var predator := String(a.data.get("kind", "")) == "predator"
		d.stance = "hostile" if predator and not d.dead else "neutral"
		d.caption = "Dead" if d.dead else ("Predator" if predator else "Game")
	elif n is StoryWalker:
		var w := n as StoryWalker
		var who := _contact_name(w)
		d.name = who if who != "" else (w.label if w.label != "" else "Someone")
		d.stance = "friendly"
		d.health = 1.0
		d.caption = "Companion"
	elif n is StoryContact:
		var c := n as StoryContact
		d.name = c.who
		d.stance = "friendly"
		d.caption = "Talk  (E)"
	elif n is Horse:
		d.kind = "horse"
		d.name = "Horse"
		d.stance = "friendly"
		d.health = 1.0
		d.caption = "Saddle horse"
	return d


## The target now (null: hidden, after a fade).
func show_target(n: Node, dist := -1.0) -> void:
	if n != null and not is_instance_valid(n):
		n = null
	_want = n != null
	distance = dist
	if n == null:
		return
	var d := describe(n)
	if n != subject:
		subject = n
		_shown_h = float(d.health)
	health_frac = maxf(float(d.health), 0.0)
	if str(d) != str(info):
		info = d
		queue_redraw()
	visible = true


func _process(delta: float) -> void:
	var a := move_toward(modulate.a, 1.0 if _want else 0.0, delta / FADE_S)
	if a != modulate.a:
		modulate.a = a
	if a <= 0.0 and visible and not _want:
		visible = false
		subject = null
		info = {}
	var h := move_toward(_shown_h, health_frac, delta * 1.6)
	if h != _shown_h:
		_shown_h = h
		queue_redraw()


func _draw() -> void:
	if info.is_empty():
		return
	ClassicSkin.panel(self, PLATE)
	var col := ClassicSkin.stance_color(String(info.stance))
	draw_rect(STRIP, Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, 0.85))
	draw_rect(Rect2(STRIP.position, Vector2(STRIP.size.x, STRIP.size.y * 0.45)), Color(1, 1, 1, 0.08))
	draw_rect(STRIP, Color(0, 0, 0, 0.5), false, 1.0)
	ClassicSkin.text(self, STRIP.position + Vector2(6, 15), String(info.name), 16, ClassicSkin.INK, STRIP.size.x - 10.0)
	var hv := float(info.health)
	if hv >= 0.0:
		var dead := bool(info.dead)
		ClassicSkin.bar(self, HEALTH_BAR, _shown_h, ClassicSkin.HEALTH if not dead else Color(0.4, 0.38, 0.35),
				"Dead" if dead else "%d%%" % roundi(hv * 100.0), -1.0, ClassicSkin.HEALTH_LOST, 0.0, 12)
	var cap := String(info.caption)
	if distance >= 0.0:
		cap += ("  ·  " if cap != "" else "") + "%d m" % roundi(distance)
	ClassicSkin.text(self, CAPTION_AT if hv >= 0.0 else CAPTION_AT - Vector2(0, 22), cap, 13, ClassicSkin.DIM, 200.0)
	# the round frame: the kind's mark
	draw_circle(DISC_C + Vector2(1, 2), DISC_R - 1.0, Color(0, 0, 0, 0.4))
	draw_circle(DISC_C, DISC_R - 4.0, Color(0.24, 0.17, 0.11))
	draw_circle(DISC_C + Vector2(-8, -10), DISC_R * 0.6, Color(0.34, 0.25, 0.16, 0.55))
	var ink := col.lerp(Color(0.95, 0.88, 0.72), 0.25) if not bool(info.dead) else Color(0.45, 0.42, 0.38)
	ink.a = 0.9
	match String(info.kind):
		"animal":
			paw(self, DISC_C, DISC_R * 0.5, ink)
		"horse":
			horseshoe(self, DISC_C, DISC_R * 0.46, ink)
		_:
			bust(self, DISC_C, DISC_R - 5.0, ink)
	draw_arc(DISC_C, DISC_R - 6.5, 0.0, TAU, 48, Color(0, 0, 0, 0.35), 4.0, true)
	ClassicSkin.ring(self, DISC_C, DISC_R - 4.0, 5.0)


## A head and shoulders filling the disc of radius `rad`.
static func bust(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(0, -rad * 0.2), rad * 0.3, col)
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * float(i) / 16.0
		pts.append(c + Vector2(cos(a) * rad * 0.58, rad * 0.74 + sin(a) * rad * 0.5))
	ci.draw_colored_polygon(pts, col)


## An animal's paw: the pad and four toes.
static func paw(ci: CanvasItem, c: Vector2, k: float, col: Color) -> void:
	var pad := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pad.append(c + Vector2(cos(a) * k * 0.62, sin(a) * k * 0.48 + k * 0.38))
	ci.draw_colored_polygon(pad, col)
	for t: Vector2 in [Vector2(-0.78, -0.18), Vector2(-0.3, -0.62), Vector2(0.3, -0.62), Vector2(0.78, -0.18)]:
		ci.draw_circle(c + t * k, k * 0.24, col)


## A horseshoe, its heels down, the nail holes dark.
static func horseshoe(ci: CanvasItem, c: Vector2, k: float, col: Color) -> void:
	ci.draw_arc(c, k * 0.8, PI * 0.82, PI * 2.18, 28, col, k * 0.42, true)
	for i in 6:
		var a := PI * 0.95 + PI * 1.1 * float(i) / 5.0
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * k * 0.8, k * 0.06, Color(0.1, 0.07, 0.05, 0.9))
