class_name WildlifeSpecies
extends RefCounted
## The wildlife species (first playable wildlife, 2026-09-26; owner: "lets do what will get us playing now and then we
## will add in later"). The bodies are Quaternius's CC0 stand-in models (assets/wildlife/quaternius/SOURCE.md); the
## project's own animals (built with the horse system, tools/horse) will replace them behind the same table.
##
## Per species:
##   model, scale      the glb and its uniform scale to real size (the models face +Z; bone-measured 2026-09-26: doe
##                     ~0.95 m at the shoulder, buck ~1.0 m, wolf ~0.8 m, fox ~0.38 m)
##   kind              "prey" (graze, flee) or "predator" (stalk, chase, bite)
##   health            hit points (musket ball 120, arrow 30-90, spear 60-130: data/weapons/ballistics.json)
##   walk, run         ground speeds (m/s); walk_ref / run_ref: the speeds at which the Walk / Gallop clips play at
##                     1x (the stand-ins' strides are short, so the clips are sped up to the real speeds)
##   sight, fov        how far (m) and how wide (deg) it sees a standing, moving player (crouching and keeping still
##                     shorten it); hearing scales the player's footfall radii; scent: range (m) down the wind
##   body              [radius, length, height of the back] of the torso hit capsule (m, at scale)
##   vitals, head      hit-zone radius (m) and bones; damage multipliers VITALS_MULT / HEAD_MULT (the vitals sphere sits
##                     on the spine's bone: a shot there is the spine; the heart and lungs are found along the shot's
##                     path through the body capsule, WOUNDS)
##   skin, butcher     what each step of field dressing gives (FieldDressing; InventoryState kinds, names in
##                     inventory_state.gd NAMES); skin_s / butcher_s: its working time (s). No butcher yields: the
##                     carcass is only skinned (wolves, foxes).
##   clips             clip names (the fox and wolf name some clips differently); "low" head down, resting or lying up;
##                     "eat" at a carcass
## Traits (user 2026-09-28: "lets work on the bison so we can reuse a lot of the animal things for different animals":
## what makes a species behave as it does, read by WildAnimal, WildGroup, WildPlanner and WildlifeSpawner, so a new animal
## is an entry here, not code):
##   eco               its kind in the land's numbers (WildlifeEcology: a buck counts as a deer); the key when missing
##   brain             the group's planner (WildPlanner): "herd" (feed and bed, flee together), "pack" (hunt, eat,
##                     track, an alpha, routed), "fox" (a loner: mousing, scavenging)
##   group, fill       the group it lives in (GROUPS) and how the spawner makes up a shortfall of its eco kind: a new
##                     group of fill.size once `min` are missing (new_min for a new one when joining failed), or first a
##                     member for a group of that kind that has room (join: its most)
##   lead              who leads a group of mixed members: the highest (a doe before a buck)
##   forage            feeds on the forage (ForageField: where the deer's food grows, eating it)
##   eats              "graze" (grass), "mice" (mousing: the pounce), "meat" (carcasses; eat_rate of one a second)
##   beds              "cover" (thick cover) or "open" (lies down in the open: the plains' bison)
##   hunted            wolves' prey: "any" (every one), "weak" (only one lamed or badly hurt); none when missing
##   strike_h          [low, high] (m) where its strike lands on the player; reach (m) from its middle to strike
##   hamstring         bites at the back of the legs from behind (the pack's way against a man)
##   blood_scent       smells the player's fresh blood (wolves)
##   eat_ring          how far round a carcass it stands to eat, x its rim
##   meat              a whole carcass's meat, in deer (1 when missing): what the scavengers eat and the knife takes
##   call, flee_call   its own call now and then at dusk and night (a sound id), and the chance of it on bolting
##   defend            prey that turn on the player: hurt under `hurt` of its health and him within `reach`, it strikes
##                     (`damage`); with `charge` (m) it runs at him from that far (the bison), `knock` knocks him down
##   spacing           a herd's members spread this far apart round the leader (m; a spiral: a big herd keeps its room)
##   sizes             the builds it comes in against its model: [[share, smallest, largest], ...] (the bison: its model a
##                     bull's, the cows smaller); each animal picks one (WildAnimal.set_size: body, zones, reach scaled)
##   rig               the body it wears: none, a stand-in's (its clips by name, WildAnimal); "horse" the project's own
##                     horse (WildHorse: its gait clips by speed, its head carried by a pose, the tack off)
##   tires             running winds it: its fatigue climbs this much faster in flight, and winded (WildAnimal.winded)
##                     its run falls off to a trot (the wild horse: run hard, it can be caught)
##   tame              it can be caught and broken (HorseBreaking): `spirit`, how long it bucks under a rider
##   coats             the coats it comes in (HorseLook; one picked for each animal, the more often the more it is listed)

const VITALS_MULT := 2.2
const HEAD_MULT := 2.5
## Wounds (user 2026-09-28, the hunt's blood: heart, lungs, gut, leg, graze): where the shot goes through the body
## decides them (WildAnimal.wound_at), and each its damage (mult: x the hit's; the head's collider has HEAD_MULT
## already), its bleeding (bleed: that share of the damage, in health a second, at first; clot: the share of it that
## stops a second, 0 never; x RUN_BLEED while it runs) and its blood on the ground (look: WildlifeSpawner.blood_drop;
## the drops bigger and closer the harder it bleeds). A wound that clots before the animal has bled out heals.
##   heart  drops within seconds, 50-80 m on; big bright drops close together
##   lungs  15-40 s; pink froth
##   spine  (the withers: the old vitals sphere, on the spine's bone) down where it stands
##   gut    minutes; dark, sparse, green flecks; it lies up close by if not pushed (WildAnimal.BED_BLEED), pushed it runs
##   leg    (shoulder or haunch) bleeds hard at first, clots, limps (LAME_SPEED); usually lives
##   graze  a shot glancing along it: a few drops, soon stops
const WOUNDS := {
	"heart": {"mult": 2.6, "bleed": 0.2, "clot": 0.0, "look": "red"},
	"lungs": {"mult": 2.2, "bleed": 0.045, "clot": 0.0, "look": "froth"},
	"spine": {"mult": 2.2, "bleed": 0.1, "clot": 0.0, "look": "red"},
	"head": {"mult": 1.0, "bleed": 0.08, "clot": 0.0, "look": "red"},
	"gut": {"mult": 1.0, "bleed": 0.012, "clot": 0.0, "look": "gut"},
	"leg": {"mult": 0.9, "bleed": 0.05, "clot": 0.035, "look": "red"},
	"graze": {"mult": 0.4, "bleed": 0.05, "clot": 0.12, "look": "red"},
}
## Where they lie in the body's capsule (every species alike): [along, up, radius] as fractions of its half-length
## (toward the head) and of its radius (up from its axis). The shot's path through the body: nearest the heart, then
## the lungs; else where it went in: the gut from GUT_ALONG[0] to [1], the shoulder forward of it and the haunch behind
## (legs); passing the axis further out than GRAZE_OUT of the radius, it only grazes.
const HEART := [0.5, -0.4, 0.4]
const LUNGS := [0.48, 0.05, 0.62]
const GUT_ALONG := [-0.55, 0.28]
const GRAZE_OUT := 0.8
## Bleeding while it runs, x.
const RUN_BLEED := 1.4

const DATA := {
	"deer": {
		"step": 0.6, "name": "deer", "model": "res://assets/wildlife/smooth/deer.glb", "scale": 0.38, "kind": "prey",
		"health": 110.0, "walk": 1.2, "run": 9.0, "walk_ref": 0.75, "run_ref": 4.2, "turn": 5.0,
		"sight": 55.0, "fov": 300.0, "hearing": 1.3, "scent": 70.0,
		"body": [0.24, 1.25, 0.82], "vitals": [0.17, "Torso3"], "head": [0.11, "Head"],
		"skin": {"deer_hide": 1}, "butcher": {"venison": 4, "brains": 1, "sinew": 2, "bone": 2}, "skin_s": 6.0, "butcher_s": 8.0,
		"clips": {"idle": ["Idle", "Idle_2"], "graze": "Eating", "alert": "Idle", "walk": "Walk", "run": "Gallop",
				"jump": "Gallop_Jump", "attack": "Attack_Kick", "hit_l": "Idle_HitReact_Left",
				"hit_r": "Idle_HitReact_Right", "death": "Death", "low": "Idle_Headlow", "eat": "Eating"},
		"brain": "herd", "group": "deer_herd", "fill": {"group": "deer_herd", "min": 2, "size": [2, 5]}, "lead": 1.0,
		"forage": true, "eats": "graze", "beds": "cover", "hunted": "any", "strike_h": [0.8, 1.4],
	},
	"stag": {
		"step": 0.6, "name": "buck", "model": "res://assets/wildlife/smooth/stag.glb", "scale": 0.37, "kind": "prey",
		"health": 140.0, "walk": 1.25, "run": 9.5, "walk_ref": 0.75, "run_ref": 4.3, "turn": 4.5,
		"sight": 60.0, "fov": 300.0, "hearing": 1.3, "scent": 80.0,
		"body": [0.27, 1.35, 0.9], "vitals": [0.19, "Torso3"], "head": [0.12, "Head"],
		"skin": {"deer_hide": 1, "antler": 1}, "butcher": {"venison": 5, "brains": 1, "sinew": 2, "bone": 2}, "skin_s": 7.0, "butcher_s": 9.0,
		"clips": {"idle": ["Idle", "Idle_2"], "graze": "Eating", "alert": "Idle", "walk": "Walk", "run": "Gallop",
				"jump": "Gallop_Jump", "attack": "Attack_Headbutt", "hit_l": "Idle_HitReact_Left",
				"hit_r": "Idle_HitReact_Right", "death": "Death", "low": "Idle_Headlow", "eat": "Eating"},
		"eco": "deer", "brain": "herd", "group": "deer_herd", "lead": 0.0, "meat": 1.2,
		"forage": true, "eats": "graze", "beds": "cover", "hunted": "any", "strike_h": [0.5, 1.3],
		"defend": {"hurt": 0.6, "reach": 2.4, "damage": 20.0},
	},
	"wolf": {
		"step": 0.55, "name": "wolf", "model": "res://assets/wildlife/smooth/wolf.glb", "scale": 0.43, "kind": "predator",
		"health": 80.0, "walk": 1.5, "run": 10.5, "walk_ref": 0.8, "run_ref": 4.6, "turn": 6.0,
		"sight": 70.0, "fov": 250.0, "hearing": 1.5, "scent": 110.0,
		"body": [0.2, 1.05, 0.72], "vitals": [0.14, "Torso3"], "head": [0.1, "Head"],
		"bite": 12.0, "bite_cd": 1.4,
		"skin": {"wolf_pelt": 1}, "butcher": {}, "skin_s": 6.0,
		"clips": {"idle": ["Idle", "Idle_2"], "graze": "Idle_2_HeadLow", "alert": "Idle", "walk": "Walk",
				"run": "Gallop", "jump": "Gallop_Jump", "attack": "Attack", "hit_l": "Idle_HitReact_Left",
				"hit_r": "Idle_HitReact_Right", "death": "Death", "low": "Idle_2_HeadLow", "eat": "Eating"},
		"brain": "pack", "group": "wolf_pack", "fill": {"group": "wolf_pack", "min": 1, "new_min": 2, "size": [2, 5], "join": 7},
		"eats": "meat", "eat_rate": 0.004, "beds": "cover", "strike_h": [0.25, 1.1], "hamstring": true,
		"blood_scent": true, "eat_ring": 1.3,
	},
	"fox": {
		"step": 0.35, "name": "fox", "model": "res://assets/wildlife/smooth/fox.glb", "scale": 0.2, "kind": "prey",
		"health": 35.0, "walk": 0.9, "run": 8.0, "walk_ref": 0.4, "run_ref": 2.3, "turn": 7.0,
		"sight": 45.0, "fov": 260.0, "hearing": 1.6, "scent": 60.0,
		"body": [0.1, 0.55, 0.36], "vitals": [0.08, "Torso3"], "head": [0.06, "Head"],
		"skin": {"fox_pelt": 1}, "butcher": {}, "skin_s": 3.5,
		"clips": {"idle": ["Idle", "Idle_2"], "graze": "Eating", "alert": "Idle", "walk": "Walk", "run": "Gallop",
				"jump": "Gallop_Jump", "attack": "Attack", "hit_l": "Idle_HitReact_Left",
				"hit_r": "Idle_HitReact_Right", "death": "Death", "low": "Eating", "eat": "Eating"},
		"brain": "fox", "group": "fox", "fill": {"group": "fox", "min": 1},
		"eats": "mice", "eat_rate": 0.0025, "beds": "cover", "strike_h": [0.15, 0.6],
		"call": "wild_rec_fox_call", "flee_call": 0.4,
	},
	# The plains bison (user 2026-09-28: "bison behavior in the open plains a lot of them"; "lets work on the bison so we
	# can reuse a lot of the animal things"): Poly by Google's bison (CC-BY 3.0) rigged on Quaternius's stag armature
	# (CC0) with the stag's clips, in metres (tools/wildlife/bison_rig.py; assets/wildlife/bison/SOURCE.md): a bull's
	# build (~1.97 m at the hump, 3.3 m long), the cows smaller ("sizes"). Poor eyes, a keen nose and ears; big herds on open ground, bedding down in the open; a
	# gallop near 50 km/h for a short way. Hard to kill (a ball through the lungs, not the shoulder), and a hurt one, or
	# any one crowded, may turn and charge. The wolves take only the weak ones.
	"bison": {
		"step": 0.8, "name": "bison", "model": "res://assets/wildlife/smooth/bison.glb", "scale": 1.0, "kind": "prey",
		"health": 520.0, "walk": 1.1, "run": 12.5, "walk_ref": 0.95, "run_ref": 5.4, "turn": 2.6,
		"sight": 38.0, "fov": 300.0, "hearing": 1.2, "scent": 150.0,
		# (a bull's body, the model's: user 2026-09-28, "make the bisons accurate make them bigger they can not be smaller
		# than the horse": ~1.97 m at the hump, 3.3 m long, 1.05 m across; the cows ~0.87 of it, ~1.7 m and 2.9 m, all
		# of them well over the horse's 1.43 m and 2.4 m)
		"body": [0.53, 2.6, 1.65, -0.41], "vitals": [0.34, "Torso3"], "head": [0.27, "Head"],
		"sizes": [[0.35, 0.97, 1.03], [0.65, 0.84, 0.9]],
		# (its meat is venison: in 1765 the word was any game's flesh, the buffalo's too)
		"skin": {"bison_robe": 1}, "butcher": {"venison": 14, "tongue": 1, "tallow": 3, "sinew": 4, "brains": 1, "bone": 4},
		"skin_s": 16.0, "butcher_s": 24.0,
		"clips": {"idle": ["Idle", "Idle_2"], "graze": "Eating", "alert": "Idle", "walk": "Walk", "run": "Gallop",
				"jump": "Gallop_Jump", "attack": "Attack_Headbutt", "hit_l": "Idle_HitReact_Left",
				"hit_r": "Idle_HitReact_Right", "death": "Death", "low": "Idle_Headlow", "eat": "Eating"},
		"brain": "herd", "group": "bison_herd", "fill": {"group": "bison_herd", "min": 1, "size": [6, 14], "join": 18},
		"lead": 1.0, "eats": "graze", "beds": "open", "hunted": "weak", "strike_h": [0.6, 1.3], "reach": 3.4, "meat": 6.0,
		"spacing": 5.2,
		"defend": {"hurt": 0.75, "reach": 3.4, "damage": 45.0, "charge": 14.0, "crowd": 6.0, "knock": 7.0},
	},
	# The wild horse (user 2026-09-28: "use the bison or deer logic to build a herd of wild horses that can be tamed"):
	# the project's own horse (tools/horse: the rideable Horse's model, its tack off) on WildHorse, with the deer's and
	# the bison's herd brain. A band: a lead mare leads, the stallion follows at its back and turns on a man who crowds
	# it. Eyes nearly all round (a blind spot straight behind), keen ears and nose; fast, but it winds ("tires"): run
	# hard, it falls off to a trot. Caught (G at its side, HorseBreaking) and ridden out, it is broken to a Horse.
	"horse": {
		"step": 0.7, "name": "wild horse", "model": "res://assets/horse/horse.glb", "scale": 1.0, "kind": "prey", "rig": "horse",
		"health": 300.0, "walk": 1.4, "run": 13.5, "walk_ref": 1.38, "run_ref": 10.0, "turn": 3.2,
		"sight": 65.0, "fov": 340.0, "hearing": 1.5, "scent": 100.0,
		"body": [0.34, 1.5, 1.45], "vitals": [0.16, "chest"], "head": [0.2, "head"],
		# (a horse's hide went for rawhide; its meat is venison as the bison's is)
		"skin": {"rawhide": 2}, "butcher": {"venison": 8, "sinew": 3, "tallow": 2, "brains": 1},
		"skin_s": 14.0, "butcher_s": 20.0,
		"clips": {"idle": ["idle"], "graze": "graze", "alert": "alert", "walk": "walk", "run": "run", "jump": "idle",
				"attack": "rear", "hit_l": "idle", "hit_r": "idle", "death": "death", "low": "rest", "eat": "graze"},
		"brain": "herd", "group": "horse_herd", "fill": {"group": "horse_herd", "min": 2, "size": [4, 8], "join": 10},
		"lead": 1.0, "eats": "graze", "beds": "open", "hunted": "weak", "strike_h": [0.4, 1.2], "reach": 2.6,
		"meat": 3.5, "spacing": 3.0, "tires": 4.0,
		"defend": {"hurt": 0.5, "reach": 2.4, "damage": 18.0, "knock": 4.0},
		"tame": {"spirit": 70.0},
		"coats": ["bay", "bay", "dun", "dun", "chestnut", "brown", "black", "grey"],
	},
	"stallion": {
		"step": 0.7, "name": "wild stallion", "model": "res://assets/horse/horse.glb", "scale": 1.0, "kind": "prey", "rig": "horse",
		"health": 340.0, "walk": 1.4, "run": 13.5, "walk_ref": 1.38, "run_ref": 10.0, "turn": 3.2,
		"sight": 65.0, "fov": 340.0, "hearing": 1.5, "scent": 100.0,
		"body": [0.35, 1.55, 1.45], "vitals": [0.16, "chest"], "head": [0.2, "head"],
		"skin": {"rawhide": 2}, "butcher": {"venison": 9, "sinew": 3, "tallow": 2, "brains": 1},
		"skin_s": 14.0, "butcher_s": 20.0,
		"clips": {"idle": ["idle"], "graze": "graze", "alert": "alert", "walk": "walk", "run": "run", "jump": "idle",
				"attack": "rear", "hit_l": "idle", "hit_r": "idle", "death": "death", "low": "rest", "eat": "graze"},
		"eco": "horse", "brain": "herd", "group": "horse_herd", "lead": 0.0, "eats": "graze", "beds": "open",
		"hunted": "weak", "strike_h": [0.9, 1.6], "reach": 2.8, "meat": 3.8, "spacing": 3.0, "tires": 4.0,
		# (he rears and strikes at a man who crowds the band, and comes at one who hurts it)
		"defend": {"hurt": 0.7, "reach": 2.6, "damage": 24.0, "charge": 12.0, "crowd": 6.0, "knock": 5.5},
		"tame": {"spirit": 110.0},
		"coats": ["bay", "dun", "black", "chestnut", "brown", "grey"],
	},
}

## The groups the spawner makes (WildlifeSpawner._spawn_group): the group's species (its brain's), its members
## ("species", or [first, share, rest]: the first one that species at that share, e.g. a buck leading does), its size and
## the activity it starts at.
const GROUPS := {
	"deer_herd": {"species": "deer", "members": ["stag", 0.45, "deer"], "size": [3, 5], "starts": "feed"},
	"lone_buck": {"species": "deer", "members": ["stag"], "size": [1, 1], "starts": "feed"},
	"fox": {"species": "fox", "members": ["fox"], "size": [1, 1], "starts": "feed"},
	"wolf_pack": {"species": "wolf", "members": ["wolf"], "size": [3, 4], "starts": "bed"},
	"bison_herd": {"species": "bison", "members": ["bison"], "size": [8, 14], "starts": "feed"},
	# (a band: its stallion, and mares led by the first of them)
	"horse_herd": {"species": "horse", "members": ["stallion", 1.0, "horse"], "size": [4, 8], "starts": "feed"},
}


## Clips that loop (the glb clips import without looping).
const LOOPING := ["Idle", "Idle_2", "Idle_Headlow", "Idle_2_HeadLow", "Eating", "Walk", "Gallop"]

static var _prepared := {}


static func get_data(species: String) -> Dictionary:
	return DATA.get(species, DATA["deer"])


## A species' kind in the land's numbers (a buck is a deer).
static func eco_of(species: String) -> String:
	return String((DATA.get(species, {}) as Dictionary).get("eco", species))


## The land's kinds that have bodies in the world (WildlifeSpawner keeps them to the numbers): deer, wolf, fox, bison,
## horse.
static func eco_kinds() -> Array[String]:
	var out: Array[String] = []
	for sp: String in DATA:
		var e := eco_of(sp)
		if not out.has(e) and (DATA[sp] as Dictionary).has("fill"):
			out.append(e)
	return out


## The species that makes up a shortfall of eco kind `eco` (the one whose entry has "fill").
static func filler(eco: String) -> Dictionary:
	for sp: String in DATA:
		if eco_of(sp) == eco and (DATA[sp] as Dictionary).has("fill"):
			return DATA[sp].fill
	return {}


## A species' brain (its group's planner): herd, pack, fox.
static func brain(species: String) -> String:
	return String((DATA.get(species, {}) as Dictionary).get("brain", "herd"))


## A new body for `species` (not yet set up): its rig's (WildHorse for "horse"), else a WildAnimal.
static func make(species: String) -> WildAnimal:
	if String(get_data(species).get("rig", "")) == "horse":
		return WildHorse.new()
	return WildAnimal.new()


## The species' model, its clips set to loop once (the imported Animation resources are shared by every instance).
static func model(species: String) -> PackedScene:
	var d := get_data(species)
	var ps := load(String(d.model)) as PackedScene
	if ps and not _prepared.has(species):
		_prepared[species] = true
		var probe := ps.instantiate()
		for ap in probe.find_children("*", "AnimationPlayer", true, false):
			for clip in LOOPING:
				if (ap as AnimationPlayer).has_animation(clip):
					(ap as AnimationPlayer).get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		probe.free()
	return ps
