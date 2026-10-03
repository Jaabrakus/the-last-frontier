<!-- research track design-story, story-research workflow 2026-10-02 (web research by agents; verify H claims before in-game text) -->

# Track report: what makes open-world story missions engaging (for Frontier and Two Fires)

**Method.** I did web research and read four project files: `/Users/kiwimango/Downloads/Frontier/docs/main_story.md`, `/Users/kiwimango/Downloads/Frontier/docs/maps.md`, `/Users/kiwimango/Downloads/Frontier/data/story/missions/two_fires.json` and `/Users/kiwimango/Downloads/Frontier/scripts/story/story_hud.gd`. I edited nothing and ran nothing heavy. The session's web-search budget (200 searches) ran out near the end, so a few points rest on a single source. Each one is marked.

**How sure I am:**
- **H**: a developer statement, a well-cited encyclopedia entry, or several reliable outlets agree.
- **M**: one review or secondary article, or a guide for a plain game fact.
- **L**: a forum or player opinion, or my own recall that I did not re-check.

Numbers in [brackets] point to the source list at the end.

---

## 1. Game by game

### Red Dead Redemption 2

**What works**
- **Chapters set the pacing.** They let Rockstar move the player around the map and control the tempo without closing the open world. Their narrative lead writes an outline of about a page and a half, and the team builds the missions back from it [3] (M).
- **The camp is a living home.** It has needs (food, ammunition, medicine) and a mood that changes conversations. A chat in camp can start a mission [3][5] (M).
- **The camp shows the story's decline.** It starts as the hopeful camp of Chapter 2 and ends as the broken remnant at Beaver Hollow [6] (H; this is the well-known plot).
- **Honor reaches into the story.** It changes how people treat you. It swaps single lines inside cutscenes, changes Arthur's reaction to his diagnosis, and changes his death scene [4] (M).
- **The epilogue is quiet.** Years later, a new lead tears down a shack and builds a ranch house with old companions, then plays the final revenge mission [7] (M). Some critics found it too long or anticlimactic [8] (L–M).

**What fails**
- **The missions are rigid.** PC Gamer said they felt like "following stage directions rather than roleplaying." Stepping off the intended path fails the mission [1] (H). Players describe one repeated template: ride, cutscene, follow, something goes wrong, shoot, ride [2] (L).
- **The start is slow.** This is a widely made complaint [8] (L–M).
- **The scale cannot be copied.** The main script ran about 2,000 pages, with 1,200 actors and 2,200 days of motion capture [9] (M). Copy the structures, not the size.

**For Frontier**
- The household or settlement is Frontier's camp. Let it show the state of the story: the Prologue homestead grows and then stands empty, the Part 1 town is a consultation slot, and the ford settlement grows in Part 3.
- Let reputation tags swap single lines inside story cards. It is cheap and makes the tags feel present.
- Put a short, optional epilogue at the 1757 homestead site, using the building system.
- `StoryObjectives` already checks results in the world ("fell 3 trees anywhere", "build within r m"). Keep it that way. Fail a mission only when a real goal is lost (the witness dies, the boats sink), never because the player left a path.

### GTA V

- **Three leads.** Dan Houser described them as nuanced characters rather than archetypes, each good and bad at different things [11] (M). They unlock one at a time so the player learns each first [12] (M). Players can switch between them freely outside missions, and inside some missions each one takes a role (pilot, gunner, sniper) [10][69] (M).
- **Heists.** Setup missions gather gear and vehicles. Some heists let you choose stealth or a loud approach. You hire crew whose skill trades against their cut, and crew who survive get better and can be hired again [10] (M–H).
- **Variety.** Rockstar said it wanted fewer "drive from A to B and kill something" missions [69] (M).
- **"By the Book".** This mission makes the player take part in torture and cannot be skipped. IGN, Polygon, Eurogamer and human-rights groups criticised it [10][13] (H).

**For Frontier**
- Two Fires has one lead across 18 years. The several-leads idea fits better in two places: the future storylines (a new character each time, same valley), and co-op roles inside missions. Give missions 2 or 3 role slots (the bateau's steersman, the rifle on the bank, the one inside). AI crew or household workers fill them in solo play; friends fill them in co-op.
- Use the heist shape for The Strongbox (mission 7), The Letter (13), Lost Stores (6) and the pack-train ambushes. Scout, then prep (blacked faces, a bribed packer, horses), then choose an approach, then hire crew with skills, a cut and loyalty. Crew who die stay dead.
- Never force an atrocity. In Part 2 and in any raid, the player must be able to refuse, and the world must remember the refusal.

### Assassin's Creed III (same period and region, a Kanien'kehá:ka lead)

**Praised**
- A Kanien'kehá:ka protagonist speaking Kanien'kéha. The language was taught by Akwiratékha Martin, and the cultural liaison was Teiowí:sonte Thomas Deer of the Kanien'kehá:ka Onkwawén:na Raotitióhkwa Language and Cultural Center in Kahnawà:ke [14] (H).
- Deer told the team not to depict sacred masks, and advised on clothing and on which spiritual music was off-limits [14] (H). The team also switched to longhouses after realising tipis were wrong [16] (M).
- Deer said a Kanien'kehá:ka lead in a popular series shows the nation as living today, not only as history [14] (M, paraphrased).
- The story makes players face the fact that the Revolution did not end well for Native nations [16] (M).

**Criticised**
- It tells the Euro-American Revolution story from a Native point of view, instead of centring Kanien'kehá:ka history [16] (M).
- Anton Treuer, an Ojibwe scholar, said it shows mainly one side of Native history: dealing with violence [19] (M).
- The Clan Mother comes close to the "mystic Native" stereotype [17] (M).
- The prologue as Connor's British father, Haytham, runs about five hours. It was criticised for pacing and for suggesting Connor's legitimacy comes through his white father [18] (M), and called a bait-and-switch [21] (M).
- A reviewer compared Connor's presence at every famous event to Forrest Gump [20] (M). The time jumps hurt clarity [21] (M). Critics were split on Connor himself: dull to some, strong to others [14 (Wikipedia)] (M).
- **The Homestead.** You recruit settlers through small missions, and their lives move on: the Norris and Myriam wedding, Achilles' funeral [22] (M). But the economy layer was obtuse [21] (M), and the best side content was tucked away where most players miss it [20] (M).

**Gap.** In this pass I found no published Kanien'kehá:ka criticism. The critics I found are not Mohawk. For Frontier, the nation's office's own view is the one that counts.

**For Frontier**
- AC3 shows the consultation rule working, because the list of what not to show came early. Ask the office for its list of what is off-limits before anyone writes anything.
- Show daily life, not only war (Treuer's point). Part 1's lessons system is a good place for this.
- Never treat the player's colonial origin as the "real" self. Adoption in Part 1 must not read as a stop on the way back.
- Keep the player at the edge of history. For example, see the 1768 Fort Stanwix congress from the crowd and the ferry, not from inside every famous room.
- Players remember the Homestead's people, not its economy. Make the household's people part of the story, and make the money side easy to read.

### Ghost of Tsushima

- **No waypoints.** The Guiding Wind and a minimal HUD replace them, so the player stays in the world [23][24] (M–H).
- **Standoffs** are duels the player starts, taken from the film *Sanjuro* [25] (M).
- **Tales of Tsushima** are side quests built as character arcs. Lady Masako's revenge tale, about nine missions long, is praised as being as good as the main story [27] (L–M).
- **Mythic Tales** are legends the islanders believe, and each rewards a unique item. The director said the game is not meant to be supernatural; it stays grounded [24] (M).
- **Real people.** The team avoided real historical figures after being advised it would be insensitive [23] (M).
- **Criticised:** repetitive side content, copy-pasted camps and villages, fox shrines repeated 16 times, and nature guides that end up as quest markers in disguise [23][26] (M).

**For Frontier**
- Guide the player through the world itself: chimney smoke, a blaze cut on a tree, the river, birds. Make the gold diamond marker optional.
- Add a standoff before fights with Vane's men. Camera and silence do the work, so no voice is needed.
- **If the story goes magical, use the Mythic Tales model.** These are the settlers' own legends, left ambiguous, each rewarding a unique item. One documented settler source is Braucherei, the folk-healing practice of the Pennsylvania Germans from the 1700s [66] (M). Whether the Mohawk Valley Palatines practised the same is unverified (L).
- **Never make Native ceremony into a game power.** The Clan Mother criticism and the mask warning both point the same way.
- The quiet man's ashiko chain fits as a tavern legend that Sarah Kerr tells. Telling it as a tale makes the odd thread feel deliberate.
- For real figures, follow Ghost of Tsushima's caution. Native leaders appear only through the office.

### The Witcher 3

- **No fetch quests.** That was the studio rule, and every quest is meant to be a story with a twist. They admit a few padded quests slipped through [32] (M).
- **The Bloody Baron.** The designer, Paweł Sasko, showed the Baron helping Geralt find Ciri before revealing his alcoholism and abuse. No good ending is guaranteed. Results depend on choices made hours earlier, and in some runs the Baron kills himself [28][29] (H).
- **Pacing graph.** Sasko plots tension over time, colour-coded by type of gameplay, and puts the most important moments at the highest and lowest points [30] (M).
- **Ciri's ending** comes from a hidden tally of five small moments across three quests, such as whether you have a snowball fight with her. Three of five gives the good ending, and no meter is ever shown [33] (M).
- **Battle of Kaer Morhen.** Allies you recruited earlier turn up: 9 to 16 of them in any combination, and every combination had to be tested [31] (H).

**For Frontier**
- Make "The Ford" (mission 19) or "Ferryman" (12) a Kaer Morhen moment: whoever you helped comes to fight, such as the farm family, Rankin, Ackerly or Tuttle's deserters. Keep the pool small so testing stays bounded.
- Decide endings with 4 to 6 small hidden moments with key people, plus who is still alive.
- Reveal Vane the way Sasko revealed the Baron: help first, sins later.

### Kingdom Come: Deliverance

- **Henry is a nobody.** He is a blacksmith's son who loses his first fist-fight and cannot read until a scribe teaches him. His skills grow by use [36] (M).
- **The tutorial has a gentle clock.** Before his village is destroyed, he runs errands in it. If he dawdles with the beer his father sent him for, it gets warm and his father notices [34] (M).
- **Flexible quests.** The main quest is modular. Side quests can end without you, and failing one way opens other options, sometimes in other quests [34] (M). Players complained when timed quests were not clearly marked [35] (L).
- **Historical grounding.** The team worked with historians and photographed real places [37] (M). But its loud claim of "accuracy" set off a long debate about who the game left out [37] (M).

**For Frontier**
- This is the closest match to the Two Fires Prologue: a nobody, a home, a raid. Copy its shape. Add 2 or 3 errands at German Flatts that introduce named neighbours before 12 November 1757. One of them should be the farm family's brother who goes missing in the raid in the 1765 chain.
- Have people teach skills. Reading a lease could be one of the lessons.
- Make time limits clear in the text ("before the ice", "by court day").
- Publish the project's S/H/D basis keys rather than claiming "accuracy".

### Mount & Blade

- The sandbox (renown, lords, factions, your own kingdom) produces stories without being told to [38] (L–M).
- Players felt Bannerlord's authored main quest belonged to a different game, and many skip it [38] (L).

**For Frontier:** build the authored chain from the sandbox's own verbs. The sandbox must still work if a player ignores the chain, as the doc's rule 1 already says.

### This War of Mine and Frostpunk

- **This War of Mine** puts you in charge of civilians in a city under siege, modelled on Sarajevo. Its research included survivors and a consultant who lived through the siege [39] (M). The moral weight comes from scarcity, not from lecturing.
- **Frostpunk's** Book of Laws makes some choices permanent, such as child labour versus a children's shelter, and tracks hope and discontent. If you crossed lines, the ending asks whether survival was worth it [41] (M).
- A Frostpunk designer, Przemysław Solski, said main plots were cut to one or two sentences so the text would not compete with running the city. Scarcity is what makes the numbers personal [40] (M–H).

**For Frontier**
- On the captive march and through Part 1's first winter, scarcity is the drama. Whether you share rations, with the family watching, is a question for the office.
- Put moral choices into the systems: sell the seed corn, or take Vane's money.
- End each Part with a reckoning that shows what happened and does not tell the player what to feel.

### 80 Days

- More than 650,000 words and 170+ cities, written in inkle's ink language. It mixes story choices with route and money planning, and it tracks traits [42] (H).
- **Postmortem lessons** [43] (H):
  - Making exploration optional turned chores into rewards.
  - Scope grew from a planned 20–30 cities to over 100, and the connections between cities grew even faster.
  - The conversation system came out obtuse.
  - Seven or eight playtesters missed serious bugs.
  - An in-game feedback button that attached the save file proved invaluable.
- **Meg Jayanth's GDC talk:** give NPCs their own goals even when that limits the hero, and let the protagonist be vulnerable and fail [44] (H).

**For Frontier:** in Part 1, the family and town should have their own agendas (with the office). Make content an optional reward. Cap content counts early. Add a "report a problem" button that attaches the save.

### Pentiment (the closest model for text-only dialogue)

- **Typographic voice.** There is no voice acting. Text is written in six fonts that match education and class: a peasant hand, a scribe's hand, a humanist hand, a monastery Gothic, and printer's type [46][47] (M–H).
- **Text is written live.** Letters appear as if written, with ink dips. Anger splatters ink, shouts shake, whispers shrink. When Andreas learns more about someone, their lettering is corrected on screen [46][47] (H).
- **Accessibility.** There is an easy-reading mode, an OpenDyslexic font, and a harder mode with the long s [48] (M).
- **The clock.** Each day is split into parts. Most actions are free, but some investigation steps cost hours, so you cannot follow every lead and are never sure you accused the right person [49] (M).
- **Time span.** Three acts over 25 years (1518, 1525, 1543), chosen to show how the player's choices change a community [45][46] (H).
- **Meals are conversation scenes.** Who you eat with changes how the town sees you and what you learn [50] (M). The background you choose in early dialogue opens options later [50] (M).
- **Small team.** About 13 people, with history consultants Christopher de Hamel and Edmund Kern [45] (H). Its minigames serve the story, not challenge [46] (H).

**For Frontier**
- **Give each community its own lettering.**
  - Palatine Germans in Fraktur. Christoph Sauer brought Fraktur type to Pennsylvania in 1738 for German readers [63] (H); search summaries add that Franklin's press used only roman type (M).
  - Printed broadsides in Caslon, the type colonial printers commonly used; Dunlap's 1776 Declaration broadside was set in it [64] (H).
  - Officers and lawyers in a round hand.
  - Free OFL fonts exist: UnifrakturMaguntia, Libre Caslon, IM Fell [65] (M–H). Add a plain-font toggle.
- Write text in live with a quill sound and a skip key. Correct someone's lettering when the player learns who they really are.
- Run The Letter (13) and The Magistrate (17) on a clock: some acts cost hours, court day is fixed, and you cannot follow every lead.
- Use the household's table and the tavern as conversation scenes.
- Let the customizer's background open dialogue options.

---

## 2. Cross-cutting answers

### Pacing curves
- Jesse Schell's "interest curve" says: an early hook, then rising peaks with valleys between them, then a climax [54] (M). Add Sasko's colour-coded tension graph [30] and RDR2's chapters [3].
- **The problem in Two Fires:** the Prologue has six building missions with no people in them before the raid ([two_fires.json](/Users/kiwimango/Downloads/Frontier/data/story/missions/two_fires.json)).
- **Proposed fix:**
  - Open with a 60-second flash-forward to the raid night (a card, distant shots, an orange sky), then "Autumn 1757, six weeks earlier."
  - Interleave the building missions with errands for the neighbours.
  - The raid is the peak and the march is the valley.
  - Part 1 opens at low tension, and Sasko's point says that is a good place for important reveals.
- **Give each Part a shape:** settle, threat, set piece, loss or turn, quiet reckoning.

### Mission variety
- Combine a verb (track, ride, paddle, climb, shoot, sneak, build, trade, talk) with a place, an hour or season, and a stake.
- Never use the same template twice in a row. Each mission should add a verb or combine two.
- GTA V is the positive example [69]; RDR2 [1][2] and Ghost of Tsushima [26] are the warnings.
- In The Ford chain, defences pile up near the end (12, 15, 18, 19). Turn one of them into a clock-driven investigation or a heist.

### Making a nobody matter
- **Locally and visibly:** people you helped come back (Kaer Morhen), the homestead grows (AC3, RDR2), and the town changes over the years (Pentiment).
- **As a witness, not the cause, of big history.** This avoids the Forrest Gump criticism [20]. Henry and the civilians of This War of Mine work this way.
- **Through skills learned from people**, like Henry learning to read.
- **Through vulnerability**, as Jayanth recommends [44]. The captive march does this already.
- **Through the background chosen in the customizer**, which should open dialogue lines (Pentiment).

### Branching without the scope exploding
- **The spine is "branch and bottleneck"** [52] (H): the story branches, then rejoins at events every version shares. Put the bottlenecks on history's fixed dates: the raid, the Burning, the 1760 handover, Stanwix 1768, 1775. Between them, track flags and tags. Each bottleneck reads them (line variants, who is alive).
- **Side content as storylets** [53] (H): each one is a small piece of story with prerequisites and effects. The missions file already has `when`. Adding a storylet does not touch the others.
- **Barks by salience** [53] (H): pick the most specific line that matches the player's tags, and always keep a default line.
- **Branch inside a mission by approach**, and let the outcomes converge (GTA heists, KCD).
- **Endings:** a hidden tally (Witcher) plus who is alive, which the doc already has.
- **Caps:** limit allies, endings and contacts. 80 Days and Kaer Morhen both show how combinations blow up [43][31].
- **One event seen from two sides.** Part 1's escape choice can mean you meet the Burning from outside if you escaped, or from inside if you stayed. Both paths rejoin in 1760. Both need consultation.

### Memorable antagonists
- Keep the antagonist close to the protagonist, present throughout, and likeable first: Dutch as the father figure (H), Haytham as the man you play first [18], the Baron's sympathy before his sins [28].
- Give Hollis and Company a face (Vane) and a handwriting (his letters).
- **Plant Silas Vane in 1757.** He could be the land-office clerk who registers your claim and is kind to you.
- **In 1760 he could buy back returned captives or pay your passage home.** This is unverified: the history track must check whether agents paid to redeem captives in 1760.
- **In 1765 he holds a paper on your homestead.** The debt makes Part 3 personal.
- Give him a loud brute among his men, as Micah is to Arthur, so Vane's own carefulness stands out.

### Making text-only dialogue hit hard
- **Keep lines short.** Frostpunk cut its plots to a sentence or two [40], and Disco Elysium aimed for fast, ticking lines [57].
- **Give each community a lettering** [46][47].
- **Let silence work.** A card with a single line after a loss is enough.
- **Make documents physical.** Leases, letters and broadsides are items you read in the world. "Paper Against Paper" (mission 3) is the natural place.
- **Swap lines by reputation** inside cards, as RDR2's honor swaps lines [4].
- **Let NPCs refuse, leave and decide** for themselves [44].

### Cutscenes without voice
- Stage scenes in the engine with the trailer pipeline's camera takes. Anchor text to the speaker and let the player hold a key to read. Ambient sound and music do the voice's job.
- **Theatre staging (Kentucky Route Zero):** the scene rearranges itself instead of cutting away [55] (M).
- **Frozen tableau (Return of the Obra Dinn):** freeze a moment and let the player walk through it. It needs posed figures, not animation [56] (M). Uses:
  - the raid's aftermath;
  - the night Elias drowned, as Ackerly tells it in "Ferryman" (12);
  - the burned town, only with the office.
- **Story minigames (Pentiment):** a barn raising, signing a lease, loading a bateau.
- **Standoffs** (Ghost of Tsushima).
- **Date cards**, which the HUD already has.
- **Cost:** cards and frozen tableaux cost almost nothing at runtime, which keeps the Mac mini cool.

---

## 3. Arc Raiders, for co-op and PvP storylines

**How it works**
- An underground hub (Speranza) has traders who give quests and slowly reveal their own agendas. A codex collects what you learn [59] (H).
- Quests send squads of 1 to 3 onto shared maps where other players compete [59] (H).
- Map conditions rotate on a fixed schedule (night raid, electromagnetic storm, Harvester events) and change risk and reward [60] (M).
- Expeditions are an optional reset every 8 weeks with permanent account rewards. In the fiction, you build a caravan and leave [61] (M).
- "Don't shoot" calls and proximity voice chat make trust the story, and betrayal stings because the trust was real [62] (M).

**For Frontier**
- Make German Flatts or the ford post the hub. Contacts give contracts (escort a bateau, raid a pack train, a hunt) that can collide with a squad on the other side, such as the escort against the Black Boys.
- Run scheduled valley conditions as server-wide windows: hard frost, court day, militia muster, the fur brigade coming down, the 1768 treaty crowds.
- Make "going west" the Expedition: an optional reset into the next storyline's year that carries an heirloom (a rifle, a family name, a quilt). This matches the doc's "every other storyline starts fresh."
- Give players period peace signals (a raised hand, a white cloth, a hail), since NPC dialogue is text.
- Keep world-changing beats, like burning the Flatts, to solo play or the co-op host's world. In shared 16-player sessions, use contracts and conditions instead.

---

## 4. The 12 most useful lessons, ranked

1. **Introduce people before you put them at risk.** Add 2 or 3 errands at German Flatts before the raid, and plant the farm family's brother there (KCD [34]; AC3 Homestead [22]; RDR2's camp [5][6]).
2. **Missions must use the sandbox, not fight it.** Fail only on real goals and allow more than one approach. Keep `StoryObjectives` checking results in the world (RDR2 [1]; GTA heists [10]; KCD [34]).
3. **Bring the antagonist in early, make him personal, and show his help before his sins.** Silas Vane appears in 1757 (Baron [28][29]; Haytham [18]).
4. **Build on a branch-and-bottleneck spine with bottlenecks on fixed historical dates.** Use storylets for side content and salience-picked barks for reputation tags [52][53].
5. **Decide endings and late scenes from many small moments.** Allies you helped turn up at the final defence; cap their number [33][31][4].
6. **Use the heist shape for crime and raid missions** (scout, prep, approach, crew with a cut and loyalty). Crew slots double as co-op roles [10][59].
7. **Keep the nobody at the edge of history, and let them matter locally.** They witness Stanwix; they are not in every famous room [20][45].
8. **Give each community its lettering, write text in live, keep lines short, and offer a plain-font toggle** [46][47][48][40][63][64].
9. **Create pressure with the clock, not countdown timers.** Some acts cost hours, side chances expire, and the text says so clearly [49][34][35].
10. **Open each time jump with a reckoning** of what changed because of you, carried by systems and never by a lecture [45][41][39][21].
11. **Every side chain is a person with a twist, and no template repeats.** No bare fetch quests [32][27][26].
12. **Use a cheap, strong unvoiced cutscene kit:** in-engine staging, frozen tableaux, theatre-style rearranging, date cards, story minigames [55][56][46].

## 5. Five traps to avoid

1. **Forcing an atrocity.** GTA V's unskippable torture [13]. In Part 2 and in any raid, the player must be able to refuse, warn, or leave.
2. **Native life shown only as war, as a backdrop, or as a source of magic.** Treuer [19], the "Native view of the colonists' story" critique [16], the Clan Mother [17], and the mask warning [14]. If the story goes magical, use the settlers' own folklore and keep it ambiguous.
3. **A slow opening with no people in it.** AC3's five-hour prologue [18] and RDR2's slow start [8]. Two Fires currently opens with six people-less building missions.
4. **Rigid missions and repeated templates.** RDR2's fail-if-you-leave-the-path [1] and Ghost of Tsushima's copy-pasted camps and 16 fox shrines [26].
5. **Exploding scope.** 80 Days went from 20–30 cities to 100+ [43], Kaer Morhen had 9–16 allies in any combination [31], and Bannerlord's main quest felt bolted on [38]. Cap the counts, prefer storylets, and keep the main chain optional on top of the sandbox.

---

## 6. Tools (light on the Mac mini)

- **The project has no dialogue system yet.** Story text today is the cards in `two_fires.json`, shown by `scripts/story/story_hud.gd`.
- **Cheapest path:** stay with JSON and add storylet `when` conditions on tags.
- **Ink options:**
  - inkgd: pure GDScript, MIT licence. Godot 4 support lives on a separate branch with no official release yet.
  - GodotInk: needs the .NET (C#) build of Godot.
- **Dialogic 2:** GDScript, MIT licence, needs Godot 4.5 or later (the project is on 4.7) [67].
- **Recommendation:** stay with JSON, and adopt ink only if the writers need it.
- **Fonts:** UnifrakturMaguntia, Libre Caslon and IM Fell are free under the OFL [65].

---

## Sources

1. PC Gamer, RDR2 review: https://www.pcgamer.com/red-dead-redemption-2-review
2. Player discussion (L): https://lemmy.imagisphe.re/post/202557/718211
3. https://arynews.tv/gta-6-will-adopt-red-dead-redemption-2-style-chapter-structure-rockstar-confirms ; https://gtaintel.com/news/gta-6-chapters-story-structure-rdr2
4. https://www.thegamer.com/red-dead-redemption-2-honor-changes-story/ ; https://reddead.fandom.com/wiki/Honor
5. https://www.gamerevolution.com/guides/450813-red-dead-redemption-2-camp-needs-and-morale
6. https://twinfinite.net/guides/red-dead-redemption-2-story-summary/
7. https://guides4gamers.com/red-dead-redemption-2/quests/home-improvement-for-beginners/
8. https://whatculture.com/amp/gaming/8-biggest-flaws-in-red-dead-redemption-2
9. https://www.ireddead.com/rdr2/news/vulture-interviews-dan-houser ; https://nygamecritics.com/2018/10/26/the-process-how-my-rockstar-games-story-in-vulture-came-to-be/
10. https://en.wikipedia.org/wiki/Grand_Theft_Auto_V
11. https://thegtaplace.com/news/28256/polygon-interviews-dan-houser-on-the-gtav-characters/ ; https://www.mcvuk.com/development-news/dan-houser-on-the-gta-v-gender-bias/
12. https://www.gematsu.com/2013/07/grand-theft-auto-v-not-all-characters-playable-from-start
13. https://www.nbcnews.com/technolog/grand-theft-auto-v-torture-episode-sparks-controversy-4B11185864 ; https://www.denofgeek.com/?p=119538
14. https://newspaperrock.bluecorncomics.com/2012/11/assassins-creed-3s-mohawk-advisers.html ; https://en.wikipedia.org/wiki/Ratonhnhak%C3%A9:ton
15. https://www.kasu.org/2012-10-31/a-mohawk-hero-in-the-not-so-diverse-gaming-world
16. https://microsites.csusm.edu/nonnativewarpaint/?p=20
17. https://newspaperrock.bluecorncomics.com/2013/01/native-values-in-assassins-creed-3.html
18. https://www.killscreen.com/does-all-ac3-prelude-help-or-hurt/
19. http://newspaperrock.bluecorncomics.com/2012/11/assassins-creed-3-misrepresents-history.html
20. https://amherststudent.com/article/assassins-creed-iii-fails-flaunt-its-assets/
21. https://www.complex.com/pop-culture/a/michael-rougeau/ubisoft-assassins-creed-3-review-pursuit-of-happiness ; https://selectbutton.com/reviews/assassins-creed-iii-review
22. https://assassinscreedwiki.accesstheanimus.com/wiki/Myriam
23. https://en.wikipedia.org/wiki/Ghost_of_Tsushima
24. https://www.androidcentral.com/ghost-tsushima-creative-director-interview ; https://geekculture.co/geek-interview-ghost-of-tsushima-nate-fox
25. https://www.denofgeek.com/?p=600501
26. https://www.videogameschronicle.com/review/ghost-of-tsushima/ ; https://gamingbolt.com/ghost-of-tsushima-review-ghost-of-assassins-creed
27. https://www.tribality.com/?p=35945
28. https://en.wikipedia.org/wiki/The_Bloody_Baron
29. https://kotaku.com/the-story-behind-the-witcher-3s-bloody-baron-quest-1736090893
30. https://www.pcgamer.com/how-the-witcher-3s-best-quest-was-made/
31. https://www.shacknews.com/article/94509/witcher-3-quest-designers-talk-design-process-most-difficult-quest-to-create
32. https://windowscentral.com/gaming/im-grateful-the-witcher-4-isnt-following-this-annoying-rpg-trend-a-key-cyberpunk-2077-and-the-witcher-3-policy-lives-on-with-the-sequel ; https://stevivor.com/features/interviews/cd-projekt-reds-mateusz-tomaszkiewicz-on-the-witcher-3-wild-hunt-and-lessons-learned-for-hearts-of-stone/
33. https://gamesradar.com/witcher-3-ending-best-worst ; https://thewitcher3.wiki.fextralife.com/Endings
34. https://www.gamebanshee.com/kdxqy
35. https://steamcommunity.com/app/379430/discussions/0/591766382100683960
36. https://primagames.com/tips/kingdom-come-deliverance-learn-how-read-mightier-sword-quest ; https://kingdom-come-deliverance.fandom.com/wiki/Skills_(KCD)
37. https://www.gamewatcher.com/2018-20-04-warhorse-co-founder-criticizes-media-over-kingdom-come-controversy ; https://english.radio.cz/node/8210854
38. https://ianboudreau.substack.com/p/mount-and-blade-2-bannerlord-is-content ; https://steamcommunity.com/app/261550/discussions/0/3776868105337946498
39. https://kotaku.com/the-making-of-a-very-different-kind-of-war-video-game-1560735762 ; https://techraptor.net/content/art-war-mine-interview-11-bit-studios
40. https://www.invenglobal.com/articles/6528/igc-2018-empathize-with-numbers-the-process-of-frostpunk-scenario-writing
41. https://destructoid.com/?p=220323 ; https://www.dreadcentral.com/reviews/280943/frostpunk-review-apocalypse-done-depressing
42. https://en.wikipedia.org/wiki/80_Days_(2014_video_game)
43. https://www.gamedeveloper.com/business/postmortem-inkle-s-i-80-days-i-
44. https://gdcvault.com/play/1023062/Forget-Protagonists-Writing-NPCs-with ; https://gamedeveloper.com/design/video-writing-npcs-with-agency-for-i-80-days-i-and-beyond
45. https://en.wikipedia.org/wiki/Pentiment_(video_game)
46. https://www.pcgamesn.com/pentiment/art-fonts-story
47. https://languageatplay.de/?p=3624
48. https://www.familygamingdatabase.com/accessibility/Pentiment
49. https://www.videogameschronicle.com/review/review-pentiment-is-an-outstanding-tale-of-monks-mystery-and-murder ; https://dev.avclub.com/pentiment-game-review-obsidian-1849843232
50. https://www.rpgfan.com/review/pentiment/ ; https://www.gameinformer.com/review/pentiment/quill-power
51. https://www.dualshockers.com/pentiment-wouldnt-exist-if-not-for-game-pass/
52. https://www.ifwiki.org/Standard_Patterns_in_Choice-Based_Games
53. https://emshort.blog/2016/04/12/beyond-branching-quality-based-and-salience-based-narrative-structures/ ; https://emshort.blog/2019/11/29/storylets-you-want-them/
54. https://notesbylex.com/interest-curve
55. https://gdcvault.com/play/1021134/Scenography-of-Kentucky-Route ; https://bulletpointsmonthly.com/2020/03/18/theatrical-spaces
56. https://emshort.blog/2019/06/06/return-of-the-obra-dinn-lucas-pope/
57. https://en.wikipedia.org/wiki/Disco_Elysium
59. https://arcraiders.com/news/everything-you-need-to-know
60. https://insider-gaming.com/arc-raiders-event-tracker-every-map-condition-schedule/
61. https://www.pcgamesn.com/arc-raiders/wipe-reset-rewards ; https://mp1st.com/news/arc-raiders-optional-wipes-december-17-permanent-expedition-rewards
62. https://godisageek.com/reviews/arc-raiders-review/ ; https://kotaku.com/arc-raiders-embark-pvp-toxic-betrayal-leaper-2000640905
63. https://digitallibrary.hsp.org/index.php/Detail/entities/ENT.000003168
64. https://www.library.upenn.edu/events/typography-independence/makers-blog/printing-and-type
65. https://www.fontsquirrel.com/fonts/unifraktur-maguntia ; https://www.fontsquirrel.com/fonts/libre-caslon ; https://lists.fedoraproject.org/pipermail/fonts/2010-June/001158.html
66. https://en.wikipedia.org/wiki/Pow-wow_(folk_magic)
67. https://github.com/ephread/inkgd ; https://github.com/paulloz/godot-ink ; https://github.com/dialogic-godot/dialogic
69. https://www.igrandtheftauto.com/gta5/news/gta-v-preview-and-new-info-round-up