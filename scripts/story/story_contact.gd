class_name StoryContact
extends Node3D
## Someone to talk to (docs/main_story.md: "every mission is started by the player at a contact"; the audit's item 3): a
## lantern's warm glow and a name tag at a person or a post, and E close by opens their conversation (StoryDialogue).
## It is one of the player's E interactables (PlayerInteractor: the "interactables" group, interact_point, the prompt
## "E  Talk to Margaretha Rauch", interact): it glows when it is the one in reach, as anything else E can use.
##   StoryContact.at_post(level, at, "two_fires/rumours", "Margaretha Rauch")   # a post of its own, the lantern on its arm
##   StoryContact.at_person(body, "two_fires/rumours", "Margaretha Rauch")      # on a person: the lantern at their side
##   StoryContact.spawn_for(tree, "two_fires")    # the storyline's contacts, once each (StoryDirector, as it begins)
## The storyline's contacts are its storyline file's "contacts" (docs/main_story.md section 3: data/story/storylines/
## <id>.json holds them, the director puts them in the world); their names come from its dialogue file's speakers.
## The outcome of each talk is kept (last_outcome), sent (talked) and handed to on_done if one is set. A contact with an
## "if" (StoryDialogue.holds) shows only while it holds (a neighbour there only until the Flatts burn, say).
## Cheap: the glow is an unshaded sprite, the light has no shadow and fades out past LIGHT_FADE_M.

const GROUP := &"interactables"           ## PlacedWeapon.GROUP: the interactor's list
const CONTACTS := &"story_contacts"
const POST_H := 2.0
const LANTERN_AT := Vector3(0.42, 1.66, 0.0)      ## on a post: hung from the end of its arm
const LANTERN_AT_PERSON := Vector3(0.3, 0.92, 0.12)  ## on a person: at their side, as carried
const TAG_NEAR_M := 9.0                   ## the name tag full nearer than this
const TAG_FAR_M := 16.0                   ## gone past this
const LIGHT_COLOR := Color(1.0, 0.7, 0.4)
const LIGHT_FADE_M := Vector2(24.0, 10.0) ## the light fades out from 24 m over 10 m
const QUIET_S := 0.5                      ## s after a talk before E opens it again (the key that closed it still down)
const CHECK_S := 1.0

signal talked(outcome: String)

var id := ""
var who := ""                  ## the name on the tag and in the prompt
var convo := ""                ## the conversation E opens (StoryDialogue.open's convo_id)
var post := true               ## stands on a post of its own (false: on a person, its parent)
var when: Variant = null       ## shown only while this holds (StoryDialogue.holds; null always)
var interact_reach := 2.6
var on_done: Callable          ## (outcome: String), after each talk
var last_outcome := ""
var talks := 0
var _quiet_t := 0.0
var _wait_release := false
var _talking := false
var _check_t := 0.0
var _flick := 0.0
var _shown := true
var _glow: MeshInstance3D
var _glass: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _light: OmniLight3D
var _tag: Label3D
var _lantern: Node3D
var _post_meshes: Array = []


## A contact on a post of its own at `at` (on the ground there), under `parent`.
static func at_post(parent: Node, at: Vector3, convo_id: String, name_: String, contact_id := "") -> StoryContact:
	var c := StoryContact.new()
	c.id = contact_id
	c.who = name_
	c.convo = convo_id
	c.post = true
	c.name = "Contact_" + (contact_id if contact_id != "" else name_).validate_node_name()
	parent.add_child(c)
	c.global_position = at
	return c


## A contact on a person (a body in the world): the lantern at their side, the tag over their head.
static func at_person(person: Node3D, convo_id: String, name_: String, contact_id := "") -> StoryContact:
	var c := StoryContact.new()
	c.id = contact_id
	c.who = name_
	c.convo = convo_id
	c.post = false
	c.name = "Contact"
	person.add_child(c)
	return c


## The storyline's contacts (its storyline file's "contacts": [{id, speaker | name, convo, place, offset, at, face, if}],
## placed on the ground at a named place of the storyline (+ offset) or at "at" [x, z]; a speaker is a key of its
## dialogue file's speakers, whose name it takes); one already there is left. The storyline is the running director's
## when it is this one, else read from StoryDirector.dir (tests point it at their own). Returns those made.
static func spawn_for(tree: SceneTree, storyline: String) -> Array[StoryContact]:
	var made: Array[StoryContact] = []
	if tree == null or tree.current_scene == null or storyline == "":
		return made
	var sd := StoryDirector.find(tree)
	var line: Dictionary = sd.line if sd != null and sd.storyline_id == storyline and not sd.line.is_empty() \
			else StoryDirector.load_json(StoryDialogue.story_dir() + "storylines/%s.json" % storyline)
	var list: Array = line.get("contacts", []) if line.get("contacts") is Array else []
	if list.is_empty():
		return made
	var places: Dictionary = line.get("places", {}) if line.get("places") is Dictionary else {}
	var talk := StoryDialogue.load_file(storyline)
	var speakers: Dictionary = talk.get("speakers", {}) if talk.get("speakers") is Dictionary else {}
	var have := {}
	for n in tree.get_nodes_in_group(CONTACTS):
		have[String((n as StoryContact).id)] = true
	for e: Variant in list:
		if not (e is Dictionary):
			continue
		var d := e as Dictionary
		var cid := String(d.get("id", ""))
		if cid == "" or have.has(cid):
			continue
		var xz := Vector2.ZERO
		var at: Variant = d.get("at")
		var place: Variant = places.get(String(d.get("place", "")))
		var off: Variant = d.get("offset")
		if at is Array and (at as Array).size() >= 2:
			xz = Vector2(float(at[0]), float(at[1]))
		elif place is Array and (place as Array).size() >= 2:
			xz = Vector2(float(place[0]), float(place[1]))
		else:
			push_warning("StoryContact: %s has no place" % cid)
			continue
		if off is Array and (off as Array).size() >= 2:
			xz += Vector2(float(off[0]), float(off[1]))
		var sp: Variant = speakers.get(String(d.get("speaker", "")))
		var nm := String(d.get("name", (sp as Dictionary).get("name", "") if sp is Dictionary else d.get("speaker", "")))
		var cv := String(d.get("convo", ""))
		if cv != "" and not cv.contains("/"):
			cv = "%s/%s" % [storyline, cv]
		var c := at_post(tree.current_scene, Vector3(xz.x, FrontierTerrain.height_at(xz.x, xz.y), xz.y), cv, nm, cid)
		c.when = d.get("if")
		c._refresh_shown()                           # (one whose `if` does not hold is not seen even for a frame)
		if d.has("face"):
			c.rotation.y = deg_to_rad(float(d.get("face")))
		have[cid] = true
		made.append(c)
	return made


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(CONTACTS)
	set_meta(&"bark_height", POST_H + 0.6 if post else StoryBark.HEIGHT)
	if post:
		_build_post()
	_build_lantern()
	_tag = Label3D.new()
	_tag.name = "NameTag"
	_tag.text = who
	_tag.font = FrontierHUD.serif()
	_tag.font_size = 26
	_tag.outline_size = 8
	_tag.outline_modulate = Color(0.02, 0.015, 0.01, 0.8)
	_tag.modulate = Color(FrontierHUD.GOLD, 0.0)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0008
	_tag.position = Vector3(0, POST_H + 0.3 if post else 2.15, 0)
	add_child(_tag)
	_refresh_shown()


func _build_post() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.33, 0.24, 0.16)
	wood.roughness = 0.92
	var pole := MeshInstance3D.new()
	pole.name = "Post"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.065
	cm.bottom_radius = 0.08
	cm.height = POST_H
	cm.radial_segments = 8
	cm.rings = 1
	pole.mesh = cm
	pole.material_override = wood
	pole.position = Vector3(0, POST_H * 0.5, 0)
	add_child(pole)
	var arm := MeshInstance3D.new()
	arm.name = "Arm"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.06, 0.06)
	arm.mesh = bm
	arm.material_override = wood
	arm.position = Vector3(0.22, POST_H - 0.12, 0)
	add_child(arm)
	_post_meshes = [pole, arm]
	# the post stands in the way (a thin body: nothing to climb or crawl under)
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.08
	cs.height = POST_H
	shape.shape = cs
	shape.position = Vector3(0, POST_H * 0.5, 0)
	body.add_child(shape)
	add_child(body)


## The lantern: an iron frame round warm glass, a cap, and its glow (a soft sprite) and a small light.
func _build_lantern() -> void:
	_lantern = Node3D.new()
	_lantern.name = "Lantern"
	_lantern.position = LANTERN_AT if post else LANTERN_AT_PERSON
	add_child(_lantern)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.12, 0.11, 0.1)
	iron.metallic = 0.6
	iron.roughness = 0.55
	var fm := BoxMesh.new()
	fm.size = Vector3(0.15, 0.03, 0.15)
	for y: float in [-0.11, 0.11]:
		var f := MeshInstance3D.new()
		f.mesh = fm
		f.material_override = iron
		f.position = Vector3(0, y, 0)
		_lantern.add_child(f)
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(1.0, 0.82, 0.55)
	_glass.emission_enabled = true
	_glass.emission = LIGHT_COLOR
	_glass.emission_energy_multiplier = 2.2
	_glass.roughness = 0.3
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var gm := BoxMesh.new()
	gm.size = Vector3(0.12, 0.19, 0.12)
	glass.mesh = gm
	glass.material_override = _glass
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern.add_child(glass)
	var cap := MeshInstance3D.new()
	var cpm := CylinderMesh.new()
	cpm.top_radius = 0.015
	cpm.bottom_radius = 0.09
	cpm.height = 0.07
	cpm.radial_segments = 8
	cpm.rings = 1
	cap.mesh = cpm
	cap.material_override = iron
	cap.position = Vector3(0, 0.155, 0)
	_lantern.add_child(cap)
	if post:
		var ring := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.008
		rm.bottom_radius = 0.008
		rm.height = 0.2
		rm.radial_segments = 4
		rm.rings = 1
		ring.mesh = rm
		ring.material_override = iron
		ring.position = Vector3(0, 0.27, 0)
		_lantern.add_child(ring)
	_glow = MeshInstance3D.new()
	_glow.name = "Glow"
	var q := QuadMesh.new()
	q.size = Vector2(0.95, 0.95)
	_glow.mesh = q
	var gmat := StandardMaterial3D.new()
	_glow_mat = gmat
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gmat.albedo_color = Color(1.0, 0.62, 0.3, 0.55)
	gmat.albedo_texture = _glow_texture()
	gmat.disable_fog = true
	gmat.disable_receive_shadows = true
	_glow.material_override = gmat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern.add_child(_glow)
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.light_color = LIGHT_COLOR
	_light.light_energy = 0.9
	_light.omni_range = 3.6
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_light.light_specular = 0.2
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = LIGHT_FADE_M.x
	_light.distance_fade_length = LIGHT_FADE_M.y
	_lantern.add_child(_light)


static func _glow_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


# --- E ---------------------------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


func distance_from(p: Vector3) -> float:
	var q := interact_point()
	return Vector2(p.x - q.x, p.z - q.z).length() + absf(p.y - q.y) * 0.25


func highlight_targets() -> Array:
	var out: Array = []
	if post:
		out.append_array(_post_meshes)
	elif get_parent() != null:
		for g in get_parent().find_children("*", "MeshInstance3D", true, false):   # (meshes: not a bark or tag over them)
			if not is_ancestor_of(g):
				out.append(g)
	for g in _lantern.find_children("*", "MeshInstance3D", true, false):
		if g != _glow:
			out.append(g)
	return out


func interact_prompt(_player: Node) -> String:
	if not ready_to_talk():
		return ""
	return "Talk to %s" % who if who != "" else "Talk"


func interact(_player: Node) -> void:
	if not ready_to_talk():
		return
	_talking = true
	StoryDialogue.open(get_tree(), convo, _on_talked)


## E would open the talk now: shown, a conversation to have, none open, and not straight after the last one.
func ready_to_talk() -> bool:
	return _shown and convo != "" and not _talking and _quiet_t <= 0.0 and not _wait_release \
			and not StoryDialogue.is_open(get_tree())


func _on_talked(outcome: String) -> void:
	_talking = false
	talks += 1
	last_outcome = outcome
	_quiet_t = QUIET_S
	_wait_release = true            # (the key that ended it may still be down: no second talk on its release)
	talked.emit(outcome)
	if on_done.is_valid():
		on_done.call(outcome)


# --- Each frame ------------------------------------------------------------------------------------------------

func _refresh_shown() -> void:
	var on := when == null or StoryDialogue.holds(get_tree(), when)
	if on == _shown and visible == on:
		return
	_shown = on
	visible = on
	for b in find_children("*", "StaticBody3D", false, false):
		(b as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_quiet_t = maxf(0.0, _quiet_t - delta)
	if _wait_release and not (InputMap.has_action(&"interact") and Input.is_action_pressed(&"interact")):
		_wait_release = false
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = CHECK_S
		_refresh_shown()
	if not _shown:
		return
	# the flame's small unrest in the glass and the glow
	_flick += delta
	var f := 0.9 + 0.06 * sin(_flick * 7.3) + 0.04 * sin(_flick * 13.1 + 1.7)
	_glass.emission_energy_multiplier = 2.2 * f
	_light.light_energy = 0.9 * f
	var gc := _glow_mat.albedo_color
	gc.a = 0.55 * f
	_glow_mat.albedo_color = gc
	# the name tag near the player only
	var pl := StoryDialogue.local_player(get_tree())
	var a := 0.0
	if pl != null:
		var d := pl.global_position.distance_to(global_position)
		a = clampf(1.0 - (d - TAG_NEAR_M) / (TAG_FAR_M - TAG_NEAR_M), 0.0, 1.0)
	_tag.modulate.a = a
	_tag.visible = a > 0.01
