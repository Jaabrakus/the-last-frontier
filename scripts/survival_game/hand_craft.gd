class_name HandCraft
extends RefCounted
## What is made with the hands alone (user 2026-10-01: "there's no craft menu for the items that do not need a crafting table"): cord
## from bark, a rope belt and sling, a bow drill, pine-knot torches (CampStation.HAND). The same recipes the knapping stone makes
## (CampStation.STONE), worked from the character screen's Craft tab by a station that is only the player's own hands: a CampStation
## of kind "hand" riding on the player, so the work, the practice and the results are the stations' own.


## The player's hands (made once, a child of the player).
static func of(player: Node) -> CampStation:
	var h := player.get_node_or_null("HandCraft") as CampStation
	if h == null:
		h = CampStation.new()
		h.name = "HandCraft"
		h.kind = "hand"
		player.add_child(h)
	return h


## The rows for the tab: {id, text, ok, detail}.
static func rows(player: Node) -> Array:
	return of(player).menu_rows(player)


## Starts making `id` (the screen is closed first: the work is done in the world, kneeling). False when it cannot be made now.
static func make(player: Node, id: String) -> bool:
	return of(player).make(player, id)
