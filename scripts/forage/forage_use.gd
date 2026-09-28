class_name ForageUse
extends Node
## Using a gathered herb from the pack (the inventory screen: right-click or double-click it): plantain, bruised leaves
## laid on a wound, heal it a little over time (forage.json plantain.use: heal, over_s); yarrow packed into a wound
## closes most of its bleeding at once (yarrow.use: `stanch`, the share of the blood still to lose: PlayerWounds.stanch)
## and heals little.
##
## A poultice on the player is this node (a child named "Poultice"), healing until it is spent; one at a time.

var player: Node
var left := 0.0
var rate := 0.0


## Can `item` be used from the pack?
static func can_use(item: String) -> bool:
	return not _use_of(item).is_empty()


static func _use_of(item: String) -> Dictionary:
	var plants: Dictionary = ForageField.load_data().get("plants", {})
	for k: String in plants:
		if String(plants[k].get("item", "")) == item and plants[k].has("use"):
			return plants[k].use
	return {}


## Uses one `item` of `inv` on `p` (the screen's copy of the pack, written back when it closes). Returns the line
## to show.
static func use(p: Node, item: String, inv: InventoryState) -> String:
	var u := _use_of(item)
	if u.is_empty() or p == null:
		return ""
	if inv.pack_count(item) <= 0:
		return "No %s in the pack." % InventoryState.name_of(item).to_lower()
	var hp := float(p.get("health"))
	var mx := float(p.get("max_health"))
	# a bleeding wound (PlayerWounds): the poultice stanches it
	var w: Variant = p.get("wounds")
	var bleeding: bool = w is PlayerWounds and (w as PlayerWounds).bleeding()
	if hp >= mx - 0.5 and not bleeding:
		return "You have no wound to dress."
	if p.get_node_or_null("Poultice") != null and not bleeding:
		return "A poultice is on the wound already."
	inv.take(item, 1)
	if w is PlayerWounds:
		# on the wound whether it still bleeds or not: a dressed wound does not fester (LastingConditions)
		(w as PlayerWounds).dress(1.0)
		if u.has("stanch"):
			(w as PlayerWounds).stanch(float(u.stanch))
	if bleeding:
		if p.get_node_or_null("Poultice") != null:
			return "%s: the bleeding stops." % String(u.get("text", "A poultice"))
	# well rested (SurvivalBridge): the poultice heals more, and as fast
	var k := SurvivalBridge.heal_item_mult_in(p.get_tree())
	var pu := ForageUse.new()
	pu.name = "Poultice"
	pu.player = p
	pu.left = float(u.get("heal", 15.0)) * k
	pu.rate = pu.left / maxf(float(u.get("over_s", 20.0)), 0.1)
	p.add_child(pu)
	return "%s: %sit will heal %s over the next %d seconds." % [String(u.get("text", "A poultice")),
			"the bleeding stops, and " if bleeding else "", "well (you are rested)" if k > 1.0 else "a little",
			int(u.get("over_s", 20.0))]


func _physics_process(dt: float) -> void:
	if player == null or not is_instance_valid(player) or player.get("is_dead") == true or left <= 0.0:
		queue_free()
		return
	var h := minf(rate * dt, left)
	left -= h
	player.set("health", minf(float(player.get("health")) + h, float(player.get("max_health"))))
