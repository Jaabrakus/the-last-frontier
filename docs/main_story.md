# Story: an open-world history game, GTA-style

DRAFT v4 (2026-10-01). Nothing here is built. v4 adds the main story the owner
outlined (a fresh start, taken in by a nation, the raid on the town, then the British
taxes); The Ford becomes one part of it. v3 adds the owner's answers: it's
the frontier and anything can happen. You make your own character, anyone can be
attacked, reputation decides the consequences, and you can join any community,
including a Native nation, roleplay-style. v1 was a slow story about surviving and
settling; the owner asked for "the GTA of this", with many storylines from historical
events later. So this version is built around **storylines made of missions, given by
contacts, in one open world that you are free to roam between missions.** The first
storyline keeps v1's plot (the ford, the doubly sold lease, Hollis and Company) and
turns it into missions.

Historical claims use the project's basis keys (S / H / D). Every H still has to be
checked before it goes into in-game text.

## What "GTA" means here

| GTA | Frontier |
|---|---|
| A city you roam freely | The valley: the ford, the woods, the river, the Carry, German Flatts, later the town |
| A protagonist with a voice and a past | **Your own character** (customizer and background); who they become is roleplay: who you side with, who you join, what you're known for |
| Contacts on the map who give missions | People at their spot with a marker: a lantern in a window, a note nailed to a post, a man waiting by a canoe |
| Missions: chases, heists, shootouts, escorts | Horse chases, canoe races and pursuits, raids on a storehouse, ambushes, escorting a bateau, stockade defences, smuggling runs, hunts |
| Wanted level, police | **Reputation**, plus hue and cry for the moment itself (see below). **Hue and cry:** a crime seen by witnesses raises it; first the constable, then the magistrate's posse, then the garrison. Lose them in the woods or across the river, or lie low |
| Money, properties, businesses | Coin and the trader's book; property you buy, build or take (a cabin, a mill, the ferry, a tavern) earns income that the household works |
| Side activities | What the game already has: hunting, the range, wild horses, boats, farming, the household |
| Satire | Period satire: Albany speculators, pompous officers, the Stamp Act, pamphlets and broadsides |
| One map, several protagonists (GTA V) | One valley across decades: each storyline is the same map in a different year |

The survival sim stays underneath. A storyline is a layer on top of it, never a
replacement: you still have to eat, sleep and stay warm between (and during) missions.

## How storylines work

A **storyline** is one self-contained story pack:

- **era and start date** (for example autumn 1765),
- **the world state** for that year: which buildings stand, are ruined or are not yet
  built, who lives where, which roads and boats exist,
- **a starting hook** for the player's own character (why they are here this year),
- **contacts**, each with their own short chain of missions,
- **a main mission chain** (about 15 to 25 missions) and **side chains**,
- **endings**, after which the year stays open for free roam.

Storylines are data, so new ones can be added later without rewriting the game:

```
data/story/storylines/<id>.json   era, start, world state, lead, contacts, endings
data/story/missions/<id>.json     the missions: giver, trigger, objectives, fail rules, rewards, next
```

A small `StoryDirector` reads these files, puts contact markers on the map and runs
each mission's objectives through systems that already exist (combat, horses, boats,
hunting, building, the household). Mission objectives are a small set of reusable
kinds: `go_to`, `talk`, `kill`, `capture`, `escort`, `chase`, `steal`, `deliver`,
`defend`, `survive_until`, `hunt`, `build`, `stay_unseen`. A new storyline is mostly
data plus a few scenes.

### Rules

1. **Free roam between missions.** Every mission is started by the player at a
   contact. The calendar keeps moving, but the main chain waits for you.
2. **The world remembers.** Mission results live in the world (a burned storehouse
   stays burned, a dead contact stays dead, a won property is yours), the same way
   chests and field beds keep their own history.
3. **Anything can happen.** Anyone can be attacked, robbed, helped or ignored,
   contacts included. Nobody is protected, so a mission chain whose giver dies goes
   on through someone else (a widow, a partner, a rival) or ends. There is no game
   over, only reputation (below).
4. **Native nations.** Mohawk, Oneida, Stockbridge-Munsee, Lenape and other nations'
   characters get no lines, names or missions until that nation's office signs off
   (the backlog release rule). Where the history needs them, a storyline leaves a
   marked `[[consultation slot]]` and must still work with the slot empty. Several of
   the future storylines below depend heavily on this, and that is said next to them.

## Reputation

There is no single wanted meter. Every community keeps its own opinion of you, built
from what its people saw or heard:

- **Per person:** trust (already in `data/survival/npcs.json` standing).
- **Per community:** the garrison, the traders, the valley settlers, the outlaws, the
  authorities, each Native nation, and later the Patriots and the Loyalists.
  Communities talk to each other a little (word travels along the river at the speed
  of boats), so robbing the trader might please the outlaws and worry the settlers.
- **What you're known for:** a few tags that follow you everywhere, such as *a good
  shot*, *keeps his word*, *a thief*, *a killer*, *a friend of the Oneida*. People
  greet you, price their goods and offer missions by them.
- **Witnesses.** A crime nobody sees is only rumour. A crime that is seen starts a
  hue and cry right then, and the witness carries it to their community. Kill the
  witness and you get a worse tag.
- **The law** is just one community. Its reputation sets the bounty, the posse and
  whether the magistrate will hear you.

## Joining communities (roleplay)

You can belong to more than one community, and your standing in one can lock you out
of another. Joining changes where you live, who gives you work, what you wear and
what you're taught. It is never a different game mode; the same world just treats
you differently.

| Community | How you join | What it gives |
|---|---|---|
| The garrison / a ranger company | Enlist, or prove yourself to the sergeant | Pay, rations, army missions, the musket drill |
| The traders | Work the bateaux; buy a share | The river trade, goods, business properties |
| The valley settlers | Settle, marry in, keep your word | Land, a farm, neighbours who turn out to help |
| The outlaws | Rob, smuggle, run from the law | Black-market goods, raids, hideouts in the woods |
| Your own household and settlement | Build it (what the game already has) | Workers, a home base, income; others can join *you* |
| A Native nation | Adoption, as many settlers and captives historically were (E:S35, the backlog's `npc.town.adopted`) | A family and a town, a new name, that nation's knowledge, its storyline |

**Joining a Native nation** is the biggest roleplay path and the most sensitive one. It
can be designed into the framework now (the community, the reputation and the joining
flow), but each nation's people, town life, language and adoption itself are written
*with* that nation's office before they ship. That's the project's own release rule.
Until then the path stays a `[[consultation slot]]`.

## The main story: Two Fires (1757–1775)

*A fresh start in the open land. You build a home, lose it, are taken in by a nation,
make a name there, lose that home too, and end up between two worlds as the British
tighten their grip and the colonies move toward revolt.*

The arc follows what documented captivity narratives describe (H: James Smith,
captured 1755, adopted, back among colonists in 1760, leader of the 1765 "Black Boys"
rising against British troops and traders; Mary Jemison, taken 1758, stayed with the
Seneca for life; verify both before using any detail). The lead is your own
character, with no famous name. One character lives the whole story and ages through
it, and every other storyline in the future starts fresh.

### Prologue: Open Land (1756–57), the tutorial

- You arrive in the open land beyond the last farms with an axe, a gun and nothing
  else. **Make a name for yourself** starts here: nobody knows you.
- The tutorial is the game's own building and survival: fell trees, build a cabin,
  plant a field, hunt, catch a wild horse, the top-left key hints
  ([[project_first-time-tutorial]]). Neighbours at German Flatts trade with you.
- **The raid (November 1757).** A French-led force with allied warriors burns German
  Flatts (H: 12 November 1757, about 150 captives taken; verify). It's a playable
  night: defend the cabin, get neighbours out, and fail. The raid is part of a war
  between empires, not a "savages attack" scene; the text and the people on both
  sides show why it is happening.
- You are taken captive. The long march north is the first time the game takes your
  gear away and you survive on what you're given.

### Part 1: Taken In (1757–59)

- **Adoption.** A family who lost a son takes you in to fill his place; mourning and
  adoption were how many nations replaced their dead (H, verify per nation). You get
  a new family, a home in the town, and at first no name, or a child's name.
- **Learning the way:** the bow, hunting and tracking, horses, tree climbing (the
  climbing system), canoes, snowshoes, building a longhouse or a bark house. These are
  the lessons in the knowledge journal, taught by your new family's people. They
  replace the old hunter's role from earlier drafts.
- **Make a name.** Your adult name is earned: a great hunt, saving someone, a deed
  in the war. Your reputation as a member of the town starts here.
- Missions come from your family and the town: hunts, trading trips to the French
  posts, scouting, and later going to war with the town's men against the British, or
  refusing to go.
- You can try to escape back to the colonists at any point. It's a real choice, and
  the story goes on either way.

### Part 2: The Burning (1759–60)

- **The colonists strike the town.** The model is Rogers' Rangers' raid on the
  Abenaki town of Saint-Francis (H: 4 October 1759; verify), which was revenge for
  years of raids on New England. Played from inside the town at dawn. Your family is
  killed, scattered or saved, depending on what you do.
- The war ends with the French surrender (H: Montreal, 1760). Captives are "returned"
  under the peace, whether they want it or not (H, verify). Choose: go back, hide, or
  stay with the survivors.
- Either way you are now a person between two worlds. Colonists don't trust you, and
  your town may not either.

### Part 3: The Line and the Tax (1763–68)

- **Pontiac's War and the Proclamation line** (H: 1763). The Crown forbids settling
  west of the line, which angers the colonists. Some colonial vigilantes turn on
  peaceful Native towns (H: the Paxton Boys, December 1763; verify).
- **The British taxes.** The Stamp Act (H: 1765) and the troops who stay after the war.
  Frontier men black their faces and attack British pack trains and forts (H: the
  "Black Boys", Pennsylvania, 1765; verify). GTA-style crime missions: ambushes on
  pack trains, smuggling, running from soldiers, tavern politics.
- **The Ford** (below) is this part: back in the valley in 1765 with the garrison
  leaving and Albany men buying up the land. Elias Crane's hook becomes one contact's
  story instead of your own.
- **The boundary treaty at Fort Stanwix** (H: 1768) sells the land your town hunted on.
  Whose side you speak for there is the biggest roleplay choice in the story.

### Part 4: The Spark (1770–75)

- The colonies move toward revolt (H: the Boston "massacre" 1770, the Tea Party 1773,
  Lexington and Concord April 1775). In the valley it splits neighbours, families and
  the nations.
- The story ends in 1775 with your choice of side: the Patriots, the Crown, your
  nation, or none. The Revolution itself (the 1777 siege) is the next storyline.

### Why this works

- **Every system is used:** building and farming (the prologue), survival and lessons
  (Part 1), combat and stealth (Part 2), crime, reputation and business (Part 3),
  factions (Part 4).
- **Make a name** is literal: you go from nobody, to a nameless captive, to someone
  with an earned name and a reputation in two worlds.
- **Both sides do terrible things,** and the player sees both from the inside. That is
  the period's honest story and keeps it from being a simple good-guys tale.

### What the consultation rule means for this story

Parts 1 and 2 happen inside a Native town, so they're the heart of the story and
the part that most needs the nation's office. The framework, the lessons and the
missions can be built now with placeholder text, but the nation, its people, the
adoption, the town life and the raid can't ship until that office signs off. If one
nation's office says no, the story moves to another nation whose office says yes,
which is why the town's nation is not fixed yet. Abenaki (Saint-Francis/Odanak),
Kahnawake Mohawk and Seneca towns all took in adoptees in this period (H, verify).

## The Ford (1765–68): Part 3 of the main story

*New York, autumn 1765. The war is over, the garrison is leaving, and Albany money
wants the ford.*

**You** come back to the valley in 1765 after the war, known in two worlds and
trusted in neither. **Elias Crane** (invented), a settler who held a lease at the
ford, is found dead in the river and the lease has been sold twice; his family (or
whoever is left) is the contact who pulls you in. Missions 1 to 5 below were the
tutorial in v2; in the main story the Prologue is the tutorial, and these become the
first missions back in the valley.

**What you want** is up to you: the truth about Elias, the ford for yourself, money,
revenge, or a way to keep the land your town hunted on out of Albany's hands.

**The antagonist:** **Hollis and Company** (`npc.city.merchant`), an Albany merchant
house buying up every doubtful lease around the ford, plus its man on the spot,
**Silas Vane** (invented): smiling, careful, and backed by hired toughs.

### Contacts (each gives a mission chain)

| Contact | Id | Their missions |
|---|---|---|
| The old hunter | `npc.woods.old_hunter` | The tutorial chain: tracking, the hung cache, the first hunt; later a revenge hunt for the men who burned his hut |
| Sergeant Amos Tuttle | `npc.fort.sergeant` | Off-the-books jobs before the garrison leaves: recover deserters, "lose" army stores, then the march-out |
| The sutler | `npc.fort.sutler` | Smuggling rum and powder past the customs men; a strongbox heist that goes wrong |
| The trader | `npc.post.trader` | Bateau escorts up and down the river; a race to Schenectady before the ice |
| The farm family | `npc.valley.farm_family` | Protect the farm from Vane's men; find the brother who vanished in the 1757 raid (H: German Flatts burned in November 1757; verify) |
| Hugh Rankin | `npc.valley.surveyor` | A rival who can become an ally: steal his survey book, or save his life |
| Isaac Ackerly | `npc.valley.ferryman` | He saw the night Elias drowned; protect him, and he talks |
| Sarah Kerr | `npc.valley.tavern` | Card games, fights, rumours, and the Sons of Liberty's broadsides (the Stamp Act, 1765; H) |
| The quiet man | `npc.wanderer.shinobi` | A side chain of stealth missions; he gives the real iron ashiko ([[project_items-from-npcs-or-crafted]]) |

### The main chain (about 20 missions, in four parts)

**Part 1: Dead Man's Ford (winter 1765)**
1. *Off the Boat* (tutorial): the trader puts you ashore at dusk. Fire, shelter, and
   the top-left key hints ([[project_first-time-tutorial]]).
2. *Cold Tracks*: the old hunter teaches tracking. You follow a trail to where Elias
   was pulled from the river.
3. *Paper Against Paper*: the lieutenant reads your lease. Rankin's stakes are already
   in the lot. Pull them out, or don't.
4. *Range Money*: win powder from the soldiers in a shooting contest.
5. *The Hut in the Snow*: Vane's men burn the old hunter's hut. You get him out and
   chase them on horseback through the snow. This is the first shootout.

**Part 2: The Soldiers Go (spring–summer 1766)**
6. *Lost Stores*: help Tuttle sell off army stores before the march-out. This is
   theft, so the first hue and cry starts if anyone sees you.
7. *The Strongbox*: the sutler's heist. Vane's men hit it first.
8. *Bateau Run*: escort the trader's boats against river raiders. Gunfights from canoes.
9. *March Out*: the garrison leaves. Take the empty stockade, burn it, or leave it.
10. *Raise a Roof*: build your cabin before court day. The household and the leader
    planner come in here ([[project-leader-planner]]).

**Part 3: Hollis's Men (autumn 1766–1767)**
11. *The Survey Book*: steal Rankin's book from the tavern, or win it at cards.
12. *Ferryman*: Vane's men come for Ackerly at night. Defend the ferry.
13. *The Letter*: break into Hollis's warehouse in the town and find the letter that
    ties Vane to Elias's death.
14. *Turncoat*: Rankin chooses a side, depending on how you treated him.
15. *Fire at the Flatts*: Vane's men burn the farm family's barn. Ride to stop it.

**Part 4: The Line (autumn 1768)**
16. *Crowds on the Road*: the boundary treaty congress at Fort Stanwix (H: signed 5
    November 1768; verify) brings thousands past the ford. Feed and ferry them, and
    keep your property safe.
17. *The Magistrate*: bring your witnesses to court alive.
18. *Vane's Play*: Vane comes with papers and gunmen to take the landing.
19. *The Ford*: the final defence or the final chase, by river or on horseback.
20. *Epilogue*: who keeps the ford.

### Many ways through

The main chain is the spine, but every part can be reached from more than one
community, and who you've joined changes who asks you:

- **As a settler or the law's friend:** you prove Vane killed Elias and bring him to
  the magistrate.
- **As an outlaw:** you rob Hollis's warehouse, take the ford by force and run it as a
  smugglers' landing.
- **As a company man:** you work *for* Vane, and the farm family and the ferryman are
  the people in your way.
- **As a soldier:** you enlist with Tuttle and the story follows the garrison out.
- **As a member of a nation** (`[[consultation slot]]`): the land fight seen from the
  other side of the line.

### Endings

The endings follow your reputation and who is still alive, not a single choice:

- **Justice:** Vane hangs on your witnesses' word, and the ford is yours.
- **Revenge:** you kill Vane yourself. The ford is yours, and the law's reputation
  remembers.
- **Outlaw king:** the ford is a smugglers' landing and you run it.
- **Sold out:** you take Hollis's money and become a company man.
- **Gone:** you left the story with a nation, the army or the woods. The ford's fate
  happens without you, and you hear it as news.

After every ending the valley in 1768 stays open for free roam, side chains and the
household.

## Future storylines (one valley, many years)

The map is the same each time, changed for the year. These follow the real history of
the valley and its neighbours; each one needs its own research pass.

| Year | Storyline (working title) | The history (H, verify) | Native consultation |
|---|---|---|---|
| 1757 | **The Flatts Burn** | The French-led raid on German Flatts, November 1757 | Needed (the raiders included allied nations) |
| 1758 | **The Carry** | Building Fort Stanwix at the Oneida Carry | Needed (the Oneida) |
| 1759 | **Rangers** | Rogers' Rangers and the war in the north | Needed |
| 1765 | **The Ford** | The garrison leaves; the Stamp Act; land speculation | Slots only (storyline 1) |
| 1768 | (inside storyline 1) | The boundary line treaty at Fort Stanwix | Slots only |
| 1775 | **Liberty Pole** | The Revolution splits the valley: committees, Loyalists who flee, neighbour against neighbour | Partly |
| 1777 | **The Siege** | The siege of Fort Stanwix and the battle of Oriskany | Essential: the Oneida and the Mohawk fought on opposite sides |
| 1778–80 | **The Burning Valley** | Raids up and down the Mohawk valley | Essential |
| 1790s | **The Turnpike** | Settlers flood west; the canal is planned | Partly |

The 1757 and 1761 starts are already in the backlog as "post" milestones; this table
turns them into storylines.

## What to build, in order

**Built (2026-10-01):** the mission framework and the Prologue of Two Fires on the
valley map. `scripts/story/` (StoryDirector runs the missions, StoryObjectives checks
each step against the world, StoryHUD shows the cards, the mission and its key hints
top-left, the marker), `data/story/storylines/two_fires.json` and
`data/story/missions/two_fires.json` (Open Land, Clearing, A Roof of Brush, Fire, Meat
for Winter, A House and a Home, The Night of the Raid), the "story" save part, and the
New game screen's Story switch (on by default; off is free play in 1765). The stockade
stands in for the fort at German Flatts. The raid is heard (shots toward the Flatts) and
told in cards; a played raid needs human fighters, which the game doesn't have yet.
Test: `Godot --headless --fixed-fps 60 --path . -s tests/story/test_story.gd --
survival=on story=two_fires`.


1. **The mission framework:** `StoryDirector`, the storyline and mission data files,
   contact markers, the mission start/fail/pass flow, a mission HUD (objective text
   and a marker), retry from a checkpoint.
2. **Hue and cry:** the alert levels, pursuers, how to lose them.
3. **Reputation and joining:** communities, tags, witnesses, the join flow.
4. **Part 1 of The Ford** (missions 1–5). It is also the first-time tutorial.
5. **The rest of The Ford**, including the cutscene tools (camera takes like the
   trailer pipeline's, see [[trailer-pipeline]]) and the text dialogue boxes.
6. **Storyline 2.** Pick the one whose research and consultation are ready first.

## Decided (2026-10-01)

- The frontier is open: anyone can be attacked, and reputation is the consequence.
- You play your own character; the story is roleplay.
- The main story is Two Fires (above). One character lives all of it; every other
  storyline starts fresh with a new character.
- You can join communities, Native nations included (with the consultation rule).
- All dialogue is text, no voice acting: dialogue boxes in missions, short subtitle
  barks in the world, letters and broadsides as readable items.

## Open questions for the owner

- **The map.** The prologue fits the valley we have (German Flatts). The town in Parts
  1 and 2 and the 1765 pack-train country are elsewhere (to the north, or west in
  Pennsylvania and Ohio). Should the game get more maps, or should the story move
  those events into the valley as fiction?
