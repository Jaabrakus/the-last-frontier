# Frontier

Third-person colonial frontier shooter prototype (Godot 4.7). A stockade fort
in a forest clearing with a shooting range outside the north gate. You carry a
hunting bow, a flintlock musket and a flintlock pistol, and the thrown weapons: a
throwing spear, a tomahawk and a (legendary) atlatl.

Open the folder in Godot and press **F5**.

| Input | Action |
|---|---|
| WASD / Shift / Alt | Move / sprint / walk |
| Ctrl or C, Space | Crouch (toggle), jump |
| 1 2 3 4 5 6, mouse wheel | Bow, musket, pistol, spear, tomahawk, atlatl (the wheel cycles all six) |
| LMB | Hold to aim, release to shoot (bow: draw; musket/pistol: shoulder, then fire on release; thrown weapons: wind up, then throw on release) |
| RMB | Firearms: raise and steady the aim without firing (zoom, tighter spread); bow: let the string down; thrown weapons: lower without throwing |
| E | Pick up a thrown weapon out of walking reach (walking over it also picks it up); tap: take an item or a dropped torch |
| T | Torch: tap to take one from the pack, lit (the right hand with a long gun, the bow or empty hands; the left with the pistol and the thrown weapons); tap again to put it out and back in the pack; hold to raise it beside the shoulder and light farther |
| R | Reload |
| 7 / 8 | Take out / put away the felling axe / the mattock (gathering) |
| LMB with a tool out | Hold at a tree, sapling, felled trunk or rock: keep swinging |
| E at a tree, trunk or rock | Takes out the right tool and swings it once |
| B | Build mode on / off (wheel: the piece, R: turn it, hold E: build it; see Building) |
| E at a horse | At its saddle: mount (hold E on horseback: get off); at its head: lead it / Stay (see Horses) |
| G at a wild horse's side | Grab its mane and swing up bareback (on foot, or from the saddle riding alongside it); W A S D keep your balance while it bucks, G lets go (see Horses, Wild horses) |
| E by a felled tree with the horse near | Hitch the trunk to the horse and drag it (see Horses) |
| E at a dead animal's neck with the horse near | Rope the carcass to the horse and drag it home (see Horses) |
| E at a dead animal's neck on foot | Drag it on a rope in the left hand; T puts a torch in the right; E lets go (see Horses) |
| E at a felled tree's crown | Limb it with the axe: the branches off, a bare log left (see Gathering) |
| E at a log's end on foot | Pull it with both hands walking backward (S back, A / D sideways); E lays it down or stacks it on a barricade (see Horses) |
| E at a wheelbarrow's handles / bed | Push it (E sets it down) / put in a deer, a log length or pack things, or tip them out (see Horses) |
| E at a horse cart's shafts / tailboard | Hitch the horse to it (in the saddle: a tap) or unhitch it / put in a deer, a log, the wheelbarrow or pack things, take out the last (see Horses) |
| E at a wild plant | Pick berries, nuts, acorns, herbs, or dig a root (see Wild food and herbs) |
| LMB with the hoe out | At open ground: break it out into a bed; at a growing bed: hoe out the weeds (see Farming) |
| E at a bed | Sow it (hold E: which crop), harvest it when ripe, or pull up frost-killed plants (see Farming) |
| V | Eat the best food in the pack (right-click food in the pack: eat that) |
| Z | Sleep on the ground (Z again, or move, to get up); better in a lean-to and by a fire |
| F at a lit campfire | Cook: roast the pack's venison, corn or squash, boil its beans, or bake its cornmeal into johnnycake (see Fire, cold and shelter) |
| F5 / F9 | Quick save / load the latest save (see Saving and death) |
| F3 | Debug readout |

## Weapons

Weapons are carried in a relaxed idle and raised only while aiming. Shots are zeroed: a full-draw arrow or a ball lands on the crosshair (drop is compensated); undercharged arrows fall short. The camera sits centered and high behind the player (SOCOM 2 style).


- **Bow**: silent, draw strength sets arrow speed/damage (30-90), fatigue after a long hold, 24 arrows. Arrows drop noticeably: hold over at range.
- **Musket**: 120 damage, very accurate still/crouched, 5-stage reload (~8 s). Interrupting (sprint, jump, swap) keeps finished stages.
- **Pistol**: 105 damage, fast to draw, poor past ~30 m, 3-stage reload (~3 s).
- **Long gun in the left hand**: crouch-walking after a while without aiming, the left hand carries the musket in the
  middle at its side and the right hand is free; switching from the musket to the tomahawk or the spear keeps the
  musket in the left hand (not slung) and draws the throwable with the right; its key (or the throwable's again)
  brings the musket back to both hands, aim ready in about 0.4 s.
- **Thrown weapons** (spear 2, tomahawk 2, atlatl 5 darts): hold LMB to wind up (the arc shows where it lands), release to throw; they stick in wood, straw and soft ground and are picked up again. The character plays the source graph's throw (raised into the throw aim pose, then release-start, release-end, back to carry; the whole body when standing, the upper body over the legs when moving). The spear is carried overhand above the shoulder like a javelin (lowered across the body while sprinting) and drawn from the back sling along the long-gun draw's own path, the tomahawk like a hatchet in the fist, head up, drawn from the back of the belt; after a throw the next one is taken into the hand during the draw; both carries are poses of the source clips (see `Player_Animation_Project/graph_analysis/throwables/throwables_design.md` section 6).

## Torch

Pine-knot torches (split pitch pine with a head of fat-pine splints bound in birch bark; a project-made model)
ride in the pack as one stack (4 at the start; the inventory shows them, right-click the stack to take one in
hand). **T** (tap) lights one into the hand the weapon does not need; T again puts it out and back in the pack with its
burn time kept; **holding T** raises it beside the shoulder, the flame above the head, to light farther (letting go
lowers it). A torch burns for 6 minutes of real time (`torch_burn_s`), dies down over its last 12 % (about 45 s) and
falls from the hand when it is burnt out. Its fire is a flickering warm light (10 m, fades with distance; no shadows
unless `torch_shadows` is on) with a flame that bends with the wind and trails as you move, sparks, pine smoke and a
crackle.

- The torch is carried like a hatchet: the arm hanging at the side, the fist round the handle beside the hip, the
  torch angled a little forward and out (the tomahawk's one-hand carry arm and grip).
- With the musket or the over-under out the **right** hand holds the torch and the **left** hand carries the gun alone,
  gripped in the middle at its balance point (just ahead of the lock), level along the left side, muzzle forward;
  lighting one plays a short handoff (the left hand takes the gun, then the right hand brings up the torch). The bow
  is held in the left hand beside it (drawing the string tosses the torch); the pistol and the thrown weapons take
  the right hand, the torch the left; with empty hands the torch is in the right. Switching weapons passes it
  between the hands.
- **Aiming** a long gun (RMB, or LMB to shoulder), **drawing the bow** or **reloading** tosses the torch a little
  ahead and to its hand's side; it keeps burning and lighting the ground where it lands, and the right hand takes
  the stock, the left the fore-end. Tap **E** on it to pick it up. The pistol keeps the torch (it aims one-handed).
- Mounting a horse puts the torch out and packs it; a vault or climb, and death, let it fall.
- Heavy rain (a storm's core, from the weather) drowns it in about 20 s unless something solid overhead (a roof)
  keeps it off; water puts it out at once.

Damage, speed and spread are the balanced values of `data/weapons/ballistics.json`, applied to every weapon when the player is built (`WeaponBalance`).

Flintlocks flash in the pan, fire after a short hang-fire and leave lingering smoke.

## Gathering

Fell trees, buck them into logs and break stone (`scripts/gathering/`, numbers in `data/gathering/gathering.json`).
The felling axe (an American felling axe of the 1750s-60s: heavy poll, flared bit, straight 86 cm hickory haft)
rides head down in the pack's tool loop behind the right shoulder; the mattock (a pick-mattock) is in the pack. Both
are the player's from the start. 7 / 8 draws one over the shoulder (a weapon in the hands is put away first; a weapon
key or H puts the tool back). Facing something it works on, hold LMB to swing, or tap E. The tools take both
hands: with a torch in the hand, taking one out tosses the torch down first (it keeps burning and lights the
work; E picks it up), and taking a torch (T) while a tool is out puts the tool back.

- **Standing trees** take strokes by the trunk's diameter, the species' hardness (pine soft, oak and maple hard)
  and the skill: a 30 cm white pine 4 strokes at level 0, a 70 cm one 12. Cut through, the tree topples away from
  you (a Novice's fall wanders up to 30 degrees; from Apprentice it goes where you mean it to) and can hurt anyone
  it comes down on; a stump stays. The felled tree is bucked where it lies: one log per 2.4 m of clear bole (a
  Novice's later lengths may split into firewood), then the crown gives firewood and branches.
- **Limbing** (user 2026-09-27): stand in a felled tree's crown and **E** (or LMB), *Limb the white pine*: a few
  strokes by the crown's spread take its branches off (its firewood and branches go into the pack) and the trunk
  lies bare, a **log** (the clear bole, 2.4 m a length). Along it the axe bucks a length off as its own log lying
  there (*Buck a log off the white pine*), not into the pack; the last length bucks into the pack. A log can be
  pulled on foot, hauled by the horse, or laid in a barricade (see Horses). Bucking a tree you have not limbed
  still puts its logs straight into the pack.
- **Saplings** come down in two strokes (one from Apprentice): a pole and branches.
- **Rocks** (limestone outcrops, shale ledges, granite boulders) break into stone as the mattock works them, with
  now and then a nodule of chert (flint) from the limestone; the rock shrinks and is gone at the end.
- **Skills**: Woodcutting, Mining and Building (the last for building, next), 0-100 with the survival tiers
  (Novice, Apprentice 20, Journeyman 40, Adept 60, Master 80) and the survival growth curve. A level swings
  faster, does more per stroke and gives better yields; every level and tier shows at the top of the screen.
  Saved in `user://frontier_gathering.json`.
- Everything gathered goes into the pack (Tab) and stacks. Felled trees, cut saplings and quarried rocks are saved
  with the game (see Saving and death); a new game grows the forest back.

The draw, the carry and the strokes are clips of `animations_extra/Actor_B_from_A.res` (retargeted, see CREDITS.md):
the machete's draw and stow, the two-handed level swing (felling) and overhead blow (bucking, stone). Tests:
`tests/gathering/test_gathering.gd` (headless: skills, data, yields, and on the level felling, bucking, stone,
E, the tools and a weapon); `tests/gathering/felling_shots.gd` (windowed filmstrip of a felling, the poses, the
icons, the inventory). Sounds: `tools/sfx/gathering.py`.

## Building

Log cabins, windows, doors, palisade forts and chimneys from the logs and stone in the pack (`scripts/building/`,
costs in `data/building/building.json`). **B** turns build mode on (what is in the hands is put away; a weapon
key, H, 7 / 8 or mounting a horse ends it). The piece to build shows as a ghost at the crosshair: green where it
can go, red where it cannot, with the reason under the crosshair ("Needs 2 more logs", "A tree is in the way",
"Too steep: the footing would not reach the ground", "You are standing in the way"). The **mouse wheel** picks the
piece, **R** turns it (a quarter turn on the ground, end for end on a socket), **hold E** and let go to build it.
A panel on the left lists the pieces under their groups (Cabin, Camp, Furniture, Crafting, Fort; it scrolls with the
choice), every cost (logs, stone, firewood, poles, branches, a hide), the logs and stone in the pack and the Building
skill; a piece is dimmed when the pack is short of anything it costs. Beds, racks and the alchemy table stand on a
built floor too; the drying rack may stand over a campfire.

| Piece | Cost | |
|---|---|---|
| Floor and foundation | 4 logs, 6 stone | 3 x 3 m puncheon floor on hewn sills and a fieldstone footing (up to 1 m of fall under it) |
| Notched log wall | 6 logs | nine courses of round logs, hewn faces, clay chinking; saddle-notched log ends where two walls meet |
| Log wall with window | 5 logs | cased window, board shutters |
| Log wall with door | 5 logs | cased doorway, a hung plank door (tap E: open / shut), stone steps down to the ground from a floor |
| Corner post | 1 log | hewn post for a floor corner or a wall's end (post-and-log corners) |
| Gable end | 2 logs | board-clad gable on a wall top |
| Roof | 4 logs | one 3 m bay of riven-shingle roof on two wall tops; bays join along the ridge |
| Stone hearth and chimney | 16 stone | firebox and stack against a wall (inside or out) or on its own; E lays firewood and lights it: a fire indoors (warms the cabin under its roof, cooks with F, smoke from the stack, the rain cannot drown it) |
| Campfire | 6 stone, 4 firewood | a fieldstone ring, the wood laid; E lights it (flint and steel or a torch), adds firewood, smothers it; F cooks on it; warms, dries, keeps wolves off |
| Brush lean-to | 5 poles, 10 branches | two forked posts, a ridge pole, a thatched slope; keeps wind and rain off whoever sits under it |
| Bough bed | 8 branches, 2 poles | boughs laid thick between side logs; E or Z in it: warmer, a better sleep |
| Drying rack | 6 poles, 2 branches | a pole scaffold over (or beside) a lit campfire: E hangs venison, a day or two later E takes down jerky |
| Pole bed | 4 poles, 6 branches, 1 deer hide | a pole frame on legs, a straw tick, a hide: the best sleep, best of all under a roof |
| Musket rack | 3 poles, 1 log | six long guns or bows stand in it as they were (hold E with one in the hands; E takes it) |
| Spear barrel | 1 log, 2 branches | an open barrel: five spears, dart throwers or muskets stand in it |
| Tanning frame | 4 poles, 1 log | a frame and a fleshing beam: E dresses a deer hide into buckskin (brains or cornmeal, a lit fire beside it) or scrapes it into rawhide |
| Alchemy table | 2 logs, 2 stone | an herbalist's bench: E makes plantain salve, wintergreen tea, ginseng tonic, willow bark tea, slippery elm gruel, elderberry syrup (the teas, gruel and syrup with a lit fire near) |
| Workbench | 2 logs, 2 poles | E: moccasins and fur mitts into your kit, mending worn moccasins, arrows (6), a throwing spear, atlatl darts (2) |
| Stretching hoop | 2 poles, 4 branches | E laces a wolf or fox pelt in; it dries in 2-3 game days (graded by the stretching); E takes the dried pelt down |
| Storage chest | 2 logs | E opens it: the pack beside the chest, a click moves one, a right-click all, Load / Unload everything; kept in the save |
| Woodpile | 2 poles, 2 branches | E stacks the pack's firewood (up to 18); within 3 m of a campfire or hearth it feeds it by itself as it burns low, through the night |
| Smokehouse | 4 logs, 4 poles, 6 branches | a bark hut with a smudge fire: a food larder (E), and raw venison in it smokes to jerky in 20 game hours while the smudge burns (firewood 4 h a stick; a woodpile beside it tops it up) |
| Palisade wall | 8 logs | eight sharpened stakes set in the ground (each follows the ground), a ribband inside |
| Palisade gate | 10 logs | two hewn posts, a lintel, two plank leaves (tap E: open / shut) |

- **Snapping:** pieces are 3 m modules and snap to each other: walls to a floor's edges (outside face out), the
  next wall in line or round a corner (the courses alternate like a notched corner), posts to floor corners and
  wall ends, gables and roof bays to wall tops (a bay goes over the room, between the gables), a hearth to a
  wall's face, the next floor, the next palisade section in line or round a corner. With no socket near, a piece
  goes on the ground under the crosshair on a 0.25 m grid, facing the camera in 15 degree steps. Gables and
  roofs need a wall.
- **Collision:** walls, the window's sill and head, the door and gate leaves, roofs (both slopes), gables,
  floors and the chimney are solid; the doorway and the open gate are not; a door on a raised floor has a ramp
  under its steps so the player walks straight in. Cabin walls and roofs cannot be free-climbed (like the fort's).
- **Take down:** the last choice on the wheel. The piece under the crosshair glows and the prompt says what comes
  back; tap E. Half the cost comes back at Novice, three quarters at Master (Building skill). A piece something
  rests on (a wall under a roof, a floor under walls) has to wait until that comes down first.
- **Building skill:** every piece built gives Building experience (0.3 + 0.08 per log + 0.05 per stone; about
  three one-room cabins to Apprentice).
- The look is the fort's: the same generated log, board, shingle and fieldstone meshes and the processed CC0 Poly
  Haven textures (StructureMeshKit, StructureMaterials). The grass is kept out from under floors and footings.
- What you build is saved with the game (see Saving and death); a new game starts without it, except the fort itself.
- **The fort is built from these pieces** (user 2026-09-28): the palisade, the gate, the firing step along the north wall,
  its ramps and ladders, the two blockhouses and the flag pole are the menu's Fort pieces, stamped free of cost when the
  level is built exactly where `data/building/fort_structure.json` lists them (`FortPlan.stamp_structure`); the cabin, the
  storehouse, the crates and the range are still the level's own. The furnishing on top (`fort_plan.json`) is stamped after.
  Take them down, rebuild them, cut them like any piece. The blockhouses' lower storeys are hollow with a hung door (E).
- **Windows in the palisade:** with the felling axe in the hand, aim at a built palisade (within 1.5 m): "Chop through the
  palisade", 8 strokes cut a piece two stakes wide and 1 m tall, **from belly height up**, measured from where you stand:
  the first piece starts 1 m over your feet (so on the firing step's deck the first cut takes everything from belly height
  to the top, a notch to shoot over; on the ground the next cuts take the next piece up, the third takes the top off; halfway
  up a ramp the piece rises with you); nothing below belly height is ever cut. Build mode's Fort group fills an opening in
  again: Repair (the stakes stand as they were) or Cover with logs (horizontal logs across it; the axe knocks them out).
  The cuts are saved with the game. (`scripts/building/palisade_cuts.gd`)

Tests: `tests/building/test_building.gd` (headless: data and costs, meshes and colliders, sockets and snapping as
numbers, and on the level with the real input path: B, the wheel, hold E, a cabin built piece by piece, notched
corners, what is refused and why, a palisade line with a corner and a gate, E opens the door and the player walks
in, a wall stops them, take down and the refund, a weapon key ends build mode);
`tests/building/building_shots.gd` (windowed: a cabin, its door and inside, a palisade with its gate, the ghost
green and red, take down, walls and posts on a slope).

## Survival: hunger, rest, one clock

The survival core (`scripts/survival/`, the design in `graph_analysis/survival/`) runs in play through **one bridge**,
`scripts/survival_game/survival_bridge.gd` (`SurvivalBridge`). A new game starts as the backcountry hunter on
**Early September 1765 at 08:00**, with the kit's food in the pack (6 lb of jerky, about 2 meals, and 8 lb of cornmeal,
which wants a fire).

- **Vitals** (bottom left, `scripts/ui/hud.gd`; user 2026-09-27: "i like the right more actually and a blue bar under
  it for rested the other badges users can look in the tab to find"): the health bar and its number (the blood still
  to lose dark red behind it; what a lasting harm holds it under shaded grey at its end), **well rested** under it (a
  blue bar counting the sleep's boost down, the hours left; an empty dim track when you are not), and the torch (its
  burn while in the hand; the number carried). Food, warmth, wet, the lasting harms, drink and tobacco are in the
  **Tab** screen's **Condition** tab. The date and hour are the HUD's clock (top centre). A game day burns three meals (a game day is about 46 real minutes); an empty stomach lives off
  the body's reserve for about a game day, then health drains. Worse stages are told on screen.
- **Eating**: **V** eats the best food you carry (safe food before raw meat), or right-click food in the pack.
  Jerky is a third of a meal; a butchered deer's venison is a meal each, raw (1 in 10 turns the stomach) until there is
  a fire; berries and nuts are a mouthful (variety, not a living); cornmeal must be cooked, acorns leached.
  Roast venison and johnnycake are cooked on a campfire (**F**, below).
- **Sleep is a boost, not a need** (user 2026-09-27): you never get tired. **Z** sits you down and sleeps (at night
  until half an hour after sunrise, by day a nap; the night passes in about 8 seconds with the sky) and earns
  **well rested**: 1.5 game hours per hour slept (up to 8 hours' worth), more for better sleep, less on the bare
  ground: eight hours rough earn about 9 hours of it, by a fire 11, in a lean-to 15, in a lean-to by a fire 17
  (bedding is still to come). While well rested you heal three
  times as fast, a plantain poultice heals half again as much, and skills grow a quarter faster. Hunger (beyond
  peckish), cold, wet, a storm or a wolf within 60 m wake you; so does moving or Z.
  **Healing once a day** (user 2026-09-27: "to not cheat well rested you can be well rested multiple times in a day but
  only once a day regain or healths from effects"): a well-rested sleep heals (the faster healing and refill, the
  stronger poultice, the faster clotting, a cure that wants rest, a wound's knitting) only if the last one that healed
  was 16 game hours or more before, so a night's sleep heals night after night, whatever the hour. A nap in between
  makes you well rested again for the skills and sobering up, and heals nothing more; the wake-up line and the
  Condition tab say which it was.
- **One clock**: the core's time drives the sky (the 36-day survival calendar: each game day is the 5th, 15th or 25th
  of its month). **One weather**: the sky's (the visible clouds, rain and storms) is what wets and chills you.
  **One health**: hunger and cold drain the player's health, and a bite counts for the core; neither starving nor the
  cold kills (see Lasting harm).
- Cold slows you; hypothermia stops the sprint. **The cold never kills** (user 2026-09-27: "no death from cold"): its
  drain stops at 15 health. A long cold (about two game hours very cold, one hypothermic) leaves you **chilled to the
  bone** (`lasting_chill.gd`; the health bar shades what it cannot heal to): your health heals no higher than 70%
  and every heal (the body's own, well rested's, a rest or a sleep, a poultice or a remedy) at half speed, until you
  have been **warm and well rested for two game days** (the day's healing sleep only; going cold again starts the
  count over). **In extreme cold**
  (chilled, or a bitter night under -10 C out of doors) a sleep rests only **by a heat source** (a lit fire within 4 m,
  or indoors by a lit hearth: half the sleep or more): otherwise "too cold to rest". A sleep by a heat source is a
  **warm rest**: drink, a hangover or hunger do not cap its boost, and well rested the drink and a hangover wear off
  twice as fast.
- **Lasting harm** (user 2026-09-27: "the pressure is stunted growth and decay people have to fix their toon with";
  `lasting_conditions.gd`): no need kills, but each one neglected long enough leaves a lasting condition that wears
  you down until you put it right for long enough (as chilled to the bone does for the cold). None of them touches the
  aim or the movement speed. Each is told on screen when it comes and when it goes, shows in the **Condition** tab's
  *Lasting harm* with what it does, its cure and how far it has mended, and what is coming on before it does:

  | Condition | From | Does | Cure |
  |---|---|---|---|
  | Wasted | a day starving | heals no higher than 80%, every skill grows 25% slower | two days fed or peckish |
  | The ague | about three hours damp or soaked while not warm | restless (below), heals at 70% | a day dry, warm and well rested (wintergreen tea: half a day of it) |
  | Festering wound | a bleeding wound left undressed six hours | no healing, drains 2 an hour down to half health; then heals no higher than 60% | dress it (a poultice or salve), then half a day (well rested counts double) |
  | The flux | raw meat turning your stomach twice | a meal nourishes half | two days without raw meat (blackberries: 4 hours of it each) |
  | Sore feet | three hours on the move with no moccasins | restless (below) | a night's sleep in moccasins |

  Well rested and wasted now reach the core's own skills too (Hunting, Trapping, Hidecraft...), not only the axe's.

  **Wounds where they land** (user 2026-09-27: "we can see if someone got shot in the stomach"; each place its own cost
  "inline with our current game", not the movement speed). A hit of 8 or more is kept where it landed: head, chest,
  stomach, an arm or hand, a leg or foot, front or back (the nearest of the skeleton's bones to the hit; a wolf bites
  low, mostly the legs). A bleeding wound stays open until dressed (a poultice or a salve), then knits in a game day; a
  bruise (a falling tree, a blow) knits from the start. The day's healing sleep makes it knit twice as fast. While a
  place has one open:

  | Place | Cost |
  |---|---|
  | Head | skills grow 25% slower (as wasted) |
  | Chest | heals no higher than 80% (as chilled) |
  | Stomach | a meal nourishes half (as the flux) |
  | An arm | reloading takes 15% longer, the climbing grip tires half again as fast |
  | A leg | restless (below) |

  **Restless** (a leg wound, sore feet, the ague; user 2026-09-27: "allow rested by fires to make a user well rested but
  decays faster until they are well rested multiple times and it slowly gets better"): away from a fire a sleep rests
  you half as well; by a fire in full. Either way the boost wears off twice as fast, a third less so after each day's
  healing sleep, as ever after three.

  The **Condition** tab shows the body front and back (`body_chart.gd`) under the Body rows: each wound where it
  landed (red open, sickly green festering, linen dressed, purple bruised) and the lasting harms where they sit (the
  flux and wasted on the stomach, the ague on the chest, chilled on the hands and feet, sore feet). Point at a place to
  read what is there.
- **Drink, tobacco and the other vices** (`vices.gd`; user 2026-09-27: each with its trade-off, "no aim sway only for
  drunkenness"): **hold U** to drink and **hold Y** to smoke, a long or a short pull; a thin line shows the pull's size,
  never how drunk. What is taken soaks in over minutes; "You feel merry" is all you are told of drink. Right-click a
  drink or a pipe fill in the pack to take it in hand; laudanum, snuff and a quid are right-clicked to use. Each habit
  is its own (drink, tobacco, hemp, laudanum): it builds with use, fades on sober days, and taken again while addicted
  is a relapse (no well-rested boost for 48 hours). **Withdrawal** nags: addicted and sober, an inner voice speaks up
  every game hour and a half, down to every half hour as the hold deepens (laudanum's sooner), with the pains and the
  talk of one more ("Just one sip. One sip never hurt anyone", "You can always press more cider. It's easy"), and the
  good it would do, argued ("You'd reload 8% faster with a pipe in you. Out here that could be your life").
  Jimsonweed's madness shows nothing on the screen: it is told in words, now and then, and in the Condition tab. Nothing here touches the aim but drunkenness (the sway and the
  spread), nor the movement speed.

  | Vice | How | Upside | Cost |
  |---|---|---|---|
  | Rum | hold U | merry: blows bruise later and less | no well-rested boost while in you; drunk sways the aim |
  | Whiskey | hold U (2 in the kit) | merry fast, a little warmth | twice rum's strength; the habit quicker |
  | Hard cider | hold U | slow to make you merry, a little food | the drink's habit, slowly |
  | Sweet cider | 6 crabapples at the workbench | a little food | none: it turns hard in the pack in two days |
  | Tobacco | hold Y (a clay pipe) | steady: reloads 8% quicker, work a little surer | too many together turn the stomach |
  | Snuff | right-click (1 tobacco: 3 pinches, workbench) | steady at once, about an hour | the tobacco habit |
  | Chewing tobacco | right-click (1 tobacco: 2 quids, workbench) | steady four hours | meals nourish less while chewing |
  | Kinnikinnick | hold Y (bearberry and red-osier, alchemy table) | half the steadiness, no habit | weaker |
  | Kinnikinnick with tobacco | hold Y | most of the steadiness | a light tobacco habit |
  | Hemp tops | hold Y | calm: a sleep rests 25% longer, cravings quiet | hungry sooner, learning slower; a mild habit |
  | Laudanum | right-click (3 in the kit) | 12 hours: every wound's cost gone, the flux stayed, a deep sleep | learning slower; the strongest habit; a second dose within 6 hours knocks you out |
  | Jimsonweed | hold Y | a leaf eases the ague | more: six hours of madness (told in words and shown in the Condition tab; skill checks fail, no rest); a lot: collapse |

- **Beds, racks and crafting stations** (user 2026-09-27: "beds and other craftables ... spear barrels, musket racks,
  leather and tanning stations ... Alchemy"; `camp_station.gd`, `station_work.gd`, `station_menu.gd`, `remedies.gd`):
  in a bough bed or a pole bed the core has its bedding (+2 or +3 C at rest, a better sleep); under a built roof you are
  in your cabin (shelter 5), and a pole bed there is a full night's rest. E at a bed sleeps in it. The drying rack runs
  the core's jerky (10 lb of raw venison a batch make 4 lb, 1-2 game days on the rack over a lit fire; the rack's jerky
  is kept in the core's save). The tanning frame runs the core's hide dressing (a deer hide with brains, which a
  butchered deer now gives, or cornmeal, smoked over a lit fire: buckskin; a Hidecraft check the backcountry hunter,
  at 15 against 35, mostly fails at first, leaving rawhide) and rawhide scraping. The alchemy table makes remedies from
  forage: plantain salve (heals 40), wintergreen tea (warms you through; a lit fire near), ginseng tonic (4 hours more
  of well rested; it lengthens the day's healing rest, not a nap's), and over a lit fire from the new plants:
  **willow bark tea** (brings the ague's fever down, half a day of its cure, and dulls the pain of wounds for six
  hours: their head, arm and leg costs set aside, though they must still knit), **slippery elm gruel** (settles the
  flux, half a day of its cure, and for half a day a meal nourishes in full through the flux or a stomach wound) and
  **elderberry syrup** (chilled to the bone half a day nearer mended); right-click them in the pack. Crafting kneels or stands you at the station with a bar; moving
  stops it and gives the things back; getting peckish no longer stops work or cooking.
- **The workbench, the stretching hoop, the storage chest and the hearth's fire** (user 2026-09-27: "a workbench for
  moccasins, arrows and spears; a stretching hoop for wolf and fox pelts; a storage chest; making the stone hearth burn
  as a real fire indoors"): the workbench runs the core's moccasins (a third of a buckskin and a sinew), fur mitts (a
  pelt and a sinew) and mending (a hide scrap left from dressing a hide), all into the kit the core wears out (a pair
  of moccasins lasts about 32 walking hours; with none left the feet go cold), and makes arrows (2 branches and a
  flint: 6), a throwing spear (a pole and a flint) and atlatl darts (2 branches and a flint: 2) straight into the
  weapons, up to what is carried. Deer now give 2 sinew each. The hoop runs the core's pelt stretching (its Hidecraft
  check grades the pelt) and keeps the pelt drying 2-3 game days in the core's record under its own tag (saved with
  it); dried pelts sew into mitts. The chest (`storage_chest.gd`, `chest_screen.gd`) takes anything loose from the
  pack but the worn gear and the always-carried tools, and its contents are in the save. The hearth's fire is a
  campfire in hearth mode (`Campfire.hearth`): built without wood, smaller, its smoke out of the stack top, the rain
  kept off; under a built roof with a lit hearth within 7 m the core has you indoors (14 C air, no wind or rain, an
  indoor night's sleep: "in your cabin, warm by the hearth").
- **The woodpile, the smokehouse, honest indoors** (user 2026-09-27): a woodpile (`woodpile.gd`) feeds the nearest
  campfire or hearth within 3 m (one pile to a fire): while the fire is lit and down to its last game hour of wood the
  next stick goes on, so a stocked pile carries a fire through a night's sleep. A pile feeding no fire tops up a
  smokehouse's smudge beside it. The smokehouse (`smokehouse.gd`) is a food larder (the chest screen, food only) with a
  smudge fire; its raw venison takes 20 game hours of smoke to become jerky (2.8 lb a venison). Under a built roof the
  core now looks for walls (8 rays at chest height; 6 must meet a wall, door, gate, hearth or palisade): walled, a
  cabin (shelter 5, indoors with a lit hearth); a roof on open sides is an open shelter (3: out of the rain) and never
  indoors.
- **Fireflies in the world** (user 2026-09-27: "i dont want the fireflies around me i want them to be in the world";
  `scripts/wildlife/fireflies.gd`): 26 patches set once from the canopy map over meadows and forest edges (open ground
  with woods round it, the country round the fort first, 45 m apart); at dusk the four nearest within 170 m glow, and
  they stay where they are when you walk on.
- **Fire, cold and shelter** (user 2026-09-27; `camp_link.gd`, `camp_cooking.gd`): every built campfire and lean-to
  has a record in the core, and the core is told four times a second which fire you are at and how far
  (`fire_id`, `fire_distance_m`) and whether you are under a lean-to (`in_shelter`, `shelter_id`). A **lit fire** warms
  (+22 C at 1 m, +12 at 4 m, nothing past 10 m), dries you within 2 m and thaws numb hands and feet; an unlit one
  does nothing. The **lean-to** (quality 3) keeps the wind and the rain off whoever sits under its slope or at its
  mouth. The fire's fuel is its record's, in game minutes (a stick of firewood is two game hours; six at most), so it
  burns on the game clock, through a night's sleep too: stack it before you lie down, or its dying wakes you. Rain
  drowns an open fire. **F** at a lit fire cooks: three venison a roast (roast venison, no raw risk) or up to seven
  cornmeal (johnnycake); you kneel at the fire for a few seconds; moving stops it and the food comes back raw; a
  burnt roast gives charred venison or burnt johnnycake, half the food.
- Off with the user arg `survival=off`; tool and test scripts (`-s`) run without it unless they pass `survival=on`
  (they set the sky's hour themselves).

For the other systems (fire and cold, saves and death, the front end): `SurvivalBridge.find(tree)`; `.core`;
`set_context({fire_id, fire_distance_m, in_shelter, shelter_id, indoors, bedding, near})` for the core's warmth, sleep
and actions; `eat(kind, inv)`, `best_food()`, `pack_meals()`; `sleeper.start()` / `wake()`; `save_state()` /
`load_state(doc)` for the survival half of a save (needs, conditions, the date and hour, weather, the kit, skills);
`revive()` after a respawn (what death costs is for the death rule); signals `needs_changed`, `died(cause)`;
`camp` (`CampLink`: `refresh()`, `told`, `rest_quality()`), `cook` (`CampCooking`: `start(campfire)`, `last`). The pack
mapping (game kind -> core item and amount, the cooked foods, firewood as fuel) is `data/survival/game_items.json`.

Tests: `tests/survival_game/test_survival_bridge.gd -- survival=on survival_seed=7` (headless: start, clock, hunger
and eating, the body, health and death, sleep and well rested, weather, saves); `tests/survival_game/survival_shots.gd`
(windowed); `tests/survival_game/test_camp_bridge.gd -- survival=on survival_seed=7` (headless: the context, the fire's
warmth and fuel on the game clock, rain, the lean-to, cooking, sleep quality and the fire waking a sleeper, a winter
night); `tests/survival_game/test_camp_stations.gd -- survival=on survival_seed=7` (headless: the grouped menu, the
racks, beds and a cabin roof, jerky, tanning, remedies, the station menu); `tests/survival_game/stations_shots.gd`
(windowed); `tests/survival_game/test_workshop.gd -- survival=on survival_seed=7` (headless: the chest and its save,
the workbench's six things, a pelt on the hoop, the hearth lit, in the rain, indoors, cooking);
`tests/survival_game/workshop_shots.gd` (windowed); `tests/survival_game/test_lasting_chill.gd -- survival=on survival_seed=7` (headless: no death from the cold, chilled
to the bone, no rest in extreme cold without heat, two days' recovery, the warm rest over drink);
`tests/survival_game/test_lasting_conditions.gd -- survival=on survival_seed=7` (headless: each lasting condition coming on,
its effects, its cure, what sets it back; the Condition tab, the icons, the save; no one dies);
`tests/survival_game/lasting_shots.gd -- survival=on` (windowed: the vitals, the Condition tab);
`tests/survival_game/test_woodpile_smokehouse.gd -- survival=on
survival_seed=7` (headless: a woodpile carrying a fire through a night, the smokehouse smoking venison, the chest screen
clicked through with real mouse and key events); `tests/wildlife/test_fireflies.gd -- birdlife=on`.

## Saving and death

The game saves itself and dying costs your pack (`scripts/save/`).

- **F5** quick saves; **F9** loads the latest save (quick or auto). The game **autosaves** when you wake from sleep,
  every 5 minutes, after a respawn, and when you quit. **Launching the game continues the latest save**; the user arg
  `new_game` starts fresh (the main menu will choose, later). Saves are JSON in `user://saves/frontier/` (`quick.json`,
  `auto.json`), written whole or not at all.
- A save holds the survival core (needs, conditions, the date and hour, the kit, skills), the sky and weather, the
  player (where, health, the pack, what they wear, the weapons' state, the torches, the gathering skills), the felled
  trees, stumps and quarried rocks, what you built (doors, the campfires and their coals, the fort's pieces and the
  windows cut in its palisade, the gate's door), weapons and torches lying about, the animals (alive and dead, how far they are butchered), where the
  horse stands (a load it was dragging is left lying), the wheelbarrow and the horse cart (where they stand, what is in
  them, the horse still in the cart's shafts), the picked plants, and your home and dropped packs. Loading rebuilds the level from its seeds and
  applies the save on top. A save from another forest layout keeps everything but the felled trees and the picked
  plants, and says so.
- **Death**: *You died* (or starved, froze, bled to death), and 5 seconds later you wake **where you last slept** (the
  fort's yard until you have slept anywhere) with what you wear and your skills. **The pack's contents and the torches
  you carried stay where you fell**, a leather bag on the ground, unmarked: remember where you fell (user 2026-09-27:
  "it should be on the user to remember"). **E** at it: *Take back your pack*. Food left lying goes to scavengers: after 2 game hours,
  a unit an hour (the venison and jerky first).
- The animation debug keys that were on F5 and F9 moved to **Shift+F5** (freeze) and **Shift+F9** (light hit).
- Off in tool and test scripts (`-s`) unless they pass `save=on` (and then no save is continued on its own, and the
  saves go to `user://saves/frontier_test/`, never over the player's).
  `SaveGame.find(tree)`: `save_game(slot)`, `load_slot(slot)`, `build_doc()`; each system's part is a
  `save_*` / `load_*` pair in `SaveParts`. `DeathRule.find(tree)`: `home`, `respawn()`, `drop_pack(at)`.

Tests: `tests/save/test_save_game.gd -- save=on survival=on wildlife=on survival_seed=7` (headless: change every
system, F5, load and compare, the forest-layout guard, death and the dropped pack, scavengers, taking it back);
`tests/save/test_cart_save.gd -- save=on wildlife=on` (headless: the horse cart hitched with goods, a deer and logs in
it, and with the wheelbarrow in it, saved and loaded);
`tests/save/save_shots.gd -- out=/abs/dir save=on survival=on` (windowed: dead, home, at the pack).

## Wild food and herbs

Berries, nuts and herbs grow in the woods round the fort where they would (`scripts/forage/`, plants and numbers in
`data/forage/forage.json`; the plants are the project's own models). Every one of them is also deer food, so a patch
in season is where the deer feed. **E** at a plant picks a handful into the pack: the player bends, reaches or kneels
to it (the extracted Actor_B clips: pick-flower for low plants, a search low, at a metre or high), a bar fills, then
*+1 Blackberries*. Moving, jumping, aiming or a hit stops it with nothing taken.

| Plant | Where | Gives | In season |
| --- | --- | --- | --- |
| Blackberry bramble | the woods' edges and clearings | blackberries | late July to early September |
| Wild strawberry | the open ground | wild strawberries | June |
| Plantain | where people walk: round the fort, by the range lane | plantain leaves | May to October |
| Wintergreen | under pines and hemlocks | wintergreen (leaves; red berries from mid September) | all year |
| Ginseng | shaded maple woods, scarce | the root (a dug root does not grow back) | mid August to October |
| Oak | under the oaks | acorns (a quarter of them down in late August) | late August to November |
| Hazel | the hazel shrubs | hazelnuts | late August to September |
| Black willow | the damp hollows | willow bark | all year |
| Yarrow | the open ground, by the paths | yarrow (white flower heads June to September) | May to October |
| Slippery elm | young trees in the low, rich ground | slippery elm bark | all year |
| Elderberry | damp thickets along the hollows | elderberries | mid August to September |
| Hemp | run wild round the fort and the lane | hemp tops | late July to September |
| Bearberry | a mat at the edges of the pines | bearberry leaves (red berries late summer to spring) | all year |
| Red-osier dogwood | the damp hollows, blood-red stems | red-osier bark (white berries in August) | all year |
| Jimsonweed | the trodden ground round the fort | jimsonweed (flowers, then spiny pods) | July to October |
| Crabapple | small trees at the woods' edges | crabapples | September and October |

The last nine (user 2026-09-27: "we will need more plants and herbs for these new things") are for the remedies and,
next, the vices. The low ground is a hollow that lies a metre or so below the ground round it, where it stays damp.
A plant that bears once a season (crabapples, hazelnuts) bears again when its season comes round.

- The game's date (25 August unless the clock runs) decides what is ripe; out of season or picked clean the prompt
  names the plant and **E** says when it bears. Picked plants fill again over a few game days while in season.
- A patch deer have fed at says so in its prompt: *(deer have been feeding here)*.
- **Plantain**: right-click (or double-click) it in the pack for a poultice on a wound, 15 health over 20 seconds.
  **Yarrow** packed into a wound closes nine tenths of the bleeding at once (the rest in a second or two) and heals a
  little. Elderberries and crabapples are food; hemp tops, bearberry, red-osier bark and jimsonweed keep for the vices.
- **Deer feed at them**: a herd's feeding places (WildlifeSpawner.find_place) go to the food plants in its range,
  the richest pulling most, and a grazing deer eats from the patch it stands in (the ripe food first, so less is left
  for the player). Find the berries, the acorns, the strawberry leaves of the season and you find the deer.
  `ForageField.find(tree)`: `deer_spots()`, `deer_feed_spot()`, `deer_eat()`, `deer_food()`.
- The low plants push the grass back where they grow (the grass blocker map), so the grass does not bury them.

Tests: `tests/forage/test_forage.gd` (headless: data, calendar, placement and habitats, seasons, picking with the
real E, deer, the poultice through the pack); `tests/forage/forage_shots.gd` (windowed: each plant, picking, the pack,
and the frame time with the plants shown and hidden).

## Farming

Beds of the Three Sisters, tobacco and flax, hoed out of open ground (user 2026-09-28: "add farming into the game";
`scripts/farming/`, numbers in `data/farming/farming.json`; the crops are the project's own models, built from the
forage plants' parts).

- **The hoe** is made at the forge (2 bar iron, 2 charcoal, a pole) or traded for; it is not in the kit. A start with
  nothing makes a **digging stick** (a pole and a knife, at the knapping stone or the workbench), half the hoe's bite.
  **7** cycles the felling axe, the mattock and the hoe.
- **Breaking ground**: with the hoe out, hold **LMB** at open ground: a 2 m bed on the world's grid, about five strokes
  (fewer with skill), the grass cleared off it. Not on rock, water, a steep slope, among trees or where a building
  stands; the ground is frozen from December to February.
- **Sowing** (**E** at a worked bed; hold **E** for the list), March to October, from the pack's seed: the **Three
  Sisters** (a seed each of corn, beans and squash: the beans climb the corn and the squash shades the hills; they
  yield more together), or corn, beans, squash, tobacco or flax alone. A new character has a pouch of seed (corn 6,
  beans 6, squash 4, tobacco 3, flax 4); every harvest saves a little seed back.
- **Growing** on the game's clock (a sleep moves it on): sprouts, young plants, grown, ripe, in 3 to 4 game days (a
  game day is a third of a month). Weeds come up a third and two thirds of the way: hoe them out (**LMB**) for a
  better harvest; rain on the bed helps a little. November's frost kills what is not ripe (a late sowing warns).
- **Harvesting** (**E** at a ripe bed): ears of corn, beans, squash, tobacco leaves or flax into the pack, by the
  weeding, the rain and the **Husbandry** skill (a field skill like Woodcutting; it trains on every stroke, sowing and
  harvest, and raises the yield). The bed is ready to sow again.
- **The crops**: roast corn and squash and boil beans on a lit campfire (**F**); pound 4 ears into a pound of cornmeal
  at the knapping stone; twist 3 tobacco leaves into tobacco for the pipe and 2 flax into cordage at the workbench.

The beds are records in the survival core's world (`core.state.world.farm`), saved with it. `FarmField.find(tree)`;
the hoe's side is GatherTools' `"ground"` target (`FarmField.ground_candidates`, `strike`, `hoe_prompt`).

## Horses

A stocky 14.1-hand colonial saddle horse stands saddled near the start (the project's own model; the riding
clips are extracted Actor_B data, see CREDITS.md). **E** at its saddle mounts it: W / S go and stop, A / D steer,
Shift spurs it up a gait, Alt holds a walk, Space jumps from a canter; **hold E** (half a second) to get off.

- **Leading** (`scripts/horse/horse_lead.gd`): **E** at the horse's head, *Lead horse*: it follows you on a lead
  rope at a walk, trots when you run (canters only to catch up), comes up on your right and stops when you stop,
  and steers round trees, rocks and walls. **E** at its head again, *Stay*, and it stands.
- **Hauling logs** (log skidding, the period's way of getting timber out of the woods; `horse_haul.gd`,
  `skid_load.gd`, `log_pile.gd`, numbers in `data/horse/haul.json`). Fell a tree, bring the horse up so its
  hindquarters are by the butt (lead it, or ride up and stop), then **E** at the butt, *Hitch the white pine to
  the horse*: the tree is limbed and topped (its crown's firewood and branches go into the pack) and the bole
  (what is left of it after any logs bucked off) is chained behind the horse on a singletree. From the saddle a
  tap of **E** does the same with a butt behind the horse. Ride or lead the horse on: the log drags on the ground,
  slides round trunks, cuts the corners and swings behind on turns, and rides up over stumps and rocks. Its
  weight slows the horse: a light log lets it trot, a big bole it takes at a walk or a crawl, and one it cannot
  start is refused (*Too heavy for one horse (about 1,900 kg): buck logs off it*). Caught square on a tree or a
  rock the horse stops: turn it to free the log (after a few seconds the log is worked free). Stopped, **E** at
  the load (or a tap in the saddle): *Unhitch*; the bole lies where it is, to be bucked into logs with the axe or
  hitched again by either end. **E** at the horse's hitch with logs in the pack chains a bundle of up to six;
  unhitched it is laid down as a pile, and **E** at the pile takes the logs back.
- **Hauling game** (`carcass_load.gd`, weights in `haul.json` "carcass"; user 2026-09-26). A shot deer, buck, wolf or
  fox, once it lies still, is dragged home to be skinned instead of where it fell: bring the horse up so its hitch
  is near the carcass, then **E** at the animal's **neck**, *Hitch the deer to the horse* (looking at its body, E still
  skins it where it lies), or a tap of **E** in the saddle. A rope goes round its neck from the singletree and it is
  dragged head first on its side, over bumps and round trunks like a log; at 6-80 kg it leaves the horse its trot.
  **E** at it (or a tap in the saddle, stopped) lets it go where it is, to be skinned or hitched again. On the rope
  it cannot be skinned and is not cleaned up; a hauled carcass lies another ten minutes from where it was let go.
- **Dragging game on foot** (`foot_drag.gd`, numbers in `haul.json` "foot"; user 2026-09-27). With no horse by it,
  **E** at a dead animal's **neck**, *Drag the deer*: your gun goes on your back and a short rope from your left
  hand drags it head first behind you as you walk, the same rope and ground as the horse's. The right hand stays
  free: **T** puts a lit torch in it, to see and to keep wolves off at night. Its weight sets your pace: a fox at a
  jog, a wolf or a doe at a slow walk (about 1.1 m/s), a buck slower (about 0.8 m/s); no sprint, and anything
  heavier, or uphill, slower still, down to an extreme crawl (nothing is too heavy on foot, only very slow). Caught on a trunk, the rope holds you: step round it. **E** again,
  *Let go of the deer*, and it lies there to be skinned or dragged on, and your gun comes back to your hands. A
  jump, drawing a weapon, a heavy hit, mounting, kneeling to work or a vault also let it go. With the horse's
  hitch by the neck, E there ropes it to the horse instead.
- **Pulling a log on foot and log barricades** (`log_pull.gd`, numbers in `haul.json` "foot_log"; user 2026-09-27:
  "a wall against a raid"). **E** at either end of a log, *Drag the white pine log (about 280 kg)*: your gun or axe
  goes on your back (a torch back into the pack), you take hold of a rope round its end with both hands and pull
  it walking backward, the source's pull clips: **S** pulls it back, **A / D** step sideways and swing it round;
  the mouse turns the camera while you keep facing the log. The weight sets the pace, from about 0.65 m/s for a
  light log to a crawl: one 2.4 m length of a middling pine, birch or maple (about 250-420 kg; these are game
  values) at a crawl; a longer trunk, a hemlock's or an oak's at an extreme crawl (*... very slow*; nothing is
  refused; bucking it shorter or the horse is far quicker). **E** lays it down, straight and level where it is; pulled against a log already laid, **E**
  stacks it on top (*Stack the log on the barricade*), up to three high: crouch behind two, stand and shoot over
  three. A laid log stays put, stops a musket ball and is saved; **E** at a stack's end takes the top log again.
  A jump, a weapon key, a heavy hit or death let go (the log lies loose).
- **The wheelbarrow** (`wheelbarrow.gd`, numbers in `haul.json` "wheelbarrow"; user 2026-09-27: "instead of dragging
  if the has a wheel borrow it can be faster"). One stands near the start (saved where you leave it). **E** at its
  handles, *Push the wheelbarrow*: your gun or axe goes on your back (a torch back into the pack), both hands take
  the handles and it rolls before you as you walk, stopping at trunks and walls. Its load sets the pace, faster than
  dragging: empty at a jog (2.4 m/s), a doe at 1.8 m/s (dragged, 1.1), a 160 kg log length at about 1.2, heavier
  slower still; no sprint. **E** again sets it down (so do a jump, a weapon key, a heavy hit, sleep or death).
  **E** at its bed: *Put the deer in the wheelbarrow* (a dead animal lying by it), *Put the log in the wheelbarrow* (a
  log of one length by it), or *Load the wheelbarrow*: the chest screen, the pack beside the bed, a click moves one,
  a right-click all of a kind, and **Load everything** / **Unload everything** move it all at once. What is in it
  shows in the bed. With a deer or a log in it, **E** at the bed tips it out beside it.
- **The horse cart** (`horse_cart.gd`; user 2026-09-27: "attach wheelbarrel to horse and create a carrage where we can
  add more things", the two-wheeled cart, "with this and wheelbarrel it allows for automation"). A box bed on two big
  spoked wheels between shafts; one stands by the demo horse. With a horse by its shafts (led there, or ridden up and
  stopped), **E** at the shafts (or a tap in the saddle) *Hitch the horse to the cart*: the horse goes between the
  shafts, the cart behind it. Whatever moves the horse moves the cart (ridden, led, and so later a horse sent along a
  route by itself): it trails round a turn and swings behind, up to 25 degrees off the horse's line, the wheels on the
  ground each its own. Its weight and what is in it, rolled over rough ground and up the slope, caps the horse's pace:
  empty at a trot (3.2 m/s), 700 kg in it a little slower (2.8), up a slope slower still. Two trunks the horse slips
  between and the cart cannot stop them both ("The cart is caught: turn the horse to swing it clear"); held a few
  seconds it is worked free. **E** at the tailboard (hold E for the list): *Put the deer in the cart* (two side by
  side, one over them), *Put the log in the cart* (up to six, along the bed), *Put the wheelbarrow in the cart* (it
  rides alone in the bed with whatever is in it: take it out where the cart can go no further and push it on),
  *Take out* what went in last, or *Load the cart*: the chest screen, as the wheelbarrow's, the goods shown in the
  bed. At most 700 kg in it. Saved with the game: where it stands, the horse still in its shafts, the goods, and the
  deer, logs or wheelbarrow in the bed.
- **Wild horses** (`scripts/wildlife/wild_horse.gd`, `scripts/horse/horse_breaking.gd`; user 2026-09-28: "a herd of
  wild horses that can be tamed"). Bands of them live on the open land east of the fort (and the fields and the lake
  shore), and one band of strayed woods horses in the fort's own woods: a stallion and three to seven mares, a mare
  leading and the stallion at the back, the project's own horse in bay, dun, chestnut, brown, black or grey, no tack.
  They have the deer's and the bison's herd brain (grazing heads down, one standing sentry, bedding down in the open,
  bolting together, keeping away from where they met danger). They see nearly all the way round (only straight behind
  is blind), hear and smell well, and outrun anything, but they **tire**: run hard, a horse falls off to a trot and
  can be caught (chase a band on your own horse and the one that tires drops behind). A crowded stallion rears and
  strikes; one behind a fresh horse gets kicked. **Catch**: **G** at its side (not its head: it bolts, or the
  stallion rears at you) grabs a fistful of mane and swings you up bareback; from the saddle, riding alongside it, G
  takes you across onto its back. Its band bolts. **Break it**: it bucks, crow-hops, rears, spins and bolts. Under the
  crosshair a ring shows your balance as a dot, a mark on the ring's edge the way it is throwing you, and round it
  the horse's spirit. **W A S D** shift your weight and move the dot: lean against the throw (a buck throws you
  forward: S; a rear back: W; a spin outward: lean into it). The dot out of the ring, or the grip's stamina spent
  (its own ring, draining faster the further off balance you are), and you are thrown (knocked down and bruised).
  **G** lets go (off on your feet). Each move you sit takes some of its spirit, more the better you sat it; none
  left, it is **broken** and yours: ridden, led and hitched like any horse, with a rope bridle for the reins and no
  saddle, kept in the save. A horse that threw you runs off wild again but remembers the ride: the next one is
  shorter. A tired horse (run down first) has less spirit, a hurt one too; a fresh stallion is the hardest ride.
  Shot, a wild horse is game like the rest (rawhide, venison, sinew, tallow).
- Not yet: a sled (snow), a four-wheeled wagon, several horses in a team, the harness as a model (it is drawn),
  keeping a load on a rope through a save (a save leaves it lying where it is), game packed across the saddle,
  laying a log from the horse's chain straight into a barricade (unhitch it, then pull it into place on foot).

Tests: `tests/horse/test_haul.gd` (headless: the pull table and weights; on flat ground the drag, the cap, turns,
a stump, a trunk, a jam, unhitching, bucking, a bundle; leading with trunks about; in the level with the real E:
lead, fell, hitch, ride, unhitch in the saddle, a bundle and its pile; a carcass on flat ground and in the level:
Hitch at the neck and Skin at the body, ride with it, let it go, skin it; run with `wildlife=on` for the spawner's
own deer); `tests/horse/haul_shots.gd` (windowed); `tests/horse/test_foot_drag.gd` (headless, the level with the
real keys: the offer at the neck, the drag and its pace, no sprint, the rope, the left arm back along it, a torch in
the right hand, letting go by E, a jump, a weapon key and a heavy hit, a buck against a doe, the horse's E first);
`tests/horse/foot_drag_shots.gd` (windowed: the offer, dragging from behind and the side, at night with the torch);
`tests/horse/test_log_pull.gd` (headless, the level with the real keys: limbing a felled tree, a length bucked off as
its own log, too heavy, pulling with S and A, laying, stacking three high, the top log taken, cover, the save, a jump);
`tests/horse/log_pull_shots.gd` (windowed: a felled tree and limbed, pulling, the barricade crouched behind and aimed
over); `tests/horse/test_wheelbarrow.gd` (headless, the level with the real keys: pushing, its pace, the grips in the
hands, a trunk, setting down, a deer and a log in and out, pack things and Load / Unload everything, the save, a
jump); `tests/horse/wheelbarrow_shots.gd` (windowed: parked, pushed, a deer, a log, the screen, a load in the bed);
`tests/horse/test_horse_cart.gd` (headless: parked, hitched, drawn round a turn, its pace empty and loaded, goods, a
deer, logs, the wheelbarrow in and out, caught between two trunks and worked free, unhitched, ridden with the real
keys); `tests/wildlife/test_wild_horses.gd` (headless, `-- wildlife=on`: the bands, gaits, grazing, flight and
winding, G at the head, behind and at the side, a ride broken with the real keys, riding it, the save, a rider
thrown and the horse wild again, the catch from the saddle, the carcass).

## Layout

```
scripts/player/   player.gd (controller, camera, weapons), player_anim.gd (AnimationTree built in code),
                  bone_mannequin.gd (stand-in body for the unskinned rig)
scripts/torch/    the torch: PlayerTorch (T, pack, toss), DroppedTorch, TorchFire (flame, light), TorchState, TorchModels
scripts/weapons/  weapon.gd (spread, launch), bow.gd, firearm.gd, musket.gd, pistol.gd,
                  projectile.gd (ballistic arrows/balls), weapon_models.gd (placeholder meshes)
scripts/world/    frontier_level.gd (fort, range, forest), target_dummy.gd
scripts/gathering/ gather_tools.gd (tools, strokes, targets), veg_harvest.gd (felled / cut / quarried vegetation),
                  felled_tree.gd (the fall, bucking, the stump), gather_skills.gd, tool_pose.gd, gather_models.gd
scripts/survival_game/ survival_bridge.gd (the one bridge to the survival core), survival_sleep.gd (Z),
                  camp_link.gd (campfires and lean-tos to the core), camp_cooking.gd (F at a fire), camp_station.gd
                  (beds, the drying rack, the tanning frame, the alchemy table, the workbench, the stretching hoop),
                  station_work.gd + station_menu.gd (working at a station, its menu), remedies.gd,
                  provision_models.gd (the food, hide and remedy icons)
scripts/forage/   forage_field.gd (placing, drawing, E, seasons, deer), forage_models.gd (the plants), forage_pick.gd
                  (picking), forage_use.gd (the plantain poultice, yarrow)
scripts/horse/    horse.gd (gaits, jump, hills), horse_mount.gd (E), rider_link.gd, horse_lead.gd (leading on foot),
                  horse_haul.gd / skid_load.gd / log_pile.gd (log skidding), carcass_load.gd (hauling game)
scripts/building/ build_mode.gd (B, the ghost, placing, take down), build_snap.gd (sockets, validity),
                  build_geometry.gd (meshes, colliders), build_world.gd / built_piece.gd (the placed pieces),
                  build_door.gd (doors, gate leaves), build_hud.gd, build_grass.gd, build_data.gd,
                  fort_pieces.gd / fort_plan.gd (the fort's pieces and their stamping), palisade_cuts.gd (windows)
scripts/ui/hud.gd, scripts/fx/fx.gd, scripts/core/ (input, hit routing)
animations/, characters/   Actor_B library + rig from Player_Animation_Project/godot_export
tests/            smoke_test.gd (headless gameplay test), screenshot.gd, compute_weapon_offsets.gd
```

Headless test:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path ~/Downloads/Frontier -s tests/smoke_test.gd -- --no-capture
```

Loading: the level builds everything in code in `frontier_level.gd` `_ready()`. The player's rig (the 77 MB Actor_B
library) is not preloaded; it loads on a worker thread while the world is built (`scripts/core/background_load.gd`),
and `StartupPrefetch` requests the level's meshes, textures and sounds on worker threads first
(`data/startup/prefetch.json`; re-record it with `python3 tools/perf/startup_prefetch_list.py` after big content
changes). Phase times: `-- startup_profile=1` (or `=quit`), or `python3 tools/perf/startup_times.py [--headless |
--editor] [--runs 3]` (min and median per phase); test: `tests/perf/test_startup.gd`.

## Gathering sounds

Mining, chopping and felling sound like iron on stone and wood (`audio/sfx/gathering_rec/`): each sound is layered
from real CC0 recordings (Kenney, kheetor, rubberduck; see CREDITS.md and the folder's `SOURCE.md`) by
`tools/sfx/gathering_rec.py`, with a little synthesis only where the recordings lack something. Several variants of
each, a random pitch and level per play and never the same variant twice in a row. `GatherSfx`
(`scripts/audio/gather_sfx.gd`) picks the sound for each event.

| Sound | Heard as |
|---|---|
| `gather_rec_pick_rock` | The mattock on rock: a sharp contact click, a short bright ring of the iron head (inharmonic, gone in under 0.1 s), the stone's dull knock, then chips and grit scattering and settling |
| `gather_rec_pick_rock_hard` | A stronger stroke that bites deeper: more knock and chips, a shorter ring (more often as Mining grows) |
| `gather_rec_rock_split` | A piece breaks off: a lower crack, grit trickling, the chunk dropping, rubble |
| `gather_rec_rock_depleted` | The last of the outcrop gives way: a big break, blocks dropping, a slide of rubble over a rumble |
| `gather_rec_axe_chop` / `_big` | The felling axe into a standing trunk: the bite, the trunk's woody thock (deeper and longer in a big trunk), a chip flying |
| `gather_rec_axe_chop_sapling` | A sapling: lighter, higher and springy, its leaves shivering |
| `gather_rec_buck` | Bucking a log on the ground: drier, shorter, damped by the ground |
| `gather_rec_tree_crack` | The hinge lets go: fibres cracking faster and faster, the trunk groaning, a last long tear |
| `gather_rec_tree_fall` | The crown rushing down through the air and the neighbours' branches, peaking as it meets the ground |
| `gather_rec_tree_land` | The trunk hits the ground: a heavy thud and a bounce, branches crunching, leaves and twigs settling |

They play on the World bus (outdoor reverb), arrive late from afar (sound travel) and carry by their size (a sapling
80 m, a chop 220 m, a tree landing 400 m). Test: `tests/audio/test_gather_sfx.gd` (headless).

## Sky and weather

A day of about 48 real minutes over the Mohawk Valley in 1765 (`scripts/world/env/`: `WorldClock`, `DayNight`).
The clouds are volumetric and sit at their real heights over the curved Earth (`shaders/sky/cloud_engine.gdshaderinc`):
fair-weather cumulus that build through the afternoon, a stratocumulus deck when it is overcast, cirrus and a
cirrostratus veil, and storm fronts (`WeatherSystem`) that appear as towers on the upwind horizon a few real minutes
before they arrive: the anvil dims the sun, a gust front bends the trees, then heavy rain, lightning and thunder
(delayed by the distance), then a trailing rain deck and crisp clearing air. A cloud over the sun shades the ground.
The stars are the real sky precessed to 1765 (Polaris 1.95 deg from the pole). They stay sharp while the camera
turns: Godot's TAA has no motion vectors for the sky, so `SkyMotionVectors` (`scripts/world/env/sky_motion_vectors.gd`,
a CompositorEffect on the WorldEnvironment) writes them from the camera's rotation (the stars kept 0.4x of their
brightness in a turn without it, 0.75-0.9x with it; a still view is unchanged).

The sun and the moon cross the sky where they really stand (`WorldClock`; the moon as seen from the ground, with its
parallax and its distance), drawn larger than life so they read on screen (`scripts/world/env/sky_bodies.gd`:
`SUN_DISC_SCALE` 2, `MOON_DISC_SCALE` 2.5; the real discs are about 6 px at 70 deg). The sun's disc is limb-darkened
with a small glow, turns orange and dims toward the horizon, and the sky's glare round it is rolled off so it is never
lost in a white blowout. The moon shows its phase (the lit side toward the sun, tilted as it really is on the sky),
the near side's seas and highlands (a procedural map: `tools/environment/sky/make_moon_map.py`), earthshine on a young
or old crescent, a faint halo at night; it is pale in the daytime sky and orange near the horizon, and a bright moon
hides the stars round it. Clouds pass in front of both.

Under the trees (`scripts/world/env/forest_light.gd`, `scripts/world/vegetation/canopy_map.gd`,
`shaders/common/canopy.gdshaderinc`): a crown-cover map baked from the vegetation layout lets the terrain, grass,
ferns, trees and impostors take part of the sky light under the canopy and add the green-gold light the leaves scatter
down (from the sun and the sky); the near trees' crown hulls cast dappled shadows with sunflecks that move with the
wind (`shaders/vegetation/canopy_dapple.gdshader`, in place of the old alpha-card shadow proxies); thin leaves glow
against the sun or the moon; the eye opens slowly under the canopy (no pumping between forest and clearing); the air
under the leaves is dimmer and greener, and the rain still shows; at night the night sky gives a faint fill and
colours fade toward grey (rod vision), so a moonless forest is dark but not black. The crown blobs stay out of SDFGI
while it runs (black pockets under the trees otherwise). `forest_light=0` turns it off; add `veg_dapple=0` for the
shadow casters from before.

| Dev key | Action |
|---|---|
| Shift+F6 / Shift+F7 | One hour back / forward |
| Shift+F8 | Weather: clear, fair, overcast, storm approaching (cycles) |

Tests: `tests/env/test_weather.gd` and `tests/env/test_sun_moon.gd` (headless: the moon's place against Meeus's lunar
series (~0.1 deg), its phase and the tilt of its bright limb against the astronomical position angle, its orientation,
distance and parallax, the discs' colours),
`tests/env/weather_mirror_check.gd` (windowed: the sky's clouds against their CPU mirror). Captures and cost:
`tools/environment/sky/sky_shots.gd`, `tools/environment/sky/sky_cost.gd`, `tools/environment/sky/sun_moon_shots.gd`
(the sun's arc, sunrise and sunset, the moon across a night and through its phases, the day moon, clouds passing in
front; it also checks the rendered discs against their CPU mirror). The forest light: `tests/env/test_forest_light.gd`
(headless), `tools/environment/lighting/forest_light_shots.gd` (every time of day and weather, in the forest, at its
edge and in the open), `tools/environment/perf/forest_probe.gd` (`veg_dapple=cards`, variants `shd3_off` = the
current setup, `pre_forest_light`).

front; it also checks the rendered discs against their CPU mirror), `tools/environment/sky/star_motion.gd` (windowed:
the stars' brightness and width while the camera turns, tilts, walks and runs, against a still view; `fix=0` shows the
engine's TAA alone).

## Snow and the seasons

Winter is real (`scripts/snow/`): the survival core already turns the sky's rain to snow below freezing and keeps the
snow on the ground (building while it snows, settling, melting in a thaw, deepest in January and February); `SnowCover`
shows it. The ground whitens with the depth (`shaders/common/snow.gdshaderinc`: thinner under the crowns and on the
trodden paths, patchy while it is thin), the grass is buried as it deepens (tall straw still stands out of it), snow lies
on the trees (the pines hold it), the rocks, the roofs, the palisade's tips and the ledges and banks against the walls,
but not under a roof (a shelter map built from the level's colliders, rebuilt when a building piece goes up). Flakes
fall round the camera in place of the rain, drifting with the wind. Whoever walks the snow leaves prints: the player,
the spouse, the horse (hooves), the deer, wolves, foxes and bison, each their own stride; new snow fills them in
(`SnowPrints`: pressed into a trail map round the player, kept as records for tracking: `prints_near()`). Footsteps
crunch; deep snow slows walking (snowshoes help: `survival_conditions.gd`).

The broadleaves' year (`scripts/snow/season_leaves.gd`, `shaders/vegetation/leaf_season.gdshaderinc`): the maples,
oaks, birches and hazels turn from mid September (each its colours), are in full colour by mid October, drop their
leaves through November (the first lasting snow brings down the last) and stand bare to April, when the buds break
and the leaves come back; the white pines and the hemlocks stay green. Tree by tree over the whole world, the same in
every level of detail and at every distance: the maples first and the oaks last, whole stands ahead of others, the
high ground sooner; the woods turn patch by patch. The shade follows: a bare tree's shadow thins to its limbs' and the
woods under the bare crowns open to the sky (the canopy map keeps the evergreens' cover apart). The forest is about
58 % hardwood. The forest floor greens with moss and herbs after the buds, fades in the autumn under fresh fallen
leaves and lies brown in winter; the ferns turn golden then russet, die back over winter and unfurl again in spring.
The undergrowth: hazel and young trees under the canopy, fern beds, downed logs and big windthrown trunks with their
root plates. The grass cures to straw through the autumn and stands tan over the winter.

Herbs and wildflowers come from the grass itself (`shaders/grass/grass.gdshader` `pick_herb`, the cards painted by
`tools/environment/terrain/make_herb_atlas.py`): some of the tufts the GPU already draws round the camera become a plant
instead, by chance and in drifts, with no placement on the CPU and no objects of their own, everywhere there is ground.
Under the trees fern beds (golden then russet in the autumn, died back in winter), wood sorrel, mayapples, and the
spring's trilliums and violets; in the open black-eyed Susans and wild bergamot in the summer, goldenrod and asters from
August into October, each in its days of the year (the `season_day` global). None of them is a forage plant: what can
be picked is still placed by `ForageField`.

| Dev key | Action |
|---|---|
| Shift+F10 | Snow test: a snowing January morning, then a clear winter day with the snow lying, then back |

Tests: `tests/snow/test_snow.gd` (windowed: the cover, the falling snow, prints and their filling in, the footsteps,
the shelter, the slowed walk; `shots=<dir>`), `tests/snow/test_seasons.gd` (windowed: the calendar, the snow stripping
the last leaves, the winter canopy; `shots=<dir>`: two views of the woods in every season).

See CREDITS.md for animation provenance.
