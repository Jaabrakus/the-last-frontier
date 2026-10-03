class_name ClassicMicroMenu
extends Control
## The classic HUD's micro menu, bottom right over the bag bar (ClassicFrames): a row of small leather buttons, each with
## its own drawn mark, that open the game's screens with the cursor free (Esc frees it), as their keys do:
##   Character  (Tab)   the character screen's Gear tab (InventoryScreen)
##   Spells     (Tab)   the same screen: its Spells list (drag a spell onto the hotbar)
##   Skills     (K)     the character screen's Skills tab
##   Quest log          a node in group QUEST_LOG with toggle() opens it; none yet: its tooltip says it comes later
##   Map                a node in group WORLD_MAP with toggle(); none yet: later
##   Settings   (Esc)   the pause menu's Settings (PauseMenu)
## Read by the test: buttons (MicroButton: id, later, tooltip_text; press() does what a click does).

const QUEST_LOG := &"classic_quest_log"
const WORLD_MAP := &"classic_world_map"
const BTN := Vector2(30, 38)
const GAP := 3.0
## [id, title, key ("" none), screen ("gear", "skills", "settings", a group)].
const ENTRIES := [["character", "Character", "Tab", "gear"], ["spells", "Spells", "Tab", "gear"], ["skills", "Skills", "K", "skills"],
		["quests", "Quest log", "", "group:classic_quest_log"], ["map", "Map", "", "group:classic_world_map"],
		["settings", "Settings", "Esc", "settings"]]

var frames: ClassicFrames
var buttons: Array[MicroButton] = []


func _init() -> void:
	name = "MicroMenu"
	custom_minimum_size = Vector2(BTN.x * ENTRIES.size() + GAP * (ENTRIES.size() - 1), BTN.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	for i in ENTRIES.size():
		var e: Array = ENTRIES[i]
		var b := MicroButton.new()
		b.id = String(e[0])
		b.glyph = b.id
		b.position = Vector2(float(i) * (BTN.x + GAP), 0)
		b.size = BTN
		var screen := String(e[3])
		b.action = func() -> void: frames.open(screen)
		add_child(b)
		buttons.append(b)
	refresh()


## The tooltips, and which are still to come (once a second: a quest log or a map may come into the tree).
func refresh() -> void:
	for i in buttons.size():
		var e: Array = ENTRIES[i]
		var b := buttons[i]
		var screen := String(e[3])
		var later := screen.begins_with("group:") and not _group_has(StringName(screen.substr(6)))
		var key := String(e[2])
		var tip := String(e[1]) + ("  (%s)" % key if key != "" else "") + ("\nComing later" if later else "")
		if b.id == "spells" and not later:
			tip += "\nThe Spells list in the character screen: drag a spell onto the hotbar"
		if later != b.later or tip != b.tooltip_text:
			b.later = later
			b.tooltip_text = tip
			b.queue_redraw()


func _group_has(g: StringName) -> bool:
	var n := get_tree().get_first_node_in_group(g) if is_inside_tree() else null
	return n != null and n.has_method(&"toggle")


func button(id: String) -> MicroButton:
	for b in buttons:
		if b.id == id:
			return b
	return null


## A small leather button with a drawn mark (the micro menu's and the bag bar's).
class MicroButton:
	extends Control
	var id := ""
	var glyph := ""
	var later := false
	var action: Callable
	var count := ""                    ## a small number in the corner (the pack's things)
	var _hover := false
	var _press_t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(false)
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	## What a click does.
	func press() -> void:
		_press_t = 0.18
		set_process(true)
		queue_redraw()
		if action.is_valid():
			action.call()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			press()

	func _process(delta: float) -> void:
		_press_t = maxf(0.0, _press_t - delta)
		queue_redraw()
		if _press_t <= 0.0:
			set_process(false)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		ClassicSkin.panel(self, r, false, 0.75 if later else 1.0)
		var ink := ClassicSkin.INK if not later else Color(ClassicSkin.DIM.r, ClassicSkin.DIM.g, ClassicSkin.DIM.b, 0.65)
		if _hover and not later:
			ink = ClassicSkin.BRASS_HI
		var c := r.get_center() + (Vector2(0, 1) if _press_t > 0.0 else Vector2.ZERO)
		var k := minf(r.size.x, r.size.y) * 0.36
		ClassicMicroMenu.draw_glyph(self, glyph, c, k, ink)
		if _hover:
			ClassicSkin.edge(self, r.grow(-2.5), 1.0, 1.4)
			draw_rect(r.grow(-3.0), Color(ClassicSkin.BRASS_HI.r, ClassicSkin.BRASS_HI.g, ClassicSkin.BRASS_HI.b, 0.12))
		if _press_t > 0.0:
			draw_rect(r.grow(-3.0), Color(1, 0.9, 0.7, _press_t * 1.2))
		if count != "":
			ClassicSkin.text_right(self, Vector2(r.end.x - 4.0, r.end.y - 4.0), count, 11, ClassicSkin.INK)


## A button's mark, centred on `c`, about `k` px from the centre to its edge, in `col`.
static func draw_glyph(ci: CanvasItem, glyph: String, c: Vector2, k: float, col: Color) -> void:
	var dark := Color(0, 0, 0, 0.5 * col.a)
	match glyph:
		"character":
			ClassicTargetFrame.bust(ci, c + Vector2(0.8, 1.2), k * 1.15, dark)
			ClassicTargetFrame.bust(ci, c, k * 1.15, col)
		"spells":
			FrontierHUD.draw_spell_circle(ci, Rect2(c - Vector2(k, k), Vector2(k, k) * 2.0))
		"skills":
			# a felling axe crossed over a quill: the trades learned
			for pass_i in 2:
				var o := Vector2(0.8, 1.0) if pass_i == 0 else Vector2.ZERO
				var cc := dark if pass_i == 0 else col
				ci.draw_line(c + o + Vector2(-k * 0.75, k * 0.85), c + o + Vector2(k * 0.55, -k * 0.65), cc, 2.0, true)
				var head := PackedVector2Array([c + o + Vector2(k * 0.25, -k * 0.95), c + o + Vector2(k * 0.95, -k * 0.35),
						c + o + Vector2(k * 0.62, -k * 0.05), c + o + Vector2(k * 0.38, -k * 0.5)])
				ci.draw_colored_polygon(head, cc)
				ci.draw_line(c + o + Vector2(k * 0.8, k * 0.85), c + o + Vector2(-k * 0.55, -k * 0.75), cc, 1.4, true)
				var vane := PackedVector2Array([c + o + Vector2(-k * 0.55, -k * 0.75), c + o + Vector2(-k * 0.05, -k * 0.55),
						c + o + Vector2(k * 0.35, k * 0.2), c + o + Vector2(-k * 0.3, -k * 0.15)])
				ci.draw_colored_polygon(vane, cc)
		"quests":
			# a scroll: the sheet, its rolled ends, a few lines of hand
			for pass_i in 2:
				var o := Vector2(0.8, 1.0) if pass_i == 0 else Vector2.ZERO
				var cc := dark if pass_i == 0 else col
				var sheet := Rect2(c + o + Vector2(-k * 0.62, -k * 0.8), Vector2(k * 1.24, k * 1.6))
				ci.draw_rect(sheet, cc, false, 1.4)
				ci.draw_line(sheet.position + Vector2(-k * 0.15, 0), Vector2(sheet.end.x + k * 0.15, sheet.position.y), cc, 3.0, true)
				ci.draw_line(Vector2(sheet.position.x - k * 0.15, sheet.end.y), sheet.end + Vector2(k * 0.15, 0), cc, 3.0, true)
				for j in 3:
					var y := sheet.position.y + k * (0.45 + 0.38 * j)
					ci.draw_line(Vector2(sheet.position.x + k * 0.22, y), Vector2(sheet.end.x - k * (0.22 + 0.2 * (j % 2)), y), cc, 1.0)
		"map":
			# a folded map: three panels, a dashed way and its end
			for pass_i in 2:
				var o := Vector2(0.8, 1.0) if pass_i == 0 else Vector2.ZERO
				var cc := dark if pass_i == 0 else col
				var pts := PackedVector2Array([c + o + Vector2(-k, -k * 0.6), c + o + Vector2(-k * 0.33, -k * 0.85), c + o + Vector2(k * 0.33, -k * 0.6),
						c + o + Vector2(k, -k * 0.85), c + o + Vector2(k, k * 0.6), c + o + Vector2(k * 0.33, k * 0.85),
						c + o + Vector2(-k * 0.33, k * 0.6), c + o + Vector2(-k, k * 0.85), c + o + Vector2(-k, -k * 0.6)])
				ci.draw_polyline(pts, cc, 1.4, true)
				ci.draw_line(c + o + Vector2(-k * 0.33, -k * 0.85), c + o + Vector2(-k * 0.33, k * 0.6), cc, 1.0)
				ci.draw_line(c + o + Vector2(k * 0.33, -k * 0.6), c + o + Vector2(k * 0.33, k * 0.85), cc, 1.0)
				for j in 4:
					var a := c + o + Vector2(-k * 0.7 + j * k * 0.32, k * 0.35 - j * k * 0.18)
					ci.draw_line(a, a + Vector2(k * 0.16, -k * 0.09), cc, 1.2)
				var x := c + o + Vector2(k * 0.62, -k * 0.35)
				ci.draw_line(x - Vector2(k, k) * 0.14, x + Vector2(k, k) * 0.14, cc, 1.4)
				ci.draw_line(x + Vector2(-k, k) * 0.14, x + Vector2(k, -k) * 0.14, cc, 1.4)
		"settings":
			# a cog
			for pass_i in 2:
				var o := Vector2(0.8, 1.0) if pass_i == 0 else Vector2.ZERO
				var cc := dark if pass_i == 0 else col
				var pts := PackedVector2Array()
				for j in 32:
					var a := TAU * float(j) / 32.0
					var rr := k * (0.92 if (j / 2) % 2 == 0 else 0.68)
					pts.append(c + o + Vector2(cos(a), sin(a)) * rr)
				ci.draw_colored_polygon(pts, cc)
				ci.draw_circle(c + o, k * 0.3, Color(0.1, 0.07, 0.05, 0.95) if pass_i == 1 else dark)
		"pack":
			# the pack: its body, the flap, the straps and the buckle
			for pass_i in 2:
				var o := Vector2(0.8, 1.0) if pass_i == 0 else Vector2.ZERO
				var cc := dark if pass_i == 0 else col
				var body := Rect2(c + o + Vector2(-k * 0.75, -k * 0.45), Vector2(k * 1.5, k * 1.35))
				ci.draw_rect(body, cc)
				var flap := PackedVector2Array()
				for j in 13:
					var a := PI + PI * float(j) / 12.0
					flap.append(c + o + Vector2(cos(a) * k * 0.8, -k * 0.45 + sin(a) * k * 0.55))
				ci.draw_colored_polygon(flap, cc)
				ci.draw_arc(c + o + Vector2(0, -k * 0.95), k * 0.3, PI, TAU, 12, cc, 1.6, true)
				if pass_i == 1:
					ci.draw_line(c + Vector2(-k * 0.75, -k * 0.2), c + Vector2(k * 0.75, -k * 0.2), Color(0.1, 0.07, 0.05, 0.8), 1.4)
					ci.draw_rect(Rect2(c + Vector2(-k * 0.16, -k * 0.34), Vector2(k * 0.32, k * 0.3)), ClassicSkin.BRASS)
					ci.draw_line(c + Vector2(-k * 0.5, k * 0.25), c + Vector2(k * 0.5, k * 0.25), Color(0.1, 0.07, 0.05, 0.5), 1.0)
		"bag":
			# a drawstring pouch
			for pass_i in 2:
				var o := Vector2(0.8, 1.0) if pass_i == 0 else Vector2.ZERO
				var cc := dark if pass_i == 0 else col
				var pts := PackedVector2Array()
				for j in 17:
					var a := -PI * 0.1 + PI * 1.2 * float(j) / 16.0
					pts.append(c + o + Vector2(cos(a) * k * 0.78, k * 0.2 + sin(a) * k * 0.68))
				pts.append(c + o + Vector2(-k * 0.3, -k * 0.45))
				pts.append(c + o + Vector2(k * 0.3, -k * 0.45))
				ci.draw_colored_polygon(pts, cc)
				ci.draw_colored_polygon(PackedVector2Array([c + o + Vector2(-k * 0.3, -k * 0.45), c + o + Vector2(-k * 0.55, -k * 0.85),
						c + o + Vector2(k * 0.55, -k * 0.85), c + o + Vector2(k * 0.3, -k * 0.45)]), cc)
				if pass_i == 1:
					ci.draw_line(c + Vector2(-k * 0.34, -k * 0.45), c + Vector2(k * 0.34, -k * 0.45), Color(0.1, 0.07, 0.05, 0.85), 1.6)
		_:
			ci.draw_circle(c, k * 0.3, col)
