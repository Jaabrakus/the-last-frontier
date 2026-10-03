<!-- completeness critic over the six tracks, 2026-10-02 -->

# Completeness review: corrections and gaps in the six Two Fires research reports

I read all six reports. I also grepped `data/story/missions/two_fires.json`, `scripts/story/` and `docs/main_story.md`. I edited nothing and did not launch Godot. The web search budget was already used up (200 of 200), so every check below was a direct page fetch.

## A. Spot checks on the claims the story rests on

1. **Saint-Francis raid date: 4 October 1759 is correct.** The rangers saw the town's smoke late on 3 October and attacked on the 4th, so design-arc's "3 or 4 October" question is settled. (High)
   - 142 rangers reached the town.
   - Rogers claimed "as many as 200" dead. French reports said "closer to thirty, mainly women and children."
   - On the retreat, McLynn counts 3 officers and 46 other ranks killed or captured.
   - Source: https://en.wikipedia.org/wiki/St._Francis_raid
2. **German Flatts, 1757: the Oneida warned three times, not once or twice.** (High: transcription of the original testimony.) history-core and design-arc each have only part of this. The in-game text should say "warned three times."
   - The first warning came about 15 days before the attack.
   - A further report from Oswegatchie came later. The "6 days" in the transcription is the gap between warnings, not 6 days before the attack.
   - A wampum belt arrived the day before.
   - Losses: "About 40 … killed or drowned" and "nearly 150 men, women and children" taken.
   - The fort was "about a quarter of a league from the village."
   - This page does not say which bank the village was on. The north-bank and south-bank claim rests on Wikipedia and schenectadyhistory.org (Medium).
   - Source: https://www.herkimer.nygenweb.net/gerflats/gerflatsattacks.html
3. **Black Boys rebellion.**
   - Confirmed: the pack train had 81 horses; 200 to 300 armed men surrounded Fort Loudoun on 11 March; the only casualty was James Brown.
   - The number of men who stopped the train is not settled. Wikipedia gives no number. EBSCO says "a group of ten men" and dates that interception to 5 March, not the 6th. design-arc's "about 35" does not appear in the page it cites, so treat it as unverified.
   - On the cargo, EBSCO says it was both trade goods and goods for the British "to keep the peace". Write it as "trade goods and diplomatic presents."
   - Sources: https://en.wikipedia.org/wiki/Black_Boys and https://ebsco.com/research-starters/history/black-boys-rebellion
4. **Tryon County was created on 24 March 1772**, with its seat at Johnstown and five districts. Confirmed. (Medium-High) https://en.wikipedia.org/wiki/Tryon_County,_New_York
5. **The 1768 boundary line in New York needs a warning for writers.** (High) https://en.wikipedia.org/wiki/Line_of_Property
   - The treaty ends the line "to Canada Creek, where it empties into the Wood Creek at the West of the Carrying Place beyond Fort Stanwix."
   - That Canada Creek is west of Rome. It is **not** West Canada Creek at German Flatts, where Belestre's force came in. Writers will mix the two up.
   - German Flatts was on the colonial side long before 1768. So The Ford's land rush has to be either on land further west toward the line, or a fight over land already patented (a double sale). It cannot be "newly opened" land at the Flatts.
6. **Sir William Johnson's land and enslaved people.**
   - The DCB confirms 130,000 acres from the Canajoharie Mohawk, about 40,000 acres from the Oneida in 1765, and about 100,000 acres on Charlotte Creek for £300, abandoned after 1768. https://www.biographi.ca/en/bio/johnson_william_4E.html
   - Wikipedia's Johnstown page says he "enslaved some 60 Africans" and was "the largest enslaver in the county and perhaps in the state." (Medium) https://en.wikipedia.org/wiki/Johnstown,_New_York
   - history-core's "his son inherited about 20" does not contradict this. Use about 60 for the Johnson Hall household.
7. **James Smith's adoption town was not on the Allegheny.** (High) https://gutenberg.org/cache/epub/44934/pg44934-images.html
   - He was adopted at Tullihas, "on the west branch of Muskingum … inhabited by Delawares, Caughnewagas, and Mohicans." That is in Ohio, and it was a mixed town.
   - Confirmed: his gun was taken and he hunted with "bow and arrows for near two years"; the starving winter was February 1758.
   - Consequence: Smith's material involves the Lenape and Mohican offices, not only Kahnawake.

## B. Contradictions between the reports

1. **The Native town candidates.** maps-assets researched Odanak, a Seneca site (Townley-Read) and Canajoharie.
   - Townley-Read dates from 1715 to 1754, so it was gone before the story starts.
   - The Canajoharie Mohawk were British allies; their town would not have taken in captives from a French raid.
   - Only Odanak fits both the 1757 capture and the 1759 burning. Drop the other two as Part 1 towns, and design for a mission town of the Seven Nations of Canada.
2. **"Walked north."** The Prologue card (two_fires.json:104) and maps-assets' travel map both send the captives north. history-core gives the route as west over the Oneida Carry to Oswego, then by water down Lake Ontario and the St Lawrence (Medium).
   - My own rough straight-line estimates from coordinates (not sourced): German Flatts to Kahnawake about 285 km, to Odanak about 380 km. The water route is much longer.
3. **Objective kinds.** design-arc says its contracts "reuse" go_to, deliver, hunt, capture, escort, steal, defend, survive_until and stay_unseen. Of those, only go_to exists. The built kinds are go_to, fell, build, fire_lit, kill (animals only) and wait_for. Every multiplayer mode depends on codebase item 2 being done first.
4. **`when` conditions.** design-story assumes the missions file "already has `when`", which would make storylets cheap.
   - My grep found `when` only in the file's summary text.
   - No mission uses it, and nothing in `scripts/story/` reads it.
   - So the director needs work before storylets are possible.
5. **Story missions in co-op.** design-story wants co-op role slots inside story missions. But story cards always pause the game (story_hud.gd:160), and design-arc keeps world-changing beats to solo play or the host's world. This needs a decision.
6. **Four different policies for magic:**
   - history-hidden: a New Game setting of History, Whispers or Folklore.
   - design-arc: a seasonal Wild Hunt during the Twelve Nights, with a Himmelsbrief that keeps loot when you die.
   - design-story: ambiguous legends on the Ghost of Tsushima "Mythic Tales" model.
   - maps-assets: magic as a map condition or layer.

   history-hidden's setting option can hold the other three. Separately, the mammoth already in the game, which design-arc uses as a boss, breaks a strict History mode. Decide whether it only appears outside that mode.
7. **Which maps.** maps-assets proposes 5 core squares (8 with options) and leaves out Lake George. history-hidden calls Lake George and Champlain "the strongest new map", carrying 3 or 4 storylines. design-arc's Mode A needs no new map. Pick one set.
8. **How Silas Vane enters.** There are four competing versions:
   - design-story: a kind land-office clerk in 1757.
   - design-arc: the Fort Herkimer sutler buying burned lots in 1757–58.
   - history-hidden: modelled on John Hendricks Lydius.
   - history-core: Baynton, Wharton & Morgan, or George Klock (unverified).

   Also, two_fires.json:82 mentions "the land office". My understanding is that New York land came by patent from the governor and council, not from a land office (Medium; I did not check this). Verify before writing the clerk version.
9. **Adoption wording.** main_story.md:149 says "a family who lost a son" and "at first no name". The JSON already says "lost someone", and the narratives show people named at the adoption itself. Bring the design doc in line with both.
10. **The Prologue's geography.**
    - The game's river runs north–south in the east column of the grid, so "north bank" has to be mapped to one side of it.
    - two_fires.json:20 puts the homestead south-east of the stockade, which is next to the fort, on the side that did not burn.
11. **The year of The Carry.** design-arc sets it in 1756; maps-assets in 1758. Minor, but pick one.

## C. Claims that look wrong or unsourced

- **history-core, Kirkland:** "among the Oneida from about 1764–66." My recollection (I could not check it this pass) is that he was with the Seneca in 1764–66 and began his Oneida mission in 1766.
- **history-core, the committee:** "Committee of Safety formed 27 August 1774." That date may belong to the Palatine district meeting rather than a county-wide committee. Check it before writing the 1774 missions.
- **history-hidden, New France:** "more than 1,000 enslaved Black people by 1759." This looks like a conflation (Low-Medium, from recall). The commonly cited totals cover the whole period up to 1834, and most people enslaved in New France were Indigenous ("panis"). That side of it is itself consultation material.
- **design-arc, the Black Boys:** "about 35 men" is unsourced (see A3).
- **design-arc, 8v8:** "the owner's 8v8 wish" is not in this request. Confirm where the owner said it.
- **design-story, 1760:** Vane redeeming captives or paying passage home in 1760 has no source, and history-core found nothing on returns in 1760. Do not build on it.
- **maps-assets, Odanak:** "51 houses" could not be traced (the report marks it Low). Do not use it.
- **design-story, tools:** Dialogic 2 "needs Godot 4.5 or later" is unverified, but nothing depends on it.

## D. Gaps no track covered

1. **Who to consult.** No report lists the offices, what each one covers, or the order. The content implies at least:
   - Odanak and Wôlinak (Waban-Aki) for Parts 1 and 2;
   - Kahnawake (Smith's family, the smuggling trade);
   - the separate Oneida nations in New York, Wisconsin and Ontario;
   - Stockbridge-Munsee (Samadagwis, the Stockbridge rangers, the Mohicans at Tullihas);
   - the Lenape/Delaware (Tullihas, Shingas, Post);
   - the Seneca (Devil's Hole, Jemison).

   I recall a live dispute in which Odanak objects to the Vermont state-recognised "Abenaki" groups (Low-Medium; not verified). Contact the Quebec band councils directly.
2. **"Works with the slot empty" does not hold for Parts 1 and 2.** Part 1 happens inside the town, Part 2 is the burning of Odanak, and no track proposed a fallback.
   - A documented one exists: captives bought or held by Canadians. Catherine Frank was held in Montreal, Stuart was sold to priests at Detroit, and Susanna Johnson's family was imprisoned in Quebec.
   - French-Canadian content needs no sign-off.
   - This is also the only place the owner's "new setting on a worktree" clause might apply, and no track looked at an alternative setting.
3. **Children and graphic violence.**
   - The code aims for "anyone can be attacked", growth.gd has children, and the real raids killed women and children.
   - There is no rule that children cannot be harmed, and no one checked age ratings or store rules.
   - On-screen scalps, the gauntlet, and the cannibalism on the Saint-Francis retreat also need a written content policy.
4. **Freedom-seekers in the bounty system.** Hue and Cry draws on newspaper reward notices, a genre that includes many adverts for people escaping slavery. Never allow them as targets; a mission to help them is the better use. Also check that the household's "workers" do not read as unfree labour by accident.
5. **Wampum belts.** history-core's first mission has the player carry a belt. Belts are diplomatic records of living nations, so they belong in a consultation slot, not in the loot pool.
6. **Captives in 1760.** What happened to them when Montreal surrendered is still unresearched, and the 1760 turning point in design-story depends on it.
7. **French and Canadian characters.** They are the enemies who need no consultation and the basis of the fallback in item 2, but no track researched their voices, dress or lettering.
8. **Languages in text-only dialogue.** There is no rule for German, Dutch, French and English speech, for interpreters, or for untranslated lines. The Fraktur lettering also needs readability and translation checks.
9. **AI-made assets.** Steam requires games to disclose AI-generated content (from recall, Medium), and no track mentioned it. The project's SOURCE.md and SHA-256 rules also apply to fonts and museum scans.
10. **Empty years.** No report has missions for 1760–63 or 1769–73.

## E. Risks

**Scope**
- On the table now:
  - about 24 mission ideas in history-core;
  - more than 10 hooks in history-hidden;
  - 3 multiplayer modes and a magic overlay in design-arc;
  - 5 to 8 new map squares, plus Lake George;
  - 17 missing features in the codebase report, including two size-L items.
- The Prologue raid alone needs the human fighter (L), fire and ruin (M), captivity (S-M) and ideally in-game cutscenes.
- I suggest a freeze to four things:
  - correct the Prologue's facts and add neighbour errands;
  - build the human NPC fighter;
  - build one multiplayer mode, The Burnt Flatts, which reuses wolves, weather and ice;
  - write one storyline that needs no consultation, either The Ford or a Lake George rangers story, while consultation goes on.

**Sensitivity**
- Part 2 depends on one nation's sign-off (Odanak), and there is no historical substitute. main_story's idea of moving to another nation breaks the history.
- The Black Boys convoy mode rewards stopping goods bound for Native nations. The context has to be inside the mode itself, not only in the story.
- The witch-master hook ended historically with an old woman dead. The Himmelsbrief and Braucherei are living Christian folk practices, so avoid treating them as loot or as a joke.

**Heat on the Mac mini**
- **16 players on a player's machine is too many.** All tracks agree on 8 to 12. 15 remote players at about 2 ms each comes to about 30 ms a frame, so 16 players needs a separate headless server.
- **Crowd scenes exceed the budget.** Watching Stanwix from the crowd (about 3,000 attendees is often quoted but unverified) and the handover of 200+ captives both go past the cap of 12 animated figures. Use flat stand-in figures and sound.
- **Fire lighting adds up.** Each torch light costs 0.55 ms, or 1.4 ms with a shadow. Burning 60 houses needs one shared fire light with no shadows.
- **Lake George is expensive.** Open water and long sight lines defeat occlusion, and 260 bateaux plus rope-and-oxen hauling is heavy physics. Keep the boats non-physical until they are raised.
- **Albany** needs merged meshes per block and occluders.
- **Development work makes heat too.** Bake one square at a time; elevation-data conversion, stand-in-image bakes and `--write-movie` runs are all heavy.

## F. Decisions needed from you

1. Which town Part 1 uses, and whether Part 2 stays the burning (only Odanak fits).
2. What Parts 1 and 2 do with the slot empty. I suggest evaluating Montreal captivity.
3. One magic policy, and whether the mammoth stays out of History mode.
4. Whether Lake George is in the map set.
5. Which version of Silas Vane's introduction to keep.
6. A child-harm and gore policy, and the list of excluded bounty targets.
7. The player cap when a player's machine hosts: 8 to 12.

Files read: `/Users/kiwimango/Downloads/Frontier/data/story/missions/two_fires.json`, `/Users/kiwimango/Downloads/Frontier/docs/main_story.md`, `/Users/kiwimango/Downloads/Frontier/scripts/story/`. `/Users/kiwimango/Downloads/Frontier/scripts/weapons/musket_butt_ground.gd` exists, as design-arc says.