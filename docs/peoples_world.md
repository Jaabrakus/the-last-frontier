# The world's own peoples (a test)

Status 2026-10-04: **a test in the character creator.** The owner, 2026-10-03: "maybe we dont use those races and we
make custom ones for our full metal alchemist and edge chronicles sky pirates treasure planet game", then "yea lets test
it". Inspiration only: no names, symbols or designs from Treasure Planet, The Edge Chronicles or Fullmetal Alchemist.

## The rule: keep the faces, change the peoples

- **Every face stays.** The 35 real peoples' 484 faces, skin tones and hair are what a player looks like, and every
  one of them is a face of every invented people. The creator offers each people 18 faces, two from each of the nine
  regions, starting in a different region per people. No invented people maps onto one real ancestry.
- **The peoples are the world's.** Who you are (your homeland, your dress, your marks, your story) comes from the
  Downbelow and the Drift, not from a real nation. This sets aside the hardest problems the real peoples brought:
  Native dress and tattoos waiting on consultation, sacred designs, and real nations in a raid-and-kidnap story.

## The four peoples of the test

| People | Home | Look | Mark in the skin | Sway | Dress (to build) |
|---|---|---|---|---|---|
| **Downbelowers** | the Downbelow: farms, forts, trappers' cabins under the Drift | every skin and colouring; natural eyes and hair | none | most have none; a few children are Sighted | the period clothes as built (homespun, muskets) |
| **Driftborn** | the floating isles and the ships of the Drift, for generations | tall and lean, weathered (more weathering), pale **silver** or **ice** eyes, **silver**, ash or flaxen hair | none | natural windcallers: the sky crews, traders and pirates | the sky crews' clothes (the Drift set) |
| **Keelfolk** | the keelstone mines in the roots of the isles | stocky and broad; **keel gold** or ember eyes; **soot** or **copper** hair | **keelstone flecks**: patches of crystal-dusted skin (a cool sheen from afar) set with glinting specks that glow faintly | Gust and stone | miners' leather, aprons, lamps (new) |
| **The Etched** | Vessary's pyramids: scholars, builders, rulers | **violet** or dark eyes; shaved or close-cropped | **Form veins**: thin glowing lines worn into the skin by Form | Form, the alchemy | long coats and robes of Vessary (new) |

Later, if the owner likes the direction:

- **Beast-kin**, the Treasure Planet nod: animal-featured faces. They need new heads (the body and its clothes fit
  as they are), so they could be NPC-only at first.
- **The Mended**: an option for any people rather than a people. Limbs replaced in brass and keelstone, like Silver or
  automail but our own design. It needs the limb models.
- **Height and build.** The look already has `stature`, but the player's body does not use it. The Driftborn's height
  and the Keelfolk's breadth need the body scaled, and that touches the camera, the climbing and the clothes, so the
  test leaves it out.

## Names

Every name is a placeholder until it has a collision check (not a real people, place or sacred word; not from Disney
or Nickelodeon). "Graven" was dropped because a 2021 video game has that title. The Etched took its place. "The
Downbelow" has its own note in docs/main_story.md 0.3 (Cherryh's *Downbelow Station*). "Driftborn" and "Keelfolk" are
plain compounds and still need checking.

## What a "yes" would change

- **The creator** lists only these peoples. The real ones leave the creator but keep their faces.
- **The NPCs** are drawn from the real peoples now. Factions would be re-peopled: sky crews Driftborn, Vessary's
  officials the Etched, the Downbelow's settlers Downbelowers.
- **Clothes and tattoos** become per people. The other session builds them once the list is settled.
- **The 35 music tracks** made per people would become the regions' and peoples' themes, or be retired.
- **The opening** still uses real 1757 history (troupes de la marine, Canadian militia, real places). Invented peoples
  fit best if the Downbelow becomes a fictional frontier with an 18th-century feel, with invented factions for the
  raid. That is the owner's call.

## How it is built

- **Data:** `data/customizer/world_peoples.json`. It holds the peoples, their groups (The Downbelow, The Drift,
  Vessary), skin ranges, eye and hair colour weights, own hair styles, mark and lineup outfit, and the world's eye
  colours (silver, ice, storm, keel gold, ember, violet). The hair colours silver, ash, copper and soot are in
  `assets/character/hair/hair_colors.json`.
- **Peoples:** `CharacterPeoples` (scripts/customizer/peoples.gd). `listed_groups` and `listed_peoples` are what the
  creator shows. `people`, `presets`, `stylized_presets` and `random_look` take a world people's id like a real one's.
  `world_listed` is true in the game; the user arg `peoples=real` brings back the real list. Tool and test runs list
  the real peoples unless they pass `peoples=world`.
- **The creator:** `CreatorOptions` has the Mark row (look key `trait`, 0..1: None, Faint, Marked, Strong) and the
  world eye colours. `with_people` gives a world people its own first hair style, most common colours, weathering and
  mark. The emblems are in `PeopleEmblem` (`_e_downbelower`, `_e_driftborn`, `_e_keelfolk`, `_e_etched`).
- **The marks:** `assets/character/shaders/people_trait.gdshaderinc`, used by both skin shaders and set by
  `BodyMaterials.set_trait`. They are drawn in UV space, which runs about a metre of skin per unit everywhere
  (measured).
- **Test:** `tests/customizer/test_world_peoples.gd -- peoples=world`.
- **Shots:** `tools/character/world_peoples_shots.gd -- peoples=world out=DIR`.
