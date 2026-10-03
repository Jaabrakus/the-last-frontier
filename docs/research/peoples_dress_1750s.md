<!-- peoples' dress research: six regional reports, the Woodlands note and the costume critic, merged 2026-10-03 -->

# Everyday dress of the 35 peoples, c. 1750–1765, for the cloth2 garments

The owner wants "garments each race would have worn in that time period". This file merges seven pieces of research:

- six regional reports: Europe, Africa, East Asia, South and Southeast Asia, the Middle East and North Africa, and a note on the Eastern Woodlands and mixed-ancestry peoples;
- a costume historian's review of all six.

The corrections from that review are applied throughout. The project was only read: this is the only file written.

This file is a build spec for the cloth2 pipeline (`tools/character/cloth2/`). It does not promise that every garment ships.

## 1. Scope, rules and conventions

### 1.1 Scope and rules

- **Period:** 1750–1765. Sources from outside these years are marked, and their certainty is lowered.
- **Who:** every people in `assets/character/body/peoples.json` (35). Each people gets:
  - men's everyday dress (3–6 garments);
  - women's everyday dress (3–6 garments);
  - one better-off outfit for each.
- **Ordinary people first:** a farmer, a labourer, an artisan, a townswoman, and only then the better-off. Each section ends with the clichés and anachronisms to avoid.
- **Religious, ceremonial, office and regalia items** are listed under "Noted, not playable" in each section. They are never free picks. A few can become playable later, but only with care: a story role, an office, or a review.
- **Body practices** (tattoo, henna, kohl, nose rings, face paint) belong to the body, not the wardrobe. They are noted only.
- **Sumptuary laws** (colours imposed on non-Muslims, Qing imperial yellow, Joseon yangban privileges) can be offered as historical presets. The game never enforces them, and gives them no gameplay meaning.
- **One garment per slot.** The outfits follow the `PlayerOutfit` slots. Where a report put two garments in one slot, I moved one and say so in the row.

### 1.2 Conventions

**Heights and positions**
- **Heights:** z in metres on the cloth2 reference fit. This is the female base, about 1.60 m tall; the male fit is about 1.64 m. For a 1.71 m adult, multiply by about 1.07.
- **Landmarks:**

  | Landmark | z (m) |
  |---|---|
  | hat band plane | 1.545 |
  | shoulder top | ~1.40 |
  | neck root | 1.33 |
  | armpit | ~1.22 |
  | under the bust | ~1.16 |
  | waist | 1.02 |
  | hip | 0.93 |
  | crotch | ~0.80 |
  | mid-thigh | ~0.68 |
  | knee | 0.47 |
  | mid-calf | ~0.27 |
  | ankle | 0.08 |
- **Limbs:** t runs from 0 at the shoulder or hip to 1 at the wrist or ankle. The elbow is at about t 0.5.
- **Angles** round the body run from 0° at the front to 180° at the back, the same on both sides. +x is the wearer's left.

**Layers**
- Layers are `spec.LAYERS`: base 10, mid 20, legwear 30, tails 35, outer 40, wrap 50, belts 60, head 80, ornaments 85.
- An in-between number is used where an ensemble needs one: 36 for a long inner robe over trousers, 38 for a sash over that robe.
- `{20, hips 35}` means 20 by default and 35 on the hips region.

**Ids**
- All ids are snake_case.
- An **unprefixed** id is shared by several peoples and built once.
- An id **prefixed** with the people id (`japanese_`, `chinese_` and so on) is unique to that people.
- (x) marks an existing cloth2 garment (lib 2). (r) marks an existing lib-1 id to rebuild on cloth2, rather than adding a new id.

**Styles and presets**
- A **style** is a second mesh from the same recipe, with a few keys changed.
- A **preset** is the same mesh in other colours or cloth.
- Every cut serves both sexes: cloth2 builds a cut once and replays it on the male fit and the bust gauge (`garment.py`). A separate men's and women's id exists only where the cut differs.

**Colours**
- Colour names are tokens in `tools/character/cloth2/palette.json`.
- A token marked * is new (§2.5).

**Certainty**

| Mark | Meaning | Catalog grade (rough) |
|---|---|---|
| H | A period eyewitness or a dated object from 1740–1770 agrees. | A |
| M | The witness is 20–70 years off, or the source is a scholarly summary. | B |
| L | Later evidence, or inference. Ship with the "(artistic licence)" note. | C |

- † marks the reporter's background knowledge, not re-checked this session.
- The web-search budget (200) ran out in every track. Later checks were made by fetching known pages, or by reading primary texts already downloaded.

**Sources**
- A key in brackets, such as [EU-K1], links to its entry in §7.
- (x) and (r) garments keep the sources already in their catalog entries.

### 1.3 The consultation hold

The project's rule (`docs/main_story.md` §10.8): ask each office for its list of what is off-limits before anything is written. Review is paid and consultants are credited.

- **haudenosaunee, lenape, shawnee, wabanaki: no garments are designed here.** Their sections list:
  - the offices to consult;
  - the state of the existing Eastern Woodlands set (17 `ew_*` items, lib 1, not offered today);
  - the open discrepancies.
- **metis and afro_native:** no people-specific garments. They take the colonial set and the plain trade goods (§3.3) now. The sash and capot carry no "Métis" label.
- **pacific_islander: every item is held.** The critic gates Māori and Hawaiian garments (the everyday pākē and kīhei included) and tapa/kapa motifs. I extended the gate to the whole people. The Society Islands research is kept as candidates to bring to review. The Pacific offices are not yet identified.
- **Regalia and office pieces** in every section are built only for a story role, never as free picks.

### 1.4 Project facts to fix before any of these sets ships

1. **No filter by people.** `PlayerOutfit.offered()` (`scripts/customizer/player_outfit.gd`, line 139 on) filters by slot and by the men/women tag only. Once any set reaches lib 2, every one of the 35 peoples is offered it.
   - Add a `peoples` field to catalog entries and filter on it.
   - Add a review gate that reads the catalog `review` string, which nothing reads today. It must hide the Woodlands, Pacific and regalia items until signed off.
2. **BASIC is chosen by body type only.** `BASIC` (`player_outfit.gd`, line 31) dresses every people in European linen under their own clothes. Make it per people. Each section below gives a **Basic** line.
   - In the 1757 valley, anyone born or living in the colonies dresses from the colonial set. The homeland basics are for:
     - origin choices;
     - flashbacks;
     - the shore-folk of Vessary.
3. **Slots.**
   - `SLOTS` (line 24) lacks `accessories.shoulder`, `accessories.arms` and `accessories.ears_nose`. The catalog defines all three. `rigging_harness` (lib 2, `accessories.shoulder`) cannot be picked today.
   - Proposed new slots:
     - `accessories.head` (layer 82): a veil over a cap. Until it exists, a cap and its veil are one garment.
     - `accessories.face`: face veils, with care only.
4. **Closed garments.** Add the tag `pants` (`CLOSED_TAGS`, line 42) to every pair of trousers, drawers, hakama and loincloth. Wrap skirts and robes are not closed.
5. **Recipe gaps.**
   - `recipes.shirt()` always cuts at 0.905, so it needs a `bottom=` argument.
   - `coat()` cannot make side slits, so it must pass `slits` through to `tails`.
   - `shirt()` needs a neckline-slit angle for the Persian left-shoulder opening.
6. **Patterns do not render yet.** The cloth shader does not draw zone patterns: the apron's `pattern_note` says a check apron renders in its base colour. Checks, stripes, strip seams, prints, ikat and setts all wait on this.
7. **Deny-list.**
   - `DENY_TERMS` (`tools/character/lib/catalog.py`, line 43) already blocks "chiefs", "pipes", "tribal" and "eagles". Catalog copy taken from this file must be reworded: "tobacco pouch", not "pipe"; "headman", not "chief".
   - Add "negro", "mulatto", "coolie", "oriental" and "harem", with an exception for quoted `history` text (critic).

### 1.5 Corrections applied

**From the critic**

*Dates and evidence*
- **Ceinture fléchée.** The first coloured sash on Canadiens is 1776 (Anbury), the chevron sash 1778, and the name 1798. No patterned sash is attested for 1750–65.
  - My own correction to the critic: the project's `sash_worsted` entry already cites d'Aleyrac, in Canada 1755–60, for "a sash around the capot". A plain sash in 1757 is therefore M, not M-L. The wording of the quote still needs checking.
- **Vietnamese edict of 1744:** it applied to the court. The southern dress change is M; the "pointed hat" clause is L-M. The northern outfit stays the default.
- **Edo sumptuary law:** "except tsumugi" is M. The better-off wife wears a plain outer with a rich lining.
- **Haori hem:** about 0.95–1.00 ("reaches only to the waist", Thunberg). 0.85 is a variant.
- **Persia:** the Hanway items are labelled "1740s"; the Zand cylindrical cap is the default.
- **Niebuhr's metal cone hat** (Syria) is H for the 1760s; the report's gap note is deleted.
- **`dutch_jak`:** M. The museum gives an alternative date of 1810–20.
- **Brunias:** 1765–96, mostly the 1770s–90s, idealised.

*Garments moved, merged or dropped*
- **Reuse existing ids:** `hunting_shirt` becomes the existing `hunting_shirt_tow` / `hunting_frock`.
- **`gown`** gets two front modes, stomacher and closed.
- **`frock_linen`:** a plain shirt-cut frock, with no yoke and no collar.
- **The bedgown** is for the homeland; colonial use before 1765 is L.
- **Highland dress** moves out of scots_irish (§4.2a).
- **Spanish:** no maja trimmings, the montera is L, and Florida takes the colonial set plus the capa.
- **Dropped:** `palatine_cap_quilted`. Brogue drain holes are L.
- **Kongo `pelt_front`** goes to regalia. Ethiopian `cloak_pallium` is noted only. Bosman's deerskin cap with coral marks an office.
- **Ethiopia:** Muslim men wear a cap and turban. The women's kamis is M-L.
- **Korea:** the manggeon goes into a new `hair_sangtu`, not into the shared `hair_topknot`.
- **China:** no all-white outer dress (white reads as mourning). `changshan` is renamed `changpao`. No class rule on foot binding.
- **Cone hats:** a separate profile for each people. Never "coolie hat".
- **Vietnam:** a wound khăn vấn band replaces the `khan_dong`.
- **Thai:** the details are M, because La Loubère wrote 65–75 years early.

*Naming and with-care notes*
- **african_american:** M until the New York and New Jersey ads are read. The New York cloth names replace the Chesapeake terms. Racial terms stay out of ids, names and tokens.
- **Kamon:** generic or invented marks only.
- **South Asia:** the Sikh dastar is not the generic pagri. The jama's tie side is a choice, never inferred.
- **Malay:** a care note on the kris.
- **MENA:**
  - unveiled townswomen outdoors are the game's choice, so they carry a grade C note;
  - the kolah-e naderi has a Sunni religious-political meaning;
  - suggested UI label "Moroccan (towns)" for moorish.
- **Pacific:** under consultation.
- **Palette:** the duplicate tokens are merged.

**My own corrections**

- **One garment per slot:**
  - `kurk_fur` moves to `accessories.wrap`;
  - the Ottoman better-off man wears either the kaftan or the jubba;
  - the Korean women's jacket is layered over the skirt band;
  - the Malay sarong worn over drawers uses `alt_slots` `accessories.waist`.
- **Palette merges checked against `palette.json`:**
  - "indigo_dark" is the existing `stroud_blue` (#1E2B4A);
  - "morocco_red" is `madder_red` (#8E2B21);
  - "morocco_yellow" and "isparek_yellow" are `yellow` (#D0A93A);
  - the existing `orange` (#C0632A) is not saffron, so saffron gets its own token.
- **Shared wrappers:** cloth wrappers are shared meshes across West and Central Africa, Yemen, South Asia, Malaya, Thailand and Vietnam. They are plain rectangles, told apart by presets. Hats, collars and robes stay people-specific.

## 2. New recipe types, merged

Existing types in `cloth2.recipes`: coat (with the COAT, FROCK, JACKET and CAPOT styles), jacket, capot, waistcoat, apron, neckwear, soft_cap, rigid_hat, leggings, belt, sash, harness, pouch_belt and shirt. The six reports proposed about 40 new types; the critic merged them into the 16 below.

### 2.1 New types

| # | Type | What it is: modes and keys | Built from | Garments that need it |
|---|---|---|---|---|
| T1 | **`gown`** | A fitted bodice with a floor-length skirt. Front: `stomacher` (the open robe pinned to a stomacher) or `closed` (edge to edge). Back: fitted or `sack` (box pleats from the neck). Optional sleeve flounces. | `recipes.jacket` bodice plus a skirt weighted from the petticoat (`settlers.weights_from`, `closed_skirt_weights`) | `gown_open`, `gown_sack`, `gown_close_bodied` |
| T2 | **`robe`** | One long-robe type with four front modes: `crossed` (left over right), `side_fastened` (neck to right armpit, then down the side), `under_arm` (the jama crossover) and `open` (edge to edge). Shared options: split fronts with closed-skirt back weights, side slits, a high waist seam, a hanging-sleeve fin, sleeves past the wrist (`trims.extrude`), a raised collar band, and ties or toggles. | `coat()` torso and sleeves + a new `overlap_line` polyline + `fin` + `skirt_hang` | `japanese_kosode` (and its styles), `japanese_haori`, `korean_jeogori_mens`, `korean_jeogori_womens`, `korean_juui`, `korean_dopo`, `chinese_duanshan`, `chinese_ao`, `chinese_changpao`, `vietnamese_ao_giao_linh`, `vietnamese_ao_ngu_than`, `vietnamese_ao_tu_than`, `south_asian_jama`, `south_asian_angarkha`, `south_asian_peshwaz`, `entari`, `entari_womens`, `persian_qaba`, `jubba` (styles binish, dulaman), `kurk_fur`, `ottoman_ferace`, `ottoman_kaftan`, `moorish_qaftan`, `kurdish_shalloon_coat`, `malay_baju_panjang` |
| T3 | **`tunic`** | An unfitted T-shaped garment pulled on over the head. Keys: neck-slit depth, wide open sleeves, side slits, sleeveless armholes, an optional hood, and a closed skirt down to the hem. | `shirt()` shell and sleeves + the petticoat's closed skirt + `hood.hood_on_back` | `west_african_tunic`, `west_african_robe`, `ethiopian_kamis`, `ethiopian_vest_long`, `thawb`, `thob_womens`, `qashshaba`, `north_african_jillebba`, `egyptian_tob_sebleh` |
| T4 | **`bodice`** | A short fitted top: covers the front, with short sleeves, back ties, and a hem at 1.15–1.17 or 0.92. A `panel` kind is a front-only diamond on strings. | torso + arm shell, `strap()`; `select` for the panel | `south_asian_choli`, `malay_bodice`, `vietnamese_yem` |
| T5 | **`wrap_skirt`** | One wrapped or tube skirt. Keys: top (waist 1.03, navel 1.06, armpit 1.23, or a pinned top at 1.30), hem, flare, overlap angle and fold edge, rolled band (raised 0.004–0.006, zone 1), pleats or flat panels, wound layers (stepped rims), shoulder pins. | the petticoat's shell, tails and `closed_skirt_weights`, `g.skirt` entry + `skirt_hang.py` | `wrapper_knee`, `wrapper_calf`, `wrapper_long`, `wrapper_high`, `filipino_saya`, `filipino_tapis`, `korean_chima`, `chinese_mamianqun`, `south_asian_sari`, `draped_dress`; held: the Scots philabeg (§4.2a) and the Pacific pāreu / ʻahu |
| T6 | **`trousers`** | One trousers type. Keys: crotch drop 0.015–0.32, waist (band, drawstring, folded panel), and cuff (knee band, open slit, ankle band, tie, gathered fall, churidar ruching, footed). Kinds: `drawers`, `wide`, `breeches`, `hakama` (pleats, side openings, back board) and `draped` (dhoti and chong kraben: a wrapped cloth drawn between the legs). | `slops` / `breeches` ops: `legs()`, `crotch()`, `drift.flare_legs`, raised cuffs | `dutch_breeches_wide`, `spanish_calzon`, `west_african_trousers_wide`, `drawers_short`, `drawers_linen`, `salvar_mens` (styles narrow, knee, çakşır), `salvar_womens` (style shintiyan), `chinese_ku`, `korean_baji`, `japanese_momohiki`, `japanese_hakama`, `filipino_salawal`, `vietnamese_quan`, `south_asian_pyjama`, `south_asian_dhoti`, `thai_chong_kraben`; later the existing `breeches` and `slops` |
| T7 | **`loincloth`** | `band(0.98, 1.04)` + `strap()` from the front waist through the crotch to the back waist + a front-only flap. Tag `pants`. | straps, tails | `loincloth`. `ew_breechcloth` stays separate and under review. |
| T8 | **`drape`** | A rectangle of cloth on `drift.envelope`. Anchors: both shoulders, one shoulder, the breast, head-short, head-long, head-to-ankle, knotted, back-carry. Options: brooch, fringe, ends wound round the arms. | `drift.envelope` (the `cloak_hooded` method), `hats.head_grid` for the head anchors | `rebozo`, `mantle_one_shoulder`, `mantle_upper_wrap`, `mantle_back_carry`, `ethiopian_shamma`, `ethiopian_netela`, `south_asian_chadar`, `south_asian_odhni`, `south_asian_kashmir_shawl`, the sari's pallu, `thai_sabai`, `thai_pha_shoulder`, `malay_selendang`, `arab_shoulder_cloth`, `spanish_mantilla`, `wrap_drape_womens`, `haik_mens`, `kurdish_charokhia`, `head_kerchief`, `head_veil_long`, `keffiyeh`; held: the Scots plaids and tonnag, the Hawaiian kīhei |
| T9 | **`cloak`** | Generalises `cloak_hooded`, `sail_cloak` and `weather_cape`. Kinds: hooded, capelet, circle cape (the arms inside), square-shouldered `aba` (arm slits), fleece-lined. A `poncho` kind (head slit) is held. | `drift.envelope` + `hood.py` | `mantelet_hooded`, `cloak_long_hooded` (a `cloak_hooded` style), `spanish_capa`, `aba`, `burnous`, `kepenek`, `sheepskin_coat`, `ethiopian_tippet`; held: the tiputa and the Māori flax cloak |
| T10 | **`head_wrap`** | Cloth wound round the head. Kinds: `band` (crown bare), `kerchief` (whole head, knotted), `turban` (a helix of `hats.tube` rolls round a cap core), `tall`, `flat` (a cap bound high and flat) and `coil` (a cord or fillet). `hides_hair_zones` is set per kind. | `hats.head_grid`, `hats.tube`, `HW.ellipsoid` knots, strap ends | `head_band`, `head_tie`, `malay_destar`, `vietnamese_khan_van`, `south_asian_pagri`, `turban_common`, `turban_town`, `turban_sesh`, `turban_flat_womens`, `persian_kolah_shawl`, `kurdish_turban_fringed`, `moorish_head_wrap_womens`, `north_african_fillet` |
| T11 | **`sandal`** | A sole of straw, leather, a wood block or toothed wood (geta), with a thong, latchets, side loops or ankle cords. | `feet.sole`, `straps.strip` | `sandals_leather`, `japanese_waraji`, `japanese_zori`, `japanese_geta`, `korean_jipsin`, `chinese_straw_sandal`, `vietnamese_guoc`, `spanish_alpargatas` |
| T12 | **`slipper`** | A low closed shoe with no heel and no buckle. Options: backless; a pointed or upturned toe. | `feet.SockTube` (low top 0.05–0.07) + `sole()`; the `shoes_buckled` ops | `slippers_backless`, `south_asian_jutti`, `chinese_cloth_shoes`, `korean_taesahye` |
| T13 | **`rigid_shoe`** | A carved wooden shoe as rigid parts on each foot, worn over stockings. | `HW.lathe` / `box` | `wooden_shoes` (French and Dutch styles) |
| T14 | **`hand_cover`** | A shell over the forearm and hand: fingerless, with a thumb hole, a pointed flap over the back of the hand, or a finger loop. | arm shell, `strap()` | `mitts`, `japanese_tekko`, `korean_tosi` |

New kinds and profiles on existing types:

| On | New kinds / profiles | Garments |
|---|---|---|
| `soft_cap` | `skullcap` (plain; a gored-and-knot variant); `flat` (bonnet) and `fall` (kertch), both held; `montera` (L, optional). Lappets and chin strings on `womens`. | `skullcap`, `chinese_guapimao`, `ottoman_cap_womens`, `french_cornette`, `mutch`, `dutch_muts_oorijzer`, `spanish_montera` |
| `rigid_hat` (`hats.felt_hat`) | `CONE`, `DOME_FINIAL`, `UMBRELLA`, `GAT`, `FLAT_DRUM` (L, deferred), `VISOR` (held), and a tall crown-only profile (crown taper; flat, dome or four-cornered top). New styles of `ROUND_HAT` need no code. | `japanese_sugegasa`, `chinese_douli`, `vietnamese_non_la`, `filipino_salakot`, `malay_tudong`, `korean_gat`, `kalpak`, `persian_kolah_zand`, `kurdish_kaouk`; ROUND_HAT styles: `hat_flat_womens`, `spanish_sombrero_gacho`, `korean_paeraengi` |

### 2.2 Options on existing types (no new type)

- **apron:**
  - `bib`: `leather_apron`, `japanese_haragake` (bib, belly pouch, crossed straps);
  - flat style (folds ≈ 0.002, flare 0.02): `apron_flat`.
- **sash:**
  - a front knot (knot_angle 0);
  - a flat bow knot (box + ellipsoid), for the Japanese women's obi joined into the kosode;
  - narrow cord sashes;
  - hardware hooks for a dagger, an inkhorn, or a **pouch on a cord** (the Chinese tobacco bag and purse, the Japanese pouch with a netsuke toggle, the Korean pouch). The weapons are gear, not garment pieces.
  - Garments: `sash_shawl`, `spanish_faja`, `west_african_fillet`, `ethiopian_girdle`, `ethiopian_sash_silk`, `chinese_yaodai`, `korean_sejodae`, `vietnamese_that_lung`, `south_asian_kamarband`, `south_asian_patka`, `malay_kris_belt`.
- **belt:** clasp bosses (`belt_clasp`), no buckle (`belt_cord`), and a plate belt (`malay_tali_pending`).
- **leggings:**
  - ties instead of buttons, and a helix stripe: `gaiter_tied`;
  - garters with a falling fold: `moorish_cloth_stockings`;
  - no side flap, turned-down top: `spanish_botas_de_ala`.
- **jacket / coat / waistcoat styles:**
  - `jacket_short`, `waistcoat_womens`, `bedgown` (needs large ease and no armpit relief; make a `bedgown` kind if `jacket` cannot go loose), `salta`, `japanese_hanten`, `chinese_magua`, `vietnamese_ao_canh`, `spanish_jubon`;
  - `greatcoat` (FROCK);
  - `yelek_short`, `chinese_majia`, `malay_waistcoat`.
- **shirt** (with `bottom=`, a full-length `opening()`, or a slit angle): `frock_linen`, `shirt_ruffled`, `shirt_collarless`, `persian_pirahan`, `filipino_camisa`, `filipino_baro`, `malay_baju`, `malay_baju_womens`, `thai_sua`.
- **petticoat:** `petticoat_quilted`, `petticoat_short`, `south_asian_ghagra` (flare 0.35), `spanish_basquina`, `spanish_guardapies` (colours only).
- **stockings:**
  - in leather: `mest`;
  - knit: `socks_knit`;
  - **sock zones** inside the footwear (the tabi, the beoseon, Chinese cloth socks), so that `legs.over` stays free for gaiters.
- **sea_boots:** `boots_soft`. **moccasins:** `charuq`, `brogues`. **shoes_buckled:** `shoes_tied`.

### 2.3 Engine changes

1. `shirt(bottom=)`, side slits passed through `coat()`, and a neckline-slit angle.
2. `overlap_line`: a polyline that generalises the capot's vertical `overlap` (needed by the `robe` modes).
3. `trims.extrude` past the wrist (sleeves that cover the hands).
4. Fringe trim (`edge_zone` with hanging strands).
5. The `skirt_hang` pass on every long robe and skirt (they will clip when running or aiming, because cloth2 is skinned, not simulated). Long men's robes split at the front overlap below 0.86.
6. Zone patterns drawn by the cloth shader (§1.4, item 6).
7. Gating and slots: the people filter, the review gate, per-people `BASIC`, the missing slots, and `accessories.head` / `accessories.face` (§1.4, items 1–3).

### 2.4 Cloth kits and patterns

**Cloth kits.**
- Existing: LIN, WOOL, TWILL, KNIT, SUEDE, LEA, FUR, HES, FLAT.
- New: COT (lighter than LIN), SILK (sheen), MUSLIN (sheer; it can render opaque at first), STRAW (also leaf, bamboo and raffia hats), WOOD, RAFFIA, HORSEHAIR (translucent, for the gat).
- Held with the Pacific set: BARK (tapa), MAT, THRUM.

**Patterns.**
- Existing: `check`, `stripes`.
- New:
  - `print` (chintz and calico);
  - `quilting` (diamond or scroll; a normal pattern);
  - `strip_seams` (a seam every 0.15–0.18 m on African narrow-strip cloth);
  - `madras_check`, `jaspe` (ikat), `bandhani` dots, `komon` (small stencil dots), `boteh`;
  - crest decals (generic kamon only);
  - `sett` (a thread-count tartan with bias and dicing; only with the Highland set).
- Held: tapa geometric.

### 2.5 Palette

New tokens, after merging:

| Token | Hex | For |
|---|---|---|
| `indigo_pale` | #6E8BB1 | pale indigo and woad (merges indigo_light, indigo_pale, woad_blue) |
| `cotton_white` | #EEEBE1 | bleached cotton and muslin (merges cotton_white, muslin_white ×2) |
| `undyed_white_wool` | #E0D8C5 | undyed white wool and felt (merges felt_white, wool_undyed_white and the dropped Africa token) |
| `undyed_brown` | #6C523E | the Spanish pardo; undyed brown wool and felt |
| `saffron` | #DCA523 | turmeric and saffron (not the existing `orange` #C0632A) |
| `safflower` | #D66D7E | safflower pink and rose |
| `crimson` | #9D1D30 | lac and kermes crimson |
| `vermilion` | #C8402F | Vietnamese and Chinese red |
| `copperas` | #A97B3D | the yellow-brown of copperas stripes |
| `tukula_red` | #8E3B24 | camwood red (or `madder_red` if a test render reads the same) |
| `straw` | #C6AC6E | straw, palm leaf, raffia |
| `bamboo` | #B49A60 | split-bamboo hats |
| `camel_hair` | #A47C4F | camel and goat hair mantles (check it against `butternut` #957549) |
| `lambskin_grey` / `lambskin_black` | #7D7A74 / #1E1C1B | kalpak and kolah bands |
| `shagreen_green` | #4F6B4A | Persian slippers |
| `asagi` | #5F9EA6 | Japanese pale blue-green |
| `rokocha` | #6C6240 | the Japanese brown fashionable in the 1760s |
| `beni` | #B4344A | safflower red linings |
| `moegi` | #6E8B3D | Japanese green |
| `jade_green` | #9DBFA8 | Korean jade jackets and skirts |
| `yuebai` | #D9E2E6 | Chinese "moon white" |
| `cu_nau_brown` | #6A4129 | Vietnamese yam-dyed brown |
| `horsehair_black` | #121212 | the gat (translucent) |
| `wood` | #9B7B55 | sabots and geta |

**Reuse instead of adding:**

| Proposed | Use instead |
|---|---|
| dark indigo, kon, indigo_dark | `stroud_blue` |
| hanada | `indigo_mid` |
| nezumi | `slate_grey` |
| frieze_grey | `slate_grey` |
| osnaburg | `tow` / `linen_unbleached` |
| morocco_red | `madder_red` |
| turkey_red | `scarlet` |
| morocco_yellow, isparek_yellow | `yellow` |
| raffia_black, goat_hair_black and the other natural blacks | `logwood_black` |
| plains_green | `ranger_green` (#3B4A2E) |
| nankeen | `pale_buff` |
| Qing purple | `logwood_plum` |

- Held with the Pacific set: tapa_natural, tapa_brown, mati_red, nono_yellow, muka_gold.
- "negro_cotton" is **not** a token (critic). Use `undyed_white_wool`.

## 3. Garments shared across peoples (build once)

### 3.1 Existing cloth2 garments (x), reused with new presets

| Garment (x) | New presets, and who uses them |
|---|---|
| `shirt_linen`, `shirt_tucked`, `shirt_check`, `shift_linen` | all colonial and Atlantic peoples; sailors of every people |
| `breeches` | add a buckskin/leather preset (scots_irish, palatine, african_american) |
| `petticoat` | linsey stripes, penistone green |
| `stockings` | yarn and worsted: white, grey, blue |
| `leggings_wool` | — |
| `waistcoat_sb`, `waistcoat_skirted`, `veste_sleeved` | `veste_sleeved` also serves as the German *Wams* and the Spanish *chupa* |
| `frock_coat`, `coat_skirted`, `coat_regimental_1751`, `capot` | — |
| `jacket_womens` | also serves as the French *juste* or *casaquin* and the Dutch jak; add a chintz `print` preset |
| `stays_laced` | also the German *Mieder* and the Spanish *cotilla* |
| `apron` | also the Spanish *delantal*; add the gowns to its `fit_over` |
| `kerchief_womens` | also the *pañuelo* and the Filipino *alampay* |
| `cap_linen`, `cloak_hooded` | — |
| `neckerchief`, `stock_linen` | — |
| `cocked_hat`, `round_hat`, `hunting_cap`, `tuque_knit` | — |
| `sash_worsted` | plain only (§1.5) |
| `moccasins`, `shoes_buckled` | — |
| `slops`, `sea_jacket`, `neckerchief_sea`, `tar_hat`, `sea_boots` | sailors of every people |

### 3.2 Existing lib-1 ids to rebuild on cloth2 (r), not duplicate

- **`hunting_shirt_tow` and `hunting_frock`.** These are the frontier hunting shirt.
  - Cut: loose, lapped left over right by 0.10–0.12, held by a sash or belt, hem 0.62.
  - Shoulder cape to 1.17 at the back and 1.20 at the front, with a fringed edge of 0.035.
  - Sleeves to the wrist with band cuffs.
  - Cloth: tow or linsey; colours `linen_unbleached`, `tow`, `butternut`, `walnut_brown`.
  - Certainty: H for the Virginia Regiment in July 1758 [EU-U1]; M for this cut and the fringe (the detailed descriptions are from 1775 on†).
- **`leggings_buckskin`, `monmouth_cap`, `mittens_fur`.** `monmouth_cap` and `tuque_knit` are also the "worsted cap", "red cap" or "Monmouth cap" of the runaway ads [AF-N1], [AF-N2].
- **`fur_mantle`.** Rebuild it, but put it in review first: its history cites Lenape robes (Heckewelder).
- **`ew_shirt_linen` duplicates `shirt_linen`.** Build one trade shirt with a worn-loose variant.
  - `ew_shirt_ruffled` becomes the shared `shirt_ruffled` (§3.4).
  - How the shirt is worn in the Woodlands set stays under review.

### 3.3 Plain trade goods any people may wear (after the offices' review)

From the Woodlands note. The rule: offer the plain good, as a trader or storekeeper sold it. Do not offer a nation's cut or way of wearing it: breechcloth, wrap skirt, the belted matchcoat drape, quill and bead work, finger-weaving, ribbon work, or community designs.

| Good | Item | Rule |
|---|---|---|
| Stroud (Gloucestershire broadcloth, blue or red) and duffel | palette `stroud_*` | Any cloth or colour on any garment. |
| A plain blanket wrap | `capot_blanket` (r) | Fine for anyone. The belted matchcoat drape needs review. No Hudson's Bay point-blanket stripes before 1779. |
| Linen trade shirts: white, check, ruffled | `shirt_linen` (x), `shirt_ruffled` | Calico shirts stay grade B. |
| Silk and check handkerchiefs | `neckerchief` (x) | Fine round the neck. Worn as a head wrap it carries the Shawnee citation (`ew_head_wrap`), so the Shawnee review comes first. |
| Silk ribbon | as binding only | Ribbonwork is the nations' art. |
| Plain worsted sash | `sash_worsted` (x) | Never labelled "Métis". |
| Plain trade silver: ring brooches, ear bobs, arm and wrist bands | `ew_brooches`, `ew_earbobs`, `ew_armbands`, `ew_wristbands` | Plain forms only. |
| Gorgets; peace medals; laced coats and hats given as diplomatic gifts | `ew_gorget`; none; planned `ew_trade_coat` | Political or status items: review first. The deny-list term "chiefs" also rules out the usual name. |
| Glass beads, brass cones, thimbles | trim | Fine as goods. The patterns they are worked into belong to the nations. Wampum is never an item. |
| Vermilion | creator `vermilion_cheeks` | Restricted and reviewed. |
| Plain wool leggings and moccasins made by colonists | `leggings_wool` (x), `moccasins` (x) | Fine for anyone (Knox, 1758, H). The edged or quilled `ew_*` versions need review. |

### 3.4 New shared garments

**Colonial family (Europe and the Atlantic)**

| id | slot · layer | type | cut and measurements (m) | cloth · colours | used by | cert. | src |
|---|---|---|---|---|---|---|---|
| `gown_open` | outer 40 | gown, front `stomacher`, back fitted | **Bodice:** over `stays_laced`; the fronts pinned to a stomacher (the stays' zone 3); square neck at 1.235 in front, 1.36 behind; waist 1.02, front point 0.985. **Sleeves:** end at t 0.50–0.52, turned cuff 0.04. **Robings:** 0.025 wide, raised 0.002, down both fronts to the hem. **Skirt:** hem 0.10 (0.07 better-off); open front from half-width 0.03 at the waist to 0.16–0.20 at the hem; pleated in at the sides and back (folds 0.012–0.015); flare 0.20; 0.012 over the petticoat. **Better-off:** 1–3 sleeve flounces 0.06–0.12, deeper behind the elbow (zone 3). | worsted (calimanco, camlet, tammy, often glazed), printed linen or cotton (`print`), check; silk taffeta and damask better-off · `madder_red`, `indigo_mid`, `full_green`, `logwood_black`, `buff`, `pale_yellow`, `drab` | all six European peoples, african_american, euro_african | H garment; M-H cut | [EU-E4] |
| `gown_sack` | outer 40 | gown style, back `sack` | `gown_open` plus two double box pleats, 0.09 wide each, either side of the centre back, falling loose from the neck to the hem (the robe à la française) | silk | better-off: french, english, dutch, spanish | H† | [EU-E4] |
| `gown_close_bodied` | outer 40 | gown, front `closed` | as `gown_open`, but the fronts meet edge to edge with hooks; the skirt is closed or only just open. The working "stuff gown", and the Caribbean close-bodied gown. | worsted, calico, check | english, scots_irish, palatine, african_american, euro_african | M | [EU-E4], [AF-N11] |
| `bedgown` | outer 40 | jacket loose (or a new kind) | **Body:** T-cut, body and sleeves as one; no waist shaping or armpit relief; left over right by 0.06–0.08, pinned or held by the apron strings; low round neck filled by the kerchief, optional collar band 0.02; ease 0.035, side gores flare 0.03; hem 0.82 front, 0.80 back. **Sleeves:** wide, end at t 0.45–0.50, turned back 0.03. | linen, linsey-woolsey, check, printed cotton · `linen_unbleached`, `linen_white`, `check_blue`, `indigo_mid`, `madder_red` | english, scots_irish, dutch (homeland) | M-H homeland; L in the colonies before 1765 | [EU-E2], [EU-E2b], [EU-U2] |
| `frock_linen` | outer 40 | shirt at outer ease (`hem=0.48, side_hem=0.48, ease≈0.045, slit_top=0.60` + `over`) | **Cut:** a plain, loose, shirt-cut pullover worn over the clothes; hem 0.48, side slits to 0.60; neck slit 0.14 deep with one button; dropped shoulders; full sleeves to a wrist band (t 0.92). **Not:** no yoke, gathers, smocking or falling collar (those belong to c. 1780–1850). | unbleached linen, hemp, tow, duck · `linen_unbleached`, `tow`, `linen_white`, `drab` | english (carters, waggoners, labourers); palatine *Kittel*, dutch *kiel*, french *sarrau* (all L) | H garment (a coachman's "linen frock", 1746); L cut | [EU-E1] |
| `greatcoat` | accessories.wrap 50 | coat, FROCK style | **Fit:** hem 0.29 front, 0.28 side, 0.27 back; outer ease +0.012 over `frock_coat`, `waistcoat_sb`, `shirt_linen`, `breeches`. **Collar:** falling collar 0.075, optional shoulder cape to 1.12. **Front:** single-breasted, 6 buttons r 0.011 from 1.28 to 0.98 (Ulster style: one clasp at the throat). **Cuffs and back:** round cuffs (t0 0.70); vent to 0.72; flapped pockets at 0.88. | frieze, duffel, drab broadcloth · `drab`, `slate_grey`, `walnut_brown`, `stroud_blue`, `logwood_black` | english, scots_irish (the Ulster "big coat"), dutch, palatine; french *redingote* (L) | H† English; H Irish frieze (1751 notice); L-M for wearing it cloak-like | [EU-U2] |
| `leather_apron` | accessories.waist 35 | apron + `bib` | **Bib:** 0.26 wide, from the waist to 1.30, neck strap 0.02. **Skirt:** flat, not gathered, from 1.02 to 0.48 (0.30 for smiths); ties at the back; fitted over the breeches and waistcoat. | oil-tanned leather · `leather_brown`, `leather_black`, `buff`; linen or check for other trades | artisans of every colonial people: smiths, farriers, shoemakers, coopers, masons; Vessary's miners (main_story §8.1) | H† (Diderot's plates, 1751–72); M cut | Diderot† |
| `hat_flat_womens` | head 80 | rigid_hat, ROUND_HAT style | **Crown:** about 0.13 across (crown_a ≈ crown_b 0.066), 0.03–0.05 high. **Brim:** brim_r 0.19–0.22, flat (droop ≤ 0.01). **Ties:** silk ribbon under the chin or at the nape (zone 1). **Reference:** a V&A straw hat of 1750–74 is 0.445 across, with a crown 0.047 high. | `straw` (STRAW kit), black silk taffeta cover, felt · `ribbon_*` | english, scots_irish, palatine (worn over the cap), dutch, french (*bergère*), african_american ("a black silk hat"), euro_african (over a head wrap) | H | [EU-E3], [EU-G1], [AF-N1] |
| `mantelet_hooded` | accessories.wrap 50 | cloak, capelet | **Cut:** a short cape over the shoulders and arms; back hem 0.93; rounded front ends to the waist (1.00). **Hood:** gathered at the neck (half-width 0.13). **Closing:** ribbon ties at the throat (1.30); lined. The English "cardinal" is the scarlet preset. | wool, black silk taffeta · `scarlet`, `logwood_black`, `walnut_brown`, `slate_grey` | french, english, dutch | M-H New France; M† for "cardinal" | [EU-F1] |
| `cloak_long_hooded` | accessories.wrap 50 | `cloak_hooded` (x) style | hem 0.16, flare 0.06; a larger gathered hood (half-width 0.15) thrown back | heavy frieze · `stroud_blue`, `slate_grey`, `logwood_black`, `madder_red` | scots_irish, english (country women) | M (Irish women's outer garment, 17th–18th c.); L-M for blue in the 1750s | [EU-U3] |
| `petticoat_quilted` | legs.lower 30 | `petticoat` (x) preset + `quilting` | ease 0.03; hem 0.24–0.26; diamond or scroll quilting | silk or glazed worsted over wool wadding · `indigo_mid`, `madder_red`, `full_green`, `logwood_black`, `deep_yellow` | english, dutch (*gestikte rok*), french, palatine, scots_irish, african_american ("a red quilted petticoat") | H† | [AF-N1] |
| `petticoat_short` | legs.lower 30 | `petticoat` (x) style | hem 0.28–0.32 | wool, linsey; stripes | french (Canada) | M-H: D'Aleyrac, "skirts that scarcely go down to the calves" (quoted second-hand) | D'Aleyrac, via a reenactor guideline whose publisher could not be confirmed |
| `jacket_short` | outer 40 | jacket, JACKET style | a man's short jacket: hem 0.86, sleeves to the wrist (`sleeve_end` 0.90), 7–9 horn or pewter buttons, no cuff buttons, ease +0.005 | frieze, kersey, linsey-woolsey, plains, fearnought, duffel · `logwood_black` ("black frize jacket", 1751), `slate_grey`, `drab`, `stroud_blue`, `madder_red`, `undyed_white_wool`* | scots_irish, african_american, english, dutch, palatine; labourers and boatmen of every colonial people | H | [EU-U2], [AF-N1] |
| `waistcoat_womens` | outer 40 | jacket style | a woman's working waistcoat "without skirts": hem 0.93, buttoned (8 buttons, z 1.25–0.96), sleeves to the wrist or elbow; worn as a suit with a petticoat of the same cloth. **Style `jacket_laced`:** laced through eyelets, with short back skirts to 0.88. | linsey-woolsey, kersey, osnaburg, tow cloth | african_american, english, scots_irish (working women) | H garment; M for New York cloth | [AF-N1], [AF-N6], [AF-N7] |
| `trousers_long` | legs.lower 30 | `slops` (x) style, END ≈ 0.97 | ankle-length labourers' and sailors' trousers, with the slops' ease and seat; tag `pants` | osnaburg, check, tow · `linen_unbleached`, `tow`, `check_blue` | african_american, euro_african, sailors of every people | H | [AF-N1], [AF-N10] |
| `shoes_tied` | feet 40 | `shoes_buckled` (x) style | the buckle replaced by a thong tied through two latchets; a coarse, heavy sole | `leather_black`, `leather_brown` | african_american and labourers of every colonial people | H | [AF-N1], [AF-N3] |
| `shirt_ruffled` | shirt 10 | `shirt_linen` (x) style | a raised frill (zone 1) 0.03–0.04 deep down the breast slit ("ruffled at the bosom") | white linen · `linen_white` | better-off men of every colonial people; the trade shirt | H | [AF-N1] |
| `mitts` | accessories.hands 35 | hand_cover | fingerless shell over the hand and forearm, with a thumb hole and a pointed flap over the back of the hand; to the elbow (t 0.45) or the wrist | silk, kid, knit · `logwood_black`, `linen_white`, colours | better-off women of every colonial people | M† | — |
| `wooden_shoes` | feet 40 | rigid_shoe | **Size:** sole about 0.27 (the foot +0.02); heel 0.02–0.03; opening over the instep; worn over stockings. **Style `french`:** pointed toe, optional leather strap over the instep. **Style `dutch`:** rounded, high toe. | WOOD kit (poplar, willow, beech), plain or blackened · `wood`* | french, dutch (homeland) | H† homeland; L Canada and Albany | — |
| `brogues` | feet 40 | `moccasins` (x) style | a single sole of raw or tanned hide, no heel; upper to 0.09–0.10; thong lacing over the instep. Drain holes are L†. | `leather_brown`, `buckskin_pale`, `leather_black` | scots_irish (Ulster homeland); the held Highland set | H Highlands (Burt: "brogues or pumps without heels"); M Ireland | [EU-H2] |
| `rebozo` | accessories.wrap 50 | drape, head or shoulder anchor | a rectangle about 0.65 × 2.2 m, with knotted fringes 0.15 at the ends; worn over the head or the shoulders, one end thrown over the opposite shoulder | cotton in blue-and-white ikat (`jaspe`); silk with gold or silver thread for the better-off | spanish (New Spain); any people of New Spain | H for 18th-century New Spain, across classes; L Florida and Spain | [EU-S8], [EU-S8b] |

**Africa and the tropics.** One cloth rectangle at four lengths, with presets per people.

| id | slot · layer | type | cut and measurements (m) | cloth · colours | used by | cert. | src |
|---|---|---|---|---|---|---|---|
| `wrapper_knee` | legs.lower {30, hips 35}; alt_slots `accessories.waist` 35 (over drawers) | wrap_skirt | **Cloth:** a rectangle about 2.0 × 0.62 m, about 1½ turns. **Top:** a rolled band at 1.00–1.04 (raised 0.006, zone 1). **Overlap:** at the front-left (−30°), split down its whole height so a stride opens it. **Hem:** 0.44 (0.40–0.50), flare 0.05. | hand-spun cotton strip cloth (`strip_seams`); raffia panels 0.52 × 0.52 sewn side by side, 3–4 panels, seams vertical (Kongo); check; stripes · `cotton_white`*, `indigo_mid`, `stroud_blue`, `indigo_pale`*, `straw`*, `tukula_red`* | west_african men; central_african men (raffia); arab (*futa*, Yemen and Tihama); south_asian (*lungi*; the *veshti* folded up double); malay (*kain sarong* over the drawers, in the waist slot) | H | [AF-A2], [AF-C3], [NIE], [SA7], [ML1] |
| `wrapper_calf` | legs.lower {30, 35} | wrap_skirt style | **Top:** 1.03, or 1.06 worn from the navel. **Hem:** 0.25 (0.20–0.30). **Cloth:** about 2.2 × 0.90 m, about twice round. **Over-wrapper:** optional, shorter (2 layers, hem 0.30). **Presets:** front fold for the Thai *pha nung*; a black tube rolled at 1.03 for the Vietnamese *váy*. | strip cotton; velvet, silk, perpetuana (better-off); Indian chintz; black cotton | west_african (Gold Coast better-off men), thai (*pha nung*), vietnamese (*váy*) | H | [AF-A1], [TH1], [VN1] |
| `wrapper_long` | legs.lower {30, 35} | wrap_skirt style | top 1.03; hem 0.12 (0.08–0.16: "as low as the small of their legs"); about 2.2 × 0.95 m wound twice; optional over-wrapper, hem 0.30; optional fringed hem (zone 3) | strip cotton, indigo, imported Indian cotton, raffia, silk brocade, blue-and-red check | west_african women; central_african women and better-off; south_asian (*veshti* to the ankle, white with a coloured or zari border) | H-M | [AF-A2], [AF-C1], [AF-C3], [SA7] |
| `wrapper_high` | legs.lower 30 | wrap_skirt style, top under the arms | top 1.23, folded and tucked at the breast; hem 0.47 (village); a second mesh with hem 0.08 for town wear | cotton; Bugis check (`check`) · `madder_red`, `indigo_mid`, `cotton_white`* | malay women (the village woman's only garment); later the Pacific ʻahu (held) | H | [ML1] |
| `mantle_one_shoulder` | accessories.wrap 50 | drape, one shoulder | about 2.2 × 1.1 m, across the back and over the right shoulder, the left arm bare; front edge from the shoulder (1.42) diagonally to the opposite hip (0.90); back hem about 0.60. **Style `large`:** about 2.6 × 1.6 m. **Style `plaid`:** wound round the body ("somewhat in the form of a highland plaid … usually dyed blue", Equiano; M). | strip cotton, silk-and-cotton strip cloth (better-off), raffia | west_african men, central_african men (M-L for commoners) | H | [AF-A2], [AF-A4], [AF-C1] |
| `mantle_upper_wrap` | accessories.wrap 50 | drape, breast anchor | about 1.8 × 0.9 m over both shoulders, the ends crossed over the breast, the arms covered to the elbow. The documented upper cloth, so no outfit needs to be bare. | cotton; silk ("a veil of silk", Bosman) | west_african women, central_african women, euro_african (Caribbean shawl) | M-H | [AF-A1], [AF-A2] |
| `mantle_back_carry` | accessories.wrap 50 | drape, back-carry anchor | a child sling across the back, tied over the breast | cotton, raffia | central_african (Cavazzi's engraving of a woman hoeing, 1687); west_african; north_african (a pouch in the back of the haik [LEM]) | M | Cavazzi 1687 (no link), [LEM] |
| `head_band` | head 80 | head_wrap `band` | a cloth folded into a band round the brow, the crown bare; hides no hair zones. **Default:** 0.04–0.05 wide, knotted at the front or side, ends 0.05. **Style `knot_back`:** 0.07–0.09 tall, tied behind, ends 0.12. **Style `wound`:** several turns, no hanging ends. | cotton: `cotton_white`*, `indigo_mid`, check, black satin | japanese (*tenugui*); chinese women (forehead band, black satin 0.04–0.06, `knot_back`); west_african women (`knot_back`: "handkerchiefs tied round their heads, leaving their crowns bare"); filipino (*putong*, `wound`, 0.04–0.06) | H | [AF-A2], [EA-J1], [PH3] |
| `head_tie` | head 80 | head_wrap `kerchief` | **Style `full`:** a handkerchief over the whole head, knotted at the front or the nape. **Style `tall`:** built up 0.10–0.15 above the crown. | cotton and silk handkerchiefs; `madras_check` | african_american (optional, never the default: M for 1750s North America); euro_african Caribbean (`tall`, M-L before 1765) | M | [AF-A2], [AF-N11], [AF-N12] |
| `skullcap` | head 80 | soft_cap `skullcap` | edge about (60°, 72°, 80°), ease 0.005–0.008, no band; optional short tassel (`hats.tube`); also the core under the turbans | white cotton; white or brown felt (*libdeh*); red felt with a dark-blue silk tassel; indigo · `cotton_white`*, `undyed_white_wool`*, `undyed_brown`*, `scarlet` | west_african (Moore's cotton caps; feathers and goat-tail tufts mark status); every MENA people; north_african (red cap); Muslim ethiopian; kurdish women | H | [AF-A2], [LAN], [SHA] |
| `sandals_leather` | feet 40 | sandal | a flat leather sole 0.010 with an instep strap and a toe loop ("a single sole … with latchets", Poncet; "single soles, or sometimes thin pieces of wood, bound upon the foot with a strap", Niebuhr) | `leather_brown`, `buckskin_pale`, undyed | west_african, central_african, ethiopian, arab, north_african. Bare feet were just as usual: use feet "-". | M-H | [AF-E1], [NIE] |
| `drawers_short` | legs.lower 30 | trousers `drawers` | drawstring at 1.00; hem at mid-thigh 0.68 (style `knee`: 0.47); ease about 0.03; crotch drop about 0.08; tag `pants` | white coarse cotton; Malay cotton, or red or yellow taffeta | ethiopian men ("coarse cotton trowsers that reached to the middle of his thigh"); malay men (*seluar*) | H | [AF-E2], [ML1] |
| `loincloth` | legs.lower 30 | loincloth | band at z 0.98–1.04; a strip 0.22 wide; front flap to 0.75–0.85 | brown or black hemp (*khố*); white cotton (*fundoshi*) | vietnamese (field and water work), japanese (the labourer's base layer); the Pacific maro is held | M | [VN1], [EA-J1] |

**East Asia**

| id | slot · layer | type | cut and measurements (m) | cloth · colours | used by | cert. | src |
|---|---|---|---|---|---|---|---|
| `gaiter_tied` | legs.over 30 | leggings, GAITERS style + ties | a tube from 0.10 to 0.42, ease 0.006, seam at the outer back, 2–3 ties at the top or two straps below the knee; optional helix stripe (wrapped strips) | `indigo_mid` cotton (*kyahan*); coarse white cotton (*haengjeon*); blue or black (*bangtui*); linen strips (Persian peasants) | japanese, korean (H), chinese (L-M), persian peasants (L-M), armenian and kurdish rural (L) | H for Japan and Korea | [EA-J1], [EA-K4], [DIB] |
| `apron_flat` | accessories.waist 35 | `apron` (x), flat style | band at 0.98–1.02; a panel 0.45–0.65 wide that does not wrap round; hem 0.40–0.50 | `indigo_mid` cotton (*maekake*, *weiqun*); white cotton (*haengju chima*: taken off before elders); striped cotton or wool (the *pestamal*, the Armenian *mezar*) | japanese (H), korean (H), chinese (M-L), armenian (L) | M | [EA-K3], [ARM] |
| `head_cloth_womens` | head 80 | `soft_cap` (x) `womens`, frill None | caul 0.04 over the hair knot | white or indigo cotton | japanese (*anesan-kaburi*), korean (the lower-status women's head cloth) | M | [EA-K6] |

**Middle East and North Africa.** Shared by most of the nine peoples.

| id | slot · layer | type | cut and measurements (m) | cloth · colours | used by | cert. | src |
|---|---|---|---|---|---|---|---|
| `shirt_collarless` | shirt 10 (tucked) or {10, hips 35, thighs 35} (worn outside) | shirt (`collar=False`) | **Neck:** round, 0.085 / 0.078, with a front slit to 1.20. **Sleeves:** straight to the wrist (end 0.97), open, no band, very wide (0.45–0.55 round at the wrist). **Body:** hem 0.62, side slits to 0.80. | white linen or cotton; silk gauze for the better-off · `linen_white`, `cotton_white`* | ottoman_turkish, levantine, arab (towns), armenian, kurdish, moorish, egyptian | H | [NIE], [SHA], [LAN], [CHE] |
| `drawers_linen` | legs.lower {8} under a gown, else 30 | trousers `drawers` | drawstring at 1.00–1.03 with embroidered tie ends; crotch drop 0.06; ease 0.025; hem below the knee (0.40); tag `pants` | white linen or cotton | MENA townsmen and women (Egypt; Aleppo in summer). Off by default for the Bedouin and many country Arabs and Maghrebis. | H | [LAN], [RUS], [SHA], [BUR] |
| `salvar_mens` | legs.lower 30 | trousers `wide` | **Waist:** a rolled drawstring band at 1.04–1.07. **Crotch:** about 0.62 (drop 0.18). **Legs:** about 0.80 round each leg at the knee (ease about 0.08), tapering to an ankle band at 0.10–0.14 (band 0.035, about 0.32 round). Tag `pants`. **Styles:** `narrow` (Persian: "loose … without any tight ligaments", drop about 0.10, hem open at 0.08); `knee` (Moroccan linen, hem 0.40, M); `cakshir` (to 0.06, sewn to yellow leather socks as one mesh). | wool broadcloth or coarse woollen · `undyed_brown`*, `slate_grey`, `indigo_mid`, `logwood_black`; red broadcloth (`scarlet`) for the better-off; camlet in summer | ottoman_turkish, levantine, armenian, egyptian, arab (Yemen better-off), moorish (`knee`); `narrow`: persian, kurdish, Julfa Armenians; `cakshir`: better-off ottoman and levantine | H structure; M dimensions | [NIE], [RUS], [HAN], [CHE] |
| `salvar_womens` | legs.lower {8}, under the shift | trousers `wide`, ankle fall | crotch near the knee (about 0.50); legs 1.0–1.2 m round at the widest; gathered into an ankle band at 0.08–0.10 with the cloth falling over it to about 0.05; tag `pants`. **Style `shintiyan`:** tied below the knee (0.42) with running strings, hanging to the feet (Lane, 1830s: M). | cotton or linen (indigo for poor women); striped silk-cotton; printed muslin; damask brocaded with silver (elite) | ottoman_turkish, levantine, persian, arab, armenian, kurdish, moorish (M), egyptian | H | [MWM], [RUS], [NIE], [LAN] |
| `entari` | vest 36 | robe `crossed`, side tapes | **Body:** fitted to the hip; the fronts wrap over and tie with tapes at the side; round collarless neck. **Sleeves:** to the wrist, with small buttons and loops. **Skirt:** hem 0.36–0.40 ("under the knees"); side slits from 0.85; 1.5–2.0 m round at the hem. **Style `entari_long`:** hem 0.06–0.08; the *kuftan* sleeve 0.08 past the wrist, split from t 0.75. | striped silk-cotton (the stripes often figured), Aleppo flowered stuffs, Indian silk-cottons, calico, muslin in summer · crimson, `yellow`, green and white stripes; `indigo_mid`; `madder_red` | ottoman_turkish, levantine (*kunbaz*), armenian, kurdish ("the common antari"), arab (Yemen better-off), egyptian (*kuftan*) | H | [RUS], [NIE], [LAN] |
| `entari_womens` | vest 36 | robe `open`, fitted | **Body:** does not wrap over the breast; neckline low to 1.12–1.15, showing the shift; buttoned from the bust to just below the girdle (z 1.15 → 0.95, 12–18 small buttons); open at each side from the hip down. **Sleeves:** tight, longer than the wrist, split from t 0.70. **Hem:** 0.02 (to the ground). **Style:** cut like a man's (Kurdish). | as `entari`; silk for the better-off | ottoman_turkish, levantine, armenian, kurdish, egyptian (*yelek*) | H | [RUS], [LAN], [MWM] |
| `jubba` | outer 40 | robe `open` | loose, edge to edge, no fastenings; sleeves end short of the wrist (0.88); hem 0.10–0.15. **Style `binish`:** fuller, to the heels (0.04), the sleeves past the fingers. **Style `dulaman`:** to the heels, wrapping over. | wool broadcloth; shalloon or camlet in summer; linen for a summer dulaman. Christians wear dark colours. | ottoman_turkish ("common people … are content with the breeches, the enteri, and the benisch"), levantine, armenian, egyptian (*gibbeh*), arab (Yemen better-off) | H | [NIE], [RUS], [LAN] |
| `kurk_fur` | accessories.wrap 50 (moved from outer 42: one per slot) | robe `open` + fur zone (FUR) | **Default:** mid-leg (hem 0.30), sleeves to the bend of the arm (t 0.45), a fur border 0.13 wide (5 inches). **Style `short`:** mid-thigh (0.65), sleeveless. **Style `curdee`** (women): the sleeves just below the shoulder (t 0.15). | coarse fox (common people), squirrel, sable, ermine · `fur_red_fox`, `fur_*` | ottoman_turkish, levantine, armenian (winter) | H | [RUS], [MWM] |
| `sash_shawl` | accessories.waist 38 | sash (x) | z 0.94–1.09, wound 2–3 times, the ends tucked (a short end optional). Over the inner robe, under the outer coat. **Hardware:** a dagger stuck obliquely at the right front, or a Yemeni jambiya at the centre front (weapons are gear); a scribe's inkhorn. | Kerman or Kashmir shawl (`boteh`); white figured muslin; white or red wool (Egypt); figured worsted with one end doubled into a purse (Barbary); striped silk (Fez: a V&A sash measures 0.565 × 0.145 m) | all nine MENA peoples | H | [NIE], [RUS], [LAN], [SHA], [HAN], [VA-O364379] |
| `belt_clasp` | accessories.waist 39 | belt + clasp bosses | a band about 0.07 wide ("four fingers broad"; "three inches"), with a front clasp of two round bosses 0.06–0.08 across | gilt or silver on cloth; leather with brass plates (Kurdish peasants); crimson velvet embroidered in gold (Moroccan ladies) | women: ottoman_turkish, levantine, armenian, kurdish, moorish, egyptian; kurdish men | H | [MWM], [RUS], [RIC], [CHE] |
| `belt_cord` | accessories.waist 60 | belt (x), no buckle | a cord, a thin thong or narrow raffia at z 0.99–1.01 | leather, raffia, wool cord | central_african; arab (the Bedouin thong); north_african women (a wool cord girdle) | M | [AF-C4], [BUR] |
| `thawb` | shirt {10, hips 36, thighs 36} | tunic | a long pullover shirt; neck slit to 1.15–1.20; wide open sleeves (0.55–0.70 round); hem 0.12–0.20 (towns, Egypt) or 0.25–0.30 (herders), about 2.0 m round; zone 1 embroidery at the slit and cuffs. **Style `eree`:** slit nearly to the waist (1.05). | coarse cotton; indigo cotton or linen ("blue shirts and drawers"); brown wool (*zaaboot*) | arab, egyptian (`eree`), levantine villagers | H | [LAN], [NIE], [BUR] |
| `thob_womens` | shirt {10, hips 25, thighs 25} | tunic | as `thawb`, a little closer, hem 0.04–0.08 ("reaching to the feet"). **Style `shift_ottoman`:** hem 0.20, the sleeves hanging half way down the arm. Built opaque, even where period images show sheer gauze. | `indigo_mid`, `stroud_blue`, brown or black cotton; silk gauze for the better-off; Yemen highland: linen checked blue and white with coloured needlework | ottoman_turkish, levantine, arab, armenian, kurdish, moorish, egyptian | H | [LAN], [RUS], [NIE], [MWM] |
| `qashshaba` | shirt {10, hips 36}, or outer 40 | tunic + hood | undyed wool to mid-leg (0.30), large sleeves and a hood, girded at the waist ("a long coarse frock of undyed wool") | `undyed_white_wool`*, grey | moorish (commoners), north_african | H | [CHE], [LEM] |
| `aba` | accessories.wrap 50 | cloak `aba` | sleeveless, square shoulders about 0.10 wider than the shoulder joints; the front edges hang 0.10–0.20 apart; hem 0.20–0.30 (or 0.10); arm slits at 1.05–1.30, or short wide sleeves (the Hama *boush*) | goat hair, camel hair, wool: broad brown-and-white stripes the commonest; blue-and-white rare; black for sheikhs and in Egypt; thin white Baghdad wool · `camel_hair`*, `logwood_black` | arab (both sexes, in Lahsa), egyptian, levantine, kurdish ("the universal abba"), persian (better-off) | H | [NIE], [BUR], [LAN], [RIC] |
| `wrap_drape_womens` | accessories.wrap 50 | drape, head-to-ankle | a large sheet over the head and the whole dress to the ankle, held, knotted or pinned at the chest; the arms inside or at the edges (animation risk M) | **Presets:** `izar` (Levant: white calico for Christian and Jewish women, checkered blue or red for Muslim women; a communal marker, so offer it as a choice); `chador` (Persia: white); `habarah` (Egypt: glossy black silk, two breadths of about 2.7 × 1.15 m; white silk for unmarried women); `milayeh` (blue-and-white chequers with red ends); `haik` (Morocco: "comes over the head, and surrounds the face") | levantine, persian, egyptian, armenian, moorish, north_african | H existence; M feasibility | [RUS], [HAN], [DIB], [LAN], [CHE], [SHA] |
| `haik_mens` | accessories.wrap 50 | drape, one shoulder + head | wool about 5.5 × 1.6 m; the upper corners joined with thread or a wooden bodkin over one shoulder, the rest wound round the body, the top over the head | white or undyed wool · `undyed_white_wool`* | north_african, moorish | H | [SHA], [CHE], [LEM] |
| `burnous` | accessories.wrap 50 | cloak, hooded | one piece, close at the neck, hooded, wide below; closed at 1.15–1.30; hem 0.15–0.25; some fringed | white or undyed wool; dark blue European cloth in town in winter; white or blue at court | north_african, moorish | H ("wore by them all") | [SHA], [CHE] |
| `draped_dress` | vest 36 | wrap_skirt, pinned top | a tube from 1.30 (the top edge folded over to 1.05) to a hem at 0.08; the front and back edges pinned at each shoulder (brooches: a ring + pin, optional chain); a wool cord girdle; 0.15 overlap on the right | undyed white, indigo or dark-brown wool; a striped hem for the better-off | north_african women; egyptian (Upper Egypt *hulaleeyeh*) | M-H | [CHE], [LAN] |
| `turban_common` | head 80 | head_wrap `turban` | the core is a small cloth cap or a low scarlet felt cap; coarse cloth wound loosely in 3–5 rolls on a tilted helix; outer width 0.22–0.25, roll height 0.05–0.07, roll radius 0.012–0.016 | white cloth (washed fresh); red or yellow wool shawl; coarse cotton. **Presets:** `christian` (a red cap wrapped in blue-and-white striped linen); `copt` (dark); Kurdish (dark red with blue-striped ends). **Never green:** reserved for descendants of the Prophet. | ottoman_turkish, levantine, armenian, kurdish, moorish, egyptian, arab (Yemen: two caps under a loose cloth), north_african (better-off), ethiopian (Muslim men, white) | H | [SHA], [LAN], [RUS], [NIE], [RIC], [AF-E2] |
| `turban_town` | head 80 | head_wrap `turban` | the core is a stiff, quilted, flat-topped cap (*kaouk*), 0.10–0.16 high; white muslin "about twenty-four yards"; outer 0.28–0.32 across, 0.08–0.12 high | white muslin on a red core | better-off: ottoman_turkish, levantine, egyptian, moorish | H | [RUS] |
| `turban_sesh` | head 80 | head_wrap `turban` + hanging ends | several caps under a large muslin cloth whose fringed ends (silk or gold) "flow loose upon the shoulders"; ends 0.25–0.35 | white muslin | arab (better-off, Yemen and the Hejaz) | H | [NIE] |
| `turban_flat_womens` | head 80 | head_wrap `flat` | a small cap bound with a kerchief wound in a high, flat shape | printed muslin; an embroidered handkerchief; cotton. **Preset `rabtah`** (Egypt). | ottoman_turkish, levantine ("a warm cloth cap … cotton and muslin"), egyptian | H (M for the Egyptian preset, Lane 1830s) | [MWM], [LAN], [RUS] |
| `head_kerchief` | head 80 | drape, head-short | a square over the head, hanging to the shoulders. **Style `large`:** about 1.8 m square. | red for young women, black for older women; cotton or silk | arab (Bedouin women), levantine villagers, armenian (village, L), north_african (a triangle over the plaited hair, L) | H Bedouin | [BUR], [RUS] |
| `keffiyeh` | head 80 | drape, head-short + optional cord | a square headcloth, one corner falling behind and two over the front of the shoulders; optional camel-hair cord (a ring of r about 0.095, 0.009 thick, two turns) | cotton or cotton-silk, yellow or yellow-green; a red-and-white striped Damascus or Baghdad shawl for sheikhs | arab (Bedouin men), Bedouin of the Levant | M (Burckhardt, 1810s); cord M for 1760 | [BUR], [VA-O319327] |
| `kalpak` | head 80 | rigid_hat, tall crown-only | a cloth cap lined with cotton, "of various heights in the crown" (0.14–0.20), bordered with a lambskin band 0.05 | cloth · `lambskin_black`*, `lambskin_grey`* | armenian; ottoman Christians ("worn by many of the Christians in the East") | H (Niebuhr, verified) | [NIE] |
| `slippers_backless` | feet 40 | slipper | the heel back cut away; the toe pointed, 0.02 beyond the foot; often worn trodden down at the heel. **Style `persian`:** heels 0.03–0.04, "without quarters". | yellow morocco (Muslim men "always yellow"); red (Christians at Aleppo); thick red morocco, pointed and turned up (Egypt); yellow (women); green shagreen (Persia) | all nine MENA peoples | H | [RUS], [LAN], [HAN], [CHE] |
| `mest` | legs.over 6 | `stockings` (x) in LEA | a leather sock-boot to z 0.22–0.28, under the trouser cuff | `yellow` (Muslim men); red or black (others); thin coloured leather (women) | ottoman_turkish, levantine, egyptian, arab (better-off) | H | [RUS], [LAN], [NIE] |
| `boots_soft` | feet 40 | `sea_boots` (x) build | soft, to z 0.42, pointed toe, low or no heel | `yellow` (Muslims); red and iron-shod for common people in winter. Christians may not wear yellow (a sumptuary preset). | ottoman_turkish (travel), levantine | H | [RUS], [NIE] |
| `charuq` | feet 40 | `moccasins` (x) build | rawhide drawn round the foot by a laced thong, tied over leg wraps | rawhide | persian peasants; rural armenian and kurdish (the Anatolian *çarık*) | M | [DIB], [ARM] |
| `socks_knit` | legs.over 6 | `stockings` (x), KNIT | to z 0.30 | wool; patterned bands are L (19th-century evidence) | persian ("socks of wool which reach over the ankles"), armenian, kurdish | H Persia | [HAN] |
| `kepenek` | accessories.wrap 50 | cloak (the `weather_cape` method) | stiff felt to the knee (0.47); square shoulders; open front; optional hood | `undyed_white_wool`*, `undyed_brown`* | shepherds: ottoman_turkish (M), kurdish, persian | M | [RIC], [DIB] |
| `sheepskin_coat` | accessories.wrap 50 | cloak + fleece zone (FUR) | an envelope to the knee, the fleece inside; goatskin with the hair on | sheepskin, goatskin | arab (Bedouin; highland Yemen), kurdish, persian peasants | M-H | [BUR], [RIC], [NIE] |
| `salta` | outer 40 | jacket (x) | a short jacket, hem 0.92–0.98, the edges meeting, no buttons (or braid loops). **Style `fur`:** fur-lined to the waist. | cloth or velvet embroidered in gold (the Egyptian women's *saltah*); stripes or florals (Zand women); `fur`: Persian men (Hanway, 1740s) | egyptian, persian, armenian (velvet) | M-H | [LAN], [DIB], [HAN] |
| `yelek_short` | vest 20 | waistcoat (x): `back=None`, no pockets | a short sleeveless vest under the robe; hem 0.90; round neck; about 12 small buttons | silk, cotton | egyptian (*sudeyree*); M for the others | H Egypt | [LAN] |

## 4. The peoples

Every section has the same columns:

| Column | What it gives |
|---|---|
| **id** | the garment |
| **slot · layer** | where it goes |
| **cut and measurements** | in metres. "§3" means the shared spec, with only the preset given here |
| **cloth · colours** | the cloth and its colour tokens |
| **type** | the recipe type |
| **cert.** | certainty: H, M or L |
| **src** | the source key |

### 4.1 english

English colonists, provincial soldiers and regulars. The soldiers' uniforms are the existing regulars and militia sets.

**Basic:** `shirt_linen` + `breeches`; `shift_linen` + `petticoat` (as now).

**Men, everyday** (farmer, labourer, carter, artisan)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_linen` (x) | shirt 10 | as built | linen · `linen_unbleached`, `linen_white`; check | shirt | H | catalog |
| `breeches` (x) | legs.lower 30 | as built, plus a buckskin preset | leather (`buckskin_pale`), drab or brown wool | — | H | [EU-U2] |
| `veste_sleeved` (x) | vest 20 | a sleeved waistcoat for labourers | `drab`, `walnut_brown`, `kersey_blue` | waistcoat | H | catalog |
| `frock_linen` | outer 40 | §3 | `linen_unbleached`, `tow`, `drab` | shirt | H garment, L cut | [EU-E1] |
| `round_hat` (x) | head 80 | felt | `logwood_black`, `walnut_brown` | rigid_hat | H | catalog |
| `neckerchief` (x) · `stockings` (x) · `shoes_buckled` (x) or `shoes_tied` | neck, legs.over, feet | as built | check, linen; worsted | — | H | catalog, [AF-N1] |
| `leather_apron` (artisans) · `greatcoat` (winter) | waist 35 · wrap 50 | §3 | `leather_brown` · `drab`, `slate_grey` | apron + bib · coat | H† | §3 |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shift_linen` (x) + `stays_laced` (x) | shirt 10 · vest 20 | as built | linen | — | H | catalog |
| `petticoat` (x) or `petticoat_quilted` | legs.lower 30 | as built / §3 | worsted, linsey, quilted glazed worsted | petticoat | H | [EU-E4] |
| `jacket_womens` (x) | outer 40 | as built (pinned edge to edge, sleeves to the elbow) | worsted, linen, printed cotton, stripes | jacket | H | catalog |
| `apron` (x) · `kerchief_womens` (x) · `cap_linen` (x) | waist 35 · neck · head 80 | as built | `linen_white`, `check_blue` | — | H | catalog |
| `hat_flat_womens` | head 80 (over the cap) | §3 | `straw`*, black silk | rigid_hat | H | [EU-E3] |
| `cloak_hooded` (x), red | accessories.wrap 50 | as built | `scarlet` wool | cloak | H | catalog |

The `bedgown` is the homeland option (M-H); in the colonies before 1765 it is L.

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `frock_coat` (x) or `coat_skirted` (x) + `waistcoat_skirted` (x) silk + `stock_linen` (x) + `cocked_hat` (x) + `shoes_buckled` (x) | outer, vest, neck, head, feet | as built | broadcloth, silk · `walnut_brown`, `stroud_blue`, `drab` | coat | H | catalog |
| woman: `gown_open` (fitted back, the English gown; sleeve flounces) | outer 40 | §3 | silk taffeta, damask, glazed worsted | gown | H | [EU-E4] |
| woman: `petticoat` matching, or `petticoat_quilted` · `hat_flat_womens` · silk `kerchief_womens` · `mitts` · `mantelet_hooded` (`scarlet`: the "cardinal") | legs.lower, head, neck, hands, wrap | §3 | silk, straw, wool | — | H / M† | §3 |

**Noted, not playable:** Quaker plain dress (religious); clergy gowns and bands (the existing `coat_skirted` "minister" preset); mourning black as a story state.

**Avoid:** Pilgrim buckled hats; decoratively smocked "smocks".

### 4.2 scots_irish

Ulster Scots settlers of the backcountry, with an Ulster homeland preset. **Ulster Scots are not Highlanders.** Kilts and tartan on them are a cliché. Named clan tartans are a 19th-century development (H†).

**Basic:** as now.

**Men, everyday** (backcountry farmer and hunter)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_linen` (x) | shirt 10 | as built | linen, tow | — | H | catalog |
| `breeches` (x), leather preset | legs.lower 30 | as built | `buckskin_pale`, `leather_brown` | — | H (1750s notices) | [EU-U2] |
| `jacket_short`, frieze preset | outer 40 | §3 (hem 0.86, 7 buttons, ease +0.005) | frieze · `logwood_black`, `slate_grey` | jacket | H (Alexander Steel, an Irish servant, "a black frize jacket", *Pennsylvania Gazette*, 3 Oct 1751) | [EU-U2] |
| `hunting_shirt_tow` (r) | outer 40 | §3.2 | tow, linsey · `butternut`, `walnut_brown` | capot cut | H 1758 (the Virginia Regiment); M for settlers | [EU-U1] |
| `leggings_wool` (x) or `leggings_buckskin` (r) · `moccasins` (x) or `shoes_tied` | legs.over · feet | as built | wool, leather | — | H | catalog |
| `round_hat` (x) | head 80 | felt | `logwood_black`, `walnut_brown` | — | H | catalog |

**Ulster homeland men:** `greatcoat` (frieze, Ulster style with one throat clasp), `brogues` (M for Ireland), `stockings`, `round_hat`. The blue bonnet is L for 1750s Ulster.

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shift_linen` (x) + `stays_laced` (x) | shirt · vest | as built | linen | — | H | catalog |
| `petticoat` (x), striped linsey preset | legs.lower 30 | as built | linsey-woolsey · `madder_red`/`linen_unbleached` stripes, `indigo_mid` | — | H | [EU-U2] |
| `jacket_womens` (x) or `waistcoat_womens` | outer 40 | as built / §3 | linsey, worsted, check | jacket | H | catalog, [AF-N1] |
| `apron` (x) · `kerchief_womens` (x) | waist · neck | as built | linen, check | — | H | catalog |
| `mutch` | head 80 | soft_cap `womens` + new chin strings: edge at 66°, 110° and 135° from the crown (front, side, back), so it covers the ears; caul 0.015; a goffered frill 0.022 round the face; chin strings 0.008 wide, tied under the chin, ends 0.08 | white linen or muslin | soft_cap | H Scotland (Dictionary of the Scots Language: 1723, 1724, 1753); M for Ulster and the backcountry | [EU-H7] |
| `cloak_long_hooded` | accessories.wrap 50 | §3 | frieze · `stroud_blue`, `slate_grey`, `madder_red` | cloak_hooded style | M | [EU-U3] |

The `bedgown` is the Ulster homeland option ("Bed Gown", an Irish servant, 1766: M).

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man (Ulster merchant, backcountry squire): `frock_coat` (x) + `waistcoat_sb` (x) + `breeches` (x) + `cocked_hat` (x) + `shoes_buckled` (x); `greatcoat` in winter | — | as built | broadcloth · `drab`, `walnut_brown`, `stroud_blue` | — | H | catalog |
| woman: `gown_open` or `gown_close_bodied` in worsted or silk · `hat_flat_womens` · silk `kerchief_womens` · fine `cloak_long_hooded` | outer, head, neck, wrap | §3 | worsted, silk, fine wool | gown | H | [EU-E4] |

**Avoid:** kilts, tartan and clan setts; coonskin caps; the caubeen and the shillelagh.

#### 4.2a Held: Highland and Lowland Scottish dress (not a people in peoples.json)

The critic moved these out of scots_irish. They wait for:
- a future `highland_scots` people (civilian); or
- a military set for the 42nd, 77th and 78th Highland regiments in America, 1756–63.

**The law:** Highland tartan dress (the plaid, the philabeg, trews, shoulder belts) was illegal in Scotland "for man or boy" from 1 August 1747 to 1782 [EU-H1].
- Soldiers were exempt.
- Women and the knitted bonnet were not named.
- The Act did not apply in America (M).

The `scots_` prefix follows the future people's id.

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `scots_bonnet_blue` | head 80 | soft_cap `flat`: a band 0.03 deep at the brow (edge 64–80°); Lowland crown a flat disc 0.28 across, overhanging by 0.05–0.07; Highland crown smaller (0.23), worn tilted; thickness 0.006; a toorie (knob 0.02) on top; a ribbon cockade is an explicit political choice only (black Hanoverian, white Jacobite) | knitted, fulled, sheared wool · `indigo_pale`*, `indigo_mid`, `slate_grey` | soft_cap | H Scotland | [EU-H6a], [EU-H6b], [EU-H6c], [EU-H2] |
| `scots_short_coat` | outer 40 | JACKET: hem 0.98–1.00; sleeves end 0.90, small round cuffs (t0 0.83) with 3 buttons; collarless; over a `waistcoat_sb` 5–6 inches longer (hem about 0.85) | tartan or plain wool; silver buttons for the better-off | jacket | H (Burt; the NMS tartan suit of about 1744) | [EU-H2], [EU-H5b] |
| `scots_philabeg` | legs.lower 30 | wrap_skirt: top 1.04, belted at 1.00; hem 0.53–0.60; two flat front aprons about 0.30 wide, the right over the left by 0.12–0.15; loose pleats laid in at the belt from 55° to 180°, 0.025–0.03 deep | `sett` "hard tartan" worsted · `madder_red`, `indigo_mid`, `full_green`, `logwood_black`, `deep_yellow` | wrap_skirt | H by the 1720s–40s | [EU-H2], [EU-H3] |
| `scots_plaid_shoulder` | accessories.wrap 50 | drape: tucked under the belt behind at 1.00, rising over the back (120–240°, the right arm free) to the left shoulder; pinned at 1.28 with a ring brooch (0.06); the end hangs behind to about 0.55; its sett aligned with the philabeg's | `sett` | drape | H | [EU-H2], [EU-H3] |
| `scots_hose_cut` | legs.over 10 | stockings + a bias pattern: top 0.46 with a 0.04 cuff turned down; garter tape 0.015 at 0.43, ends 0.06 | red-and-white dicing, or the plaid's sett | stockings | H short hose; M dicing | [EU-H2], [EU-H5b] |
| `scots_trews` | legs.lower 30 | trousers, footed: from the waist (1.03) to the foot, cut on the bias; ease 0.006–0.008, a fuller seat; garters at 0.43 | `sett` | trousers | H (NMS trews, 1744); worn by gentry, for riding | [EU-H5c], [EU-H8a] |
| `scots_sporran` | accessories.waist 60 | belt 0.04 wide at 1.00; a goatskin or leather pouch at the centre front, 0.16 × 0.18 × 0.03; a clasp frame 0.15 on top; 2–3 tassels | leather, goatskin, brass | belt | M† | — |
| `scots_kertch` | head 80 | soft_cap `fall`: white linen pinned over the forehead (0.03 above the brow), round the back of the head, falling over the ears to about 1.40; worn by married women | linen | soft_cap | H 1769 | [EU-H3] |
| `scots_snood` | head 80 | a ribbon loop 0.015–0.02 wide, above the brow at about 1.60 and under the occiput at about 1.52; worn by unmarried women; hides no hair | `ribbon_red`, `ribbon_blue`, `ribbon_black` | loop strip | H | [EU-H3] |
| `scots_tonnag` | accessories.wrap 50 | drape: a small plaid about 0.9 × 1.4 m over the shoulders, to the waist behind (0.98); a brooch 0.05–0.07 at 1.25 | tartan, stripes, plain worsted | drape | H (Pennant) | [EU-H3] |
| `scots_plaid_womens` | accessories.wrap 50 | drape, head anchor: about 1.3 × 2.7 m "brought over the head", to the waist behind; one corner falls to 0.10 | tartan or check, silk or fine worsted (silk-lined for the better-off, Macky 1722); plain coarse wool for the poor | drape | H 1720–55; M after 1755 | [EU-H2], [EU-H8b] |

The `scots_arisaid` is deferred (L-M for the 1750s).

The kertch and the snood mark marital status. Offer them as the player's choice, never as inferred state.

### 4.3 french

Canadiens, habitants, troupes de la marine (the existing regulars set) and coureurs de bois. In 1757 they are the raiders on screen (main_story §10.1). A homeland preset covers France.

**Basic:** as now.

**Men, everyday** (habitant, militiaman, canoe man)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_linen` (x) · `veste_sleeved` (x) · `breeches` (x) | shirt · vest · legs.lower | as built | linen; wool · `undyed_white_wool`*, `drab`, `stroud_blue` | — | H | catalog |
| `capot` (x) | outer 40 | as built; plain cloth | wool · `undyed_white_wool`*, `stroud_blue`, `slate_grey` | capot | H | catalog |
| `tuque_knit` (x) | head 80 | as built | knit · `scarlet`, `stroud_blue`, `linen_white` | soft_cap | H | catalog |
| `sash_worsted` (x) | accessories.waist 60 | plain or with two stripes; no arrow pattern | worsted · `scarlet`, `stroud_blue`, `full_green` | sash | M (d'Aleyrac's "a sash around the capot", per the catalog entry); patterned sashes not before 1776–78 | catalog, [CR-CF] |
| `leggings_wool` (x) (*mitasses*) · `moccasins` (x) (*souliers de boeuf*) | legs.over · feet | as built | wool, oiled leather | — | H (Knox, 1758) | catalog |

**Homeland:** `wooden_shoes` (style `french`, H† for rural France) and `frock_linen` as the *sarrau* (L).

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shift_linen` (x) + `stays_laced` (x) | shirt · vest | as built | linen | — | H | catalog |
| `petticoat_short` | legs.lower 30 | §3 (hem 0.28–0.32) | wool, linsey, stripes | petticoat | M-H | D'Aleyrac (second-hand) |
| `jacket_womens` (x), striped preset (*juste*, *mantelet*) | outer 40 | as built | striped stuff · `madder_red` / `linen_unbleached` | jacket | M-H (a 1759 image of a Canadienne in a striped jacket, a black kerchief and a ribbon-trimmed cap, cited second-hand) | [EU-F1] |
| `apron` (x) · `kerchief_womens` (x), black preset | waist · neck | as built | linen · `logwood_black`, `linen_white` | — | M-H | [EU-F1] |
| `french_cornette` | head 80 | `cap_linen` / soft_cap `womens` + two lappets (*barbes*) 0.04 × 0.15, hanging or pinned up; ribbon trim | linen; muslin or lace (the *coiffe*) for the better-off | soft_cap | M | [EU-F1] |
| `mantelet_hooded` | accessories.wrap 50 | §3 | wool · `slate_grey`, `walnut_brown`, `scarlet` | cloak | M-H | [EU-F1] |

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `coat_skirted` (x), gentleman preset + `waistcoat_skirted` (x) + `cocked_hat` (x) + `stock_linen` (x) + `shoes_buckled` (x) | — | as built | broadcloth, silk | coat | H | catalog |
| woman: `gown_sack` (the robe à la française) + matching petticoat · `mantelet_hooded` in black silk · `french_cornette` in lace · `mitts` | outer, wrap, head, hands | §3 | silk | gown | H† | [EU-E4] |

**Noted, not playable:** Ursuline, Grey Nun, Récollet and Jesuit habits. The white Bourbon cockade is political.

**Avoid:**
- the beret and the striped sailor shirt;
- the arrow-patterned ceinture fléchée (1770s–90s);
- the blanket capote made from Hudson's Bay point blankets (from 1779);
- calling any of this "Métis".

### 4.4 palatine

German Palatine settlers of the Mohawk and Schoharie valleys: German Flatts and Stone Arabia, the player's 1757 neighbours. No distinct Palatinate or Mohawk-valley costume is documented for the 1750s, so they wear the colonial set with a few German details.

**Basic:** as now.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_linen` (x) | shirt 10 | as built | linen · `linen_unbleached` | — | H | catalog |
| `breeches` (x), leather preset (buckskin knee breeches, not Lederhosen) | legs.lower 30 | as built | `buckskin_pale`, `leather_brown` | — | H | [EU-G1] |
| `veste_sleeved` (x) (the *Wams*) | vest 20 | as built | wool · `drab`, `walnut_brown`, `stroud_blue` | waistcoat | M | [EU-G1] |
| `neckerchief` (x) | accessories.neck | tied "in a double knot under the chin" | linen, check, silk | neckwear | M | [EU-G1] |
| `round_hat` (x) · `tuque_knit` (x) or `monmouth_cap` (r) in winter | head 80 | as built | felt; knit | — | H | catalog |
| `stockings` (x) · `shoes_buckled` (x) · `frock_linen` (the *Kittel*) | legs.over · feet · outer | as built / §3 | — | — | H / L (frock) | [EU-E1] |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shift_linen` (x) + `stays_laced` (x) (the *Mieder*, worn as the outer bodice in summer) | shirt · vest | as built | linen; worsted | — | M | [EU-G1] |
| `petticoat` (x), striped linsey | legs.lower 30 | as built | linsey · stripes | — | H | [EU-G1] |
| `jacket_womens` (x) | outer 40 | as built | linen, worsted | jacket | H | catalog |
| `apron` (x), check · `kerchief_womens` (x) | waist · neck | as built | `check_blue` linen (common in Pennsylvania German households) | — | H | catalog, [EU-G1] |
| `cap_linen` (x) + `hat_flat_womens` over it | head 80 | as built / §3 | linen; straw | — | M (a flat hat over the cap) | [EU-G1] |

`palatine_cap_quilted` is dropped until its notice is dated (critic).

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `frock_coat` (x), palatine_brown preset + `waistcoat_sb` (x) + `cocked_hat` (x) | — | as built | broadcloth · `walnut_brown` | coat | H | catalog |
| woman: `gown_close_bodied` or `gown_open` in dark worsted or calico · silk `kerchief_womens` | outer · neck | §3 | worsted, calico | gown | L for specifics | [EU-E4] |

**Noted, not playable:** Mennonite and Brethren "plain" dress is religious. Never apply it to Lutheran or Reformed Palatines. Amish dress is codified later.

**Avoid:** the dirndl and Alpine Lederhosen; the shortgown for 1757 (`jacket_womens` already rules it out).

### 4.5 dutch

The Dutch-descended families of Albany, Schenectady and the Hudson valley. **They dressed English-style:** Kalm (1749) says "their dress is however like that of the English" [EU-K1] (H). Albany defaults to the English outfits (§4.1). The Netherlands is a homeland preset.

**Basic:** as now.

**Men, everyday** (Albany: the English set, plus):

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| English men's set (§4.1) | — | — | — | — | H | [EU-K1] |
| `greatcoat` (winter) | accessories.wrap 50 | §3 | duffel, frieze · `drab`, `slate_grey` | coat | H† | §3 |
| homeland: `dutch_breeches_wide` | legs.lower 30 | trousers `breeches`: waistband 1.06, pleated; very full in the seat and thighs (+0.06–0.08 at mid-thigh, `drift.flare_legs`); gathered into a buttoned knee band at 0.43–0.45; fly front | black, dark blue or brown wool; canvas for fishermen; horn or silver buttons | trousers | M Zuiderzee fishermen (a 17th-century fashion that survived; mostly described from the 1890s on); L Albany | [EU-R4] |
| homeland: `jacket_short` (the *buis*) or `sea_jacket` (x) · `waistcoat_sb` (x) · `round_hat` (x) · `wooden_shoes` (style `dutch`) | — | §3 | wool; wood | — | L / H† | §3 |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| English women's set (§4.1) | — | — | — | — | H | [EU-K1] |
| `petticoat_quilted` | legs.lower 30 | §3 | glazed worsted, silk | petticoat | H† | §3 |
| `jacket_womens` (x), chintz preset (the jak) | outer 40 | as built, closed edge to edge with hooks. The Hindeloopen jak (57 cm long; 1750, or 1810–20) is not a reliable guide to the 1750 cut. | chintz (`print`); plain wool for every day | jacket | M homeland; M-L Albany ("Dutch chintz jacket", New York 1774; "Dutch" also meant German) | [EU-R1], [EU-R5], [EU-R5b] |
| homeland: `dutch_muts_oorijzer` | head 80 | a close under-cap (black or white), a white linen or lace top cap, and the oorijzer: a metal band 0.008–0.012 wide round the back of the head from temple to temple, with ornamented ends about 0.015 at the temples | linen; brass, silver or gold (`brass`, `silver`, `gold_lace`) | soft_cap + hardware | M (Friesland, North Holland, Zeeland; the large forms are 19th-century); L Albany | [EU-R2] |
| homeland: `wooden_shoes` (`dutch`) | feet 40 | §3 | wood | rigid_shoe | H† | — |

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `coat_skirted` (x) + `waistcoat_skirted` (x), silver buttons, + `cocked_hat` (x) | — | as built | broadcloth | coat | H | catalog |
| woman: `gown_open` or a chintz jak, a lace cap; in Friesland a gold or silver oorijzer | outer, head | §3 | silk, chintz | gown | M | [EU-R1], [EU-R2] |

**Noted, not playable:** the black gown and bands of the Dutch Reformed ministers.

**Avoid:** Albany Dutch in "Knickerbocker" breeches, clogs and winged Volendam caps. These come from 19th- and 20th-century images (Irving, 1809†).

### 4.6 spanish

Spaniards of Florida (St. Augustine, Pensacola), New Spain and the Caribbean. Spain itself is the default. **Florida's everyday dress** is the colonial set plus the capa (M) [EU-S6].

**Basic:** as now.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_linen` (x) · `veste_sleeved` (x) (the *chupa*) · `stockings` (x) | shirt · vest · legs.over | as built | linen; wool | — | H | catalog |
| `spanish_calzon` | legs.lower 30 | trousers `breeches`, open knee: the outer knee seam open from 0.40 to 0.53 with 4–6 buttons (zone 2), often left open | wool, chamois, buckskin; velvet for the better-off · `logwood_black`, `walnut_brown`, `buckskin_pale` | trousers | M | [EU-S7] |
| `spanish_faja` | accessories.waist 60 | sash: a flat band from 0.94 to 1.08, wound three turns; the ends tucked at the left hip, or one short end hanging | wool or silk · `scarlet`, `madder_red`, `logwood_plum`, `logwood_black`, `royal_blue` | sash | M (New Spain); † Spain | [EU-S7] |
| `spanish_capa` | accessories.wrap 50 | cloak, circle cape with the arms inside: a three-quarter to full circle from a small stand collar at 1.36; hem 0.20 (the short capa ends at 0.55). **Embozos:** the inner front facings, 0.14 wide (zone 1). **Style `embozado`:** the right front thrown over the left shoulder (static). **Options:** a shoulder cape (*esclavina*) to 1.12; a clasp, chain or cord at the throat (zone 2). | *paño* broadcloth (Segovia, Béjar) · `undyed_brown`* (the *pardo* of ordinary men), `walnut_brown`; better-off: dark brown, black or blue with red or green velvet embozos | cloak | H universal before the decree of 10 March 1766; M cut and colours | [EU-S1], [EU-S2] |
| `spanish_sombrero_gacho` | head 80 | ROUND_HAT style: crown_h 0.10, rounded; brim_r 0.22; droop 0.05 (the brim falls all round); ribbon band 0.02 | felt · `logwood_black`, `walnut_brown`, `slate_grey` | rigid_hat | H | [EU-S1] |
| `shoes_buckled` (x) or `spanish_alpargatas` | feet 40 | alpargatas: a plaited esparto or hemp sole 0.012 thick; canvas toe and heel; ribbons crossed over the instep and wound round the ankle to 0.14 | `hemp`, `ribbon_black` | sandal | M-L† | — |
| New Spain frontier: `spanish_botas_de_ala` | legs.over 30 | leggings without the side flap: a deerskin wrap from the ankle to 0.46, the top turned down 0.06, a garter at 0.44; stamped leather (zone 1) | deerskin · `buckskin_pale`, `leather_brown` | leggings | M-L | [EU-S7] |

`spanish_montera` is optional and L. Build it as grade C if at all: a cloth cap with a rounded crown and a turned-up band 0.07, split into flaps (Cano y Olmedilla's prints are of 1777–88). It is not the bullfighter's montera of 1835.

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shift_linen` (x) + `stays_laced` (x) (the *cotilla*) | shirt · vest | as built | linen | — | H | catalog |
| `spanish_guardapies` | legs.lower 30 | the `petticoat` (x) preset | wool · `madder_red`, `deep_yellow`, `full_green`, `indigo_mid`; striped | petticoat | M | [EU-S3] |
| `jacket_womens` (x), or `spanish_jubon` | outer 40 | jubón: a JACKET style closed with hooks or 9 buttons, fitted; hem 0.97–0.99 with a basque 0.03–0.04; long close sleeves (end 0.90) with small cuffs | wool; silk for the better-off · black or colours | jacket | M-L for 1750–65 (the majo look is documented mostly in 1770s–90s Madrid) | [EU-S3], [EU-S3b] |
| `apron` (x) (*delantal*) · `kerchief_womens` (x) (*pañuelo*) | waist · neck | as built | linen | — | H | catalog |
| outdoors: `spanish_basquina` | legs.lower 30 (over the guardapiés: a petticoat style at layer 32) | petticoat style: top 1.04, hem 0.10; dense waist pleats (folds 0.014, steps 14); a wide flare; a hem band 0.06 of velvet ribbon (zone 1). No maja fringe or tassels. | black wool (*bayeta*, *estameña*) or silk · `logwood_black` | petticoat | M-H | [EU-S3] |
| outdoors: `spanish_mantilla` | accessories.wrap 50 | drape, head anchor: a half circle about 1.2 m from the brow over the head to the waist behind (1.00), the ends crossed over the breast | white wool baize with a black velvet border 0.05 (ordinary women, M†); black silk lace (better-off) | drape | H garment | [EU-S9] |
| New Spain: `rebozo` | accessories.wrap 50 | §3 | `jaspe` cotton | drape | H | [EU-S8] |

**Slot conflict:** the basquiña goes over the guardapiés, but both are in `legs.lower`. Either build the basquiña with the guardapiés as an inner zone, or give it `alt_slots` `accessories.waist`.

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `coat_skirted` (x), gentleman preset in silk + `waistcoat_skirted` (x) + `cocked_hat` (x) + a fine dark `spanish_capa` with velvet embozos | — | as built / above | silk, broadcloth, velvet | coat, cloak | H | [EU-S1] |
| woman: a silk `spanish_basquina` over the guardapiés, with `jacket_womens` or `spanish_jubon` in silk, and a lace `spanish_mantilla`; or `gown_open` | — | above / §3 | silk, lace | — | M | [EU-S3], [EU-S9] |

**Noted, not playable:**
- penitents' Holy Week robes and the capirote;
- the religious habits of the Franciscan missions of Florida;
- the *soldado de cuera*'s deerskin armour coat (a later military set).

**Avoid:**
- the peineta (19th century);
- the mantón de Manila;
- flamenco polka dots;
- the matador's montera;
- the conquistador's morion;
- maja trimmings (the *redecilla* hairnet, *madroño* tassels) before the 1770s.

### 4.7–4.10 The Eastern Woodlands nations: on hold (consultation)

No garments were designed for haudenosaunee, lenape, shawnee or wabanaki, as the brief asked. Nothing here changes until the offices answer. The main line of *Two Fires* needs no Native character, name, line, town life or adoption (main_story §10.8).

**The existing set.** `tools/character/garments/woodlands/` holds 17 `ew_*` items. All are lib 1, so none is offered today.
- **Clothing:** shirt, ruffled shirt, shift, breechcloth, wrap skirt, men's and women's leggings, men's and women's moccasins, head wrap, matchcoat, sash.
- **Ornaments:** gorget, brooches, arm bands, wrist bands, ear bobs.

**Findings to send to the offices first** (from the Woodlands note):

1. **Nothing gates or shows the review note.** Every item carries a `review` string, but no script reads it.
   - The Outfit tab shows only the description, the `licence_note` and "(artistic licence)".
   - Rebuilt at lib 2, the set would be offered to all 35 peoples (§1.4).
2. **The source base is narrow.**
   - Only one source is by a Native institution: Six Nations Polytechnic.
   - Most observers wrote after 1765: Jones 1773, Cresswell 1775, Smith 1799, Doddridge 1824, Jemison as told to Seaver 1824.
   - No item cites a Wabanaki source, yet the set's tooltip names the Wabanaki.
3. **Leggings seam (M).** Six Nations Polytechnic's Hodinohso:ni Art Lesson #11, *Clothing Styles* (Rick Hill and Roxanne Sky, 2012), puts the men's legging seam at the front, with a small opening at the bottom. `ew_leggings_m` puts the flap on the outside of the leg (Knox 1758, Doddridge). This may be a difference of period or nation. Haudenosaunee reviewers should settle it.
4. **The sash (M).** The same lesson calls the finger-woven sash a mark of status and rank. `ew_sash` is offered as an everyday accessory with a "generic" chevron. The lesson is "for educational purposes only, and not meant for commercial use". Ask Deyohahá:ge: before a commercial game leans on it.
5. **The costume bible's source keys cannot be checked.** `source/graph_analysis/customizer/costume_bible.md`, cited by `data/customizer/creator.json`, is not on this machine.

**Related items with no review flag.** These need the same review:
- the Woodlands hair styles: `hair_crown_lock_braided`, `hair_crown_lock_silver`, `hair_club_wrapped_f`, `hair_braid_f`, `hair_long_loose`, `hair_loose_tied`;
- `vermilion_cheeks` and `nose_jewel_silver` in `creator.json`;
- the frontier `fur_mantle`;
- the colonial `moccasins`, `leggings_wool`, `capot` and `sash_worsted`. These are Native-derived or Métis-linked forms, offered to everyone today.

**Plain trade goods:** §3.3.

#### 4.7 haudenosaunee

The Mohawk valley is Kanien'kehá:ka country. Offices (H unless marked):

| Nation or body | Office |
|---|---|
| Confederacy | the Grand Council at Onondaga, through the [Onondaga Nation office](https://www.onondaganation.org/page/92) and the Hodinǫhsǫ:nih External Relations Committee |
| Seneca | [Seneca Nation THPO](https://sni.org/culture/tribal-historic-preservation-office/) (Mary Jemison is Seneca material); the Tonawanda Seneca Nation; the [Seneca-Cayuga Nation](https://sctribe.com/seneca-cayuga-cultural-historic-preservation-program) |
| Cayuga and Tuscarora | the Cayuga Nation and the Tuscarora Nation (both on the [NY State Parks consultation list](https://parks.NY.gov/documents/inside-our-agency/PublicDocuments/GuidancePolicies/ConsultationofIndianNationsTribes.pdf)) |
| Oneida | the Oneida Indian Nation's [Shako:wi Cultural Center](https://mohawkvalleymuseums.us/?p=2364); the [Oneida Nation, Wisconsin](https://oneida-nsn.gov/wp-content/uploads/2016/04/ONEIDA-CULTURAL-HERITAGE-DEPARTMENT-9.13.pdf); the Oneida Nation of the Thames (M) |
| Kanien'kehá:ka | the [Saint Regis Mohawk Tribe THPO](https://www.srmt-nsn.gov/programs/tribal-historic-preservation-office) (Akwesasne); Kahnawà:ke's [Language and Cultural Center](https://www.korkahnawake.org/about) (James Smith's adoptive family were Kahnawake people); Kanesatake and Tyendinaga (M) |
| Six Nations of the Grand River | Six Nations Polytechnic, the Deyohahá:ge: Indigenous Knowledge Centre; the [Woodland Cultural Centre](https://www.cbc.ca/1.7597299) |

#### 4.8 lenape

On the Susquehanna and in the Ohio country by the 1750s.

| Nation | Office | Note |
|---|---|---|
| Delaware Tribe of Indians | [Historic Preservation Office](https://dthpo.delawaretribe.org/) | H |
| Delaware Nation, Anadarko | [Cultural Preservation](https://www.delawarenation-nsn.gov/tag/thpo) (THPO re-established 2022) | H |
| Stockbridge-Munsee Community | [THPO, Williamstown](https://williamsrecord.com/455194/news/this-is-our-homeland-stockbridge-munsee-historic-preservation-office-establishes-itself-in-williamstown) | H; also the Mohicans at Tullihas |
| Delaware Nation at Moraviantown | [Moraviantown](https://en.wikipedia.org/wiki/Delaware_Nation_at_Moraviantown) | M; the most direct office for the Moravian sources (Zeisberger, Loskiel, Heckewelder) |
| Munsee-Delaware Nation | — | M |

The Delaware Tribe and the Delaware Nation do not work with state-recognised or unrecognised groups that claim to be Lenape. Start with the recognised nations and ask them how to handle other groups.

`fur_mantle` cites Lenape robes.

#### 4.9 shawnee

Towns of the Ohio country and the Susquehanna. The three federally recognised tribes (H):
- the [Shawnee Tribe THPO](https://shawnee-nsn.gov/news/maalaakwahi-keneemepe-thpo);
- the [Eastern Shawnee Tribe](https://estoo-nsn.gov/?p=1078);
- the [Absentee Shawnee Tribe](https://www.absenteeshawneetribe-nsn.gov/cultural-preservation).

Show them first:
- `ew_head_wrap` (Shawnee men, 1773: the only garment tied to a named nation);
- `nose_jewel_silver`;
- the ear bobs;
- the hair styles.

#### 4.10 wabanaki

Abenaki, Penobscot, Maliseet, Mi'kmaq and Passamaquoddy.

| People | Office | Note |
|---|---|---|
| Abenaki (Odanak, Wôlinak) | the [Bureau du Ndakina](https://www.usherbrooke.ca/actualites/evenements/details/45946) of the Grand Conseil de la Nation Waban-Aki, mandated for consultations since 2013; the [Musée des Abénakis](https://www.musees.qc.ca/en/discover-museums/museums-of-quebec/abenaki-museum/) | H; first for the *Taken In* storyline |
| Penobscot | [Penobscot Nation THPO](https://penobscotnation.org/departments/cultural-historic-preservation/historic-preservation) | H |
| Passamaquoddy | [the THPO](https://wabanaki.com/thpo_officer/) and the Waponahki Museum | H |
| Wolastoqiyik (Maliseet) | the Houlton Band and the Wolastoqey communities in Canada | M |
| Mi'kmaq | the [Mi'kmaq Nation, Maine](https://members.nathpo.org/thpodirectory/Details/mi-kmaq-nation-previously-aroostook-band-of-micmacs-1657408); [Kwilmu'kw Maw-klusuaqn](https://mikmaqrights.com/?p=1184) | H |
| Collections (not a substitute for the nations) | the [Abbe Museum](https://abbemuseum.org/archaeology) | — |

Odanak and Wôlinak publicly reject Vermont's state-recognised "Abenaki" groups (H). Contact the Québec band councils directly.

### 4.11 west_african

Akan, Yoruba, Igbo, Mande, Wolof and others.

**In the valley and at Landfall they wear the colonial set** (the african_american list). Newly arrived Africans were put into issued colonial clothing almost at once. What they kept shows in adornment: beads at the arms and neck (New York, 1763), pierced ears, and their own hair styles. The homeland outfits below are for an origin choice, a flashback, or a scene set in Africa.

**Two looks for men:**
- **A:** Gold Coast and the Bights: a wrapper and a shoulder cloth.
- **B:** Senegambian Muslim and notable men (Mande, Wolof, Fula): a tunic and wide trousers.

**Basic (homeland):** men `wrapper_knee`; women `wrapper_long` + `mantle_upper_wrap`. Bare feet are a real option (feet "-"): even a notable "had no Shoes nor Stockings" (Moore).

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| A: `wrapper_knee` | legs.lower {30, 35} | §3: hem 0.44 ("a Cloth round their Middles, which came down about their Knees") | strip cotton, a seam every 0.15–0.18 m (Senegambia; narrower on the Gold Coast) · `cotton_white`*, `indigo_mid` to near-black, blue-and-white stripes and checks; Indian "guinea cloth" on the coast | wrap_skirt | H | [AF-A2], [AF-A5] |
| A: `mantle_one_shoulder` | accessories.wrap 50 | §3 ("another Cloth over their right Shoulder (the Men having generally one Arm bare)"); style `plaid` for the Igbo (M) | as the wrapper | drape | H | [AF-A2], [AF-A4] |
| `skullcap` | head 80 | §3; optional feathers or a goat-tail tuft (zone 1) as a status mark | white or indigo cotton | soft_cap | H | [AF-A2] |
| B: `west_african_trousers_wide` | legs.lower {30, 35} | trousers `wide`: a drawstring band at 1.00–1.03; about 6.4 m of cloth gathered in at the top ("about seven Yards wide, gather'd round the middle"); ease about 0.09, folds 0.02; crotch about 0.62; hem 0.44, open, about 0.65 round; tag `pants` | cotton · `cotton_white`*, `yellow`, `indigo_mid` | trousers | H | [AF-A2] |
| B: `west_african_tunic` | outer 40 | tunic: an unfitted T, about 1.25 m round; hem 0.46; sides open from the hem to 0.80; wide open sleeves to t 0.55, 0.60–0.80 round at the cuff; a round neck with a 0.10 front slit; bound edges (zone 1) ("a Garment like a Surplice … no lower than the Knees") | white strip cotton; blue-and-white broad stripe | tunic | H | [AF-A2], [AF-A3] |
| B: `sandals_leather` or bare feet | feet 40 | §3 | leather | sandal | M-H | [AF-A2] |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `wrapper_long` (2 layers optional) | legs.lower {30, 35} | §3 (hem "as low as the small of their legs") | as the men's | wrap_skirt | H | [AF-A1], [AF-A2] |
| `west_african_fillet` | accessories.waist 60 | sash: a cloth "about half Ell broad and two Ells long" (about 0.34 × 1.4 m, if the Dutch ell is meant) folded to about 0.08 and tied round the wrapper, both ends hanging | red wool · `stroud_red`, `scarlet` | sash | H Gold Coast c. 1700; M 1750s | [AF-A1] |
| `mantle_upper_wrap` | accessories.wrap 50 | §3 (women did not leave an arm bare) | cotton; silk | drape | M-H | [AF-A1], [AF-A2] |
| `head_band`, style `knot_back` | head 80 | §3 ("Slips of blue or white Cotton-Cloth … leaving their Crowns bare") | `cotton_white`*, `indigo_mid` | head_wrap | H | [AF-A2] |

Waist beads, coral, gold and anklets are jewellery, not garments.

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man (Gold Coast): `wrapper_calf` from the navel (top 1.06, hem 0.28) + `mantle_one_shoulder` style `large` + `sandals_leather` | — | §3 | velvet, silk, perpetuana; silk-and-cotton strip cloth | wrap_skirt, drape | M-H | [AF-A1], [AF-A6] |
| man (Senegambia): `west_african_tunic` in fine white cotton (or a blue-white striped worsted with fine linen sleeves) + `west_african_trousers_wide` + a white `skullcap` + `sandals_leather` ("slippers"); gold earrings | — | above | fine cotton | tunic | H | [AF-A2], [AF-A3] |
| woman (Gold Coast): `wrapper_long` (hem 0.10) in silk or Indian cotton + `west_african_fillet` with gold or silver lace + a silk `mantle_upper_wrap`; gold and coral | — | §3 | silk, Indian cotton | wrap_skirt | M-H | [AF-A1] |
| woman (Saint-Louis, Senegal, 1758): `west_african_robe` | outer 40 | tunic: as `west_african_tunic`, but hem 0.10, worn over a wrapper, with `sandals_leather`; gold earrings, necklaces and bracelets | "exceeding white cotton … wove into narrow slips of six or seven inches" | tunic | H | [AF-A3] |

**Noted, not playable:**
- Bosman's deerskin cap with a coral string and a staff marks an office: a headman role only.
- Islamic gris-gris amulets (leather packets of written verses).
- "Fetiche" gold ornaments.
- Kente is Asante elite cloth. Rømer (1760) describes cotton bands "three fingers wide"; full silk kente is late 18th to early 19th century.
- Adinkra is mourning cloth, first dated 1817: not for the 1750s.

**Gap:** the Yoruba of Oyo are not covered. Do not fill the gap with the 19th-century agbada and aso-oke.

**Avoid:**
- kente or adinkra as generic "African" cloth;
- leopard skins and "tribal" paint;
- the dashiki (20th century);
- the tall conical signare headdress (19th-century imagery).

### 4.12 central_african

Kongo, Soyo and Mbundu. In the colonies they wear the colonial set, as west_african does.

**Basic (homeland):** men `wrapper_knee` (raffia); women `wrapper_long` + `mantle_upper_wrap`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `wrapper_knee`, raffia preset | legs.lower {30, 35} | §3: one row of 3–4 standard panels 0.52 × 0.52 m sewn side by side; top 1.00, hem 0.48 (one panel deep); vertical seams every 0.52 | raffia · `straw`*, `tukula_red`*, `logwood_black` | wrap_skirt | H garment; M panel layout | [AF-C3], [AF-C4] |
| `belt_cord` | accessories.waist 60 | §3 | cord, raffia, leather | belt | M | [AF-C4] |
| `mantle_one_shoulder` | accessories.wrap 50 | §3 | raffia or cotton | drape | M-L for commoners | [AF-C1] |

Head bare: a 17th-century Capuchin text calls them "almost bald". Feet bare.

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `wrapper_long` | legs.lower {30, 35} | §3: waist 1.03 to hem 0.12; about 2.0 × 0.95 m (two panel rows less a fold) | raffia, Angolan or imported cotton | wrap_skirt | M-H | [AF-C3], [AF-C4] |
| `mantle_upper_wrap` | accessories.wrap 50 | §3 | raffia, cotton | drape | M | [AF-C1] |
| `mantle_back_carry` (optional) | accessories.wrap 50 | §3 | cotton | drape | M | Cavazzi 1687 |

Anklets ("in four pairs") are jewellery.

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man (Kongo noble; Soyo, c. 1740–50, the d'Asti watercolours): `wrapper_long` with a fringed hem (zone 3) | legs.lower | §3 | "fine raffia cloth or silk brocade", or "a cotton wrapper checkered in blue and red" | wrap_skirt | H | [AF-C1] |
| man: a red `sash` + a red or blue European coat (`frock_coat` (x) or `coat_skirted` (x), `scarlet`) | waist · outer | as built. d'Asti shows the coat hung from the shoulder, which needs a draped variant. | wool | sash, coat | M-H / M | [AF-C1] |
| woman: `wrapper_long` in Indian cotton or silk + a fine `mantle_upper_wrap`; coral beads | — | §3 | Indian cotton, silk | — | L-M | [AF-C1], [AF-C3] |

**Noted, not playable (Christian elite regalia, from Lopes in 1591 to d'Asti in the 1750s):**
- the folded animal pelt at the waist (`pelt_front`);
- the mpu cap and the nkutu net;
- the Order of Christ insignia, crosses and rosaries;
- the church *mestres'* white shoulder cloth.

**Gap:** Mbundu and Luanda.

**Avoid:** Kuba cloth (another region, documented later).

### 4.13 african_american

Colonial-born people of African descent, free and enslaved. They lived in Albany, Schenectady and on the valley's estates, and among the free Black sailors of Vessary's Landfall.

**Evidence:** a tally of Virginia Gazette runaway ads, 1755–75 (mostly 1766–75), plus New England and New York ads. **Certainty is M until the New York and New Jersey ads are read** (Hodges & Brown, *"Pretends to Be Free"*, 662 ads; not yet consulted).

**New York presets use** linsey-woolsey, tow cloth, osnaburg, kersey and duffel. They do not use the Chesapeake "Virginia cloth" or the napped woollen the ads call by a racial name.

**Basic:** as now.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_linen` (x) or `shirt_check` (x) | shirt 10 | as built | osnaburg or tow · `tow`, `linen_unbleached`; check. "An osnabrug shirt" is the commonest phrase. | — | H | [AF-N1] |
| `jacket_short` | outer 40 | §3 | kersey, linsey, duffel · `undyed_white_wool`*, `stroud_blue`, `madder_red`, `copperas`* stripes | jacket | H garment | [AF-N1], [AF-N9] |
| `breeches` (x) or `trousers_long` | legs.lower 30 | as built / §3 | leather, osnaburg, kersey; check | — | H ("jacket and breeches" 47 times, "shirt and trousers" 38) | [AF-N1] |
| `round_hat` (x) in felt, or `monmouth_cap` (r) / `tuque_knit` (x) | head 80 | as built | felt; knit · `scarlet`, `stroud_blue` ("a red Cap", Deerfield 1749) | — | H | [AF-N1], [AF-N2] |
| `stockings` (x) · `shoes_tied` (or bare feet) | legs.over · feet | as built / §3 | yarn, worsted · white, grey, blue (Rhode Island ads, 1760–83: all runaways) | — | H | [AF-N3] |
| `neckerchief` (x) · `veste_sleeved` (x) or `waistcoat_sb` (x) (optional) | neck · vest | as built | striped silk, check; homespun | — | M / H | [AF-N1] |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shift_linen` (x) | shirt 10 | as built | osnaburg | — | H | [AF-N1] |
| `petticoat` (x) | legs.lower 30 | as built | linsey stripes; osnaburg; green penistone ("Sal", New York 1766); blue halfthick; red flannel · `ranger_green`, `stroud_blue`, `madder_red` | — | H | [AF-N1], [AF-N4] |
| `waistcoat_womens` (or `jacket_womens` (x)) | outer 40 | §3: the "waistcoat and petticoat" suit, "without skirts" | as the petticoat | jacket | H garment | [AF-N1], [AF-N6], [AF-N7] |
| `cap_linen` (x); `head_tie` optional, not the default | head 80 | as built / §3 | linen; check or silk handkerchief | — | M-H / M | [AF-N12] |
| `kerchief_womens` (x) · `apron` (x) | neck · waist | as built | white, check, red | — | H | [AF-N1] |
| `stockings` (x) · `shoes_tied`, or bare feet ("bare-footed and bare-legged", 1770) | legs.over · feet | — | — | — | H | [AF-N3] |

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man (a free tradesman, or a man in his own best clothes) | — | `frock_coat` (x) (blue, brown or "Russia drab", metal buttons) + `waistcoat_sb` (x) in red cloth + buckskin `breeches` + `shirt_ruffled` + worsted `stockings` + `shoes_buckled` (x) with silver buckles + `round_hat` or `cocked_hat` in beaver felt + a silk `neckerchief` | broadcloth, silk | — | H | [AF-N1], [AF-N2] |
| man (boatman or sailor; the story's free Black boatman) | — | `sea_jacket` (x), blue + `shirt_check` (x) + `slops` (x) ("Sailor's blue Jacket, Petticoat Trousers") + `round_hat` | wool, check | — | H | [AF-N1] |
| woman | — | `gown_open` or `gown_close_bodied` in calico, chintz or calimanco ("striped red, white and yellow"), or a calico jacket and petticoat; a red `petticoat_quilted`; stays "with fringed blue riband"; a silk `kerchief_womens`; `hat_flat_womens` (black silk or felt); `cloak_hooded` (red, or purple cloth); silver buckles, earrings, beads | calico, silk | gown | H | [AF-N1], [AF-N5] |

**Never made into garments:** iron collars. Livery was the enslaver's display: offer it only in story context.

**Avoid:**
- the 19th–20th-century headwrap-and-apron caricature as a woman's default look;
- minstrel-show exaggeration.

### 4.14 ethiopian

Amhara, Tigrayan and Oromo peoples of the highlands; the Gondar court of Iyoas I (1755–69). The outfits below are the Christian highlanders'.

**Basic:** men `drawers_short` + `ethiopian_shamma`; women `ethiopian_kamis` + `ethiopian_netela`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `drawers_short` | legs.lower 30 | §3: mid-thigh 0.68 (Bruce); knee style for Poncet's "Drawers of Cotton" | white coarse cotton · `cotton_white`* | trousers | H | [AF-E1], [AF-E2] |
| `ethiopian_girdle` | accessories.waist 60 | sash with no hanging ends: "a narrow web of cotton cloth, which they wind eight or ten times about their waist" (z 0.95–1.06, lift 0.035), tucked at the right hip; a crooked knife stuck in at the right is gear | coarse white cotton | sash | H | [AF-E2] |
| `ethiopian_shamma` | accessories.wrap 50 | drape, both shoulders: about 2.0 × 2.7 m (V&A 401-1869, c. 1860: 2.06 × 2.74 m), round the body and over the shoulders. Static variant: the edge drawn over the head ("nothing but his eyes could be seen"). Lowering it off the shoulders is a salutation: an animation note. | plain hand-spun white · `cotton_white`*. Coloured borders L-M for the 1760s. | drape | H | [AF-E1], [AF-E2], [AF-E3] |
| `ethiopian_tippet` (instead of the shamma) | accessories.wrap 50 | cloak, capelet: a goatskin to the elbow, about 0.40 deep, the hair outside, tied at the throat ("in form of what the women call a tippet") | goatskin · `drab`, `walnut_brown` | cloak | H | [AF-E2] |
| `sandals_leather` or bare feet | feet 40 | §3 | leather | sandal | M-H | [AF-E1] |

**Head bare** for Christian laymen (H). Bruce: wearing anything on the head was "an offence … unless for Mahometans … or for priests". **Muslim men** wear a `skullcap` with a large white `turban_common` (Bruce: H).

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `ethiopian_kamis` | shirt {10, hips 25} | tunic: white cotton to the ankle (hem 0.10), about 1.5 m round at the hem; long wide sleeves to the wrist, 0.45–0.60 round at the cuff; a round neck with a 0.12 slit. Proportions from the V&A kamis 400-1869 (1830–68): 1.24 m long, 1.57 m sleeve to sleeve. | cotton · `cotton_white`* | tunic | M-L for highland Christian women (it rests on Bruce's lowland Shiho women and an object of 1830–68) | [AF-E2], [AF-E3b] |
| `ethiopian_netela` | accessories.wrap 50 | drape, head and shoulders: the shamma's cloth over the head and shoulders | white cotton | drape | M-H | [AF-E1], [AF-E3] |
| `ethiopian_girdle` or a leather `belt` | accessories.waist 60 | above ("girt about the middle with a leather belt") | cotton, leather | sash, belt | M | [AF-E2] |
| `sandals_leather` or bare feet | feet 40 | §3 | — | — | M | — |

The hair (shuruba) is already in the creator.

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `ethiopian_vest_long` | outer 40 | tunic: a silk or fine cotton "Vest" with long sleeves; hem 0.15–0.25 ("his upper garment reached down to his ancles"); gold embroidery (zone 3) | silk · `cotton_white`*, `crimson`*, `indigo_mid` | tunic | H | [AF-E1], [AF-E2] |
| man: a fine `ethiopian_shamma` + `ethiopian_sash_silk` + `sandals_leather`; head bare | waist 60 | sash: red silk "about five yards long, with a silk fringe" (about 4.6 m), wound, the fringed ends hanging | red silk · `crimson`* | sash | H | [AF-E2] |
| woman: `ethiopian_kamis` style `sleeved` | shirt | tunic: silk or "very fine Calico, with large Sleeves which hang down to the Ground" (cuff about 1.0 m round); embroidered neck and cuffs (zone 1: L-M for the 1760s) | silk, fine calico | tunic | M | [AF-E1], [AF-E3b] |
| woman: a silk `ethiopian_netela`; hair "twisted, and set out with Rings"; silver jewellery | — | — | silk | drape | M | [AF-E1] |

**Noted, not playable:**
- the *mateb*, a blue silk neck cord that is "a badge of Christianity all over Abyssinia";
- priests' muslin turbans;
- the king's or a governor's muslin fillet and the *kirn* horn (office);
- lion and leopard skins (trophies);
- Ras Michael's black velvet cloak with a silver fringe (`cloak_pallium`).

**Gaps:**
- Oromo dress (the Gondar court was strongly Oromo-influenced†).
- Muslim (Jabarti) dress beyond the cap and turban.
- Prutky, who was in Gondar in 1752: read him.

**Avoid:** the lion-mane cape as generic Ethiopian dress.

### East Asia: rules for all three peoples

- **Left over right, always (H).** The left front lies on top, so its edge sits on the wearer's right (x < 0), like `CAPOT.overlap`. In Japan, right over left is how the dead are dressed: never offer it.
- **Socks and gaiters.** Socks (the tabi, the beoseon, Chinese cloth socks) are a sock zone inside each footwear entry, so `legs.over` stays free for gaiters.
- **Movement.** Ankle-length robes and hanging sleeves clip when running or aiming.
  - Long men's robes split at the front overlap below 0.86.
  - Long skirts use the petticoat's closed six-panel skirt.
  - The tucked-up kosode and the tasuki cord are period fixes that make good gameplay variants.

### 4.15 japanese

Mid-Edo townspeople and farmers of the Hōreki era (1751–64). The eyewitness is Thunberg (1775–76), 10–25 years late.

**Sumptuary law.** The shogunate often banned townspeople from silks and other "extravagant fabrics" (H). "Except tsumugi pongee" is M. For peasants, cotton and hemp were the rule†. Commoners wore plain colours, small prints and vertical stripes in browns, greys and indigo, with bright linings hidden inside.

**Obi.** The obi is joined into each kosode as its own zones, because a kosode is never worn without one. That leaves `accessories.waist` free for the apron.

**Basic:** men `japanese_kosode` (the obi included) with `legs.lower` "-"; women `japanese_kosode_womens`.

**Men, everyday** (townsman, artisan, farmer)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `japanese_kosode` | shirt {20, hips 35, thighs 35} | robe `crossed` + hanging sleeve. **Body:** a straight T from loom-width panels (0.34–0.36). The top panel's edge sits at x ≈ −0.10 at the waist; the V runs down to 1.15; split below 0.86. **Collar band:** 0.055 wide, raised 0.003, from the nape down to 0.70, with a 0.012 white or pale blue undercollar strip. **Hem:** 0.08–0.10 ("to the heels"); ease 0.022, flare 0.04. **Sleeves:** sewn to the body, ending at t 0.88; the bag hangs about 0.20 below the forearm, its lower corner rounded. **Obi zones:** a *kaku-obi* a hand's breadth wide (0.09–0.10) at z 0.92–1.01, wound twice, knotted at the back (0.08 × 0.04 × 0.025, ends 0.08). | cotton; unlined hemp in summer; lined or padded in winter · `stroud_blue`, `indigo_mid`, `asagi`*, `rokocha`*, `slate_grey`, `logwood_black`; vertical stripes, checks | robe | H form and cloth; M measurements | [EA-J1], [EA-J2], [EA-J4] |
| `japanese_kosode_short` (labourers) | shirt, as above | style: hem 0.45, to the knee. Variant `tucked`: the back hem tucked into the obi (`hem_by_angle(0.45, 0.55, 0.75)`). | as above | robe | H | [EA-J1] |
| `japanese_momohiki` | legs.lower 30 | trousers `breeches`: close fitting, from the waist (1.02) to the ankle (t 0.97, about z 0.10), ease 0.007; waist ties as a narrow zone; tag `pants` | `indigo_mid` cotton; hemp in the north | trousers | H existence; M fit | [EA-J1] |
| `japanese_hanten` | outer 40 | JACKET + a collar band raised the whole height of the opening: hip length (hem 0.80); open edge to edge (half-width 0.04 at the chest, 0.06 at the hem); collar band 0.06 down the whole front, often black; tube sleeves to t 0.75, ease 0.02 | thick indigo cotton, sometimes stitched (sashiko); an optional shop mark on the back (an invented mark) | jacket | M (the firemen's form is late Edo) | [EA-J11] |
| `japanese_haragake` (craftsmen) | vest 20 | apron `bib`: a bib 0.36–0.40 wide from 1.32 to 0.78; a belly pouch 0.30 × 0.12; straps crossing at the back, ties at the back waist | indigo or black cotton | apron | M | [EA-J11] |
| `head_band` (*tenugui*) | head 80 | §3: a cloth about 0.90 × 0.34 folded to a band 0.04–0.05, knotted at the front or side | white; indigo with a stencil pattern (`komon`) | head_wrap | H | [EA-J1] |
| `japanese_sugegasa` (journeys, fishermen) | head 80 | rigid_hat `CONE`: 0.46 across, 0.12 high; an inner head ring at `hats.CROWN_P`; chin cords. Otherwise men went bare-headed. | sedge · `straw`* | rigid_hat | H | [EA-J1] |
| `japanese_zori` · `japanese_waraji` (travel) · `japanese_geta` (rain) | feet 40 | sandal. **zori:** a woven sole with a toe thong. **waraji:** a rice-straw sole 0.24 × 0.095 × 0.010 with a toe thong, side loops and straw cords tied round the ankle. **geta:** a wooden sole 0.22 × 0.09 × 0.015 with two teeth 0.06 high. Bare feet are also usual. | straw; wood · `straw`*, `wood`* | sandal | H | [EA-J1] |
| `gaiter_tied` (*kyahan*) · `japanese_tekko` | legs.over 30 · accessories.hands | §3 · hand_cover: from t 0.55 over the back of the hand, with a finger loop | `indigo_mid` cotton | — | H · M | [EA-J1] |

Also noted, not built now:
- the straw rain cape (*mino*) and the oiled-paper rain cloak;
- the `loincloth` as *fundoshi*: the labourer's base layer, tagged `pants`.

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `japanese_kosode_womens` | shirt {20, hips 35, thighs 35} (closed-skirt panels) | robe `crossed` + hanging sleeve. **Body:** hem 0.04–0.06 (to the feet); the V crosses higher and closer, at 1.18; collar band to 0.65. **Sleeves:** detached below the shoulder, 0.48–0.55 deep, ending at t 0.90. **Style `furisode`:** sleeves 0.65–0.80 deep, for unmarried women (married women also wore long sleeves in the 1770s). **Obi zones:** 0.27 wide at z 1.00–1.27, twice round; a flat bow knot 0.26 × 0.12 × 0.06, ends about 0.20; at the back by default, with a front variant (Thunberg: married women tied in front; Kyoto archives: merchant wives in front). | cotton or tsumugi; stripes, checks, small stencil prints · `indigo_mid`, `rokocha`*, `slate_grey`; a `beni`* lining showing at the hem | robe | H form; M measurements and knot | [EA-J1], [EA-J3], [EA-J4], [EA-J6] |
| `apron_flat` (*maekake*) | accessories.waist 35 | §3: panel 0.45–0.50 wide, hem 0.40 | `indigo_mid` cotton | apron | H | [EA-J6] |
| `japanese_kosode_tasuki` | shirt | a kosode style: the sleeve bag shortened and tied back by a thin cord (0.012) crossing in an X at the back | cord · `madder_red`, `indigo_mid` | robe | H | [EA-J12] |
| `head_cloth_womens` (*anesan-kaburi*) | head 80 | §3 | white or indigo cotton | soft_cap | M | — |
| `japanese_zori` · `japanese_waraji` · `japanese_geta` · bare feet | feet 40 | above | — | sandal | H | [EA-J1] |

**Farm woman:** `japanese_kosode_short` + tasuki + `japanese_tekko` + `gaiter_tied` + `japanese_sugegasa` (M). Avoid monpe trousers for 1750s central Japan: they are later and northern.

**Better-off** (a merchant and his wife)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `japanese_kosode` in tsumugi, lined, with 3 or 5 crests | shirt | above | pongee, plain dark colours or fine stripes; generic crest decals | robe | M | [EA-J1] |
| man: `japanese_haori` | outer 40 | robe `open` + hanging sleeve: hem 0.95–1.00 ("reaches only to the waist", Thunberg), with a 0.85 variant; open front, the collar turned back 0.05; tied with two cords at 1.12; side gussets; sleeves as the kosode; five crests about 0.04 across (centre back at 1.30, the back of each sleeve, each breast at x ±0.11, z 1.25) | thin silk or gauze, most often black, sometimes green · `logwood_black`, `moegi`*; plain outside with a richly patterned lining | robe | M | [EA-J1], [EA-J7] |
| man: `japanese_hakama` (formal visits only) | legs.lower, layer 38 (over the kosode) | trousers `hakama`: to the ankle (0.08), sewn between the legs; 5 front pleats and 2 back; open at the sides two-thirds of the way down; a back board under 0.15 tall | hemp, striped brown or green, or plain black | trousers | M | [EA-J1] |
| man: a white tabi sock zone under fine rattan `japanese_zori`; a tobacco pouch with a netsuke toggle on the obi (hardware). No swords for commoners. | feet | — | — | — | H / M | [EA-J1] |
| woman: `japanese_kosode_womens` in plain silk or tsumugi **with a rich hidden lining** (default), sleeves 0.60–0.75, a red padded hem roll; obi 0.28–0.30 of damask or brocade, knotted at the back or the front; white tabi; lacquered geta | shirt, feet | above | silk; lining in `beni`* | robe | M | [EA-J1], [EA-J6] |
| woman, variant: crepe or figured satin dyed with yūzen pictures on the lower half and sleeves. The edicts forbade gold thread, embroidery and all-over tie-dye for townspeople, so this is "worn against the edicts". | — | — | — | — | M-L | [EA-J4] |

**Noted, not playable:**
- the kamishimo (formal homage dress);
- the unbelted over-robe (*uchikake*: weddings, the upper class, courtesans);
- Buddhist and Shinto clergy robes; pilgrims' whites; the white dress of the dead;
- the samurai's two swords;
- Tokugawa or imperial crests (the hollyhock, the chrysanthemum, the paulownia).

The Ainu are a separate people and need their own research.

### 4.16 chinese

Han commoners of the Qing, in the Qianlong era, of Jiangnan and Canton. The eyewitness is Osbeck (Canton, 1751: H). Visual sources: Xu Yang's *Prosperous Suzhou* (1759) and the Southern Inspection Tour scroll (1764–70). Most people wore cotton; museum collections are mostly elite silk.

**White reads as mourning:** keep it for undergowns and trousers, never for a whole outer outfit, a head cloth or shoes. The queue stays visible under every cap. There are no standing collars in the 18th century (M).

**Basic:** men `chinese_duanshan` + `chinese_ku`; women `chinese_ao` + `chinese_ku`.

**Men, everyday** (labourer, boatman, artisan)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `chinese_duanshan` | shirt {20, hips 35} (over the trousers) | robe `side_fastened`, short. **Neck:** a flat T with no shoulder seam; round and collarless (a 0.085, b 0.078, z0 1.335). **Front:** the right-front overlay curves from the neck (0, 1.31) to the right armpit (−0.13, 1.22), then down the right side. **Toggles:** five, r 0.006, at z 1.31, at (−0.07, 1.27), and at 1.21, 1.08 and 0.95. **Hem:** 0.78–0.82, side slits 0.10. **Sleeves:** to the wrist (t 0.95; t 0.80 for labourers), ease 0.025 rising to 0.04 at the cuff. Body ease 0.018. | cotton · `stroud_blue`, `indigo_mid`, `logwood_black`, `pale_buff` (nankeen); ramie or hemp in a southern summer | robe | H form; M measurements | [EA-C1], [EA-C2] |
| `chinese_ku` (men and women) | legs.lower 30 | trousers `wide`. **Waist:** top 1.06, a folded white waist panel 0.12 deep (zone 1), tied with a cord. **Crotch:** 0.06. **Legs:** ease 0.045 at the thigh, 0.04 at the hem; hem at t 0.95. Labourers roll them to t 0.75; an optional ankle band at 0.10–0.12. Tag `pants`. | cotton · `cotton_white`*, `indigo_mid`, `logwood_black` | trousers | H ("wide and white, tied at the waist and the knees") | [EA-C1] |
| `chinese_yaodai` | accessories.waist 60 | sash: a cotton band 0.08–0.10 at z 0.98–1.06, knotted at the front left, ends 0.25. Optional tobacco bag and purse on cords to the knee (hardware). | `stroud_blue`, `logwood_black` | sash | M-L (H for the hanging pouches) | [EA-C1] |
| `chinese_douli` | head 80 | rigid_hat `CONE`: 0.50–0.60 across, 0.10–0.14 high; split-bamboo lattice with leaves between; a coloured rim binding (zone 1) | bamboo · `bamboo`*, `straw`* | rigid_hat | H | [EA-C1], [EA-C7] |
| `chinese_cloth_shoes` · `chinese_straw_sandal` · bare feet (the poor) | feet 40 | slipper: a black cotton upper with a low vamp and a blunt toe, no heel; a white layered-cloth sole 0.015–0.020 thick ("as thick as one's finger"); a white sock zone to 0.30 · sandal: straw | cotton · `logwood_black`; straw | slipper, sandal | H | [EA-C1] |
| `gaiter_tied` (*bangtui*) | legs.over 30 | §3, with a diagonal-stripe texture | `stroud_blue`, `logwood_black` | leggings | L-M (better attested in the 19th century) | — |

**Women, everyday** (boat, farm or town)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `chinese_ao` | shirt {20, hips 35} | robe `side_fastened`: hem 0.60–0.70; wide sleeves to t 0.97, cuff ease 0.05; collarless; a narrow edge binding 0.01–0.02 (zone 1). The broad embroidered borders are later (L). | cotton · `stroud_blue`, `indigo_mid`, `logwood_black`, green | robe | M | [EA-C1] |
| `chinese_ku` | legs.lower 30 | above | above | trousers | H ("dressed like men in coat and trousers") | [EA-C1] |
| `apron_flat` (*weiqun*) | accessories.waist 35 | §3: band at 1.02, 0.55 wide, hem 0.45 | `indigo_mid` | apron | M-L | — |
| `head_band` (forehead band, style `knot_back`) | head 80 | §3: black satin 0.04–0.06, tied at the back; mostly older women, and in winter | `logwood_black` satin | head_wrap | M | — |
| `chinese_douli` (field and boat work) · `chinese_cloth_shoes` (women's style, with an embroidered upper zone) or bare feet and straw sandals | head · feet | above | — | — | H / M | [EA-C1] |

The hair, knotted on top with a long silver pin, belongs to the hair system.

**Foot binding** crossed classes in Jiangnan†, and was absent among Cantonese boat women and the Hakka. Build only ordinary shoes. No bound-foot shoes.

**Better-off** (a merchant or gentleman and his wife)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `chinese_changpao` (the long gown, also called *paozi*) | shirt {20, hips 35, thighs 35} | robe `side_fastened`, long: hem 0.12–0.15; two side slits to about 0.45; sleeves past the wrist (t ≈ 1.05) to cover the hands, cuff ease 0.05; unlined; five gilt ball buttons; a white inner gown shown at the hem and cuffs | silk or cotton · purple (`logwood_plum`) or black outer; `cotton_white`* inner | robe | H (two wide robes, "the under one white and the outer purple or black") | [EA-C1] |
| man: `chinese_magua` or `chinese_majia` | outer 40 · vest 20 | **magua:** JACKET, waist length (hem 0.92), open at the centre front, 5 buttons from 1.31 to 0.95, collarless, short wide sleeves (t 0.80, ease 0.035). **majia:** WAISTCOAT, collarless and sleeveless, straight hem at 0.95, 5–7 buttons, no pockets. | silk · `logwood_black`, `stroud_blue`, `logwood_plum` | jacket, waistcoat | M | [EA-C7] |
| man: `chinese_guapimao` | head 80 | soft_cap `skullcap`, gored: six gores, a velvet brim band 0.012, a plain silk knot on top; edge at the hairline (60–70°), ease 0.010; the queue stays visible | black silk · `logwood_black` | soft_cap | H-M | [EA-C1], [EA-C7] |
| man: boot-like dark silk stockings (a sock zone) with embroidered edges; `chinese_cloth_shoes`; a fan and a pouch | feet | — | silk | — | H | [EA-C1] |
| woman: `chinese_ao` in silk, knee length (0.50), with cuff and edge bands 0.03 | shirt | above | silk | robe | M | — |
| woman: `chinese_mamianqun` (Han women only) | legs.lower, layer 32 (over the trousers; the trousers become an inner zone, or the skirt takes `alt_slots`) | wrap_skirt: two overlapping panels, each with a flat front panel 0.25–0.30 wide and pleated sides; a plain cotton waistband (zone 1); ankle length (0.06–0.10) | silk · `stroud_blue`, green, `logwood_black` for daily wear; red for festivals only | wrap_skirt | M | [EA-C7] |

**Noted, not playable:**
- officials' hats with rank finials and feathers, rank badges and court robes;
- imperial bright yellow; five-clawed dragons;
- wedding red, the phoenix crown and the cloud collar;
- white mourning bands;
- Buddhist and Daoist robes.

Manchu women's dress belongs to another people.

**Avoid:**
- one "Asian hat" mesh, and the term "coolie hat";
- standing mandarin collars;
- the 20th-century qipao.

### 4.17 korean

Joseon commoners in the reign of King Yeongjo (1724–76).

**Evidence:**
- Genre painting turned to commoners in the 18th century.
- A study of the paintings counts women's jackets as 39.8% white and 18.3% jade, and skirts as 34.4% deep blue and 20.4% jade.
- Commoners wore white cotton. The upper class wore ramie and silk. Repeated bans on white clothing were mostly ignored.

**Basic:** men `korean_jeogori_mens` + `korean_baji`; women `korean_jeogori_womens` + `korean_chima`.

**Hair.** Adult men always wore a horsehair headband (manggeon) under the topknot. Build a Korean **`hair_sangtu`** with the manggeon as a black mesh zone. The shared `hair_topknot` cannot take it: it is listed for six peoples. Unmarried men wore a braid, with no topknot, no manggeon and no gat†.

**Men, everyday** (farmer, artisan)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `korean_jeogori_mens` | shirt {20, hips 35} | robe `crossed`, short. **Front:** left over right, the overlap edge at x ≈ −0.07; the V down to 1.20. **Collar band:** 0.045–0.05, raised 0.003 (zone 1), with a white strip 0.012 on top (the *dongjeong*, zone 3). **Ties:** one pair of short narrow ties at the right breast (−0.06, 1.15), ends 0.20–0.25 × 0.025. **Body:** hem 0.84 (the hip line); closed sides. **Sleeves:** to t 0.97, ease 0.015–0.02. | white cotton, hemp, summer ramie; quilted in winter · `cotton_white`*, `jade_green`* (L) | robe | H form; M length | [EA-K4], [EA-K9] |
| `korean_baji` | legs.lower 30 | trousers `wide`: the waist folded and cord-tied at 1.02–1.05; a very deep crotch with gussets (drop 0.12–0.18, crotch at about 0.65–0.72); legs ease 0.07 at the thigh, 0.05 above the tie; ankle ties (*daenim*), a band 0.03 at z 0.10–0.13 knotted at the inner ankle, the folds bunching above it; tag `pants`. **Style `jambangi`:** knee length (0.45), no ties (M). | white cotton; single, lined, quilted or padded | trousers | H form; M-L crotch depth | [EA-K4] |
| `gaiter_tied` (*haengjeon*) | legs.over 30 | §3, with two straps tied below the knee; in place of the ankle tie; worn by all classes for walking | coarse white cotton | leggings | H | [EA-K4] |
| `korean_juui` (the commoners' outer robe) | outer 40 | robe `crossed`, long: closed sides with gussets; narrow sleeves; a collar band with the white strip; ties on the right; hem about 0.30 | cotton · white, `slate_grey`, `indigo_pale`* | robe | H form; M for its prevalence in the 1750s | [EA-K4] |
| `korean_paeraengi` (workers) | head 80 | ROUND_HAT style: loosely woven bamboo strips; a rounded crown 0.07–0.08 high, clearly separate from the brim; brim_r 0.17–0.20. Farmers at work were often bare-headed with the manggeon (L). | bamboo · `bamboo`* | rigid_hat | H form; M measurements | [EA-K3] |
| `korean_jipsin` | feet 40 | sandal: a woven sole with side loops and a cord round the heel and over the instep; over a *beoseon* sock zone (white padded cotton, top at 0.18–0.22, pointed upturned toe). **Style `mituri`:** a finer hemp-cord sandal. | straw, hemp cord · `straw`*; `cotton_white`* sock | sandal | H existence; M sock | [EA-K4] |

**Optional:** `korean_tosi` (forearm warmers: hand_cover from t 0.55 to the wrist; padded cotton in winter, bamboo in summer; M-L). A pouch on a cord at the waist.

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `korean_jeogori_womens` | shirt, layer 36 (over the skirt band; the report's 20 put it under) | robe `crossed`, short. **Body:** 0.29 long at the back (Madam Yoon's jacket, 1735–54: 29 cm long, 138 cm across the sleeves), so the hem sits at about 1.10, over the top of the skirt band; a tight fit, ease 0.006. **Sleeves:** narrow and straight, small armholes, to t 0.98, ease 0.005. **Collar:** band 0.04 in the *dang-ko* style, with the white strip 0.012. **Ties:** at (−0.05, 1.20), ends 0.35–0.45 × 0.04 (M). | white cotton, hemp, ramie · `cotton_white`*, `jade_green`* | robe | H | [EA-K1], [EA-K2] |
| `korean_chima` | legs.lower 30 (closed-skirt panels) | wrap_skirt: gathered into a white waistband 0.10 tall at z 1.06–1.16, tied at the front right; commoners wrap it with the overlap at the back (the left side was a yangban privilege, M); hem at the calf, 0.22–0.28, for commoners; flare 0.22–0.28, folds 0.02. **Style `chima_lifted`:** hitched up into the band on one side (`hem_by_angle`, about 0.35 right and 0.25 left). The inner trousers (*sokbaji*) are an inner zone, white cotton, tagged `underwear`. | cotton, hemp · `stroud_blue`, `jade_green`*, white, `slate_grey` | wrap_skirt | H form; M commoner length | [EA-K2], [EA-K7] |
| `apron_flat` (*haengju chima*) | accessories.waist 35 | §3: a half-width panel 0.55–0.65 wide that does not wrap round; hem 0.40–0.50; taken off before elders | white cotton | apron | H existence; M size | [EA-K3] |
| `head_cloth_womens` | head 80 | §3 | white cotton | soft_cap | M | [EA-K6] |
| `korean_jipsin` | feet 40 | above | — | sandal | H | [EA-K4] |

The low bun with a long pin (`hair_jjok_f`) and the girl's braid are hair assets.

**Better-off** (yangban)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `korean_dopo` | outer 40 | robe `crossed`, long, + hanging sleeve: ankle length (0.12); very wide sleeves 0.50–0.60 deep (M-L); an inner flap over the back opening. **Style `jungchimak`:** side slits instead of the back flap. | ramie, silk · white, `jade_green`* | robe | M | [EA-K3] |
| man: `korean_sejodae` | accessories.waist 60 | sash: a cord 0.01, tied at z 1.15, its tassels hanging to the knee | silk cord | sash | M-L | — |
| man: `korean_gat` (*heungnip*) | head 80 | rigid_hat `GAT`: a cylinder crown narrowing to a flat top, 0.12–0.15 high, about 0.10 across at the top (M-L); a very wide, thin, flat brim 0.40–0.50 across (L: the only measured example is late 19th century, 31.5 cm overall); translucent; ribbon or bead chin strings about 0.35 long. From the later 18th century commoners wore it too. | lacquered horsehair or bamboo · `horsehair_black`* (HORSEHAIR kit) | rigid_hat | M | [EA-K3], [EA-K4] |
| man: `korean_taesahye` | feet 40 | slipper: leather covered in silk, with patterned lines at the toe and heel | silk, leather | slipper | M | — |
| woman: `korean_jeogori_womens` in silk, in the three-colour form (*samhoejang*): the collar, ties and cuffs in contrasting zones (e.g. a jade or yellow body, a purple collar and ties, indigo cuffs) + a floor-length `korean_chima` (hem 0.02) in deep blue or red silk, wrapped to the left, over layered underskirts (flare 0.30); silk shoes | — | above | silk | robe, wrap_skirt | H for the rule (often not kept, as the paintings show) | [EA-K2] |

**Noted, not playable:**
- the outdoor face-covering robe (*jangot*) and the skirt worn over the head (*sseugae chima*). These are gendered seclusion garments: later, and only with care.
- the large wigs (*gache*) that Yeongjo tried to ban;
- mourning dress, including the paeraengi worn in mourning;
- officials' robes, rank badges and hats; wedding robes;
- the dress of shamans, monks and gisaeng.

### 4.18 south_asian

Bengal, the Deccan, Gujarat and beyond, and the lascar sailors of East India ships.
- **The north** (Hindustan, Bengal, Rajasthan, Gujarat) is the default.
- **The south** (the Tamil country, the Deccan) and **Bengal** are presets.
- **The sari is not all-India dress:** northern women wore the ghagra, choli and odhni.

**Basic:** men `south_asian_dhoti` (shirt "-"); women `south_asian_ghagra` + `south_asian_choli`. In the south and Bengal: `south_asian_sari`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `south_asian_dhoti` | legs.lower 30 | trousers `draped`: a cloth about 4.5 × 1.15 m knotted at z 1.00–1.03; 5–7 front pleats hanging at the centre front to z 0.20; the back end tucked at the centre-back waist; thigh ease 0.04; hem 0.15–0.25; tag `pants`. **Style `kilted`:** hem 0.45, for labourers. | white or unbleached cotton with a red, black or indigo border (zone 1) | trousers | H | [SA7], [SA9] |
| `south_asian_chadar` | accessories.wrap 50 | drape, both shoulders: about 2.6 × 1.1 m over both shoulders, the ends down the front to 0.90, or one end thrown back over the left shoulder. The south's *angavastram* is a lighter preset. | white cotton; wool in winter | drape | H-M | [SA7] |
| `south_asian_pagri` | head 80 | head_wrap `turban`: a compact wound turban, the crown covered, 0.07–0.10 above the band, a little fuller at the back, outer surface 0.03 off the scalp. **Style `low`:** for the south. | cotton · white, `madder_red`, `crimson`*, `saffron`*, `indigo_mid`; `bandhani` dots for Rajasthan | head_wrap | M-H | [SA7], [SA10] |
| `south_asian_kamarband` | accessories.waist 60 | sash: a band 0.10–0.12, knotted at the front left, ends 0.30 | white or coloured cotton | sash | M | — |
| `south_asian_angarkha` (townsman, servant) | outer 40 | robe `under_arm`: the front crossing to a tie under the arm; a waist seam at 1.08; a gathered skirt, flare 0.18; hem 0.30–0.45 for every day (court examples of the late 1700s reach the floor); narrow sleeves to t 1.0, ruched | white cotton · `cotton_white`* | robe | M | [SA3] |
| `south_asian_jutti` | feet 40 | slipper: a closed vamp to the instep (top z 0.065), the heel crushed down, a pointed toe turned up a little (0.02–0.03). Bare feet were just as usual for labourers. | red, brown or black leather | slipper | M | [SA7] |
| south: `wrapper_long` (*veshti*) | legs.lower {30, 35} | §3: top 1.04, hem 0.10; or `wrapper_knee` (folded up double to 0.47) | white with a coloured or zari border | wrap_skirt | H | [SA7] |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `south_asian_ghagra` | legs.lower {30, hips 35, thighs 35} | `petticoat` style: a drawstring at 1.00–1.03, hem 0.09–0.12, flare 0.35 (the petticoat's is 0.20), folds 0.025 | block-printed cotton (`print`), tie-dye dots (`bandhani`) · `madder_red`, `indigo_mid`, `saffron`*, `safflower`* | petticoat | H | [SA10] |
| `south_asian_choli` | shirt 10 | bodice: fitted, covering the front, ending under the bust at 1.15–1.17; sleeves to t 0.40; back ties (a later V&A choli measures 0.26 from the nape to the hem and 0.78 round under the bust) | cotton or silk · `madder_red`, green, `yellow`, `indigo_mid` | bodice | H form (paintings); M detail | [SA10], [SA8] |
| `south_asian_odhni` | accessories.wrap 50 | drape, about 2.5 × 1.5 m: one end tucked into the ghagra at the front, across the body, over the head and the left shoulder, hanging behind to 0.70. Build a shoulder-only version first, and the head drape later (it needs the head grid and hair hiding). | sheer cotton (MUSLIN), tie-dyed or printed | drape | H | [SA10], [SA4] |
| `south_asian_jutti` or bare feet | feet 40 | above | — | slipper | M | — |
| south and Bengal: `south_asian_sari` | legs.lower 30 (chest 25) | wrap_skirt + the pallu drape, joined: cloth 5–5.5 × 1.15 m (the Tamil nine-yard sari: about 8 m); the skirt from 1.02 to 0.10–0.15; 6–8 front pleats tucked at the centre front; the pallu diagonally from the right hip over the left shoulder, hanging to 0.80. The blouse was not universal in the 18th-century south and Bengal, so the choli is optional. | white or unbleached with a red border (Bengal); indigo or red checks (Madras); deeper solid colours | wrap_skirt + drape | H | [SA7], [SA9] |

The madisar drape between the legs belongs to one community (Tamil Brahmin women). It is not the generic sari.

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `south_asian_jama` | outer 40 | robe `under_arm`: ankle length by the 18th century (V&A examples: 1.50 m long, 2.24 m across the sleeves, 4.34 m round the hem; another 1.525 from the neck to the hem); a short bodice with a waist seam at 1.10–1.12; the crossover tied under the arm; hem 0.10–0.15; flare 0.35 (capped so the legs do not show through); sleeves to t 1.05, ruched; tie tabs (3 at the neck, 2 under the arm). **The tie side** (left or right) carried a Hindu or Muslim association†: offer it as the player's choice, never infer it. | fine white muslin, block-printed chintz, or gold-embroidered; red facings | robe | H | [SA1], [SA2], [SA3] |
| man: `south_asian_pyjama` | legs.lower 30 | trousers, churidar: tight below the knee, with 0.15–0.25 of extra length ruched over the ankle in 3–6 raised rings; tag `pants` | striped silk-cotton (*mashru*) or cotton | trousers | M-H | [SA4] |
| man: `south_asian_patka` | accessories.waist 60 | sash wound over the jama; decorated ends hanging at the centre front to 0.55 (ends 0.45 × 0.22; a V&A child's patka is 2.44 × 0.27 m) | chintz, embroidered muslin | sash | H | [SA5] |
| man: `south_asian_kashmir_shawl` + a muslin `south_asian_pagri` + an embroidered `south_asian_jutti` | accessories.wrap 50 | drape, both shoulders: 2.86 × 1.27 m, with floral ends and fringe (V&A, c. 1750–60) | pashmina, cream · `boteh` ends | drape | H | [SA6] |
| woman: `south_asian_peshwaz` over the pyjama and the choli, with a large odhni | outer 40 | robe `open`: a high waist seam at 1.15; skirt to 0.10; long sleeves; decorated bands along every edge | muslin with tinsel and foil | robe | H for court dress | [SA4] |
| woman (Rajput alternative): the everyday ghagra, choli and odhni in silk with zari borders | — | presets | silk | — | H | [SA10] |

**Lascar sailors:** `slops` (x) at calf length, or `trousers_long`; `sea_jacket` (x); a `south_asian_pagri` or a kerchief (L-M).

**Noted, not playable:**
- the sacred thread;
- ascetics' saffron robes;
- Sikh Khalsa dress and the dastar (religious: not the generic pagri);
- caste-regulated dress (for example the breast-cloth restrictions in Travancore).

**Avoid:**
- "harem pants" exaggerations;
- giant curled-toe shoes;
- the sari as all-India dress;
- a turban on everyone.

### 4.19 filipino

Lowland Christian Tagalog and Visayan people of the Spanish era, and the "Manila men" of the galleon trade. The core source is the vignettes of the Murillo Velarde map (1734) and Coo (2014) as summarised.

**Basic:** men `filipino_camisa` + `filipino_salawal`; women `filipino_baro` + `filipino_saya`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `filipino_camisa` | shirt {10, hips 35} | shirt (`collar=False`): collarless; close long sleeves (sleeve_end 0.95); worn untucked (the claim that Spain forced untucked shirts is a myth); hem 0.80, side hem 0.84, slits to 0.86 | abacá (*sinamay*), cotton · white, unbleached, striped | shirt | H-M | [PH2], [PH3] |
| `filipino_salawal` | legs.lower 30 | trousers `wide`: loose, to the knee or shin (hem 0.30–0.42), drawstring; tag `pants` | cotton, abacá · white, `linen_unbleached`, `indigo_mid` | trousers | H-M | [PH2], [PH3] |
| `head_band` (*putong*), style `wound` | head 80 | §3: a wound cloth 0.04–0.06 tall | white or indigo (red marked rank in earlier Tagalog custom) | head_wrap | M for 18th-century use | [PH3] |
| `filipino_salakot` | head 80 | rigid_hat `DOME_FINIAL`: radius 0.21–0.25, height 0.12–0.16; an inner head band (*baát*); a chin strap; a knob or spike finial 0.03–0.06 | bamboo, rattan or nito · `bamboo`*, `straw`* | rigid_hat | H | [PH5] |

Feet bare (M). The *chinelas* slipper is well documented only in the 19th century.

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `filipino_baro` | shirt 10 | shirt with `bottom=`: a collarless wide neck (a 0.10, b 0.085, z0 1.315); hem 0.96; 18th-century sleeves long and narrow, gathered at the head (gather 0.014) | sinamay, cotton · white, unbleached | shirt | M-H | [PH3], [PH4] |
| `filipino_saya` | legs.lower 30 | wrap_skirt: narrow and sheath-like, from 1.02 to 0.09; flare 0.035; a back pleat for the stride | striped or plaid cotton (Panay weaves, imported Indian *cambaya*) | wrap_skirt | H-M | [PH3], [PH4] |
| `filipino_tapis` | accessories.waist 35 (over the saya) | wrap_skirt: a darker, thicker cloth wrapped tight from the waist (or from 1.13); hem 0.30–0.45 | `stroud_blue`, `logwood_black`, brown | wrap_skirt | H-M | [PH4], [PH1] |
| `kerchief_womens` (x) (*pañuelo*, *alampay*) | accessories.neck 25 | a square over the shoulders covering the breast, often of the saya's cloth | as the saya | neckwear | M-H | [PH3], [PH4] |

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man (principalía): European dress, which the principalía are shown wearing "invariably" by the 18th century. `frock_coat` (x) + `waistcoat_sb` (x) + `breeches` (x) + `stockings` (x) + `shoes_buckled` (x) + `round_hat` (x). The 1734 vignettes show a mestizo in a hat, coat and stockings. | — | as built | silk, cotton · `stroud_blue`, `logwood_black`, `walnut_brown` | — | H | [PH1], [PH3] |
| man (alternative): a piña `filipino_camisa` and a silver-trimmed `filipino_salakot` | — | above | piña | — | M | [PH5] |
| woman: `filipino_baro` and `kerchief_womens` of piña; `filipino_saya` of silk or Indian chintz; a silk `filipino_tapis`; slippers | — | above | piña, silk, chintz | — | M | [PH4] |

**Manila-men sailors:** `slops` (x), `shirt_check` (x), and the putong or the salakot (L).

**Noted, not playable:** church veils; babaylan ritual dress.

**Avoid:** the 19th-century barong tagalog (embroidered piña, a collar); the terno and butterfly sleeves.

### 4.20 vietnamese

Đại Việt, divided between the Trịnh lords (the north) and the Nguyễn lords (the south). **The north is the default.**

**The 1744 edict.** The Nguyễn edict changed southern dress, but it applied to the court. Minh Mạng extended it to all of Vietnam only in 1830.
- The southern swap is M for commoners in 1750–65.
- Its "pointed hat" clause is L-M.
- Whether the 1744 tunic was already the five-panel *áo ngũ thân* is disputed† (M).

**Basic:** men `vietnamese_ao_canh` + `vietnamese_quan`; women `vietnamese_yem` + `wrapper_calf` (*váy*).

**Men, everyday** (north)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `vietnamese_ao_canh` | shirt {10, hips 35} | JACKET style: hip length (hem 0.87); side slits; a front closure with 5 cloth-knot buttons (hardware ellipsoids); narrow sleeves to t 0.95; a small round neck | hemp, cotton · `cu_nau_brown`*, `logwood_black`, `indigo_mid` | jacket | M | [VN1], [VN6] |
| `vietnamese_quan` | legs.lower 30 | trousers `wide`: calf to ankle (hem 0.12–0.30); a rolled or drawstring waist; tag `pants` | cotton, hemp · `logwood_black` (the 1744 edict replaced black trousers with brown in the south), `cu_nau_brown`* | trousers | H south; M north | [VN1], [VN2] |
| `loincloth` (*khố*), for field and water work | legs.lower 30 | §3: band at 0.98–1.04, strip 0.22, front flap to 0.75 | hemp · `cu_nau_brown`*, `logwood_black` | loincloth | M | [VN1], [VN4] |
| `vietnamese_khan_van` | head 80 | head_wrap `band`, wound: a long cloth about 0.30 wide wound into a band 0.05–0.07 tall over the hair bun. The pre-formed *khăn đóng* / *khăn xếp* is 19th–20th century, so the id `khan_dong` is dropped. | `logwood_black` cloth | head_wrap | M | [VN5] |
| `vietnamese_non_la` | head 80 | rigid_hat `CONE`: r 0.22, h 0.19; a chin strap | palm leaf · `straw`* | rigid_hat | M | [VN1] |
| `vietnamese_guoc` or bare feet | feet 40 | sandal: a wooden sole block 0.025–0.04 with one strap; or areca-spathe sandals | wood | sandal | M | [VN1] |

**Women, everyday** (north)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `vietnamese_yem` | shirt 10 | bodice `panel`: about 0.40 m square worn as a diamond; the top cut straight at 1.29 with a neck string; side strings tied behind at 1.05; the point at 1.00; the back bare | cotton, silk · white, `logwood_black`, `cu_nau_brown`* for every day; `vermilion`*, `safflower`* for festivals | bodice | H-M | [VN3] |
| `wrapper_calf` (*váy*) | legs.lower 30 | §3, tube preset: black, rolled at 1.03, hem 0.15–0.25 | `logwood_black` cotton | wrap_skirt | H-M | [VN1], [VN2] |
| `vietnamese_ao_tu_than` | outer 40 | robe `open`: a long open tunic, hem 0.25; a full back panel; two front panels free below the waist, tied or left hanging; side slits from 0.95; no buttons; a band along the neck and front edges (piping zone 0.03); narrow sleeves to the wrist; worn open over the yếm | `cu_nau_brown`*, `logwood_black` | robe | H-M | [VN1], [VN8] |
| `vietnamese_that_lung` | accessories.waist 60 | sash: a front knot, the ends to 0.70 | coloured silk or cotton | sash | L-M | — |
| `vietnamese_non_la` or bare head | head 80 | above. The *khăn mỏ quạ* (a black cloth over the hair, pinched to a point above the forehead) is L: optional. The *nón quai thao* (a flat drum hat) is L for the 1750s: deferred. | — | — | M | [VN1] |

**South (after 1744: M):** `vietnamese_ao_ngu_than` in plain cotton below the knee + `vietnamese_quan` + `vietnamese_non_la`; the hair in a bun.

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man (north): `vietnamese_ao_giao_linh` | outer 40 | robe `crossed`: the left panel over the right, closing at the wearer's right; hem 0.15; wide sleeves (wrist ease 0.08); a contrasting collar band | silk · `stroud_blue`, `logwood_black`, brown | robe | M | [VN2], [VN4] |
| man (south): `vietnamese_ao_ngu_than` | outer 40 | robe `side_fastened`: a stand collar 0.028; closes diagonally from the collar to the right armpit, then down the right side, with 5 buttons; hem 0.35; side slits from 0.95; narrow sleeves | silk gauze or satin · blue, red, russet, pink, green, indigo. Never yellow (reserved for the ruler). | robe | M | [VN1], [VN2], [VN5] |
| man: + `vietnamese_khan_van`, silk `vietnamese_quan`, `vietnamese_guoc` | — | above | silk | — | M | [VN5] |
| woman (north): a silk `vietnamese_ao_tu_than`, a `vermilion`* `vietnamese_yem`, a silk `wrapper_calf` and `vietnamese_that_lung`. South: a silk `vietnamese_ao_ngu_than`, `vietnamese_quan` and `vietnamese_khan_van`. | — | above | silk | — | M | [VN1] |

**Noted, not playable:** the *áo tấc* and court robes; white mourning dress; yellow.

**Avoid:** the 20th-century áo dài silhouette; the nón quai thao as an all-Vietnam symbol.

### 4.21 thai

Siamese of the kingdom of Ayutthaya. The core source is La Loubère (1687–88), 65–75 years early, so **the details are M** and the overall wrap forms H. The temple murals of 1734 are a later check.

**Basic:** men `thai_chong_kraben` (shirt "-", bare head and feet: the period norm); women `wrapper_calf` (*pha nung*) + `thai_sabai`. Covering the woman's torso is the game's choice: La Loubère says most women wore only the lower cloth.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `thai_chong_kraben` | legs.lower 30 | trousers `draped`: a cloth "two Ells and an half long" (about 2.9 × 0.95 m) wrapped at z 0.98–1.04, one end pulled up between the thighs and tucked at the back; hem 0.50–0.65; thigh ease 0.045; a roll ridge at the centre back; tag `pants` | cotton, plain, check or printed · `indigo_mid`, `madder_red`, `walnut_brown` | trousers | H form; M details | [TH1], [TH2] |
| `thai_pha_shoulder` (cold weather) | accessories.wrap 50 | drape, the ends wound round the arms: a cloth or painted linen worn as a mantle | cotton, painted linen | drape | M-H | [TH1] |

Bare torso, feet and head are the period norm (H). A checked sash (*pha khao ma*) and the *ngop* hat are L: not built.

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `wrapper_calf` (*pha nung*) | legs.lower 30 | §3, front-fold preset: let down full like a close skirt to half way down the leg (hem 0.22). Alternative preset: `thai_chong_kraben` worn by women, below the knee. | cotton · as the men's | wrap_skirt | H | [TH1], [TH2] |
| `thai_sabai` | shirt 10 | drape, breast: about 2.2 × 0.35 m wound once round the chest (z 1.12–1.25) and over the left shoulder, the end hanging behind to 0.95 | cotton, silk | drape | M | [TH1] |
| `thai_pha_shoulder` | accessories.wrap 50 | above | — | drape | M | [TH1] |

Bare feet and head. Short hair (`hair_siamese_short_f`).

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `thai_sua` | shirt {10, hips 35} | shirt + a full-length `opening()`: open in front, no neckband; sleeves nearly to the wrist (end 0.90) and "about two Foot wide" (wrist ease about 0.05); hem 0.85 | white muslin · `cotton_white`* (MUSLIN) | shirt | M | [TH1] |
| man: `thai_chong_kraben` in Indian chintz (*pha lai*), in the simplified patterns made for the general public. The royal flame and celestial patterns were reserved for the court: never offered. | legs.lower | above | chintz (`print`) | trousers | H-M | [TH3], [TH5] |
| woman: `wrapper_calf` in silk or chintz with borders, and a silk `thai_sabai` | — | above | silk, chintz | — | M | [TH3] |

**Noted, not playable:** the *lomphok* (a white, high, pointed cap with a chin tie: an official's); the *khrui* robe; monks' robes.

**Avoid:** the 20th-century "chut thai" national costumes.

### 4.22 malay

Malays of the peninsula and Sumatra (Johor-Riau, Kedah, Dutch Malacca), traders and sailors of the Straits. The core source is Marsden (1783), about Sumatra: M for the peninsula in the 1750s.

**Basic:** men `malay_baju` + `drawers_short` + `wrapper_knee` (in the waist slot); women `wrapper_high`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `malay_baju` | outer 40 (alt_slots shirt) | shirt with `bottom=`, pullover: open in front only to the bosom; young men to the waist (hem 0.97); **style `elder`** to the knee (0.50); loose wide sleeves (ease 0.03), or nearly tight with buttons at the wrist | cotton · `indigo_mid`, `cotton_white`* | shirt | H | [ML1] |
| `drawers_short` (*seluar*) | legs.lower 30 | §3: to half way down the thigh (0.68) | cotton; red or yellow taffeta (Marsden) | trousers | H Sumatra; M peninsula | [ML1] |
| `wrapper_knee` (*kain sarong*) | accessories.waist 35 (alt slot, over the drawers) | §3: a sewn tube 1.8–2.4 m round × 0.9–1.2 m deep, folded and tucked at the hips, hem 0.35–0.45. A V&A Makassar sarong (18th century) is 1.98 × 1.14 m: a blue and red check with white lines. It can also be slung over the shoulder as a sash. | Bugis check (`check`) · `madder_red`, `indigo_mid`, `cotton_white`* | wrap_skirt | H | [ML1], [ML2] |
| `malay_destar` | head 80 | head_wrap `band`: a coloured handkerchief made into a small turban, the crown left bare, 0.045 tall, a knot at the front side. **Style `twisted`:** a twisted white or blue cloth (`hats.tube`), for villagers. | cotton, silk · colours | head_wrap | H | [ML1] |
| `malay_tudong` (journeys) | head 80 | rigid_hat `UMBRELLA`: r 0.28, h 0.12 | leaf, straw · `straw`* | rigid_hat | M shape | [ML1] |

Bare legs and feet (H).

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `wrapper_high` | legs.lower 30 | §3: up to the armpits (1.23), folded and tucked at the breast; hem at the knee in the villages, where it is the only garment; to the feet (the second mesh) in town | cotton, check | wrap_skirt | H | [ML1] |
| `malay_bodice` (town) | shirt 10 | bodice: a short closed bodice ending at 0.92 | cotton | bodice | M (cut details uncertain) | [ML1] |
| `malay_baju_womens` (town) | outer 40 | shirt or coat style: like the men's, buttoned at the wrists; young women's sleeves to just past the elbow (t 0.6); open to the bosom; waist length | cotton, chintz | shirt | H | [ML1] |
| `malay_selendang` | accessories.wrap 50 | drape: about 1.5 m, with fringed or worked ends, across the back of the neck and hanging in front; women of rank use it as a veil | fine cotton or silk | drape | H | [ML1] |

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `malay_waistcoat` | vest 20 | WAISTCOAT style: sleeveless, with a shirt-like stand collar 0.02, buttoned to the top with 9 gold filigree buttons (hardware lathe) from 1.30 to 0.95; hem 0.89 | silk · `gold_lace` buttons | waistcoat | H | [ML1] |
| man: `malay_baju` in chintz or flowered silk; a silk `wrapper_knee` with gold thread (Makassar silk with gilt-paper thread) | — | above | silk, chintz | — | H | [ML1], [ML2] |
| man: `malay_kris_belt` | accessories.waist 60 | sash: crimson silk wound several times, with a loop for the kris sheath. **The kris is gear:** an heirloom with spiritual weight†. Give it a care note; never make it a trinket. | silk · `crimson`* | sash | H | [ML1] |
| man: `malay_destar` in fine silk | head 80 | above | silk | — | H | [ML1] |
| woman: `malay_baju_panjang` | outer 40 | robe `open`: open front, knee to ankle (hem 0.15–0.47), 9 buttons along each forearm | chintz, silk | robe | H | [ML1] |
| woman: `malay_tali_pending`, with a silk wrapper and a silk `malay_selendang` | accessories.waist 60 | belt: a gold or silver plate 0.05 wide with a large filigree clasp set with a stone | gold, silver · `gold_lace`, `silver` | belt | H | [ML1] |

**Noted, not playable:** royal yellow; the royal songket head cloths (*tengkolok*).

**Avoid:** the "Teluk Belanga" baju kurung as 18th-century dress. Its standard form is late 19th century (L-M).

### 4.23 pacific_islander: on hold (consultation)

The peoples of Tahiti and the Society Islands, Hawaii, Tonga, Samoa and Aotearoa. Mai of Raiatea sailed to London in 1774.

**Not one people.** Use the regional presets. `peoples.json` files this people under the group "Southeast Asia", which is wrong.

**Hold.** Māori and Hawaiian garments (the everyday pākē and kīhei included) and tapa/kapa motifs go through the same consultation gate as the Woodlands set (critic). The rows below are **candidates to bring to review, not a build list**. The offices are still to be identified. Every source is from the first contacts of 1767–79 (Cook), just after the target years.

| candidate | slot | cut | cloth | type | cert. | src |
|---|---|---|---|---|---|---|
| maro (`loincloth`) | legs.lower 30 | a cloth between the thighs and round the waist ("worn by every man"); strip 0.25, band 0.98–1.03, flaps to 0.85 | tapa (BARK): natural, brown, red | loincloth | H | [PI1], [PI2] |
| pāreu (`wrapper_knee`, 2–3 layers) | legs.lower 35 | wrapped two or three times round the waist, below the knee "like a petticoat": hem 0.38 (men), 0.30 (women), flare 0.08 | tapa, matting | wrap_skirt | H | [PI1] |
| tiputa | outer 40 | cloak `poncho`: 1.8–2.3 m long with a head hole; front and back to 0.45–0.55; 0.7–0.9 wide; open sides | white or natural tapa, red- or yellow-dyed. The patterns need review. | cloak | H form | [PI1], [PI2] |
| tapa girdle | accessories.waist 60 | thin tapa tied over the tiputa | tapa | sash | H | [PI1] |
| taumata | head 80 | rigid_hat `VISOR`: a woven coconut-leaf band with a front visor 0.08–0.10, crown open | leaf, fine matting | rigid_hat | H | [PI1] |
| ʻahu, layered (better-off) | legs.lower | wrap_skirt, 3–4 layers (raised steps 0.004); top 1.23 for women. Status was shown by quantity: cloths 8–10 yards long. | fine bleached or red tapa | wrap_skirt | H | [PI1], [PI2] |
| Hawaiian pāʻū and kīhei; Tongan and Samoan wraps; the Māori flax cloak, tātua belt and rāpaki | — | — | — | — | M / L-M / H | [PI1], [PI3] |

The tamau (a cord of plaited human hair wound round the head) needs particular care.

**Never playable without consultation:**
- the red-feather maro ʻura;
- the chief mourner's costume;
- Hawaiian feather cloaks and helmets;
- Samoan fine mats (ʻie tōga);
- the Māori kaitaka and dog-skin cloak (kahu kurī);
- tattoo (tatau, tā moko).

**Avoid:** the 19th-century piupiu (the rāpaki came first); grass skirts and "coconut bras".

### Middle East and North Africa: rules for all nine peoples

**Layers.** The current defaults would put the sash under the robe and the shift under the trousers. These ensembles therefore use their own layer numbers:

| Garment | Slot · layer |
|---|---|
| inner long robe | vest 36 |
| sash, worn round the inner robe and under the outer coat | waist 38–39 |
| outer coat | outer 40 |
| fur robes and mantles | wrap 50 |
| women's trousers, under the shift whose tails hang over them | 8 |
| leather sock-boots and knit socks, under the trouser cuffs | 6 |

**Face veils.** Niebuhr says Eastern townswomen "all, without exception, wear veils" outdoors. Showing them unveiled outdoors in Egypt, Arabia and Syria is the game's choice. Record it as a grade C ("artistic licence") note. The face veils themselves (yaşmak, burqu', ruband, the Yemeni gauze) need an `accessories.face` slot and are offered only with care: optional, never a default, with no gameplay meaning.

**Sumptuary colours.** Non-Muslims were made to wear dark dress and red (not yellow) shoes. These were imposed, discriminatory laws. Offer them as accurate presets, never as rules the game enforces.

**Never:**
- green turbans or bright green dress as a generic colour (reserved for descendants of the Prophet);
- the tall stiff fez (after 1829);
- dancers' and "harem" costumes as everyday dress;
- Bedouin dress for every Arab;
- exaggerated curled shoes.

### 4.24 levantine

People of the eastern Mediterranean: Syria, Lebanon and Palestine. The core source is Russell on Aleppo (1740s–71: H).

**Gap:** no 18th-century source was read for Mount Lebanon or Palestinian villagers (L).

**Basic:** men `shirt_collarless` + `salvar_mens` + `entari`; women `thob_womens` + `salvar_womens`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_collarless` | shirt 10 | §3 | linen, cotton · white | shirt | H | [RUS] |
| `salvar_mens`, or `drawers_linen` in summer | legs.lower 30 | §3. In summer ordinary people "lay aside their Shahkshoor, wearing drawers only". | wool; linen | trousers | H | [RUS] |
| `entari` (the *kunbaz*) | vest 36 | §3: below the knee, wrapping over, tied with tapes | striped cotton, Aleppo flowered stuffs | robe | H | [RUS] |
| `jubba`, style `dulaman`, in linen | outer 40 | §3 ("for the cloth Dulaman substitute one of linen") | linen; wool in winter | robe | H | [RUS] |
| `sash_shawl` · `turban_common` | waist 38 · head 80 | §3: "a small cloth cap, rolling a coarse Shash loosely round it" | wool, cotton | sash, head_wrap | H | [RUS] |
| `slippers_backless` · winter: `kurk_fur` (coarse fox) and red iron-shod `boots_soft` | feet · wrap | §3 | `yellow` (Muslim) or red (Christian) morocco | slipper | H | [RUS] |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `thob_womens` | shirt {10, 25} | §3: "hanging down to the feet, under the Kunbaz and over the Gintian" | cotton, linen | tunic | H | [RUS] |
| `salvar_womens` | legs.lower 8 | §3: "pursed at the ankle with a ribband" | cotton, striped silk-cotton | trousers | H | [RUS] |
| `entari_womens` · `belt_clasp` | vest 36 · waist 39 | §3: a belt 3 inches wide with a gilt clasp | striped stuffs; gilt | robe, belt | H | [RUS] |
| `turban_flat_womens` · `mest` + `slippers_backless` | head · legs.over · feet | §3: "a warm cloth cap … cotton and muslin"; thin coloured leather | — | — | H | [RUS] |
| outdoors: `wrap_drape_womens`, preset `izar` | accessories.wrap 50 | §3 | white calico (Christian and Jewish women); checkered blue or red (Muslim women) | drape | H | [RUS] |

**Village and Bedouin-style women:** a coarse blue `thob_womens` with wide sleeves, "open a little at the breast, and reaching to the ankles"; a black `head_kerchief`; bare legs and bare feet in the country (H).

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `salvar_mens`, style `cakshir`, in red cloth, sewn to yellow leather socks | legs.lower 30 | §3 | `scarlet` broadcloth; `yellow` leather | trousers | H | [RUS] |
| man: a flowered `entari`, style `entari_long`, under a long `jubba` (`dulaman`) "tucked up so as to show part of the waistcoat"; a belt under the waistcoat (inner zone) and a long Persian shawl as the `sash_shawl` over the dulaman, with a dagger on a silver chain (gear) | vest · outer · waist | §3 | silk, Aleppo flowered stuffs; a Kashmir shawl (`boteh`) | robe, sash | H | [RUS] |
| man: `kurk_fur` (short and mid-leg; a single fur for those who go on foot) + `turban_town`. In summer the *abai*: a `jubba` preset in silk or camlet with large sleeves, laced with gold at the seams. | wrap · head · outer | §3 | sable, fox; silk | — | H | [RUS] |
| woman: silk `salvar_womens`; a silk-gauze `thob_womens` (opaque); a fitted `entari_womens` of European silk or Aleppo flowered stuff, open at the neck; an embroidered `belt_clasp` with a gilt clasp set with pearls or stones; a fitted sable `kurk_fur` | — | §3 | silk | — | H | [RUS] |
| woman: `levantine_turban_high` | head 80 | head_wrap `turban`: a high round turban of coloured muslin, with pearls and egrets (the Istanbul fashion) | coloured muslin; pearls | head_wrap | H | [RUS] |

The gold collar, bracelets and anklets, and the string of sequins on the forehead, are jewellery.

**With care:** "a sort of silver or lackered hat, shaped like a cone, a platter, or some other fantastic form", worn by women in Syria (Niebuhr, verified by the critic: H for the 1760s). The name *tantour* and the tall horn form are 19th century (M). It is a married woman's insignia: optional, never a default.

**Not playable:** Christian clergy dress (a black outer robe and a dark-blue turban).

### 4.25 ottoman_turkish

Turks of Anatolia and Rumelia: the soldiers, merchants and sailors of the Mediterranean.

**Basic:** men `shirt_collarless` + `salvar_mens` + `entari`; women `thob_womens` (style `shift_ottoman`) + `salvar_womens`. A peasant's minimum is the shirt and drawers [NIE].

**Men, everyday** (Anatolian or Rumelian peasant, Istanbul tradesman)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_collarless`, tucked in | shirt 10 | §3 | linen, cotton | shirt | H | [NIE] |
| `salvar_mens` | legs.lower 30 | §3 | wool · `undyed_brown`*, `indigo_mid` | trousers | H | [NIE], [RUS] |
| `entari` | vest 36 | §3: hem 0.38 | striped or plain cotton | robe | H | [NIE] |
| `sash_shawl` | accessories.waist 38 | §3, with a knife (gear) | red or striped wool | sash | H | [RUS] |
| `turban_common` on a red cap | head 80 | §3: white cloth, washed fresh. The caps are "chiefly red, or green": use red. | white cloth | head_wrap | H | [RUS] |
| `slippers_backless` (`yellow`) · `boots_soft` (travel: "wide boots" over foot-cloths) · `charuq` (M) | feet 40 | §3 | morocco, rawhide | slipper | H | [NIE], [RUS] |
| optional: `jubba`, style `binish` · `kepenek` (shepherds) | outer · wrap | §3 | wool; felt | — | H / M | [NIE], [RIC] |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `thob_womens`, style `shift_ottoman` | shirt {10, 25} | §3: hem 0.20; the wide sleeves hang "half way down the arm" | linen, cotton | tunic | H | [MWM] |
| `salvar_womens` · `entari_womens` · `belt_clasp` | legs.lower 8 · vest 36 · waist 39 | §3 | cotton, striped silk-cotton | — | H | [MWM], [RUS] |
| `turban_flat_womens` | head 80 | §3: a small cap bound with a handkerchief | muslin | head_wrap | H | [MWM] |
| `mest` with `slippers_backless` | legs.over 6 · feet | §3: "thin leather boots, in wide slippers" | leather | — | H | [NIE] |
| outdoors: `ottoman_ferace` | outer 40 | robe `open`: to the heels (0.03); long straight sleeves; a square collar about 0.40 × 0.40 "hanging flat on the back" | white linen, shawl or cloth ("which no woman of any sort appears without") | robe | H | [RUS], [MWM] |

The face kerchief (*yaşmak*) is with care (above).

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: a silk `shirt_collarless`; `salvar_mens`, style `cakshir` (red over yellow); a striped silk `entari`, style `entari_long`; a Persian-shawl `sash_shawl` with a dagger (gear) | — | §3 | silk, broadcloth | — | H | [NIE], [RUS] |
| man: `ottoman_kaftan` | outer 40 | robe `open`: to the feet, partly "taken up … by means of a broad girdle". Wear it **or** the `jubba` (`binish`), not both: one per slot. | silk, broadcloth | robe | H | [NIE] |
| man: `kurk_fur` in winter (wrap) + `turban_town` + `yellow` slippers | — | §3 | fur; muslin | — | H | [RUS] |
| woman (Montagu, 1717: M-H): `salvar_womens` of thin rose damask brocaded with silver; a white silk-gauze `thob_womens` (opaque) buttoned at the neck; a fitted white-and-gold `entari_womens` with long fringed sleeves falling back; an `ottoman_kaftan` of the same stuff as the trousers, fitted, to the feet; a `belt_clasp` four fingers broad; `kurk_fur` style `curdee` in green-and-gold brocade lined with ermine or sable; white kid `slippers_backless` embroidered in gold | — | §3 | silk, brocade, fur · `safflower`*, `silver_lace` | — | M-H | [MWM] |
| woman: `ottoman_cap_womens` | head 80 | soft_cap `skullcap`: a small cap "fixed on one side of the head", with a gold tassel | velvet with pearls (winter), silver stuff (summer) | soft_cap | M-H | [MWM] |

**Not playable:**
- the rank turbans of the ulema, kadis and officials;
- the ceremonial fur robe of the legal class;
- Janissary and other military headgear;
- dervish caps and dress;
- the pilgrim's *ihram*;
- wedding dress.

### 4.26 persian

People of Iran after the Safavids. Karim Khan Zand ruled from Shiraz from 1751, so **the Zand default** covers 1751–65. Hanway's observations (1743–45, under Nader Shah) are **labelled "1740s"**.

**Basic:** men `persian_pirahan` + `salvar_mens` (style `narrow`) + `persian_qaba`; women `persian_pirahan` + `salvar_womens`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `persian_pirahan` | shirt 10 | shirt with the new slit angle: no wristbands and no collar; a slit and a small button on the **left shoulder**; sleeves about 0.30 round at the wrist; hem 0.62 | checked silk-cotton, or plain cotton | shirt | H (1740s) | [HAN] |
| `salvar_mens`, style `narrow` | legs.lower 30 | §3 | cotton, wool | trousers | H (1740s) | [HAN] |
| `persian_qaba` | vest 36 | robe `crossed`: two or three light layers "which reach only to their knees" (hem 0.45–0.50); fitted, crossing the chest to fasten under the right arm; narrow sleeves long enough to cover the fingers (`trims.extrude`); slits to 0.75; about 1.6 m round at the hem | "slight cotton"; quilted in winter · `crimson`* (the favourite). Coarse deep blue was the mourning colour: not a festive default. | robe | H (1740s); M-H for the Zand cut | [HAN], [DIB] |
| `sash_shawl` | accessories.waist 38 | §3, with a long knife in a wooden case (gear) | shawl, cotton | sash | H | [HAN] |
| `persian_kolah_zand` | head 80 | rigid_hat, tall crown-only: a tall cylindrical cap, 0.20–0.24 (Karim Khan "replaced the kolāh-e nāderī with a tall cylindrical cap"). **1740s option:** a shorter summer cap (0.12–0.14) "faced with grey Bokharian lambskins". | felt or cloth · `crimson`*; `lambskin_grey`* | rigid_hat | H for the kind (Iranica, verified); M for the height | [DIB], [HAN] |
| `socks_knit` + `slippers_backless`, style `persian` | legs.over 6 · feet 40 | §3 | wool; shagreen · `shagreen_green`* | — | H | [HAN] |

**Peasants:** `charuq` + `gaiter_tied` (linen leg wraps); `kepenek` or `sheepskin_coat` in winter (M: Du Mans, 1660s, via Iranica).

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `persian_pirahan` (women's) | shirt {10, 25} | as above, longer, "open at the breast" (built with a modest opaque slit) | cotton | shirt | M-H | [HAN] |
| `salvar_womens` | legs.lower 8 | §3, Persian preset | cotton | trousers | H ("the women also wear drawers and slippers as the men") | [HAN] |
| `salta` | outer 40 | §3: short, loose, long-sleeved | stripes, florals | jacket | M | [DIB] |
| `persian_charqad` | head 80 | drape, head-short: a head scarf pinned under the chin, hanging over the shoulders | cotton, silk | drape | M | [DIB] |
| `slippers_backless` · outdoors: `wrap_drape_womens`, preset `chador` | feet · wrap 50 | §3: "a white veil, which covered their whole body" | white | — | H | [HAN], [DIB] |

The peasant women of Gilan planted rice unveiled [HAN].

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: `persian_qaba` in brocaded silk with small florals, over quilted silk under-robes | vest 36 | above | brocade | robe | M-H | [DIB] |
| man: `salta`, style `fur` (a short fur coat to the waist: sable or squirrel; 1740s) | outer 40 | §3 | fur | jacket | H (1740s) | [HAN] |
| man: a Kerman shawl as the `sash_shawl` and as `persian_kolah_shawl`; a gold-mounted knife (gear); green shagreen heeled slippers; `aba` | head 80 | head_wrap `turban`: a shawl wound round the tall cap | Kerman shawl · `boteh` | head_wrap | H | [HAN], [DIB] |
| woman (Iranica: M): a `persian_pirahan` embroidered in gold (built opaque with a modest slit: period images show sheer shifts open to the navel); `salvar_womens` of stiff brocade woven in diagonal floral stripes (the wide, stiff trousers "by mid-century", verified); a striped `salta`; `persian_cap_jewelled` (a soft_cap with a chain at the temple and a small gold plate) [HAN]; a white chador outdoors | — | above | brocade, silk | — | M | [DIB], [HAN] |

**Noted:** the `kolah_naderi` (0.25–0.30 tall, four corners at the top, red: the 1740s style [HAN]). Its four points stood for the first four caliphs (Iranica): a Sunni religious-political meaning. Offer it at most as a dated 1740s option, with that note.

**Avoid:** Qajar fashions after 1790 (tall black lambskin hats, long robes). Zand men wore knee-length robes.

### 4.27 arab

The Bedouin of the desert, the townspeople of the Hejaz and Basra, and the merchants of Mocha. Yemeni and town dress are as well attested as Bedouin dress.

**Basic:** men `thawb`; women `thob_womens` + `salvar_womens`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| Bedouin: `thawb` (no drawers) | shirt {10, 36} | §3: hem 0.28 | coarse cotton · `cotton_white`*, `indigo_mid` | tunic | H | [BUR], [NIE] |
| Bedouin: `aba` | accessories.wrap 50 | §3 | goat or camel hair · broad brown-and-white stripes | cloak | H | [BUR] |
| Bedouin: `keffiyeh` · `belt_cord` (a leather thong) | head 80 · waist 60 | §3 | cotton, yellow or yellow-green; leather | drape, belt | M / H | [BUR] |
| Bedouin: bare feet or `sandals_leather`; `sheepskin_coat` in winter | feet · wrap | §3 | — | — | H | [NIE], [BUR] |
| Yemen and Tihama labourer: `wrapper_knee` (*futa*) + `arab_shoulder_cloth` + `sash_shawl` with a jambiya at the centre front (gear) + `turban_common` (two caps under a loosely bound cloth); "neither shoes nor stockings" | legs.lower · wrap · waist · head | `arab_shoulder_cloth`: a strip 0.30 wide over the left shoulder (`straps.strip`); the rest §3 | linen, cotton; checks and stripes | wrap_skirt, drape | H | [NIE] |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `thob_womens` | shirt {10, 25} | §3 | `stroud_blue`, brown, `logwood_black` (Bedouin); blue (Tihama) | tunic | H | [BUR], [NIE] |
| `salvar_womens` | legs.lower 8 | §3 ("All the women in the East wear drawers") | cotton, linen | trousers | H | [NIE] |
| `head_kerchief` | head 80 | §3 | red (young women), black (older) | drape | H | [BUR] |
| `aba` (both sexes, in Lahsa) · bare feet or `slippers_backless` | wrap · feet | §3 | — | — | H | [NIE] |

Rings in the nose and ears, anklets and bracelets are body features and jewellery: noted only.

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man (Yemen, the "dress of distinction"): a shirt over wide cotton `salvar_mens`; `sash_shawl` with a jambiya (gear); an `entari` with straight sleeves under a flowing `jubba`; `turban_sesh`; a fine linen `arab_shoulder_cloth` ("Arabians of rank"); `mest` or slippers | — | §3 | linen, cotton, muslin | — | H | [NIE] |
| man (Bedouin sheikh): a black `aba`, sometimes worked with gold; a red-and-white striped Damascus or Baghdad shawl as the `keffiyeh`; yellow `boots_soft` or red shoes | — | §3 | goat hair, silk | — | M | [BUR] |
| woman: Yemen highland `thob_womens` (blue-and-white check with needlework at the top and middle); embroidered hems on the `salvar_womens`; a Bedouin black silk `head_kerchief`, style `large` (two yards square); silver jewellery | — | §3 | linen, silk | — | H / M | [NIE], [BUR] |

The embroidered gauze face veils of Sana and Mokha: with care.

**Not playable:**
- the pilgrim's *ihram*;
- the sherifs' green;
- dervish dress.

**Avoid:** the red-and-white checked headcloth as the "Arab" default (a modern association); the cord is only M for 1760.

### 4.28 armenian

Armenians of the Caucasus, Anatolia and New Julfa in Isfahan; merchant houses from Amsterdam to Manila.

"The dress of the Christians in the East is nearly the same as that of the Turks. Only they are prohibited the use of bright-coloured stuffs. They may not wear boots of yellow leather" (Niebuhr, verified). In 1760 Armenians mostly dressed like their neighbours. Avoid the 19th-century "national costume".

**Basic:** men `shirt_collarless` + `salvar_mens` + `entari`; women `thob_womens` + `salvar_womens`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_collarless` · `salvar_mens` (Ottoman) or style `narrow` (Persia, Julfa) | shirt · legs.lower | §3 | linen; dark wool · `logwood_black`, `stroud_blue`, `walnut_brown` | — | H | [NIE] |
| `entari` · `jubba` | vest 36 · outer 40 | §3, dark or striped | wool, striped cotton | robe | H | [NIE], [RUS] |
| `sash_shawl`, or `belt_clasp` (leather, silver buckle) | accessories.waist | §3 | wool; leather | — | H / L | [ARM] |
| `kalpak`, or `turban_common` (preset `christian`) | head 80 | §3 | cloth and lambskin; a red cap in blue-and-white striped linen | — | H | [NIE], [RUS] |
| `slippers_backless` (red); rural: `charuq` + `socks_knit` | feet · legs.over | §3 | morocco; rawhide, wool | — | H / L-M | [RUS], [ARM] |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `thob_womens` (the Eastern red-cotton *halav* preset: L) | shirt {10, 25} | §3 | cotton | tunic | M | [ARM] |
| `salvar_womens` · `entari_womens` (the *ant'ari* / *arkhalukh*: front-open, fastened at the waist) | legs.lower 8 · vest 36 | §3 | cotton, silk | — | M | [ARM] |
| `apron_flat` (*mezar*) · `belt_clasp` | waist 35 / 39 | §3. One waist slot: the belt is worn under the apron as its zone, or one is chosen. | striped wool; silver | — | L / M | [ARM] |
| `head_kerchief` (village) · `socks_knit` with slippers or rawhide shoes | head · legs.over · feet | §3 | — | — | L | [ARM] |
| outdoors: `wrap_drape_womens`, preset `izar` (white: "plain white calico" for Christian women at Aleppo) | accessories.wrap 50 | §3 | white calico | drape | H | [RUS] |

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man (Istanbul or Aleppo merchant): a dark, fine `jubba` (`binish`); `kurk_fur` (sable or fox); a striped silk `entari`; a Kashmir `sash_shawl`; a tall `kalpak` with black lambskin; red slippers over `mest` (not yellow) | — | §3 | broadcloth, silk, fur | — | H | [NIE], [RUS] |
| man (New Julfa or Persia): `persian_qaba` and a shawl. The Julfan black velvet cap is documented only in portraits; its shape and date are unclear (L): not built. | — | §4.26 | — | — | M / L | [ASL] |
| woman: a velvet `salta` (purple, blue or burgundy, embroidered); a festive `jubba` (*juppa*) in velvet over the `entari_womens`; a silver-plaque `belt_clasp` | — | §3 | velvet, silver · `logwood_plum`, `stroud_blue`, `crimson`* | — | L-M (19th-century sources) | [ARM] |

**With care:** the married women's coin band and mouth cloth.

**Not playable:** Armenian clergy dress.

### 4.29 kurdish

Kurds of the Zagros and Taurus, between the Ottoman and Persian empires: herders, farmers and the horsemen of the emirates. Most detail comes from Rich (1820: M). Russell gives the 1750s–60s evidence for the felt cap.

**Basic:** men `shirt_collarless` + `salvar_mens` (`narrow`) + `entari`; women `thob_womens` + `salvar_womens`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_collarless` · `salvar_mens`, style `narrow` (tapered; the Jaf wore "light drawers") · `entari` ("the common antari or gown") | shirt · legs.lower · vest | §3 | cotton, wool | — | M-H | [RIC] |
| `kurdish_shalloon_coat` | outer 40 | coat with side slits: hem 0.50, open at the breast; the skirts "left unsewn … so that they hang down from the girdle in four tails, … two behind and two before" (slits at 0°, 90° and 180°); coloured braid on the sleeves and breast (piping, zone 3) | shalloon · brown, `undyed_white_wool`*; braid colours | coat | M (1820) | [RIC] |
| `belt_clasp` (leather with brass plates) | accessories.waist 39 | §3 | leather, brass | belt | M | [RIC] |
| `kurdish_kaouk`, with a short white shash | head 80 | rigid_hat, tall crown-only: "the high tapering felt Kaook, with a short white shash", 0.20–0.25; or `turban_common` in dark red with blue-striped ends (1820) | felt; white cloth | rigid_hat | H-M (Russell); M (Rich) | [RUS], [RIC] |
| `aba` ("the universal abba"), `kepenek` or `sheepskin_coat` | accessories.wrap 50 | §3 | goat hair, felt, sheepskin | cloak | M | [RIC] |
| feet: `charuq`, or shoes with ties (black or yellow, tasselled); the worsted *klash* is L-M | feet 40 | §3 | rawhide, leather | — | M | [RIC] |

**Women, everyday** (Rich, 1820: M)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `thob_womens` + `salvar_womens` | shirt · legs.lower 8 | §3: "a shift and trowsers of coarse blue calico" | blue calico · `indigo_mid` | — | M | [RIC] |
| `belt_clasp`, strap preset | accessories.waist 39 | the shift "buckled about the waist with a strap" | leather | belt | M | [RIC] |
| `kurdish_charokhia` | accessories.wrap 50 | drape, short: "a kind of cloak, or mantle, without sleeves, fastened over the breast, and hanging down behind to the calves" (hem 0.30), knotted by the ends over the breast | darker blue stuff with several white stripes at the bottom (peasants); blue-and-white checked calico (Jaf women) | drape | M | [RIC] |
| `skullcap` ("a small cap") | head 80 | §3 | cloth | soft_cap | M | [RIC] |

The long hanging sleeve tails (*faqiyana*) are 20th century (L): optional.

**Better-off** (Rich: M)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: an `entari` of flowered silk or gold stuff, "buttoned at the throat, and allowed to hang open"; a `belt_clasp` with gold, silver or lapis clasps; a quilted winter robe (*libada*, a `jubba` preset); `aba` | — | §3 | silk, gold stuff. Kurds "affect the brightest and most glaring colours". | — | M | [RIC] |
| man: `kurdish_turban_fringed` | head 80 | head_wrap `turban`: check silk wound with the forehead left bare, "an immense bush of fringe" down the back; or a Kashmir shawl worn loosely | check silk in red, yellow and blue with metal thread | head_wrap | M (1820) | [RIC] |
| woman: Turkish-style `salvar_womens` and a loose shift; a `belt_clasp` with two very large clasps; an `entari_womens` cut like a man's (buttoned at the throat, open below) in striped silk, chintz or Gujarat gold stuff; `kurdish_robe_womens` (a satin outer robe, robe `open`, with tighter sleeves "which do not reach down to the elbows", t 0.40); a `kurdish_charokhia` in check silk | — | §3 / above | silk, satin, chintz | — | M | [RIC] |

**With care:** the women's mitre of silk shawls "pinned together in front … about two feet in height", its ends to the ankles, with gold lace and coral strings. It is very heavy; a reduced version would be about 0.35 m. Optional only, never a default.

**Avoid:**
- the suits of modern Kurdish fighters;
- the fixed 19th-century "national costume".

### 4.30 north_african

The Amazigh (Berber) peoples of the Maghreb: the Rif, the Atlas, Kabylia and the edge of the Sahara. "The Arabs, in general, wear nothing but woollen" (Shaw).

**Basic:** men `qashshaba` or `north_african_jillebba`; women `draped_dress`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `north_african_jillebba` or `qashshaba` | shirt {10, 36} | jillebba: tunic, "a close-bodied frock or tunick … with or without sleeves", girded, knee length (0.45); qashshaba §3 | undyed wool · `undyed_white_wool`*, `undyed_brown`* | tunic | M (Shaw, 1720s) / H | [SHA], [CHE], [LEM] |
| `haik_mens` · `burnous` | accessories.wrap 50 | §3. One wrap slot: the burnous over the haik needs the haik as an under layer (`accessories.shoulder`) or as one combined mesh. | wool | drape, cloak | H | [SHA], [CHE] |
| `sash_shawl` | accessories.waist 38 | §3: worsted, one end doubled into a purse | worsted | sash | H | [SHA] |
| `north_african_fillet` (otherwise bare-headed) | head 80 | head_wrap `coil`: a narrow ring round the temples (`hats.tube`): "Several Arabs and Kabyles go bare-headed all the year long, binding their temples only with a narrow fillet" | wool cord | head_wrap | H | [SHA] |
| bare feet or `sandals_leather`; no drawers, no linen | feet | §3 | — | — | H | [SHA] |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `draped_dress` | vest 36 | §3: "a haick tied round their waist, the folds of which, covering the neck and shoulders, are fastened by clasps" | undyed or indigo wool | wrap_skirt | M-H | [CHE] |
| `belt_cord` (a wool cord girdle) | accessories.waist 60 | §3 | wool | belt | M-H | [CHE] |
| `head_kerchief` (a triangle over the plaited hair) | head 80 | §3 | wool, cotton | drape | L | — |
| outdoors: `wrap_drape_womens`, preset `haik` (country women were less strict); `mantle_back_carry` (a pouch in the back of the wrap for a child) | accessories.wrap 50 | §3 | wool | drape | H / M | [SHA], [LEM] |

Crescent-shaped ear-rings, silver bracelets and anklets, and necklaces of glass beads or cloves are jewellery [CHE].

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man (a country Moor "in easy circumstances"): "a haick for summer, another for winter, a cape [burnous], a red cap, and a pair of slippers"; richer clans add the scarlet cap and a `turban_common` | — | §3: `skullcap` in red felt, `slippers_backless` | wool, felt | — | H | [CHE], [SHA] |
| woman: a finer `draped_dress` with a striped hem; silver brooches joined by a chain; heavier silver jewellery | vest 36 | §3 | wool, silver | wrap_skirt | M | [CHE] |

The Algiers town *sarmah* (a pierced gold or silver plate headdress) belongs to town women (M-L): not here.

### 4.31 moorish

Arabic-speaking townspeople of Morocco (Fez, Tetouan, Rabat-Salé), many of Andalusi descent. The critic suggests the UI label **"Moroccan (towns)"**: "Moorish" is a European exonym.

**Basic:** men `shirt_collarless` + `salvar_mens` (`knee`) + `moorish_qaftan`; women `thob_womens` + `salvar_womens`.

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `shirt_collarless` · `salvar_mens`, style `knee` | shirt · legs.lower | §3 | linen | — | H / M (the cut below the knee) | [CHE] |
| `moorish_qaftan` | vest 36 | robe `open`: ankle length, with a row of small front buttons (M) | cotton in summer, cloth in winter | robe | H | [CHE] |
| `sash_shawl` (striped Fez silk) · `turban_common` on a red cap | waist 38 · head 80 | §3 | silk; cloth | — | H | [CHE], [VA-O364379] |
| `haik_mens` or `burnous` · `slippers_backless` (`yellow`) | wrap 50 · feet | §3 | wool; morocco | — | H | [CHE] |
| commoners: `qashshaba` | shirt or outer | §3 | undyed wool | tunic | H | [CHE] |

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `thob_womens` (with an optional second, coarser shift over it, "tied round their waist") | shirt {10, 25} | §3 | linen, cotton | tunic | H | [CHE] |
| `salvar_womens` | legs.lower 8 | §3 ("The Citizens of both Sexes" wear drawers) | linen | trousers | M | [SHA] |
| `belt_clasp` · `skullcap` (sometimes; plaited hair) · `slippers_backless` (`yellow`) | waist · head · feet | §3 | — | — | H | [CHE] |
| outdoors: `wrap_drape_womens`, preset `haik` | accessories.wrap 50 | §3 | white wool | drape | H | [CHE], [SHA] |

**Better-off**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: a fine `haik_mens` and a white or blue `burnous` (at court with a sabre and a curved dagger on a shoulder belt: gear); a cloth `moorish_qaftan`; a red cap with a white `turban_town` | — | §3 | fine wool, cloth | — | H | [CHE] |
| woman (Chénier: H): an ample fine linen `thob_womens` with the bosom embroidered in gold; a rich `moorish_qaftan` of cloth or velvet worked in gold; a `belt_clasp` of crimson velvet with a gold or silver buckle, or a Fez girdle; yellow slippers | — | §3 | linen, velvet, gold · `crimson`*, `gold_lace` | — | H | [CHE] |
| woman: `moorish_head_wrap_womens` | head 80 | head_wrap `flat`: gauze folds streaked with gold, tied behind, the fringes falling with the tresses to the waist; a band of gold or pearls 2 inches wide round the forehead | gauze with gold | head_wrap | H | [CHE] |
| woman: `moorish_cloth_stockings` | legs.over 30 | leggings, ease 0.04: stockings "of fine cloth … large, which is tied below the knee and at the ancle, over which it falls in folds" (garters at 0.43 and 0.09) | fine cloth | leggings | H | [CHE] |

Henna patterns are a body feature: noted only.

### 4.32 egyptian

Egyptians of the Nile valley and delta, Muslim and Coptic, under Ottoman pashas and the Mamluk beys. Niebuhr (1761) gives the 1760s structure (H). Lane (1825–35) gives the detail (M).

**Basic:** men `thawb` (`eree`) + `drawers_linen`; women `drawers_linen` + `thob_womens`. "The poorer sort wear nothing but those drawers, and a long blue shirt" [NIE].

**Men, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `thawb`, style `eree` | shirt {10, 36} | §3: slit nearly to the waist | blue cotton · `indigo_mid`; brown wool (*zaaboot*) in winter | tunic | H | [LAN], [NIE] |
| `drawers_linen` | legs.lower 30 | §3. The peasant "wears only the shirt and drawers". | linen | trousers | H | [NIE] |
| `sash_shawl` · `turban_common` over a felt `skullcap` and a red felt cap | waist 38 · head 80 | §3 | white or red wool; white, red or yellow woollen cloth or coarse cotton | — | H | [LAN] |
| `aba` · `slippers_backless` (red or yellow) or bare feet | wrap 50 · feet | §3 | black, or brown-and-white | — | H | [LAN] |

**Copts:** dark turbans and dull colours [LAN]; a red cap wrapped in blue-and-white linen [NIE] (H, verified). These are sumptuary presets.

**Women, everyday**

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| `drawers_linen` + `thob_womens` (blue, to the feet) | legs.lower 8 · shirt {10, 25} | §3 | `indigo_mid` cotton | — | H | [NIE] |
| `head_veil_long` (*tarhah*) | head 80 | drape, head-long: over the head and hanging behind "nearly or quite to the ground" | dark-blue muslin or linen (commoners); white muslin embroidered at each end | drape | M | [LAN] |
| outdoors: `wrap_drape_womens`, preset `milayeh` | accessories.wrap 50 | §3 | blue-and-white chequers with red ends | drape | M | [LAN] |
| red slippers or bare feet | feet 40 | §3 | — | — | H | [LAN] |
| Upper Egypt: `draped_dress` (preset *hulaleeyeh*) | vest 36 | §3: "wrapping it round the body, and attaching the upper parts together over each shoulder" | dark wool | wrap_skirt | M | [LAN] |

The face veil (*burqu'*) is with care.

**Better-off** (Lane, 1830s: M)

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| man: a white striped `shirt_collarless`; `yelek_short` (*sudeyree*); `entari`, style `entari_long` (*kuftan*, with split sleeves); a Kashmir or figured-muslin `sash_shawl`; `jubba` (*gibbeh*); `turban_town` on a red cap; red pointed slippers over yellow `mest` | — | §3 | silk, cotton, broadcloth | — | M | [LAN] |
| woman: a fine `thob_womens`; `salvar_womens`, style `shintiyan`; `entari_womens` (*yelek*: to the ground, buttoned, side slits); a girdle of a square shawl folded diagonally (`sash_shawl` preset); a velvet `salta`; `turban_flat_womens` (preset *rabtah*: "a high, flat shape") with a white `head_veil_long` | — | §3 | silk, velvet, muslin | — | M | [LAN] |
| woman, outdoors: `egyptian_tob_sebleh` + `wrap_drape_womens` (preset `habarah`, black silk) | outer 40 · wrap 50 | tunic: pink, rose or violet silk, with sleeves "nearly equal in width to the whole length of the gown" (very large hanging sleeves: M-L feasibility) | silk · `safflower`*, `logwood_plum` | tunic | M | [LAN] |

Niebuhr (1761) confirms the outdoor pattern in Cairo: "a large black veil", and rich clothes "covered with a sort of large wrapper of plain linen".

### 4.33 metis: colonial set only (consultation)

Families of French and Native descent, common in the fur trade and on the lakes.

**Flag the label first.**
- The Métis National Council defines the Métis as a distinct people of historic Métis Nation ancestry, who emerged in the late 18th century in the northwest. It says explicitly that this is not the same as mixed ancestry (H).
- Calling the Great Lakes French–Native families of 1680–1815 "Métis" is a scholarly usage (Peterson 1985). It is contested in politics today (M for the 1750s).
- Example of such a family: Charles Langlade, baptised at Michilimackinac in 1729, whose mother Domitilde was Odawa.

**Now:** the colonial set (§3.1) and the plain trade goods (§3.3). Never label the sash or the capot "Métis". Plain cloth capots fit 1757. The blanket capote made from point blankets is a later form (from 1779).

`peoples.json` gives metis the Eastern Woodlands hair styles, crown locks included. Those need the same review.

**Consult:**
- the Métis National Council;
- the Manitoba Métis Federation, which left the MNC in 2021;
- the Métis Nation of Ontario (its historic communities are disputed by the Chiefs of Ontario);
- the Gabriel Dumont Institute ([gdins.org](https://gdins.org/product/wahwaykinishoo_den_li_kapot/));
- the First Nations those 1750s families belonged to: the Odawa at Michilimackinac, and the Anishinaabe at Sault Ste. Marie (L: not checked one by one).

### 4.34 afro_native: colonial set only (consultation)

"African and Native" is not a nation. In the period these families lived inside particular Native communities, above all the Algonquian towns of southern New England and Long Island (Mandell, *Journal of American History* 85:2, 1998: H).

**Present this people with care (M):** outsiders used intermarriage to question whether these communities were still Native.

**Now:** the colonial set and the plain trade goods. No people-specific garments. `peoples.json` gives afro_native African-descent hair styles only.

**Consult, as their own nations:**
- the [Mashpee Wampanoag THPO](https://mashpeewampanoagtribe-nsn.gov/historic-preservation-nagpra);
- the [Wampanoag Tribe of Gay Head (Aquinnah) THPO](https://wampanoagtribe-nsn.gov/thpo);
- the Narragansett Indian Tribal Historic Preservation Office;
- the Mashantucket Pequot Museum and Research Center;
- the Mohegan Tribe;
- the Shinnecock Indian Nation;
- the Unkechaug Nation;
- Stockbridge-Munsee.

**Also involve:**
- the NMAI and NMAAHC team behind *IndiVisible* (2009);
- the project's sensitivity readers (main_story §16.2).

### 4.35 euro_african

People of European and African descent.

**British North America: reuse the african_american list** (§4.13). Build no separate garments (H). The ads describe people of mixed descent in the same osnaburg and homespun. Some carried better clothes when trying to pass as free. **Do not encode a colour-based dress hierarchy as a default.**

**Basic:** as now.

**Caribbean preset** (Dominica, St Vincent: Brunias, 1765–96, mostly the 1770s–90s, idealised; M-L for 1750–65). Kriz calls his paintings "taxonomic images of specimens". Plain white linen probably dominated real wear more than his stripes suggest.

| id | slot · layer | cut and measurements | cloth · colours | type | cert. | src |
|---|---|---|---|---|---|---|
| women: `shift_linen` (x) · `petticoat` (x) (white or striped) · `jacket_womens` (x) · `kerchief_womens` (x) · `apron` (x) tied at the hips with a front bow · `head_tie` (`full` or `tall`, madras check) | — | as built / §3 | white linen, stripes · `madras_check` | — | M-L | [AF-N11], [CR-BRU] |
| men: `shirt_linen` (x) · `waistcoat_sb` (x) · `breeches` (x) or `trousers_long` in white linen or osnaburg · `round_hat` (x) (felt or straw) · `neckerchief` (x) | — | as built | linen | — | M | [AF-N11] |
| enslaved Caribbean dress (Long, 1774: H): osnaburg shirts and trousers, check linens, striped hollands, fustian, baize, Kendal cottons, "coarse hats, woollen caps, cotton and silk handkerchiefs", blanketing | — | the colonial set | — | — | H | [AF-N10] |
| better-off woman: `gown_close_bodied`; a tall madras `head_tie` topped with a wide `hat_flat_womens` (straw or felt); `mantle_upper_wrap` as a shawl; pearls ("all of the women whose necks are visible are wearing pearls") | — | §3 | silk, muslin | — | M | [AF-N11] |
| better-off man: coat, stock and cocked hat in the colonial cut (x) | — | as built | broadcloth | — | M | [AF-N11] |

**Senegal coast option** (Saint-Louis and Gorée, 1758): the Saint-Louis woman's `west_african_robe` (§4.11). Lindsay notes that the islanders "go very decently apparel'd, and in the French taste" (M).

**Avoid:**
- the tall conical signare headdress (19th-century imagery);
- the racial terms of the ads in ids, names or UI copy (quoted history text only).

## 5. Build order

**Types and gates come first, then the peoples, by game relevance.**

The relevance tiers are my reading of three things:
- the `peoples.json` notes;
- Act 1 (main_story §10.1);
- Vessary's shore-folk (§8.2).

§8.2 names no Earth peoples beyond "the Atlantic world", so the owner should confirm the tiers.

### 5.1 Step 0: gates, before any new people's garment is offered

1. `PlayerOutfit.offered()`: add a filter by people (a `peoples` field on catalog entries) and a review gate that honours the `review` string.
2. Per-people `BASIC` (the **Basic** line of each section).
3. `SLOTS`: add `accessories.shoulder`, `accessories.arms` and `accessories.ears_nose`; later `accessories.head` (and `accessories.face`, with care).
4. Tag `pants` on trousers, drawers, hakama and loincloths. Add the `DENY_TERMS` words in §1.4.
5. Get the cloth shader to draw zone patterns: check, stripes, strip seams, print.

### 5.2 Step 1: engine ops and garments that need no new type

These are cheap, and they serve the 1757 valley.

**Engine work**
- `shirt(bottom=)` and side slits through `coat()`.
- The palette tokens of §2.5.
- The COT, SILK, STRAW and WOOD kits.
- The `print`, `quilting` and `strip_seams` patterns.

**Styles of existing types**

| Built from | Garments |
|---|---|
| shirt | `frock_linen`, `shirt_ruffled` |
| shoes_buckled | `shoes_tied` |
| slops | `trousers_long` |
| jacket | `jacket_short`, `waistcoat_womens`, `bedgown` |
| coat | `greatcoat` |
| petticoat | `petticoat_quilted`, `petticoat_short` |
| cloak_hooded | `cloak_long_hooded` |
| ROUND_HAT | `hat_flat_womens` |
| cap_linen / soft_cap | `french_cornette` (lappets), `mutch` (chin strings) |
| apron | `leather_apron` (bib), `apron_flat` |
| sash | `spanish_faja` |
| leggings | `gaiter_tied` |

**Rebuild on cloth2 (r):** `hunting_shirt_tow` / `hunting_frock`, `leggings_buckskin`, `monmouth_cap`, `mittens_fur`. Also `fur_mantle`, after its review.

### 5.3 Step 2: the new types

They are ordered by how many tier-1 and tier-2 garments each one unlocks.

| Order | Type | First garments | Needs |
|---|---|---|---|
| 1 | T1 `gown` | `gown_open`, `gown_close_bodied`, `gown_sack` | `settlers.weights_from` |
| 2 | T9 `cloak` | `mantelet_hooded`, `spanish_capa`, then `aba`, `burnous`, `kepenek` | `drift.envelope`, `hood.py` |
| 3 | T8 `drape` | `rebozo`, `spanish_mantilla`, `mantle_*`, then the MENA wraps and the shawls | envelope; head-grid anchors |
| 4 | T14 `hand_cover` | `mitts` | — |
| 5 | T5 `wrap_skirt` | `wrapper_knee`, `wrapper_long`, `wrapper_calf`, `wrapper_high`, then the saya, chima and mamianqun | `skirt_hang` |
| 6 | T10 `head_wrap` + soft_cap `skullcap` | `head_band`, `head_tie`, `skullcap`, then the turbans | `hats.tube` |
| 7 | T11 `sandal`, T12 `slipper` | `sandals_leather`, `slippers_backless`, `spanish_alpargatas` | `feet.sole` |
| 8 | T6 `trousers` | `drawers_short`, `drawers_linen`, `salvar_*`, `spanish_calzon`, `dutch_breeches_wide`, then the East Asian trousers | — |
| 9 | T3 `tunic` | `west_african_tunic`, `west_african_robe`, `thawb`, `thob_womens`, `qashshaba` | the closed-skirt weights |
| 10 | T2 `robe` | `entari`, `entari_womens`, `jubba`, `kurk_fur`, then the kosode, jama, changpao and jeogori | `overlap_line`, `trims.extrude`, the fin |
| 11 | T4 `bodice`, T7 `loincloth` | `south_asian_choli`, `vietnamese_yem`, `loincloth` | — |
| 12 | rigid_hat profiles | CONE, DOME_FINIAL, UMBRELLA, GAT, tall crown | `hats.felt_hat` |
| 13 | T13 `rigid_shoe` | `wooden_shoes` | homeland only, so lowest |

### 5.4 Step 3: the peoples, by game relevance

**Tier 1: the 1757 valley** (Acts 1–2: Fort Herkimer, the Flatts, the burned valley, Albany's trade)

| # | People | Why | What to build |
|---|---|---|---|
| 1 | palatine | the player's neighbours (the Rauch farm) | colonial set + `hat_flat_womens`, `frock_linen`, `gown_close_bodied` |
| 2 | english | provincials, regulars, the store (Vane) | `gown_open`, `greatcoat`, `leather_apron`, `mantelet_hooded` (the cardinal), `mitts` |
| 3 | french | the raiders on screen (troupes de la marine and Canadian militia; Toussaint Leclerc) | `petticoat_short`, `french_cornette`, `mantelet_hooded`, `gown_sack`. The men's set already exists. |
| 4 | african_american | enslaved and free people of the valley and Albany | `jacket_short`, `waistcoat_womens`, `trousers_long`, `shoes_tied`, `shirt_ruffled`; read the New York ads first |
| 5 | dutch | Albany and Schenectady (the English set) | `petticoat_quilted`, the jak preset |
| 6 | scots_irish | — | `mutch`, `cloak_long_hooded`, `jacket_short` (frieze), `hunting_shirt_tow` (r) |

- west_african, central_african and euro_african in the valley wear the colonial set: nothing extra.
- haudenosaunee: on hold.

**Tier 2: Vessary's docks** (Act 4: Landfall and the shore-folk: "rovers, castaways and mast-cutters, and free Black sailors and freedom-seekers from the Atlantic world")

| # | People | What to build |
|---|---|---|
| 7 | african_american and euro_african sailors and Landfall families | the sea set exists; + `head_tie`, the Caribbean preset |
| 8 | west_african | the homeland set: `wrapper_*`, `mantle_*`, `head_band`, `skullcap`, `west_african_tunic`, `west_african_trousers_wide`, `sandals_leather` |
| 9 | central_african | the homeland set |
| 10 | spanish | Atlantic sailors and Florida: `spanish_capa`, `spanish_sombrero_gacho`, `spanish_faja`, `spanish_calzon`, `spanish_alpargatas`; women's `spanish_basquina`, `spanish_mantilla`, `rebozo` |
| 11 | moorish | here if "rovers" includes the Salé rovers of Rabat-Salé; otherwise tier 3 |
| 12 | south_asian | the lascars first (slops + `south_asian_pagri`), then the full set |
| 13 | filipino | the Manila men first (slops + putong / `filipino_salakot`), then the full set |
| 14 | chinese | sailors and artisans of the Manila and Atlantic trades |
| 15 | malay | sailors of the Straits |
| 16 | japanese | castaways |

**Tier 3: the merchant peoples of the Mediterranean and the Indian Ocean.** The shared MENA set (§3.4) is built once and covers all nine.

17. levantine
18. ottoman_turkish
19. armenian
20. arab
21. egyptian
22. persian
23. moorish (if not in tier 2)

**Tier 4:**

24. kurdish
25. north_african
26. ethiopian
27. korean
28. vietnamese
29. thai

**Held:**
- haudenosaunee, lenape, shawnee and wabanaki;
- metis and afro_native, beyond the colonial set;
- pacific_islander;
- the Highland and Lowland Scottish set (§4.2a). The owner decides between a `highland_scots` people and a Highland regiments military set.

## 6. Open gaps

**North America and Europe**
- The New York and New Jersey runaway ads (Hodges & Brown): read them before building the african_american presets.
- d'Aleyrac's sash quote in `sash_worsted`: check the wording. Also find the publisher of the French women's guideline that quotes him.
- The date of the "Dutch calicoe quilted cap" notice (`palatine_cap_quilted`).

**Africa**
- Yoruba (Oyo); Mbundu and Luanda; Oromo and Muslim (Jabarti) Ethiopians.
- Prutky's travels (in Gondar, 1752).

**Asia**
- The texts of the Edo edicts.
- An 18th-century measurement for the gat brim.
- The Korean men's jacket length and the baji crotch depth (both inferred).
- The Chinese apron, leg bindings and waist sash (19th-century evidence).
- Northern Vietnam: Đoàn Thị Tình 2006, and Baron 1685.
- The Ayutthaya pha khao ma and ngop hat; Indian footwear; 18th-century Filipino headwear and footwear.

**Middle East**
- Mount Lebanon and Palestinian villagers; Anatolian village women.
- Høst's plates (1779) and Favray's paintings.
- The headcloth cord before about 1800.

**Pacific**
- Hawaii, Tonga and Samoa (Cook's third voyage; the Bishop Museum).
- Who the Pacific offices are.

**Consultation and project files**
- Consultation for all six Woodlands and mixed-ancestry peoples.
- The missing costume bible (`source/graph_analysis/customizer/costume_bible.md`).

## 7. Sources

Each key links to its page. The project files read were:
- `tools/character/cloth2/garment.py`, `recipes.py`, `spec.py`, `hats.py`, `palette.json` and the garment modules;
- `scripts/customizer/player_outfit.gd`;
- `assets/character/body/peoples.json` and `assets/character/catalog.json`;
- `tools/character/lib/catalog.py`;
- `docs/main_story.md` and `docs/maps.md`.

### Europe
- [EU-K1] Kalm on Albany, 1749 (New York State Museum). [EU-K2] Grant, *Memoirs of an American Lady*.
- [EU-R1] Rijksmuseum BK-BR-609, a woman's jacket from Hindeloopen (1750, or 1810–20). [EU-R2] Oorijzer. [EU-R3] Klederdracht (Nederland). [EU-R4] "Why Vondel looked like a fisherman in harem trousers". [EU-R5], [EU-R5b] Dutch jackets in runaway notices ("Dutch" also meant German).
- [EU-H1] History of Parliament on the Dress Act. [EU-H2] Burt's *Letters* (written c. 1727–37, published 1754), quoted in the Arisaid article; [EU-H2b] Edmund Burt. [EU-H3] Pennant, *Tour in Scotland 1769*, via the Dictionary of the Scots Language. [EU-H5a] NMS arisaid; [EU-H5b] NMS kilt suit c. 1790–1800; [EU-H5c] NMS trews. [EU-H6a], [EU-H6b], [EU-H6c] The blue bonnet. [EU-H7] Dictionary of the Scots Language, "mutch". [EU-H8a] Trews; [EU-H8b] Full plaid.
- [EU-U1] Washington to Bouquet, 13 July 1758. [EU-U2] *Pennsylvania Gazette* runaway notices (Steel 1751, O'Daniel 1756, Beard 1766). [EU-U3] The Kinsale cloak.
- [EU-E1] Smock-frock. [EU-E2], [EU-E2b] V&A bedgowns. [EU-E3], [EU-E3b] V&A hats. [EU-E4] Readex: working women's dress in runaway notices.
- [EU-F1] Tomczyszyn, thesis on Quebec clothing 1635–1760. [EU-F2] Canadian Encyclopedia, clothing in the colonial period. D'Aleyrac (in Canada 1755–60), quoted in a reenactor guideline whose publisher could not be confirmed.
- [EU-G1] Goschenhoppen Historians, colonial clothing.
- [EU-S1] The Esquilache riots (the decree of 10 March 1766). [EU-S2] FIT, the Spanish cape. [EU-S3] Basquiña; [EU-S3b] the maja dress; [EU-S3c] Majismo. [EU-S5] Lorenzo Tiepolo, Prado. [EU-S6] Florida Museum, St. Augustine. [EU-S7] Tucson Presidio living-history guide (a reenactor source: M-L). [EU-S8], [EU-S8b] The rebozo. [EU-S9] The mantilla. Cano y Olmedilla, *Colección de trajes de España* (1777–88), Biblioteca Nacional de España (not linked).
- Critic's checks: [CR-CF] Ceinture fléchée; [CR-TAN] Tantour; [CR-BRU] Agostino Brunias. Diderot's *Encyclopédie* plates (1751–72)† (not linked).

### Africa and the African diaspora
- [AF-A1] Bosman, *Coast of Guinea* (1704/05). [AF-A2] Moore, *Travels into the Inland Parts of Africa* (1738). [AF-A3] Lindsay, *A Voyage to the Coast of Africa in 1758*. [AF-A4] Equiano, *Interesting Narrative* (1789; his birthplace is disputed: M). [AF-A5] Kriger, "Guinea Cloth". [AF-A6] Kente; [AF-A6b] Adinkra.
- [AF-C1] Fromont, "Foreign Cloth, Local Habits" (2017), on d'Asti c. 1750. [AF-C3] Vansina, raffia cloth 1500–1800 (summary). [AF-C4] The Capuchin text; [AF-C4b] Kongo textiles. Cavazzi, *Istorica descrizione* (1687) (not linked).
- [AF-E1] Poncet, *A Voyage to Aethiopia* (1709). [AF-E2], [AF-E2b], [AF-E2c] Bruce, *Travels* (1790; in Ethiopia 1769–72). [AF-E3] V&A shamma 401-1869; [AF-E3b] V&A kamis 400-1869. [AF-SALT] Salt (1814).
- [AF-N1] Geography of Slavery in Virginia (University of Virginia). [AF-N2] Historic Deerfield. [AF-N3] NPS, stockings of Rhode Island runaways. [AF-N4] Global Threads Manchester. [AF-N5] Colonial Williamsburg survey (seen via a search summary). [AF-N6] A linsey-woolsey jacket, c. 1775. [AF-N7], [AF-N7b] The Still Room, runaway clothing database. [AF-N9] Baumgarten via the Revolutionary War Journal. [AF-N10] Long, *History of Jamaica* (1774). [AF-N11] FIT, Brunias. [AF-N12] *The Old Plantation*. Hodges & Brown, *"Pretends to Be Free"* (not consulted).

### East Asia
- [EA-J1] Thunberg, *Travels*, vol. 3 (1795; observed 1775–76). [EA-J2] Tokyo Metropolitan Library, Edo fashion. [EA-J3] Obi. [EA-J4] Kosode. [EA-J5] Met, *Kimono Style*. [EA-J6] Kyoto Prefectural Archives, Edo women's costume. [EA-J7] Haori. [EA-J8] Segawa Kikunojō II (rokō-cha). [EA-J9] Kogin-zashi. [EA-J10] Harunobu, c. 1765 (Met). [EA-J11] nippon.com, happi (modern: M). [EA-J12] Tasuki.
- [EA-C1] Osbeck, *A Voyage to China* (Canton, 1751). [EA-C2] *Prosperous Suzhou* (1759). [EA-C3] Met 1988.350, the Southern Inspection Tour. [EA-C5] Garrett, *Chinese Dress*. [EA-C6] NMS, the cotton of ordinary people. [EA-C7] Magua (also the Changshan, Mamianqun, Guapi mao and Asian conical hat articles). [EA-C8] Nankeen.
- [EA-K1] Madam Yoon's jacket (Seok Juseon Memorial Museum). [EA-K2] Sim Hwa-jin, *J. Korean Society of Costume* 50(2), 2000. [EA-K3] Encyclopedia of Korean Culture, paeraengi (also the work skirt, jungchimak, jangot and gat entries). [EA-K4] AKS costume dictionary, heungnip (also the haengjeon and baji entries). [EA-K5] Met, Korean genre painting. [EA-K6] Women's hairstyles in Joseon. [EA-K7] Chima. [EA-K8] Korea Times, white clothing. [EA-K9] Choi 2015 (late 19th century: L).

### South and Southeast Asia, and the Pacific
- [SA1] V&A jama, 18th century; [SA2] V&A jama IS.8-1968; [SA3] V&A angarkha; [SA4] V&A peshwaz; [SA5] V&A patka; [SA6] V&A Kashmir shawl, c. 1750–60; [SA7] Tanjore caste and occupation paintings, c. 1770–1800; [SA8] V&A choli, c. 1830–40 (measurements only); [SA9] Solvyns (1796–99); [SA10] an 18th-century Rajasthani painting.
- [PH1] The Murillo Velarde map, 1734; [PH2] Barong tagalog (cites Coo 2014); [PH3] Clothing in the Philippines (cites Coo 2014); [PH4] The baro't saya; [PH5] The salakot.
- [VN1] Hội An heritage, dress practices (cites Lê Quý Đôn, Thích Đại Sán 1696, Borri 1618); [VN2] Áo dài; [VN3] Yếm; [VN4] Vietnamese clothing; [VN5] Khăn vấn; [VN6] William Alexander, 1793; [VN7] Đoàn Thị Tình 2006 (not read); [VN8] Áo tứ thân.
- [TH1] La Loubère, *A New Historical Relation of the Kingdom of Siam* (1693); [TH2] History of Thai clothing; [TH3] V&A pha nung; [TH4] The Wat Ko Kaeo Suttharam murals, 1734; [TH5] GWU, Thai textiles.
- [ML1] Marsden, *The History of Sumatra* (1783); [ML2] V&A Makassar sarong, 18th century; [ML3] Baju kurung.
- [PI1] Cook, *Journal* of the first voyage (1768–71); [PI2] Tapa cloth; [PI3] Māori traditional textiles.

### Middle East and North Africa
- [NIE] Niebuhr, *Travels through Arabia* (1761–67; English 1792), vols 1–2. [RUS] Russell, *Natural History of Aleppo* (2nd edition 1794; Aleppo 1740s–71). [HAN] Hanway, *British Trade over the Caspian Sea* (1753; Persia 1743–45). [SHA] Shaw, *Travels … Barbary and the Levant* (1738). [CHE] Chénier, *The Present State of the Empire of Morocco* (1788; consul 1767–82). [LEM] Lemprière, *A Tour from Gibraltar to Tangier* (1791). [MWM] Lady Mary Wortley Montagu, *Letters* (1717). [LAN] Lane, *Modern Egyptians* (1825–35). [BUR] Burckhardt, *Notes on the Bedouins* (1810–12). [RIC] Rich, *Koordistan* (1820).
- [DIB] Diba, "Clothing x", *Encyclopaedia Iranica*. [IRK] Iranica, Kurdish clothing (summary only). [TRC] TRC Leiden, the Kurds of western Iran. [ARM] Armenian dress (19th–20th c.). [ASL] UCLA, "Of Hats and Men". [QUA] Quataert, clothing laws in the Ottoman Empire (abstract only).
- [VA-O364379] V&A, Moroccan sash; [VA-O319391] V&A, Syrian jubbah; [VA-O319327] V&A, keffiyeh.

[EU-K1]: https://exhibitions.nysm.nysed.gov/albany/art/kalm.html
[EU-K2]: https://exhibitions.nysm.nysed.gov/albany/art/grant4.html
[EU-R1]: https://www.rijksmuseum.nl/en/collection/BK-BR-609
[EU-R2]: https://en.wikipedia.org/wiki/Oorijzer
[EU-R3]: <https://nl.wikipedia.org/wiki/Klederdracht_(Nederland)>
[EU-R4]: https://the-low-countries.com/article/why-vondel-looked-like-a-fisherman-in-harem-trousers
[EU-R5]: https://kittycalash.com/2012/07/13/dutch-treat/
[EU-R5b]: https://mimicofmodes.com/2012/07/14/dutch-jacket/
[EU-H1]: https://historyofparliament.com/2020/11/17/banning-scottish-highland-dress-in-the-aftermath-of-culloden/
[EU-H2]: https://en.wikipedia.org/wiki/Arisaid
[EU-H2b]: https://en.wikipedia.org/wiki/Edmund_Burt
[EU-H3]: https://www.dsl.ac.uk/entry/snd/tunag
[EU-H5a]: https://nms.ac.uk/explore-our-collections/stories/scottish-history-and-archaeology/highland-style/highland-style-sub-pages/arisaid-c1790
[EU-H5b]: https://nms.ac.uk/explore-our-collections/stories/scottish-history-and-archaeology/highland-style/highland-style-sub-pages/kilt-suit-c1790-1800
[EU-H5c]: https://www.nms.ac.uk/explore-our-collections/collection-search-results/trews/636069
[EU-H6a]: https://www.futuremuseum.co.uk/collections/life-work/key-industries/textiles/bonnet-making/kilmarnock-bonnet-1
[EU-H6b]: https://selvedge.org/blogs/selvedge/the-scots-blue-bonnet-1
[EU-H6c]: https://www.marariley.net/knitting/caps.htm
[EU-H7]: https://www.dsl.ac.uk/entry/snd/mutch
[EU-H8a]: https://en.wikipedia.org/wiki/Trews
[EU-H8b]: https://en.wikipedia.org/wiki/Full_plaid
[EU-U1]: https://founders.archives.gov/documents/Washington/02-05-02-0224
[EU-U2]: https://allthingsliberty.com/2017/04/runaway-day-5-5/
[EU-U3]: https://en.wikipedia.org/wiki/Kinsale_cloak
[EU-E1]: https://en.wikipedia.org/wiki/Smock-frock
[EU-E2]: https://collections.vam.ac.uk/item/O360251/bedgown-unknown
[EU-E2b]: https://collections.vam.ac.uk/item/O360256/bedgown-unknown
[EU-E3]: https://collections.vam.ac.uk/item/O85963/hat-unknown
[EU-E3b]: https://collections.vam.ac.uk/item/O357072/hat-unknown
[EU-E4]: https://www.readex.com/readex-report/issues/volume-11-issue-3/runaway-recapturing-information-about-working-womens-dress
[EU-F1]: https://mspace.lib.umanitoba.ca/items/35551f1e-322f-4810-b619-4a2db3ad275b
[EU-F2]: https://www.thecanadianencyclopedia.ca/en/article/clothing-during-the-colonial-period
[EU-G1]: https://goschenhoppen.org/colonial-clothing/
[EU-S1]: https://en.wikipedia.org/wiki/Esquilache_Riots
[EU-S2]: https://fashionhistory.fitnyc.edu/spanish-cape/
[EU-S3]: https://es.wikipedia.org/wiki/Basqui%C3%B1a
[EU-S3b]: https://historylab.es/es/vestido-de-maja/
[EU-S3c]: https://es.wikipedia.org/wiki/Majismo
[EU-S5]: https://www.museodelprado.es/en/the-collection/art-work/young-man-smoking/3d18e99f-690f-4efe-b0e2-6c53545af3c3
[EU-S6]: https://www.floridamuseum.ufl.edu/staugustine/timeline/criollas-soldiers/
[EU-S7]: https://tucsonpresidio.com/spanish-colonial-costumes-a-guide-for-living-history-volunteers/
[EU-S8]: https://unframed.lacma.org/node/1552
[EU-S8b]: https://smithsonianeducation.org/textiles/english/gallery/rebo_de.htm
[EU-S9]: https://en.wikipedia.org/wiki/Mantilla
[CR-CF]: https://en.wikipedia.org/wiki/Ceinture_fl%C3%A9ch%C3%A9e
[CR-TAN]: https://en.wikipedia.org/wiki/Tantour
[CR-BRU]: https://en.wikipedia.org/wiki/Agostino_Brunias
[AF-A1]: https://archive.org/details/newaccuratedescr00bosm
[AF-A2]: https://archive.org/details/travelsintoinlan00moor
[AF-A3]: https://archive.org/details/avoyagetocoasta00lindgoog
[AF-A4]: https://www.gutenberg.org/ebooks/15399
[AF-A5]: https://www.lse.ac.uk/Economic-History/Assets/Documents/Research/GEHN/Helsinki/HELSINKIKrieger.pdf
[AF-A6]: https://en.wikipedia.org/wiki/Kente_cloth
[AF-A6b]: https://en.wikipedia.org/wiki/Adinkra_symbols
[AF-C1]: https://revistas.usp.br/anaismp/article/view/139689
[AF-C3]: https://www.africanhistoryextra.com/p/textile-trade-and-industry-in-the
[AF-C4]: https://mavcor.yale.edu/node/3888
[AF-C4b]: https://en.wikipedia.org/wiki/Kongo_textiles
[AF-E1]: https://archive.org/details/avoyagetothiopi00poncgoog
[AF-E2]: https://www.gutenberg.org/ebooks/54181
[AF-E2b]: https://www.gutenberg.org/ebooks/54531
[AF-E2c]: https://www.gutenberg.org/ebooks/56502
[AF-E3]: https://collections.vam.ac.uk/item/O143073/
[AF-E3b]: https://collections.vam.ac.uk/item/O143065/
[AF-SALT]: https://archive.org/details/avoyagetoabyssi00saltgoog
[AF-N1]: https://www2.vcdh.virginia.edu/gos/
[AF-N2]: https://www.historic-deerfield.org/2020-8-14-picturing-slavery-clothing-appearance-and-new-england-advertisements-for-run-away-enslaved-men-during-the-18th-century/
[AF-N3]: https://www.nps.gov/articles/000/stockings-of-runaways-advertised-in-rhode-island-by-paul-dickfoss.htm
[AF-N4]: https://globalthreadsmcr.org/control-and-contestation-clothing-for-enslaved-people/
[AF-N5]: https://www.colonialwilliamsburg.org/discover/sources/the-virginia-gazettes/slavery-and-the-virginia-gazette/a-survey-of-the-material-culture-of-enslaved-black-women-through-runaway-slave-advertisements/
[AF-N6]: https://susanhollowayscott.com/blog/2019/9/10/a-linsey-woolsy-jacket-for-an-enslaved-woman-c1775
[AF-N7]: https://thestillroomblog.com/2012/12/21/shifting-garment-styles-1750-1790-history-as-sketching/
[AF-N7b]: https://thestillroomblog.com/2012/07/20/variety-among-the-18th-century-lesser-sorts/
[AF-N9]: https://revolutionarywarjournal.com/colonial-slave-clothing/
[AF-N10]: https://archive.org/details/historyjamaicao02longgoog
[AF-N11]: https://fashionhistory.fitnyc.edu/c-1770-96-brunias-free-women/
[AF-N12]: https://en.wikipedia.org/wiki/The_Old_Plantation
[EA-J1]: https://darwin-online.org.uk/converted/Ancillary/BeagleLibrary/1795-6_Thunberg_A719.03.html
[EA-J2]: https://www.library.metro.tokyo.lg.jp/portals/0/edo/tokyo_library/english/fashion/page2-1.html
[EA-J3]: <https://en.wikipedia.org/wiki/Obi_(sash)>
[EA-J4]: https://en.wikipedia.org/wiki/Kosode
[EA-J5]: https://www.metmuseum.org/press-releases/kimono-style-2022-exhibitions
[EA-J6]: https://artsandculture.google.com/story/_QWx99wNZFNvLw
[EA-J7]: https://en.wikipedia.org/wiki/Haori
[EA-J8]: https://kabuki21.com/kikunojo2.php
[EA-J9]: https://en.wikipedia.org/wiki/Kogin-zashi
[EA-J10]: https://www.metmuseum.org/art/collection/search/54572
[EA-J11]: https://www.nippon.com/en/guide-to-japan/cs00090/
[EA-J12]: <https://en.wikipedia.org/wiki/Tasuki_(sash)>
[EA-C1]: https://archive.org/details/voyagetochinaeas01osbe
[EA-C2]: https://en.wikipedia.org/wiki/Prosperous_Suzhou
[EA-C3]: https://www.metmuseum.org/art/collection/search/41493
[EA-C5]: https://fashionhistory.fitnyc.edu/source-database/global-fashion/asia/east-asia/chinese-dress-from-the-qing-dynasty-to-the-present-2007
[EA-C6]: https://www.nms.ac.uk/discover-catalogue/the-material-lives-of-ordinary-people-rare-19th-century-chinese-cotton
[EA-C7]: <https://en.wikipedia.org/wiki/Magua_(clothing)>
[EA-C8]: https://en.wikipedia.org/wiki/Nankeen
[EA-K1]: https://artsandculture.google.com/asset/jeogori-madam-yoon-s-jacket-unknown/NgG7ibUYdACk4g
[EA-K2]: https://koreascience.or.kr/article/JAKO200011919951994.page
[EA-K3]: https://encykorea.aks.ac.kr/Article/E0059795
[EA-K4]: <https://dh.aks.ac.kr/~katd/wiki/index.php/복식사전:흑립>
[EA-K5]: https://www.metmuseum.org/essays/work-and-leisure-eighteenth-century-genre-painting-in-korea
[EA-K6]: https://gwangjunewsgic.com/arts-culture/korean-culture/womens-hairstyles-in-joseon-korea/
[EA-K7]: <https://en.wikipedia.org/wiki/Chima_(clothing)>
[EA-K8]: https://www.koreatimes.co.kr/opinion/20260912/why-did-everyone-in-old-korea-wear-white
[EA-K9]: https://db.koreascholar.com/Article/Detail/299031
[SA1]: https://collections.vam.ac.uk/item/O74009/robe-mans-robe-jama/robe-unknown/
[SA2]: https://collections.vam.ac.uk/item/O144142/jama-unknown/
[SA3]: https://collections.vam.ac.uk/item/O155023/
[SA4]: https://collections.vam.ac.uk/item/O470782/
[SA5]: https://collections.vam.ac.uk/item/O455709/patka
[SA6]: https://collections.vam.ac.uk/item/O139698/
[SA7]: https://collections.vam.ac.uk/item/O405373/a-south-indian-sepoy-and-painting-unknown
[SA8]: https://collections.vam.ac.uk/item/O475966
[SA9]: https://en.wikipedia.org/wiki/Frans_Balthazar_Solvyns
[SA10]: https://icvtesting.nvli.in/museum-paintings/lady-grove
[PH1]: https://artesdelasfilipinas.com/archives/the-murillo-velarde-map-1734-a-fascinating-record-of-filipino-life
[PH2]: https://en.wikipedia.org/wiki/Barong_tagalog
[PH3]: https://en.wikipedia.org/wiki/Fashion_and_clothing_in_the_Philippines
[PH4]: https://philippinefolklifemuseum.org/portfolio-items/barot-saya
[PH5]: https://en.wikipedia.org/wiki/Salakot
[VN1]: https://hoianheritage.net/en/specialised-exchanges/research-exchange/dress-practices-of-the-people-of-hoi-an-48.html
[VN2]: https://en.wikipedia.org/wiki/%C3%81o_d%C3%A0i
[VN3]: https://en.wikipedia.org/wiki/Y%E1%BA%BFm
[VN4]: https://en.wikipedia.org/wiki/Vietnamese_clothing
[VN5]: https://en.wikipedia.org/wiki/Kh%C4%83n_v%E1%BA%A5n
[VN6]: https://album-online.com/detail/en/ZTAzYWFhMA/william-alexander-portrait-cochin-chinese-soldier-a-barefoot-standing-full-alb4090278
[VN7]: https://lib.hpu.edu.vn/handle/123456789/24381
[VN8]: https://en.wikipedia.org/wiki/%C3%81o_t%E1%BB%A9_th%C3%A2n
[TH1]: https://vajirayana.org/v2/asia/a-new-historical-relation-of-the-kingdom-of-siam/part-ii-of-the-manners-of-the-siameses-in-general/chap-i
[TH2]: https://en.wikipedia.org/wiki/History_of_Thai_clothing
[TH3]: https://collections.vam.ac.uk/item/O39283
[TH4]: https://spafajournal.org/index.php/spafajournal/article/view/955
[TH5]: https://collectionstories.museum.gwu.edu/?p=3687
[ML1]: https://www.gutenberg.org/ebooks/16768
[ML2]: https://collections.vam.ac.uk/item/O453988/
[ML3]: https://en.wikipedia.org/wiki/Baju_kurung
[PI1]: https://www.gutenberg.org/ebooks/8106
[PI2]: https://en.wikipedia.org/wiki/Tapa_cloth
[PI3]: https://en.wikipedia.org/wiki/M%C4%81ori_traditional_textiles
[NIE]: https://archive.org/details/b28773263_0001
[RUS]: https://archive.org/details/naturalhistoryof01russ
[HAN]: https://archive.org/details/b30414702_0001
[SHA]: https://archive.org/details/travelsobservati00shaw
[CHE]: https://archive.org/details/b28771515_0001
[LEM]: https://archive.org/details/tourfromgibralta00lemprich
[MWM]: https://archive.org/details/lettersladymaryw00mont
[LAN]: https://archive.org/details/accountofmanners00lane
[BUR]: https://archive.org/details/notesonbedouins00burcgoog
[RIC]: https://archive.org/details/narrativeofresid01richuoft
[DIB]: https://www.iranicaonline.org/articles/clothing-x/
[IRK]: https://www.iranicaonline.org/?p=9828
[TRC]: https://trc-leiden.nl/trc-digital-exhibition/index.php/beyond-the-chador-regional-dress-from-iran/item/257-5-the-kurds-of-western-iran
[ARM]: https://en.wikipedia.org/wiki/Armenian_dress
[ASL]: https://modernarmenianhistory.history.ucla.edu/2020/02/04/blog-11
[QUA]: https://www.cambridge.org/core/journals/international-journal-of-middle-east-studies/article/clothing-laws-state-and-society-in-the-ottoman-empire-17201829/72775D2B3D53BBF757AD9C16A39361DC
[VA-O364379]: https://collections.vam.ac.uk/item/O364379
[VA-O319391]: https://collections.vam.ac.uk/item/O319391
[VA-O319327]: https://collections.vam.ac.uk/item/O319327
