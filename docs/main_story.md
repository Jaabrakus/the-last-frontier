# Two Fires: the main story, GTA-style

DRAFT v6 (2026-10-03): section 0, the parents' prologue, comes first and overrides v5 where they
differ. v5 (2026-10-02) replaced v4's arc with the owner's new spine (2026-10-02): "you are
primitive, then the user finds a whole new world of wonder with sky galleons, then the main
character gets to a world with pyramids, a bustling world." It starts from the design the judges
rated highest (the "systems" draft: four loops, the Sway, the city of Vessary). It grafts the best
ideas the judges named from the other two drafts ("character" and "history"), and fixes the
weaknesses they listed. It keeps v4's framework: storylines as data, free roam, reputation per
community, joining communities, the consultation rule and the Decided list.

The research is in `docs/research/`. Where `critic.md` corrects a report, the critic wins. Maps are
in `docs/maps.md`.

Basis keys: **S** a source, **H** history still to check before it becomes in-game text, **D** our
own design. Every invented name needs a collision check before it ships: not a real people, place
or sacred word, and not a name from Disney or Nickelodeon.

## 0. v6: the parents' prologue (owner, 2026-10-03)

The owner set a new opening on 2026-10-03. It overrides v5 wherever they differ: the logline (6.2),
the lead (9.1), Act 1 (10.1) and the start of Act 2 (10.2, missions 11-13). Sections 6-18 below are
still v5's text until they are rewritten to match this.

### 0.1 The arc, as the owner gave it

1. **The creator makes the parents.** You play one of them. ("the char creation is important so we
   are creating the parents, we play as one of the parents")
2. **You build the bond by teaching the child to survive.**
3. **The point of view changes at the mammoth.** Once the child has learned enough, the parent lets
   the child make the kill, and from then on you are the child.
4. **The mammoth dies, and the village and the neighbours gather.**
5. **A raid party hits.** Everyone stops when the sky cracks. The galleons fight, and one crashes.
6. **The keelstone pirates come out of the wreck.** They use the Sway to kill the raiders and the
   villagers. The parents die abruptly, and the child is kidnapped.
7. **The setting is like the Edge** (The Edge Chronicles, inspiration only). The world we live in
   is **the Downbelow**.

This settles the two ideas of 2026-10-03:

- From the first idea it keeps "the fallen galleon is the bad guys". The revived-monsters ending is
  not in this arc.
- From the second it keeps "you are the child", but you start as the parent and become the child.

### 0.2 How each beat plays on what is built (D, proposals)

| Beat | How it plays | Built | New |
|---|---|---|---|
| Make the family | The creator makes parent A and parent B (each can be randomised), and you pick who you play. The child's face, skin, eyes and hair come from the two parents (`ChildLook.from_parents`). You choose the child's name and sex. The child is about ten. | `ChildLook`, `ChildProportion`, growth stages, `StoryWalker` child size | a Family step in the creator; the child as a story person |
| Teaching | The built Prologue missions become lessons. You do each one, the child watches, then does it with you: fire, felling, the lean-to, tracking, the hunt. Each lesson is a flag (`tf.taught.<skill>`). Small choices fill a hidden **bond** count: share food, answer a question, carry them over the ford, a story at bedtime. | the Prologue missions, `Household`, the first-time tutorial | the child copying a task; the bond count |
| ★ The mammoth | The parent fights the woolly mammoth: climbs it and buckles a leg. When it is down, the parent holds out the spear: "Your turn." **Control passes to the child**, and the child makes the kill. That is the POV change, and it lasts the rest of the game. | `StandInGiant`, `MammothTemper`, `MammothButchery`, the giants' music | the hand-over beat; switching the player body to the child |
| The feast | The neighbours come to the clearing: butchering, fires, food. It is the warmest scene in the game, and the last one with the parents. | `MammothButchery`, the people effect, `story_home` | the feast gathering |
| The raid | `RaidStage` hits the feast at night (troupes de la marine and Canadian militia only, as now). The child hides and runs, and never fights people. | `RaidStage`, `Captivity` | the raid at the feast |
| The sky cracks | Everyone stops: muskets go down and the fighting halts. The two galleons fight over the valley, and one falls (`SkyBattle`, `SkyTear`, `WreckFall`). | all three | the raid freezing on the crack |
| The pirates | They walk out of the wreck and use the Sway on everyone, raiders and villagers alike. It is the first magic the player sees, and it comes as horror, not wonder. | `NpcFighter`, the Sway's moves | Sway casters as enemies (11.7) |
| The parents die | Abruptly: no last words and no slow motion. No gore. The parent you played falls where the child can see. | ragdolls | the deaths in the scene |
| Kidnapped | The child is caught and carried aboard (`Captivity`). Why them (proposal): the child is **Sighted**. Ships run on the Sway (11.9), and the pirates take Sighted children to call wind into their sails. | `Captivity`, the lock ring | the reason, then Act 2 aboard |

A proposal for the wreck: the child reaches the wreck first and finds a man pinned under a spar. By
instinct the child lifts it, which is the first lock (mission 11's, already built). The man gets up,
and his crew comes out behind him. That man is the pirates' leader, and he takes the child *because*
he saw that gift. The child's kindness lets the killing out. This gives the leader the 2026-10-03
role (evil, with his own goal, using you) and plants the betrayal on the first night.

### 0.3 The Downbelow

- **The name.** The Downbelow is what the sky-folk call the ground world: our 1757 frontier, under
  the Drift. It fits the lore already written (Ossel's chained pyramids, land that drifts loose, the
  wreck fields).
- **A collision note.** "Downbelow" is the planet's nickname in C. J. Cherryh's novel *Downbelow
  Station* (1981). It is a plain word, so the risk is low, but the owner decides.
- **The mammoth.** The Downbelow keeps beasts the colonists know only as bones. The big bones found
  at Big Bone Lick in 1739 (H: verify), which colonists called the "incognitum", are the history
  hook. In this valley one still walks.
- **The rule change.** This drops 10.1's "no mammoths in the story layers" for the hunt's one beast.

### 0.4 What it changes in v5

| v5 | v6 |
|---|---|
| 6.2: a nobody loses their land in a raid | **New logline (D):** "Autumn 1757. Past the last farm you raise a child and teach them everything you know. On the day they make their first great kill, the sky breaks, and the people who fall out of it take everything. You grow up among them." |
| 9.1: you make one lead with a background | You make the parents and their background. The child is the lead from the mammoth on. |
| Jost Rauch, the neighbour's boy | Proposal: he stays as the child's friend at the feast, and his fate is the old `tf.jost_*` choice. |
| 7.5 rule 1: the wonder never causes a real event | The massacre happens at your own clearing past the last farm, which history never recorded. The register lists the family as "killed or taken in the raid": history blames the raid, and only the child knows. The Flatts' real totals stay as they are. |
| 7.5 rule 5: Act 1's only wonder is the card and three hints | Add the mammoth. |
| Act 2: the burned valley on foot with Rook | Captive aboard the pirate ship, then a time skip to a young adult. This needs player ageing (growth stages exist for NPCs). Act 2 gets redesigned once the owner answers 0.5. |
| Rook: the mentor you rescue, who sells you | Proposal: Rook becomes the pirates' leader, the man under the spar. He raises the child as crew and is the father figure who used them. |

### 0.5 Open, for the owner

1. **The creator.** Do you make both parents, or make one and generate the other? (Proposed: both,
   each with a randomise button.)
2. **The deaths.** Does the child see who killed the parents? (Proposed: the child sees only chaos
   and light. The captain says the raiders did it, and the child learns the truth years later. That
   is the betrayal.)
3. **The time skip.** How old is the child when you play them grown up? (Proposed: about 17.)
4. **Rook.** Is he the pirates' leader?
5. **The other galleon.** Who was it? (Proposed: a Lamp Chain ship from Vessary, hunting the
   pirates. The grown child meets its crew later.)
6. **The name.** Keep "the Downbelow"?

## 1. What exists today

Only these exist. Everything else in this document is design.

| Piece | Where | State |
|---|---|---|
| The Prologue (7 missions: Open Land to The Night of the Raid) | `data/story/missions/two_fires.json`, `data/story/storylines/two_fires.json`, `scripts/story/` | Built and committed. Kinds: `go_to`, `fell`, `build`, `fire_lit`, `kill` (animals only), `wait_for`. Story cards pause the game (`story_hud.gd` ~160) |
| The wonder sky | `scripts/world/env/wonder_look.gd`, `shaders/sky/wonder_sky.gdshaderinc` | In the working tree, not committed. A ringed giant near the celestial pole (circumpolar at the valley), an icy moon and a rust moon with phases, violet, teal and gold nebulae |
| The reveal | `EnvironmentRig.reveal_wonder(20 s)` (`environment_rig.gd:182`); the story effect `wonder_reveal` sets `flags["wonder"]` (`story_director.gd:192-198`) and is restored on load (`:273`) | In the working tree |
| Ambient sky galleons | `scripts/world/env/sky_traffic.gd` | In the working tree. At most 2 ships, 150-260 m up, far mesh past 450 m. **It needs `assets/sky/sky_galleon.glb`, which is not exported yet** |
| The galleon model | `tools/models/sky_galleon.py` (Blender, untracked) | A two-masted brigantine: hull ~26 m, ~32.5 m overall, beam 7.5 m. `Galleon_LOD1` under 3,000 triangles. Mast-top fans, keel-wings, a keel crystal, material `EtheriumGlow` |
| Aim | `JogAimArm`, `get_aim_point()`, the head look | Built |
| A ring by the crosshair | `GripRing` (`scripts/climb/grip_ring.gd`), the climbing stamina ring | Built |
| The sandbox | survival, building, felling, hunting, horses, boats and canoes, tree climbing, bow, musket, pistol, saber, tomahawk, spear, atlatl, snow, river ice, the household, visitors, god rays, wolves | Built |
| Co-op | `NetSession` P1-P6, up to 16 over ENet; hits decided by the shooter (`forward_hit`, `net_session.gd:476`) | Built |

Missing (from `docs/research/codebase_story_audit.md`): human NPC fighters, more objective kinds
with fail rules, checkpoints and branches, a dialogue box with choices, bodies for contacts, fire
and ruin, captivity, hue and cry, a map framework, in-game cutscenes.

## 2. What "GTA" means here

| GTA | Frontier |
|---|---|
| A city you roam freely | The valley first (the ford, the farms, the woods, the river). Then the sky. Then **Vessary**, the city of nine pyramids |
| A protagonist with a past | **Your own character** (customizer and background). Who they become is roleplay: who you side with, who you join, what you're known for |
| Contacts on the map who give missions | People at their spot with a marker: a lantern in a window, a note on a post, a man by a canoe, a woman at a dock crane |
| Missions: chases, heists, shootouts, escorts | Escapes, salvage runs, a mast haul, boardings, ship fights, a heist on a counting room, a vote, a chase across chained pyramids |
| Wanted level, police | **Reputation**, plus the moment itself: hue and cry in the valley, the **Lamp Chain** in Vessary |
| Money, properties, businesses | Coin and credit in the valley; in Vessary a berth on a pyramid face and a salvage share, worked by your household and crew |
| Side activities | What the game already has: hunting, the range, wild horses, boats, farming, climbing, the household |
| Satire | Albany speculators, pompous officers, a Crown commissioner who can't see what he hunts, a city that votes by weighing bronze pins |
| One map, several protagonists | One life across four places: the valley, the ship, the open sky, the city. Other storylines reuse the valley in other years |

The survival sim stays underneath. A storyline is a layer on top of it, never a replacement: you
still eat, sleep and stay warm between and during missions.

## 3. How storylines work

A **storyline** is one self-contained story pack:

- its era and start date;
- the world state for that year (which buildings stand, are ruined or are not yet built; who lives
  where);
- a starting hook for the player's own character;
- **contacts**, each with a short chain of missions;
- a main mission chain and side chains;
- **endings**, after which the world stays open for free roam.

Storylines are data, so new ones can be added without rewriting the game:

```
data/story/storylines/<id>.json   era, start, world state, places, parts (with their maps), contacts, endings
data/story/missions/<id>.json     the missions: giver, trigger, steps, fail rules, rewards, next
```

`StoryDirector` reads these files, puts contact markers on the map and runs each step through
systems that already exist. A new storyline is mostly data plus a few scenes.

### Rules

1. **Free roam between missions.** The player starts every mission at a contact. The calendar keeps
   moving, but the main chain waits for you, except where a dated clock is shown clearly in the text
   ("before the dark of the moon", "the tide closes").
2. **The world remembers.** A burned storehouse stays burned, a dead contact stays dead, a won berth
   is yours.
3. **Anything can happen.** Anyone can be attacked, robbed, helped or ignored, contacts included.
   A chain whose giver dies passes on to someone else (section 9) or ends. There is no game over,
   only reputation.
4. **Native nations.** No Native character, name, line, town life or adoption ships until that
   nation's office signs off (the backlog's release rule). Where history needs them, the storyline
   leaves a marked `[[consultation slot]]` and still works with the slot empty.
5. **Fail only on a real loss.** A mission fails when a real goal is lost (the witness dies, the ship
   sinks), never because the player left a path. Hard set pieces fail forward (section 10).

## 4. Reputation

There is no single wanted meter. Every community keeps its own opinion of you, built from what its
people saw or heard.

- **Per person:** trust (already in `data/survival/npcs.json` standing).
- **Per community:** in the valley the garrison, the traders, the settlers, the outlaws, the
  authorities and each Native nation (a slot). In Vessary the seven communities in section 8.
  Word travels at the speed of boats in the valley and of ships in the sky.
- **What you're known for:** a few tags that follow you, such as *keeps his word*, *a thief*,
  *a killer*, *Sighted*, *the one who saw the ship fall*. People greet you, price their goods and offer
  missions by them, and single lines in story cards swap by tag.
- **Witnesses.** A crime nobody sees is only rumour. A crime that is seen starts the hue and cry
  right then, and the witness carries it to their community. Kill the witness and you get a worse tag.
- **The law** is one community among others. Its reputation sets the bounty and who comes for you.

## 5. Joining communities (roleplay)

You can belong to more than one community, and standing in one can lock you out of another. Joining
changes where you sleep, who gives you work, what you wear and what you're taught. It is never a
separate game mode.

| Where | Community | How you join | What it gives |
|---|---|---|---|
| Valley | The garrison | Enlist, or prove yourself to the sergeant | Pay, rations, army jobs |
| Valley | The traders | Work the boats; buy a share | Goods, credit, the river trade |
| Valley | The settlers | Settle, keep your word | Neighbours who turn out to help |
| Valley | The outlaws | Rob, smuggle, run from the law | Black-market goods, hideouts |
| Valley | A Native nation | Adoption (`[[consultation slot]]`) | Only with that nation's office |
| Anywhere | Your household and crew | Build it; sign articles | Workers, a home base, a ship's crew |
| Vessary | Seven city communities | Section 8 | Section 8 |

## 6. The main story: Two Fires (1757-1761)

### 6.1 Four loops

The main chain teaches one loop per act. Every main mission is a loop in a story's clothes.

1. **Live off the land** (built): fell, build, hunt, keep warm, keep a household. Act 1.
2. **Go out, take, get back**: extraction with loadout risk. On foot in Act 2, by ship from Act 3.
3. **Crew a ship**: the galleon as a vehicle you walk on. Act 3.
4. **Make a name in the city**: contacts, contracts, a berth, reputation per community, the law.
   Act 4.

The Sway's timed lock-on (section 11) is the skill game in loops 2 to 4.

### 6.2 Logline and the title card

**Logline.** Autumn 1757. A nobody clears land past the last farm at German Flatts and loses it to
a war between empires. On the first night of captivity a burning ship falls out of the sky. From
then on they see what almost no one on Earth can: a ringed world over the pines, and ships sailing
between worlds. They leave on one, live through their mentor's betrayal, and land in Vessary, a
loud, rich city of nine chained pyramids. Three years later their own world's empire arrives there
with a treaty and guns.

**The thread** is making a name, and what you do with a door. In 1757 you are a settler on
contested land. In Vessary you are the newcomer, watching "your side" try to buy someone else's
city. The game doesn't tell you what to feel. It puts you on the dock.

**The title card**, before Open Land:

> There were two fires in the sky on the night they took you. Everyone at the Flatts saw the
> first. Only you followed the second.
>
> Autumn 1757. Six weeks earlier.

It promises the wonder in minute one, so players who came for sky ships wait gladly and history
players aren't ambushed (AC3's long prologue was called a bait-and-switch).

| Act | Time in play | Years | The feeling | Why |
|---|---|---|---|---|
| 1. Open Land | ~1 h 30 | Oct-Nov 1757 | Small, cold, physical; "I made this"; then helpless | You build, meet neighbours, and a real raid takes it all |
| 2. The Sighted | ~4 h | Nov 1757 - May 1758 | Awe and loneliness | The sky opens for you alone. The valley is ash. Only a stranger with no shadow, and one smiling Albany man, understand |
| 3. The Upper Sea | ~3-4 h | summer 1758 | Freedom, belonging, betrayal | A crew, a ship you learn by hand, storms; then the man who gave you the sky takes the ship |
| 4. The Ninepins | ~8 h + free roam | 1758-1761 | The stranger in a great city; then the mirror | A nobody again, until your own world's company lands on the dock |

### 6.3 Why the reveal lands

1. **Contrast.** Ninety minutes of mud, axe work and neighbours, then a raid told at its real size.
   The frontier's look is muted, so `WonderLook` (richer colour, gold motes) hits hard.
2. **The lowest point.** You are bound, your gear is gone and your house burns behind you. The
   wonder is a rescue and a wound at once: you can never unsee it.
3. **Promised in minute one** by the title card.
4. **Personal.** The world doesn't change; your eyes do. History stays intact.
5. **You do the looking.** The sky fades in over 20 seconds (`reveal_wonder`, built) at night,
   while you still have control. It is the same sky you have watched for ninety minutes: the stars
   stay put, and now a ringed world wheels round the pole star. It was always there.
6. **The first lock is a rescue.** Your first use of the power lifts a spar off a pinned man. The
   sky and the power arrive in one act.
7. **It is tied to your own first fire.** You carry a coal of the burning keel away in the tinderbox
   from the *Fire* mission. Those are the two fires.
8. **It is tied to your house.** On the walk home you learn what your captor said on the raid night:
   *"Pas celui-là. Il a bâti une maison."* ("Not that one. He built a house.") The house you built
   saved your life.
9. **Three hints anyone could explain away** come first: grandmother Anna's marsh lights (Irrlichter,
   the settlers' own lore), a pine stump cut too clean, as if the tree was lifted out, and a night
   when every bird stops at once.

### 6.4 The 70/30 rule, our way

Treasure Planet's directors made their look 70% traditional and 30% science fiction. Ours is:
**everything you touch is 18th-century; what it does is the wonder.**

- A galleon is a ship any sailor would know, on a glowing stone keel.
- Vessary keeps ledgers, weighs evidence, rings bells and posts notices.
- Your musket still takes six seconds to reload.
- Act 1 is about 98% history. It is the ground the 30% stands on.

The wonder grows act by act: a trace; then one wreck, one sky and one move; then the open Drift;
then a whole other history built from familiar materials. "70/30" stays an internal note.

## 7. The wonder's lore

### 7.1 What it is (D)

- **The Upper Sea.** Sailors call it **the Drift**. It is a sea of light and current folded over
  every sky, ours included. Its shoals are nebulae, its storms are lightning that never reaches the
  ground, and worlds sit in it like islands. The built wonder sky is the Drift as seen from the
  valley.
- **The Wheel and its moons.** The ringed giant near the pole is **the Wheel**. Colonists who can
  see call its moons **the Lamb** (the icy one) and **the Fox** (the rust one). The Fox's own people
  call it **Ossel**. Vessary stands on it, so once the sky opens you can see where you are going on
  every clear night.
- **Keelstone.** A pale stone that rises in the Drift's light. Bound into a keel, it floats a ship,
  which sails the currents on plain canvas. Burned, it gives a bright, sweet smoke. Under our thin sky
  it greys and dies within a season.
- **Sky galleons.** Wood, rope and canvas over a glowing stone keel, with two outrigger keel-fins
  that steer by tilting into the current. There are no engines and no thrusters.
- **Ossel.** A dry, windy moon. Its bedrock is veined with keelstone, so its land wants to rise.
  Over a thousand years its people piled stone on the richest veins to hold the ground down.
  **The pyramids are weights**, chained to the bedrock, and the city grew on the pinned ground
  between them. Beyond the rim, land that was never pinned has broken loose and drifts: islands,
  ruined towns, and the hulks that wrecked on them. These are the wreck fields.
- **The Veil and the Sighted.** Our world sits behind a Veil, and its people see only their own sky.
  Breathe keelstone smoke, or live long in the Drift, and you become **Sighted**: you see both skies,
  for good. Anything that falls into our air is solid and seen by everyone, and remembered as a
  fire-ship, a prodigy or a falling star. On Earth the Sighted are few and get called mad.
  The code already fits: the wonder is a per-machine sky setting (`WonderLook.apply`) switched on by
  the saved flag `wonder`. In co-op each player sees it only after their own reveal.
- **The Wayglass.** A pilot's lens cut from the great lens of Vessary's **Ninth Lantern**. Held to a
  light, it shows the safe channels through the Veil.
  - About thirty years ago House Ammert darkened the Ninth Lantern to close the shore trade.
  - A young lens-mate called Rook stole the glass and ran the shore trade with it for a generation:
    masts and powder from the frontier, through Albany smugglers.
  - In 1757 he was caught at last. Captain Ithel's cutter *Candlewake* was carrying him and the glass
    home for trial when a storm threw it, burning, through the Veil onto the Mohawk.

### 7.2 The tides: why the 1750s, and why history forgot (H dates, D lore)

The Veil thins when real things move in our sky. Its doors are dated, which gives the story clocks
the player can trust.

| Door | The real event (H, High; verify wording) | In the story |
|---|---|---|
| 1607, 1682 | Returns of Halley's comet | Older tides. Some of Vessary's Shore-folk families came up then |
| Autumn 1757 - spring 1759 | The comet Halley predicted for 1758: first seen again on Christmas night 1758 by Palitzsch, past the sun on 13 March 1759 | **The comet tide.** The lanes reach down to the north. The *Candlewake* is thrown down early in it; the *Long Patience* comes down for masts in May 1758 |
| 6 June 1761 | Transit of Venus | **The transit tide**, a few weeks wide. Hollis and Company's ship comes up on it. The climax, and the last ship home for eight years |
| 3 June 1769 | Transit of Venus | **The last door.** An epilogue card for those who stayed |
| After 1769 | No transit until 1874 | The Veil thickens, the narrows close, keelstone on Earth greys, the Sighted die off. **This is why history has no sky galleons** |

- **The narrows.** Between tides a ship can still try to cross. Most burn. The Wayglass shows the safe
  channel; the Ninth Lantern, lit, shows it to every ship. That is what everyone in Act 4 fights over.
- **Why the north.** The Wheel stands near the pole, and the lanes anchor beneath it, over the cold
  north woods.
- **Why history is silent.** Keelstone dies under our sky, so every relic ends as a grey stone in a
  cabinet of curiosities (a real 18th-century fashion, H). The French officers keep their search
  secret, and their papers are lost when Montreal surrenders in 1760 (H for the surrender, D for the
  papers). The Crown's commission is secret and is wound up after 1769. The door shuts.

There is no time slip. The lead lives 1757 to 1761 in order, and is in Vessary while Quebec falls
(1759) and Montreal surrenders (1760). The news comes up with the 1761 ship.

### 7.3 Why ships reach the 1750s frontier

- **Masts.** Ossel grows no tall trees, and the Drift's best masts are North America's white pines.
  The Crown claimed the same trees with the Broad Arrow mark (H: the white pine laws of 1691 and 1711;
  verify whether they reached New York). Felling is built, so the frontier's own work becomes the
  wonder's trade.
- **Powder.** Ossel has little saltpetre, so smuggled powder is a fortune.
- **People and wrecks.** Castaways, runaways, and ships that strayed near the Veil and fell through.

### 7.4 How the real history connects

| On the frontier (real) | In the wonder (mirror) |
|---|---|
| Land held on paper: patents, lots sold twice, burned lots bought cheap | Who owns ground that won't stay put? Berths sold by height; Vane buying pins; Rook's patent in two names |
| Lydius bought land from sachems one at a time, out of council (H) | Vane buys pins from one House at a time, out of the Weighing |
| The Flatts were warned three times and laughed (H) | The Hollowers warn that the pins grow lighter; you warn the Weighing. *Noon Warning* shows a warning heeded |
| The Palatines' own tar camps on the Hudson, 1710-12 (H) | Rook was a boy in them. Vessary binds debtors to Hollows shifts |
| Plassey, 23 June 1757: a trading company won a state by buying one of its lords (H) | Hollis and Company's treaty, and Vane buying House Ammert's debts |
| The Broad Arrow pines (H) | The Drift's mast trade |
| Captives held in Montreal until the war ended (H, Low: one family record) | Jost, if he is taken; the work-gang and unpinning in Vessary |

### 7.5 Seven rules that keep Act 1 true

1. The wonder never causes, explains or undoes a real event. The raid happened for the war's reasons.
2. No real person sees the wonder on screen. Belestre, Herkimer, Johnson and Vaudreuil stay in the
   background. Only invented people are Sighted.
3. Real dates and numbers stay, with their basis keys. The raid is told at its real size before any
   ship falls. Player choices decide which named neighbours live, never the historical totals.
4. The register of the dead and taken is read before the wreck hunt starts.
5. Act 1's only wonder is the title card and three hints anyone could explain away.
6. The wonder never touches Native belief or land. Nothing links the sky-folk to any Native nation,
   and the wreck site and the Veil are never sacred or burial ground.
7. Free play in 1757 or 1765 never sets the wonder flag.

### 7.6 Our names, not Disney's or Nickelodeon's

- **"Etherium"** is Treasure Planet's word. Player text says *the Upper Sea* or *the Drift*. Rename
  the `EtheriumGlow` material, the shader comments and the "etherium fans" in `sky_galleon.py` before
  release.
- **Check the model.** Its mast-top fans are the nearest thing in the project to the film's solar
  sails. Our silhouette rule is a deep stone keel, outrigger keel-fins and a plain square rig. If the
  fans read as the film's, cut them and keep the keel-fins and glowing canvas.
- **Never:** a cyborg mentor, a shape-shifting pet, a robot, a cat captain, a crescent-moon port, a map
  sphere, solar surfing, an inn burning, or any name from the film.
- **"Bending"** is Avatar's word. Ours is **the Sway**. Its four arts belong to guilds and factions,
  there are no four nations, and nobody is chosen.

## 8. Vessary, the city of nine pins

Colonists call it **the Ninepins**, after the skittles game the Palatines and the Dutch played.

### 8.1 The look

**It is not** Egypt, the Maya, the Aztec or the Inca, and it borrows no other real culture's sacred
architecture either. The art team's list:

- no sandstone, gold caps, sphinxes, obelisks, hieroglyphs or tombs;
- no front stairs, temple tops, feathered serpents, jade or glyph blocks;
- no Persian or Central Asian glazed tilework, no temple-mountains, no ziggurat shrines;
- no sacrifice, no knotted cords, no judgement of souls.

A pyramid here is a weight, a lighthouse and a mine.

- **Nine steep pyramids** (about 60°), 90-180 m tall: dark basalt banded with white lime mortar,
  bound down by bronze chains with links the size of a cart.
- **Docks and gantries** jut from every face. The higher your berth, the higher your rank.
- **A lantern crowns each top:** a great lens of glass and bronze over a keelstone fire, the beacon
  ships steer home by. Eight burn. The Ninth has been dark for thirty years.
- **Between the pyramids** stand low white courtyard houses, each flying a kite in its family's
  colours, so the sky is full of kites.
- **Writing** is pin-holes punched in brass plates, read by touch or by shining a light through them.
  In the game it is a dot script with English underneath.
- **Dress.** Layered robes with hems weighted by small bronze pins ("a heavy man" means a rich one).
  Sailors wear harness and tethers. Miners wear leather aprons, and the keelstone dust on them glows
  at night.
- **Everyone is human** and uses the player's rig and the customizer. Peoples differ by dress, trade
  and posture, never by skin. Beasts reuse our rigs: drift-oxen on the bison, wreck-dogs on the wolf,
  a drift-matriarch on the mammoth.

### 8.2 Peoples and politics

- **Pinfolk:** the old families of the Nine Houses, who own the pyramids, docks and mines. Proud and
  legalistic.
- **Driftfolk:** born aboard ship, loyal to their crews rather than to any ground. The city needs them
  and looks down on them.
- **Hollowers:** keelstone miners under the pins. Organised, angry, and the first to feel the ground
  shift.
- **Shore-folk:** crossers from veiled worlds: an older generation of rovers, castaways and
  mast-cutters, and free Black sailors and freedom-seekers from the Atlantic world who built a
  self-governing quarter called **Landfall** (written with sensitivity readers).

**The Weighing.** The Houses govern by laying bronze pins on a great balance in a weigh-house, like
a Dutch *waag* (players from the Palatinate and Albany will know one). Pins are votes, and they can
be bought and lent. Trials weigh evidence the same way. It is a merchants' scale, never a judgement
of souls.

**The Lenswrights** grind the lenses, keep the beacons and charts, take a toll from every ship on a
lit channel, and teach the Sway.

**Three tensions:**
1. **The mining.** Every ton of keelstone dug out makes a pin lighter. The Hollowers say the Houses are
   digging the city loose.
2. **The shore.** House Ammert darkened the Ninth Lantern to shut out the shore trade and its people.
   Landfall wants it lit, and your Wayglass could light it.
3. **The Company**, from mission 33.

The city is older, richer and stronger than the lead. Its people act whether or not you help, so
Act 4 is never a saviour story.

### 8.3 Communities to join

| Community | How you join | What it gives |
|---|---|---|
| **House Ammert** (the First Pin) | A retainer's oath to Lady Iselde | A high berth, pins at the Weighing, the law's favour, the Pin move |
| **The Lenswrights** | Mother Sael's three trials | The Light art, charts, the Beacon move |
| **The Hollow Brotherhood** | Work a shift; stand at the strike | The Weight art (Lighten), the Hollows as a hideout |
| **The Free Crews** | Sign articles on a Driftfolk ship | A crew, salvage shares, Breath at sea |
| **Landfall Commons** | Bring crossers in safely; keep your word | A home, a tavern, Earth goods |
| **The Smoke** (outlaws) | Run dust, rob a wreck, cross the Wardens | Ember tricks, black markets, hidden docks |
| **Hollis and Company** | Take Vane's coin | Pay, guns and powder, the treaty's side |

After mission 36, House Ammert and Landfall can't both trust you, and Landfall never trusts a
Company man. The valley's communities carry on alongside.

### 8.4 Economy

The coin is the **pin**, a bronze peg. Landfall changes pence for pins at a bad rate. The city's
wealth comes from keelstone (it lifts ships and powers the Sway), masts (one valley pine is worth a
year's wages), powder, salvage, beacon tolls, and food from the Kitchen Isles, farm islands tethered
to the rim.

**Your businesses, first version:** one **berth** on a pyramid face (its height sets its price and
its income) and one **salvage share**. Your household and crew work them while you're away. A tavern
share, a keelstone claim and mast contracts come later, only if the first two prove fun. Cut:
skiffs as stealable city cars, and ship insurance (a crippled ship limps home and is repaired at your
berth for a fee and a day).

### 8.5 What makes it bustle, cheaply

- Crowd stand-ins (walking cards) with short text barks over the nearest heads.
- Ships arriving every minute (`SkyTraffic` with dock routes, 3-4 at once).
- Kites as particles, the bell of the Hours, smoke.
- Things that happen without you: a skiff crash, a Warden chase, a strike march, a race.
- The posted almanac of city days (section 12).

### 8.6 The law: the Lamp Chain

The frontier's hue and cry in city clothes, and you can see it climb.

- **Witnesses.** A crime someone sees rings the district's hue bell and **lights a lamp on the
  nearest tier.** Lamps climb from tier to tier and jump from pin to pin. How high the light has
  climbed is your wanted level, and the whole city can see it.
- **Who comes:**
  - 1 lamp (the bottom tier): the **Wardens of the Scale** ("the Weights") on foot, with chains and
    the Pin move. They arrest rather than kill.
  - 3 lamps (mid-face): a House's guard.
  - 5 lamps (the crown, then the next pin): Lenswright cutters from the air with lens-beams.
- **Losing them.** Break sight, go into the Links or down into the Hollows, change your coat, or go
  out past the rim. The lamps go out tier by tier.
- **Bounties** hang as pins on your name at the **Wanted Scale**. Pay it off there, or get a House to
  lift it. Never on freedom-seekers, debtors on the run, children, or anyone for what they are.
- **Sentences.** The harshest is **unpinning**: exile on a drifting rock (it reuses *The Rock*,
  mission 26). A lighter one is a Hollows work-gang shift, a short captivity you can escape. Nobody is
  executed on screen.
- Lamps are emissive sprites, never real lights.

### 8.7 Twelve places

1. **The Weighing Hall**, atop the First Pin: a balance as tall as a house under open sky. Council,
   trials, the vote.
2. **The Scales:** the great market where everything is sold by weight. The Wanted Scale hangs here.
3. **The High Docks:** berths stacked up the Fourth Pin's faces, with cranes and gangways. Your
   galleon's home.
4. **The Links:** a shanty town built in the anchor chains, all of it climbable. The best place to
   lose the Weights.
5. **The Hollows:** mines under the Third Pin where loose rubble floats and keelstone seams glow.
6. **Landfall:** bread ovens, rum, a meeting hall, a printer setting Caslon type. It smells like Earth.
7. **The Dark Pin:** the Ninth Pin, its chains rusted and its docks abandoned. Outlaws, and the finale.
8. **The Terraces of Sallow:** shaded garden terraces with keelstone-pumped fountains. Heists.
9. **The Rim and the Tether Gates:** cliffs where the pinned ground ends. Winches haul ships in; the
   loud, timed exits for raids.
10. **The Kitchen Isles:** farm islands on cables, seen from the rim (a later side map).
11. **The Still Water:** a bathhouse that is neutral ground by old law. Weapons stay at the door.
12. **The Company Factory:** a Georgian brick warehouse dropped onto an alien square in mission 33,
    with a gunship moored above it. It is meant to look wrong, and to mirror Fort Herkimer.

## 9. Characters

### 9.1 The lead

You make the lead in the customizer. The background gives one line choice in Act 1, a "what you left
behind" letter, and one opening in Act 4:

| Background | Act 1 | Act 4 |
|---|---|---|
| A Palatine farmer's younger child (no land to inherit) | The Rauchs trust a German speaker sooner; you read Fraktur | Rook's German is your own; Landfall's bread oven is a business from day one |
| A runaway bound servant | A reward notice may reach the fort | You spot the Company's recruiters |
| A provincial soldier who walked off when his term ran out | The sergeant half-knows your drill | You can read the marines' drill |
| An Albany trader's clerk | You can read patents and know Hollis and Company's house | You read Vane's ledger faster |
| A free Black boatman from Albany (written with sensitivity readers) | Some doors at the Flatts close, shown honestly; your freedom is never treated as a crime | Landfall's elders know your face |

**Hooks that run the whole game:** making a name (nobody, then "the one who saw the ship fall", then a
crewman, then a name in Vessary); Jost; the Wayglass sewn into your coat lining; the coal in your
tinderbox; the ashes of your house; being Sighted, for good.

### 9.2 Rook (Matthias Raab), the mentor who sells you

- **Who he is.** Born about 1700 in the Palatinate. As a boy he was in the tar camps on the Hudson,
  1710-12 (H). In 1712 he ran, and was taken up by a mast-runner that dared the narrows (D). He has
  lived 46 years in the Drift. Sailors call him Rook; *Raab* means raven. He has been in the Drift so
  long that **he casts no shadow under our sun.** That costs nothing to render: his mesh doesn't cast
  one. Check "Raab" against the Burnetsfield patent list before it ships.
- **What he does for you.** You free him from under a spar at the wreck (mission 11). He walks you home
  through the wolves, teaches you Breath, gets you aboard a ship, and tells the best stories in the
  game. Warm, funny and patient: "The Drift rewards long patience." That is also his rule of the lock.
- **What he wants.** The farm his family was promised in 1710 and never got. The Palatines who stayed
  got land at German Flatts by the Burnetsfield Patent of 1722-23 (H). His share went to nobody,
  because the boy never came back.
- **What he does.** He has known Silas Vane for years through the shore trade. He sells Vane three
  things: the Ninth Lantern's channel, the timing of the 1761 tide, and **you**, the Wayglass carrier,
  as the Company's pilot. In return he gets a patent for ten thousand acres up the Mohawk made out to
  Matthias Raab and to you. He believes he is giving you a home, the one you both lost.
- **The two betrayals.** In Act 3 he betrays the ship (the Mutiny, to keep the glass from the
  Lenswrights). In Act 4 you learn he sold the city and you (mission 34). Whether he betrays *you* at
  the end comes from a hidden tally (section 10.6).
- **His lettering.** A sailor's English hand. When you learn his name, it corrects itself on screen
  into a Palatine boy's Fraktur.
- **Not Silver:** no cook, no false limb, no pet, no treasure map.

### 9.3 Silas Vane, the final antagonist

- **Help first.** Vane is the partner of the sutler at Fort Herkimer, modelled loosely on Lydius (H),
  the Albany smuggler with doubtful deeds. In autumn 1757 he gives you credit against a note,
  "because a man should start somewhere." After the raid he brings you a coat and offers to buy your
  burned lot "to keep it from the Albany men."
- **He is Sighted.** His father's house bought keelstone in Rook's shore trade, and Vane breathed its
  smoke at eleven. He is the only other person on Earth who sees your sky, and being understood is what
  draws you to him.
- **Sins later.** He buys widows' lots cheap (*Burned Lots*), buys Rook's sale, and by 1761 holds a
  secret Crown commission through Commissioner Lisle. On the transit tide he steps off the gunship
  *Albany Venture* with a treaty, a band, forty Company marines and a smile: "You'll remember me."
- **His weapons** are paper, coin and guns. He never uses the Sway.
- **His loud man,** Bram Kolb, wears a lead-lined coat that Draw and Lighten can't move.
- **If you kill him early,** Lisle leads the 1761 crossing, seeing painfully through spectacles of
  ground keelstone, and Kolb is the Company's face in the city.

### 9.4 Contacts

| Contact | Acts, place | Community | Side chain (at most 4) |
|---|---|---|---|
| **Margaretha Rauch**, a Palatine farm wife; her son Jost (9) and grandmother Anna | 1-2, the Flatts; 1761 | Valley settlers | *Bread and Salt* (feed the fort), *The Mill* (rebuild it), *Anna's Lights* (the marsh lights are shards from older wrecks), *Jost's Letter* |
| **Silas Vane** | 1-2, the fort; 4, Vessary | Hollis and Company | *Burned Lots* (buy out widows: a sin you can refuse), *Anything Strange*, *Company Work*, *Treaty Day* |
| **Commissioner Edmund Lisle**, of the Crown's secret Commission of the Upper Air | 2, the fort from Feb 1758 | The Crown | *Be My Eyes* (describe what he can't see; you may lie), *The King's Trees* (stop the mast-runners), *Dead Stone* |
| **Toussaint Leclerc**, Canadian militiaman, the captor who spared you | 1-2 | The French, and his conscience | *Snowshoes*, *A Prisoner's Price* (ransom Jost through Montreal by letter), *Neither King* (sink the keel so no empire gets it) |
| **Titus Brand**, a Black ranger serving three years for his freedom papers (modelled on Jacob Jones, H) | 2, with Lisle's party; 4, Landfall | His own | *Papers* (his captain owes Vane, and freeing Titus costs you Vane's favour), *Snowshoe Scout*, *No Press* (stop the Company's recruiters in Vessary). His ending: stay in Landfall, or go home with his papers |
| **Rook** | 2-4 | The Smoke | *Gust*, *Draw*, *Shadowless* (reading ships by their glow), *The Farm at Schoharie* (his story, over three night watches) |
| **Captain Orrin Sarrow**, half-blind, steers by the Sway; his navigator **Kessa Vellam** | 3-4 | The Free Crews | *Beacons Out* (relight dead beacons), *The Captain's Eyes*, *Kessa's Test*, *Articles* (your own crew) |
| **Mother Sael**, the Lenswrights' archivist | 4 | The Lenswrights | *Three Trials*, *The Pin-Hole Library*, *Beacon*, *What the Ninth Saw* |
| **Hannah Mercer**, keeper of Landfall, who came up in 1744 on one of Rook's mast-runners | 4 | Landfall | *New Arrivals* (guide crossers), *Recruiters*, *The Commons' Ship*, *A Roof in Landfall* |
| **Gorran Tell**, the Brotherhood's foreman | 4 | Hollow Brotherhood | *Stone*, *The Strike*, *Collapse*, *The Undermining* (someone is digging under the Ninth Pin) |
| **Lady Iselde Ammert**, heir of the First Pin | 4 | House Ammert | *A Retainer's Oath*, *Heavy Coin*, *The Ninth Pin's Debt*, *Close the Door* |

Every side chain is a person with a twist, never a bare fetch quest.

**Chains pass on when a contact dies:**

| Who dies | What carries on |
|---|---|
| Margaretha | Anna |
| Vane | Lisle leads the 1761 crossing; Kolb in the city; in 1765, Nathaniel Hollis |
| Rook | Sisk, the Smoke's scarred boss, takes the mutiny and the sale; Rook's papers carry the reveal in 34 |
| Sarrow | Kessa |
| Hannah | Her deputy, Moses Tarrant |
| Leclerc | His letters reach you through Margaretha |
| Any mentor | A pupil can teach the same moves, so a death never locks a move away |

**Others:** Jost Rauch (9 in 1757; ship's boy if he comes with you), grandmother Anna, Dominie
Ehrhardt (keeper of the register), the fort's sergeant, Captain Ithel (dies at the wreck), Hadu (the
*Long Patience*'s bosun, who teaches Ember). Check Rauch, Ehrhardt and Raab against the Burnetsfield
list; the register shows invented names until real ones are verified.

### 9.5 All of it is text

Dialogue boxes with choices, barks over heads, letters, broadsides and pin-hole plates. No voice.

- **Lettering per community** (Pentiment's lesson): Fraktur for the Palatines (UnifrakturMaguntia,
  OFL); a round hand for Vane, officers and deeds; Caslon for printed cards and broadsides (Libre
  Caslon, OFL); French *ronde* for the Canadians; Vessary's dot script with English under it; Rook's
  sailor's hand.
- **Text writes itself in live.** Anger splatters the ink. A hand corrects itself when you learn who
  someone really is.
- **French stays French** until you learn it. Glosses grow as you do (from Rook, then Leclerc).
- **Lines that exist only if you earned them:**
  - Anna's hymn, "Allein und doch nicht ganz allein" (H: check its date and author), learned in
    *Neighbours*, can be sung on Rook's fever night. He knows it from the tar camps.
  - In *The Wreck in the Pines* Leclerc finds you staring at a sky he can't see: *"Qu'est-ce que tu
    regardes ?"* Answer *Rien*, *Les étoiles* or *Un monde*. If you said *Un monde*, his parting words
    at the Mast-Runners are *"Va voir ton monde."*
- **Accessibility:** a plain-font toggle and a dyslexia font.

## 10. Acts and missions

**Objective kinds.**
- **Built:** `go_to`, `fell`, `build`, `fire_lit`, `kill` (animals), `wait_for`.
- **Planned in the audit:** `talk`, `kill` (people), `capture`, `escort`, `chase`, `steal`,
  `deliver`, `defend`, `survive_until`, `stay_unseen`, `follow`.
- **New in this design:** `choose` (a choice that branches), `lock_cast` (land a Sway lock on a
  target), `sail_to`, `crew` (stations manned), `extract` (leave a zone holding an item), `race`,
  `read` (a document), and `repair` (a variant of `build` on ship pieces).

★ marks a set piece. Mission numbers run through the whole story: 38 missions.

### 10.1 Act 1: Open Land (Oct-Nov 1757, the valley). Loop 1, ~1 h 30, 10 missions

The built Prologue is Act 1's opening. Its missions keep their order; three new ones slot in.

**Fixes to the built Prologue** (critic B10, history-core flags 1-2):

| Where | Now | Change to |
|---|---|---|
| `storylines/two_fires.json:17` `homestead` [78, 64] | South-east of the stockade, on the fort's side, which did not burn | About **[1000, 100]**, east of the river (centre x0 = 832, meanders about ±95 m) in the open land square. Add `ford` (the rapid at z ≈ 60), `flatts_farms` and `mill` east of the river, `fort_church` at the stockade, `raiders_camp` and `wreck` at the head of the open land (about [1100, -380], near the upper rapid). The stockade stays as Fort Herkimer. The game's west bank is the real south bank; its east bank is the real north bank, where the farms burned |
| `storylines/two_fires.json:15` (`_doc`) | "in the woods south-east of it" | The new bank layout, above |
| `storylines/two_fires.json` `parts` | Prologue, then *Taken In* on the North Woods map | Acts 1-4 on the valley, the valley's burned layer, the Upper Sea and Vessary. *Taken In* becomes a separate storyline (section 18) |
| `missions/two_fires.json:19` | Opens on "Autumn, 1757" | Add the title card before it (section 6.2) |
| `missions/two_fires.json:20` | "a night inside their stockade"; "pointed south-east, into the trees" | "a night inside Herkimer's palisade"; "pointed across the ford, past the last farms on the far bank" |
| `missions/two_fires.json:24` | "Find the open ground south-east of the Flatts" | "Cross the ford to the open ground past the last farms" |
| `missions/two_fires.json:82` | "the land office" | "the men who hold the patent's papers" (New York land came by patent from the governor and council; Medium, verify) |
| `missions/two_fires.json:102` | "The farms outside the fort are burning" | "The farms across the river from the fort are burning" |
| `missions/two_fires.json:103` | "says something in a language you do not know" | Keep it, and show the line itself in French: *"Pas celui-là. Il a bâti une maison."* End: "Behind you, someone puts a torch to the roof you raised." |
| `missions/two_fires.json:104` | "By dawn the Flatts are ash and about a hundred and fifty people are being walked north"; "a town you have never seen, and a family that has lost someone" | "By dawn the farms are ash; the fort across the river held. About forty are killed or drowned and nearly a hundred and fifty taken." The captives are herded up the bank to the raiders' camp, to be marched west by the Carry and taken by water to Canada (Medium) |
| `missions/two_fires.json:105` | End of the Prologue; Part 1 *Taken In* next | Leads into *The March* (mission 10) |
| `missions/two_fires.json:108` `_review` | The raid shows allied warriors | Allied warriors appear only in reviewed text, never on screen. The text goes to the offices of the nations the French summary names, once they are identified (NYCD vol. 10, pp. 672-674) |
| The church | Not mentioned | Unfinished walls at the fort in 1757 (H: built 1753-67) |
| The warning | Not in the Prologue | New mission 8: **warned three times** (H, High: about 15 days before, again from Oswegatchie, and with a belt the day before). The warners are a `[[consultation slot]]`. With the slot empty, Anna passes it on: "We have been warned three times this month, and the men laughed." No belt is ever an item |
| The raiders on screen | Undefined | Troupes de la marine and Canadian militia only. Allied warriors are named in the cards as part of the force (true), never shown as targets |
| `data/world/squares.json` | Mammoths: open_land 4, field_land 2, lake 1, fort_woods 1. Bison: open_land 40, field_land 24, lake 10 | The story's valley layers (1757-61) have **no mammoths and no bison** (H: no record of bison in the Mohawk Valley in the 1750s; verify). Free play keeps the sandbox numbers. Horses stay as strays and free-ranging farm stock (D) |

| # | Mission | When, where | Summary | Kinds | Systems |
|---|---|---|---|---|---|
| 1 | Open Land (built; text fixed) | Oct 1757, Fort Herkimer to the ford | The title card. A night inside the palisade, then over the ford to ground nobody has claimed. *Nobody here knows your name.* | go_to | walking, key hints |
| 2 | Clearing (built) | your ground | Fell three trees. One old stump nearby is cut too clean, as if the tree was lifted out. | fell | felling |
| 3 | A Roof of Brush (built) | your ground | A lean-to before the rain. | build | building |
| 4 | Fire (built) | your ground | Flint, steel and a tinderbox you will carry to another world. The smoke tells the woods someone lives here. | build, fire_lit | fire; the tinderbox item (new, S) |
| 5 | Meat for Winter (built) | the woods | Hunt a deer and drag it home. | kill | bow or musket, stalking, hauling |
| 6 | Neighbours (new) | the Rauch farm, the fort's store | Carry venison to Margaretha, Jost and grandmother Anna. Anna tells of the Irrlichter in the marsh and teaches you her hymn. Vane gives you credit against a note in your pack. | deliver, talk, choose | dialogue box v1, contact bodies (none of them fight), the song item, documents |
| 7 | A House and a Home (built; text fixed) | your ground, late Oct | Floor, walls and roof before the snow. A night when every bird stops at once. | build | building |
| 8 | The Third Warning (new) | early Nov, farm to farm | Word comes a third time, and the men laugh. Carry it farm to farm: **a hidden count of the families you persuade** decides which named neighbours live. Send Margaretha and Jost to sleep at the fort (this decides whether Jost is taken). Bury your gear in a cache (PackDrop; it pays off in *Ash*). | talk, choose, build | dialogue, the hidden count, the cache |
| 9 ★ | The Night of the Raid (built; becomes playable) | 3 a.m., 12 Nov 1757 (H) | Shots and an orange sky. Get whoever you can to the ford; the fort across the river holds. At your own clearing you are taken. A captor looks at you and says something in a language you do not know. Your roof is set alight. | wait_for, escort, survive_until | slice: heard and told in cards, a scripted run, a staged capture, fire and ruin on your house; later the fighter AI; one shared fire light |
| 10 | The March (new) | 12 Nov, by day, up the east bank | Gear stripped, hands bound, the cold. Toussaint Leclerc, the Canadian who spared you, shares a crust. Jost is beside you if he was taken. From the raiders' camp you see the fort across the river and the smoke of the farms (H: the force stayed through the 13th and drove back a sortie of about 50). | follow, survive_until, choose | captivity (`BareStart`, a bound state), two scripted guards with sight cones and no brain, cold |

### 10.2 Act 2: The Sighted (Nov 1757 - May 1758, the burned valley). Loop 2 on foot, the Sway, ~4 h, 9 missions

| # | Mission | When, where | Summary | Kinds | Systems |
|---|---|---|---|---|---|
| 11 ★ | Two Fires (**the reveal**, ~1 h 35) | the night of 12-13 Nov, the raiders' camp and the pines | At the fire Leclerc repeats his words to another captor, still unreadable. Then two sky ships fight high over the valley, seen from the camp: a great shot strikes the sky beside the ringed giant and it cracks there, one ship falls burning into the pines, and as it lands the break runs across the sky and opens it (the reveal, ~50 s, you keep control). The camp scatters. Slip your bonds, with Jost or without him, and reach the wreck. Breathe the burning keel's smoke under the broken sky. Captain Ithel is dying; a stranger is pinned under a spar. "Hold it in your eye. All of it." **Your first lock** (3 s, a still target) lifts the spar, and the stranger crawls free. Ithel gives you the Wayglass: "Take it to the Ninth Lantern. No one else." You scoop a coal of the keel into your tinderbox: the second fire. | stay_unseen, go_to, lock_cast, talk, choose | escape, the sky battle (SkyBattle) and the sky tear (SkyTear), the wreck (the broken and burning galleon), the lock ring, staging (3 takes) |
| 12 | The Man with No Shadow | that night, the open land to the ford | Rook walks you toward the fort through the snow. Wolves come to the raid's dead stock, and he drives them off with Gust. Share your bread, or don't. You repeat the captor's words, and Rook, who has sailors' French, tells you: "Not that one. He built a house." By the moon on the snow you see he casts no shadow. | follow, survive_until, kill, choose | wolves (built), cold, the language thread, a tally moment |
| 13 | Ash | 14-20 Nov, the burned Flatts and the fort | The raiders have gone west. The farms are ruins and the fort still stands. Your house is a black square, with your cache if you dug one. Dominie Ehrhardt reads the register of the dead and taken and strikes your name. Vane brings a coat and offers for your lot. You hide Rook in your stone root cellar, and that night his wound burns with fever. Sit with him; sing the hymn if you learned it. | go_to, talk, choose, deliver | the burned layer, the reckoning, the hymn callback |
| 14 | First Lesson | Dec 1757, the frozen river at dusk | Rook teaches Gust on a lantern, a hat on a post and a running wolf. Your tinderbox's coal breathes motes back. That night Vane finds you on the fort's wall, watching the Wheel. "Beautiful, isn't she? I was eleven." He sees it too. | lock_cast, talk | the Sway's lock, `JogAimArm`, motes, the free floor |
| 15 | Salvage | Dec-Jan, the burned farms by day | Bring iron, seed grain and stray stock back before dusk shuts the gate. The drum is your loud exit; a hidden canoe is the quiet one. Wolves gather at the carcasses. | steal, deliver, extract | solo extraction, `DeathRule`, the coat lining |
| 16 | The Wreck in the Pines | Jan 1758 | Two hunts come for the wreck. Commissioner Lisle (who cannot see) with a file of redcoats and the ranger Titus Brand. And Leclerc's small party of Canadians, sent by the governor's officers under orders of secrecy. Get the ship's log and a keel shard first: by stealth, by Gust, or by siding with one of them. | stay_unseen, steal, extract, choose | human fighters, snow prints, the Sway on Earth |
| 17 | Broad Arrow | Mar 1758 | Rook's mast contract: fell three great pines and haul them with the horse to the clearing while Lisle's men mark the King's trees. Vane pays for the masts; you watch him and Rook talk like old partners. | fell, deliver, defend | felling and hauling as the wonder's trade |
| 18 | Noon Warning | 30 Apr 1758 (H) | This time the warning comes at noon and people listen (H, High: an Oneida warned Captain Herkimer at noon; with the slot empty, a settler rider brings it). Three hours to the attack: farm to farm, a sick woman by cart, the cattle, the dominie's register, the swollen spring ford, and the gate barred at the first shots. You hear the attack and never fight it. Whoever is still outside is lost, told in cards. | escort, deliver, survive_until, choose | escort AI, horse and cart, the spring flood, a clock |
| 19 ★ | The Mast-Runners | the dark of the moon, May 1758 | The *Long Patience* comes down to load masts, one mast sprung. Raise the pine you felled into her with the horse and whoever you saved, while Leclerc's party and Lisle's men close in. Hold the clearing, choose who comes (Jost, Titus), and rise through the Veil. | repair, defend, escort, choose, go_to | fighters, the first story ship, Gust in combat, `repair` |

**Why *Noon Warning* has no fight, and how 16 and 19 stay honest.** The real attack of 30 April 1758
was about 80 warriors and 4 Frenchmen (H, High). A fight against Frenchmen only would falsify it, and
Native warriors are never AI enemies. So the mission is a race against a clock, the river and the
cattle, and the attack is heard. The parties in 16 and 19 are different: one small detachment sent
on a secret errand, and the reviewed text says why it is French and Canadian only (the officers kept
the secret among the King's own men). That text goes for review like the raid's.

### 10.3 Act 3: The Upper Sea (summer 1758, the voyage). Loop 3, ~3-4 h, 8 missions

The tightest act: you are crew, not captain. Between missions you roam the ship and each reach's
islands.

| # | Mission | Where | Summary | Kinds | Systems |
|---|---|---|---|---|---|
| 20 ★ | Through the Veil | the first reach | The open Drift at last. Sign the ship's articles: shares, rules, and a vote for sailing master (H: pirates' articles of the 1720s; verify). Learn the stations; meet Sarrow, Kessa and Hadu. | talk, choose, crew | the moving deck, stations, the articles |
| 21 | Learning the Ropes | the first reach | Trim into a current, ride a tide-race, fill a slack sail with Gust. Kessa notices the glass. | sail_to, race, lock_cast | sailing, Breath at sea, Draw (Rook) |
| 22 | The Dead Ships | the wreck field | Salvage keelstone from old hulks (an Earth sloop among them), fight off the Smoke's scavengers, and be back aboard before the current turns. | steal, kill, extract | extraction by ship, wreck-dogs (wolf AI) |
| 23 ★ | Storm at the Shoal | the lightning shoal | Smother the burning sails. Two men go over on tethers and you can Draw back only one: Rook's man, or the bosun's mate whose line Rook's man is already cutting. Patch the hull after. **If you miss the lock, Kessa catches the line**, and the moment counts for her, not you. | defend, survive_until, lock_cast, choose, repair | ship damage, Kindle and Smother (Hadu), a tally moment |
| 24 | Rook's Table | the stern, night | He tells you about the tar camps, the ship that took a boy off the Hudson, and the farm he was promised. He asks what you carry. Later, his oilskin case of letters: open it before the watch changes, or don't. | talk, choose, stay_unseen, read | dialogue, documents, the tally |
| 25 | The Dead Beacon | the first reach | A dead beacon on a floating rock. Kindle it and hold up the Wayglass, and a channel appears. Kessa tells you what the glass is. Rook is watching. | go_to, lock_cast, talk | a Sway puzzle, Flare (Kessa) |
| 26 ★ | Mutiny | every deck | Sarrow means to give the glass to the Lenswrights. Rook's Smoke hands take the ship to keep it. With a high tally he offers you a share ("Stay with me. I'll see you home."); otherwise he comes for the glass in a **crossing duel**. Join him, or escape in the longboat with the glass and the wounded captain. Lose badly and you are marooned: **The Rock**, a floating island where you make shelter and fire and signal Kessa (the homestead verbs again). | choose, kill or stay_unseen, escort, build, fire_lit | deck fighting, Sway against Sway; the branch *The Rock* |
| 27 ★ | Nine Pins Rising | the approach to Ossel | Nine chained pyramids, eight lit and one dark, and the docks crowd round you. By longboat through a dust wind, aboard the stolen ship, or on Kessa's skiff from the Rock. The branches rejoin here. | sail_to, go_to | the city streaming in, crowds, staging |

### 10.4 Act 4: The Ninepins (Vessary, summer 1758 - June 1761). Loop 4 and full raids, ~8 h, 11 missions

| # | Mission | Where | Summary | Kinds | Systems |
|---|---|---|---|---|---|
| 28 | A Bed in Landfall | Landfall | Earn a bed from Hannah Mercer by a delivery across the Scales. A Warden chase passes: help, hinder or watch. | deliver, talk, chase | the city, the law |
| 29 | Weights Against You | the Links | Sisk's Smoke hang pins on your name. Survive a street ambush and learn the Wanted Scale and the Lamp Chain. | survive_until, kill | bounties, the Lamp Chain |
| 30 | The Lenswrights' Door | the lens school | Mother Sael's trials: lock on a falling plate, a moving skiff and a far lens. Join, or leave with what you learned. | lock_cast, choose | mastering the Sway, Mark |
| 31 | A Berth of Your Own | the High Docks | Buy a berth with salvage money, or win one in a race round the pins. Refit a salvaged hull and take your salvage share. Hire your crew (the household). | choose, race, repair, crew | one berth, one salvage share, crew |
| 32 | Into the Hollows | under the Third Pin | A gallery collapses and the rubble floats. With Gorran Tell, who teaches Lighten, bring out a buried shift. Someone is digging toward the Ninth Pin. | escort, survive_until, lock_cast | interiors, the Weight art |
| — | *Two years in the Ninepins* | card | Summer 1758 to spring 1761. Contracts, side chains and free roam fill it. The comet tide closes in March 1759. | — | the date jump |
| 33 ★ | The Company's Flag | 6 June 1761 (H), the High Docks | On the transit tide the *Albany Venture* limps in from a half-charted crossing with a band, forty Company marines and Silas Vane. If Jost was held in Montreal, he is aboard as the Company's cabin boy, 13 now, with the news that Quebec fell and Montreal surrendered (H). "I brought you someone." Choose where you stand. | talk, choose | staging, crowds, the Factory |
| 34 | Rook's Hand | the Terraces and the Factory | Vane is buying pins. Run it as a heist (scout; prepare with a bribed clerk, a dust wind or Mark through walls; go in loud or quiet) for his ledger, or carry his bribes for him. In the ledger: your chart pages in Rook's copy, and a patent in two names. Rook's hand corrects itself into Fraktur. | steal, stay_unseen, deliver, read | heist roles, the lettering correction |
| 35 | Rook's Choice | his room in the Links | Face him. He sold the door and you for a farm for you both, and believes it a gift. Vane has cheated him too: the patent's land is under another claim, the double sale again. Help him, give him to the Wardens, or let him go. | choose, talk, capture or defend | a standoff, the tally |
| 36 ★ | The Weighing | Landfall to the Weighing Hall | Get the ledger and your witnesses across the city alive while the Smoke and the Company hunt you, then watch the pins fall. Whoever you helped turns up, six at most. | escort, survive_until, choose | reputation decides the vote |
| 37 ★ | The Dark Pin | the Ninth Pin | Whatever the vote, Vane moves on the Lantern: a galleon fight round the pins, a climb up the rusted chains, Kolb on the gantry, Vane at the lens, and a final six-second Beacon lock. Rook stands with you, hesitates, or stands with Vane. If you miss the Beacon lock, the ally with your highest standing finishes it, and the epilogue credits them. | sail_to, defend, kill, go_to, lock_cast, choose | everything, within 12 animated |
| 38 | The Long Way Home | Vessary, the closing tide, the valley | You see what the city became. The tide is closing and the last ships go down for eight years. Stay, or cross home to the valley in summer 1761: the farms rebuilding, Montreal fallen, captives coming home (H: check the 1760 returns), your clearing grown with birch. Free roam goes on; *The Ford* (1765) is the next storyline. | sail_to, go_to, choose | a map change, a date jump, the 1761 layer |

**Every community has a way through.** Missions 34 to 37 can be played from inside any Vessary
community. For example, in *Rook's Hand* a Lenswright reads the ledger at the Weighing's archive, a
Hollower comes up through the Factory's floor, Landfall's printer forges a clerk's pass, the Smoke
steals it, House Ammert subpoenas it, and a Company man carries the bribes.

### 10.5 Endings

The last choice is made at the Lantern. Your reputation decides which options you have.

1. **The Lit Passage** (needs the Lenswrights and the Beacon). The glass goes back into the great lens.
   The channel is lit for every ship until the door shuts in 1769. Landfall grows, the Company has to
   trade under the Scale, and Vane stands trial if you took him alive with the ledger.
2. **The Burned Glass** (always open). You break the glass in the fire, and the Ninth's channel is lost.
   The Company's men join Landfall or are unpinned.
3. **The Company's Port** (needs Vane's trust). The treaty stands and a Company factory takes the High
   Docks. You are rich and titled. Landfall never forgives you, and when the door shuts in 1769 the
   factory is stranded under the Wheel.
4. **The Pilot-King** (needs the Smoke or your own crew). You keep the glass. Only your ships know the
   channel, and Rook's too if he kept faith. The Weights hunt you for good.

Mission 38 follows any ending: stay, or ride the closing tide home. A last card tells those who stayed
about the door of June 1769. Epilogue cards follow whoever is alive: Rook, Vane, Sarrow, Kessa, Jost,
Titus, Hannah, Margaretha, and Leclerc by letter from Quebec.

### 10.6 Rook's hidden tally

Six moments. The player never sees a meter.

1. You share your bread on the walk (12).
2. You sing the hymn on his fever night (13). This only exists if you learned it in *Neighbours*.
3. You keep his secret from the fort and from Lisle (13-17).
4. You save his man in the storm (23).
5. At his table you ask about his farm, not his ship, and leave the oilskin case shut or tell nobody
   what is in it (24).
6. You show mercy in the mutiny (26).

| Tally | At the Mutiny | At the Dark Pin |
|---|---|---|
| 4 or more | He offers you a share | He turns on Vane |
| 2 or 3 | He offers you a share (3) or comes for the glass (2) | He hesitates, and you must cross him |
| 0 or 1 | He comes for the glass | He stands with Vane |

What you say at *Rook's Choice* (35) moves him one either way.

### 10.7 Pacing

Act 1 about 1 h 30, Act 2 about 4 h, Act 3 about 3-4 h, Act 4 about 8 h: about 17 hours of main chain,
then free roam. Each act runs settle, threat, set piece, loss or turn, then a quiet reckoning card.
No template repeats twice in a row.

### 10.8 The consultation rule in this story

The main line needs no Native character, name, line, town life or adoption. v4's Parts 1 and 2
(*Taken In* and *The Burning*) leave the main line and become an optional storyline (section 18) that
waits on the offices: Odanak and Wôlinak first, then Kahnawake and the others the critic lists. The
remaining slots in this story are the source of the 1757 warning, the noon warning of 1758, the
raid's allies, and the captives' march beyond the first camp. Each office is asked for its list of
what is off-limits before anything is written.

## 11. The Sway (the bending)

### 11.1 The rule

- Ready the empty casting hand, aim with the over-the-shoulder aim, and hold the crosshair on a target
  (an object or an enemy). A ring fills over that move's lock time.
- If the aim leaves the target for more than **0.15 s**, the lock breaks. **Only a full lock casts.**
- At full lock the ring closes with a click. Release within **1 s** to cast. Hold longer and the lock
  fizzles, but you keep your motes.
- `JogAimArm` points the arm at the crosshair's point (`get_aim_point()`), and the head follows it. Both
  are built.
- You can walk while locking. Sprinting, climbing, rolling, being knocked down or drawing a weapon
  breaks the lock. **Any hit you take breaks your lock, and any hit you land on a caster breaks theirs.**
- **Crossing.** Lock onto a caster who is locking onto you. Whoever fills first wins; the loser's lock
  snaps and they stagger. It is a standoff (Ghost of Tsushima's lesson): camera, silence, two threads.
  It serves Rook, the House duellists and PvP.
- **Teamwork.** Two crewmates locking one target fill it 50% faster.

### 11.2 The moves

| Move | Art | Lock | Motes | Range | Effect | Counterplay |
|---|---|---|---|---|---|---|
| **Gust** | Breath | 0.6 s | 1 | 25 m | A push: knock down, blow out a torch, fill a sail | Brace (crouch, ground the musket); heavy targets; break sight |
| **Draw** | Breath | 1.2 s | 1 | 15 m | Pull an object or a held weapon to you; pull an ally back from a fall | A two-handed aim resists it; strafing breaks it |
| **Flare** | Light | 0.5 s | 1 | 30 m | A blinding burst; startles beasts; shows what is hidden | Look away; shutter your lantern |
| **Mark** | Light | 2.5 s | 0 | 80 m | Outlines the target through walls for you and your crew for 30 s | Stay out of sight; Veil-cloth |
| **Kindle** | Ember | 1.0 s things, 2.5 s people | 1 | 20 m | Sets alight fuses, sails, kegs, a coat | Water, a wet cloak, Smother |
| **Smother** | Ember | 0.8 s | 1 | 20 m | Puts out fire, or damps a flintlock's pan so it misfires | Prime again (a reload step) |
| **Lighten** | Weight | 1.5 s | 2 | 20 m | Floats a thing or a person for 4 s | Pin-weighted coats, lead; shoot the caster |
| **Pin** | Weight | 2.0 s people, 4.0 s ships | 2 | 20 m (120 m for ships) | Roots a person for 3 s; drags down a skiff, slows a galleon | Lighten cancels it; steer out of line |
| **Beacon** | Light (master move) | 6.0 s | 3 | 300 m | Lights a lens: a quiet exit from a wreck field, and the finale | The hold itself: you stand exposed |

Lock time stretches up to 1.5 times at long range or on targets that resist. Practice cuts it to
0.7 times.

**Reading the place** (each art needs something in the world):
- **Breath** scales with the game's shared wind (already used for scent) and is weak in tight rooms.
- **Ember** needs a flame within 15 m of you or the target: a torch, a fire, a lit lantern, a slow
  match, a burning thing.
- **Light**: Flare needs a light in view (the sun, a lantern, a fire). Mark and Beacon don't.
- **Weight** needs keelstone ground, so it works only on Ossel and in the Drift.
- **On Earth** you hold at most 3 motes and only Breath works. The frontier stays the frontier.
  The first lock at the wreck (mission 11) borrows the burning keel itself; it is not a move you keep.

### 11.3 Motes

- Motes are grains of keelstone in a belt pouch: 3 under our sky, 6 in the Drift, up to 10 with
  upgrades in Vessary.
- **The free floor.** The coal in your tinderbox breathes one grain back every 90 s, up to 2, anywhere.
  So you can always experiment.
- Above the floor, motes refill at one a minute under the night Drift, all at once at a lit beacon, or
  when you grind a keelstone shard from your pack.
- Keelstone is also loot, so big plays are a choice between spending and selling. That puts the Sway
  inside the extraction economy without making players afraid to try it.

### 11.4 On screen

- A thin ring round the crosshair fills clockwise. The target gets an outline in the art's colour plus a
  ring shape for colour-blind players: Breath open, Light dotted, Ember notched, Weight doubled.
- A tone rises as it fills; the ring flickers in the 0.15 s grace.
- The casting hand reaches out and trembles as the lock nears full.
- **At 50%, a faint thread of light runs from your hand to the target, visible to everyone.** NPC targets
  flinch or dive for cover. When someone locks onto you, you see their thread, plus a soft arrow at the
  screen edge if it comes from behind.

### 11.5 Teaching and growth

| Art | Taught by | When |
|---|---|---|
| Breath | Rook: Gust (14), Draw (21) | Acts 2-3 |
| Ember | Hadu, the bosun: Kindle and Smother (23) | Act 3 |
| Light | Kessa: Flare (25); Mother Sael: Mark (30) and Beacon (her chain) | Acts 3-4 |
| Weight | Gorran: Lighten (32); House Ammert's duellists: Pin | Act 4 |

Growth runs on `SurvivalLearning` (by doing, trying, being taught, watching). Use shortens locks,
stretches range and saves motes. A mentor's trial unlocks a variant, such as a cone-shaped Gust or an
Anchor Pin. (As built, 11.10: mastery is the caster's own count of casts landed per spell, `SwayCaster.uses`, saved with
the motes; its tier sets the hands, the clip and the lock time. Watching and being taught, a line in the Skills tab, and
range, motes, strain and break times that grow with it are still to come.)

### 11.6 Why it is fun and not spammy

- **A lock is a commitment.** You are slow, exposed and unable to fire, in a world of six-second reloads.
- **It controls rather than kills.** A musket ball is still the quickest kill. The Sway makes openings:
  Smother a sentry's pan, then close in with the saber; Lighten a crate, then Gust it; Mark a man for a
  crewmate's musket; Pin a skiff, then board it.
- **Every move has a counter**, and every lock can be seen and broken.
- **Holding a ring takes skill.** Keeping it on a running wolf or a banking skiff is a real aiming test.

### 11.7 Enemies who use it

| Enemy | Moves | How to deal with them |
|---|---|---|
| The Smoke's dust-burners | Kindle, Flare | Bring water; look away |
| The Wardens | Pin, to arrest | Their pin coats shrug off Lighten |
| Lenswright cutters (5 lamps) | Flare beams, Pin on skiffs | Get under awnings and galleries |
| Rook | Gust, Draw, crossing | Break his lock from behind the mast |
| House duellists | Pin, Mark, crossing | Win the crossing |
| Company marines | No Sway | Their covered-pan locks resist Smother |
| Kolb | No Sway | His lead coat ignores Draw and Lighten |

**AI rules:** the AI uses the player's rules and shows the same ring and thread. Its locks take 1.3
times the player's time. At most two casters may lock the player at once. An AI caster always lets go
when line of sight breaks. Native beings are never enemies or powers.

### 11.8 Tuning and build path

- **Data:** `data/sway/moves.json` holds each move's lock time, radius, grace, release window, motes,
  range, source, moving penalty, growth steps, and the AI factor.
- **The ring:** `GripRing` (`scripts/climb/grip_ring.gd`) becomes the lock ring, a second mode of the
  same widget.
- **The target:** a hit test from `get_aim_point()` on the target's body, plus a 2° grace cone.
- **Animation:** each move needs only the existing aim pose plus one short release clip (0.3-0.5 s),
  keyed in Blender the way the forage grab was (`tools/anim_author/blender/forage_grab.py`, installed
  like `install_forage.gd`). Log every Sway clip in `animations/SOURCE.md`.
- **Effects:** Gust and Draw are impulses; Lighten and Pin reuse the ragdoll, impulses and damping;
  Kindle is fire and ruin's ignite; Smother sets the target's flintlock back before its priming step
  (`over_under.gd:75`, `powder_pour_pan`); Mark is an outline shader shared with your crew; the thread
  is a single line mesh, with small particle counts and no fluid simulation.

### 11.9 Ships run on the Sway (owner, 2026-10-02)

Keelstone floats a galleon; the Drift's currents carry it slowly. What makes a ship fast, or able to fight, is its crew's Sway:

| Station | The cast | Notes |
|---|---|---|
| **Windcaller** | Lock on a sail and **hold** it: the wind stays in the sail while the lock holds; motes drain each second held | Two on one sail fill it 50% faster (11.1 teamwork). A hit on a windcaller breaks the lock and the sail goes slack |
| **Gunner** | Lock on the shot in its cradle: the longer the lock (0.6-2 s), the harder the push; release fires | No powder and no reload, but the gunner stands exposed while holding |
| **Heavy shot** | Ballast boulders: two gunners lock together | The crew's coordination moment in PvP and boss fights |

Motes (keelstone shards) are the ship's fuel: a long chase burns the crew's stores, raids for keelstone matter, and spend-or-sell
(11.3) holds at ship scale. Rook's Gust (14) pays off in Act 3: the player's first berth is windcaller on the *Long Patience*.
Open: a few rare powder cannons bought from Earth smugglers (prized, loud, and they need no caster).

### 11.10 Mastery, levitation and the Gust musket (owner, 2026-10-02)

- **Every move grows by use** (by doing; as built, the caster's own count of casts landed per spell, not yet SurvivalLearning: 11.5):
  **untrained** = both hands empty, kneel and press the palms to the floor while the ring fills (held still meanwhile; the pillar's
  run-launch comes at practised); **practised** = a two-handed standing push; **expert** = a one-handed push, the other hand free to
  hold a pistol, tomahawk or saber, which still fires or swings (left click) while the spell is readied, the aim button being the
  spell's lock. Gust needs only one free hand once expert, and does both jobs: the push in a fight and the wind held in a sail (11.9).
  Spells are readied only from the hotbar: a grant puts them in the Tab screen's Spells list, dragged onto 1-9.
- **The Form art unlocks at the crash** (mission 11): the wreck is where the shaping is learned. Its moves: earth wall (cover),
  stone form (spike / cannonball, replacing stone spikes), pillar and mend. Levitate was planned here and folded into Gust the same
  day (the Modes bullet): Gust locked on a boulder (the ships carry them as shot and ballast) lifts it while held, like a bowstring
  drawn; strain builds; release hurls it along the aim; held too long the power breaks (it drops, the caster staggers, the motes are
  lost). Heavy stones need two casters. Shape planks is dropped.
- **The Gust musket** (an upgrade once Gust and its stone hurl are known): no powder; the ball is loaded and rammed and Gust drives it out.
  Reload about a third of the flintlock's 6 s, no powder smoke (a ring of wind at the muzzle), quieter; each shot spends Sway. The
  flintlock stays as the weapon that needs none.

- **Modes** (one key flips a spell's mode; the hotbar icon shows it): **pillar** in *self* mode by default rises under the caster
  (cast in stride while running it launches you up and forward, timed on the foot plant for a boost; cast mid-jump it rises where you
  land) or in *free* mode wherever the circle is aimed (out to 10 m); **stone form** raises a *spike* (it hits whoever stands there; levitated it
  flies like a lance) or a *cannonball* (levitated it flies heavier and farther and rolls). **Gust hurls them** (owner, later the same day: no separate levitate): Gust held on a stone (a raised spike or cannonball, a ship's boulder)
  lifts it like a bow drawn, release hurls it, held too long it breaks. The spells: **Gust** (push, sails, hurl stones); **Form**: earth
  wall, stone form (spike / cannonball), pillar (self / free), mend.

## 12. Co-op and the Arc Raiders inspiration

### 12.1 What stays solo

- **The whole main chain and every tally.** All consultation-slot content. Every beat that changes the
  story's world: the raid, the reveal, the Mutiny's choice, the vote, the Lantern choice, the endings.
- **The crew character is separate by default:** a Vessary-born or Landfall sailor (or a fort survivor
  for *The Fallen Ship*). It has its own berth, stash and reputation. Co-op loot never enters the story
  save; links are cosmetics and reputation titles only. This keeps spoilers out of co-op and keeps gear
  loss and murder tags out of the story.

### 12.2 What co-op gets

- **Crew Runs.** One galleon carries 2-8 players. Stations: helm (heading and height), sails (timed trim
  to the current), keel (ballast up or down; it can overheat), two to four guns, lookout (spyglass,
  Mark), and the Sway-hand (Gust into the sails, Pin another ship). In solo, household and crew NPCs hold
  stations with simple automation, the way household jobs already work.
- **The hub is Vessary, walked**, not a menu (Arc's CEO called its menu hub underused). Contacts hand out
  contracts, the way Arc's and Tarkov's traders give quests.
- **The raid:** sail out through the Tether Gates to a wreck field; board hulks and islands on foot; loot;
  fight; get back aboard. Threats: the Smoke, Company salvors, wreck-dogs (wolf AI), drift-oxen with a
  matriarch boss (bison and mammoth rigs), storms, and other crews.
- **Ways out:** the tide (exit channels close on a posted timer); a Tether Gate call (loud, 90 s, every
  crew hears the bell); a dead beacon lit with Beacon (quiet, needs a lens charm, once).
- **Loadout risk:** your pack drops where you die (`DeathRule`); one item in the coat lining survives;
  your hold can be plundered if you're boarded; a crippled ship limps home. The free **Landfall kit**
  (a pistol, a cutlass, rope, 2 motes, no lining slot) means a bad run never locks you out.
- **Between raids** your berth's crew salvage for you, like Arc's rooster.
- **Contracts** repeat once a contact's chain is done (with their story effects removed): escorting
  crossers, rescuing shifts, relighting beacons, Company salvage, dust runs, House debts, and Warden
  bounties on NPC outlaws or on players with the killer tag. Never on freedom-seekers.
- **Set pieces as crew challenges:** *Storm at the Shoal* replayed as a crew challenge with no story state
  (Sea of Thieves' Tall Tales).
- **The almanac** rotates conditions: Beacon Night, Dust Wind, Low Drift, Lightning Shoal, the Company
  Convoy, the Herd Crossing. **Quiet Drift** turns off PvP and pays about 30%.
- **Peace tools:** ground your musket (`musket_butt_ground.gd`, built), a parley flag on the mast, a
  "Friend!" bark.

### 12.3 The Fallen Ship (the Earth-side mode, on the existing map)

- Winter 1757-58 on the valley's burned layer, with Fort Herkimer as the hub (a menu first, walkable later).
- Loot: keelstone shards, wreck parts, iron from the farms, stray stock.
- Threats: wolves, cold, river ice, other squads, and, once fighters exist, small French and Canadian
  parties (never Native warriors).
- Ways out: the fort gate (loud: a drum and a slow gate) or your hidden canoe (quiet).
- **The Burnt Flatts** is the same mode with no wreck and no wonder, for strict-history lobbies.

### 12.4 Numbers and tech

- **8 players** by default when a player's Mac hosts (2-4 crews of 2-4). **12** only after animation level
  of detail for remote players (P8). **16** only on a headless server, which is where the owner's 8v8
  (`docs/multiplayer_readiness.md`) lives as **Convoy**: two Company galleons and their skiffs against two
  raider ships in a channel. Only the squares near players are simulated.
- **The ship is a moving platform:** players and dropped items are held in the ship's own space (new, M).
- **Story cards must not pause in co-op** (`story_hud.gd` ~160).
- **Hits move to the host** (`NetSession.forward_hit`, `net_session.gd:476`) before any public PvP with
  gear loss. Among friends the shooter's machine can keep deciding.

## 13. Maps

Full plans and budgets are in `docs/maps.md`. In short:

| Map | Acts | Size | State |
|---|---|---|---|
| The Mohawk Valley | 1, 2, 4 (home), *The Fallen Ship* | 3×3 squares of 832 m (~2.5 km); the slice needs only the 2 baked squares | Exists; needs the 1757, burned and 1761 layers |
| The galleon (*Long Patience*) | 3, 4, co-op | The model: hull ~26 m, ~32.5 m overall | Model in progress; export first |
| The Upper Sea (the Drift) | 3 | 3 reaches, each ~1.5 km × 600 m, no terrain | New |
| Wreck fields | co-op raids | ~1 × 1 km; *The Dead Ships* reuses reach 2 | New |
| Vessary | 4, the hub | 1 square (832 m) with a dense core ~600 × 450 m | New |
| The Hollows | 4 | ~400 m of galleries | New interior |

New terrain: one square (Vessary), plus one optional valley square. v1's North Woods, Mountain Road,
Albany and travel map leave this spine.

## 14. Features to build

### 14.1 Against the codebase audit

| Gap (audit #) | Size | What it serves here |
|---|---|---|
| 1 Human NPC fighter and brain (and NPC animation LOD) | L | The playable raid, the wreck race, the Mast-Runners, the mutiny, the Wardens, the Smoke, the marines, raid AI. Must react to a lock at 50% |
| 2 Objective kinds, fail rules, checkpoints, branches, `when`, effects as data | M | Every mission, plus `choose`, `lock_cast`, `sail_to`, `crew`, `extract`, `race`, `read`, `repair` |
| 3 Dialogue box with choices, barks, letters | M | Every contact; city barks; pin-hole plates |
| 4 Contact bodies | M | The Rauchs, Vane, Leclerc, Rook, Lisle, Titus, the crew, the city contacts |
| 5 Fire and ruin | M | The raid, the wreck, the burned layer, Kindle and Smother, burning sails |
| 6 Captivity | S-M | The march; work-gangs; arrests |
| 7 Witnesses, hue and cry, tags | M-L | The fort's law; the Lamp Chain |
| 8 Map framework, layers, date jump | L | Valley layers, the Upper Sea, wreck fields, Vessary; the jumps to 1761 |
| 9 Cutscene staging | M | Missions 11, 19, 20, 27, 33, 36, 37 |
| 11 AI boats and crews | M, growing | AI galleons, skiffs, crews at stations |
| 13 Quest log, journal, map | S | Early; the chart pages are a plot object |
| 14 Learning from a mentor | S-M | Sway lessons and trials; French |
| 15 Large interiors | M-L each | Below decks, the Weighing Hall, the Hollows, a Landfall tavern, the Factory |
| 16 Co-op story cards | S-M | Contracts and crew runs |
| 17 Player ageing | S | Optional: four years show on the face by 1761 |

Deferred: 10 (mounted combat; no horses in the sky) and 12 (bear, moose and beaver, which belong to the
North Woods storyline).

### 14.2 New

| Feature | Size | Builds on |
|---|---|---|
| **The Sway lock-on** (ring, grace, release window, motes and the free floor, crossing, the thread, 9 moves, NPC casters) | M | `GripRing`, `get_aim_point()`, `JogAimArm`, the head look, `Hit.deliver`, `data/sway/moves.json` |
| **The falling ship and the wreck** (scripted fall, fire, smoke; a broken and burning model) | S-M | `sky_galleon.glb` (export first), TorchFire, `wonder_reveal` |
| **The galleon** (a deck you walk while it moves; currents, stations, damage, boarding, `repair`) | L | `Boat.drive`, `BoatRider`, `crew_on`, building pieces |
| **Moving-platform sync** | M | `NetSession` |
| **Upper Sea map type** (reaches, currents, islands, haze, fog walls) | M-L | The wonder sky, `SkyTraffic` |
| **Island and wreck-field kit** | M | `StructureMeshKit`, CC0 rocks |
| **Extraction framework** (raid flow, exits, stash, containers, the coat lining, the almanac) | M | `DeathRule`, `PackDrop`, `NetSession` |
| **Vessary kit** (pins, chains, parametric houses, docks, the Lamp Chain's lamps) | L | `StructureMeshKit`, terrain flat zones, visibility ranges, occluders |
| **Crowd stand-ins** (walking cards baked from Actor_B in the period garments, 8 directions, moved along lanes by a shader; a card swaps for a full body only within ~15 m when a mission needs it) | M | The trees' impostor cards |
| **NPC bodies on AnimationPlayer with animation LOD** | M | `WildAnimal._step_anim` (`wild_animal.gd:447`) |
| **One berth and one salvage share** | S-M | Household jobs, `SurvivalEconomy` |
| **A Sighted sky per player; story flags in co-op** | S | `WonderLook`, `StoryDirector.flags` |
| **Community lettering and French glosses** | S-M | StoryHUD; UnifrakturMaguntia, Libre Caslon (OFL) |
| **Items:** the tinderbox and its coal, the Wayglass, keelstone and motes, the song, notes and letters | S | The pack, the economy |
| **The tide calendar** (dated doors in the `seasons.json` style) | S | `SurvivalClock` |

Cut or later: skiffs as stealable city cars, ship insurance, more businesses, the travel map.

## 15. Build order

1. **Vertical slice, "Two Fires": the reveal and the first lock inside two hours.** Missions 1-12 and 14
   on the existing valley (`fort_woods` and `open_land`, both baked). Mission 13 waits for the burned
   layer. No human AI. It needs:
   - **The Prologue fixes** (data, S): the title card, the texts, the homestead and places on the east
     bank, and the story's 1757 layer without mammoths or bison. The layer itself (M): the Flatts farms,
     the ford, the unfinished church, the mill, the pine grove at the head of the open land.
   - **Talk:** `talk`, `deliver` and `choose`; a minimal dialogue box with Fraktur and round hand; the
     hidden count; bodies for Margaretha, Anna, Jost and Vane, none of whom fight.
   - **The raid as built** (heard and told in cards), plus a scripted run, a staged capture, and fire and
     ruin v1 on your own house.
   - **Captivity v1:** `BareStart`, a bound state, the march behind a scripted Leclerc with two guards on
     the `FilmActor` pattern (sight cones, no brain).
   - **The fall:** export `assets/sky/sky_galleon.glb` from `tools/models/sky_galleon.py` **and a broken,
     burning variant** (this is on the slice's critical path); the scripted fall; Ithel posed and dying;
     Rook's body with no shadow; the Wayglass and the tinderbox coal; the reveal (built); 3 camera takes.
   - **The Sway v1:** the lock ring on `GripRing`, the target query, motes with the free floor, the first
     lock (the spar) and Gust (*First Lesson*), one release clip; Rook's walk with the wolves (built);
     `SkyTraffic` over the valley to close.
   - **Pacing:** the house by about 60 min, the errands about 15, the raid and march about 15, the fall at
     about 1 h 35, the end near 2 h.
   - **Test:** a steady 60 fps on the medium preset through the burning wreck. The slice shows whether the
     reveal lands and whether the lock feels good, before any galleon or city work starts.
2. **Human NPC fighter (L)**, with animation LOD for NPC bodies: the playable raid and every fight after it.
3. **Mission flow and talk:** objective kinds, fail rules, checkpoints and branches (M); the full dialogue
   box with choices (M); the quest log (S).
4. **All of Act 2 and *The Fallen Ship*:** the burned layer, full fire and ruin, captivity, the fort's hue
   and cry, the extraction framework, friends' lobbies of up to 8.
5. **The galleon and the Upper Sea (Act 3):** the ship scene with its origin on the ship, sailing and
   stations, moving-platform sync, one reach first and then three; Draw, Kindle, Smother and Flare.
6. **Vessary's first district:** the High Docks, Landfall and the Scales with three pins in full detail;
   crowd cards; the Lamp Chain; one berth and one salvage share; missions 27-31.
7. **Wreck-field raids, contracts and the almanac:** crews raiding from the city, with hits decided by the
   host before any public play.
8. **The rest of Act 4,** the endings, and the valley's 1761 layer.
9. **Later:** Convoy (8v8) on a headless server; *The Ford* (1765); the consultation storylines as offices
   sign.

## 16. Risks, and how the design keeps each one small

### 16.1 Scope

- **Caps:** 38 main missions, 11 contacts with at most 4 side missions each, 9 moves, 4 endings, six
  allies at the Weighing, one city square, one detailed ship model, three reaches, one raid map at first.
- **Reuse:** Acts 1-2 play on the valley we have. Every people uses one human rig. Beasts use the wolf,
  bison and mammoth rigs. The sky maps have no terrain. Ship work reuses felling, building, the horse and
  the household as crew. *The Rock* is the homestead again.
- **Proof before spending:** the slice proves the reveal and the lock before any galleon work.
- **Cut lists:** if the galleon slips, Act 3 shrinks to 20, 22, 23, 26 and 27 on one reach. If time runs
  short, Act 4 drops to about six missions (28, 30, 33, 34, 36, 37) with 38 told in cards.

### 16.2 Sensitivity

- **Native nations.** The main line needs none of their content (section 10.8). Native warriors are never
  AI enemies; the raid's allies appear only in reviewed text; the warnings go to the Oneida offices; no
  wampum belt is ever an item or loot. The wonder borrows no Indigenous belief: no wendigo, no sky-canoe
  tale, no chasse-galerie. Every invented word is checked against real languages and sacred vocabularies.
  The ranger companies that included Stockbridge men stay off screen.
- **The pyramid city** follows the list in 8.1 and is never a people waiting to be saved.
- **Landfall** is written with sensitivity readers. Freedom-seekers are never bounty targets, and slavery
  is never a spectacle. The household's workers are paid crew under signed articles. Slavery in New France
  (mostly of Indigenous people) is consultation material.
- **Children** flee and can never be harmed by the player or the AI. Jost cannot be killed. Harm to
  children in the real raids appears only in text.
- **Gore.** No scalps, gauntlet or cannibalism on screen. The raid's dead are told, not displayed.
- **The hymn** is a real hymn, used with respect and never as a spell.
- **Real people** stay in the background.
- **Rights.** Section 7.6 for Disney and Nickelodeon. Disclose AI-assisted assets as Steam requires. Keep
  `SOURCE.md` and SHA-256 records for every asset, font and scan.

### 16.3 Performance on the M4 Mac mini

| Cost | How the design holds it down |
|---|---|
| People | At most 12 fully animated anywhere; AnimationPlayer bodies with animation LOD (a full player tree is ~2 ms each); crowd cards and sound for the rest |
| Fire | One shared fire light without shadows per scene (a torch light is 0.55 ms, 1.4 ms with its shadow); Kindle fires are glowing materials and particles |
| Open sky | Haze and fog-walled reaches instead of long sight lines; no open water anywhere |
| Ships | At most 2 near in a fight, 2 over the valley, 3-4 in the city; `Galleon_LOD1` past 450 m; story ships have no physics until a mission needs it |
| Players | 8 on a host Mac; only the squares near players simulated |
| The city | One square; merged blocks; box occluders (the pins are natural ones); lamps glow by material; interiors only for mission buildings |
| Dev work | Bake one square at a time; one Blender process at a time |
| Fallback | A "Cool" preset (30/40 fps cap, 0.75 render scale with MetalFX, 2 shadow splits). It is a fallback, not a budget |

### 16.4 History

Check before writing in-game text: the raid's figures and route; the warnings; which redcoats were at the
Flatts that winter; the 30 April 1758 noon warning; the white pine laws in New York; the hymn's date; the
pirates' articles; what happened to captives in 1760; the Burnetsfield patent; the tar camps of 1710-12.
The astronomy (Halley's comet in 1758-59, the transits of 1761 and 1769) is High. Publish the basis keys
rather than claiming "accuracy".

## 17. The Ford (1765-68): the storyline after the main story

*New York, autumn 1765. The war is over, the garrison is leaving, and Albany money wants the ford.*

- **The hook (v4).** Elias Crane (invented), who held a lease at the ford, is found dead in the river, and
  the lease has been sold twice. His family pulls you in.
- **Who plays it.** After the Home ending the main character can go on into it. A new character can start
  it from New Game (Story off is free play in 1765).
- **The antagonist** is Hollis and Company. Its man on the spot is Silas Vane if he came home alive,
  otherwise Nathaniel Hollis (the chain passes on).
- **Its contacts and main chain** (the sergeant, the sutler, the trader, the farm family, Rankin, Ackerly,
  Sarah Kerr, the quiet man; four parts, about 20 missions) stand as drafted in v4 (commit `c05979f`)
  until its own pass.
- **Fixes for that pass:**
  - The 1768 line (critic A5): the land fight is a double sale of land patented long ago, not newly opened
    land at the Flatts. The line's Canada Creek is at Wood Creek, not West Canada Creek.
  - Courts were Albany County's until Tryon County was created on 24 March 1772.
  - Unstamped deeds (H: the Stamp Act in force 1 November 1765, repealed 18 March 1766) are Vane's lever.
  - The farm family's missing brother comes from the 1757 register in *Ash*.
- **Ties to the main story:** your register entry, your burned lot (sold or kept in *Ash*), Vane's note,
  and whoever lived.

## 18. Future storylines (one valley, many years)

The map is the same each time, changed for the year. Each needs its own research pass.

| Year | Storyline (working title) | The history (H, verify) | Native consultation |
|---|---|---|---|
| 1757-60 | **Taken In** (with *The Burning*, 1759) | Captivity and adoption in a mission town; Rogers' raid on Odanak, 4 October 1759 | Essential: Odanak and Wôlinak first. Only Odanak fits both the capture and the burning |
| 1758 | **The Carry** | Building Fort Stanwix at the Oneida Carry | Needed (the Oneida) |
| 1759 | **Rangers** | Rogers' Rangers and the lake war | Needed for the Stockbridge companies |
| 1765-68 | **The Ford** | The garrison leaves; the Stamp Act; a double-sold lease | Slots only |
| 1775 | **Liberty Pole** | The Revolution splits the valley | Partly |
| 1777 | **The Siege** | Fort Stanwix and Oriskany | Essential |
| 1778-80 | **The Burning Valley** | Raids up and down the valley | Essential |
| 1790s | **The Turnpike** | Settlers flood west; the canal is planned | Partly |

One character lives the main story. *The Ford* can carry that character on or start fresh; every other
storyline starts fresh. The backlog's 1757 and 1761 starts become the main story's Act 1 and its Home
ending.

## 19. Decided

**2026-10-01 (owner), kept:**
- The frontier is open: anyone can be attacked, and reputation is the consequence.
- You play your own character; the story is roleplay.
- One character lives the main story, Two Fires. Every other storyline starts fresh (*The Ford* may also
  carry the main character on).
- You can join communities, Native nations included, under the consultation rule.
- All dialogue is text, no voice acting: dialogue boxes, short barks in the world, letters and broadsides
  as readable items.

**2026-10-02 (owner), new:**
- **The spine:** primitive first (Act 1, the real 1757 frontier: the German Flatts homestead, the raid,
  captivity, with history kept true), then a world of wonder with sky galleons, then a bustling world of
  pyramids.
- **Treasure Planet's 70/30 rule** as inspiration (70% real 18th century, 30% wonder), with our own
  designs, names and lore: no Disney names, characters or ship designs.
- **GTA-style:** open world, missions from contacts, free roam, reputation per community, joinable
  communities, anyone attackable, chains pass on.
- **Powers** are element moves with a **timed lock-on**: hold the crosshair on the target for a per-move
  time; the lock breaks if the aim leaves; only a full lock casts. They reuse the existing aim system.
- **Arc Raiders** inspiration is welcome. The netcode allows 16, but a Mac host means 8-12.
- **Protect the M4 Mac mini:** the medium preset at 60 fps, at most ~12 animated people on screen, one
  shared fire light, crowds as cheap stand-ins, maps sized to stream; no design that needs huge crowds or
  huge open water.
- **Native nations:** nothing ships without the nation's office; the design works with the slots empty.
  The invented wonder world needs no consultation but borrows no real Indigenous sacred belief.
- **Build on what exists** (section 1).

## 20. Settled by this draft, for the owner to confirm

1. *Taken In* and *The Burning* leave the main line and become a storyline that waits on consultation
   (critic F1, F2).
2. With the slots empty, captivity is one night under French and Canadian captors, and Jost's Montreal
   captivity is the documented fallback (Catherine Frank's family).
3. **Magic policy** (critic F3): the wonder is the main story's own layer from mission 11; free play never
   sets the flag. The story's valley layers have no mammoths and no bison; free play keeps the sandbox;
   the rigs serve the Drift's beasts.
4. Lake George, the North Woods, Albany, the Mountain Road and the travel map leave this spine's map set
   (critic F4).
5. Vane enters as the Fort Herkimer sutler's partner (critic F5), modelled on Lydius, and he is Sighted.
6. No child can be harmed. No bounties on freedom-seekers, runaways, debtors or anyone for what they are.
   No scalps, gauntlet or cannibalism on screen (critic F6).
7. A player's Mac hosts 8 by default and 12 at most after animation LOD; 16 needs a headless server
   (critic F7).
8. The co-op crew character is separate from the story character.
9. In-game words: the Upper Sea, the Drift, the Sway. Never "etherium" or "bending" in player text.
10. No time slip: the dated tides (1757-59, 1761, 1769) are the clocks.

## 21. Open questions for the owner

- Is Rook's turn right: a Palatine boy of the tar camps who sells the door and you for a patent in two
  names, believing it a gift?
- May we use a real hymn (with respect, never as a spell) for Anna's song?
- The two years in Vessary (between 32 and 33): a date card with free roam, or contracts that move the
  calendar?
- The Home ending's 1761 valley layer: build it, or end on cards and hand straight to *The Ford*'s 1765?
- The galleon's mast-top fans: keep them, or cut to keel-fins and glowing canvas only (section 7.6)?
