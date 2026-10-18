# The anime look of bending: a reference sheet for the element effects

Written 2026-10-16 by the element team's reference finder. **Word note:** this is a reference doc, not player text,
so it uses the show's words (bending, Avatar, the characters' and places' names). Player-facing strings never do
(`tests/ring/test_player_words.gd`). **Asset note:** descriptions and links only; nothing of the show is copied,
saved or traced into this repository (see `docs/reference/README.md`).

What this doc covers: the look all four elements share in *Avatar: The Last Airbender* (2005-2008, Nickelodeon;
animated in Korea by JM Animation, DR Movie and Moi Animation) and what *The Legend of Korra* (2012-2014, Studio
Mir; Studio Pierrot for the first half of Book Two) adds. Each element's own gather, shapes and timing are in
`avatar_<element>.md`.

How to read the frame counts: the show is 24 frames a second, drawn mostly "on twos" (one new drawing every two
frames, 12 a second) with fast action and effects "on ones". Frame counts below are typical 2D figures for this kind
of action, written from memory of the episodes, not measurements of the show. Verify on the named scenes before
locking a number.

## 1. What "anime style" meant to the show's makers

- The co-creators (Michael Dante DiMartino, Bryan Konietzko) named Hayao Miyazaki, Studio Gainax (Evangelion, FLCL)
  and Kôji Morimoto as influences and chose the style partly so the Korean studios could draw what they were best
  at. Konietzko, 2005: "we wanted to steer away from the flatness a lot of the shows have going now, the really
  graphic style. We wanted a more atmospheric, cinematic feel". So: cel-shaded characters and effects over
  painterly, atmospheric backgrounds, not a flat graphic poster look.
  Source: Animation Magazine, "Avatar Bends it Like Anime on Nick" (Feb 2005),
  https://www.animationmagazine.net/2005/02/avatar-bends-it-like-anime-on-nick/
- Every bending move was choreographed by the martial-arts consultant Sifu Kisu (Northern Shaolin), filmed on video
  from the storyboard's camera angles, and handed to the animators as reference; "we never did motion capture once".
  Early pencil tests "showed rough drafts of how each element would look from different angles". The show's bending
  is therefore real human motion with the element drawn as the body's extension, not a particle system attached to a
  hand. Source: Kung Fu Kingdom, "Interview with Sifu Kisu", https://kungfukingdom.com/interview-with-sifu-kisu/
- Which art drives which element (the Avatar Wiki's "Connection" sections, confirmed by Kisu's interviews and the
  live-action stunt team): water = Yang/Chen taijiquan (tai chi), earth = Hung Gar (Toph: Southern Praying
  Mantis), fire = Northern Shaolin (changquan, with some Northern Praying Mantis and xingyi), air = Baguazhang
  (circle walking) with a hint of xingyiquan. The element's motion inherits the art's character: water flows and
  turns, earth roots and strikes, fire explodes along straight lines and kicks, air circles.
- Korra's creators (2012): "even though we use computers to make the show, character animation and bending effects
  remain hand-drawn". Source: The Hollywood Reporter guest post "Legend of Korra creators: 5 things",
  https://www.hollywoodreporter.com/live-feed/legend-korra-creators-5-things-312068 (fetch now redirects through
  a paywall gateway; the quote is as reported by search results and by Mental Floss,
  https://www.mentalfloss.com/entertainment/tv/the-legend-of-korra-tv-series-facts).

## 2. Line and colour: effects are drawn as shapes, not clouds

- **Cel colours.** Every object is a base colour plus one shadow tone (two on big objects or in Korra), a highlight,
  and a closed outline. The outline is dark but not black: a dark brown on skin and cloth, a dark red-brown on
  fire, a deep blue on water, a dark grey-brown on rock. Air is the exception (section 6).
- **An effect has a silhouette.** Fire is a flame-shaped mass with pointed tongues at its edge; water is a tube or a
  ribbon with a rounded tip; a boulder is a faceted polyhedron; an air blast is a cone or a ring. You could cut each
  one out with scissors. There is no fuzzy cloud of particles standing in for the element; even dust and smoke are
  drawn as puffs with a rim.
- **Interior tones are bands, not gradients.** A flame is three to four flat bands (red-orange rim, orange, yellow,
  pale core) whose boundaries wobble frame to frame. Water has a mid-blue body, a lighter band along the top, white
  at the leading edge. Rock has a lit face, a mid face, a shadow face. The bands move with the shape; they are
  not a texture scrolling across it.
- **Scale cues are in the drawing.** A big effect gets more tongues, more facets, more foam, and darker outlines,
  not more blur. Enormous fire (the comet finale) is drawn as a filled frame of two or three bands with the
  background bleached.
- **Transparency is used sparingly**: air, mist and the inner glow of a lightning bolt. Fire and water are opaque
  (water sometimes shows what is behind it as a darker tint, mostly in close-ups).

## 3. Timing: anticipation, snap, hold, follow-through

The 2D grammar every bending move follows (Wikipedia's "Twelve basic principles of animation" is the general
reference: https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation):

1. **Anticipation (the gather).** The body loads in the opposite direction of the move and the element gathers:
   water lifts from its source, earth cracks under a planted foot, fire buds at the knuckles, air swirls round the
   hands. Typically 4 to 12 frames (0.15 to 0.5 s) for a basic strike; much longer for a charged cast (a fire
   charge or a lightning wind-up runs 1 to 3 s, and the drawing shows the charge growing).
2. **The snap (the release).** One or two drawings carry the whole release. The limb arrives at full extension and
   the element leaves it in the same drawing or the next. This is where smears live (section 4). 2 to 4 frames.
3. **The hold (the pose).** The bender stays in the finished stance while the element travels. A clean, readable
   silhouette, typically 6 to 12 frames (0.25 to 0.5 s) before the recovery. Fire masters hold longest; water
   benders flow straight into the next sweep; airbenders are already turning.
4. **Follow-through and settle.** The element and the loose parts (sleeves, hair, a water tail, dust) overshoot
   and settle a few frames after the body stops. The element always lags the hand by 2 to 4 frames and then
   catches up (the "drag"); that lag is what makes water read as heavy and air as light.
5. **Moving holds.** Nothing is ever truly frozen: a held flame flickers (its tongues change every other frame), held
   water sways, a held rock has dust trickling off it, held air has lines drifting.

Scenes to time this against: Zuko's fire blasts in the Agni Kai of "The Southern Air Temple"; Katara's whip in
"The Waterbending Scroll"; Toph's pillar launch in "The Blind Bandit"; Aang's air-blast kick shattering a catapulted rock in "Winter Solstice, Part 2: Avatar Roku" (wiki).

## 4. Smears, multiples and speed lines

- **Smear frames**: on the release drawing, a fast limb or element is drawn stretched between its start and end
  positions, often with a few repeated edges, for 1 or 2 frames. A whip becomes a long tapering streak with the tip
  drawn twice; a fire punch's bolt is a stretched teardrop on the frame it leaves the fist; an air blast is a
  stretched cone. General reference: https://en.wikipedia.org/wiki/Smear_frame (describes the technique; the
  show is a sensible example but not treated there).
- **Multiples**: several copies of a hand or foot in one drawing during a flurry (fire jabs, Ty Lee's chi-blocking
  strikes), each copy fainter.
- **Speed lines** on the background or around a fast object: radiating lines towards the camera for a charge;
  horizontal streaks for a dash (earth skating, air running). Korra uses these more than the original.
- The element's trail is drawn as a shape, too: a thrown boulder leaves a wedge of dust and chips; a fire bolt leaves
  a tail of detached tongues that shrink; a water whip sheds teardrops with white highlights.

## 5. Impact: flashes, bursts and the hit

- On a heavy hit the show uses a **flash frame** (one or two frames of white or of the element's pale colour), a
  **radial burst** (a star of spikes, or a ring, drawn in the element's colour then white), **screen shake** on the
  camera, and a **dust or spray ring** at the point of contact that expands and fades in 6 to 10 frames.
- Classic monochrome anime **impact frames** (black-and-white inversions, Yutaka Nakamura style) are not typical of
  the original series; it prefers flashes and radial bursts. Korra uses more high-contrast and silhouette moments.
  General reference for the technique: Know Your Meme's culture entry,
  https://knowyourmeme.com/memes/cultures/impact-frames and 80.lv's note on Pierrick Picaut's impact-frame
  breakdown (contrast, directionality, expressionism),
  https://80.lv/articles/learn-how-to-add-accents-to-your-animations-with-impact-frames
- **The hit is sold by the receiver**: the struck body is thrown in a straight line with a smear, lands with a dust
  ring, the element that hit them dissipates in the same instant (fire to a puff of smoke and embers, water to
  spray and a puddle, rock to rubble, air to lifted dust). No lingering particle cloud.

## 6. Each element's palette

Described from memory of the episodes; hex values are not published by the production. Pick ours by eye against
these descriptions.

| Element | Body | Bands and rims | Outline | At night | Notes |
|---|---|---|---|---|---|
| Fire | orange | red-orange outer rim, yellow mid, pale yellow to white core | dark red-brown | becomes the light source: faces and ground take an orange glow | Azula's fire: cobalt blue rim, lighter blue mid, pale cyan or white core. Lightning: white core with a blue halo, jagged, 1-2 frames per shape. The dragons' fire in "The Firebending Masters": rainbow bands (white, yellow, orange, red, purple, green, pink), a one-off. |
| Water | mid blue, a little green-grey in rivers | lighter blue band along the lit top, white foam at tips, leading edges and splashes | deep blue | silver-blue, white rims brighter | Ice: pale blue to near-white facets, white edges, sharp straight lines; frost crawls as a white crackle. Mist: translucent white. |
| Earth | the ground's own colour (tan, ochre, grey, green-grey) | lit face, mid face, shadow face; strata lines on pillars | dark grey-brown | darker, dust reads paler | Dust: rounded beige puffs with a lighter rim; chips: small angular flecks. Crystal (the Crystal Catacombs): green with white rims. Metal: grey, bent in sheets. Lava (Korra): orange-yellow core with black crust, a fire palette on a liquid shape. |
| Air | none (invisible until it moves) | translucent white or pale grey swooshes, concentric arcs, spiral curls; lifted dust and leaves show its path | thin light grey, or no line | pale lines stay pale | Compressed air (the scooter, the sphere) is a translucent pale ball with curved streak lines. Air that cuts (air blades, swipes) is drawn as a crescent with a sharper rim. |

How an effect reads against the background: backgrounds are painted, muted and atmospheric (soft edges, low
saturation, haze); effects are cel, saturated and hard-edged. Fire is always the brightest thing on screen and
casts light; water is lighter than the water it came from (the foam does the work) and darker than the sky; earth is
the same colour as the ground, so the show separates a lifted rock with its outline, its dust, and the shadow it
casts on the ground; air is pale lines over whatever is behind, so the show reads it by what it moves (dust, cloth,
hair, grass, the opponent).

## 7. The element is the body's extension

- The element leaves from the striking limb and travels the way that limb pointed: fire from the fist's line, water
  along the arm's arc, a rock from the ground towards where the punch went, air from the palm or the staff's sweep.
- Its mass follows the art: water trails the hand (heavy, late), fire leaves instantly (light, explosive), earth
  needs the body's whole weight (a stomp, a dropped stance, a pull from the hips), air is already moving before the
  hand finishes (the body turns through it).
- The bender's eyes and head lead; the hands follow; the element follows the hands. This order is visible in every
  wind-up and is why the moves read as intentional.

## 8. How a move ends

| Element | At the end of a move |
|---|---|
| Water | falls under gravity, splashes in a crown with white spikes, lands as a puddle or a wet sheen; ice shatters into pale chips or melts into a smaller puddle; mist thins. |
| Earth | drops as rubble (a few larger blocks and many chips) with a dust ring; a pillar sinks back or is left standing; a fissure stays as a scar. |
| Fire | burns out in a puff: the flame shrinks to a few detached tongues, then a short grey smoke puff and embers that wink out in a handful of frames. On a surface: a brief scorch glow. |
| Air | dissipates: the lines thin, spread and fade in 4 to 8 frames; lifted dust and leaves settle; cloth and hair stop swinging a beat later. |

## 9. What The Legend of Korra adds

- More cinematic lighting (rim light, two shadow tones, lens effects), 1920s-city props, and a camera that moves more.
- Pro-bending (Book One) shows each element in short, boxed bursts: water in single lashes and "water bullets", earth
  as thrown discs from floor hatches, fire as quick jabs; it is a good study of fast release and quick recovery
  without the long gathers of the original.
- Studio Mir's smears are generous, and the finales (Book Three's "Enter the Void" and "Venom of the Red Lotus",
  Book Four's "Kuvira's Gambit", "Day of the Colossus", "The Last Stand") show every element at scale with
  hand-drawn effects.
- Book Two's first half (Studio Pierrot) has a different character model and is generally rated the weaker half;
  "Beginnings" (Wan's story) is drawn in a deliberate woodblock-print style with flat, paper-like fire and spirits,
  a one-off look. Sources: A.V. Club episode guides,
  https://www.avclub.com/the-legend-of-korra-the-guide-1798178532; Wikipedia, Studio Mir,
  https://en.wikipedia.org/wiki/Studio_Mir
- Ming-Hua (Book Three) is the most inventive water animation in either series: water as prosthetic arms with
  locally frozen tips.

## 10. What this implies for a 3D engine (suggestions, not the brief)

Suggestions from the reference, for the element chats to weigh:
- Build effects as **meshes with silhouettes** (a flame mass, a water tube, a faceted rock, an air cone) shaded in
  **stepped bands** with an **outline** (inverted hull or a post pass), instead of sprite clouds.
- Step the **shape change** of an effect at 12 updates a second (the flame's tongues, the water's foam edge) while
  the effect's position moves smoothly; the eye reads the stepping as "drawn".
- Give each cast an explicit **gather, snap, hold, settle** timeline, with the element lagging the hand by 2 to 4
  frames at 24 fps (about 0.1 s) and overshooting.
- On the release frame, **stretch** the projectile mesh along its velocity for 1 to 2 frames (a smear) and, on hit,
  **flash** for 1 to 2 frames and spawn a **ring** or **star burst** in the element's colour that fades in about
  0.3 s; kill the element's own effect at the same instant.
- Keep the game's existing dither-near-camera and own-wall fades (`data/bending/fx_looks.json`) as they are: they
  are camera hygiene, not style.

## 11. Links (reading only)

- The four arts on the Avatar Wiki (technique lists with episode citations):
  https://avatar.fandom.com/wiki/Waterbending, https://avatar.fandom.com/wiki/Earthbending,
  https://avatar.fandom.com/wiki/Firebending, https://avatar.fandom.com/wiki/Airbending
- Any episode's page on the same wiki is its title with underscores, e.g.
  https://avatar.fandom.com/wiki/The_Waterbending_Scroll
- "The Essence of Bending": a 9-minute featurette in which Bryan Konietzko and Sifu Kisu discuss how each art was
  built (listed on TheTVDB as a season-0 special,
  https://www.thetvdb.com/series/avatar-the-last-airbender/episodes/8303854; a public upload is titled
  "Avatar: The Last Airbender - The Essence of Bending with Bryan Konietzko and Sifu Kisu"). The four short
  "Creating the Legend" clips (one per element, about a minute each, Kisu demonstrating) are listed in the same
  season-0 set.
- Sifu Kisu interview (no mocap, video reference, pencil tests): https://kungfukingdom.com/interview-with-sifu-kisu/
- Animation Magazine, Feb 2005 (influences, studios, "atmospheric, cinematic"):
  https://www.animationmagazine.net/2005/02/avatar-bends-it-like-anime-on-nick/
- The comet-finale Agni Kai pencil tests: posted by Nickelodeon Animation on Twitter/X on 5 September 2020 and
  covered by Gizmodo Australia ("equal parts shonen and wuxia"); the Gizmodo AU link
  (https://gizmodo.com.au/?p=1397630) now redirects to the front page, so search the post by date.
- Martial-arts background articles: Martial Journal, "The martial arts in Avatar: The Last Airbender",
  https://martialjournal.com/the-martial-arts-in-avatar-the-last-airbender; Looper on Baguazhang,
  https://looper.com/370518/the-technique-from-both-naruto-and-avatar-that-exists-in-real-life; Dot and Line on
  tai chi and water, https://dotandline.net/?p=732
- Effects-animation craft (how hand-drawn fire, water and smoke are shaped, not about the show): Wave Motion
  Cannon, "Articulating Mob Psycho's Flames", https://wavemotioncannon.com/2016/09/18/articulating-mob-psychos-flames/;
  Kazunori Ozawa, *Animation Effect Drawing Technique* (Genkosha; listing
  https://stuartngbooks.com/products/animation-effect-drawing-technique-70418); Johannes Fast's hand-drawn fire
  course, https://www.skillshare.com/classes/Traditional-Animation-How-to-Animate-Fire/10453438
- Korra choreography critique (sits behind a bot check; not read for this doc): The Artifice, "Korragraphy:
  choreography mistakes in The Legend of Korra",
  https://the-artifice.com/korragraphy-choreography-mistakes-in-the-legend-of-korra/
- Not found: a frame-by-frame breakdown of the original series' effects by an animator. Sakugabooru has no tag for
  the show. If one of the element chats finds one, add it here.

## Q&A

(Answers to the element chats' questions are appended here with the date.)
