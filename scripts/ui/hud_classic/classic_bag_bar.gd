class_name ClassicBagBar
extends Control
## The classic HUD's bag bar, bottom right (ClassicFrames): four bag sockets and the pack (the haversack), right-most and
## larger. They read the real bags (PlayerBags; the owner 2026-10-03, "WoW-style bags"): the pack shows the haversack's
## picture and in its corner the free slots of all the bags ("+N" when things ride loose), its tooltip the haversack's
## and all the bags' free slots and the loose; a socket with a bag shows that bag's picture and its free slots, its tooltip
## the bag, its slots and what it holds; an empty socket is dimmed. Bag 1 is the socket beside the pack (it fills after the
## haversack). A click toggles that bag's window (BagWindows; the pack the haversack's), its rim gold while open; a bag
## item dragged onto a socket is put on there (the bag there must be empty), a socket's bag dragged into a bag slot comes
## off (empty), onto another socket they change places; anything else dropped on a socket or the pack goes into that bag.
##   refresh(player)   the counts, the pictures and the tooltips (once a second; at once when the windows change)
## Read by the test: buttons (ClassicMicroMenu.MicroButton, these BagSocket; press() does what a click does), pack.

const BAGS := 4
const BAG := Vector2(32, 32)
const PACK := Vector2(40, 40)
const GAP := 3.0

var frames: ClassicFrames
var buttons: Array = []
var pack: ClassicMicroMenu.MicroButton
var _icons: ItemIcons


func _init() -> void:
	name = "BagBar"
	custom_minimum_size = Vector2(BAG.x * BAGS + GAP * BAGS + PACK.x, PACK.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	for i in BAGS + 1:
		var b := BagSocket.new()
		var is_pack := i == BAGS
		b.bar = self
		b.id = "pack" if is_pack else "bag_%d" % (BAGS - i)
		b.glyph = "pack" if is_pack else "bag"
		b.later = not is_pack
		b.size = PACK if is_pack else BAG
		b.position = Vector2(float(i) * (BAG.x + GAP), 0.0 if is_pack else PACK.y - BAG.y)
		b.tooltip_text = ("Pack  (%s)" % BagWindows.key_label()) if is_pack else "Bag %d  (empty)" % (BAGS - i)
		var s := socket_of(b)
		b.action = func() -> void: _toggle(s)
		add_child(b)
		buttons.append(b)
		if is_pack:
			pack = b


## The socket (PlayerBags: 0 is bag 1, beside the pack) of bag button `b`; -1 for the pack.
static func socket_of(b: ClassicMicroMenu.MicroButton) -> int:
	return int(b.id.trim_prefix("bag_")) - 1 if b.id.begins_with("bag_") else -1


## The bag windows (BagWindows) of the HUD these frames are on.
func windows() -> BagWindows:
	return BagWindows.of(frames.hud) if frames != null and frames.hud != null else null


func player() -> FrontierPlayer:
	return frames.player if frames != null else null


## A click: the socket's bag window (the pack: the haversack's) opened or closed; an empty socket says what it is for.
func _toggle(s: int) -> void:
	var w := windows()
	if w == null:
		if frames != null:
			frames.open("gear")              # (no bag windows: the character screen's pack, as before them)
		return
	var g := PlayerBags.find(player())
	if s >= 0 and (g == null or g.bag_kind(s + 1) == ""):
		w.error("No bag in bag %d: drag a bag here" % (s + 1))
		return
	w.toggle_bag(s + 1)
	refresh(player())


func refresh(p: FrontierPlayer) -> void:
	if p == null:
		return
	if _icons == null and is_inside_tree():
		_icons = ItemIcons.shared(get_tree())
	var g := PlayerBags.find(p)
	if g == null:
		_refresh_plain(p)
		return
	var w := windows()
	var free := g.free_total()
	var tip := "Pack  (%s)\nHaversack: %d of %d slots free\nAll bags: %d of %d slots free" % [BagWindows.key_label(), g.free_slots(0),
			g.bag_size(0), free, g.slots_total()]
	var lc := g.loose_slots()
	if lc > 0:
		tip += "\nYour bags are full: %d thing%s loose (slower%s)" % [lc, "" if lc == 1 else "s", ", no sprint" if not g.sprint_ok() else ""]
	tip += "\nClick: the haversack · %s: all the bags" % BagWindows.key_label()
	_show(pack, tip, ("+%d" % lc) if lc > 0 else str(free), false)
	(pack as BagSocket).show_bag(PlayerBags.HAVERSACK, _icon(PlayerBags.HAVERSACK), w != null and w.is_open(0), lc > 0)
	for b: ClassicMicroMenu.MicroButton in buttons:
		var s := socket_of(b)
		if s < 0:
			continue
		var k := g.bag_kind(s + 1)
		var bs := b as BagSocket
		if k == "":
			_show(b, "Bag %d  (empty)\nA bag from the pack goes in this socket: drag it here" % (s + 1), "", true)
			bs.show_bag("", null, false, false)
			continue
		var holds := PlayerBags.holds_text(k)
		_show(b, "%s  (bag %d)\n%d slots, %d free\nHolds %s\nClick: open it · drag it into a slot: take it off (empty)" % [g.bag_name(s + 1), s + 1,
				g.bag_size(s + 1), g.free_slots(s + 1), holds if not PlayerBags.is_specialty(k) else "only " + holds],
				str(g.free_slots(s + 1)), false)
		bs.show_bag(k, _icon(k), w != null and w.is_open(s + 1), false)


func _icon(k: String) -> Texture2D:
	return _icons.get_icon(k) if _icons != null else null


## No bags (another player's HUD, a test without them): the pack's count of things, as before the bags.
func _refresh_plain(p: FrontierPlayer) -> void:
	var n := 0
	for e: Variant in p.inventory_pack:
		if e is Dictionary:
			n += maxi(int((e as Dictionary).get("count", 1)), 0)
	_show(pack, "Pack  (Tab)\n%d thing%s in it" % [n, "" if n == 1 else "s"], str(n) if n > 0 else "", false)


func _show(b: ClassicMicroMenu.MicroButton, tip: String, count: String, dim: bool) -> void:
	if tip != b.tooltip_text or count != b.count or dim != b.later:
		b.tooltip_text = tip
		b.count = count
		b.later = dim
		b.queue_redraw()


## A bag socket or the pack: the micro menu's leather button, with the bag's picture on it when one is there (else its
## drawn pouch, dimmed), its free slots in the corner, a gold rim while its window is open; clicked (let go on it: a drag
## is not a click) it toggles that window; a drag source (its bag) and a drop target (BagWindows.drop_on_socket).
class BagSocket:
	extends ClassicMicroMenu.MicroButton
	var bar: ClassicBagBar
	var bag_kind := ""
	var texture: Texture2D
	var open := false
	var full := false
	var drop_state := ""
	var _down := false

	func show_bag(k: String, tex: Texture2D, is_open: bool, is_full: bool) -> void:
		if k != bag_kind or tex != texture or is_open != open or is_full != full:
			bag_kind = k
			texture = tex
			open = is_open
			full = is_full
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if mb.pressed:
			_down = true
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(mb.position):
				press()

	func _notification(what: int) -> void:
		if (what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT) and drop_state != "":
			drop_state = ""
			queue_redraw()
		if what == NOTIFICATION_DRAG_BEGIN:
			_down = false

	func _get_drag_data(_at: Vector2) -> Variant:
		var s := ClassicBagBar.socket_of(self)
		var g := PlayerBags.find(bar.player()) if bar != null else null
		if s < 0 or g == null or g.bag_kind(s + 1) == "":
			return null
		_down = false
		set_drag_preview(BagSlot.drag_preview(texture, bag_kind, 36.0))
		return BagUI.socket_payload(g, s)

	func _can_drop_data(_at: Vector2, d: Variant) -> bool:
		var g := PlayerBags.find(bar.player()) if bar != null else null
		if g == null or not (d is Dictionary) or bar.windows() == null:
			return false
		var s := ClassicBagBar.socket_of(self)
		var v := BagUI.verdict_socket(bar.player(), g, s, d) if s >= 0 else BagUI.verdict_into(bar.player(), g, 0, d)
		var st := "ok" if bool(v.ok) else "no"
		if st != drop_state:
			drop_state = st
			queue_redraw()
		return true

	func _drop_data(_at: Vector2, d: Variant) -> void:
		drop_state = ""
		queue_redraw()
		var w := bar.windows()
		var s := ClassicBagBar.socket_of(self)
		if s >= 0:
			w.drop_on_socket(d, s)
		else:
			w.drop_on_bag(d, 0)
		bar.refresh(bar.player())

	func _draw() -> void:
		if bag_kind == "" or texture == null:
			super()
		else:
			var r := Rect2(Vector2.ZERO, size)
			ClassicSkin.panel(self, r, false)
			var bed := r.grow(-3.0)
			ClassicActionBar.ActionButton.parchment(self, bed)
			ClassicSkin.fit_texture(self, texture, bed, 1.5)
			if _hover:
				draw_rect(bed, Color(ClassicSkin.BRASS_HI.r, ClassicSkin.BRASS_HI.g, ClassicSkin.BRASS_HI.b, 0.15))
			if _press_t > 0.0:
				draw_rect(bed, Color(1, 0.9, 0.7, _press_t * 1.2))
			if count != "":
				ClassicSkin.text_right(self, Vector2(r.end.x - 3.0, r.end.y - 3.0), count, 12,
						BagUI.BAD.lerp(Color.WHITE, 0.2) if full else Color.WHITE)
		var rr := Rect2(Vector2.ZERO, size)
		if open:
			draw_rect(rr.grow(-1.0), ClassicSkin.GOLD, false, 2.0)
		if drop_state == "ok":
			draw_rect(rr.grow(-1.0), BagUI.GOOD, false, 2.0)
		elif drop_state == "no":
			draw_rect(rr.grow(-1.0), BagUI.BAD, false, 2.0)
