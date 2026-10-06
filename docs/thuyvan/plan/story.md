# Thủy Vân, Book I: the player's story (plan, 2026-10-05)

Part of the Thủy Vân conversion plan. This part covers the player's own story: the arc, missions, choices, ending, where
the canon cast crosses the player's path, how each people's start differs, side content from the 32 short stories, the
player's small relational power, and where the old main-story ideas land.

Sources: `bible_v3.txt` (D01-D16, H01-H23, P01-P08, L01-L16, R01-R22, the 50 dossiers' Book 1 entries),
`series_bible.txt` (v1 reveal ladder and Book I beats), `stories.txt` (32 stories and 8 seeds), the 15 concept sheets,
memory notes (main story v6, world peoples, clothes, boats, household, co-op, soundtrack, no target cues, no debuffs, skills
easy to learn, judges by eye), the main checkout's `docs/main_story.md` and `scripts/story/` (read only), and the
spellcraft worktree's `docs/bending_design.md` (read only).

Status words, as the bible uses them: **CANON** means the bible says it (V3 inherited, or V3 proposal the owner has not
overruled). **PROPOSAL** means this plan invents it so the game can play, and the owner must approve it before it ships.
I mark every PROPOSAL that touches canon.

---

## 0. The short version

- **Logline (PROPOSAL):** *"You taught them the rite, and the rite put their name in the register. Three months later the
  river at Đá Trắng stops, the dig they were sent to is burned, and the notice says no one lived. Everyone has an account
  of what happened. You need the true one, and your own."*
- **Title:** the storyline uses the owner's Book I title, **The River That Would Not Move** (owner to confirm).
- **You** are an ordinary adult of any of the eight peoples, made in the creator. You are not chosen and you do not fix
  the river. Your stake is personal: **your kin** (by default your child, newly counted as an adult at 15-16; also a
  younger sibling, a ward or an apprentice) is levied for "river works" and sent to a dig in the south. The dig is the one
  Ruk-Khan burns in Book I's opening.
- **The spine:** a Prologue and four acts that follow Book I's own four acts and dates (Year 0, months 1-5). The canon
  events happen around you, on time. You see pieces of them, carry testimony between people, and get your kin back. The
  war still begins for the wrong reason, because it does in the books. What your choices change is local and personal:
  who lives in your village, who trusts you, how your kin comes home, what becomes of your testimony, and where you stand
  when the war starts.
- **The signature system is the Account.** It is a ledger of what you saw, who told you what, what you can show, and what
  you owe. It gives no narrator truth: contradicting accounts sit side by side with their sources. This is how the game
  obeys "no exposition dump; the player earns the cosmology".
- **Your power is small, relational and local.** You have your people's art, learned from people and places. It is
  strongest at home, and away from home it works where you have made a relationship with a place and kept its obligation.
  The costs are debts and consent, never slower movement or worse aim. Tidebreak is the festival sport where every art
  has its full kit.
- **Old ideas, plainly:** the parent teaching the child **fits** (it is the Prologue). The "child taken" beat **fits** as the
  levy plus the burned dig. The parents' abrupt death **fits** as the loss of an elder at the Silence (owner to confirm).
  The POV switch to the child **does not fit** a five-month Book I. Sky pirates, keelstone, galleons, the mammoth and the
  Downbelow **do not fit**. The Buried Kingdom **does not fit Book I** (it opens in Book II). The Reed Campaign is living
  memory, not a playable chapter. The Ash Coast is Book II. Details are in section 8.

---

## 1. The rules this story obeys, and how

| Rule (source) | What the story does |
|---|---|
| No faction is the good one (S1 political rule) | Your kin is taken by the empire's levy, burned out by Floodborn, sheltered by Floodborn, and freed by whichever method you choose. Every side has a true grievance and a crime in the same act. |
| No chosen one (S1; prophecy unreliable) | You are one of hundreds of families on the casualty notice. Nobody prophesies you. Your testimony is one source among many, and the war starts anyway. |
| Power is relational, costs, weakens away from home (07; S1 rules) | The arts in section 6: place bonds, named obligations, consent. You start with two household moves and learn about five more from teachers. |
| The dead do not return (07 limit 8) | Losses in the story are final. No revival, no "voice of the dead" that brings someone back. Ancestor voices are testimony, sometimes wrong. |
| Ancestors can be wrong (07 limit 4; R06) | Consultation answers (Ancestor-Bound players) are logged as "testimony: unverified" and are sometimes wrong. |
| No exposition dump (S1 mystery rule) | No codex of world truths. Lore enters the Account only as attributed claims with a source and a confidence. |
| Ninth River is a Book V truth (D15, R19) | Nothing in Book I says or implies it. See the reveal guard below, including the map art problem. |
| Peoples are a social classification, not classes (D03, D12) | Arts are traditions learned from teachers and places, not bloodlines. Your home art is just the one you start with. Body facts (gills, density, tails) are real limits, not class locks. Section 6. |
| Floodborn, Hồ Tinh, Mộc Tinh are not humans in costumes (P04, P06, P07) | Their starts use their own bodies, customs, law and limits (moorings and oral law; contract names and identity strain; grove permission to travel). Body work is phased (section 9). |
| Owner: no target cues | No marker on enemies, ever. Your kin is never marked either; you find people by asking (that is the witness theme). Contacts keep the built lantern-and-name post (`StoryContact`), which marks a person you can talk to, not a hostile. |
| Owner: getting hit never slows the player or hurts aim | No art cost, strain or wound touches speed or aim. Costs are debts, closed places and story consequences. |
| Owner: easy to learn, hard to master; human-made | Two moves at the start and one more per act. Each move does one obvious thing (Tidebreak's layout). Depth comes from places, timing and choices, not more buttons. |
| Owner: judges by eye | Every milestone has a review-image list (section 9.4). |
| Owner: no Avatar show words | Player-facing text never says bend/bender/pro-bending, nations, the four-element framing or show move names. The arts are named by relationship (section 6.5). |

### 1.1 The reveal guard (what Book I may show)

Book I's ceiling, taken from the bible's R-records and Book 1 dossier entries:

| May be learned or shown in Book I | Never in Book I (the earliest it is allowed) |
|---|---|
| The Silence is physical and bounded: no ice, no dam, fish suspended, mist that holds, "hands beneath unmoving water" (R01, L03, S1 11) | The name "Hollow Tide", or any named entity behind events (III late, R14) |
| Officials had earlier anomaly reports, seen as mismatched dates (R02, middle) | Hollowing as a mechanism (IV early) |
| Floodborn targets are dig sites people opened: Ruk asks about digging, not tribute (R03, late; partial) | The Sacred Rivers as a containment network or "seal" (IV, R17) |
| Two Heights has two independent maker signs (R04, late) | Memory as the Ninth River (V, R19); eight hydraulic channels vs nine districts as a solved fact (V, R18) |
| Vân Cổ's rescue is genuine (R05, midpoint) | Vân Cổ's communion or allegiance (IV, R15); anything that makes him look sinister |
| Mystery traces: black tablets, knocking underground, a requesting ancestral voice, memory gaps in patients, Grandmother Reed's failed response, unanswered grove offerings, a duplicated seasonal district in imperial maps (S1 Book I mystery line; C04, C18, C29, C42, C45 Book 1) | Mixed-workforce murals and the shared ancient civilization (III, R08); the Drowned King's true closure (III, R09); Liên Khởi (III, R10); the Convergence by name (unnamed I-III) |
| The White Stag seen, with two witnesses disagreeing on its direction (C43 Book 1) | The Lantern Child (Book II), the Quiet Woman and the Thousand-Mouth (not formed) |

**The map art spoils Book V.** The owner's map sheet labels "THE NINTH RIVER: Sông Ký, Memory: A hidden current", and
it labels "The Convergence, Hidden Nexus" and "The Buried Kingdom". The in-game map for Book I must leave out the Ninth
River legend and the Convergence label, and should show the Buried Kingdom only as a scholars' rumor, if at all. There is
a canon-consistent replacement plant: the in-game *imperial* map shows **nine ritual districts** with one seasonal name
duplicated (D05, Bùi Khánh's Book I find). A careful player can notice it, as Bùi does, and nothing explains it.

---

## 2. Who you are

### 2.1 The creator and the household

- You make **yourself**: an adult of any of the eight peoples (by body wave, section 9), plus your relation to the kin
  (parent by default; also sibling, aunt or uncle, hearth-adopter, guild master, grove-keeper) and optionally a
  hearth-mate.
- The **kin** is generated from you and the hearth-mate when you are their parent (`ChildLook.from_parents`, already
  built) at a 15-16 growth stage (`ChildProportion` stages exist; a teen stage for a story person is new, S-M). You name
  them.
- A hidden **bond** count (v6's idea) fills through the Prologue's small choices: answering a question, sharing food,
  letting them do the hard part, the bedtime story. It decides whether your kin trusts your method in Act 3, and whether
  they choose to walk with you at the end.
- The **agreed anchor** (from Vệ's Book I limit "Agreed Anchor", applied to ordinary people): before the kin leaves, you
  agree on a sign: a knot, a verse, a tapped rhythm. In Act 3 your kin has a gap in memory of the night of the burn, but
  they recognize the sign. It is planted in the Prologue and pays off in Act 3, and it explains nothing about why the gap
  exists.

### 2.2 The eight starts

Each start is a short home "pocket" (a small hub map) for the Prologue, then joins one of four Act 1 variants. Rites come
from the owner's own stories.

| People | Home pocket | The kin's rite (story) | How the kin is counted and taken | The loss in Act 1 | Household art (2 moves) | First teachers (stories) |
|---|---|---|---|---|---|---|
| **Dragon-Sea People** | Vạn Thủy canal district (L02) | Lantern Nets on the Seventh Tide (#1): the kin says the names of the dead and raises the first net. "Now you feed people." | The ward census; the river-works levy reads it. | Your elder, a rope-maker mending a barge line, is killed when a lock surges in the low-water days. | Water: Draw, Push | The grandmother (#1); Clerk Phúc (#2) for reading ledgers |
| **Mountain Folk** | Foothill village of the Stone-Ridge clan below Đá Trắng, **Kha Vũ's own village** (PROPOSAL) | The Rope Across First Snow (#4): the night crossing on the rope; "nobody carries you unless you're bleeding". | The clan's hearth roll, copied into the imperial "upland households" tax summary (the H08/H13 problem); the porter levy for river works reads it. | Your elder goes into the still water at the Silence and does not come up. | Earth: Jab, Guard | The aunt (#4); Scout Nhàn (#5) |
| **Stone Children** | Thạch Uyên lower terrace (L05) | Feast of the First Chisel (#7). | Guild contract under H13's narrowed terms: the House owes a crew, so apprentices go to the dig. | Your elder, a cutter, dies in a hurried repair at the Two Heights anchor when it carries impossible loads (L16; an echo of H20). | Earth: Stone Hearing (read stress by touch), Jab | Old Cutter Sen (#9); Mason Lệ Vân (#8) |
| **Floodborn** | A Reed Marches mooring (L06) | The Last Reed Boat (#19): the kin learns the stern bend at a burial boat. | The empire does not count moorings. Imperial toll guards seize the kin in a toll dispute as a "pirate" and put them to forced labor at the dig. | A mooring elder, killed by fleeing guards on the night of the burn. | Marsh water (owner to settle): Draw, Push | Har-Kel (#19); Sha-Ra's clinic (#21) for medicine |
| **Riverborn** | Deep Lotus Reaches pilot dock (L08) | The first dive under the lotus halls (from #18, Lụa). | The kin takes the unsafe pilot assignment **Nara refused** (C17 Book 1: "absent licenses appear in imperial supply reports"; PROPOSAL that it passes to your kin). | Your elder, caught in a nursery channel when its current dies ("a dead current where a school should pass", L08). | Water: Current Read, Draw | Diver Hà (#17); Lụa (#18) |
| **Hồ Tinh** | Vạn Thủy Rain Market (L02; Ảo Thành referred to, not visited) | The naming: the kin's public, contracted and private names witnessed. Children learn identity boundaries before disguise (P06). | The kin signs a translator contract with the river works, and its clauses bind them. | Your elder, a contract-holder, is killed in the same lock surge (the capital variant). | Fox-fire (owner to settle), plus Borrowed Face (body) | Sương Hồ (#10); Lady Yên Khê (#12) |
| **Mộc Tinh** | Lâm Uyên outer grove (L10), a young mobile spirit who chose a smaller body (P07) | White Blossoms at Drought End (#13): the ward's first gathering when the flowers return. | Your **ward** is a human child of the grove-edge village (kinship by shade and stewardship, P07). The village tax roll is levied. | An elder tree you are grafted to dies when the deep corridor fails (C45 Book 1: offerings unanswered). | Wood (owner to settle): Root Grip, Bark Guard | Mộc Chi (#13); the grove-tender (#14) |
| **Ancestor-Bound** | Ancestor Roads shrine hill near Đá Trắng (L11), a house of the same circuit as An Tâm's (not hers) | Paper Windows for the Dead (#22): the last night before the ancestor gates close. | Your kin is your **unbound** sibling (D03; "unbound family labor", L11). The house roll lists them for labor, and they are levied. | Your elder is lost at the Silence while on a pilgrimage to the upper reach that the clans call a burial witness. | **Consultation**, no combat art (section 6.4); staff or spear | Minh Thư (#24); a senior keeper (#23, recast, section 7) |

The variety this gives: four peoples start north (Mountain and Ancestor-Bound on the river; Stone and Mộc Tinh west, at
Two Heights and the grove), two in the capital, two south. All of them meet at Vạn Thủy in Act 2.

---

## 3. The spine: Prologue, four acts, ending

The dates are Book I's. The main beats wait for the player. When a beat starts, the Account's date jumps into its window
and never earlier (for example, Vân Cổ cannot return before month 2). Travel costs days on the calendar through a passage
screen that uses the bible's travel windows (L02 to L03, 6-9 days; L02 to L06, 4-6 days). It is not instant travel, and
closed locks add delay.

Mission kinds in brackets are the existing `StoryObjectives` kinds (`go_to`, `talk`, `follow`, `escort`, `deliver`,
`steal`, `stay_unseen`, `chase`, `defend`, `survive_until`, `build`, `fire_lit`, `wait_for`, `lock_cast`). Anything new is
marked NEW.

### Prologue: Counted (Year -1, the last month and the five flood-rite days), about 45-60 minutes

| # | Mission | What happens | Kinds |
|---|---|---|---|
| P1 | Morning work | Two lessons in your people's craft, taught to your kin (the owner's "teach the child"): knots and net ribs; rope and footing; chisel taps; reed binding; a held breath under lotus roots; contract names; petal gathering; paper trimming. This is also the controls tutorial (the first-time key hints in the top-left). The first art move is used in a chore. | `go_to`, `build`, `talk`, `lock_cast`; NEW: *the kin copies a task* |
| P2 | The rite | The story's rite (table 2.2). You guide; the kin does the hard part. Small choices fill the bond. | `talk`, `follow`, rite set piece (NEW per people) |
| P3 | The register | The kin is entered as counted (census, hearth roll, guild roll, license roll, contract registry, house roll, village roll). **Choice A** (section 4). | `talk`, `deliver` |
| P4 | The levy | The levy reads the roll. You agree the anchor sign. The kin walks to the barge under escort (the `Captivity`/`MarchStage` pattern turned around: you watch them go). For a Floodborn player it is the toll dispute instead. | `follow`, `talk`, `wait_for` |
| P5 | The flood-rite days | The festival goes on with an empty place at the table. The calendar turns to Year 0. | `fire_lit`, `talk` |

### Act 1: Still Water (Year 0, weeks 1-3; Book I act I, "The observed impossible")

Canon around you: Kha sees Đá Trắng stop and returns to his village; Hạc stops him touching the still water; Nhạn
separates raider signs from Silence signs; Linh measures downstream and restricts the harbor; Ruk burns the reopening
site and interrogates its guard; Kor-Va removes prisoners; An tests the eighth voice; Dương detects impossible stress;
Grandmother Reed's response fails at a landing; grove offerings go unanswered.

Four variants share one five-step template:

| Step | North river (Mountain, Ancestor-Bound) | North-west (Stone, Mộc Tinh) | Capital (Dragon-Sea, Hồ Tinh) | South (Floodborn, Riverborn) |
|---|---|---|---|---|
| 1.1 The impossible | At the Đá Trắng reach: the river stops; white stones under stopped water, fish hanging, boats held, mist that holds. | At the Two Heights anchor: the loads go impossible and the bolts sing (Stone). In the grove: the corridor's water goes quiet and the offerings sit untouched (Mộc Tinh). | Low water out of season (Market at Low Water, #25); the canals drop; Linh's crews close the harbor. | **Floodborn:** the burn itself, played from the boats (section 3.1). **Riverborn:** at the landing, Grandmother Reed's customary answer does not come; the guides refuse to call it an omen. |
| 1.2 The loss | The elder goes in to free a held boat of children and does not come up. Someone pulls you back. Kha and Hạc arrive, and you see Hạc stop Kha. **Choice B.** | The anchor repair kills your elder (Stone). The grafted elder tree dies (Mộc Tinh). | A lock surges as the flow returns, and the barge line your elder was mending kills them. | The guards kill a mooring elder (Floodborn). A nursery current dies (Riverborn). |
| 1.3 The rite | River deaths overwhelm the local rites. Mẹ Lửa refuses to bless an unlimited revenge oath (canon), and you are there. An Tâm's relief party performs your elder's rite, with no body. Vệ asks you a plain detail to check one of An's recollections (canon: he tests whether it is hers). You say the names. | Stone: names read at first loading (P03). Mộc Tinh: a cutting kept. | Dragon-Sea: the empty bowl beside the household ledger (P01). Hồ Tinh: debts named and suspended. Bảo, Linh's lieutenant, asks witnesses for times. Your answer goes into the duplicate report he keeps (canon C23). | Floodborn: law spoken before witnesses, a tally peg carved. Riverborn: sung route intervals. |
| 1.4 The notice | A posted notice: "Pirates burned the river works at the Heron Shrine dig (PROPOSAL name). All workers lost." Your kin is on the list or is "unlisted". You may hold their rite anyway; they will learn you did. | same | The notice at the grain office; the barber Nhu's rumor (#28). | Floodborn: your kin is **not** among the prisoners Kor-Va freed. The fleeing guards took some captives as proof of "pirate auxiliaries". Riverborn: your kin is held among the detained workers. |
| 1.5 Leaving | Leave the house to the household (`Household`): who keeps it, who goes. North and north-west players head for Two Heights; capital players stay for Act 2; Floodborn head upriver; Riverborn head for Vạn Thủy to get on a convoy (Act 2). | | | |

### 3.1 The burn, for a Floodborn player (Act 1.1 South)

The most sensitive scene in the game. Kor-Va's boats need hands, and you go because your kin is a prisoner at the dig.
You **do not kill workers**: the mission's verbs are search, free, carry and pole the boat. You see the warband's violence
and the dig's own violence: forced labor, and stamped plans with old marks. You see Ruk ask the guard about digging, not
tribute (R03). You see Kor-Va move prisoners before the second burn, too late for all of them (canon C03, C37). **Choice
C:** help Kor-Va move prisoners, or chase the guards' boat that carries your kin. Chasing fails by design, because they
escape upriver, and it costs lives at the dig. Helping saves named workers who later testify. In the north and the
capital the same night arrives only as a notice. That gap is the point.

### Act 2: The Price of Crossing (months 2-3; Book I act II)

Canon around you: the Two Heights dispute (Kha's requisition fails, Dương refuses, Lệ Thạch insists on separate
signatories, Yên Dao brokers reciprocal terms, Tấn pushes a raid); the court isolates reports; Minh moves a sealed report
and arranges witnesses; Lạc Thiên asks for a lawful review; Vân Cổ returns at the midpoint and genuinely rescues a
threatened force.

**North path** (Mountain, Ancestor-Bound, Stone, Mộc Tinh), about 6 missions:

- **2.1 Two Heights.** Carry evacuation households and work a joint survey on Dương's explicit terms: hold the rods while he
  listens. You see **two maker signs on one pier** (R04; the Account records it with no interpretation). Tấn asks you to
  back a raid that would bypass the bargain (**Choice D**). Yên Dao's terms make supplies and worker autonomy written
  conditions. Kha organizes the shared retreat. [`escort`, `talk`, `deliver`; NEW: survey hold]
- **2.2 Smoke in Goat Pass** (#5, made a main mission). Cairn messages on the evacuation route have been opened. Your convoy
  is intercepted (a "limited interception"). This plants Tấn's hidden matter (C31: he passed a route schedule) without
  identifying him; that exposure is Book III's. [`defend`, `stay_unseen`, `chase`]
- **2.3 The Return (midpoint).** You are hauling with a column, the threatened force, that is caught between a surging lower
  reach and blocked trails. Vân Cổ arrives with surviving scouts and brings it out on a retreat only he could plan (his
  Perfect Retreat specialty). **It is genuine** (R05). He asks your name and your kin's name, and remembers them. You may
  overhear him ask an officer for access to "the old service roads". That is a plant for Book II's R07, and it means
  nothing yet. [`follow`, `survive_until`, `escort`]
- **2.4 Down to the capital** on a Stone barge (a signed work contract: your obligation) or on a relief barge (5 lock
  stages; the passage screen). [`deliver`; NEW: passage screen]

**Capital path** (Dragon-Sea, Hồ Tinh, plus Riverborn arriving), about 5 missions:

- **2.1c The court's quiet.** Notices that contradict each other, the barber's rumors, a relief queue. Phạm Dực's clerks
  limit emergency releases pending proof (canon). Prince Lạc Minh is seen on a ceremonial relief duty he did not want
  (canon). [`talk`, `go_to`]
- **2.2c The sealed packet.** A masked porter asks you to carry a sealed packet between two offices and keep a copy-chit.
  You are one of the witnesses Minh Nguyệt "arranges ... who will keep it from disappearing" (canon action; PROPOSAL that
  you are one). Later the porter's cover is exposed; that is her canon cost, an exposed minor agent. You never learn who
  sent you. [`deliver`, `stay_unseen`]
- **2.3c The Return, seen from the crowd.** Vân Cổ accepts a public honor (canon). He speaks to the crowd and to you, and
  he is humane and specific. [`go_to`, `talk`]

**All except Floodborn: 2.5 The convoy south.** Linh Hải's relief convoy needs hands and lacks pilots (absent guides,
Book I). You can join as a hand: Linh teaches you to read a false draft mark, a practical skill and not magic. You can
join as its **pilot** (Riverborn, with a channel council's consent: an obligation). Or you can buy a Hồ Tinh broker's
threshold pass instead (a debt). Other routes: win a Tidebreak bout at the Seventh Tide festival for a captain's passage
bet (section 6.6). [`escort`, `talk`; NEW: draft-mark reading]

**Floodborn path:** 2.1f the mooring's judgement on the burn (Urok's alternate refrain kept, canon C39; Sira's report
questioning prisoner policy read aloud, canon C11), then 2.2f upriver as a licensed ferry crew under a Hồ Tinh contract
(Floodborn cannot disguise), then 2.3f the Return seen from a capital crowd that stares at you.

### Act 3: The Useful Account (months 3-4; Book I act III)

Canon around you: Linh finds the earlier warnings (R02); Minh preserves one report and loses an agent's cover; Bùi notes
the duplicated district; Trần Hổ treats shrine destruction as rebellion and orders punitive arrests at Đá Trắng, and the
retaliation produces the coalition its officers claimed already existed.

**Variant H: the marshes** (everyone but Floodborn), about 6 missions:

- **3.1 The toll corridor.** The convoy meets Floodborn boats and the two sides stand off. Nobody is marked; you read
  people. [`escort`, `survive_until`]
- **3.2 The burned dig.** Linh observes it was an excavation, not a village (canon). Search it and pick what to carry
  (**Choice E**): a scrap of the stamped old plans, a rubbing of a black tablet, the guards' tally. At night something
  knocks under the platform. The Account records "knocking, source unknown". [`go_to`, `steal`, `wait_for`]
- **3.3 A guide chain.** Help Har-Kel finish a burial reed boat (#19) and learn the stern bend. A funeral paid in labor
  earns you a guide. [`build`, `talk`]
- **3.4 The clinic** (Mud on the Threshold, #21). Sha-Ra keeps both lists, fighters and detained workers (canon C18). Your
  kin is here, feverish, with a gap in memory of the burn night. They recognize the anchor sign. Kor-Va disputes Ruk's
  timing (canon). [`go_to`, `talk`]
- **3.5 Ruk's terms.** Ruk seeks a maintenance record, not conquest (canon). He wants your kin's testimony about who was
  digging and what was stamped. **Choice F** (section 4) decides how your kin leaves. [varies:
  `talk` / `stay_unseen` + boats / `deliver` / `escort`]
- **3.6 The news from the north.** Trần Hổ's arrests reach your village for northern starts, or the riverbank for everyone
  else. Linh is ordered north (Act IV canon), and you go with her convoy as witnesses. [`talk`, passage]

**Variant F: the capital** (Floodborn), about 5 missions: 3.1f the prison barge in the naval basin, where your kin is
held as proof for an atrocity hearing; 3.2f the sealed-packet thread (as in 2.2c, with the broker who brought you upriver
as the exposed agent); 3.3f Lạc Thiên's lawful review (canon: he asks for review rather than public accusation and helps
secure Linh a hearing), where your kin can be released into Linh's custody as a witness; 3.4f the alternative, a
break-out through the canals (swimming is a Floodborn body strength) with an imperial warrant afterward; 3.5f an Ancestor
house novice notices your kin's memory gap and records it, unexplained; 3.6f north with the convoy, or upriver on your own.

### Act 4: War Named Too Soon (month 5; Book I act IV)

Canon around you: "A local containment failure destroys a politically charged crossing station. Evidence is interpreted
as an enemy attack. Kha accepts temporary coalition responsibility; Linh is ordered north; Ruk prepares further site
defense. An refuses a consultation for the first time before witnesses." Exit: open war authorized on a false causal
account.

- **The station is Khe Lan Ferry** (story #27, Ferrywoman Duyên), a mixed crossing on the lower Đá Trắng river where the
  foothill pack trail meets the lock road. The empire tolls it, the clans use it as a refuge route and Floodborn guides
  work it. The bible does not name the station, so this placement is a PROPOSAL.
- **4.1 Home** (northern starts only). The village after the arrests: Bạc Sơn withholds levies until return dates are
  named; Kha's coalition is forming. [`talk`, `go_to`]
- **4.2 A crossing day.** Work the ferry in a storm ("Crossing at Khe Lan Ferry", #27, played). Several factions report
  knocking under the piers. [`escort`, `deliver`]
- **4.3 The failure.** At a crowded crossing the water at the station goes still for a breath, the knocking stops, and the
  piers fail. There is no fire and there are no enemy boats. Save people, or save the station's log and your Account
  (**Choice G**). A quick player can do some of both. [`survive_until`, `escort`; NEW: destruction set piece]
- **4.4 The account.** Officers find a clan blade and Floodborn tally pegs in the wreck and read it as an attack. At the
  hearing on the bank you give your testimony (**Choice H**). An Tâm is asked to consult the station's dead and **refuses
  before witnesses** (canon). You are one of those witnesses (PROPOSAL). A decree is read: war is authorized. [`talk`;
  NEW: hearing scene]
- **4.5 Where you stand** (**Choice I**, the ending).

### The ending (no later truths spoiled)

The final choice puts you, and separately your kin, somewhere when the war begins:

| You go | What it means |
|---|---|
| With Kha's coalition | Temporary coalition responsibility (canon); your standing with clans and Stone crews. |
| With the imperial relief | Linh's convoy north, Bảo's company; the navy's standing. |
| With Ruk's site defense | The moorings' standing (if Act 3 earned it). |
| With the Stone crews | Lệ Thạch's House or Dương's repair crews. |
| Away | You carry your household out to the grove edge or the southern ports (evacuation). |
| To keep the Account | You copy your testimony to three holders who can each refuse or correct it: a shrine house, a Stone guild, a Floodborn reciter. This plants the series' distributed-witness model as an ordinary choice, with no explanation. |

Your kin makes their own choice, which depends on the bond and on Act 3's method, and it may differ from yours ("separate
futures", the bible's guardrail for Vệ). The last image is Đá Trắng, still not moving. A closing card gives the date. Free
roam continues in a thin "Year 0, month 6" layer: the ring closed, checkpoints, a camp at the Khe Lan ruins. That layer is
also the entry point for a Book II storyline (War of the Nine Banners) that reads the save.

---

## 4. Choices that matter (and what they cannot change)

| Choice | Options | What it changes | What it cannot change |
|---|---|---|---|
| **A** Register (P3) | Let it stand / falsify it | Falsified: the levy takes the neighbor's child, and your kin goes after them of their own will. The neighbor family remembers you (reputation, a side quest later). | The kin ends at the dig. |
| **B** At the still water (1.2) | Pull people from the held boats / record the stopped reach (Nhạn's report wants times and signs) | Rescue: named villagers live and appear later. Record: evidence that carries weight at the Act 4 hearing. | Nobody explains the Silence. |
| **C** The burn (Floodborn) | Help Kor-Va / chase the guards | Lives at the dig, which workers testify later, and the moorings' view of you. | The guards escape upriver with your kin. |
| **D** Tấn's raid (2.1) | Back him / back Yên Dao's terms / stay out | Clan standing; whether Tấn treats you as his (it shapes his Book II approach to you). | The bargain is signed; Kha takes Yên Dao's price (canon). |
| **E** Evidence (3.2) | Plans scrap / tablet rubbing / tally | What you can show at the hearing and in Book II. | No item proves a cause. |
| **F** Ruk's terms (3.5) | **Testify** before the mooring's witnesses (oral law) / **night rescue** (no killing needed; killing brings mooring judgement) / **petition through Linh** (slow, lawful; your testimony enters her log) / **guide the officers** to the mooring (your kin is returned through the empire; civilians die in the raid; the kin knows) | Who trusts you, how your kin regards you, which institutions want you, and whether your kin's testimony is recorded and by whom. | Your kin comes home in every branch except failure states. The coalition still forms. |
| **G** The failure (4.3) | People / log | Who lives (named NPCs) and what you can show. | The station is destroyed. |
| **H** The hearing (4.4) | Tell what you saw (true, unprovable) / tell the useful story (an attack, which is rewarded) / say nothing | Your standing, your Account's fate, and how the officers write you down. | War is authorized on a false account (canon). |
| **I** The ending | Section 3 table | The Book II start and the world-layer flags. | The river, the war, and every canon character's Book I exit state. |

Canon characters are **essential** for their Book I lives: you cannot kill them, and attacking one makes them withdraw and
brings that institution's judgement. That replaces Two Fires' "anyone attackable" rule for named cast. Ordinary NPCs stay
attackable, with consequences.

---

## 5. Crossing the canon cast (without taking their arcs)

The rule: a canon character does in the game exactly what their Book 1 entry says, at its place and time. The player
**witnesses, carries, works for or is asked by** them. The player never makes their decision, never knows their hidden
matter, and never gets an exposition they could not have.

| Character (Book 1 status) | Where you meet them | What they do (dossier) | Your part | Never |
|---|---|---|---|---|
| Kha Vũ (POV) | Đá Trắng, village, Two Heights | Returns to his village; needs the crossing; accepts Yên Dao's price; organizes the shared retreat | Villager, carrier, witness | Command for him; learn his father's survey consent (Hạc's hidden matter) |
| Hạc (major) | Đá Trắng | Stops Kha touching the still water | You see it | Explain the water |
| Nhạn (major) | Village | Separates raider signs from Silence signs | Your answer is a source in her report | Turn her report into an accusation |
| Yên Dao, Dương Sắt, Stone-Matron Lệ Thạch, Tấn, Bạc Sơn, Mẹ Lửa (major) | Two Heights, village | Bargain, refuse, sign, withhold, refuse the revenge oath (canon) | Hand on the survey; carrier; witness at the oath | Make the bargain for them; expose Tấn |
| An Tâm, Vệ (POV, major) | Your elder's rite; the Act 4 hearing | Relief party rite; Vệ tests her recollection; she refuses a consultation before witnesses | Supply the names; answer Vệ's check; witness the refusal | Learn about the eighth voice; consult through her |
| Father Từ (major) | Ancestor-Bound start | Guides An's first tests | A neighbor house's teacher, seen | Show his later coercion early |
| Linh Hải, Bảo (POV, major) | Capital, convoy, north | Measures; restricts the harbor; the convoy; ordered north; Bảo keeps the duplicate | Hand or pilot; your times in Bảo's copy; witness at her hearing | Be her investigator; prove the conspiracy |
| Lạc Thiên (major) | Capital (variant F) | Lawful review; helps secure Linh a hearing | Petitioner | Reveal the emperor's files |
| Lady Minh Nguyệt (major non-POV) | Capital, unseen | Moves a sealed report; arranges witnesses; supports Vân's return as stabilizing | One of the arranged witnesses | Learn it was her |
| Vân Cổ (midpoint) | The column or the honor | Genuine rescue; accepts the honor; asks for access to old service works | Rescued; spoken to; may overhear the request | Show any sinister sign |
| Ruk-Khan, Kor-Va, Sha-Ra (POV, major, off-page) | The burn, the mooring, the clinic | Burn, interrogate, move prisoners, seek a record; Kor-Va disputes timing; Sha-Ra records both sides | Boat-hand; patient's kin; negotiator | Learn the seal; see Mok-Ra's verse |
| Trần Hổ (major) | North, as news and soldiers | Punitive arrests | Their consequence | A personal duel |
| Phạm Dực, Cao Nhân, Trần Yên, Trần Cảnh, Lạc Vĩnh | Decrees, notices, clerks | Their Book 1 actions, felt as paperwork | Read the notices | Meet them |
| Bùi Khánh (major) | Archive side room (side quest, #31) | Finds a duplicated seasonal district | Return a reed flute's owner's name | Solve the district |
| Lạc Minh (major) | Capital relief ceremony | Volunteers and is given a ceremonial post | Crowd | Be his confidant |
| Mai Sương, Sira-Khan, Nara, Tạc (off-page or seeded) | Optional glimpses only | Mai checks passes at a coastal post; Sira's report is read aloud; Nara's refusal is felt as absent licenses; Tạc copies diagrams | At most a passing moment | Drive any Book I event |
| White Stag (appearance) | The north, Act 1 or Act 4 | Seen near a disturbed boundary; two witnesses disagree on its direction | You are one of the two witnesses; the Account keeps both | Confirm a prophecy |
| Grandmother Reed; the Root Mother; the Drowned King | Riverborn landing; Mộc Tinh grove; a disputed verse | A failed response; unanswered offerings; a title in a warning verse | The loss and myth seeds | Appear, speak, return |

---

## 6. The player's own small power

### 6.1 What an art is in the world

An art is a **tradition with teachers and places**. The bible's limit 1 says magic needs "an actual relationship or
recognized pact, a trained practitioner, and the relevant setting". It is not a bloodline (D03, D12). The owner's mapping
gives each people a home art: water for Dragon-Sea and Riverborn, earth for Stone and Mountain, later fox-fire for Hồ
Tinh and wood for Mộc Tinh. Floodborn and Ancestor-Bound are covered in 6.4.

### 6.2 What you can learn, and from whom

| When | You have | From |
|---|---|---|
| Start | Two household moves (Tidebreak's LMB Jab and E Guard, under the art's own names) | Your home |
| Act 1 | +1 move (Strike) | Your first teacher (table 2.2) |
| Act 2 | +1 move (Push or Dash) | A teacher on the road (the aunt or Nhàn, Cutter Sen, Diver Hà, Mộc Chi, Sương Hồ...) |
| Act 3 | +1 move (Wall), or **one move of another people's art** if a teacher accepts you and you take its obligation | Har-Kel, a Stone mason, a Riverborn diver... |
| End of Book I | About 5 of the 7 open-world moves; the rest in Book II | |

Body facts are real limits, not class locks. A Stone Child's dense body sinks, so water moves that need swimming are
harder. Riverborn need moisture on dry roads. Hồ Tinh shapeshifting is bodily and only Hồ Tinh have it. Healing in the
story is **medicine** (Sha-Ra's Marsh Medicine, bandages, poultices), not an art. The art Heal stays in the ring.

### 6.3 The costs (none touch speed or aim)

1. **Material.** The art needs its material nearby: water, ground, stone, living roots, a flame. Tidebreak already works
   this way (water from pools).
2. **Place bonds: power weakens away from home.** In your home region all your moves work. Elsewhere only the two
   household moves work, until you make a **bond** at a local bond-site (a landing, a waystone, a shrine, a grove marker,
   a guild door) with an offering and an obligation. Plan 6 to 10 bond-sites per region. This makes the rule a map you
   build by being a good neighbor, not a stat penalty.
3. **Obligations, as named debts in the Account.** A landing asks you to bring back a drowned person's name. A waystone
   asks you to carry the next cairn's message. A guild asks you to sign your work, with no lie in it. A grove asks you to
   water a sapling and not to cut. If a debt goes unpaid past its date, that place stops answering (your moves there
   close) and the locals know.
4. **Consent.** Some places forbid drawing: a Riverborn nursery channel, a grove's heartwood. Drawing anyway works once,
   harms the place (a nursery's flow, a tree) and brings that council's judgement. These are mission-level stakes, not a
   meter.
5. **Lock time**, as in Tidebreak (hold, fill, release). This is the only "limit" on casting.

### 6.4 The special cases

- **Ancestor-Bound: consultation, no combat art.** "Borrowed memory is not trained muscle" (07 limit 5). At a shrine, after
  rest, you can ask a voice one question in its domain: a name, a route, a joint-mark. The answer goes in the Account as
  *testimony: unverified* and is sometimes wrong. Overuse costs **Identity Strain**: you lose small ordinary things (your
  kin notices you forgot their nickname, and a journal line blurs). It never affects your controls. You fight with an
  ordinary staff, spear or knife, which keeps the bible's rule intact.
- **Hồ Tinh: Borrowed Face.** It changes appearance only. You can pass a checkpoint or enter a room. It fails with people who
  know the person, and the strain needs rest at a hearth with someone who knows your true name (an anchor NPC). Fox-fire
  as the art: owner to settle (section 10).
- **Mộc Tinh: the grove's permission.** "Travel decisions are made with the grove that sustains the traveler." You leave
  carrying a cutting. Away from Lâm Uyên your wood art depends on bonds, as above, and drought or fire are physical
  threats to you.
- **Floodborn.** Body strengths (submersion, strength) are real, and so are the limits: dry marches damage skin and cold
  slows them (P04). As a *body state*, cold or dryness must not slow the player's movement or aim (owner rule). Show it
  as damage over time and a need to wet or warm the skin instead. The Floodborn art is an owner decision.
- **Unbound** (an option for any human start): no art, more trade and relationship options. D03 says unbound humans exist.

### 6.5 Names on screen

Arts are named by relationship and craft, not by element nations. Proposals: *Current Reading*, *Net-Water*, *Stone
Hearing*, *Waystone Craft*, *Root Grip*, *Lantern Fire*, *Consultation*, *Borrowed Face*. Tidebreak's internal move
names need a player-facing pass before they appear in the world. "Air Scooter", "redirect lightning" and "bending" are
show-adjacent; owned by the arts and Tidebreak plan.

### 6.6 Tidebreak in Book I

It is a festival sport of arts under rules. The ring deck carries every material (pools, slabs, roots, lanterns), so the
**full kit** works for everyone in the ring. That is why the ring is the place to play an art at full strength, and the
open world is not. Book I circuit: the Vạn Thủy lock-basin deck at the Seventh Tide festival (#1); the Thạch Uyên terrace
court; a Reed Marches mooring platform; optionally a highland oath-gathering field. Prizes are coin, a captain's passage
bet (an Act 2 route), standing, and a teacher's notice (one move learned early). In month 5 the Vạn Thủy ring is closed by
decree. It is the first visible sign of the war.

---

## 7. Side content from the 32 stories

Q = side quest (playable). M = living-world moment (ambient scene, festival, barks). V = vista (a framed spot; also an art
review target from the story's paint cues). L = later book. Stories #1, #4, #7, #13, #19, #22 and #24 are used as Prologue
rites (section 2.2) and are also Ms in free roam.

| # | Story | Use | Notes |
|---|---|---|---|
| 1 | Lantern Nets on the Seventh Tide | Rite, M, V | Seventh Tide festival in Vạn Thủy, also the Tidebreak festival |
| 2 | The Man Who Counted Bridges | **Q** (capital) | Pins pulled from East Heron Bridge; follow the saboteur; ordinary graft (repairs delayed for profit), not the mystery |
| 3 | Salt Under the Seal | Q (southern provinces, optional) | A widow whose husband was levied; the toy boat |
| 4 | The Rope Across First Snow | Rite, V | |
| 5 | Smoke in Goat Pass | **Main 2.2** | Plants Tấn without naming him |
| 6 | The Weight of His Brother's Bow | M, Q (north) | Teach a boy the bow; a grief that becomes a tool again |
| 7 | Feast of the First Chisel | Rite, M, V | The lead in the story is canon Tạc as a teen. In the game he is 28 (C36) and present as an adult apprentice. Not the kin. |
| 8 | The Noise Inside the Wall | **Q** (north-west), V | A concealed maintenance channel with bone prayer tags: a Book I plant ("royal renovation conceals repair joints", L02). Unexplained. |
| 9 | The Quarry That Spoke Back | Q, V | Old Cutter Sen, a Stone teacher |
| 10 | Red Fan at Rain Market | M, V | Hồ Tinh start's market; a small romance thread |
| 11 | The Debt with No Name | L (Book II) | Bạch's own story; he is off-page in Book I (C12) |
| 12 | A Tail Left in the Ashes | Q (Hồ Tinh) | "Find him first." A search through contracts |
| 13 | White Blossoms at Drought End | Rite, V | Drought end = early rains = the Silence season |
| 14 | The Root That Would Not Let Go | **Q** (Mộc Tinh, or anyone at the grove edge) | Brace a split sapling; leave water and fungus cakes: a bond-site obligation |
| 15 | Rings of Fire | M, V; L for the named elder | The story names the Root Mother "Kha Mộc", which conflicts: V3 has no personal name, and she is off-page in Book I. Use an unnamed elder spirit. |
| 16 | Lotus Night Under the Bridge | V; L (Book II) | Nara is off-page in Book I; keep the place, not her |
| 17 | The Current with Two Shadows | **Q** (Riverborn) | The handprint "worse than the dead" stays unexplained; it fits the Book I mystery line |
| 18 | The Diver Who Heard Her Mother | Q, M | An ancestral voice in water; Lụa is a teacher |
| 19 | The Last Reed Boat | Rite, **Main 3.3** | |
| 20 | Blackwater Wedding Spears | Q (marshes) | Sira-Khan is off-page in Book I: an ordinary Floodborn escort leads the procession and Sira is only mentioned |
| 21 | Mud on the Threshold | **Main 3.4** | Sha-Ra's clinic |
| 22 | Paper Windows for the Dead | Rite, M, V | Young An Tâm in the story is backstory; your own house does the rite |
| 23 | The Fourth Voice in the Shrine | Q (Ancestor-Bound), **recast** | Conflict: the story's novice "Vệ" hears voices, but V3 makes Vệ **unbound** (C41, D03). Recast as an unnamed novice. The voice's "to be remembered correctly" is strong; keep the voice unidentified (Liên Khởi is a Book III reveal). |
| 24 | The Tea Cup Her Grandmother Held | Rite, M | "And less ginger next time." |
| 25 | Market at Low Water | **Act 1 capital**, M, V | Low water out of season is the Silence felt downstream |
| 26 | The Boy Who Sold Rain Eels | Q (a selling errand), M | |
| 27 | Crossing at Khe Lan Ferry | **Main 4.2**, V | Proposed as the Act 4 station |
| 28 | The Barber of Vạn Thủy | Contact, M | A GTA-style rumor contact who reads the realm by the hair around men's ears |
| 29 | During the Monsoon Ceasefire | L (Book II) | It needs the war |
| 30 | Bride Price at the Stone Steps | Q, and a teacher | Aunt Hảo teaches bargaining terms (a skill for 2.1 and 3.5) |
| 31 | The Reed Flute in the Archive | **Q** (capital) | "Scholar Khánh" looks like Bùi Khánh (C29); confirm. The flute's owner was a marsh child; a Book I-safe archive scene. |
| 32 | Winter Rice at the Burned Shrine | L (Book II) | Rebuilding after war burnings |
| seeds | Storm Tax at Heron Ford; Three Bowls of Festival Soup; Dry Season Chess on the Canal Wall... | M | Ambient scenes; Dry Season Chess fits Book II |

Two more possible duplicates to confirm: **Scout Nhàn** (#5) and canon **Nhạn** (C32, scout trainer), and **Mason Lệ Vân**
(#8) and Stone-Matron **Lệ Thạch** (C35, house naming).

**Vistas** (twelve review shots, each from a story's paint cues): the stopped reach at Đá Trắng; the lantern-net canal at
night; the Two Heights pier with two maker signs; first snow on the cliff rope; the chisel feast terraces; the quarry
cairn in fog; the rain market under awnings; lotus halls from below; the burial reed boat in mist; the clinic threshold;
the paper-window lane; Khe Lan Ferry in storm, before and after.

---

## 8. The old main-story ideas, mapped

| Old idea (memory notes / main_story.md) | Fits Thủy Vân? | Where it lands |
|---|---|---|
| The creator makes the parents; you play one and teach the child (v6) | **Yes** | The Prologue. You plus an optional hearth-mate; the kin from `ChildLook`; teaching = tutorial; the bond count. |
| The POV switches to the child at the great kill (v6) | **No, not in Book I** | Book I is five months. The bible forbids skill or age jumps across them, and a 10-year-old lead cannot carry its travel and bargains. Owner option: in a Book II storyline, play the grown kin. |
| The mammoth | **No** | The "great kill" becomes the people's coming-of-age rite. Trường Sơn's herds, and the White Stag as sacred, not prey. |
| The raid party, then the sky cracks; pirates kill all; the parents die abruptly; the child is kidnapped (v6) | **Partly** | "Taken" becomes the levy plus the burned dig. "Die abruptly" becomes the elder lost at the Silence, the lock surge or the burn: off-screen, final, a rite without a body (owner to confirm, section 10). **Pirates do not fit.** In Thủy Vân "pirates" is the empire's propaganda label for Floodborn moorings (H17 "anti-piracy"). Making pirates the villains would repeat the lie the bible criticizes. The game uses the label only on imperial notices, as a claim. |
| Keelstone, sky galleons, the sky crack, the Edge Chronicles, the Treasure Planet 70/30 | **No** | Thủy Vân has no sky ships. The wonder layer is the world itself (the peoples, Ảo Thành, the lotus halls). Retire `SkyBattle`, `WreckFall`, `RookWalk`, the wonder sky and the galleon to git history. |
| The Downbelow | **No** | It was the sky-folk's word for the ground world. The task's suggested mapping, the Buried Kingdom, does not fit Book I: objects emerge in I, the entrance opens in II, and it is explored in III (L14). Use it for a Book II/III chapter under its own name. Drop "Downbelow" (it also collides with Cherryh's *Downbelow Station*). |
| Rook, the mentor who uses you | **Partly** | Book I cannot show Vân Cổ's turn. The "trusted person who used you" appears at small scale: the masked porter's packet (you were a pawn of Minh's network, a cost you only half see), and Tấn's leaked route (unidentified until Book III). |
| The Reed Campaign | **As memory** | It happened 20 years ago (H17). It lives in the moorings missing from maps, Ruk's eye, Har-Kel's and Urok's recitations, and side quests that restore a mooring's name. It is not a playable flashback (it would need a POV that Book I's knowledge rules do not give). |
| The Ash Coast | **Book II** | The coast is not yet "ash" in Book I (it was named after successive port burnings, II+). In Book I it can appear as threatened fishing villages, with Mai's company on routine duty as an optional glimpse. |
| GTA framework: contacts, free roam, missions as data, reputation per community, joining communities, witnesses instead of a wanted meter | **Yes, it fits better than before** | The bible's "power is divisible" means reputation per institution (each clan, each Stone House, each mooring, channel councils, Hồ Tinh courts, groves, ancestor houses, magistrates, the navy). It spreads only through witnesses and at courier speed: "a coalition meeting is not universal world knowledge". Each institution has its own justice (a magistrate's warrant, mooring oral law, a clan feud, a contract breach, a guild ban). |
| "All text" | **Yes** | English text, with names in Vietnamese plus English titles ("Vạn Thủy, Capital of the Waters"). |
| Two Fires code | **The engine stays; the content retires** | Keep `StoryDirector`, `StoryObjectives`, `StoryDialogue` (choices with conditions), `StoryContact`, `StoryBark`, `StoryWalker`, `StoryEffects`, `StoryHUD`. Reuse `RaidStage`'s pattern for the burn and `Captivity`/`MarchStage` for the levy and the prison barge. Retire `data/story/*/two_fires.json` and the sky pieces. |

---

## 9. What it takes (honest effort)

### 9.1 Systems

| Piece | State | Effort |
|---|---|---|
| Storyline pack `data/story/{storylines,missions,dialogue}/thuy_van_book1.json` | Format built | Data per mission; see writing |
| The Account (seen / told / can show / owe / names; sources and confidence; contradictions side by side) | NEW | M |
| Reputation per institution, spread by witnesses at courier speed | NEW (`npc_brain` only has witnesses) | L |
| Passage screen with the calendar and the travel windows (days, food, closures) | NEW (Two Fires planned a 2D travel map) | M |
| Kin as a story person (teen growth stage, follow, anchor sign, memory gap, final choice) | `ChildLook`, `ChildProportion`, `StoryWalker`, `Household` | S-M |
| "Kin copies a task" (teaching) | NEW | M |
| Essential canon NPCs and institutional justice | NEW rule on existing NPCs | S-M |
| Arts in the open world (the Tidebreak layout outside the ring; learned-move list) | Tidebreak is ring and duel only | L (shared with the arts plan) |
| Bond-sites and obligations | NEW | M |
| Consultation (Ancestor-Bound), Borrowed Face (Hồ Tinh) | NEW | M each |
| Set pieces: the Silence (stopped water, suspended fish, held boats, mist that holds) | NEW | L |
| The burn (fire on stilts, prisoners, boats) | `RaidStage` pattern, fire | M |
| The Return (a column under threat, a planned retreat, many soldiers) | `NpcSquad`/`NpcFighter` exist | L |
| The Khe Lan failure (piers fail, a crowd, water) | NEW destruction | L |
| The hearing (crowd, testimony, decree) | `StoryDialogue` | M |
| Rite set pieces x8 | NEW | M each (L total) |
| Tidebreak festival circuit in the world | Ring built | M |
| Fonts with Vietnamese diacritics in all UI and dialogue | Check | S |

### 9.2 Writing (all English text, owner-reviewed for canon)

About 56 main-mission builds: Prologue 5 steps x 8 peoples on one template (13 unique builds); Act 1, 4 variants x 5 =
20; Act 2, about 10; Act 3, 2 variants, about 11; Act 4, about 6. Add about 18 side quests. That is roughly 35-45 thousand
words of dialogue and notices. **XL.** Every scene needs the canon check in section 5 before it ships.

### 9.3 Dependencies on the other parts of the plan

- **World:** region A (the Đá Trắng reach, the foothill village, the pack trail, Khe Lan, the shrine hill, the Two Heights
  approach), region B (a Vạn Thủy slice: one canal district, the grain piers, a lock, the archive island's outside, the
  naval basin, the ring deck), region C (the toll corridor at the delta-marsh edge, the dig, a mooring, the clinic), and
  four start pockets (Thạch Uyên terrace, Lâm Uyên outer grove, Deep Lotus pilot dock, Rain Market). **XL.**
- **Bodies and clothes:** five human-bodied peoples first (Dragon-Sea, Mountain, Stone, Riverborn, Ancestor-Bound: body
  materials and props); then Hồ Tinh (ears, tails) and Mộc Tinh (wood skin, vines); then **Floodborn** (a new body: snout,
  tail, clawed feet; every clip retargeted). Floodborn alone is **XL**.
- **Animation (own clips only, AI-assisted Blender authoring, per AGENTS.md and animations/SOURCE.md):** about 15 new clips
  (tie knots, tap a chisel, rope crossing, bind reeds, raise a net, trim paper, gather petals, a held dive, carry a pole,
  hold rods, kneel at a rite, say the names, bow, pole a boat, hand over a token). **M-L.**
- **Music:** the existing pipeline (tools/music, VSCO 2 CE, 432 Hz) takes the new cues: the Silence (a held, still cue),
  each people's rite, the Return, the hearing. **M.**
- **Arts and Tidebreak:** open-world arts and renamed moves come from the arts plan.

### 9.4 Build order (vertical slice first)

1. **Slice: Mountain Folk.** Prologue (rope rite), Act 1 north river (the Silence, the loss, An's relief rite), 2.1 Two
   Heights. That is about 11 missions on part of region A, plus the Account v1 and the kin. **L** with world art. It is the
   best first test: a human body, the most canon cast on stage, and the hook scene.
2. Dragon-Sea start and the capital Act 1 and 2 (region B slice), then the convoy (2.5).
3. Act 3 variant H (region C), then Act 4 (Khe Lan) and the ending. **The game is completable here for 2 peoples.**
4. Ancestor-Bound, Stone, Riverborn starts (human bodies). Then Hồ Tinh and Mộc Tinh. Then Floodborn with Act 1 South and
   Act 3 variant F.
5. Side quests, the Tidebreak circuit, the post-ending layer.

**Review images for the owner at each step:** the kin lineup per people (A/B/C looks); the Silence reach in 3 variants
(how still, how much mist, how visible the hands); each rite as a still; the Two Heights pier signs; the Account UI as
paper-ledger mockups (2-3 styles); Vân Cổ lineup (humane, never villain-coded); the dig before and after the burn; Khe
Lan before and after; contact sheets of every new clip. Story beats are shown as storyboards first (the twelve vistas plus
one frame per main mission), so the owner judges the story by eye before missions are built.

---

## 10. Owner questions

1. **The hook:** the kin (default your child, counted at 15-16) levied for river works and sent to the dig Ruk burns. OK?
   Other default relations?
2. **The loss:** an elder lost at the Silence, the lock surge or the burn (off-screen, final, a rite without a body). Keep,
   soften, or cut?
3. **The POV switch** from v6: drop for Book I (recommended), or plan a Book II that plays the grown kin?
4. **Should the kin always survive Book I** (recommended: yes, changed, with a memory gap and their own choice at the end)?
5. **Proposals that touch canon:** the Heron Shrine dig (name and place: on the toll corridor at the delta-marsh edge, so
   Linh's convoy can observe it); Khe Lan Ferry as the destroyed station; the Mountain start in Kha's own village; Nara's
   refused assignment passing to a Riverborn kin; the threatened force Vân Cổ rescues being a column the player hauls with;
   the player as one of Minh's arranged witnesses and as a witness to An's refusal. Approve or adjust each.
6. **Arts across peoples:** learnable from teachers with body limits (recommended, since peoples are not classes), or
   locked to the home people?
7. **The Floodborn art** (marsh water? mud? none?), **fox-fire for Hồ Tinh** (from Tidebreak's fire kit?), and **who gets the
   fire and air kits** outside Hồ Tinh?
8. **Ancestor-Bound with consultation only and no combat art.** OK?
9. **The vertical slice people:** Mountain Folk (recommended)?
10. **The map:** hide the Ninth River legend and the Convergence label in game; show the imperial map's nine districts with a
    duplicated name as Bùi's clue?
11. **Story-file conflicts:** #23's novice Vệ hears voices but C41 is unbound; #15 names the Root Mother "Kha Mộc";
    "Scholar Khánh" (#31) vs Bùi Khánh; Scout Nhàn (#5) vs Nhạn (C32). Which wins?
12. **Title:** use "The River That Would Not Move" for the game's Book I?
13. **Off-page cast** (Mai, Sira, Nara): allow a passing glimpse in the game, or keep them strictly unseen until Book II?
