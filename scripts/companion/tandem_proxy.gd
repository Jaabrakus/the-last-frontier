class_name TandemProxy
extends RefCounted
## The adapter that lets the spouse take part in the tandem poses (features/tandem/frontier_tandem.gd, which works on
## FrontierPlayer bodies). The Spouse body (a CharacterBody3D with Actor_B) is not one, so for the length of a session a
## FrontierPlayer nobody controls (the same kind of NPC the tandem feature makes for its own companion) stands in her
## place, dressed in her look, and the Spouse body is hidden and parked; afterwards she takes over again where the proxy
## stands. Nothing in features/tandem is changed.
##   as the LEAD (the wife, for a male player): the proxy carries its own TandemPoses controller (as the tandem
##     feature's two-pose preview does): lead.start_pose("yoga"), then the player's controller join_nearby().
##   as the PARTNER (the husband, for a woman player): the player's own controller takes him: take_partner(proxy).

const NAME := "SpouseTandem"


static func controller_of(p: Node) -> Node:
	return p.get_node_or_null("TandemPoses") if p != null and is_instance_valid(p) else null


## A stand-in body at `at`, facing `yaw`, dressed in `look`, a child of `parent` (the player's parent, where the tandem
## feature looks for partners).
static func make(parent: Node, look: Dictionary, at: Vector3, yaw: float) -> FrontierPlayer:
	var p := FrontierPlayer.new()
	p.name = NAME
	p.is_local = false
	p.controls = PlayerControls.new(false)
	p.demo_horse = false
	p.demo_wheelbarrow = false
	p.show_gear = false
	p.use_appearance = false
	parent.add_child(p)
	dress(p, look)
	p.toggle_hands_free()
	p.global_position = at + Vector3.UP * 0.05
	p.rotation.y = yaw
	p.yaw = yaw
	return p


## The game's own body (body v4) with `look`, as the tandem feature dresses its companion.
static func dress(p: FrontierPlayer, look: Dictionary) -> void:
	if look.is_empty():
		return
	if p.appearance != null:
		p.appearance.apply(look)
		return
	var body := p.skeleton.get_node_or_null("Body") as CharacterBodyMesh
	if body == null:
		return
	var pa := PlayerAppearance.new()
	pa.name = "Appearance"
	pa.body = body
	pa.set_process_unhandled_input(false)
	p.add_child(pa)
	p.appearance = pa
	pa.apply(look)


## A tandem controller for the proxy (the same script as the player's), for when she leads. It takes no keys.
static func add_lead(proxy: FrontierPlayer, player_controller: Node) -> Node:
	var t: Node = (player_controller.get_script() as GDScript).new()
	t.player = proxy
	proxy.add_child(t)
	t.set_process_input(false)
	return t
