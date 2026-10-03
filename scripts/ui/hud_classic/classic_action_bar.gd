class_name ClassicActionBar
extends Control
## The classic HUD's action bar, bottom centre (ClassicFrames): the hotbar's nine slots (Hotbar) as square buttons sunk in a
## leather bar with a brass medallion at each end (a compass star on it, the surveyor's card of the spell circle), each with
## its key's number in its corner, empty ones an empty socket. The one in the hands has a gold rim; a readied spell glows
## round its button in its art's colour (SwayMoves.art_color), and the Sway's lock fills over that button as it fills
## (SwayCaster.fill: a sweep clockwise from the top; full, the whole button lit; a hold, its rim bright). A spell's mode is
## the HUD's own corner badge (FrontierHUD.draw_mode_mark). The weapon's ammo and state, or the readied spell's line, is
## the one small line under the bar (FrontierHUD's: the same text). With the cursor free a button is clicked to take its
## slot in hand (Hotbar.select), and its tooltip names what is on it.
##   refresh(player, hud)   ten times a second (ClassicFrames); a button animates only while it glows or a lock is on
## Read by the test: buttons (ActionButton: kind, on, glow, lock), line.

const BTN := 42.0
const GAP := 4.0
const PAD := 6.0
const CAP_R := 24.0
const BAR_H := BTN + PAD * 2.0
const LINE_H := 20.0

var buttons: Array[ActionButton] = []
var line := ""
var plate := Rect2()
var _icons: ItemIcons


func _init() -> void:
	name = "ActionBar"
	var inner := BTN * Hotbar.SLOTS + GAP * (Hotbar.SLOTS - 1)
	var w := inner + PAD * 2.0 + CAP_R * 2.0
	custom_minimum_size = Vector2(w, 6.0 + BAR_H + LINE_H + 4.0)
	plate = Rect2(CAP_R, 6.0, inner + PAD * 2.0, BAR_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	for i in Hotbar.SLOTS:
		var b := ActionButton.new()
		b.index = i
		b.bar = self
		b.position = plate.position + Vector2(PAD + float(i) * (BTN + GAP), PAD)
		b.size = Vector2(BTN, BTN)
		b.tooltip_text = "Empty  (%d)\nTab: drag something here" % (i + 1)
		add_child(b)
		buttons.append(b)


func refresh(p: FrontierPlayer, hud: FrontierHUD) -> void:
	if _icons == null:
		_icons = ItemIcons.shared(get_tree())
	var hb: Hotbar = p.hotbar
	var sel := hb.selected() if hb != null else -1
	var c := SwayCaster.of(p)
	var locking := c != null and c.state != SwayCaster.State.IDLE
	for i in buttons.size():
		var b := buttons[i]
		var kind := hb.icon_kind(i) if hb != null else ""
		if kind != b.kind or (kind != "" and b.texture == null and not b.circle):
			var named := kind != b.kind
			b.set_kind(kind, _texture_for(kind), p)
			if named:
				b.tooltip_text = ("%s  (%d)" % [hb.label(i), i + 1]) if kind != "" else "Empty  (%d)\nTab: drag something here" % (i + 1)
		b.set_on(i == sel and kind != "")
		var spell := kind.trim_prefix("spell:") if kind.begins_with("spell:") else ""
		b.set_glow(spell != "" and hb != null and hb.spell == spell, spell)
		var lk := -1.0
		var st := 0
		if locking and spell != "" and c.move == spell:
			lk = c.fill
			st = c.state
		b.set_lock(lk, st)
		var md := ""
		if spell != "" and c != null and c.has_method(&"mode_of"):
			md = c.mode_of(spell)
		if md != b.mode:
			b.mode = md
			b.queue_redraw()
	var l := hud._ammo.text if hud != null and hud._ammo != null and hud._ammo.visible else ""
	if l != line:
		line = l
		queue_redraw()


func _texture_for(kind: String) -> Texture2D:
	if kind == "":
		return null
	if kind.begins_with("spell:"):
		return FrontierHUD.spell_texture(kind.trim_prefix("spell:"), get_tree())
	return _icons.get_icon(kind) if _icons != null else null


func _draw() -> void:
	ClassicSkin.panel(self, plate, false)
	# the buttons' row sunk a little deeper
	var row := Rect2(plate.position + Vector2(PAD - 3.0, PAD - 3.0), Vector2(plate.size.x - PAD * 2.0 + 6.0, BTN + 6.0))
	draw_rect(row, Color(0, 0, 0, 0.22))
	for cx: float in [CAP_R, size.x - CAP_R]:
		medallion(self, Vector2(cx, plate.get_center().y), CAP_R - 1.0)
	if line != "":
		ClassicSkin.text_centred(self, Rect2(0, plate.end.y + 2.0, size.x, LINE_H), line, 15, ClassicSkin.TEXT)


## An end of the bar: a leather disc in a brass ring, a four-pointed compass star on it in brass.
static func medallion(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(0.5, 2.0), r + 2.0, Color(0, 0, 0, 0.4))
	ci.draw_circle(c, r, Color(0.13, 0.09, 0.06))
	ci.draw_texture_rect(ClassicSkin.grain(), Rect2(c - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), true, Color(1, 1, 1, 0.6))
	ClassicSkin.ring(ci, c, r - 2.0, 4.0)
	for pass_i in 2:
		var k := r * (0.62 if pass_i == 0 else 0.44)
		var w := k * 0.26
		var rot := 0.0 if pass_i == 0 else PI * 0.25
		var pts := PackedVector2Array()
		for j in 8:
			var a := rot + TAU * float(j) / 8.0 - PI * 0.5
			var rr := k if j % 2 == 0 else w
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		var col := ClassicSkin.BRASS if pass_i == 0 else ClassicSkin.BRASS_LO.lerp(ClassicSkin.BRASS, 0.55)
		ci.draw_colored_polygon(pts, col)
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.45), 1.0, true)
	ci.draw_circle(c, r * 0.12, ClassicSkin.BRASS_HI)


## One slot's button.
class ActionButton:
	extends Control
	var index := 0
	var bar: ClassicActionBar
	var kind := ""
	var texture: Texture2D
	var tint := Color.WHITE
	var circle := false                ## a spell with no picture: its circle drawn
	var on := false
	var glow := false
	var art_col := Color(0.8, 0.9, 1.0)
	var lock := -1.0
	var lock_state := 0
	var mode := ""
	var _t := 0.0
	var _hover := false
	var _player: FrontierPlayer

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func set_kind(k: String, tex: Texture2D, p: FrontierPlayer) -> void:
		kind = k
		_player = p
		texture = tex
		var spell := k.begins_with("spell:")
		circle = spell and tex == null
		tint = ClassicSkin.GOLD if spell and tex != null and tex.resource_path.ends_with(".svg") else Color.WHITE
		queue_redraw()

	func set_on(v: bool) -> void:
		if v != on:
			on = v
			queue_redraw()

	func set_glow(v: bool, spell: String) -> void:
		if v != glow:
			glow = v
			if v:
				art_col = SwayMoves.art_color(String(SwayMoves.move(spell).get("art", "")))
			queue_redraw()
		set_process(glow or lock >= 0.0)

	func set_lock(v: float, st: int) -> void:
		if absf(v - lock) > 0.001 or st != lock_state:
			lock = v
			lock_state = st
			queue_redraw()
		set_process(glow or lock >= 0.0)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			var hb: Hotbar = _player.hotbar if _player != null and is_instance_valid(_player) else null
			if hb != null:
				hb.select(index)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		ClassicSkin.socket(self, r)
		var empty := kind == ""
		if not empty and not kind.begins_with("spell:"):
			parchment(self, r.grow(-2.0))       # (the pack's ink drawings read on paper, not on the dark)
		if not empty:
			if circle:
				FrontierHUD.draw_spell_circle(self, r.grow(-5.0))
			elif texture != null:
				ClassicSkin.fit_texture(self, texture, r, 4.0, tint)
		# the lock filling over the button
		if lock >= 0.0:
			var full := lock_state == SwayCaster.State.FULL or lock_state == SwayCaster.State.HOLDING
			var lit := art_col.lerp(Color.WHITE, 0.3)
			if full:
				var k := 0.35 + 0.15 * sin(_t * 12.0)
				draw_rect(r.grow(-1.0), Color(lit.r, lit.g, lit.b, k))
			elif lock > 0.0:
				sweep(self, r.grow(-1.0), lock, Color(lit.r, lit.g, lit.b, 0.45), Color(1, 1, 1, 0.95))
		if mode != "":
			FrontierHUD.draw_mode_mark(self, Rect2(Vector2(size.x - 18.0, size.y - 18.0), Vector2(15, 15)), mode, true)
		# the rims: in the hands gold, a readied spell's glow round it, the cursor on it brass
		if on:
			draw_rect(r.grow(-1.0), ClassicSkin.GOLD, false, 2.0)
			draw_rect(r.grow(-3.0), Color(ClassicSkin.GOLD.r, ClassicSkin.GOLD.g, ClassicSkin.GOLD.b, 0.3), false, 2.0)
		if glow:
			var pulse := 0.65 + 0.35 * sin(_t * 4.5)
			for k in 3:
				draw_rect(r.grow(1.0 + k * 1.6), Color(art_col.r, art_col.g, art_col.b, (0.62 - k * 0.18) * pulse), false, 1.6)
		if _hover:
			draw_rect(r.grow(-0.5), Color(ClassicSkin.BRASS_HI.r, ClassicSkin.BRASS_HI.g, ClassicSkin.BRASS_HI.b, 0.7), false, 1.0)
		var num_col := ClassicSkin.GOLD if on else (ClassicSkin.TEXT if not empty else Color(ClassicSkin.DIM.r, ClassicSkin.DIM.g, ClassicSkin.DIM.b, 0.6))
		ClassicSkin.text(self, Vector2(4, 13), str(index + 1), 12, num_col)

	## A warm paper bed for an item's ink drawing, darker toward its edges.
	static func parchment(ci: CanvasItem, r: Rect2) -> void:
		ci.draw_rect(r, Color(0.6, 0.51, 0.37))
		ci.draw_rect(r.grow(-r.size.x * 0.18), Color(0.7, 0.61, 0.45, 0.6))
		ci.draw_texture_rect(ClassicSkin.grain(), r, true, Color(1, 1, 1, 0.35))
		for k in 3:
			ci.draw_rect(r.grow(-0.5 - k), Color(0.2, 0.13, 0.07, 0.4 - k * 0.12), false, 1.0)

	## The lock's sweep: `k` of the square `r` filled clockwise from the top, its leading edge a bright line.
	static func sweep(ci: CanvasItem, r: Rect2, k: float, fill: Color, edge_col: Color) -> void:
		var c := r.get_center()
		var h := r.size * 0.5
		var pts := PackedVector2Array([c])
		var steps := maxi(2, ceili(k * 36.0))
		var last := c
		for i in steps + 1:
			var a := -PI * 0.5 + TAU * k * float(i) / float(steps)
			var d := Vector2(cos(a), sin(a))
			var s := minf(h.x / maxf(absf(d.x), 0.0001), h.y / maxf(absf(d.y), 0.0001))
			last = c + d * s
			pts.append(last)
		if pts.size() >= 3:
			ci.draw_colored_polygon(pts, fill)
		ci.draw_line(c, last, edge_col, 1.5, true)
		ci.draw_line(c, c + Vector2(0, -h.y), Color(edge_col.r, edge_col.g, edge_col.b, 0.4), 1.0, true)
