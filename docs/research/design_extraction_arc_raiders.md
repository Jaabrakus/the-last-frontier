<!-- research track design-arc, story-research workflow 2026-10-02 (web research by agents; verify H claims before in-game text) -->

# Report: Arc Raiders and extraction PvPvE as inspiration for Frontier

## Bottom line

1. **The frontier setting already suits extraction, so this track needs no new setting and no worktree.** In 1757–58 and again in 1778–80, people in the Mohawk Valley sheltered in a fort. They went out into a burned valley for food, livestock and goods, and ran back before raiders, wolves or winter caught them. That is the Arc Raiders loop.
2. **Build "The Burnt Flatts" first.** These are salvage raids in winter 1757–58 on the valley's burned 1757 layer, which the Prologue needs anyway. Fort Herkimer serves as the hub, like Arc Raiders' Speranza. Version 1 needs no human AI. The threats are wolves (they already hunt in packs and get bolder when hungry), cold, river ice, night and the other players.
3. **Second: "Hue and Cry" bounty contracts, set in The Ford's 1765 valley.** It borrows Hunt: Showdown's clue trail, capture and run out, plus Red Dead's rule that a target brought in alive pays more. It also builds the hue-and-cry system the single-player story needs.
4. **Third: "The Carry", an 8v8 convoy mode.** It meets the owner's 8v8 wish and is based on Bradstreet's 1756 bateau convoy and the Black Boys' 1765 pack-train raid. It needs the most new work.
5. **What plays the part of Arc Raiders' ARC machines:**
   - Version 1: wolves and winter, plus the mammoth the game already has as a boss beast, like Arc's Matriarch.
   - Version 2: French and Canadian raiding parties, deserters and bandits as human AI.
   - Optional magic: the Wild Hunt from the settlers' own Palatine German folklore, riding during the Twelve Nights. It reuses the horse and wolf AI.
6. **Hard lines:**
   - Native warriors are never faceless enemy AI.
   - No bounties on scalps or on people by type.
   - No wendigo or other Native sacred beings.
   - Every mode must work with the `[[consultation slot]]` empty.
7. **Two technical warnings:**
   - **Cheating:** each shooter's own machine decides its hits (`NetSession.forward_hit`, scripts/net/net_session.gd:476). That is fine among friends, but not for public PvP where you lose your gear. The Cycle: Frontier shut down partly over cheaters.
   - **Heat:** 16 players hosted on the Mac mini is heavy. Plan 8–12 players on a player's machine, and 16 only later on a separate headless server (phase P8 in docs/multiplayer_readiness.md).

Confidence marks: **high** means a fetched encyclopedia-grade page; **medium** means a guide, a single secondary source or a search summary; **low** means a claim by an interested party, or one I could not check.

---

## 1. What the genre teaches

### Arc Raiders (Embark Studios, 30 October 2025)

**Basic facts (high).** Source: https://en.wikipedia.org/wiki/Arc_Raiders
- Built in Unreal Engine 5. It was announced in 2021 as a co-op PvE game and became PvPvE in 2023.
- Raids last up to 30 minutes (40 on some maps). Squads are 1 to 3 players.
- When you die you lose your gear, except what is in a "safe pocket".
- You get out by elevators, metro stations, air shafts, or Raider Hatches that need a key.
- Between raids you are in Speranza: the workshop, selling, crafting, skills and trader quests.
- Metacritic 86 (PC), 85 (PS5), 88 (Xbox). It won Best Multiplayer Game at The Game Awards 2025 and Online Game of the Year at the D.I.C.E. Awards.
- Over 4 million copies sold by 11 November 2025, and 14 million by February 2026.

**Why they switched to PvPvE (high).** Embark says the early version "simply wasn't fun enough". The new direction is built on exploration and "uncertain alliances". https://arcraiders.com/news/evolution-of-arc-raiders-episode-2

**Lobbies (medium).**
- About 15–20 players, or 5–7 squads, per match; Embark has not confirmed this. https://www.dexerto.com/wikis/arc-raiders/lobby-size/
- Solo players are matched against solos. https://www.pockettactics.com/arc-raiders/interview-proximity-chat

**Getting out (medium).** https://allthings.how/arc-raiders-extraction-elevators-hatches-and-timers-explained/
- The elevator leaves 90 seconds after you call it, with a loud alarm that every player and machine nearby can hear.
- Each main exit closes on its own timer.
- Raider Hatches are silent, open all match long, and need a key.

**Free loadout (medium).** A random low-grade kit with no cooldown and no safe pocket, so a bad run never locks you out. https://www.shacknews.com/article/146615/how-to-use-free-loadouts-in-arc-raiders

**Scrappy (medium).** A pet rooster that gathers materials between raids, even if you die. The workshop's level is tied to his. https://allthings.how/arc-raiders-how-to-upgrade-scrappy-and-find-every-required-item/

**Map conditions on a fixed schedule (medium).**
- Each map rotates through Night Raid (more machines, better loot, and flashlights give you away), Electromagnetic Storm, Harvester, Matriarch, Hurricane, Locked Gate and Hidden Bunker. https://allthings.how/arc-raiders-map-conditions-schedule-and-rotation-times/
- The Cold Snap update (December 2025) added Snowfall: low visibility, frozen lakes and frostbite that drains health. https://www.techradar.com/gaming/arc-raiders-cold-snap-update-release-date

**Social moments.**
- There is proximity voice chat and a "Don't shoot" emote. The design director, Virgil Watkins, says they give players the tools and "we don't prescribe it" (high). https://www.pockettactics.com/arc-raiders/interview-proximity-chat
- GamesRadar+ called the game "a social experiment" (medium). https://opencritic.com/game/19023/-/reviews
- Many players believe matchmaking groups people by how aggressive they are. Embark has not confirmed this (low). https://www.gfinityesports.com/article/is-arc-raiders-pairing-players-by-aggression-fans-cant-tell

**How the story is told.**
- Through trader quests that slowly reveal what each trader wants (high). https://arcraiders.com/news/everything-you-need-to-know
- In February 2026 the CEO said "Speranza is heavily underutilized". Today it is a menu (high). https://gamingbolt.com/?p=636881

**What players disliked.**
- AI-generated NPC voice lines, criticised by Eurogamer (high; Wikipedia, above).
- Thin endgame and balance decisions that felt made on spreadsheets. After the Riven Tides update (May 2026) Steam reviews fell to Mixed, and concurrent players dropped from over 400K to under 100K (medium). https://www.kitguru.net/gaming/matthew-wilson/arc-raiders-hit-with-negative-reviews-following-latest-major-update/
- Expeditions are an optional progress reset that earns permanent bonuses (medium). https://www.pcgamesn.com/arc-raiders/wipe-reset-rewards
- A later change to a 5-day Expedition challenge drew a backlash (medium). https://frvr.com/blog/news/arc-raiders-expedition-change-community-backlash/

**What Frontier should take from it:**
- A free kit plus one protected item, so a loss never shuts you out.
- Two kinds of exit: loud ones on a timer, and quiet ones that need a key.
- A published schedule of map conditions.
- The household can be Scrappy.
- Give players tools for peace instead of rules.
- Let traders carry the story. Frontier can beat a menu here: real history gives the hub depth.

**What Frontier should avoid:** AI voices (Frontier's rule of all-text dialogue already avoids them), balance tuned on spreadsheets, and short time-limited challenges that pressure players.

### Hunt: Showdown 1896 (Crytek)

**How it works (high).** https://en.wikipedia.org/wiki/Hunt:_Showdown
- Up to 12 players. Clues narrow down where the boss's lair is.
- After the kill you must banish the boss. Picking up the bounty then shows your position to the other teams.
- Hunters die for good, but bloodline progress stays.
- Animals and objects give players away: "Flocks of crows, creaking boardwalks, and maimed horses wailing".
- Metacritic 81 on PC.

**The 1896 relaunch (high).** Bugs and a poor UI led to review bombing. https://www.pcgamesn.com/hunt-showdown/update-2-1
- The Bounty Clash mode (October 2024) is 12 players, one bounty token, 15 minutes. Concurrent players rose from about 16K to 26K.

**What Frontier should take:**
- The clue trail. Frontier already has snow prints in scripts/snow/snow_cover.gd and blood trails in scripts/player/player_blood_trail.gd.
- The moment when whoever carries the token is revealed to everyone.
- Animals as alarms. The game already has ravens, owls, bird flocks and horses.
- Slow-loading period guns, so every shot is a decision.
- A short 15-minute variant.

### Escape from Tarkov

**Quests (medium).** Traders send you to find items, kill, visit or mark places, survive, or get out from a given map. This teaches the maps, and reputation unlocks better trades. https://www.bamboogaming.net/tarkov/quests

**Scav karma (medium).** https://afkgaming.com/esports/guide/how-to-increase-scav-karma-and-fence-reputation-in-escape-from-tarkov
- Killing friendly AI characters while playing as one of them costs reputation.
- With bad karma, bosses hunt you.
- Extracting together with other players raises it.

**Story with endings (medium).** Version 1.0 (15 November 2025) added a story with four endings. https://insider-gaming.com/escape-from-tarkov-story-will-have-four-endings/ and https://www.analogstickgaming.com/news/2025/11/14/escape-from-tarkov-finally-hits-10-after-8-years-in-early-access

**What Frontier should take:** contracts that send you to the places the story uses, reputation as a memory of how you behaved, and proof that an extraction game can carry a story with endings.

### Sea of Thieves (Rare)

**Tall Tales (medium).** Replayable story chapters in the shared world, with checkpoints. https://seaofthieves.wiki.gg/wiki/Tall_Tales

**Safer Seas (high).** A private world with no PvP. Gold and reputation pay 30%, reputation is capped at level 40, and the top title (Pirate Legend) cannot be earned there. https://www.gamedeveloper.com/press-release/safer-seas-mode-brings-single-crew-servers-to-_sea-of-thieves_
- Added on 7 December 2023 (medium). https://seaofthieves.wiki.gg/wiki/Safer_Seas

**Emissary flags (medium).** A crew can fly a trading company's flag for bigger rewards. Ships flying the Reaper's Bones flag are shown on everyone's map and hunt other flag ships. https://seaofthieves.wiki.gg/wiki/Reaper%27s_Bones

**What Frontier should take:**
- Story chapters played in private co-op sessions.
- A PvE-only option that pays less.
- "Commissions": an opt-in flag that pays more and makes you a target.

### Red Dead Online bounties (medium)

Targets brought in alive pay more, and some can only be brought in alive. You deliver them to the sheriff. https://reddead.fandom.com/wiki/Bounty_Hunter_(Red_Dead_Online)

### Failures to learn from

- **The Cycle: Frontier** went offline on 27 September 2023. It was not financially viable, and cheaters had driven players away (medium). https://insider-gaming.com/the-cycle-frontier-closing-down/
- **Common causes of failure** (low; an opinion piece): no purpose beyond loot, and losses that cost too little, as in Call of Duty's DMZ. https://games.gg/ur/news/why-most-studios-struggle-to-make-a-successful-extraction-shooter/

---

## 2. History that supports extraction in Frontier

**German Flatts raid, 12 November 1757 (high).** https://en.wikipedia.org/wiki/Attack_on_German_Flatts_(1757)
- The French commander was Belestre, with about 300 regulars, militia and allied warriors.
- About 60 homes were burned, 40–50 people killed and about 150 captured.
- Some settlers fled across the river to Fort Herkimer.
- Most prisoners were later exchanged, and the settlers came back and rebuilt.

**The French report's plunder list (low: a victor's report, probably inflated).** It claims 3,000 cattle, 3,000 sheep, 1,500 horses and goods worth 1.5 million livres. Even inflated, it shows what the valley held. https://www.herkimer.nygenweb.net/gerflats/gerflatsattacks.html

**Oneida warnings (medium).** Oneida sachems warned the settlers 15 days and 6 days ahead, and the warnings were dismissed. The same page cites the Documentary History of New York. This is `[[consultation slot]]` material.

**Second attack, 30 April 1758 (medium).** About 80 warriors and 4 Frenchmen attacked and 33 inhabitants were killed. Captain Herkimer held the fort and rangers came to relieve it. Source: the New York Mercury of 22 May 1758, quoted on the same page.

**Fort Herkimer (high).**
- It was first built in 1740 around the Herkimer family's homestead and was also called Fort Kouari. The church still stands. https://en.wikipedia.org/wiki/Fort_Herkimer
- The settlers were Palatine Germans under the Burnetsfield Patent of 1722–23. https://en.wikipedia.org/wiki/German_Flatts,_New_York

**The 1778 raid (high).** Adam Helmer ran 26 miles to give the warning, and settlers got into Forts Dayton and Herkimer. The raiders burned 63 houses, 57 barns, three gristmills and a sawmill and drove off the livestock. Only three settlers were killed. https://en.wikipedia.org/wiki/Attack_on_German_Flatts_(1778)

**1780 (medium; search summary).** Crops were destroyed before the harvest, and stone houses served as forts. People ran to the nearest fort when word of raiders came. Over 330 people were killed or taken that year. https://home.nps.gov/fost/blogs/a-forgotten-civil-war-the-revolution-begins-in-the-mohawk-valley-conclusion.htm

**Fort Bull at the Oneida Carry, 27 March 1756 (high).** https://en.wikipedia.org/wiki/Battle_of_Fort_Bull
- The French officer de Léry led 84 regulars of the troupes de la marine, 166 Canadian militia and 110 allied warriors.
- The fort held 45,000 pounds of gunpowder. The attackers blew it up, and 5 of the 62 people inside survived.

**Bradstreet's convoy, 3 July 1756 (medium; search summary).** About 350 bateaux and roughly 1,000 boatmen were ambushed about 8 miles from Oswego, with 60–70 casualties. https://en.wikipedia.org/wiki/Battle_of_Fort_Oswego and https://www.biographi.ca/en/bio/bradstreet_john_4E.html

**The Oneida Carry (medium-high).** The portage was 1 to 6 miles long depending on the season, and local people ran wheeled hauling across it. https://en.wikipedia.org/wiki/Oneida_Carry

**French raiding style, "la petite guerre" (high).** Small groups of regulars and militia raided with their Native allies, travelling by canoe and on snowshoes. https://thecanadianencyclopedia.ca/en/article/troupes-de-la-marine and https://warmuseum.ca/cwm/exhibitions/chrono/1000militarized_society_e.html

**Rogers' Rangers (high).** https://en.wikipedia.org/wiki/Rogers%27_Rangers
- In the first Battle on Snowshoes (21 January 1757), the French had no snowshoes and were "floundering in snow".
- The rangers starved on the retreat from Saint-Francis.
- Date discrepancy: this page gives 3 October 1759 for the Saint-Francis raid, while main_story.md says 4 October. Check it.

**The Black Boys (high).** https://en.wikipedia.org/wiki/Black_Boys
- On 6 March 1765 at Sideling Hill, about 35 men stopped an 81-horse pack train. It carried goods for Croghan and the Philadelphia firm Baynton, Wharton and Morgan: rum, gunpowder and "warlike goods".
- They burned most of it. Fort Loudoun was besieged in November 1765, and almost no one died.

**Owen Sullivan the counterfeiter (medium).** He was hanged in New York City on 10 May 1756 and had 29 confederates. Because he would not say where his printing plates were, New York made hiding them a felony on 9 July 1756. https://www.executedtoday.com/2016/05/10/ and https://www.nybooks.com/articles/2011/11/10/american-dream-money/

**New York wolf bounty (medium-high).** From 1715 you carried the wolf's head to a Justice of the Peace. The bounty for an adult was 30 shillings in 1762 and £3 in 1768. https://www.legalgenealogist.com/?p=11857

**Deserter rewards (medium).** In 1769 a newspaper offered five guineas for a deserter from the 64th Regiment, and such notices ran many times. https://adverts250project.org/tag/desertion/ and https://www.cdss.org/elibrary/PacanNew/CITATION/C0003/C0003535.htm

**Scalp bounties: the reason for a hard line.**
- On 14 April 1756 Pennsylvania offered 130 Spanish dollars for the scalp of a male "Indian Enemy" over 12 (high). https://bountyfilm.org/lesson-four/bounties-in-pennsylvania
- Massachusetts offered similar bounties in 1755 (medium). https://ictnews.org/archive/native-history-greed-deception-and-exile-result-in-1756-scalp-act/

**The Wild Hunt.**
- In German it is the Wilde Jagd or Wütendes Heer ("raging host"). Seeing it foretold war, plague or death, and it rode with ghostly dogs and horses (high). https://en.wikipedia.org/wiki/Wild_Hunt
- It rides in the Rauhnächte, 25 December to 6 January (medium; popular sources). https://germangirlinamerica.com/what-is-rauhnacht/
- I did not confirm that the Mohawk Valley Palatines told this tale (low).

**The Himmelsbrief (medium).** Pennsylvania German protective "letters from heaven", carried folded in uniforms in wartime. https://en.wikipedia.org/wiki/Himmelsbrief

**The chasse-galerie (medium).** A French-Canadian tale of a flying canoe and a pact with the devil. It blends a French Wild Hunt story with First Nations flying-canoe stories, and its best-known text dates from 1892. Because it is partly Native in origin, don't use it without consultation. https://en.wikipedia.org/wiki/Chasse-galerie

**The wendigo (medium).** Critics show how horror media strip the wendigo of its Native meaning to make an easy villain. https://reinventionjournal.org/article/view/906

---

## 3. What plays the part of the ARC

| Candidate | Grounding | Cost now | Consultation | Verdict |
|---|---|---|---|---|
| **Wolves and winter** | NY wolf bounties; the 1757 winter; the 1757 Battle on Snowshoes | Already built: pack tactics, blood scent and hunger in scripts/wildlife/wild_animal.gd; the ecology in wildlife_ecology.gd; river ice in scripts/snow/river_ice.gd; snow cover | None | **Version 1.** Readable (howls), drawn to carcasses and blood, and harder when deer are scarce, so the ecology sets the difficulty |
| **The mammoth (boss beast)** | None; the game already includes it | Already built (wildlife_ecology.gd) | None | Frontier's Matriarch: a team-sized kill whose shots draw everyone |
| **French and Canadian partisans, deserters, bandits** | Fort Bull, Bradstreet, la petite guerre | Needs human AI fighters with guns (none yet; main_story.md says the Prologue raid needs them too) | Only if allied nations appear, and then only as consulted characters | **Version 2.** Build once and share with the Prologue |
| **The Wild Hunt (magic)** | The settlers' own European folklore | Horse and wolf AI reskinned as ghosts, riding fixed routes like Arc's patrols | None | **The seasonal magic layer** |
| **Native war parties as AI** | Historically present | — | Essential | **Never as faceless enemies.** Show them only as consulted characters |

---

## 4. Three mode designs

### Mode A: The Burnt Flatts (salvage raids)

**When and where.** Winter 1757–58, between the burning of 12 November and the attack of 30 April. It is played on the valley map's 1757 burned layer, which is item 1 in docs/maps.md's build order.

**Session.** Up to 4 squads of up to 4 players (16 at most; plan 8–12 on the Mac mini). A raid lasts about 25 minutes, and dusk is the deadline.

**Hub: Fort Herkimer.** Start it as a menu, as Arc does, and make it walkable later. The captain and the traders are invented people, with the real Herkimer in the background:
- **The sutler:** buys salvage and sells powder. His quest line reveals he is buying burned-out lots cheap for an Albany house. That plants Hollis and Company eight years before The Ford.
- **The dominie (the Reformed minister):** wants the church register and family Bibles back. They list the captives, so your own Two Fires character can appear as "taken".
- **The militia captain:** scouting jobs and a dead courier's dispatch. The 1758 attack is the season finale.
- **The widow at the mill:** livestock and grain. Her quest line rebuilds the mill in the hub, so players see the community recover.
- **The armorer:** crafting.
- **`[[consultation slot]]`:** the Oneida messenger. With the slot empty, warnings reach players through the captain.

**What you salvage:**
- Iron from burned houses: nails, hinges, kettles, axe heads.
- Root-cellar stores and seed grain.
- Stray cattle, sheep and horses. They are slow to bring home: you drive them or haul with the horse tools that exist.
- Hidden powder caches.
- Papers that feed the story.

**Threats:** hungry wolves gathering at livestock carcasses, frostbite, thin river ice, night, other squads, and the mammoth condition.

**Getting out:**
- **The fort gate (loud):** hail the sentry. The gate opens after about 60–90 seconds, and a drum or bell is heard across the valley. It shuts at dusk.
- **The ferry (loud):** blow a horn for the ferryman. When the river freezes there is no ferry, only the ice.
- **Quiet:**
  - **The countersign**, a one-use password bought from the sergeant or found on a courier. It opens the side gate silently at any time. Sentries challenging with a password is plausible army practice, but I have not checked it for the 1750s (low).
  - **Your own canoe**, hidden on the bank. It stays in the world between raids, so others can steal it.

**Risk rules:**
- When you die, your pack drops where you fall (scripts/save/death_rule.gd).
- One small item sewn into the coat lining survives, like Arc's safe pocket.
- A free "parish kit": a fowling piece with three charges, a hatchet, a blanket and bread. It has no protected item.

**The almanac (the conditions schedule), shown as a printed almanac page in the hub:**
- Hard Frost: frostbite, and the river freezes.
- Fresh Snow: every player's tracks can be followed.
- Thaw and Flood: the fords close.
- Fog.
- Night: torches give you away.
- Hungry Wolves: driven by the real deer count.
- The Old Cow: a mammoth matriarch on the open land.
- Courier Down: a race for a dead courier's satchel.
- Later, once human AI exists: Raiders in the Valley.

**Story ties:**
- A recovered first-sale deed for Elias Crane's lot explains The Ford's twice-sold lease.
- Signs of the farm family's brother who vanished in 1757 unlock a side mission in The Ford.
- The dominie's register ties the mode to your Two Fires character.
- The sutler's ledger introduces Hollis and Company.
- Later, the April 1758 attack becomes a 16-player PvE defence event.

**What exists and what is new.**
- Exists: NetSession phases P1–P6, wolves, weather, ice, DeathRule.
- New:
  - The raid flow: spawn, timer, exit zones.
  - A stash kept between raids.
  - Loot containers in the ruins.
  - Contracts written as StoryDirector data.
  - The almanac rotation.
  - The sync gaps that docs/multiplayer_readiness.md lists as "Not yet": dropped items, chests, fires, doors, carcasses dressed by a joiner, and wild horses for joiners. Dropped items and chests matter most for extraction.

### Mode B: Hue and Cry (bounty contracts)

**When and where.** 1765–68, on the valley's 1765 layer. It can move to the Mountain Road later.

**Session.** 3–4 squads, about 30 minutes. Notices are posted at the tavern and at the magistrate's. The notices are readable broadsides, as in the period's newspaper adverts.

**Targets:**
- **The coiner**, modelled on Owen Sullivan. His printing plates are the bounty token. He pays more if taken alive, but the plates alone also pay.
- **A deserter.** The army wants him alive only. This is Sergeant Tuttle's contract.
- **The stock-killing wolf.** Bring its head to the Justice of the Peace, as the 1715 law required. It needs no new AI.
- **A horse thief.**
- **Players.** Only players who joined the outlaws, or who earned the "killer" tag in front of witnesses, can be posted. They can clear it by paying a fine. This works like Sea of Thieves' Reaper's mark, but it is made from reputation, not from sorting lobbies.

**Loop:**
1. Buy the warrant. The fee is your stake.
2. Find three clues: tracks or other sign, a witness (text dialogue), and an object. Each clue shrinks the search ring.
3. Find the target and bind him, which takes a few seconds.
4. He walks tethered to you or rides your horse.
5. The hue and cry starts. About every 60 seconds a farm bell or an alarm shot reveals the carrier's area to every squad, as Hunt reveals its bounty carrier.
6. Reach the Justice, who takes about 60 seconds to write the certificate while you hold the yard. This is the equivalent of Hunt's banishing.

**Pay:** alive is full, dead is half, and a wolf's head is full.

**Threats:** the other squads, wolves and weather. Ravens and crows give movement away. The target's gang becomes armed human AI later.

**Story ties:**
- It builds the hue and cry and the capture objective, items 2 and 3 in main_story.md's "What to build", for single player as well.
- It feeds Tuttle's deserter missions and Sarah Kerr's quest line.
- The coiner's paper trail can be extra, fictional evidence for mission 13, "The Letter".

### Mode C: The Carry (8v8 convoy)

**Variants:**
- 1756: the river corridor to the Carry, with the Fort Bull depot as a map event.
- 1765: the Mountain Road pack train (docs/maps.md, map 3).

**Teams.** The convoy side (8 players) moves 6–10 loads at a set pace: bateaux on the river, then carts over the Carry, which is the weak point. The raiders (8 players) choose where to ambush.

**How to win:**
- Raiders win by burning loads, which is quick but pays nothing, or by carrying loads off to their hideout, which pays.
- In 1765, killing drivers gives the "killer" tag, because the Black Boys killed almost no one. That makes the PvP less murderous and true to the history.
- The text should show both sides: the goods were for Native trade after Pontiac's War. Any Native recipients go in a consultation slot.

**Story ties.** It shares convoy code with The Ford's mission 8, "Bateau Run", with the trader's race to Schenectady before the ice, and with Part 3's pack-train ambushes. Which side you play builds that community's reputation.

**What is new:**
- Pack horses that follow a path.
- A bateau (the game has only bark canoes now).
- Loads you can carry and burn.
- Team rules.
- A corridor map.

This mode costs the most.

### Magic overlay: The Twelve Nights (for Modes A and B, seasonal and opt-in)

From 25 December to 6 January in the game calendar, the Wild Hunt rides through the valley.
- **The riders** are horse AI. **The hounds** are wolf AI with ghost shaders. They sweep fixed lanes with a snowstorm, like Arc's patrols.
- **Seeing the Huntsman marks you:** you get cold faster. A Himmelsbrief or reaching the church lifts it.
- **The host is the war's dead.** One rider is a man killed in November, which gives the dominie's quest line a hook.

**Magic items:**
- A Himmelsbrief: keeps one item when you die, then burns up.
- The Huntsman's horn: calls the Hunt down on another squad. It is very loud.

**Why it fits:** it is the settlers' own folklore, it keeps Native sacred material out, it reuses existing AI, and the game already includes a mammoth.

---

## 5. Pieces all the modes share

- **Contracts are mission data.** They reuse StoryDirector's objective kinds: `go_to`, `deliver`, `hunt`, `capture`, `escort`, `steal`, `defend`, `survive_until`, `stay_unseen`.
- **Tools for peace:**
  - Grounding your musket (scripts/weapons/musket_butt_ground.gd exists) means "don't shoot".
  - A "Friend!" text bark shows to players nearby.
  - Voice chat can come later through GodotSteam's voice functions. https://godotsteam.com/tutorials/voice/
- **A "Quiet Valley" with no PvP**, paying about 30%, as Sea of Thieves does.
- **Your homestead is the workshop**, and the household gathers between raids like Scrappy (scripts/companion/household.gd).
- **A season is a year.** The calendar moves forward instead of a wipe. An optional, slow "Go West" reset can come later, with no 5-day timers.

## 6. Lines not to cross

- Native characters only through `[[consultation slot]]`, and every mode works with the slot empty.
- Never a bounty by race or for scalps.
- No wendigo, and no chasse-galerie without consultation.
- Contacts are invented people; real people stay in the background.
- The 1778–80 "Burning Valley" season is the period most like extraction, but it needs consultation (Brant's raids). Only after that can it be Season 3.

## 7. Build order and heat

1. **Mode A:** menu hub, wolves and weather only, friends' lobbies, 8–12 players.
2. **Mode B:** the wolf bounty first.
3. **Human AI fighters,** shared with the Prologue's raid.
4. **The Twelve Nights** event.
5. **Mode C.**

**Heat.** docs/multiplayer_readiness.md measures one player's animation tree at about 2 ms per frame (headless). So 15 remote players near you would cost about 30 ms per frame if all are fully animated.
- Add animation level-of-detail (P8) before going to 16 players.
- Keep raid maps at the valley's 3×3 size or smaller, and cap wolves at about two packs.
- 16 players needs a separate headless server, not the Mac mini.

**Security.** Move hit decisions from the shooter's machine to the host before any public matchmaking.

## 8. Questions for the owner

1. Is the multiplayer character the Two Fires character, or a separate survivor for each season? I suggest separate, with links through reputation and cosmetics.
2. Friends-only sessions first? I recommend yes.
3. Magic as a seasonal opt-in, or as its own "Old World" ruleset?
4. A menu hub first, or a walkable fort from day one?
5. For Mode C: the Mountain Road map, or a river corridor in the valley?

**Files read:**
- /Users/kiwimango/Downloads/Frontier/docs/main_story.md
- /Users/kiwimango/Downloads/Frontier/docs/maps.md
- /Users/kiwimango/Downloads/Frontier/docs/multiplayer_readiness.md
- /Users/kiwimango/Downloads/Frontier/scripts/wildlife/wildlife_ecology.gd
- /Users/kiwimango/Downloads/Frontier/scripts/wildlife/wild_animal.gd
- /Users/kiwimango/Downloads/Frontier/scripts/net/net_session.gd