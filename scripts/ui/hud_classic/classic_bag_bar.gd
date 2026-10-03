class_name ClassicBagBar
extends Control
## The classic HUD's bag bar, bottom right (ClassicFrames): four bag slots and the pack, right-most and larger, its count of
## things in its corner. For now every one opens the character screen's pack (InventoryScreen's Gear tab, as Tab does);
## the bag slots are empty sockets for the bags to come (their tooltip says so).
##   refresh(player)   the pack's count and its tooltip (once a second)
## Read by the test: buttons (ClassicMicroMenu.MicroButton; press() does what a click does), pack.

const BAGS := 4
const BAG := Vector2(32, 32)
const PACK := Vector2(40, 40)
const GAP := 3.0

var frames: ClassicFrames
var buttons: Array = []
var pack: ClassicMicroMenu.MicroButton


func _init() -> void:
	name = "BagBar"
	custom_minimum_size = Vector2(BAG.x * BAGS + GAP * BAGS + PACK.x, PACK.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	for i in BAGS + 1:
		var b := ClassicMicroMenu.MicroButton.new()
		var is_pack := i == BAGS
		b.id = "pack" if is_pack else "bag_%d" % (BAGS - i)
		b.glyph = "pack" if is_pack else "bag"
		b.later = not is_pack
		b.size = PACK if is_pack else BAG
		b.position = Vector2(float(i) * (BAG.x + GAP), 0.0 if is_pack else PACK.y - BAG.y)
		b.tooltip_text = "Pack  (Tab)" if is_pack else "Bag slot  (empty)\nBags come later: the pack holds everything for now"
		b.action = func() -> void: frames.open("gear")
		add_child(b)
		buttons.append(b)
		if is_pack:
			pack = b


func refresh(p: FrontierPlayer) -> void:
	var n := 0
	for e: Variant in p.inventory_pack:
		if e is Dictionary:
			n += maxi(int((e as Dictionary).get("count", 1)), 0)
	var tip := "Pack  (Tab)\n%d thing%s in it" % [n, "" if n == 1 else "s"]
	var c := str(n) if n > 0 else ""
	if tip != pack.tooltip_text or c != pack.count:
		pack.tooltip_text = tip
		pack.count = c
		pack.queue_redraw()
