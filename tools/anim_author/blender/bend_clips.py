"""Our own ring-sport casts and reactions (Tidebreak, the elemental ring sport; the owner, 2026-10-04: "switch to a elemental
avatar the last airbender type of game", then: the throw-style moves on NEW OWN throw clips only, and the clips our own:
docs/animation_provenance.md, animations/SOURCE.md). Derived from tools/anim_author/blender/form_clips.py (the Form casts' route)
and from nothing else: key poses typed into the CLIPS table below, solved with two-bone IK (rigkit.ik2) on the skeleton of
Actor_B's own rig (assets/character/actor_b_body.glb, read from this checkout) in Blender, and baked to the bones' local
rotations as Godot has them, with the root's position, for tools/anim_author/install_bend.gd. This tool never reads a library
clip, a dumped move (dump_move.gd / dump_pose.gd output) or rigkit.Native / MirrorNative: the base it starts every clip from is
the rig's own rest (bind) pose, which our STAND below then keys into a ready stand (the arms down by the sides, the feet set, the
knees soft, the fingers half closed). The real martial forms (Hung Gar's stomps and heavy pushes for earth; a spear's, a
tomahawk's and an atlatl's throws) were the owner's visual reference only, as the owner's account in animations/SOURCE.md says.

The first set (the owner judges these by eye before more are authored; he rejected and deleted a stiff solver-authored gait
library on 2026-10-01, so these are key poses, each with its anticipation, its strike, its follow-through and the weight going
from foot to foot):
  earth_stomp        Hung Gar's stomp: the weight onto the left leg, the right knee drawn high with the fists gathered at the chest,
                     a hang; then the foot driven down into a wide horse stance, the root dropping with it, both fists driven down
                     beside the thighs; the shock taken in the knees; the foot brought back in to the stand.  strike_s: the foot down
  earth_push         the two-hand heavy push: the weight rocks back onto the right leg as both palms are drawn back to the ribs
                     and the left foot lifts; the foot steps out into a bow stance and both palms are driven out from the chest,
                     the back leg straightening behind them; held; stepped back.  strike_s: the arms straight
  earth_rise         the uppercut raise (a rock or a column lifted): a deep crouch coiled to the right, the right fist low by the
                     knee; the legs drive up, the hips turn through, the fist rises past the face to above the head as the left
                     hand is pulled back to the hip, up onto the toes of the back foot.  strike_s: the fist at the face's height
  throw_overhand     like a spear: the left foot steps out, the body turned side-on, the right hand cocked high behind the shoulder
                     and the left arm pointed at the mark; the hips then the chest turn through, the hand comes over the top and
                     lets go out in front above the head; follow-through down across the body onto the front leg, the back heel up
  throw_sidearm      like a tomahawk (a locked wrist): a lower stance coiled hard to the right, the hand out to the side at the
                     chest's height; the body unwinds and the arm sweeps round flat, letting go in front; follow-through across
                     to the left with the back foot pivoting on its ball
  throw_underhand    a flick like an atlatl's: a short step, the body low and forward, the right hand swung back low past the hip;
                     it swings through low and flicks up, letting go at the waist's height, and rises on with the body
  knock_slide        a braced backward slide (the knock that does not lift): the hit snaps the chest back and the hands forward;
                     the feet slide apart into a low staggered brace (they never lift: the game slides the body), the body
                     leaned into the push, the forearms up in a guard (held: hold_s, while the knock lasts); then up and in
  knock_air          launched: the hit arches the body back and throws the arms out; the knees come up and the arms flail wide
                     (held: hold_s, while in the air); the legs reach down for the ground, the landing taken low (up_s),
                     and back up to the stand
The second set (2026-10-05, after the owner approved the first ten: "looks good but you can always perfect them"; the CLIPS
table's SET2 part, authored the same way; the first ten polished: the keys the IK had clamped straight pulled into reach, a
few settle keys, their hold_s and strike_s kept):
  stance_<element>   each element's idle loop while casting (meta loop: installed looping; no gait): earth Hung Gar's low wide
                     horse, the left forearm forward, breathing; fire up on the balls of the feet side-on, the fists up, a
                     bounce; water the weight flowing forward and back with the soft hands; air light, turning about the waist
  earth_boulder      the owner's "left kick to stomp and then push": the left foot kicks the rock up, the knee high, the foot
                     stamped down out ahead, the palms drawn back (held), the two-hand push.  strike_s: the push
  earth_raise        the stomp-rise (a wall or a column): the right foot stamped, sunk (held), the palms driven up
  earth_burrow       the side burrow-step: dropped low to the right, the palm by the ground, the dive
  earth_catch        the hands up and open (held), the rock caught and drawn in to the chest, held
  earth_shove        a heavy single palm from a bow stance (and its twin)
  fire_punch         the straight punch from the ribs (and its twin); fire_double the jab and the cross 0.15 s behind it;
  fire_kick          the chambered front snap kick set down ahead; fire_sweep the knife hand round flat (and its twin);
  fire_breath        the breath drawn in and driven out between the palms; fire_lightning the hands circling the charge
                     (a long hold) and both thrust out
  water_whip         drawn down behind the hip, over the shoulder, lashed out (and its twin); water_wave the palms sunk,
                     risen and pushed out wide; water_draw the circle out over the pool and up; water_shield crossed low,
                     risen apart before the face
  air_palm           the palm strike (and its twin); air_sweep both arms round flat in a circle; air_spin a whole turn on
                     the balls of the feet, the arms out (the spin channel); air_leap the crouch and spring; air_shield the
                     palms round a circle and pushed out
The third set (2026-10-05, round 2 of the skills; the CLIPS table's SET3 part, authored the same way; fire_kick, now the High
Kick, gains its twin with its keys unchanged; earth_catch re-keyed so the guard reads at a glance, its moments kept):
  fire_kick_low      the Kick's floor wave: sunk low on the left leg, the right foot drawn back off the deck (the low chamber, the
                     tell), swept round and in at the shin's height (and its twin); fire_fireball the Punch held to grow: a
                     deeper chamber, the hand far back by the hip, the palm driven out (and its twin); fire_parry the guard:
                     the knife hand stood up before the face, cut out ahead along the aim
  earth_kickup       Shove's kick-and-push: the boulder's kick mirrored and short, the toes up under the stone early (and its
                     twin); earth_uproot Column: the stamp ahead, the palms by the deck, swept up and out far ahead
  water_turn         the guard: both hands low by the right hip, swung round the body and flung out ahead; water_turn_hold its
                     loop (a ball of water rolled before the waist); water_surf the riding crouch (a loop, legs_always);
                     water_skate the skater's push-off (legs_always)
  air_pull           the palms out, dragged back to the hips with a step back; air_slip the circle walker's pivot step out to
                     the side (and its twin), air_slip_back stepping back round; air_wall the palms out flat and swept apart;
                     air_guard the guard: the arms round a circle (one palm high, one low), the palms bounced out together;
                     air_shield_hold its loop (the palms circling before the chest); air_slice the flat chop (and its twin)
The fourth set (2026-10-06, round 3's first playable: the % ring's air and hit states; the CLIPS table's SET4 part, authored
the same way; the airborne ones start and end on AIR, the plain fall's first pose, and the landings start on its arms, so they
hand over to each other; revised the same day after the review: the loops keyed at every frame from their typed functions):
  tumble             a long launch's loop: one whole backward somersault a loop, typed as a turn rate (tumble_at): flung wide
                     open while the turn is slow, pulled into a tuck as it quickens, the tuck held through the fastest part and
                     the upright pass (a ball, never a man standing), the arms two frames behind the legs, the head two behind
                     the trunk, the root drifting up while open and down in the tuck
  flinch             a light hit taken on the feet (upper mask, 0.3 s): the chest snapped back, the head a beat later, the
                     reversal spread over three frames into the cringe: the shoulders hunched, the elbows up and out and both
                     hands up before the face; eased out to the stand
  jump_double        the tucked knees-up spring: a gather, the legs kick down hard against the air (the body long), the arms
                     swing up and the knees snap up under the seat, the hands pulled in onto the knees (a ball, held a beat),
                     opened out into the fall, the legs, then the arms, then the face
  fall               the athlete in control in the air (a loop): bowed a little, the arms open wide in a true balance, the legs
                     turning a bicycle that reads from the stands, the arms see-sawing behind the chest; fall_fast the tucked
                     arrow (a loop): long and straight, the arms swept back in a narrow V, the knees drawn up a little with the
                     feet together, a wind shiver twice a loop
  helpless           spent (a loop, reads apart from the fall at a glance): the arms trailing high over the head in a tall V,
                     the back arched and the head thrown back, the legs hanging long and limp, the whole body always lying back
                     off the vertical and wallowing round a cone
  air_dodge          the sharp tucked twist: the snap in from the middle out (the hips and the chest, the knees, the arms crossed
                     before the chest, the head), the head leading the turn and landing first, the tuck tightening at its
                     fastest, opened out
  air_legs           the legs only (lower mask, a loop): both knees drawn up under any cast let go in the air, the toes
                     flickering, the trailing leg on a beat of its own
  land_light         the touchdown: the knees give, the hips sit back, the arms come down from the balance; up to the stand
  land_heavy         the punish window: slammed into a deep squat, the palms slapped onto the thighs, the chest sagging after
                     them and the head hanging last, held; then a slow heavy push up off the thighs, a settle at the stand
  Pass 3 (the same day, the critic's second notes): the tumble's arms fully flung at the seam (clear of the head); the
  flinch's cringe a forearm guard (loose fists before the chin, the chin tucked); the double jump's gather over f0-f2 and its
  push at f3 (an arch, the arms in a V behind the hips), the arms on one loop up onto the knees; the fall's arms softer and
  unmirrored; the fast fall a spike (pitched 12 degrees into the dive, the arms swept back and out, the legs long and alike);
  the helpless fall lying back 22 degrees or more at every frame, its arms trailing up from the shoulders with bent elbows and
  limp hands, never level, the head lolling behind the chest, the knees soft and one foot trailing; the air legs in two
  shapes (the right knee high, the left heel back under the seat); the heavy landing 16 frames, its push up eased and its
  parts settling at different frames (back_s unchanged).
The fifth set (2026-10-06, round 3's first playable: the deck's edge and the ground dodges; the CLIPS table's SET5 and SET5B
parts, authored the same way; the edge clips keyed in the hang's frame: the lip LIP_Y over the origin and LIP_Z ahead):
  edge_grab          caught high off the face, the hands slapped flat on the deck, the body sagging as the legs swing in
                     under the lip onto the face; settled into the hang
  edge_hang          the hang (a loop): the forearms across the coping, the palms flat on the deck, the head and the shoulders
                     well over the lip, the balls of the feet on the face; a slight sway, a breath, a glance
  edge_climb         a mantle: pressed up onto straight arms, the right knee laid on the deck, the left foot up, stood up
                     CLIMB_IN in; edge_roll sprung over the lip into a forward roll along the deck (the code carries him in)
                     and up; edge_jump a coil and a hands-push spring straight up onto the fall; edge_attack pressed up into
                     a deep crouch, the straight right leg swept round low along the deck, stood up
  roll_f, roll_b     the ground rolls (facing kept): a tight ball turned over forward / back on the deck (pivot, ground);
  roll_side          roll_side the ball rolled over sideways along its spine to the right (and its twin); duck a deep sway
                     down and back with the forearms up, held, a return
  pivot              the point the flip and the cart turn the figure about (default the hips' height over the stand's middle)
  ground, floor      the share (0-1) of the gap between the floor (the clip's `floor`, 0 by default) and the body's lowest
                     surface (SURF: typed radii round the joints) the whole figure is shifted by: a roll's ball on the deck
  --points prints each frame's key joints and the lowest surface.
  Pass 2 (the same day, the critic's notes): the hang a climber's Z (the hips 0.35 m off the face, the knees folded to a
  right angle, the feet high on the face, the shoulders shrugged under the load) with a sway that reads (5 cm, the head a
  quarter loop behind, the heels re-pressing in turn, a grip flex, a look along the deck); the grab's catch sagging the chin
  to the lip with a pendulum in and out (baked four times a frame: substeps); the climb a pool-edge mantle (the knee set on
  the nose, the shin hanging, then laid back across the nose, a held load, the hips over the left foot, a rise carried
  past); the jump's hands on the deck through a real coil and push (lift, lift_w: the code's carry taken back) and the legs
  kicked straight off the face; the roll in's apex over the hands, the palms planted ahead and the right shoulder blade
  (twist) taking the deck with the head turned and tipped away; the sweep carried across past the left foot, the right arm
  whipping against it; the rolls' palms on the deck at the drop and the shoulder roll's diagonal, the back roll's palms
  pushing the head clear, the side roll tipped onto the right shoulder with the knees across the body and the left leg
  landing first; the duck 0.55 m down and 0.3 m back with the forearms by the head and a moving hold.
  lift, lift_w       (the edge jump) the code's lift (vy, g) from the clip's start, and the share of it taken back off the
                     whole figure at each frame (a uniform shift: the keys are the body over the code's carry)
  substeps           bake the clip that many times a frame (meta fps in the json; the installer keys it at that rate)
  --fit lists the frames where a limb is within SLACK of straight (and its place pulled in) and the striking limb's slack
  at strike_s (and its place carried out to STRIKE_SLACK).
The sixth set (2026-10-06, round 3's P2: the Rises and the recoveries; the CLIPS table's SET6 part, authored the same way):
  rise_earth         Pillar: the legs reach down for the column, slammed into a deep Hung Gar horse on its top with both fists
                     driven down, leant 20 degrees with the column, sunk as it drives, thrown off its top (the arms flung up)
  rise_water         Fountain: a soft sink, then standing tall on the column, both arms swung round big circles about the
                     shoulders (water_swirl), out in front of the body, into both hands floating over the head in a wide soft
                     oval, the palms up, on both feet with the chest opened back
  rise_fire          Jet: the hover tell (the knees drawn, the fists chambered at the hips, the roar), then the burst: long and
                     straight along it, leant into the flight, the right fist punched up leading (Northern Shaolin's rising punch)
  rise_air           Updraft: wound up, then one whole turn as a Baguazhang palm change (the trunk wrung, the right palm thrust
                     out flat at the shoulder's height, the left guarding under the elbow, the feet tucked together), unfurled
                     into the glide (glide_at, a loop from meta loop_from_s to the end): laid forward into the wind with the
                     arms spread as wings, banking
  edge_scramble      the hands slapped on the deck's face and over the lip, the feet scrabbling, hauled up onto HANG exactly
  tech, tech_roll    the breakfall: a three-point slap on the deck (the right knee down, the right palm slapped flat) and up;
                     the same slap carried on into the side roll (_roll("side")'s keys from its fourth frame; and its twin)
  tech_wall          flung into a wall (meta wall_z), the soles and the palms flat on it, folded deep, then shoved off it
  lie                dazed on his back (lie_at, a loop), the right knee up, breathing; getup the carp skip-up (a kip) from it;
                     getup_roll a whole log roll (barrel) and up (and its twin); getup_attack a crab sweep of the right leg
  knock_spiked       folded hard by the hit, then stretched into a feet-first plunge: one straight vertical line, the legs
                     together under him, the toes pointed down, the arms dragged straight up over the head
  knock_bounce       flat on the back onto the deck, the limbs slamming after it, the whole back bounced up flat off it with
                     the limbs trailing, back onto LIE
  Pass 2 (the same day, the critic's notes): the earth Rise's fists driven down outside the knees with the arms nearly
  straight (a wide triangle), a grinding press and a lift through the load, one forward-up arc of the fists to the sky (the
  throw frame already sweeping up), the left side a frame behind the right, the chest arched with the head lagging and the
  knees tucked as he is hurled off; the water Rise's circles a cone about each shoulder bulging out in front and its peak
  both hands over the head on both feet (the knee left to nobody); the fire Rise's punch on a forward arc clear of the
  face, a moving hold (the fist driving on, the legs scissoring, the twist turning on), the legs a frame after the trunk,
  the left fist settling late, a harder crunch and roar in the hover; the air Rise's whirl a palm change and its glide's
  wings at the shoulders' height banking 18 degrees; the scramble's hands thrown high over the lip with the head up at
  it by f5; the wall break a splayed cat on the wall, the balls of the feet touching it, the palms leaving a frame before
  the soles; the lie's head kept out of the deck, the raised foot drawn in and the knee turned out (the coat drapes), a
  head roll, a knee sway and a hand stir that read at 15 m; the carp's coil piked past the head and its arch its own
  frame; the log roll two turns led by the shoulders, braced on the palms and pushed by the left knee face down, then a
  sit-up over the planted palms and the drawn feet; the crab's hips high on the left hand and foot, the right arm flung
  out against the sweep, the sweep wider and held a frame; the spiked knock a feet-first plunge; the bounce flat.
  Pass 3 (2026-10-07, the critic's pass-2 notes): the earth throw asymmetric (the right fist driven straight up as a rising
  bridge hand on a forward arc clear of the hat, the left elbow pulled back to the hip, the trunk twisted and leant to his
  right, closed fists); the water Rise's trunk driving its circles (twist, side bend and a hip sway after the lead hand),
  soft knees on flat feet with a surge bob, a deeper sink, and tai chi's white crane at the top (the right palm high and
  out, the left pressed by the hip, the trunk turned 30 and leant 10 toward the high hand); the glide's wings swept back
  into a dihedral with bent elbows and trailing fingers, flexing twice a bank; the scramble's right hand thrown over the
  lip at f2 and slapped on the deck at f3, the head over the lip, each hand's apex over its landing, the left slapping the
  face; the slap leant over its out-flung arm (the whole body's roll and the spine's side bend) with the head up and level,
  the tech and its roll entered from one airborne frame (TECH0), a moving settle on the tech's last frames, the roll's
  twin's hips tilted on its kneel (twin_keys); the wall break's head kept back off the wall and its palms spread high; the
  lie's beat early and bigger; the getup's shove over two frames and its landing ridden; the log roll eased out into a
  rock up to the feet, its elbows wide, its knees bent and its body kept on the deck (ground); the crab sweep's straight
  leg round the hip itself, the crab higher and flatter, the yaw +/-45 and an arm whipped across; the spiked plunge
  driven (tipped and wobbling, arched, the elbows bent, the hands out of step); the bounce's limbs left on the deck while
  the trunk lifts and slammed back first. (The side channel bends the spine toward his RIGHT for +: checked on this bake;
  the earlier "+ toward the left" in the channel list is a slip of the comment, the earlier clips' keys are unchanged.)
  twin_keys          channels typed for the mirrored twin alone (in its own frame), in place of its mirrored ones
  barrel             the figure turned about its own long axis after the flip and the cart (a log roll; + to the left)
  toes               "foot": the toes kept with the foot (a sole laid flat on the deck while the figure lies)
  _wclip             a clip typed in the deck's frame (the pelvis's place, the turn, the palms and ankles on the deck), turned
                     back into the figure's own keys at every frame; _heel_key the foot key that lands the ankle exactly
The seventh set (2026-10-07, round 3's P2: the Pop, the Slams, the held guards and the teeter; the CLIPS table's SET7 part,
authored the same way; the Slams start and end on AIR and strike three frames after their held wind-up, strike_s 0.2 s):
  jab_rise           the Pop's rising hand (one for every element; and its twin; upper mask): coiled low on the right, a rising
                     punch driven up past the face over the head, the hand opened over the top and brought down ahead to the
                     right where it closes round the stone earth's Pop keeps (POP_STONE, BendR3.pop_stone's place), held there
  earth_hammer       the Hammer: the fists clasped high over the head, the body drawn back long (held), hammered over and down
                     between the knees as the body jackknifes and the legs spread into a horse in the air (Hung Gar)
  water_downpour     the Downpour: the arms swept up into a tall V, the palms up (held), swept round and down on two arcs to
                     press flat at the hips' height, the legs reaching down and the body rising on the push (tai chi)
  fire_axe_kick      the Axe Kick (and its twin): the right leg straight up over the head, the foot flexed, the arms spread
                     (held); chopped down ahead heel first with the body pitched over it, the other leg scissored back
  air_down_gust      the Down Gust: coiled small, the knees tucked, the palms drawn up out wide and the trunk wrung (held);
                     unscrewed into a tall line, the palms flared down beside the hips, the legs long, lifted (Baguazhang)
  guard_hold_<el>    the held guards (loops): earth breathing in its low horse with the rock between the palms; water's
                     ward-off rocking forward and back, the palms tracing circles; fire bouncing on the balls of the feet behind
                     a knife hand stood up before the chin; air's wheel of the palms before the chest (one high, one low, turning)
  teeter             at the lip (held at its end by the code): the lurch over the toes, both arms windmilling backward
                     (teeter_at: typed circles about each shoulder, TEETER_R and TEETER_OUT, the left a beat behind), the heels
                     about the balls; caught leaning out
  Pass 2 (the same day, the critic's pass-1 notes): the Pop's coil wound deeper (the fist chambered behind the hip) and its
  fist driven straight up with the spine bent away from it (one C), the guard hand dropping a frame late with a dip; its
  twin rising on the left and ending on the original's own held-stone pose (twin_tail), the right hand on the stone where
  the code holds it (meta stone_hand); the Hammer's hold one backward C (the fists behind the head, the heels to the seat,
  the eyes up) and its fists finishing ahead of and below the knees on one arc, overshooting and settling, in a wider sunk
  air horse; the Downpour's press with long arms ahead of the hips on an upright column lifted 0.17 m, the feet together
  and pointed, its V wider; the Axe Kick swung up outside the body (a crescent), chopped down with the knee long and the
  rear leg split back, the fists thrown back against it, the chest open; the Down Gust's palms raised flat by the ears and
  driven 0.7 m down beside the hips, wrung harder and unscrewed past the middle with a side bend, lifted 0.18 m; the earth
  guard's horse wider and lower with a breath and a squeeze that read, the rock's palms below the face; the fire guard's
  bounce twice as deep, sharp at the bottom (abs of a sine) and soft at the top, the hands settling a beat after it; the
  teeter 15 frames: tipped from the ankles (eased in over three frames, strike_s at f3), long arms windmilling from the
  shoulders, each spun up and settled (_trap) so no frame steps more than about 55 degrees, splayed wide of the hat as
  they rise (TEETER_SPLAY), caught with the right arm up and back and the left ahead, the chest lifted, one heel up.
  Pass 3 (the same day, the critic's pass-2 notes): the Pop's meta stone_s (back_s: the stone shown when the hand reaches
  it) and the held stone cupped over its crown; its twin's rising left fist kept a fist and dropped straight back to the
  guard while the right hand leaves the chamber for the stone from f7 (twin_keys); the Hammer's fists fastest onto the
  strike, the feet hung lower with the knees down and out so the fists hang clear below them, the eyes up out of the hat;
  the Downpour's press a forward-down line (the trunk folded over the palms, the legs swung ahead into a shallow pike),
  the hands inside the shoulders while high so the strike frame falls straight down, the palms sinking on against the
  rising body; the Axe Kick's crescent swung out wide on the way up and its rear leg folded under at the strike with the
  torso over the heel; the Down Gust's palms flared out wide into a Λ (press_out), the knees kept half tucked, each frame
  of the drive bigger than the last and the spiral turning on past the strike with the head two frames behind; the teeter's
  arms starting after the lurch and caught in a wide V over the head (TEETER_FLARE), the body tipped further out from the
  ankles up on both toes, the hips, the chest and the head wobbling in overlapping waves.
The eighth set (2026-10-07, round 3's P3: the spout and the air hits; the CLIPS table's SET8 part, authored the same way; the
air clips start and end on AIR; the owner's answer of 2026-10-05: one air-only close hit per element with its own clip):
  spout_ride         stood on the spout's crown (a loop, spout_at): the knees soft, the arms out a little, the weight wandering
                     foot to foot with the trunk and the arms answering it late, the water's surge taken in the knees;
                     spout_step_off a dip, then the right foot stepped out ahead off the crown into the fall
  fire_flip_kick     the air High Kick (and its twin): gathered, then a back flip with the right leg swung up on a crescent,
                     the foot high ahead at the strike, tucked round the rest of the somersault into the fall
  air_hit_earth      Stone Knee (and its twin): wound, then a whole turn on the spot as a stone ball, the right knee driven up
                     with the right elbow down onto it and the left leg kicked down long (a flying knee's scissor)
  air_hit_water      Spin Splash: both hands on a disc of water swung round one flat ring from behind his right hip to
                     behind his left shoulder, a hammer thrower's turn and lean, the legs swung round against it
                     (water_ring_at)
  air_hit_fire       Flare Kick: the knees snapped up, then both soles shot out ahead at the hips' height, the trunk lying
                     back and the fists thrown back behind the hips
  air_hit_air        Whirl: the arms wrapped, then flung long and open on a slant (the right high, the left low) through a
                     whole turn, the legs tucked
  Pass 2 (the same day, the critic's pass-1 notes): the spout ride a wide staggered horse with the knees out and round
  arms pressing the water, the surge a quick lift and a long ease (_surge) taken two frames late in the knees, a frame late
  in the hands and three after the knees in the head; the step-off 16 frames, a deep dip held f2-f4, tipped out over the
  stepping foot with the arms in opposition, the left ball pinned while its heel rises; the flip kick's arms thrown back past
  the head along the spine's line (half fists) and round one arc onto the shins, the left a frame behind, its kicking knee
  nearly straight, the other leg folded, the head up last; the earth hit a boulder: both legs tucked, the right knee raised
  high with the elbow on it and the fists stacked before the face, a hit-stop then a whip, an overshoot, the head lagging
  and snapping round to spot (and its twin); the water hit's ball held at the arms' length from the shoulders (an
  approximate typed shoulder line, _ring_shoulders), wound to 150 degrees behind each side, the waist leading it, the body
  leaning out against it and the kneeling legs swung with the lean and against the chest, the hands parting at f9 with the
  right trailing (and its twin, the sweep being sided); the fire hit's left leg a frame after the right, a recoil, a roll so
  the legs clear the trunk from behind, the fists flung back on long arms, a nod on the impact; the air hit a Baguazhang
  palm change (the right palm leading at the head's height with the left under its elbow, the wind held two frames), then
  long open arms dragging behind the turn (AIR_DRAG) and overshooting, the feet flaring, the head held on the mark and
  snapped round to spot it (and its twin, the whirl being sided).

  twin_tail          the twin's keys from that frame on are the original's own, unmirrored (a twin that strikes with the other
                     hand and ends on the original's pose: the Pop's twin with the stone in the right hand)
Metas (seconds): strike_s the moment the cast lets go / the foot or the fist lands / the hit (SwayPose's `struck`), hold_s
where the game may hold the pose (the lock's wind-up, or the knock while it lasts; at or before strike_s on a cast), back_s
where the recovery to the stand begins, up_s (knock_air) the landing; and strings: hand (the striking limb: r, l, both,
foot_r, foot_l; SwayPose.strike_point), mask (ToolPose's: full), root ("place": the root's position is keyed and comes back to
the start but for a moved stance).

Channels of a clip (each a list of (frame, value) keys, interpolated by a monotone cubic through them, so the motion carries
through a key instead of stopping on it; a value repeated is a hold): every place is in the character's frame (+X the
character's left, +Y up, +Z forward, metres), every angle in degrees.
  root        the root's offset from the stand's (x, y, z)
  yaw         the whole body turned about the vertical (+ to the left; the feet stay where their own keys put them)
  spin        the whole figure turned about the vertical through the stand's middle, the feet's and the hands' places
              with it (a turn on the spot; + to the left)
  hips        the whole body's bow from the root (+ forward); roll: its tilt (+ the left hip up)
  chest       the spine's pitch over the hips (+ forward); side: its bend (+ toward the left); twist: its turn (+ the left
              shoulder back), each spread over the spine
  head        the neck's and head's pitch (+ down), look: their turn (+ to the left); the head keeps on the mark through the
              body's yaw and twist unless look turns it
  clav_r/l    the clavicle forward and down (deg, (fwd, down))
  hand_r/l    the palm's place, or "stand" (hanging by the thigh); face_r/l the hand's facing: a name of FACING (the right
              hand's, mirrored for the left) or ((fingers' way), (palm's way)); pole_r/l the elbow's way from the shoulder
  grip_r/l    the fingers' close from the rest's relaxed hand: 1 a fist (the thumb over it), below 0 opened out flat
  foot_r/l    the ankle's place with the foot flat, or "stand"; fyaw_r/l its toe-out (+ out); heel_r/l the heel's lift about
              the ball (+ up onto the toes, - the toes up onto the heel); knee_r/l the knee's way from the hip (or the toes')
  flip        (an airborne figure) the whole keyed body turned about the hips' height over the stand's middle: its somersault
              (+ the head forward and down); cart its cartwheel (+ the left side up); "flip_turns": whole turns spread evenly
              over the clip under the flip keys (a tumbling loop); every place and way the keys give turns with the body
  tilt        the neck's and head's side tilt (a lolling head; only a clip that keys it)
A clip with "bones": "legs" bakes only the legs' bones (a lower-body layer: no root track).
A clip with "hands_from": "shoulder" keys hand_r/l as the arm's reach from its shoulder in the turned chest's frame (a limp
arm carried whole by the spine's sway, its elbow keeping its bend), its facings and poles in that frame too.
--angles prints each frame's elbow and knee bends (degrees, 0 straight) for checking a bend the keys mean to hold.
A clip with "loop": True is a stance: its keys' last frame is its length and its first's values, interpolated across the seam
(meta loop "linear"). A clip with "mirror": True also bakes its twin, <name>_l, the same keys mirrored across the body's middle (left for right).

  Blender -b --factory-startup --python tools/anim_author/blender/bend_clips.py -- --out <bend.json> --blend <bend.blend>
      [--clips earth_stomp,throw_overhand] [--glb <actor_b_body.glb>] [--fit] [--quiet]
  (in this project through the one-heavy-process lock: zsh <scratchpad>/blender_run.sh -b --factory-startup --python ...)
--blend keeps an Actor_B rig keyed with every clip baked (an action each) for the owner to open and refine in Blender; --clips
bakes only those (the installer merges them into the library, the others kept); --glb the rig (default: this checkout's).
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)


def _glb_arg():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--glb" in argv and argv.index("--glb") + 1 < len(argv):
        return os.path.abspath(argv[argv.index("--glb") + 1])
    return os.path.join(PROJECT, "assets", "character", "actor_b_body.glb")


import bpy  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

import rigmap  # noqa: E402
# The rig of this checkout (rigmap's default path points at the main checkout, which other sessions edit): set before rigkit
# builds its skeleton from it.
GLB = _glb_arg()
rigmap.GLB = GLB
rigmap.read_glb_json.__defaults__ = (GLB,)
import rigkit  # noqa: E402

SK = rigkit.SK
FPS = 30

SPINE = [("spinea", 0.3), ("spineb", 0.3), ("spinec", 0.22), ("spined", 0.18)]
NECK = [("neck", 0.45), ("heada", 0.35), ("headb", 0.2)]
ARM = ["clavicle", "shoulder", "elbow", "wrist"]
LEG = ["upper_leg", "knee", "ankle", "heel", "ball"]
## The fingers' joints and their close at a fist (deg about the knuckles' line; the thumb across the palm).
CURL = {"index": {"a": 78, "b": 95, "c": 60}, "middle": {"a": 82, "b": 98, "c": 60}, "ring": {"a": 85, "b": 98, "c": 58},
        "pinky": {"b": 88, "c": 95, "d": 55}, "thumb": {"b": 22, "c": 40}}
## Keyed at the rest's rotation unless a channel moves them (so the game's own pose never shows through the full mask).
STILL = ["lower_base", "upper_base", "pelvis", "palm", "index_metacarpal", "middle_metacarpal", "ring_metacarpal", "pinkya",
         "thumba"]

## The hand's facings (the right hand's; the left's mirrored): the fingers' way (the wrist to the knuckles) and the palm's.
FACING = {
    "stand": ((0.05, -1.0, 0.08), (1.0, 0.0, 0.15)),          # hanging, the palm in on the thigh
    "push": ((-0.12, 0.97, 0.2), (0.0, 0.08, 1.0)),            # a palm pushed out: the fingers up, the heel of the hand leading
    "chamber": ((0.1, 0.0, 1.0), (0.0, 1.0, 0.0)),             # drawn back at the ribs, the palm up
    "fist_down": ((0.0, -0.75, 0.66), (1.0, 0.0, 0.0)),        # a fist driven down and out, the knuckles leading
    "fist_gather": ((0.55, 0.3, 0.78), (0.0, -1.0, 0.0)),      # the fists gathered at the chest, the palms down
    "fist_low": ((0.0, -0.7, 0.7), (1.0, 0.0, 0.0)),           # the uppercut's start, low by the knee
    "fist_up": ((0.0, 0.92, 0.38), (0.0, -0.35, -0.94)),       # the uppercut's fist, the palm to the face
    "guard": ((0.45, 0.85, 0.25), (0.25, 0.0, -1.0)),          # a forearm guard: the fingers up and in, the palm to the face
    "point": ((-0.05, 0.25, 1.0), (1.0, 0.0, 0.0)),            # the leading arm pointed at the mark, the palm in
    "spear_back": ((0.0, 0.85, -0.5), (0.0, 0.55, 0.85)),      # the spear's cock: the hand high behind the shoulder, the palm up-forward
    "spear_go": ((0.0, 0.55, 0.85), (0.0, -0.85, 0.55)),       # its letting go, the palm forward and down
    "spear_after": ((0.35, -0.75, 0.55), (-0.2, -0.55, -0.8)), # its follow-through down across, the palm back
    "hatchet_back": ((-0.1, 0.9, -0.4), (0.0, 0.4, 0.92)),     # the tomahawk's cock out to the side, the palm forward, the wrist locked
    "hatchet_go": ((0.25, 0.55, 0.8), (0.97, 0.0, -0.25)),     # let go flat in front, the palm in
    "hatchet_after": ((0.95, 0.1, 0.25), (0.25, -0.2, -0.95)), # its follow-through across to the left, the palm back
    "flick_back": ((0.0, -0.9, -0.4), (0.0, -0.4, 0.92)),      # the atlatl flick's back swing, the palm forward
    "flick_go": ((0.0, 0.25, 1.0), (0.0, 1.0, -0.25)),         # let go at the waist, the palm up
    "flick_after": ((0.0, 0.85, 0.5), (0.0, 0.5, -0.85)),      # rising on, the palm up and back
    "flail": ((-0.9, 0.35, 0.1), (0.0, -0.2, 1.0)),            # an arm thrown out wide, the palm forward
    "brace": ((-0.15, 0.25, 0.95), (0.0, -1.0, 0.25)),         # the hands out for the landing, the palms down
}

## The stand every clip starts and ends on (the rest pose keyed: the root a little down, the feet set a little wide and turned
## out, the arms hanging, the fingers half closed). Every channel a clip leaves out is the stand's.
STAND_FOOT_R = (-0.13, 0.077, -0.04)
STAND_PALM_R = (-0.19, 0.795, 0.06)
STAND = {
    "root": (0.0, -0.015, 0.0), "yaw": 0.0, "hips": 0.0, "roll": 0.0, "chest": 0.0, "side": 0.0, "twist": 0.0,
    "head": 0.0, "look": 0.0, "clav_r": (0.0, 0.0), "clav_l": (0.0, 0.0),
    "hand_r": STAND_PALM_R, "hand_l": (-STAND_PALM_R[0], STAND_PALM_R[1], STAND_PALM_R[2]),
    "face_r": "stand", "face_l": "stand", "pole_r": (-0.35, -0.1, -1.0), "pole_l": (0.35, -0.1, -1.0),
    "grip_r": 0.4, "grip_l": 0.4,
    "foot_r": STAND_FOOT_R, "foot_l": (-STAND_FOOT_R[0], STAND_FOOT_R[1], STAND_FOOT_R[2]),
    "fyaw_r": 7.0, "fyaw_l": 7.0, "heel_r": 0.0, "heel_l": 0.0, "knee_r": "auto", "knee_l": "auto",
}
FR, FL = STAND["foot_r"], STAND["foot_l"]
HR, HL = STAND["hand_r"], STAND["hand_l"]

CLIPS = {
    # ---------------------------------------------------------------- earth
    "earth_stomp": {
        "length": 42, "meta": {"hold_s": 10 / FPS, "strike_s": 14 / FPS, "back_s": 27 / FPS, "hand": "foot_r", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (9, (0.07, -0.05, -0.01)), (11, (0.075, -0.045, -0.01)), (14, (-0.075, -0.17, 0.0)),
                 (17, (-0.075, -0.21, 0.0)), (20, (-0.075, -0.198, 0.0)), (27, (-0.075, -0.19, 0.0)), (33, (-0.01, -0.06, 0.0)),
                 (42, (0, -0.015, 0))],
        "roll": [(0, 0), (9, -5), (11, -5), (14, 1.5), (17, 0), (42, 0)],
        "hips": [(0, 0), (9, -3), (11, -3), (14, 3), (17, 6), (20, 4.5), (27, 4), (42, 0)],
        "chest": [(0, 0), (9, -6), (11, -6), (14, 2), (17, 6), (20, 3.5), (27, 3), (36, -1), (42, 0)],
        "side": [(0, 0), (9, 4), (11, 4), (14, 0), (42, 0)],
        "head": [(0, 0), (9, 4), (11, 4), (14, -2), (17, 2), (27, 0), (42, 0)],
        "clav_r": [(0, (0, 0)), (9, (6, -8)), (14, (2, 8)), (27, (2, 6)), (42, (0, 0))],
        "clav_l": [(0, (0, 0)), (9, (6, -8)), (14, (2, 8)), (27, (2, 6)), (42, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.12, 1.02, 0.18)), (9, (-0.06, 1.22, 0.24)), (11, (-0.06, 1.24, 0.24)), (14, (-0.4, 0.76, 0.24)),
                   (17, (-0.42, 0.715, 0.235)), (22, (-0.415, 0.72, 0.232)), (27, (-0.4, 0.73, 0.225)), (33, (-0.31, 0.78, 0.155)),
                   (42, HR)],
        "hand_l": [(0, HL), (5, (0.12, 1.02, 0.18)), (9, (0.06, 1.22, 0.24)), (11, (0.06, 1.24, 0.24)), (14, (0.375, 0.78, 0.225)),
                   (17, (0.388, 0.748, 0.22)), (22, (0.386, 0.75, 0.219)), (27, (0.378, 0.758, 0.215)), (33, (0.31, 0.78, 0.155)),
                   (42, HL)],
        "face_r": [(0, "stand"), (6, "fist_gather"), (11, "fist_gather"), (14, "fist_down"), (30, "fist_down"), (42, "stand")],
        "face_l": [(0, "stand"), (6, "fist_gather"), (11, "fist_gather"), (14, "fist_down"), (30, "fist_down"), (42, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (9, (-1.0, -0.2, -0.2)), (14, (-1.0, 0.1, -0.5)), (42, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (9, (1.0, -0.2, -0.2)), (14, (1.0, 0.1, -0.5)), (42, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (6, 1.0), (32, 1.0), (42, 0.4)],
        "grip_l": [(0, 0.4), (6, 1.0), (32, 1.0), (42, 0.4)],
        # the right knee drawn up high, the foot hanging under it, then driven down out wide; brought back in at the end
        "foot_r": [(0, FR), (4, (-0.14, 0.12, 0.0)), (9, (-0.12, 0.48, 0.3)), (11, (-0.12, 0.5, 0.31)), (14, (-0.31, 0.077, 0.03)),
                   (30, (-0.31, 0.077, 0.03)), (34, (-0.22, 0.14, -0.01)), (38, FR), (42, FR)],
        "fyaw_r": [(0, 7), (9, 0), (14, 22), (30, 22), (38, 7)],
        "heel_r": [(0, 0), (4, 15), (9, -10), (11, -10), (13, -4), (14, 0), (42, 0)],
        "knee_r": [(0, "auto"), (4, (-0.2, 0.0, 1.0)), (34, (-0.2, 0.0, 1.0)), (38, "auto")],
        "foot_l": [(0, FL), (42, FL)],
        "fyaw_l": [(0, 7), (9, 10), (14, 22), (30, 22), (40, 7)],
        "knee_l": [(0, "auto"), (14, (0.45, 0.0, 1.0)), (30, (0.45, 0.0, 1.0)), (40, "auto")],
    },
    "earth_push": {
        "length": 40, "meta": {"hold_s": 9 / FPS, "strike_s": 13 / FPS, "back_s": 24 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (8, (-0.03, -0.07, -0.07)), (9, (-0.03, -0.075, -0.065)), (13, (0.0, -0.13, 0.15)),
                 (16, (0.0, -0.14, 0.17)), (24, (0.0, -0.13, 0.15)), (32, (0.0, -0.05, 0.03)), (40, (0, -0.015, 0))],
        "yaw": [(0, 0), (8, -8), (13, 6), (24, 4), (40, 0)],
        "hips": [(0, 0), (8, -4), (13, 7), (16, 9), (24, 7), (40, 0)],
        "chest": [(0, 0), (8, -6), (13, 9), (16, 12), (24, 8), (40, 0)],
        "twist": [(0, 0), (8, -6), (13, 4), (24, 3), (40, 0)],
        "head": [(0, 0), (8, -3), (13, -2), (16, 0), (40, 0)],
        "clav_r": [(0, (0, 0)), (8, (-8, 4)), (13, (14, -2)), (16, (16, -2)), (24, (13, -2)), (40, (0, 0))],
        "clav_l": [(0, (0, 0)), (8, (-8, 4)), (13, (14, -2)), (16, (16, -2)), (24, (13, -2)), (40, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.2, 0.95, 0.0)), (8, (-0.18, 1.02, -0.06)), (9, (-0.18, 1.03, -0.05)), (11, (-0.15, 1.1, 0.3)),
                   (13, (-0.13, 1.15, 0.66)), (16, (-0.13, 1.14, 0.7)), (24, (-0.13, 1.13, 0.66)), (31, (-0.2, 0.95, 0.25)), (40, HR)],
        "hand_l": [(0, HL), (5, (0.2, 0.95, 0.0)), (8, (0.18, 1.02, -0.06)), (9, (0.18, 1.03, -0.05)), (11, (0.15, 1.1, 0.3)),
                   (13, (0.13, 1.15, 0.66)), (16, (0.13, 1.14, 0.69)), (24, (0.13, 1.13, 0.655)), (31, (0.2, 0.95, 0.25)), (40, HL)],
        "face_r": [(0, "stand"), (5, "chamber"), (9, "chamber"), (12, "push"), (27, "push"), (40, "stand")],
        "face_l": [(0, "stand"), (5, "chamber"), (9, "chamber"), (12, "push"), (27, "push"), (40, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (9, (-0.3, -0.4, -1.0)), (13, (-0.8, -0.6, -0.1)), (40, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (9, (0.3, -0.4, -1.0)), (13, (0.8, -0.6, -0.1)), (40, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (6, 0.15), (11, -0.45), (28, -0.45), (40, 0.4)],
        "grip_l": [(0, 0.4), (6, 0.15), (11, -0.45), (28, -0.45), (40, 0.4)],
        # the left foot lifts on the rock back and steps out into the bow stance; the back foot turns out and stays
        "foot_l": [(0, FL), (6, (0.14, 0.16, 0.02)), (9, (0.14, 0.17, 0.1)), (12, (0.15, 0.077, 0.36)), (27, (0.15, 0.077, 0.36)),
                   (30, (0.14, 0.15, 0.2)), (34, FL), (40, FL)],
        "heel_l": [(0, 0), (4, 12), (7, -6), (11, -6), (12, 0), (27, 0), (29, 10), (33, 0), (40, 0)],
        "fyaw_l": [(0, 7), (12, 4), (30, 4), (34, 7)],
        "knee_l": [(0, "auto"), (5, (0.15, 0.2, 1.0)), (32, (0.15, 0.2, 1.0)), (36, "auto")],
        "foot_r": [(0, FR), (12, (-0.15, 0.077, -0.08)), (30, (-0.15, 0.077, -0.08)), (36, FR)],
        "fyaw_r": [(0, 7), (12, 32), (30, 32), (36, 7)],
        "heel_r": [(0, 0), (40, 0)],
    },
    "earth_rise": {
        "length": 40, "meta": {"hold_s": 10 / FPS, "strike_s": 14 / FPS, "back_s": 25 / FPS, "hand": "r", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (9, (-0.02, -0.2, -0.03)), (10, (-0.02, -0.205, -0.03)), (14, (0.0, -0.015, 0.055)),
                 (17, (0.0, -0.002, 0.065)), (25, (0.0, -0.01, 0.055)), (33, (0.0, -0.04, 0.02)), (40, (0, -0.015, 0))],
        "yaw": [(0, 0), (9, -10), (14, 10), (17, 14), (25, 12), (40, 0)],
        "hips": [(0, 0), (9, 16), (14, 0), (17, -4), (25, -3), (40, 0)],
        "chest": [(0, 0), (9, 18), (14, -4), (17, -9), (25, -7), (40, 0)],
        "twist": [(0, 0), (9, -16), (14, 14), (17, 18), (25, 15), (40, 0)],
        "side": [(0, 0), (9, -6), (14, 4), (17, 6), (25, 5), (40, 0)],
        "head": [(0, 0), (9, -14), (14, -6), (17, -16), (25, -12), (40, 0)],
        "clav_r": [(0, (0, 0)), (9, (-6, 8)), (14, (6, -18)), (17, (8, -24)), (25, (6, -20)), (40, (0, 0))],
        "clav_l": [(0, (0, 0)), (9, (6, 0)), (14, (-8, 4)), (25, (-6, 4)), (40, (0, 0))],
        "hand_r": [(0, HR), (6, (-0.195, 0.66, 0.115)), (9, (-0.205, 0.575, 0.1)), (10, (-0.205, 0.575, 0.107)),
                   (12, (-0.14, 0.95, 0.34)), (14, (-0.08, 1.42, 0.37)), (17, (-0.075, 1.77, 0.29)), (21, (-0.072, 1.76, 0.285)),
                   (25, (-0.07, 1.74, 0.28)), (32, (-0.2, 1.2, 0.2)), (40, HR)],
        "hand_l": [(0, HL), (6, (0.12, 1.05, 0.3)), (9, (0.11, 1.0, 0.36)), (10, (0.11, 1.0, 0.36)), (14, (0.19, 0.98, -0.02)),
                   (25, (0.19, 0.98, -0.02)), (40, HL)],
        "face_r": [(0, "stand"), (6, "fist_low"), (10, "fist_low"), (14, "fist_up"), (27, "fist_up"), (40, "stand")],
        "face_l": [(0, "stand"), (6, "guard"), (10, "guard"), (14, "chamber"), (27, "chamber"), (40, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (9, (-0.6, 0.0, -0.8)), (14, (-1.0, -0.2, 0.0)), (17, (-1.0, 0.2, 0.0)),
                   (40, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (9, (1.0, -0.5, 0.0)), (14, (0.3, -0.3, -1.0)), (40, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (6, 1.0), (30, 1.0), (40, 0.4)],
        "grip_l": [(0, 0.4), (6, 0.1), (11, 0.1), (14, 1.0), (30, 1.0), (40, 0.4)],
        # the right foot steps back a little for the coil, and in again at the end
        "foot_r": [(0, FR), (3, (-0.16, 0.12, -0.07)), (5, (-0.19, 0.077, -0.1)), (31, (-0.19, 0.077, -0.1)),
                   (34, (-0.16, 0.12, -0.07)), (37, FR), (40, FR)],
        "fyaw_r": [(0, 7), (9, 20), (14, 2), (17, -6), (25, -4), (31, 10), (37, 7)],
        "heel_r": [(0, 0), (2, 10), (5, 0), (11, 0), (14, 35), (17, 42), (25, 38), (30, 0), (33, 10), (36, 0)],
        "foot_l": [(0, FL), (40, FL)],
        "fyaw_l": [(0, 7), (9, 18), (14, 10), (40, 7)],
        "heel_l": [(0, 0), (12, 0), (16, 6), (25, 5), (30, 0), (40, 0)],
        "knee_l": [(0, "auto"), (9, (0.45, 0.0, 1.0)), (14, "auto")],
        "knee_r": [(0, "auto"), (9, (-0.45, 0.0, 1.0)), (14, "auto")],
    },
    # ---------------------------------------------------------------- the throws (new, our own: a spear's, a tomahawk's, an atlatl's)
    "throw_overhand": {
        "length": 36, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 10 / FPS, "back_s": 21 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.06, -0.06)), (10, (0.0, -0.08, 0.13)), (14, (0.0, -0.1, 0.18)),
                 (21, (0.0, -0.09, 0.16)), (29, (0.0, -0.04, 0.05)), (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -28), (10, 10), (14, 18), (21, 14), (36, 0)],
        "twist": [(0, 0), (6, -22), (10, 16), (14, 24), (21, 18), (36, 0)],
        "hips": [(0, 0), (6, -4), (10, 8), (14, 10), (21, 8), (36, 0)],
        "chest": [(0, 0), (6, -10), (10, 12), (14, 17), (21, 12), (36, 0)],
        "side": [(0, 0), (6, 8), (10, -4), (14, -6), (21, -4), (36, 0)],
        "head": [(0, 0), (6, -4), (10, -6), (14, -8), (21, -6), (36, 0)],
        "clav_r": [(0, (0, 0)), (6, (-8, -18)), (10, (10, -10)), (14, (14, 6)), (21, (10, 4)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (10, -6)), (10, (-4, 4)), (21, (-2, 2)), (36, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.3, 1.2, -0.12)), (6, (-0.2, 1.5, -0.48)), (8, (-0.2, 1.62, -0.12)), (10, (-0.1, 1.62, 0.5)),
                   (12, (0.0, 1.3, 0.62)), (14, (0.12, 0.98, 0.5)), (21, (0.12, 0.95, 0.45)), (29, (-0.12, 0.9, 0.2)), (36, HR)],
        "hand_l": [(0, HL), (3, (0.2, 1.1, 0.25)), (6, (0.15, 1.285, 0.465)), (8, (0.18, 1.22, 0.4)), (10, (0.24, 1.05, 0.1)),
                   (14, (0.24, 0.98, -0.02)), (21, (0.23, 0.98, 0.0)), (36, HL)],
        "face_r": [(0, "stand"), (4, "spear_back"), (7, "spear_back"), (10, "spear_go"), (14, "spear_after"), (24, "spear_after"),
                   (36, "stand")],
        "face_l": [(0, "stand"), (4, "point"), (7, "point"), (11, "chamber"), (24, "chamber"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.9, 0.2, -0.5)), (8, (-0.7, 0.2, 0.6)), (10, (-0.7, 0.4, 0.4)),
                   (14, (-0.9, 0.0, 0.2)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, -0.8, 0.0)), (10, (0.5, -0.3, -1.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.75), (9, 0.75), (10, 0.15), (14, 0.25), (28, 0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.35), (8, -0.35), (12, 0.8), (28, 0.8), (36, 0.4)],
        "foot_l": [(0, FL), (3, (0.13, 0.13, 0.02)), (5, (0.15, 0.1, 0.21)), (7, (0.16, 0.077, 0.32)), (24, (0.16, 0.077, 0.33)),
                   (28, (0.15, 0.13, 0.15)), (32, FL), (36, FL)],
        "heel_l": [(0, 0), (3, 10), (5, -8), (7, 0), (24, 0), (27, 12), (31, 0)],
        "fyaw_l": [(0, 7), (6, 14), (10, 4), (24, 4), (32, 7)],
        "knee_l": [(0, "auto"), (3, (0.2, 0.3, 1.0)), (30, (0.2, 0.3, 1.0)), (33, "auto")],
        "foot_r": [(0, FR), (6, (-0.14, 0.077, -0.07)), (27, (-0.14, 0.077, -0.07)), (32, FR)],
        "fyaw_r": [(0, 7), (4, 45), (10, 30), (14, 8), (24, 8), (32, 7)],
        "heel_r": [(0, 0), (6, 0), (10, 25), (14, 45), (24, 40), (30, 0)],
    },
    "throw_sidearm": {
        "length": 36, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 21 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (-0.03, -0.11, -0.05)), (9, (0.0, -0.12, 0.1)), (14, (0.02, -0.12, 0.15)),
                 (21, (0.02, -0.11, 0.13)), (29, (0.0, -0.04, 0.04)), (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -38), (9, 8), (14, 30), (21, 26), (36, 0)],
        "twist": [(0, 0), (6, -26), (9, 12), (14, 28), (21, 22), (36, 0)],
        "hips": [(0, 0), (6, 6), (9, 9), (14, 9), (21, 7), (36, 0)],
        "chest": [(0, 0), (6, 4), (9, 8), (14, 10), (21, 8), (36, 0)],
        "side": [(0, 0), (6, 6), (9, -6), (14, -2), (21, -2), (36, 0)],
        "head": [(0, 0), (6, -6), (9, -8), (14, -6), (36, 0)],
        "clav_r": [(0, (0, 0)), (6, (-14, -4)), (9, (12, -4)), (14, (18, 2)), (21, (14, 2)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (12, 0)), (9, (-6, 2)), (21, (-4, 2)), (36, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.35, 1.0, 0.0)), (6, (-0.525, 1.22, -0.27)), (8, (-0.48, 1.2, 0.2)), (9, (-0.3, 1.18, 0.5)),
                   (11, (-0.02, 1.12, 0.6)), (14, (0.35, 1.05, 0.38)), (21, (0.36, 1.0, 0.3)), (29, (0.0, 0.92, 0.2)), (36, HR)],
        "hand_l": [(0, HL), (3, (0.2, 1.0, 0.2)), (6, (0.1, 1.2, 0.42)), (9, (0.24, 1.1, 0.15)), (14, (0.3, 0.98, -0.06)),
                   (21, (0.29, 0.98, -0.05)), (36, HL)],
        "face_r": [(0, "stand"), (4, "hatchet_back"), (7, "hatchet_back"), (9, "hatchet_go"), (14, "hatchet_after"),
                   (24, "hatchet_after"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "point"), (7, "point"), (11, "chamber"), (24, "chamber"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.4, -1.0, -0.6)), (9, (-0.3, -1.0, 0.0)), (14, (0.2, -1.0, 0.3)),
                   (24, (0.2, -1.0, 0.3)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, -0.8, 0.0)), (10, (0.5, -0.3, -1.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.85), (8, 0.85), (9, 0.2), (14, 0.3), (28, 0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.35), (8, -0.35), (12, 0.8), (28, 0.8), (36, 0.4)],
        "foot_l": [(0, FL), (3, (0.15, 0.12, 0.02)), (6, (0.2, 0.077, 0.24)), (24, (0.2, 0.077, 0.24)), (28, (0.17, 0.13, 0.1)),
                   (32, FL), (36, FL)],
        "heel_l": [(0, 0), (3, 10), (5, -6), (6, 0), (24, 0), (27, 12), (31, 0)],
        "fyaw_l": [(0, 7), (6, 20), (9, 10), (14, -6), (24, -6), (32, 7)],
        "knee_l": [(0, "auto"), (3, (0.3, 0.2, 1.0)), (30, (0.3, 0.2, 1.0)), (33, "auto")],
        "foot_r": [(0, FR), (6, (-0.15, 0.077, -0.07)), (27, (-0.15, 0.077, -0.07)), (32, FR)],
        "fyaw_r": [(0, 7), (6, 50), (9, 25), (14, -10), (24, -10), (32, 7)],
        "heel_r": [(0, 0), (6, 0), (9, 20), (14, 45), (24, 40), (30, 0)],
    },
    "throw_underhand": {
        "length": 34,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 19 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.13, -0.03)), (9, (0.0, -0.09, 0.1)), (13, (0.0, -0.02, 0.14)),
                 (19, (0.0, -0.025, 0.13)), (27, (0.0, -0.02, 0.04)), (34, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -14), (9, 4), (13, 8), (19, 6), (34, 0)],
        "twist": [(0, 0), (6, -16), (9, 6), (13, 10), (19, 8), (34, 0)],
        "hips": [(0, 0), (6, 14), (9, 8), (13, 0), (19, 0), (34, 0)],
        "chest": [(0, 0), (6, 14), (9, 6), (13, -4), (19, -3), (34, 0)],
        "side": [(0, 0), (6, -8), (9, -4), (13, 2), (34, 0)],
        "head": [(0, 0), (6, -14), (9, -6), (13, 0), (34, 0)],
        "clav_r": [(0, (0, 0)), (6, (-10, 4)), (9, (8, 2)), (13, (12, -10)), (19, (8, -8)), (34, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (8, 0)), (13, (-4, 0)), (34, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.24, 0.76, 0.04)), (6, (-0.235, 0.71, -0.23)), (8, (-0.195, 0.68, 0.17)), (9, (-0.15, 0.8, 0.45)),
                   (11, (-0.12, 1.15, 0.57)), (13, (-0.1, 1.28, 0.6)), (19, (-0.11, 1.24, 0.57)), (27, (-0.2, 1.0, 0.25)), (34, HR)],
        "hand_l": [(0, HL), (3, (0.2, 0.95, 0.2)), (6, (0.13, 1.08, 0.4)), (9, (0.2, 1.02, 0.25)), (13, (0.23, 1.0, 0.05)),
                   (19, (0.22, 1.0, 0.05)), (34, HL)],
        "face_r": [(0, "stand"), (4, "flick_back"), (7, "flick_back"), (9, "flick_go"), (13, "flick_after"), (22, "flick_after"),
                   (34, "stand")],
        "face_l": [(0, "stand"), (4, "point"), (7, "point"), (12, "chamber"), (22, "chamber"), (34, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.5, 0.2, -1.0)), (9, (-0.6, -1.0, -0.2)), (13, (-0.8, -0.6, 0.2)),
                   (34, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.7, -0.7, 0.0)), (12, (0.5, -0.3, -1.0)), (34, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.7), (8, 0.7), (9, 0.1), (13, 0.05), (26, 0.1), (34, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.3), (8, -0.3), (12, 0.7), (26, 0.7), (34, 0.4)],
        "foot_l": [(0, FL), (3, (0.13, 0.12, 0.04)), (5, (0.14, 0.077, 0.25)), (22, (0.14, 0.077, 0.25)), (26, (0.14, 0.13, 0.1)),
                   (30, FL), (34, FL)],
        "heel_l": [(0, 0), (3, 10), (4, -6), (5, 0), (22, 0), (25, 12), (29, 0)],
        "fyaw_l": [(0, 7), (5, 8), (30, 7)],
        "knee_l": [(0, "auto"), (3, (0.2, 0.2, 1.0)), (28, (0.2, 0.2, 1.0)), (31, "auto")],
        "foot_r": [(0, FR), (5, (-0.14, 0.077, -0.06)), (25, (-0.14, 0.077, -0.06)), (30, FR)],
        "fyaw_r": [(0, 7), (5, 25), (9, 15), (13, 8), (30, 7)],
        "heel_r": [(0, 0), (6, 0), (9, 20), (13, 40), (20, 35), (28, 0)],
    },
    # ---------------------------------------------------------------- the knocks
    "knock_slide": {
        "length": 36, "meta": {"strike_s": 1 / FPS, "hold_s": 9 / FPS, "back_s": 21 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (3, (0.0, -0.03, -0.08)), (9, (0.0, -0.17, -0.03)), (15, (0.0, -0.18, -0.03)),
                 (21, (0.0, -0.17, -0.03)), (29, (0.0, -0.05, 0.0)), (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (9, 12), (21, 12), (36, 0)],
        "hips": [(0, 0), (3, -6), (9, 14), (15, 16), (21, 14), (36, 0)],
        "chest": [(0, 0), (3, -18), (9, 10), (15, 12), (21, 10), (36, 0)],
        "twist": [(0, 0), (9, 8), (21, 8), (36, 0)],
        "head": [(0, 0), (3, 14), (6, -6), (9, 2), (15, 4), (21, 2), (36, 0)],
        "clav_r": [(0, (0, 0)), (3, (10, -6)), (9, (10, 0)), (21, (10, 0)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (3, (10, -6)), (9, (10, 0)), (21, (10, 0)), (36, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.235, 1.14, 0.22)), (9, (-0.08, 1.22, 0.36)), (15, (-0.08, 1.2, 0.36)), (21, (-0.08, 1.2, 0.35)),
                   (29, (-0.2, 0.95, 0.18)), (36, HR)],
        "hand_l": [(0, HL), (3, (0.235, 1.14, 0.215)), (9, (0.1, 1.3, 0.3)), (15, (0.1, 1.28, 0.3)), (21, (0.1, 1.28, 0.29)),
                   (29, (0.2, 0.95, 0.18)), (36, HL)],
        "face_r": [(0, "stand"), (3, "push"), (8, "guard"), (24, "guard"), (36, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (8, "guard"), (24, "guard"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (3, (-0.6, -0.5, -0.4)), (9, (-0.6, -1.0, 0.1)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (3, (0.6, -0.5, -0.4)), (9, (0.6, -1.0, 0.1)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, 0.05), (8, 0.9), (26, 0.9), (36, 0.4)],
        "grip_l": [(0, 0.4), (3, 0.05), (8, 0.9), (26, 0.9), (36, 0.4)],
        # the feet slide apart on the ground (never lifted), the left ahead, the right behind turned out
        "foot_l": [(0, FL), (9, (0.17, 0.077, 0.2)), (24, (0.17, 0.077, 0.2)), (28, (0.15, 0.12, 0.08)), (32, FL), (36, FL)],
        "fyaw_l": [(0, 7), (9, 12), (24, 12), (32, 7)],
        "heel_l": [(0, 0), (3, -12), (8, 0), (24, 0), (27, 10), (31, 0)],
        "foot_r": [(0, FR), (9, (-0.19, 0.077, -0.24)), (24, (-0.19, 0.077, -0.24)), (31, (-0.16, 0.12, -0.12)), (34, FR), (36, FR)],
        "fyaw_r": [(0, 7), (9, 38), (24, 38), (34, 7)],
        "heel_r": [(0, 0), (3, -10), (8, 0), (28, 0), (30, 10), (33, 0)],
        "knee_l": [(0, "auto"), (9, (0.35, 0.0, 1.0)), (26, (0.35, 0.0, 1.0)), (32, "auto")],
        "knee_r": [(0, "auto"), (9, (-0.6, 0.0, 1.0)), (26, (-0.6, 0.0, 1.0)), (32, "auto")],
    },
    "knock_air": {
        "length": 44, "meta": {"strike_s": 1 / FPS, "hold_s": 10 / FPS, "up_s": 26 / FPS, "back_s": 30 / FPS, "hand": "both",
                               "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (3, (0.0, 0.04, -0.05)), (10, (0.0, 0.03, -0.04)), (20, (0.0, 0.02, -0.03)),
                 (24, (0.0, 0.0, 0.0)), (26, (0.0, -0.1, 0.02)), (29, (0.0, -0.21, 0.04)), (30, (0.0, -0.21, 0.04)),
                 (38, (0.0, -0.05, 0.01)), (44, (0, -0.015, 0))],
        "hips": [(0, 0), (3, -14), (10, -26), (16, -24), (20, -20), (24, -2), (26, 8), (29, 20), (30, 20), (44, 0)],
        "chest": [(0, 0), (3, -22), (10, -6), (16, -2), (20, -4), (24, 4), (26, 12), (29, 22), (30, 22), (44, 0)],
        "roll": [(0, 0), (10, 6), (16, -4), (20, 0), (44, 0)],
        "twist": [(0, 0), (10, -8), (16, 6), (20, 0), (44, 0)],
        "head": [(0, 0), (3, 22), (10, 18), (16, 16), (24, 10), (26, 2), (29, -4), (44, 0)],
        "clav_r": [(0, (0, 0)), (3, (-8, -14)), (10, (-4, -20)), (16, (0, -12)), (24, (8, 0)), (30, (10, 4)), (44, (0, 0))],
        "clav_l": [(0, (0, 0)), (3, (-8, -14)), (10, (2, -12)), (16, (-6, -20)), (24, (8, 0)), (30, (10, 4)), (44, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.45, 1.42, -0.02)), (10, (-0.49, 1.38, 0.05)), (16, (-0.5, 1.5, -0.08)), (20, (-0.48, 1.3, 0.12)),
                   (24, (-0.38, 1.0, 0.3)), (29, (-0.3, 0.75, 0.42)), (30, (-0.3, 0.75, 0.42)), (37, (-0.22, 0.9, 0.2)), (44, HR)],
        "hand_l": [(0, HL), (3, (0.45, 1.42, -0.02)), (10, (0.5, 1.5, -0.06)), (16, (0.49, 1.36, 0.075)), (20, (0.48, 1.3, 0.12)),
                   (24, (0.38, 1.0, 0.3)), (29, (0.3, 0.75, 0.42)), (30, (0.3, 0.75, 0.42)), (37, (0.22, 0.9, 0.2)), (44, HL)],
        "face_r": [(0, "stand"), (3, "flail"), (20, "flail"), (25, "brace"), (32, "brace"), (44, "stand")],
        "face_l": [(0, "stand"), (3, "flail"), (20, "flail"), (25, "brace"), (32, "brace"), (44, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (3, (-0.2, -0.6, -1.0)), (20, (-0.2, -0.6, -1.0)), (26, (-0.8, -0.4, -0.3)),
                   (44, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (3, (0.2, -0.6, -1.0)), (20, (0.2, -0.6, -1.0)), (26, (0.8, -0.4, -0.3)),
                   (44, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.4), (20, -0.3), (26, -0.2), (34, 0.2), (44, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.4), (20, -0.3), (26, -0.2), (34, 0.2), (44, 0.4)],
        # off the ground: the knees come up and forward (left and right a little out of step), then reach down for the landing
        "foot_r": [(0, FR), (3, (-0.14, 0.2, 0.05)), (10, (-0.17, 0.42, 0.3)), (16, (-0.16, 0.36, 0.22)), (20, (-0.16, 0.34, 0.18)),
                   (24, (-0.17, 0.15, 0.06)), (26, (-0.18, 0.077, 0.02)), (36, (-0.18, 0.077, 0.02)), (40, FR), (44, FR)],
        "foot_l": [(0, FL), (3, (0.14, 0.14, 0.0)), (10, (0.16, 0.34, 0.2)), (16, (0.17, 0.42, 0.3)), (20, (0.16, 0.34, 0.18)),
                   (24, (0.17, 0.15, 0.06)), (26, (0.18, 0.077, 0.02)), (36, (0.18, 0.077, 0.02)), (40, FL), (44, FL)],
        "heel_r": [(0, 0), (3, 25), (10, 30), (20, 30), (24, 15), (26, 0), (44, 0)],
        "heel_l": [(0, 0), (3, 25), (10, 30), (20, 30), (24, 15), (26, 0), (44, 0)],
        "fyaw_r": [(0, 7), (10, 12), (26, 18), (36, 18), (40, 7)],
        "fyaw_l": [(0, 7), (10, 12), (26, 18), (36, 18), (40, 7)],
        "knee_r": [(0, "auto"), (3, (-0.25, 0.3, 1.0)), (36, (-0.35, 0.0, 1.0)), (40, "auto")],
        "knee_l": [(0, "auto"), (3, (0.25, 0.3, 1.0)), (36, (0.35, 0.0, 1.0)), (40, "auto")],
    },
}

## ---------------------------------------------------------------- the second set (2026-10-05, after the owner approved the
## first ten: "looks good but you can always perfect them"; authored the same way, key poses typed here, nothing read)
FACING.update({
    "fist_fwd": ((0.0, 0.05, 1.0), (0.0, -1.0, 0.05)),         # a punch out, the knuckles leading, the palm down
    "fist_guard": ((0.25, 0.92, 0.3), (1.0, -0.1, -0.2)),      # a fist up in guard, the knuckles up, the palm in
    "palm_down": ((0.05, -0.05, 1.0), (0.0, -1.0, -0.05)),     # the fingers forward, the palm down
    "knife": ((0.0, 0.05, 1.0), (1.0, 0.0, 0.0)),              # the fingers forward, the palm in (a knife hand, two fingers)
    "sweep_out": ((-0.9, 0.1, 0.42), (0.4, 0.0, 0.92)),        # the arc's end out to the side, the palm forward
    "sweep_in": ((0.75, 0.15, 0.65), (0.65, 0.0, -0.75)),      # the arc's start across the body, the palm back
    "whip_back": ((-0.1, -0.8, -0.6), (0.0, 0.6, -0.8)),       # the whip drawn down behind the hip, the palm back
    "whip_up": ((0.0, 0.85, 0.5), (0.0, 0.5, -0.85)),          # the whip over the shoulder, the palm up and back
    "whip_go": ((0.0, -0.25, 1.0), (0.0, -1.0, -0.25)),        # the lash out and down, the palm down
    "float": ((0.1, 0.25, 0.96), (0.0, -0.96, 0.25)),          # the soft hand of the water stance, the palm down and forward
    "hold": ((0.15, 0.5, 0.85), (1.0, 0.0, -0.18)),            # a rock held between the palms, the palm in
    "arms_out": ((-1.0, 0.0, 0.1), (0.0, -1.0, 0.0)),          # an arm out wide, the palm down
    "palm_up_wide": ((-0.5, 0.0, 0.86), (0.0, 1.0, 0.0)),      # the hand out to the side and forward, the palm up
    "press_down": ((0.4, 0.0, 0.92), (0.0, -1.0, 0.0)),        # pressed down in front, the palm down
    "claw": ((0.05, 0.6, 0.8), (0.2, -0.8, 0.55)),             # the stance's forward hand, the fingers up and out, the palm forward-down
})

## A stance's own stand under the loop (the feet and the hands where the stance keeps them): every stance channel keys its own.
SET2 = {
    # ---------------------------------------------------------------- the stances (idle loops while casting as an element)
    # earth: Hung Gar's low wide horse: the feet well apart and turned out, the knees pushed out, the root low; the left forearm
    # forward in guard, the right fist chambered at the ribs; slow breathing, the weight sunk and rocking a little side to side
    "stance_earth": {
        "length": 84, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.115, 0.0)), (21, (0.012, -0.122, 0.0)), (42, (0.0, -0.112, 0.0)), (63, (-0.012, -0.122, 0.0)),
                 (84, (0.0, -0.115, 0.0))],
        "hips": [(0, 5), (42, 6), (84, 5)],
        "chest": [(0, 1), (21, 2.5), (42, 0), (63, 2.5), (84, 1)],
        "roll": [(0, 0), (21, 1.2), (42, 0), (63, -1.2), (84, 0)],
        "yaw": [(0, -8), (84, -8)],
        "twist": [(0, -6), (42, -4), (84, -6)],
        "head": [(0, 2), (42, 0), (84, 2)],
        "clav_r": [(0, (0, 4)), (42, (2, 3)), (84, (0, 4))],
        "clav_l": [(0, (2, 2)), (42, (3, 1)), (84, (2, 2))],
        "hand_r": [(0, (-0.19, 0.98, 0.04)), (42, (-0.19, 0.975, 0.05)), (84, (-0.19, 0.98, 0.04))],
        "hand_l": [(0, (0.08, 1.12, 0.33)), (21, (0.075, 1.11, 0.335)), (42, (0.08, 1.1, 0.33)), (63, (0.085, 1.11, 0.325)),
                   (84, (0.08, 1.12, 0.33))],
        "face_r": [(0, "chamber"), (84, "chamber")],
        "face_l": [(0, "claw"), (84, "claw")],
        "pole_r": [(0, (-0.6, -0.4, -1.0)), (84, (-0.6, -0.4, -1.0))],
        "pole_l": [(0, (0.8, -0.8, 0.0)), (84, (0.8, -0.8, 0.0))],
        "grip_r": [(0, 1.0), (84, 1.0)],
        "grip_l": [(0, 0.2), (42, 0.3), (84, 0.2)],
        "foot_r": [(0, (-0.25, 0.077, -0.03)), (84, (-0.25, 0.077, -0.03))],
        "foot_l": [(0, (0.25, 0.077, 0.03)), (84, (0.25, 0.077, 0.03))],
        "fyaw_r": [(0, 24), (84, 24)], "fyaw_l": [(0, 18), (84, 18)],
        "knee_r": [(0, (-0.5, 0.0, 1.0)), (84, (-0.5, 0.0, 1.0))], "knee_l": [(0, (0.5, 0.0, 1.0)), (84, (0.5, 0.0, 1.0))],
    },
    # fire: Northern Shaolin's ready: side-on, the left foot ahead, up on the balls of the feet, the fists up in guard; a quick
    # bounce on the toes (two a loop) and the lead fist working
    "stance_fire": {
        "length": 40, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.05, 0.01)), (10, (0.0, -0.068, 0.012)), (20, (0.0, -0.05, 0.01)), (30, (0.0, -0.068, 0.012)),
                 (40, (0.0, -0.05, 0.01))],
        "yaw": [(0, -22), (20, -20), (40, -22)],
        "twist": [(0, -6), (20, -8), (40, -6)],
        "hips": [(0, 4), (10, 6), (20, 4), (30, 6), (40, 4)],
        "chest": [(0, 5), (10, 6.5), (20, 5), (30, 6.5), (40, 5)],
        "head": [(0, 3), (40, 3)],
        "clav_r": [(0, (6, -2)), (40, (6, -2))], "clav_l": [(0, (8, -2)), (40, (8, -2))],
        "hand_l": [(0, (0.06, 1.3, 0.32)), (10, (0.05, 1.28, 0.33)), (20, (0.06, 1.31, 0.31)), (30, (0.05, 1.28, 0.33)),
                   (40, (0.06, 1.3, 0.32))],
        "hand_r": [(0, (-0.13, 1.18, 0.16)), (10, (-0.13, 1.17, 0.165)), (20, (-0.13, 1.18, 0.16)), (30, (-0.13, 1.17, 0.165)),
                   (40, (-0.13, 1.18, 0.16))],
        "face_r": [(0, "fist_guard"), (40, "fist_guard")], "face_l": [(0, "fist_guard"), (40, "fist_guard")],
        "pole_r": [(0, (-0.5, -1.0, -0.2)), (40, (-0.5, -1.0, -0.2))], "pole_l": [(0, (0.4, -1.0, -0.2)), (40, (0.4, -1.0, -0.2))],
        "grip_r": [(0, 1.0), (40, 1.0)], "grip_l": [(0, 1.0), (40, 1.0)],
        "foot_l": [(0, (0.13, 0.077, 0.17)), (40, (0.13, 0.077, 0.17))],
        "foot_r": [(0, (-0.15, 0.077, -0.15)), (40, (-0.15, 0.077, -0.15))],
        "fyaw_l": [(0, -4), (40, -4)], "fyaw_r": [(0, 34), (40, 34)],
        "heel_l": [(0, 10), (10, 14), (20, 10), (30, 14), (40, 10)],
        "heel_r": [(0, 20), (10, 24), (20, 20), (30, 24), (40, 20)],
        "knee_l": [(0, (0.15, 0.0, 1.0)), (40, (0.15, 0.0, 1.0))], "knee_r": [(0, (-0.5, 0.0, 1.0)), (40, (-0.5, 0.0, 1.0))],
    },
    # water: tai chi: a short bow stance, the weight flowing forward onto the front leg as the soft hands push out and down,
    # back onto the rear leg as they draw in and rise; the turn following the weight; slow
    "stance_water": {
        "length": 108, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.075, -0.02)), (27, (0.008, -0.088, 0.01)), (54, (0.0, -0.08, 0.035)), (81, (-0.008, -0.088, 0.005)),
                 (108, (0.0, -0.075, -0.02))],
        "yaw": [(0, -10), (54, -4), (108, -10)],
        "twist": [(0, -6), (27, -2), (54, 2), (81, -2), (108, -6)],
        "hips": [(0, 1), (54, 4), (108, 1)],
        "chest": [(0, -1), (54, 3), (108, -1)],
        "side": [(0, 0), (27, 1.5), (54, 0), (81, -1.5), (108, 0)],
        "head": [(0, 1), (54, 0), (108, 1)],
        "clav_r": [(0, (0, 0)), (54, (6, 2)), (108, (0, 0))], "clav_l": [(0, (0, 0)), (54, (6, 2)), (108, (0, 0))],
        "hand_r": [(0, (-0.2, 1.14, 0.15)), (27, (-0.21, 1.08, 0.26)), (54, (-0.19, 1.0, 0.36)), (81, (-0.2, 1.04, 0.24)),
                   (108, (-0.2, 1.14, 0.15))],
        "hand_l": [(0, (0.18, 1.18, 0.2)), (27, (0.19, 1.12, 0.31)), (54, (0.17, 1.05, 0.41)), (81, (0.18, 1.09, 0.29)),
                   (108, (0.18, 1.18, 0.2))],
        "face_r": [(0, "float"), (108, "float")], "face_l": [(0, "float"), (108, "float")],
        "pole_r": [(0, (-0.8, -0.7, -0.3)), (108, (-0.8, -0.7, -0.3))], "pole_l": [(0, (0.8, -0.7, -0.3)), (108, (0.8, -0.7, -0.3))],
        "grip_r": [(0, -0.05), (54, 0.1), (108, -0.05)], "grip_l": [(0, -0.05), (54, 0.1), (108, -0.05)],
        "foot_l": [(0, (0.14, 0.077, 0.15)), (108, (0.14, 0.077, 0.15))],
        "foot_r": [(0, (-0.15, 0.077, -0.12)), (108, (-0.15, 0.077, -0.12))],
        "fyaw_l": [(0, 4), (108, 4)], "fyaw_r": [(0, 30), (108, 30)],
        "knee_l": [(0, (0.25, 0.0, 1.0)), (108, (0.25, 0.0, 1.0))], "knee_r": [(0, (-0.45, 0.0, 1.0)), (108, (-0.45, 0.0, 1.0))],
    },
    # air: Baguazhang's circle walker standing: light on the feet, the heels just up, the body turning a little one way and the
    # other about the waist, the lead palm out at the shoulder's height facing in, the rear palm by the elbow; the palms
    # trading their height as it turns
    "stance_air": {
        "length": 96, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.045, 0.0)), (24, (0.015, -0.05, 0.005)), (48, (0.0, -0.04, 0.0)), (72, (-0.015, -0.05, -0.005)),
                 (96, (0.0, -0.045, 0.0))],
        "yaw": [(0, 0), (24, 10), (48, 0), (72, -10), (96, 0)],
        "twist": [(0, 0), (24, 8), (48, 0), (72, -8), (96, 0)],
        "hips": [(0, 2), (96, 2)],
        "chest": [(0, 1), (48, 2), (96, 1)],
        "side": [(0, 0), (24, -2), (48, 0), (72, 2), (96, 0)],
        "head": [(0, 0), (96, 0)],
        "look": [(0, 0), (24, 6), (48, 0), (72, -6), (96, 0)],
        "clav_r": [(0, (2, 0)), (96, (2, 0))], "clav_l": [(0, (2, 0)), (96, (2, 0))],
        "hand_l": [(0, (0.2, 1.28, 0.34)), (24, (0.24, 1.3, 0.3)), (48, (0.2, 1.24, 0.34)), (72, (0.12, 1.18, 0.32)),
                   (96, (0.2, 1.28, 0.34))],
        "hand_r": [(0, (-0.1, 1.08, 0.24)), (24, (-0.06, 1.12, 0.26)), (48, (-0.12, 1.16, 0.3)), (72, (-0.22, 1.24, 0.32)),
                   (96, (-0.1, 1.08, 0.24))],
        "face_r": [(0, "push"), (96, "push")], "face_l": [(0, "push"), (96, "push")],
        "pole_r": [(0, (-0.7, -0.8, 0.0)), (96, (-0.7, -0.8, 0.0))], "pole_l": [(0, (0.7, -0.8, 0.0)), (96, (0.7, -0.8, 0.0))],
        "grip_r": [(0, -0.3), (96, -0.3)], "grip_l": [(0, -0.3), (96, -0.3)],
        "foot_l": [(0, (0.12, 0.077, 0.08)), (96, (0.12, 0.077, 0.08))],
        "foot_r": [(0, (-0.14, 0.077, -0.06)), (96, (-0.14, 0.077, -0.06))],
        "fyaw_l": [(0, 2), (24, 6), (48, 2), (72, -2), (96, 2)], "fyaw_r": [(0, 14), (24, 10), (48, 14), (72, 18), (96, 14)],
        "heel_l": [(0, 6), (24, 4), (48, 6), (72, 9), (96, 6)], "heel_r": [(0, 8), (24, 11), (48, 8), (72, 5), (96, 8)],
    },
    # ---------------------------------------------------------------- earth
    # the boulder (the owner, 2026-10-05: "I expect the ball to have a left kick to stomp and then push"): the weight onto the
    # right leg, the left foot kicks up under the rock (it comes up out of the ground), the palms rising with it; the left knee
    # high, then the foot stamped down out ahead in a wide stance (the rock planted before him) with the palms pressed down;
    # the palms drawn back to the ribs (held); the two-hand push from the chest, the back leg straightening.  strike_s: the push
    "earth_boulder": {
        "length": 50, "meta": {"hold_s": 19 / FPS, "strike_s": 23 / FPS, "back_s": 33 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (-0.06, -0.04, -0.01)), (9, (-0.075, -0.02, -0.02)), (12, (-0.07, -0.03, -0.02)),
                 (15, (0.0, -0.16, 0.06)), (17, (0.0, -0.18, 0.05)), (19, (0.0, -0.17, 0.0)), (23, (0.0, -0.14, 0.15)),
                 (26, (0.0, -0.15, 0.17)), (33, (0.0, -0.14, 0.15)), (42, (0.0, -0.05, 0.03)), (50, (0, -0.015, 0))],
        "yaw": [(0, 0), (9, 4), (15, -6), (19, -8), (23, 6), (33, 4), (50, 0)],
        "twist": [(0, 0), (9, 4), (15, -4), (19, -6), (23, 4), (33, 3), (50, 0)],
        "roll": [(0, 0), (4, 3), (9, 5), (12, 4), (15, 0), (50, 0)],
        "hips": [(0, 0), (9, -4), (12, -2), (15, 6), (19, -3), (23, 7), (26, 9), (33, 7), (50, 0)],
        "chest": [(0, 0), (9, -6), (12, -3), (15, 8), (19, -5), (23, 9), (26, 12), (33, 8), (50, 0)],
        "side": [(0, 0), (9, -4), (12, -3), (15, 0), (50, 0)],
        "head": [(0, 0), (9, 8), (12, 6), (15, 4), (19, -2), (23, -2), (50, 0)],
        "clav_r": [(0, (0, 0)), (9, (4, -6)), (15, (4, 6)), (19, (-8, 4)), (23, (14, -2)), (26, (16, -2)), (33, (13, -2)),
                   (50, (0, 0))],
        "clav_l": [(0, (0, 0)), (9, (4, -6)), (15, (4, 6)), (19, (-8, 4)), (23, (14, -2)), (26, (16, -2)), (33, (13, -2)),
                   (50, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.2, 0.9, 0.18)), (9, (-0.17, 1.08, 0.3)), (12, (-0.15, 1.24, 0.28)), (15, (-0.22, 0.95, 0.32)),
                   (17, (-0.22, 0.92, 0.3)), (19, (-0.18, 1.02, -0.04)), (21, (-0.15, 1.1, 0.32)), (23, (-0.13, 1.13, 0.68)),
                   (26, (-0.13, 1.13, 0.69)), (33, (-0.13, 1.12, 0.65)), (41, (-0.2, 0.95, 0.25)), (50, HR)],
        "hand_l": [(0, HL), (5, (0.2, 0.9, 0.18)), (9, (0.17, 1.08, 0.3)), (12, (0.15, 1.24, 0.28)), (15, (0.22, 0.95, 0.32)),
                   (17, (0.22, 0.92, 0.3)), (19, (0.18, 1.02, -0.04)), (21, (0.15, 1.1, 0.32)), (23, (0.13, 1.14, 0.655)),
                   (26, (0.13, 1.13, 0.665)), (33, (0.13, 1.12, 0.635)), (41, (0.2, 0.95, 0.25)), (50, HL)],
        "face_r": [(0, "stand"), (6, "chamber"), (12, "chamber"), (15, "press_down"), (17, "press_down"), (19, "chamber"),
                   (22, "push"), (36, "push"), (50, "stand")],
        "face_l": [(0, "stand"), (6, "chamber"), (12, "chamber"), (15, "press_down"), (17, "press_down"), (19, "chamber"),
                   (22, "push"), (36, "push"), (50, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (9, (-0.8, -0.6, -0.4)), (15, (-1.0, 0.2, -0.3)), (19, (-0.3, -0.4, -1.0)),
                   (23, (-0.8, -0.6, -0.1)), (50, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (9, (0.8, -0.6, -0.4)), (15, (1.0, 0.2, -0.3)), (19, (0.3, -0.4, -1.0)),
                   (23, (0.8, -0.6, -0.1)), (50, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (6, -0.2), (14, -0.2), (16, -0.45), (19, 0.15), (22, -0.45), (38, -0.45), (50, 0.4)],
        "grip_l": [(0, 0.4), (6, -0.2), (14, -0.2), (16, -0.45), (19, 0.15), (22, -0.45), (38, -0.45), (50, 0.4)],
        # the left foot: the kick up under the rock (the toes up), the knee high, the stamp out ahead; back in at the end
        "foot_l": [(0, FL), (4, (0.14, 0.12, 0.03)), (7, (0.15, 0.24, 0.32)), (9, (0.15, 0.4, 0.5)), (12, (0.17, 0.46, 0.2)),
                   (15, (0.22, 0.077, 0.3)), (36, (0.22, 0.077, 0.3)), (40, (0.18, 0.15, 0.15)), (44, FL), (50, FL)],
        "heel_l": [(0, 0), (3, 14), (7, -18), (9, -26), (12, -6), (14, -2), (15, 0), (36, 0), (39, 10), (43, 0), (50, 0)],
        "fyaw_l": [(0, 7), (9, 0), (15, 10), (36, 10), (44, 7)],
        "knee_l": [(0, "auto"), (4, (0.15, 0.3, 1.0)), (40, (0.3, 0.1, 1.0)), (44, "auto")],
        "foot_r": [(0, FR), (15, (-0.16, 0.077, -0.06)), (36, (-0.16, 0.077, -0.06)), (44, FR)],
        "fyaw_r": [(0, 7), (9, 12), (15, 24), (23, 34), (36, 34), (44, 7)],
        "heel_r": [(0, 0), (50, 0)],
        "knee_r": [(0, "auto"), (4, (-0.3, 0.0, 1.0)), (15, (-0.45, 0.0, 1.0)), (40, (-0.45, 0.0, 1.0)), (44, "auto")],
    },
    # the stomp-rise (a wall or a column raised): the right knee up, the palms low and turned up; the foot stamped down out wide
    # and the body sunk (held); then the palms driven up to the chest's height as the legs rise, the wall coming up with them
    "earth_raise": {
        "length": 40, "meta": {"hold_s": 10 / FPS, "strike_s": 14 / FPS, "back_s": 25 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (5, (0.06, -0.03, -0.01)), (8, (-0.06, -0.15, 0.0)), (10, (-0.065, -0.17, 0.0)),
                 (14, (-0.06, -0.08, 0.02)), (17, (-0.06, -0.075, 0.02)), (25, (-0.06, -0.085, 0.015)), (33, (-0.01, -0.03, 0.0)),
                 (40, (0, -0.015, 0))],
        "roll": [(0, 0), (5, -4), (8, 1), (10, 0), (40, 0)],
        "hips": [(0, 0), (5, -2), (8, 8), (10, 9), (14, 0), (17, -2), (25, -1), (40, 0)],
        "chest": [(0, 0), (5, -4), (8, 10), (10, 12), (14, -4), (17, -7), (25, -5), (40, 0)],
        "head": [(0, 0), (5, 6), (10, 8), (14, -4), (17, -8), (25, -5), (40, 0)],
        "clav_r": [(0, (0, 0)), (10, (4, 6)), (14, (6, -12)), (17, (6, -14)), (25, (5, -10)), (40, (0, 0))],
        "clav_l": [(0, (0, 0)), (10, (4, 6)), (14, (6, -12)), (17, (6, -14)), (25, (5, -10)), (40, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.17, 0.92, 0.18)), (8, (-0.24, 0.78, 0.3)), (10, (-0.24, 0.76, 0.31)), (12, (-0.22, 1.0, 0.36)),
                   (14, (-0.2, 1.3, 0.38)), (17, (-0.2, 1.36, 0.36)), (25, (-0.2, 1.33, 0.34)), (32, (-0.2, 1.05, 0.22)), (40, HR)],
        "hand_l": [(0, HL), (5, (0.17, 0.92, 0.18)), (8, (0.22, 0.8, 0.31)), (10, (0.22, 0.78, 0.32)), (12, (0.2, 1.02, 0.37)),
                   (14, (0.18, 1.31, 0.39)), (17, (0.18, 1.37, 0.37)), (25, (0.18, 1.34, 0.35)), (32, (0.2, 1.05, 0.22)), (40, HL)],
        "face_r": [(0, "stand"), (5, "chamber"), (13, "chamber"), (16, "push"), (28, "push"), (40, "stand")],
        "face_l": [(0, "stand"), (5, "chamber"), (13, "chamber"), (16, "push"), (28, "push"), (40, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (8, (-1.0, -0.3, -0.3)), (14, (-1.0, -0.6, 0.0)), (40, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (8, (1.0, -0.3, -0.3)), (14, (1.0, -0.6, 0.0)), (40, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, -0.1), (13, -0.1), (15, -0.5), (30, -0.5), (40, 0.4)],
        "grip_l": [(0, 0.4), (5, -0.1), (13, -0.1), (15, -0.5), (30, -0.5), (40, 0.4)],
        "foot_r": [(0, FR), (3, (-0.14, 0.14, 0.03)), (5, (-0.17, 0.32, 0.13)), (6, (-0.19, 0.3, 0.12)), (8, (-0.28, 0.077, 0.03)),
                   (30, (-0.28, 0.077, 0.03)), (34, (-0.2, 0.14, -0.01)), (37, FR), (40, FR)],
        "heel_r": [(0, 0), (3, 14), (5, -6), (7, -2), (8, 0), (30, 0), (33, 10), (36, 0), (40, 0)],
        "fyaw_r": [(0, 7), (5, 2), (8, 22), (30, 22), (37, 7)],
        "knee_r": [(0, "auto"), (3, (-0.2, 0.0, 1.0)), (34, (-0.3, 0.0, 1.0)), (37, "auto")],
        "foot_l": [(0, FL), (40, FL)],
        "fyaw_l": [(0, 7), (8, 20), (30, 20), (38, 7)],
        "knee_l": [(0, "auto"), (8, (0.45, 0.0, 1.0)), (30, (0.45, 0.0, 1.0)), (38, "auto")],
    },
    # the side burrow-step (Earth Skate's slide and burrow): the body dropped low and leaned to the right, the right foot
    # stepped out wide, the right palm down by the ground and the left guarding the face; the dive along it.  The feet stay
    # planted (the game carries the body: a ground-surfer's glide)
    "earth_burrow": {
        "length": 34, "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 20 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (-0.06, -0.15, 0.0)), (6, (-0.09, -0.24, 0.0)), (9, (-0.12, -0.28, 0.03)),
                 (14, (-0.12, -0.27, 0.03)), (20, (-0.1, -0.24, 0.02)), (28, (-0.02, -0.06, 0.0)), (34, (0, -0.015, 0))],
        "roll": [(0, 0), (6, -8), (9, -12), (20, -10), (34, 0)],
        "hips": [(0, 0), (6, 18), (9, 24), (20, 20), (34, 0)],
        "chest": [(0, 0), (6, 10), (9, 14), (20, 12), (34, 0)],
        "side": [(0, 0), (6, -6), (9, -10), (20, -8), (34, 0)],
        "yaw": [(0, 0), (6, -10), (20, -10), (34, 0)],
        "head": [(0, 0), (6, -12), (9, -16), (20, -14), (34, 0)],
        "clav_r": [(0, (0, 0)), (9, (8, 12)), (20, (8, 10)), (34, (0, 0))],
        "clav_l": [(0, (0, 0)), (9, (4, -4)), (34, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.29, 0.71, 0.17)), (6, (-0.31, 0.62, 0.24)), (9, (-0.315, 0.565, 0.305)),
                   (20, (-0.3, 0.615, 0.28)), (28, (-0.225, 0.77, 0.13)), (34, HR)],
        "hand_l": [(0, HL), (4, (0.12, 1.0, 0.25)), (6, (0.05, 1.05, 0.33)), (9, (0.02, 1.0, 0.36)), (20, (0.03, 1.0, 0.35)),
                   (28, (0.15, 0.9, 0.15)), (34, HL)],
        "face_r": [(0, "stand"), (5, "press_down"), (24, "press_down"), (34, "stand")],
        "face_l": [(0, "stand"), (5, "guard"), (24, "guard"), (34, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-1.0, 0.3, -0.2)), (24, (-1.0, 0.3, -0.2)), (34, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, -1.0, 0.0)), (24, (0.6, -1.0, 0.0)), (34, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, -0.4), (24, -0.4), (34, 0.4)],
        "grip_l": [(0, 0.4), (5, 0.6), (24, 0.6), (34, 0.4)],
        "foot_r": [(0, FR), (2, (-0.16, 0.13, 0.0)), (5, (-0.34, 0.077, 0.02)), (24, (-0.34, 0.077, 0.02)), (28, (-0.22, 0.13, 0.0)),
                   (31, FR), (34, FR)],
        "heel_r": [(0, 0), (2, 12), (4, -4), (5, 0), (24, 0), (27, 10), (30, 0)],
        "fyaw_r": [(0, 7), (5, 35), (24, 35), (31, 7)],
        "knee_r": [(0, "auto"), (4, (-0.6, 0.0, 1.0)), (26, (-0.6, 0.0, 1.0)), (31, "auto")],
        "foot_l": [(0, FL), (34, FL)],
        "heel_l": [(0, 0), (6, 0), (9, 14), (20, 12), (28, 0)],
        "fyaw_l": [(0, 7), (9, 12), (28, 7)],
        "knee_l": [(0, "auto"), (6, (0.2, 0.0, 1.0)), (26, (0.2, 0.0, 1.0)), (31, "auto")],
    },
    # the catch (Catch: catch, Earth Shove: pull): the hands thrown up and wide before the face, the fingers spread, the weight
    # back to meet it (held); the rock taken: the hands clap round it, the right on top and the left under, and draw it in
    # before the chest, the body giving with it, held there.  Round 2's polish (the owner: every guard a pose that reads at a
    # glance; its moments kept): the hold wider and higher, and the rock held as a rock between the palms (it read as two fists
    # in a guard)
    "earth_catch": {
        "length": 38, "meta": {"hold_s": 7 / FPS, "strike_s": 10 / FPS, "back_s": 26 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (5, (0.0, -0.08, 0.01)), (7, (0.0, -0.09, 0.02)), (10, (0.0, -0.14, -0.05)),
                 (13, (0.0, -0.165, -0.08)), (26, (0.0, -0.155, -0.075)), (33, (0.0, -0.045, -0.01)), (38, (0, -0.015, 0))],
        "hips": [(0, 0), (7, 4), (10, -2), (13, -4), (26, -3), (38, 0)],
        "chest": [(0, 0), (7, 4), (10, -4), (13, -9), (26, -7), (38, 0)],
        "head": [(0, 0), (7, -6), (10, 1), (13, 4), (26, 3), (38, 0)],
        "clav_r": [(0, (0, 0)), (7, (10, -16)), (10, (8, -6)), (13, (4, -2)), (26, (4, -2)), (38, (0, 0))],
        "clav_l": [(0, (0, 0)), (7, (10, -16)), (10, (8, -6)), (13, (4, -2)), (26, (4, -2)), (38, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.27, 1.26, 0.3)), (7, (-0.33, 1.46, 0.4)), (10, (-0.1, 1.32, 0.35)), (13, (-0.08, 1.28, 0.27)),
                   (26, (-0.08, 1.275, 0.27)), (32, (-0.2, 0.98, 0.18)), (38, HR)],
        "hand_l": [(0, HL), (4, (0.27, 1.26, 0.3)), (7, (0.33, 1.46, 0.4)), (10, (0.08, 1.04, 0.38)), (13, (0.07, 1.0, 0.32)),
                   (26, (0.07, 0.995, 0.315)), (32, (0.2, 0.96, 0.18)), (38, HL)],
        "face_r": [(0, "stand"), (4, "push"), (8, "push"), (10, "palm_down"), (28, "palm_down"), (38, "stand")],
        "face_l": [(0, "stand"), (4, "push"), (8, "push"), (10, "chamber"), (28, "chamber"), (38, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (7, (-1.0, -0.5, 0.0)), (10, (-1.0, 0.1, -0.2)), (26, (-1.0, 0.1, -0.2)),
                   (38, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (7, (1.0, -0.5, 0.0)), (10, (1.0, -0.6, -0.3)), (26, (1.0, -0.6, -0.3)),
                   (38, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.6), (8, -0.6), (10, 0.05), (28, 0.05), (38, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.6), (8, -0.6), (10, 0.05), (28, 0.05), (38, 0.4)],
        "foot_r": [(0, FR), (3, (-0.15, 0.13, -0.04)), (5, (-0.18, 0.077, -0.14)), (30, (-0.18, 0.077, -0.14)),
                   (33, (-0.16, 0.13, -0.08)), (36, FR), (38, FR)],
        "heel_r": [(0, 0), (3, 12), (5, 0), (30, 0), (32, 10), (35, 0)],
        "fyaw_r": [(0, 7), (5, 24), (30, 24), (36, 7)],
        "knee_r": [(0, "auto"), (3, (-0.3, 0.0, 1.0)), (34, (-0.3, 0.0, 1.0)), (36, "auto")],
        "foot_l": [(0, FL), (38, FL)],
        "fyaw_l": [(0, 7), (10, 12), (30, 12), (36, 7)],
    },
    # the shove (Earth Shove: push): a heavy single palm: the left foot steps out, the right palm drawn back to the ribs with the
    # body coiled to the right (held); the hips turn through and the palm is driven out from the shoulder into a deep bow
    # stance, the left fist pulled back to the hip.  strike_s: the palm out
    "earth_shove": {
        "length": 34, "mirror": True,
        "meta": {"hold_s": 7 / FPS, "strike_s": 11 / FPS, "back_s": 22 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (5, (0.0, -0.06, -0.03)), (7, (0.0, -0.07, -0.03)), (11, (0.0, -0.15, 0.15)),
                 (14, (0.0, -0.16, 0.17)), (22, (0.0, -0.15, 0.15)), (29, (0.0, -0.05, 0.04)), (34, (0, -0.015, 0))],
        "yaw": [(0, 0), (7, -16), (11, 14), (14, 18), (22, 15), (34, 0)],
        "twist": [(0, 0), (7, -12), (11, 10), (14, 14), (22, 11), (34, 0)],
        "hips": [(0, 0), (7, -2), (11, 8), (14, 10), (22, 8), (34, 0)],
        "chest": [(0, 0), (7, -4), (11, 9), (14, 12), (22, 9), (34, 0)],
        "head": [(0, 0), (7, -2), (11, -4), (34, 0)],
        "clav_r": [(0, (0, 0)), (7, (-10, 4)), (11, (16, -2)), (14, (18, -2)), (22, (14, -2)), (34, (0, 0))],
        "clav_l": [(0, (0, 0)), (7, (8, -2)), (11, (-6, 2)), (22, (-4, 2)), (34, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.2, 0.98, 0.04)), (7, (-0.2, 1.06, -0.06)), (9, (-0.13, 1.13, 0.3)), (11, (-0.02, 1.15, 0.71)),
                   (14, (-0.015, 1.145, 0.71)), (22, (-0.025, 1.13, 0.67)), (29, (-0.18, 0.95, 0.2)), (34, HR)],
        "hand_l": [(0, HL), (4, (0.18, 1.1, 0.25)), (7, (0.12, 1.2, 0.36)), (10, (0.2, 1.02, 0.1)), (14, (0.2, 0.98, -0.02)),
                   (22, (0.2, 0.98, -0.01)), (34, HL)],
        "face_r": [(0, "stand"), (4, "chamber"), (8, "chamber"), (11, "push"), (24, "push"), (34, "stand")],
        "face_l": [(0, "stand"), (4, "point"), (8, "point"), (11, "chamber"), (24, "chamber"), (34, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (7, (-0.3, -0.5, -1.0)), (11, (-0.8, -0.6, -0.1)), (34, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (7, (0.6, -0.8, 0.0)), (11, (0.4, -0.3, -1.0)), (34, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.2), (9, -0.45), (26, -0.45), (34, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.2), (9, 0.9), (26, 0.9), (34, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.13, 0.04)), (6, (0.17, 0.077, 0.285)), (25, (0.17, 0.077, 0.29)), (28, (0.15, 0.13, 0.12)),
                   (31, FL), (34, FL)],
        "heel_l": [(0, 0), (3, 10), (5, -6), (6, 0), (25, 0), (27, 10), (30, 0)],
        "fyaw_l": [(0, 7), (6, 4), (28, 4), (31, 7)],
        "knee_l": [(0, "auto"), (3, (0.2, 0.2, 1.0)), (29, (0.2, 0.2, 1.0)), (32, "auto")],
        "foot_r": [(0, FR), (6, (-0.15, 0.077, -0.08)), (27, (-0.15, 0.077, -0.08)), (32, FR)],
        "fyaw_r": [(0, 7), (7, 20), (11, 36), (27, 36), (32, 7)],
        "heel_r": [(0, 0), (34, 0)],
    },
    # ---------------------------------------------------------------- fire (Northern Shaolin: long punches, kicks)
    # the straight punch (Fire Blast: punch, stream; Fire Jab: jab): a short step in, the fists up; the right fist chambered at
    # the ribs, the body coiled (held); the hips snap through and the fist drives straight out, the left pulled back to the
    # ribs.  strike_s: the fist out
    "fire_punch": {
        "length": 26, "mirror": True,
        "meta": {"hold_s": 5 / FPS, "strike_s": 8 / FPS, "back_s": 15 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.06, 0.03)), (5, (0.0, -0.065, 0.03)), (8, (0.0, -0.09, 0.11)),
                 (10, (0.0, -0.095, 0.12)), (15, (0.0, -0.09, 0.11)), (21, (0.0, -0.04, 0.03)), (26, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -18), (8, 16), (10, 20), (15, 16), (26, 0)],
        "twist": [(0, 0), (5, -10), (8, 12), (10, 14), (15, 12), (26, 0)],
        "hips": [(0, 0), (5, 3), (8, 7), (10, 8), (15, 6), (26, 0)],
        "chest": [(0, 0), (5, 4), (8, 8), (10, 9), (15, 7), (26, 0)],
        "head": [(0, 0), (5, 2), (8, -2), (26, 0)],
        "clav_r": [(0, (0, 0)), (5, (-8, 2)), (8, (16, -4)), (10, (18, -4)), (15, (14, -3)), (26, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, -2)), (8, (-6, 2)), (15, (-4, 2)), (26, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.18, 1.02, 0.08)), (5, (-0.18, 1.04, -0.02)), (7, (-0.1, 1.28, 0.4)), (8, (-0.02, 1.34, 0.69)),
                   (10, (-0.02, 1.33, 0.68)), (15, (-0.035, 1.3, 0.63)), (21, (-0.17, 1.0, 0.2)), (26, HR)],
        "hand_l": [(0, HL), (3, (0.1, 1.24, 0.3)), (5, (0.07, 1.28, 0.36)), (8, (0.19, 1.05, 0.04)), (10, (0.19, 1.03, -0.01)),
                   (15, (0.19, 1.03, 0.0)), (21, (0.18, 0.92, 0.1)), (26, HL)],
        "face_r": [(0, "stand"), (3, "chamber"), (5, "chamber"), (8, "fist_fwd"), (17, "fist_fwd"), (26, "stand")],
        "face_l": [(0, "stand"), (3, "fist_guard"), (5, "fist_guard"), (8, "chamber"), (17, "chamber"), (26, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.3, -0.5, -1.0)), (8, (-0.6, -1.0, 0.0)), (26, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.4, -1.0, -0.2)), (8, (0.3, -0.5, -1.0)), (26, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, 1.0), (22, 1.0), (26, 0.4)],
        "grip_l": [(0, 0.4), (3, 1.0), (22, 1.0), (26, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.05)), (4, (0.14, 0.077, 0.2)), (18, (0.14, 0.077, 0.2)), (21, (0.13, 0.12, 0.08)),
                   (24, FL), (26, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 0), (18, 0), (20, 8), (23, 0)],
        "knee_l": [(0, "auto"), (2, (0.2, 0.2, 1.0)), (22, (0.2, 0.2, 1.0)), (24, "auto")],
        "foot_r": [(0, FR), (4, (-0.14, 0.077, -0.06)), (20, (-0.14, 0.077, -0.06)), (24, FR)],
        "fyaw_r": [(0, 7), (5, 30), (8, 40), (18, 40), (24, 7)],
        "heel_r": [(0, 0), (5, 6), (8, 22), (15, 18), (21, 0)],
    },
    # the double jab (Fire Jab: double jab, embers): the fists up in guard (held); the left jab snaps out and back, then the
    # right cross behind it (Fire Jab's second bolt, 0.15 s after the first).  strike_s: the left jab
    "fire_double": {
        "length": 30,
        "meta": {"hold_s": 5 / FPS, "strike_s": 8 / FPS, "back_s": 18 / FPS, "hand": "l", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.06, 0.03)), (5, (0.0, -0.065, 0.03)), (8, (0.0, -0.07, 0.08)),
                 (10, (0.0, -0.07, 0.06)), (13, (0.0, -0.09, 0.12)), (18, (0.0, -0.085, 0.11)), (25, (0.0, -0.035, 0.03)),
                 (30, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -16), (8, -24), (10, -14), (13, 16), (18, 12), (30, 0)],
        "twist": [(0, 0), (5, -8), (8, -14), (10, -6), (13, 12), (18, 9), (30, 0)],
        "hips": [(0, 0), (5, 4), (8, 5), (13, 8), (18, 6), (30, 0)],
        "chest": [(0, 0), (5, 5), (8, 6), (13, 9), (18, 7), (30, 0)],
        "head": [(0, 0), (5, 3), (13, -1), (30, 0)],
        "clav_r": [(0, (0, 0)), (5, (4, -2)), (10, (0, 0)), (13, (16, -4)), (18, (12, -3)), (30, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (6, -2)), (8, (16, -4)), (10, (6, -2)), (13, (-4, 2)), (30, (0, 0))],
        "hand_l": [(0, HL), (3, (0.08, 1.26, 0.3)), (5, (0.06, 1.3, 0.3)), (7, (0.05, 1.34, 0.52)), (8, (0.03, 1.35, 0.67)),
                   (10, (0.07, 1.28, 0.34)), (13, (0.17, 1.12, 0.12)), (18, (0.17, 1.12, 0.14)), (25, (0.17, 0.95, 0.12)), (30, HL)],
        "hand_r": [(0, HR), (3, (-0.13, 1.18, 0.16)), (5, (-0.13, 1.2, 0.16)), (8, (-0.14, 1.2, 0.14)), (10, (-0.12, 1.24, 0.25)),
                   (12, (-0.04, 1.32, 0.56)), (13, (-0.02, 1.33, 0.68)), (18, (-0.035, 1.3, 0.62)), (25, (-0.17, 1.0, 0.18)), (30, HR)],
        "face_l": [(0, "stand"), (3, "fist_guard"), (6, "fist_guard"), (8, "fist_fwd"), (9, "fist_fwd"), (11, "fist_guard"),
                   (20, "fist_guard"), (30, "stand")],
        "face_r": [(0, "stand"), (3, "fist_guard"), (10, "fist_guard"), (13, "fist_fwd"), (20, "fist_fwd"), (30, "stand")],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.4, -1.0, -0.2)), (8, (0.6, -1.0, 0.0)), (11, (0.4, -1.0, -0.2)),
                   (30, (0.35, -0.1, -1.0))],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.5, -1.0, -0.2)), (13, (-0.6, -1.0, 0.0)), (30, (-0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, 1.0), (26, 1.0), (30, 0.4)],
        "grip_l": [(0, 0.4), (3, 1.0), (26, 1.0), (30, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.05)), (4, (0.13, 0.077, 0.18)), (22, (0.13, 0.077, 0.18)), (25, (0.13, 0.12, 0.08)),
                   (28, FL), (30, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 6), (22, 6), (24, 8), (27, 0)],
        "knee_l": [(0, "auto"), (2, (0.2, 0.2, 1.0)), (26, (0.2, 0.2, 1.0)), (28, "auto")],
        "foot_r": [(0, FR), (4, (-0.15, 0.077, -0.12)), (22, (-0.15, 0.077, -0.12)), (28, FR)],
        "fyaw_r": [(0, 7), (5, 32), (13, 42), (22, 40), (28, 7)],
        "heel_r": [(0, 0), (4, 16), (10, 14), (13, 26), (20, 20), (26, 0)],
    },
    # the kick (round 2: the High Kick, the crescent over walls and into jumpers; its keys as the second set had them, now with
    # its twin for the chain): the fists up, the weight onto the left leg and the right knee chambered high (held); the leg
    # snaps out, the foot driving forward at the waist's height, the toes pointed; recoiled and set down ahead in a bow stance
    # with the right fist following out; back.  strike_s: the foot out
    "fire_kick": {
        "length": 36, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 22 / FPS, "hand": "foot_r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.05, -0.03, -0.01)), (6, (0.06, -0.035, -0.02)), (9, (0.05, -0.02, -0.04)),
                 (12, (0.05, -0.04, -0.01)), (16, (0.0, -0.1, 0.12)), (22, (0.0, -0.095, 0.11)), (30, (0.0, -0.03, 0.03)),
                 (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -6), (9, -2), (16, 10), (22, 8), (36, 0)],
        "hips": [(0, 0), (6, -6), (9, -14), (12, -6), (16, 6), (22, 5), (36, 0)],
        "chest": [(0, 0), (6, 4), (9, 2), (12, 4), (16, 7), (22, 5), (36, 0)],
        "roll": [(0, 0), (6, 4), (9, 3), (14, 0), (36, 0)],
        "head": [(0, 0), (6, 2), (9, 6), (12, 2), (36, 0)],
        "clav_r": [(0, (0, 0)), (6, (4, -2)), (16, (14, -2)), (22, (10, -2)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (6, -2)), (16, (-2, 0)), (36, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.14, 1.2, 0.18)), (6, (-0.14, 1.22, 0.16)), (9, (-0.22, 1.05, -0.06)), (12, (-0.16, 1.15, 0.12)),
                   (16, (-0.06, 1.25, 0.5)), (22, (-0.06, 1.24, 0.47)), (29, (-0.18, 0.98, 0.18)), (36, HR)],
        "hand_l": [(0, HL), (4, (0.1, 1.26, 0.28)), (6, (0.08, 1.28, 0.3)), (9, (0.12, 1.3, 0.34)), (12, (0.12, 1.24, 0.28)),
                   (16, (0.19, 1.04, 0.02)), (22, (0.19, 1.04, 0.03)), (36, HL)],
        "face_r": [(0, "stand"), (4, "fist_guard"), (12, "fist_guard"), (16, "fist_fwd"), (24, "fist_fwd"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "fist_guard"), (13, "fist_guard"), (16, "chamber"), (24, "chamber"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.5, -1.0, -0.2)), (16, (-0.6, -1.0, 0.0)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.4, -1.0, -0.2)), (16, (0.3, -0.5, -1.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 1.0), (30, 1.0), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, 1.0), (30, 1.0), (36, 0.4)],
        # the right leg: chambered, snapped out, recoiled, set down ahead
        "foot_r": [(0, FR), (3, (-0.13, 0.2, 0.08)), (6, (-0.12, 0.46, 0.2)), (8, (-0.11, 0.56, 0.48)), (9, (-0.1, 0.58, 0.58)),
                   (11, (-0.11, 0.5, 0.36)), (13, (-0.12, 0.3, 0.3)), (16, (-0.13, 0.077, 0.24)), (25, (-0.13, 0.077, 0.24)),
                   (29, (-0.13, 0.13, 0.1)), (33, FR), (36, FR)],
        "heel_r": [(0, 0), (3, 20), (6, 30), (9, 52), (11, 30), (14, 4), (16, 0), (25, 0), (28, 10), (32, 0)],
        "fyaw_r": [(0, 7), (6, 2), (16, 4), (25, 4), (33, 7)],
        "knee_r": [(0, "auto"), (3, (-0.1, 0.4, 1.0)), (13, (-0.1, 0.4, 1.0)), (16, (-0.15, 0.2, 1.0)), (29, (-0.15, 0.2, 1.0)),
                   (33, "auto")],
        "foot_l": [(0, FL), (16, (0.15, 0.077, -0.1)), (25, (0.15, 0.077, -0.1)), (33, FL)],
        "fyaw_l": [(0, 7), (6, 14), (16, 32), (25, 32), (33, 7)],
        "heel_l": [(0, 0), (9, 0), (16, 14), (22, 12), (30, 0)],
        "knee_l": [(0, "auto"), (6, (0.3, 0.0, 1.0)), (28, (0.3, 0.0, 1.0)), (32, "auto")],
    },
    # the sweep (Fire Arc: sweep; Fire Wall: wall, ring): the right hand wound across to the left shoulder, the body turned to
    # the left (held); the arm sweeps round flat at the shoulder's height, a knife hand, the body unwinding to the right; on
    # out to the side.  strike_s: the hand across the front
    "fire_sweep": {
        "length": 30, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 18 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.02, -0.08, 0.0)), (9, (0.0, -0.11, 0.05)), (12, (-0.03, -0.11, 0.05)),
                 (18, (-0.03, -0.1, 0.04)), (25, (0.0, -0.04, 0.01)), (30, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, 26), (9, 0), (12, -26), (18, -22), (30, 0)],
        "twist": [(0, 0), (6, 18), (9, 0), (12, -18), (18, -14), (30, 0)],
        "hips": [(0, 0), (6, 3), (9, 6), (12, 5), (18, 4), (30, 0)],
        "chest": [(0, 0), (6, 4), (9, 7), (12, 5), (18, 4), (30, 0)],
        "side": [(0, 0), (6, 3), (9, 0), (12, -4), (30, 0)],
        "clav_r": [(0, (0, 0)), (6, (14, -6)), (9, (12, -8)), (12, (-6, -6)), (18, (-4, -4)), (30, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (-4, 2)), (12, (4, -2)), (30, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.05, 1.08, 0.22)), (6, (0.14, 1.24, 0.24)), (8, (0.02, 1.28, 0.5)), (9, (-0.15, 1.29, 0.57)),
                   (10, (-0.32, 1.27, 0.47)), (12, (-0.45, 1.23, 0.18)), (18, (-0.45, 1.2, 0.15)), (25, (-0.28, 0.95, 0.1)), (30, HR)],
        "hand_l": [(0, HL), (3, (0.2, 0.98, 0.1)), (6, (0.19, 1.02, 0.05)), (12, (0.17, 1.06, 0.18)), (18, (0.17, 1.04, 0.16)),
                   (30, HL)],
        "face_r": [(0, "stand"), (4, "sweep_in"), (7, "sweep_in"), (9, "knife"), (12, "sweep_out"), (20, "sweep_out"), (30, "stand")],
        "face_l": [(0, "stand"), (4, "chamber"), (20, "chamber"), (30, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.2, -1.0, 0.0)), (9, (-0.4, -1.0, 0.0)), (12, (-0.3, -1.0, -0.5)),
                   (30, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.3, -0.5, -1.0)), (30, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.3), (22, -0.3), (30, 0.4)],
        "grip_l": [(0, 0.4), (4, 1.0), (22, 1.0), (30, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.12, 0.04)), (5, (0.17, 0.077, 0.18)), (21, (0.17, 0.077, 0.18)), (24, (0.15, 0.12, 0.08)),
                   (27, FL), (30, FL)],
        "heel_l": [(0, 0), (3, 8), (4, -4), (5, 0), (21, 0), (23, 8), (26, 0)],
        "fyaw_l": [(0, 7), (6, 24), (9, 10), (12, -10), (21, -10), (27, 7)],
        "foot_r": [(0, FR), (5, (-0.16, 0.077, -0.08)), (21, (-0.16, 0.077, -0.08)), (27, FR)],
        "fyaw_r": [(0, 7), (6, 0), (9, 20), (12, 36), (21, 34), (27, 7)],
        "heel_r": [(0, 0), (6, 0), (9, 12), (12, 20), (18, 16), (24, 0)],
    },
    # the breath (Breath: breath, smoke, heat): the hands rise to the chest and the chest lifts back with the breath drawn in
    # (held); then the body drives forward, the palms framing the mouth and pushing out with the breath, the head forward.
    # strike_s: the breath out
    "fire_breath": {
        "length": 40,
        "meta": {"hold_s": 10 / FPS, "strike_s": 13 / FPS, "back_s": 26 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (8, (0.0, -0.02, -0.04)), (10, (0.0, -0.025, -0.045)), (13, (0.0, -0.09, 0.1)),
                 (20, (0.0, -0.1, 0.12)), (26, (0.0, -0.09, 0.1)), (34, (0.0, -0.035, 0.02)), (40, (0, -0.015, 0))],
        "hips": [(0, 0), (8, -4), (10, -5), (13, 8), (20, 10), (26, 8), (40, 0)],
        "chest": [(0, 0), (8, -9), (10, -10), (13, 10), (20, 13), (26, 10), (40, 0)],
        "head": [(0, 0), (8, -10), (10, -12), (13, -6), (20, -4), (26, -4), (40, 0)],
        "clav_r": [(0, (0, 0)), (8, (-4, -6)), (13, (10, -6)), (26, (8, -5)), (40, (0, 0))],
        "clav_l": [(0, (0, 0)), (8, (-4, -6)), (13, (10, -6)), (26, (8, -5)), (40, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.16, 1.05, 0.15)), (8, (-0.13, 1.25, 0.12)), (10, (-0.12, 1.3, 0.1)), (13, (-0.13, 1.45, 0.42)),
                   (20, (-0.14, 1.43, 0.45)), (26, (-0.14, 1.4, 0.42)), (33, (-0.2, 1.05, 0.2)), (40, HR)],
        "hand_l": [(0, HL), (5, (0.16, 1.05, 0.15)), (8, (0.13, 1.25, 0.12)), (10, (0.12, 1.3, 0.1)), (13, (0.13, 1.45, 0.42)),
                   (20, (0.14, 1.43, 0.45)), (26, (0.14, 1.4, 0.42)), (33, (0.2, 1.05, 0.2)), (40, HL)],
        "face_r": [(0, "stand"), (5, "chamber"), (10, "chamber"), (13, "push"), (28, "push"), (40, "stand")],
        "face_l": [(0, "stand"), (5, "chamber"), (10, "chamber"), (13, "push"), (28, "push"), (40, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (8, (-0.8, -1.0, -0.4)), (13, (-1.0, -0.6, 0.0)), (40, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (8, (0.8, -1.0, -0.4)), (13, (1.0, -0.6, 0.0)), (40, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, 0.0), (11, 0.0), (13, -0.5), (28, -0.5), (40, 0.4)],
        "grip_l": [(0, 0.4), (5, 0.0), (11, 0.0), (13, -0.5), (28, -0.5), (40, 0.4)],
        "foot_l": [(0, FL), (10, FL), (11, (0.14, 0.12, 0.08)), (13, (0.15, 0.077, 0.24)), (29, (0.15, 0.077, 0.24)),
                   (32, (0.14, 0.12, 0.1)), (35, FL), (40, FL)],
        "heel_l": [(0, 0), (10, 0), (11, 10), (12, -4), (13, 0), (29, 0), (31, 10), (34, 0)],
        "foot_r": [(0, FR), (13, (-0.15, 0.077, -0.06)), (29, (-0.15, 0.077, -0.06)), (35, FR)],
        "fyaw_r": [(0, 7), (13, 30), (29, 30), (35, 7)],
        "heel_r": [(0, 0), (13, 8), (26, 6), (34, 0)],
    },
    # the lightning (Fire Arc: lightning; the longest lock): a wide low stance; both hands circle - together at the belly,
    # apart and up wide, round and down - drawing the charge; the right hand drawn back by the chest with the two fingers out,
    # the left reaching ahead (held, the charge); both hands thrust out together.  strike_s: the hands out
    "fire_lightning": {
        "length": 64,
        "meta": {"hold_s": 32 / FPS, "strike_s": 36 / FPS, "back_s": 47 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.08, 0.02)), (12, (0.0, -0.11, 0.0)), (20, (0.0, -0.08, -0.02)),
                 (28, (0.0, -0.12, 0.0)), (32, (0.0, -0.12, -0.03)), (36, (0.0, -0.13, 0.1)), (40, (0.0, -0.135, 0.12)),
                 (47, (0.0, -0.13, 0.1)), (56, (0.0, -0.04, 0.02)), (64, (0, -0.015, 0))],
        "yaw": [(0, 0), (12, 0), (20, 0), (28, -10), (32, -16), (36, 8), (40, 10), (47, 8), (64, 0)],
        "twist": [(0, 0), (20, 0), (28, -8), (32, -12), (36, 6), (47, 5), (64, 0)],
        "hips": [(0, 0), (12, 4), (20, -2), (28, 3), (32, 0), (36, 8), (40, 9), (47, 7), (64, 0)],
        "chest": [(0, 0), (12, 6), (20, -5), (28, 3), (32, -2), (36, 9), (40, 10), (47, 8), (64, 0)],
        "head": [(0, 0), (12, 6), (20, -6), (28, 0), (32, -2), (36, -3), (64, 0)],
        "clav_r": [(0, (0, 0)), (12, (6, 4)), (20, (-4, -16)), (28, (4, 2)), (32, (-8, -2)), (36, (16, -4)), (47, (12, -3)),
                   (64, (0, 0))],
        "clav_l": [(0, (0, 0)), (12, (6, 4)), (20, (-4, -16)), (28, (4, 2)), (32, (10, -4)), (36, (14, -4)), (47, (12, -3)),
                   (64, (0, 0))],
        "hand_r": [(0, HR), (6, (-0.15, 0.95, 0.2)), (12, (-0.05, 1.02, 0.25)), (16, (-0.3, 1.25, 0.25)), (20, (-0.45, 1.42, 0.02)),
                   (24, (-0.42, 1.1, 0.05)), (28, (-0.22, 0.98, 0.2)), (32, (-0.2, 1.22, -0.03)), (34, (-0.12, 1.3, 0.3)),
                   (36, (-0.02, 1.36, 0.63)), (40, (-0.02, 1.35, 0.64)), (47, (-0.035, 1.32, 0.59)), (56, (-0.2, 0.98, 0.18)), (64, HR)],
        "hand_l": [(0, HL), (6, (0.15, 0.95, 0.2)), (12, (0.05, 1.02, 0.26)), (16, (0.3, 1.25, 0.25)), (20, (0.45, 1.42, 0.02)),
                   (24, (0.42, 1.1, 0.05)), (28, (0.22, 0.98, 0.2)), (32, (0.12, 1.25, 0.42)), (34, (0.06, 1.32, 0.52)),
                   (36, (0.03, 1.35, 0.61)), (40, (0.03, 1.34, 0.62)), (47, (0.04, 1.31, 0.57)), (56, (0.2, 0.98, 0.18)), (64, HL)],
        "face_r": [(0, "stand"), (6, "chamber"), (12, "chamber"), (16, "palm_up_wide"), (24, "palm_up_wide"), (28, "press_down"),
                   (31, "knife"), (48, "knife"), (64, "stand")],
        "face_l": [(0, "stand"), (6, "chamber"), (12, "chamber"), (16, "palm_up_wide"), (24, "palm_up_wide"), (28, "press_down"),
                   (31, "knife"), (48, "knife"), (64, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (12, (-1.0, -0.5, 0.0)), (20, (-0.6, -1.0, -0.4)), (28, (-1.0, -0.4, -0.2)),
                   (32, (-0.3, -0.5, -1.0)), (36, (-0.6, -1.0, 0.0)), (64, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (12, (1.0, -0.5, 0.0)), (20, (0.6, -1.0, -0.4)), (28, (1.0, -0.4, -0.2)),
                   (32, (0.6, -1.0, 0.0)), (64, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (6, -0.2), (28, -0.2), (31, 0.55), (50, 0.55), (64, 0.4)],
        "grip_l": [(0, 0.4), (6, -0.2), (28, -0.2), (31, 0.55), (50, 0.55), (64, 0.4)],
        "foot_l": [(0, FL), (3, (0.15, 0.12, 0.04)), (6, (0.2, 0.077, 0.18)), (52, (0.2, 0.077, 0.18)), (56, (0.16, 0.12, 0.08)),
                   (60, FL), (64, FL)],
        "heel_l": [(0, 0), (3, 8), (5, -4), (6, 0), (52, 0), (55, 8), (59, 0)],
        "fyaw_l": [(0, 7), (6, 10), (52, 10), (60, 7)],
        "knee_l": [(0, "auto"), (4, (0.35, 0.1, 1.0)), (54, (0.35, 0.1, 1.0)), (58, "auto")],
        "foot_r": [(0, FR), (6, (-0.2, 0.077, -0.1)), (52, (-0.2, 0.077, -0.1)), (60, FR)],
        "fyaw_r": [(0, 7), (6, 26), (32, 30), (36, 36), (52, 34), (60, 7)],
        "knee_r": [(0, "auto"), (6, (-0.45, 0.0, 1.0)), (54, (-0.45, 0.0, 1.0)), (58, "auto")],
        "heel_r": [(0, 0), (32, 0), (36, 10), (47, 8), (56, 0)],
    },
    # ---------------------------------------------------------------- water (tai chi: flowing arcs)
    # the whip (Water Whip: whip, lash; Water Jet: splash, jet): the right hand sweeps down and back past the hip drawing the
    # water, the weight back (held); it rises over the shoulder in an arc and lashes out and down, the wrist snapping, the
    # weight onto the front leg; on down across the body.  strike_s: the lash
    "water_whip": {
        "length": 32, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 10 / FPS, "back_s": 20 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.07, -0.05)), (8, (0.0, -0.06, 0.0)), (10, (0.0, -0.09, 0.1)),
                 (13, (0.0, -0.1, 0.12)), (20, (0.0, -0.09, 0.1)), (27, (0.0, -0.035, 0.02)), (32, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -24), (8, -10), (10, 10), (13, 16), (20, 12), (32, 0)],
        "twist": [(0, 0), (6, -16), (8, -6), (10, 8), (13, 12), (20, 9), (32, 0)],
        "hips": [(0, 0), (6, 4), (8, -2), (10, 6), (13, 9), (20, 7), (32, 0)],
        "chest": [(0, 0), (6, 6), (8, -5), (10, 7), (13, 11), (20, 8), (32, 0)],
        "side": [(0, 0), (6, -5), (8, 4), (10, 0), (32, 0)],
        "head": [(0, 0), (6, -2), (8, -4), (10, 0), (32, 0)],
        "clav_r": [(0, (0, 0)), (6, (-12, 6)), (8, (2, -16)), (10, (14, -4)), (13, (12, 2)), (20, (8, 2)), (32, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (6, 0)), (10, (-4, 2)), (32, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.25, 0.8, 0.12)), (6, (-0.3, 0.84, -0.2)), (7, (-0.36, 1.12, -0.16)), (8, (-0.34, 1.44, 0.04)),
                   (9, (-0.16, 1.4, 0.42)), (10, (-0.09, 1.26, 0.68)), (12, (0.0, 1.08, 0.6)), (14, (0.08, 0.98, 0.47)),
                   (20, (0.07, 0.98, 0.44)), (27, (-0.15, 0.9, 0.18)), (32, HR)],
        "hand_l": [(0, HL), (3, (0.2, 1.0, 0.2)), (6, (0.14, 1.15, 0.34)), (10, (0.2, 1.05, 0.15)), (14, (0.21, 1.0, 0.06)),
                   (20, (0.21, 1.0, 0.07)), (32, HL)],
        "face_r": [(0, "stand"), (4, "whip_back"), (6, "whip_back"), (8, "whip_up"), (10, "whip_go"), (13, "palm_down"),
                   (22, "palm_down"), (32, "stand")],
        "face_l": [(0, "stand"), (4, "float"), (8, "float"), (12, "chamber"), (22, "chamber"), (32, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.6, 0.3, -0.8)), (8, (-1.0, 0.3, 0.0)), (10, (-0.8, -0.4, 0.2)),
                   (14, (-0.6, -1.0, 0.0)), (32, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.7, -0.7, 0.0)), (12, (0.5, -0.3, -1.0)), (32, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.1), (9, 0.1), (10, -0.35), (24, -0.2), (32, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.1), (10, 0.3), (24, 0.3), (32, 0.4)],
        "foot_l": [(0, FL), (3, (0.13, 0.12, 0.04)), (5, (0.15, 0.077, 0.22)), (23, (0.15, 0.077, 0.22)), (26, (0.14, 0.12, 0.09)),
                   (29, FL), (32, FL)],
        "heel_l": [(0, 0), (3, 8), (4, -6), (5, -10), (8, 0), (23, 0), (25, 8), (28, 0)],
        "knee_l": [(0, "auto"), (3, (0.2, 0.2, 1.0)), (26, (0.2, 0.2, 1.0)), (29, "auto")],
        "foot_r": [(0, FR), (5, (-0.15, 0.077, -0.08)), (23, (-0.15, 0.077, -0.08)), (29, FR)],
        "fyaw_r": [(0, 7), (6, 36), (10, 30), (23, 28), (29, 7)],
        "heel_r": [(0, 0), (8, 0), (10, 14), (13, 22), (20, 18), (27, 0)],
    },
    # the wave (Wave: push, tide, surf): the palms sink to the hips as the body sinks back (the water gathered), then rise in
    # arcs to the chest with the palms turning forward (held, the wave stood up); both palms push out wide as the weight goes
    # onto the front leg.  strike_s: the push
    "water_wave": {
        "length": 42,
        "meta": {"hold_s": 11 / FPS, "strike_s": 15 / FPS, "back_s": 26 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.12, -0.05)), (11, (0.0, -0.09, -0.06)), (15, (0.0, -0.11, 0.13)),
                 (19, (0.0, -0.12, 0.15)), (26, (0.0, -0.11, 0.13)), (35, (0.0, -0.04, 0.03)), (42, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -6), (11, -8), (15, 4), (26, 3), (42, 0)],
        "hips": [(0, 0), (6, 6), (11, -2), (15, 6), (19, 8), (26, 6), (42, 0)],
        "chest": [(0, 0), (6, 8), (11, -5), (15, 6), (19, 10), (26, 7), (42, 0)],
        "head": [(0, 0), (6, 6), (11, -4), (15, -2), (42, 0)],
        "clav_r": [(0, (0, 0)), (6, (6, 6)), (11, (-6, -6)), (15, (14, -6)), (19, (16, -4)), (26, (12, -3)), (42, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (6, 6)), (11, (-6, -6)), (15, (14, -6)), (19, (16, -4)), (26, (12, -3)), (42, (0, 0))],
        "hand_r": [(0, HR), (6, (-0.22, 0.86, 0.2)), (9, (-0.3, 1.08, 0.12)), (11, (-0.24, 1.25, 0.04)), (13, (-0.25, 1.26, 0.3)),
                   (15, (-0.28, 1.22, 0.615)), (19, (-0.285, 1.16, 0.63)), (26, (-0.27, 1.12, 0.57)), (34, (-0.22, 0.95, 0.22)),
                   (42, HR)],
        "hand_l": [(0, HL), (6, (0.22, 0.86, 0.2)), (9, (0.3, 1.08, 0.12)), (11, (0.24, 1.25, 0.04)), (13, (0.25, 1.26, 0.3)),
                   (15, (0.28, 1.22, 0.605)), (19, (0.285, 1.16, 0.62)), (26, (0.27, 1.12, 0.57)), (34, (0.22, 0.95, 0.22)),
                   (42, HL)],
        "face_r": [(0, "stand"), (5, "palm_down"), (8, "palm_down"), (11, "chamber"), (14, "push"), (28, "push"), (42, "stand")],
        "face_l": [(0, "stand"), (5, "palm_down"), (8, "palm_down"), (11, "chamber"), (14, "push"), (28, "push"), (42, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-1.0, 0.0, -0.3)), (11, (-0.6, -0.8, -0.6)), (15, (-0.9, -0.6, 0.0)),
                   (42, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (1.0, 0.0, -0.3)), (11, (0.6, -0.8, -0.6)), (15, (0.9, -0.6, 0.0)),
                   (42, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, -0.1), (11, 0.05), (14, -0.45), (30, -0.45), (42, 0.4)],
        "grip_l": [(0, 0.4), (5, -0.1), (11, 0.05), (14, -0.45), (30, -0.45), (42, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.12, 0.05)), (6, (0.16, 0.077, 0.26)), (29, (0.16, 0.077, 0.26)), (32, (0.15, 0.12, 0.1)),
                   (36, FL), (42, FL)],
        "heel_l": [(0, 0), (3, 8), (5, -6), (6, -12), (11, -10), (14, 0), (29, 0), (31, 8), (35, 0)],
        "knee_l": [(0, "auto"), (3, (0.25, 0.1, 1.0)), (32, (0.25, 0.1, 1.0)), (36, "auto")],
        "fyaw_l": [(0, 7), (6, 4), (32, 4), (36, 7)],
        "foot_r": [(0, FR), (6, (-0.16, 0.077, -0.08)), (29, (-0.16, 0.077, -0.08)), (36, FR)],
        "fyaw_r": [(0, 7), (6, 30), (29, 30), (36, 7)],
        "knee_r": [(0, "auto"), (6, (-0.4, 0.0, 1.0)), (32, (-0.4, 0.0, 1.0)), (36, "auto")],
    },
    # the draw (Flow: draw, geyser; Frost): from a pool: the palms reach out low and down over the water, the body sinking;
    # they part and circle out wide (held); then sweep in and up before the body, the palms turning up, drawing the water up
    # with them as the legs rise; on up over the head.  strike_s: the palms up before the chest
    "water_draw": {
        "length": 44,
        "meta": {"hold_s": 11 / FPS, "strike_s": 15 / FPS, "back_s": 27 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.13, 0.03)), (11, (0.0, -0.16, 0.02)), (15, (0.0, -0.07, 0.03)),
                 (19, (0.0, -0.035, 0.02)), (27, (0.0, -0.045, 0.02)), (36, (0.0, -0.03, 0.01)), (44, (0, -0.015, 0))],
        "hips": [(0, 0), (6, 14), (11, 12), (15, 2), (19, -2), (27, -1), (44, 0)],
        "chest": [(0, 0), (6, 14), (11, 10), (15, -2), (19, -6), (27, -4), (44, 0)],
        "head": [(0, 0), (6, 10), (11, 8), (15, -6), (19, -12), (27, -8), (44, 0)],
        "clav_r": [(0, (0, 0)), (6, (10, 6)), (11, (4, 2)), (15, (6, -10)), (19, (4, -16)), (27, (3, -12)), (44, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (10, 6)), (11, (4, 2)), (15, (6, -10)), (19, (4, -16)), (27, (3, -12)), (44, (0, 0))],
        "hand_r": [(0, HR), (6, (-0.16, 0.72, 0.42)), (9, (-0.34, 0.76, 0.32)), (11, (-0.42, 0.84, 0.16)), (13, (-0.3, 0.98, 0.32)),
                   (15, (-0.14, 1.15, 0.36)), (17, (-0.16, 1.35, 0.3)), (19, (-0.2, 1.5, 0.24)), (27, (-0.21, 1.46, 0.22)),
                   (35, (-0.22, 1.05, 0.2)), (44, HR)],
        "hand_l": [(0, HL), (6, (0.16, 0.72, 0.42)), (9, (0.34, 0.76, 0.32)), (11, (0.42, 0.84, 0.16)), (13, (0.3, 0.98, 0.32)),
                   (15, (0.14, 1.15, 0.36)), (17, (0.16, 1.35, 0.3)), (19, (0.2, 1.5, 0.24)), (27, (0.21, 1.46, 0.22)),
                   (35, (0.22, 1.05, 0.2)), (44, HL)],
        "face_r": [(0, "stand"), (5, "palm_down"), (11, "palm_down"), (14, "palm_up_wide"), (16, "chamber"), (19, "push"),
                   (29, "push"), (44, "stand")],
        "face_l": [(0, "stand"), (5, "palm_down"), (11, "palm_down"), (14, "palm_up_wide"), (16, "chamber"), (19, "push"),
                   (29, "push"), (44, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.6, 0.6, -0.4)), (11, (-0.8, -0.4, -0.6)), (15, (-1.0, -0.6, 0.0)),
                   (19, (-1.0, -0.2, 0.0)), (44, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, 0.6, -0.4)), (11, (0.8, -0.4, -0.6)), (15, (1.0, -0.6, 0.0)),
                   (19, (1.0, -0.2, 0.0)), (44, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, -0.2), (14, -0.1), (17, 0.1), (19, -0.4), (30, -0.4), (44, 0.4)],
        "grip_l": [(0, 0.4), (5, -0.2), (14, -0.1), (17, 0.1), (19, -0.4), (30, -0.4), (44, 0.4)],
        "foot_l": [(0, FL), (3, (0.15, 0.12, 0.04)), (6, (0.19, 0.077, 0.14)), (30, (0.19, 0.077, 0.14)), (34, (0.16, 0.12, 0.07)),
                   (38, FL), (44, FL)],
        "heel_l": [(0, 0), (3, 8), (5, -4), (6, 0), (30, 0), (33, 8), (37, 0)],
        "fyaw_l": [(0, 7), (6, 14), (30, 14), (38, 7)],
        "knee_l": [(0, "auto"), (4, (0.35, 0.1, 1.0)), (34, (0.35, 0.1, 1.0)), (38, "auto")],
        "foot_r": [(0, FR), (6, (-0.19, 0.077, -0.06)), (30, (-0.19, 0.077, -0.06)), (38, FR)],
        "fyaw_r": [(0, 7), (6, 18), (30, 18), (38, 7)],
        "knee_r": [(0, "auto"), (4, (-0.35, 0.1, 1.0)), (34, (-0.35, 0.1, 1.0)), (38, "auto")],
        "heel_r": [(0, 0), (15, 0), (19, 10), (27, 8), (34, 0)],
    },
    # the shield (Water Shield: ice wall, bubble, heal; Frost: ice patch, freeze water): the hands cross low before the belly,
    # the body sinking (held); they rise apart before the face, the forearms upright and the palms out, the stance widening.
    # strike_s: the palms up
    "water_shield": {
        "length": 36,
        "meta": {"hold_s": 6 / FPS, "strike_s": 10 / FPS, "back_s": 22 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.11, 0.0)), (10, (0.0, -0.08, 0.03)), (13, (0.0, -0.085, 0.035)),
                 (22, (0.0, -0.09, 0.03)), (30, (0.0, -0.035, 0.01)), (36, (0, -0.015, 0))],
        "hips": [(0, 0), (6, 8), (10, 2), (22, 3), (36, 0)],
        "chest": [(0, 0), (6, 10), (10, -2), (13, -3), (22, -1), (36, 0)],
        "head": [(0, 0), (6, 10), (10, 0), (36, 0)],
        "clav_r": [(0, (0, 0)), (6, (8, 6)), (10, (6, -10)), (13, (6, -12)), (22, (5, -10)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (8, 6)), (10, (6, -10)), (13, (6, -12)), (22, (5, -10)), (36, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.1, 0.92, 0.22)), (6, (0.04, 0.96, 0.28)), (8, (-0.02, 1.2, 0.36)), (10, (-0.22, 1.42, 0.36)),
                   (13, (-0.24, 1.45, 0.37)), (22, (-0.23, 1.43, 0.35)), (30, (-0.2, 1.05, 0.2)), (36, HR)],
        "hand_l": [(0, HL), (4, (0.1, 0.92, 0.24)), (6, (-0.04, 0.98, 0.31)), (8, (0.02, 1.22, 0.38)), (10, (0.22, 1.42, 0.36)),
                   (13, (0.24, 1.45, 0.37)), (22, (0.23, 1.43, 0.35)), (30, (0.2, 1.05, 0.2)), (36, HL)],
        "face_r": [(0, "stand"), (4, "palm_down"), (7, "guard"), (10, "push"), (24, "push"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "palm_down"), (7, "guard"), (10, "push"), (24, "push"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-1.0, -0.2, -0.2)), (10, (-0.8, -1.0, 0.0)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (1.0, -0.2, -0.2)), (10, (0.8, -1.0, 0.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.0), (9, -0.5), (26, -0.5), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, 0.0), (9, -0.5), (26, -0.5), (36, 0.4)],
        "foot_r": [(0, FR), (3, (-0.15, 0.12, -0.02)), (6, (-0.22, 0.077, -0.05)), (26, (-0.22, 0.077, -0.05)),
                   (30, (-0.18, 0.12, -0.04)), (33, FR), (36, FR)],
        "heel_r": [(0, 0), (3, 10), (6, 0), (26, 0), (29, 10), (32, 0)],
        "fyaw_r": [(0, 7), (6, 16), (26, 16), (33, 7)],
        "foot_l": [(0, FL), (6, (0.17, 0.077, 0.04)), (26, (0.17, 0.077, 0.04)), (33, FL)],
        "fyaw_l": [(0, 7), (6, 14), (26, 14), (33, 7)],
        "knee_r": [(0, "auto"), (6, (-0.4, 0.0, 1.0)), (28, (-0.4, 0.0, 1.0)), (32, "auto")],
        "knee_l": [(0, "auto"), (6, (0.4, 0.0, 1.0)), (28, (0.4, 0.0, 1.0)), (32, "auto")],
    },
    # ---------------------------------------------------------------- air (Baguazhang: circles, spins)
    # the palm strike (Air Palm: palm, trip, cushion): a short step in, the right palm drawn back by the shoulder, the left
    # hand out ahead (held); the palm driven out, the heel of the hand leading, the left drawn back.  strike_s: the palm out
    "air_palm": {
        "length": 28, "mirror": True,
        "meta": {"hold_s": 5 / FPS, "strike_s": 8 / FPS, "back_s": 16 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.05, 0.02)), (5, (0.0, -0.055, 0.02)), (8, (0.0, -0.07, 0.12)),
                 (11, (0.0, -0.075, 0.13)), (16, (0.0, -0.07, 0.12)), (23, (0.0, -0.03, 0.03)), (28, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -16), (8, 12), (11, 16), (16, 12), (28, 0)],
        "twist": [(0, 0), (5, -10), (8, 8), (11, 10), (16, 8), (28, 0)],
        "hips": [(0, 0), (5, 2), (8, 5), (11, 6), (16, 4), (28, 0)],
        "chest": [(0, 0), (5, 2), (8, 6), (11, 7), (16, 5), (28, 0)],
        "clav_r": [(0, (0, 0)), (5, (-8, -2)), (8, (14, -4)), (11, (16, -4)), (16, (12, -3)), (28, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, -4)), (8, (-4, 2)), (28, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.22, 1.1, 0.08)), (5, (-0.22, 1.24, 0.0)), (7, (-0.1, 1.26, 0.4)), (8, (-0.03, 1.24, 0.64)),
                   (11, (-0.025, 1.235, 0.64)), (16, (-0.04, 1.22, 0.6)), (23, (-0.18, 1.0, 0.2)), (28, HR)],
        "hand_l": [(0, HL), (3, (0.14, 1.18, 0.28)), (5, (0.1, 1.24, 0.36)), (8, (0.18, 1.08, 0.12)), (11, (0.19, 1.05, 0.06)),
                   (16, (0.19, 1.05, 0.07)), (28, HL)],
        "face_r": [(0, "stand"), (3, "push"), (16, "push"), (28, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (6, "push"), (9, "palm_down"), (18, "palm_down"), (28, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.6, -0.8, -0.6)), (8, (-0.8, -0.6, 0.0)), (28, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.6, -0.8, 0.0)), (9, (0.6, -0.6, -0.6)), (28, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.4), (20, -0.4), (28, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.4), (20, -0.2), (28, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.05)), (4, (0.14, 0.077, 0.22)), (20, (0.14, 0.077, 0.22)), (23, (0.13, 0.12, 0.09)),
                   (26, FL), (28, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 0), (20, 0), (22, 8), (25, 0)],
        "knee_l": [(0, "auto"), (2, (0.2, 0.2, 1.0)), (24, (0.2, 0.2, 1.0)), (26, "auto")],
        "foot_r": [(0, FR), (4, (-0.14, 0.077, -0.06)), (20, (-0.14, 0.077, -0.06)), (26, FR)],
        "fyaw_r": [(0, 7), (5, 28), (8, 36), (20, 34), (26, 7)],
        "heel_r": [(0, 0), (5, 4), (8, 16), (16, 14), (23, 0)],
    },
    # the circular sweep (Air Blast: ball, vacuum): both arms wound out to the right, the body turned with them (held); they
    # sweep round flat before the body in a big circle to the left, the palms pushing the air round, the body turning through.
    # strike_s: the palms across the front
    "air_sweep": {
        "length": 36,
        "meta": {"hold_s": 7 / FPS, "strike_s": 11 / FPS, "back_s": 22 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (7, (-0.03, -0.08, 0.0)), (11, (0.0, -0.1, 0.06)), (15, (0.03, -0.1, 0.05)),
                 (22, (0.03, -0.09, 0.04)), (30, (0.0, -0.035, 0.01)), (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (7, -30), (11, 0), (15, 28), (22, 24), (36, 0)],
        "twist": [(0, 0), (7, -20), (11, 0), (15, 18), (22, 14), (36, 0)],
        "hips": [(0, 0), (7, 4), (11, 6), (15, 4), (36, 0)],
        "chest": [(0, 0), (7, 4), (11, 7), (15, 4), (36, 0)],
        "side": [(0, 0), (7, -4), (11, 0), (15, 4), (36, 0)],
        "clav_r": [(0, (0, 0)), (7, (-8, -6)), (11, (10, -8)), (15, (14, -4)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (7, (12, -6)), (11, (10, -8)), (15, (-6, -6)), (36, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.32, 1.1, 0.1)), (7, (-0.46, 1.22, 0.05)), (9, (-0.38, 1.25, 0.4)), (11, (-0.09, 1.25, 0.55)),
                   (13, (0.14, 1.22, 0.5)), (15, (0.2, 1.2, 0.3)), (22, (0.2, 1.18, 0.28)), (30, (-0.18, 0.98, 0.18)), (36, HR)],
        "hand_l": [(0, HL), (4, (0.02, 1.12, 0.3)), (7, (-0.14, 1.22, 0.38)), (9, (0.06, 1.25, 0.52)), (11, (0.3, 1.25, 0.52)),
                   (13, (0.45, 1.22, 0.3)), (15, (0.46, 1.2, 0.08)), (22, (0.45, 1.18, 0.07)), (30, (0.2, 0.98, 0.18)), (36, HL)],
        "face_r": [(0, "stand"), (4, "sweep_out"), (8, "sweep_out"), (11, "push"), (14, "sweep_in"), (24, "sweep_in"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "sweep_in"), (8, "sweep_in"), (11, "push"), (14, "sweep_out"), (24, "sweep_out"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (7, (-0.3, -1.0, -0.5)), (11, (-0.6, -1.0, 0.0)), (15, (-0.2, -1.0, 0.0)),
                   (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (7, (0.2, -1.0, 0.0)), (11, (0.6, -1.0, 0.0)), (15, (0.3, -1.0, -0.5)),
                   (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.4), (26, -0.4), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.4), (26, -0.4), (36, 0.4)],
        "foot_r": [(0, FR), (7, (-0.18, 0.077, -0.04)), (28, (-0.18, 0.077, -0.04)), (33, FR)],
        "fyaw_r": [(0, 7), (7, 30), (11, 14), (15, 0), (28, 0), (33, 7)],
        "heel_r": [(0, 0), (11, 0), (15, 12), (22, 10), (28, 0)],
        "foot_l": [(0, FL), (7, (0.18, 0.077, 0.04)), (28, (0.18, 0.077, 0.04)), (33, FL)],
        "fyaw_l": [(0, 7), (7, 0), (11, 12), (15, 28), (28, 26), (33, 7)],
        "heel_l": [(0, 0), (4, 6), (7, 10), (11, 0), (36, 0)],
    },
    # the spin (Evade: spin; Air Shield: cyclone, tornado): a little sink, the arms gathered and the body wound the other way
    # (held); a whole turn to the left on the balls of the feet, the arms flung out wide; settled facing the mark again.
    # strike_s: the turn under way
    "air_spin": {
        "length": 36,
        "meta": {"hold_s": 5 / FPS, "strike_s": 8 / FPS, "back_s": 20 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "spin": [(0, 0), (5, -20), (8, 70), (11, 190), (14, 300), (17, 360), (36, 360)],
        "root": [(0, (0, -0.015, 0)), (5, (0.0, -0.09, 0.0)), (8, (0.0, -0.05, 0.0)), (12, (0.0, -0.03, 0.0)), (17, (0.0, -0.08, 0.0)),
                 (20, (0.0, -0.09, 0.0)), (28, (0.0, -0.035, 0.0)), (36, (0, -0.015, 0))],
        "hips": [(0, 0), (5, 6), (8, 2), (14, 2), (17, 5), (36, 0)],
        "chest": [(0, 0), (5, 8), (8, -2), (14, -2), (17, 4), (36, 0)],
        "twist": [(0, 0), (5, 14), (8, -10), (11, -14), (14, -8), (17, 4), (22, 0), (36, 0)],
        "head": [(0, 0), (5, 4), (8, -2), (36, 0)],
        "clav_r": [(0, (0, 0)), (5, (8, 4)), (8, (0, -8)), (14, (0, -8)), (18, (2, 0)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, 4)), (8, (0, -8)), (14, (0, -8)), (18, (2, 0)), (36, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.08, 1.05, 0.25)), (8, (-0.44, 1.28, 0.08)), (11, (-0.48, 1.3, 0.02)), (14, (-0.47, 1.28, 0.02)),
                   (17, (-0.32, 1.12, 0.2)), (20, (-0.3, 1.08, 0.22)), (28, (-0.2, 0.92, 0.12)), (36, HR)],
        "hand_l": [(0, HL), (5, (0.08, 1.08, 0.28)), (8, (0.44, 1.28, 0.08)), (11, (0.48, 1.3, 0.02)), (14, (0.47, 1.28, 0.02)),
                   (17, (0.32, 1.12, 0.2)), (20, (0.3, 1.08, 0.22)), (28, (0.2, 0.92, 0.12)), (36, HL)],
        "face_r": [(0, "stand"), (4, "palm_down"), (7, "arms_out"), (15, "arms_out"), (18, "push"), (24, "push"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "palm_down"), (7, "arms_out"), (15, "arms_out"), (18, "push"), (24, "push"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-1.0, -0.4, -0.2)), (8, (0.0, -0.4, -1.0)), (16, (0.0, -0.4, -1.0)),
                   (18, (-0.8, -0.6, 0.0)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (1.0, -0.4, -0.2)), (8, (0.0, -0.4, -1.0)), (16, (0.0, -0.4, -1.0)),
                   (18, (0.8, -0.6, 0.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.3), (24, -0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.3), (24, -0.3), (36, 0.4)],
        "foot_r": [(0, FR), (36, FR)], "foot_l": [(0, FL), (36, FL)],
        "heel_r": [(0, 0), (5, 0), (7, 22), (15, 22), (18, 0), (36, 0)],
        "heel_l": [(0, 0), (5, 0), (7, 22), (15, 22), (18, 0), (36, 0)],
        "knee_r": [(0, "auto"), (5, (-0.3, 0.0, 1.0)), (20, (-0.3, 0.0, 1.0)), (28, "auto")],
        "knee_l": [(0, "auto"), (5, (0.3, 0.0, 1.0)), (20, (0.3, 0.0, 1.0)), (28, "auto")],
    },
    # the leap (Air Jump: leap, dash; Fire Jets; Footwork; Wind Run: updraft): a deep crouch, the arms swung back low (held);
    # the spring: the legs drive straight up onto the toes and the arms swing up overhead; off the ground the knees draw up a
    # little, the toes pointed; down to the stand.  strike_s: the spring
    "air_leap": {
        "length": 32,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 20 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.18, 0.02)), (6, (0.0, -0.26, 0.03)), (9, (0.0, 0.0, 0.04)),
                 (11, (0.0, 0.04, 0.04)), (14, (0.0, 0.05, 0.03)), (20, (0.0, -0.02, 0.02)), (24, (0.0, -0.1, 0.02)),
                 (32, (0, -0.015, 0))],
        "hips": [(0, 0), (4, 16), (6, 24), (9, 2), (11, -4), (14, 4), (20, 6), (24, 10), (32, 0)],
        "chest": [(0, 0), (4, 14), (6, 20), (9, -2), (11, -6), (14, 0), (20, 2), (24, 6), (32, 0)],
        "head": [(0, 0), (6, -16), (9, -10), (11, -8), (20, 0), (32, 0)],
        "clav_r": [(0, (0, 0)), (6, (-8, 6)), (9, (6, -20)), (11, (6, -24)), (16, (4, -10)), (24, (4, 0)), (32, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (-8, 6)), (9, (6, -20)), (11, (6, -24)), (16, (4, -10)), (24, (4, 0)), (32, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.24, 0.73, -0.02)), (6, (-0.235, 0.66, -0.155)), (8, (-0.22, 1.0, 0.26)), (9, (-0.2, 1.42, 0.28)),
                   (11, (-0.2, 1.74, 0.16)), (14, (-0.24, 1.6, 0.16)), (20, (-0.3, 1.25, 0.2)), (24, (-0.25, 0.95, 0.25)), (32, HR)],
        "hand_l": [(0, HL), (4, (0.24, 0.73, -0.02)), (6, (0.235, 0.66, -0.155)), (8, (0.22, 1.0, 0.26)), (9, (0.2, 1.42, 0.28)),
                   (11, (0.2, 1.74, 0.16)), (14, (0.24, 1.6, 0.16)), (20, (0.3, 1.25, 0.2)), (24, (0.25, 0.95, 0.25)), (32, HL)],
        "face_r": [(0, "stand"), (4, "flick_back"), (7, "flick_back"), (9, "fist_up"), (13, "fist_up"), (18, "brace"), (24, "brace"),
                   (32, "stand")],
        "face_l": [(0, "stand"), (4, "flick_back"), (7, "flick_back"), (9, "fist_up"), (13, "fist_up"), (18, "brace"), (24, "brace"),
                   (32, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.4, 0.4, -1.0)), (9, (-1.0, -0.2, 0.0)), (20, (-0.8, -0.4, -0.3)),
                   (32, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.4, 0.4, -1.0)), (9, (1.0, -0.2, 0.0)), (20, (0.8, -0.4, -0.3)),
                   (32, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.3), (20, -0.3), (32, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.3), (20, -0.3), (32, 0.4)],
        # the feet: down through the crouch and onto the toes at the spring; off the ground the toes pointed and the knees
        # drawn up a little; reaching down for the stand
        "foot_r": [(0, FR), (9, FR), (12, (-0.13, 0.16, 0.03)), (15, (-0.13, 0.2, 0.06)), (19, (-0.13, 0.12, 0.02)), (21, FR),
                   (32, FR)],
        "foot_l": [(0, FL), (9, FL), (12, (0.13, 0.14, 0.01)), (15, (0.13, 0.22, 0.08)), (19, (0.13, 0.13, 0.03)), (21, FL),
                   (32, FL)],
        "heel_r": [(0, 0), (6, 0), (9, 40), (12, 45), (17, 35), (21, 0), (32, 0)],
        "heel_l": [(0, 0), (6, 0), (9, 40), (12, 45), (17, 35), (21, 0), (32, 0)],
        "knee_r": [(0, "auto"), (4, (-0.35, 0.0, 1.0)), (26, (-0.35, 0.0, 1.0)), (30, "auto")],
        "knee_l": [(0, "auto"), (4, (0.35, 0.0, 1.0)), (26, (0.35, 0.0, 1.0)), (30, "auto")],
        "fyaw_r": [(0, 7), (6, 14), (12, 7), (32, 7)], "fyaw_l": [(0, 7), (6, 14), (12, 7), (32, 7)],
    },
    # the shield circle (Air Shield: shield): the palms circle up and round before the body - down and in, out wide, up over
    # the head - meeting at the top (held); then pushed out forward and apart, the air standing as a wall.  strike_s: the
    # palms out
    "air_shield": {
        "length": 38,
        "meta": {"hold_s": 9 / FPS, "strike_s": 13 / FPS, "back_s": 24 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.07, 0.0)), (9, (0.0, -0.04, -0.02)), (13, (0.0, -0.09, 0.08)),
                 (16, (0.0, -0.1, 0.09)), (24, (0.0, -0.09, 0.08)), (31, (0.0, -0.035, 0.02)), (38, (0, -0.015, 0))],
        "hips": [(0, 0), (4, 6), (9, -2), (13, 5), (16, 6), (24, 5), (38, 0)],
        "chest": [(0, 0), (4, 7), (9, -6), (13, 6), (16, 8), (24, 6), (38, 0)],
        "head": [(0, 0), (4, 4), (9, -8), (13, -2), (38, 0)],
        "clav_r": [(0, (0, 0)), (4, (6, 4)), (7, (0, -14)), (9, (2, -22)), (13, (14, -6)), (24, (11, -5)), (38, (0, 0))],
        "clav_l": [(0, (0, 0)), (4, (6, 4)), (7, (0, -14)), (9, (2, -22)), (13, (14, -6)), (24, (11, -5)), (38, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.08, 0.95, 0.24)), (5, (-0.4, 1.1, 0.2)), (7, (-0.36, 1.48, 0.18)), (9, (-0.085, 1.665, 0.23)),
                   (11, (-0.16, 1.48, 0.42)), (13, (-0.222, 1.322, 0.57)), (16, (-0.225, 1.31, 0.58)), (24, (-0.22, 1.28, 0.55)),
                   (31, (-0.2, 1.0, 0.2)), (38, HR)],
        "hand_l": [(0, HL), (3, (0.08, 0.95, 0.24)), (5, (0.4, 1.1, 0.2)), (7, (0.36, 1.48, 0.18)), (9, (0.085, 1.665, 0.23)),
                   (11, (0.16, 1.48, 0.42)), (13, (0.222, 1.322, 0.57)), (16, (0.225, 1.31, 0.58)), (24, (0.22, 1.28, 0.55)),
                   (31, (0.2, 1.0, 0.2)), (38, HL)],
        "face_r": [(0, "stand"), (3, "palm_down"), (5, "arms_out"), (7, "palm_up_wide"), (9, "fist_up"), (12, "push"), (26, "push"),
                   (38, "stand")],
        "face_l": [(0, "stand"), (3, "palm_down"), (5, "arms_out"), (7, "palm_up_wide"), (9, "fist_up"), (12, "push"), (26, "push"),
                   (38, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.2, -1.0, -0.6)), (9, (-1.0, 0.0, 0.0)), (13, (-0.9, -0.6, 0.0)),
                   (38, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.2, -1.0, -0.6)), (9, (1.0, 0.0, 0.0)), (13, (0.9, -0.6, 0.0)),
                   (38, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.3), (28, -0.4), (38, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.3), (28, -0.4), (38, 0.4)],
        "foot_l": [(0, FL), (10, FL), (11, (0.14, 0.12, 0.08)), (13, (0.15, 0.077, 0.2)), (28, (0.15, 0.077, 0.2)),
                   (31, (0.14, 0.12, 0.08)), (34, FL), (38, FL)],
        "heel_l": [(0, 0), (10, 0), (11, 8), (12, -4), (13, 0), (28, 0), (30, 8), (33, 0)],
        "foot_r": [(0, FR), (13, (-0.15, 0.077, -0.06)), (28, (-0.15, 0.077, -0.06)), (34, FR)],
        "fyaw_r": [(0, 7), (13, 28), (28, 28), (34, 7)],
        "heel_r": [(0, 0), (13, 8), (24, 6), (32, 0)],
    },
}
CLIPS.update(SET2)

## ---------------------------------------------------------------- the third set (2026-10-05, round 2 of the skills: the moves
## the new kits need; authored the same way, key poses typed here, nothing read). Northern Shaolin (fire), Hung Gar (earth), tai
## chi (water) and Baguazhang (air) are style labels for the typed poses, as above.
FACING.update({
    "lift_out": ((-0.35, 0.45, 0.82), (-0.15, 0.85, -0.5)),    # the uproot's palms flung up and out, the palms up and back
    "knife_up": ((0.0, 0.97, 0.22), (0.97, 0.0, -0.2)),        # the parry's knife hand stood up before the face, the palm in
    "bagua": ((-0.2, 0.95, 0.2), (0.92, 0.1, 0.38)),           # a circle walker's lead palm out at the side, turned in to the centre
    "slice_back": ((0.55, 0.25, -0.8), (0.0, -0.95, -0.3)),    # the slice's hand cocked back by the ear, the palm down
    "slice": ((0.45, 0.0, 0.89), (0.0, -1.0, 0.0)),            # the slice out flat, the palm down, the fingers ahead and across
})


def _ring(frames, fn):
    """A loop's keys round a circle: fn(angle in radians) at each of `frames` (the first's again at the last, the seam)."""
    n = len(frames) - 1
    return [(fr, fn(2 * math.pi * (i % n) / n)) for i, fr in enumerate(frames)]


def EIGHTHS(length):
    """A loop's nine key frames: its eighths, the seam's frame last."""
    return [length * i // 8 for i in range(9)]


def _r3(v):
    return tuple(round(x, 4) for x in v)


SET3 = {
    # the low kick (the Kick: the floor wave; the tell the opponent reads, so the chamber is LOW): sunk deep onto the bent left
    # leg, the body bowed forward and coiled to the right, the right foot drawn far back behind just off the deck, the fists
    # up (held); the foot sweeps out wide round and in, forward and across, the leg long and the sole skimming the deck at the
    # shin's height (a crescent along the floor), the body turning through low over the standing knee; set down ahead into a
    # low bow stance.  strike_s: the foot across the front
    "fire_kick_low": {
        "length": 32, "mirror": True,
        "meta": {"hold_s": 6 / FPS, "strike_s": 9 / FPS, "back_s": 20 / FPS, "hand": "foot_r", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, (0, -0.015, 0)), (3, (0.05, -0.12, -0.03)), (6, (0.08, -0.25, -0.06)), (9, (0.05, -0.26, 0.0)),
                 (12, (0.02, -0.25, 0.08)), (15, (0.0, -0.22, 0.16)), (20, (0.0, -0.215, 0.155)), (27, (0.0, -0.07, 0.04)),
                 (32, (0, -0.015, 0))],
        "yaw": [(0, 0), (6, -18), (9, 12), (12, 20), (15, 10), (20, 8), (32, 0)],
        "twist": [(0, 0), (6, -12), (9, 10), (12, 14), (20, 6), (32, 0)],
        "hips": [(0, 0), (6, 20), (9, 2), (12, 6), (15, 12), (20, 11), (32, 0)],
        "chest": [(0, 0), (6, 12), (9, 8), (15, 8), (20, 6), (32, 0)],
        "roll": [(0, 0), (6, -5), (9, 4), (15, 0), (32, 0)],
        "side": [(0, 0), (6, 8), (9, 4), (15, 0), (32, 0)],
        "head": [(0, 0), (6, -14), (9, -10), (15, -8), (20, -7), (32, 0)],
        "clav_r": [(0, (0, 0)), (6, (6, -2)), (9, (-10, 6)), (15, (10, -2)), (20, (8, -2)), (32, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (10, -2)), (9, (14, -3)), (15, (8, -2)), (20, (6, -2)), (32, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.15, 1.04, 0.16)), (6, (-0.16, 0.98, 0.22)), (9, (-0.34, 0.8, -0.08)), (12, (-0.28, 0.84, 0.0)),
                   (15, (-0.17, 0.94, 0.14)), (20, (-0.17, 0.94, 0.14)), (27, (-0.18, 0.9, 0.12)), (32, HR)],
        "hand_l": [(0, HL), (3, (0.1, 1.1, 0.3)), (6, (0.05, 1.04, 0.4)), (9, (0.03, 1.02, 0.44)), (12, (0.05, 1.03, 0.44)),
                   (15, (0.07, 1.05, 0.44)), (20, (0.07, 1.05, 0.43)), (27, (0.16, 0.94, 0.16)), (32, HL)],
        "face_r": [(0, "stand"), (3, "fist_guard"), (7, "fist_guard"), (9, "fist_low"), (13, "chamber"), (22, "chamber"),
                   (32, "stand")],
        "face_l": [(0, "stand"), (3, "fist_guard"), (22, "fist_guard"), (32, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.5, -1.0, -0.2)), (9, (-1.0, -0.2, 0.2)), (15, (-0.3, -0.5, -1.0)),
                   (32, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.4, -1.0, -0.2)), (32, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, 1.0), (26, 1.0), (32, 0.4)],
        "grip_l": [(0, 0.4), (3, 1.0), (26, 1.0), (32, 0.4)],
        # the right foot: drawn far back off the deck behind, round out wide to the side, forward and in across the front at
        # the shin's height, its sole just over the deck; set down ahead in the bow stance; back in at the end
        "foot_r": [(0, FR), (3, (-0.16, 0.1, -0.16)), (6, (-0.2, 0.13, -0.36)), (7, (-0.4, 0.13, -0.12)),
                   (8, (-0.38, 0.13, 0.26)), (9, (-0.105, 0.1, 0.57)), (10, (0.03, 0.12, 0.53)), (12, (0.01, 0.125, 0.44)),
                   (14, (-0.09, 0.1, 0.42)), (15, (-0.12, 0.077, 0.41)), (24, (-0.12, 0.077, 0.41)), (27, (-0.13, 0.13, 0.19)),
                   (30, FR), (32, FR)],
        "heel_r": [(0, 0), (3, 18), (6, 34), (8, 4), (9, -12), (12, -6), (15, 0), (24, 0), (26, 12), (29, 0), (32, 0)],
        "fyaw_r": [(0, 7), (6, 20), (8, 0), (9, -30), (12, -22), (15, 8), (24, 8), (30, 7)],
        "knee_r": [(0, "auto"), (3, (-0.2, -0.3, 1.0)), (6, (-0.3, -0.8, 0.5)), (7, (-0.7, 0.2, 1.0)), (10, (-0.3, 0.4, 1.0)),
                   (15, (-0.15, 0.1, 1.0)), (27, (-0.15, 0.1, 1.0)), (30, "auto")],
        "foot_l": [(0, FL), (32, FL)],
        "fyaw_l": [(0, 7), (6, 16), (9, 26), (15, 32), (24, 32), (30, 7)],
        "heel_l": [(0, 0), (9, 4), (15, 16), (22, 14), (28, 0), (32, 0)],
        "knee_l": [(0, "auto"), (3, (0.35, 0.0, 1.0)), (26, (0.35, 0.0, 1.0)), (30, "auto")],
    },
    # the Fireball (Punch held to grow it): a deeper chamber than the punch's: the body coiled hard to the right and sunk back on
    # the rear leg, the right hand drawn far back by the hip cupping the fire, the left palm out ahead aiming (held while it
    # grows); the hips snap through, a long step's bow stance and the palm driven out at the shoulder's height, the left
    # pulled back to the ribs.  strike_s: the palm out
    "fire_fireball": {
        "length": 36, "mirror": True,
        "meta": {"hold_s": 8 / FPS, "strike_s": 11 / FPS, "back_s": 22 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (0.0, -0.08, -0.02)), (8, (0.02, -0.15, -0.08)), (11, (0.0, -0.13, 0.15)),
                 (14, (0.0, -0.14, 0.17)), (22, (0.0, -0.13, 0.15)), (29, (0.0, -0.05, 0.04)), (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (4, -16), (8, -34), (11, 18), (14, 22), (22, 18), (36, 0)],
        "twist": [(0, 0), (4, -10), (8, -20), (11, 14), (14, 16), (22, 12), (36, 0)],
        "hips": [(0, 0), (8, 2), (11, 9), (14, 10), (22, 8), (36, 0)],
        "chest": [(0, 0), (8, 0), (11, 10), (14, 12), (22, 9), (36, 0)],
        "side": [(0, 0), (8, 4), (11, -2), (22, -1), (36, 0)],
        "head": [(0, 0), (8, 1), (11, -3), (36, 0)],
        "clav_r": [(0, (0, 0)), (8, (-14, 4)), (11, (18, -4)), (14, (20, -4)), (22, (16, -3)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (8, (10, -2)), (11, (-6, 2)), (22, (-4, 2)), (36, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.2, 1.0, 0.0)), (8, (-0.26, 0.98, -0.24)), (10, (-0.12, 1.22, 0.33)), (11, (-0.025, 1.32, 0.74)),
                   (14, (-0.025, 1.32, 0.745)), (22, (-0.035, 1.3, 0.71)), (29, (-0.18, 1.0, 0.2)), (36, HR)],
        "hand_l": [(0, HL), (4, (0.12, 1.18, 0.3)), (8, (0.08, 1.3, 0.47)), (11, (0.19, 1.05, 0.04)), (14, (0.19, 1.03, 0.0)),
                   (22, (0.19, 1.03, 0.01)), (29, (0.18, 0.92, 0.1)), (36, HL)],
        "face_r": [(0, "stand"), (3, "chamber"), (9, "chamber"), (11, "push"), (24, "push"), (36, "stand")],
        "face_l": [(0, "stand"), (4, "fist_guard"), (7, "push"), (9, "push"), (11, "chamber"), (24, "chamber"), (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (8, (-0.6, -0.6, -0.6)), (11, (-0.8, -0.6, -0.1)), (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (8, (0.5, -0.8, -0.3)), (11, (0.3, -0.5, -1.0)), (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, 0.3), (9, 0.3), (11, -0.3), (26, -0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (4, 0.6), (7, -0.3), (10, 1.0), (26, 1.0), (36, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.04)), (5, (0.15, 0.077, 0.28)), (27, (0.15, 0.077, 0.28)), (30, (0.14, 0.12, 0.1)),
                   (34, FL), (36, FL)],
        "heel_l": [(0, 0), (2, 8), (4, -4), (5, 0), (27, 0), (29, 8), (33, 0)],
        "knee_l": [(0, "auto"), (2, (0.25, 0.2, 1.0)), (31, (0.25, 0.2, 1.0)), (34, "auto")],
        "foot_r": [(0, FR), (5, (-0.16, 0.077, -0.12)), (28, (-0.16, 0.077, -0.12)), (34, FR)],
        "fyaw_r": [(0, 7), (5, 30), (8, 50), (11, 40), (28, 40), (34, 7)],
        "heel_r": [(0, 0), (8, 0), (11, 26), (14, 30), (22, 24), (30, 0)],
        "knee_r": [(0, "auto"), (5, (-0.5, 0.0, 1.0)), (28, (-0.5, 0.0, 1.0)), (32, "auto")],
    },
    # the Parry (fire's guard): side-on, the left fist chambered at the ribs, the right forearm stood up before the face with
    # the knife hand's edge to the shot (held: the window); the knife hand cuts down and out straight ahead along the aim, the
    # arm long, the body snapping round behind it (the shot sent back).  strike_s: the knife hand out ahead
    "fire_parry": {
        "length": 30,
        "meta": {"hold_s": 4 / FPS, "strike_s": 8 / FPS, "back_s": 16 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (2, (0.0, -0.06, 0.0)), (4, (0.0, -0.09, -0.04)), (8, (0.0, -0.12, 0.12)),
                 (11, (0.0, -0.125, 0.13)), (16, (0.0, -0.12, 0.12)), (24, (0.0, -0.04, 0.02)), (30, (0, -0.015, 0))],
        "yaw": [(0, 0), (4, -24), (8, 16), (11, 20), (16, 16), (30, 0)],
        "twist": [(0, 0), (4, -14), (8, 12), (11, 14), (16, 11), (30, 0)],
        "hips": [(0, 0), (4, -2), (8, 8), (16, 6), (30, 0)],
        "chest": [(0, 0), (4, -4), (8, 10), (11, 11), (16, 8), (30, 0)],
        "side": [(0, 0), (4, 4), (8, -3), (16, -2), (30, 0)],
        "head": [(0, 0), (4, -2), (8, -3), (30, 0)],
        "clav_r": [(0, (0, 0)), (4, (2, -8)), (8, (16, -4)), (11, (18, -4)), (16, (14, -3)), (30, (0, 0))],
        "clav_l": [(0, (0, 0)), (4, (-6, 2)), (8, (-6, 2)), (16, (-4, 2)), (30, (0, 0))],
        "hand_r": [(0, HR), (2, (-0.16, 1.28, 0.24)), (4, (-0.06, 1.45, 0.22)), (6, (-0.07, 1.38, 0.42)), (8, (-0.035, 1.31, 0.72)),
                   (11, (-0.03, 1.31, 0.72)), (16, (-0.04, 1.29, 0.68)), (24, (-0.18, 1.0, 0.2)), (30, HR)],
        "hand_l": [(0, HL), (2, (0.17, 1.06, 0.08)), (4, (0.19, 1.04, 0.03)), (8, (0.19, 1.04, 0.03)), (16, (0.19, 1.04, 0.04)),
                   (24, (0.18, 0.92, 0.1)), (30, HL)],
        "face_r": [(0, "stand"), (2, "knife_up"), (5, "knife_up"), (8, "knife"), (18, "knife"), (30, "stand")],
        "face_l": [(0, "stand"), (2, "chamber"), (18, "chamber"), (30, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (4, (-0.3, -1.0, 0.3)), (8, (-0.5, -1.0, 0.0)), (30, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (4, (0.3, -0.5, -1.0)), (30, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (2, -0.5), (22, -0.5), (30, 0.4)],
        "grip_l": [(0, 0.4), (2, 1.0), (24, 1.0), (30, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.05)), (4, (0.14, 0.077, 0.22)), (20, (0.14, 0.077, 0.22)), (23, (0.13, 0.12, 0.08)),
                   (27, FL), (30, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 0), (20, 0), (22, 8), (26, 0)],
        "knee_l": [(0, "auto"), (2, (0.2, 0.2, 1.0)), (24, (0.2, 0.2, 1.0)), (27, "auto")],
        "foot_r": [(0, FR), (4, (-0.15, 0.077, -0.1)), (22, (-0.15, 0.077, -0.1)), (27, FR)],
        "fyaw_r": [(0, 7), (4, 40), (8, 36), (22, 36), (27, 7)],
        "heel_r": [(0, 0), (4, 4), (8, 24), (16, 18), (24, 0)],
    },
    # ---------------------------------------------------------------- earth
    # the kick-up (Shove's kick-and-push: the stone kicked up off the deck, the push after it): the boulder's kick mirrored and
    # short: the weight onto the left leg, the right foot lifts (held), and kicks up and forward, the toes up under the stone,
    # the palms rising to the ribs ready to push; set down a little ahead.  strike_s: the toes at the top
    "earth_kickup": {
        "length": 18, "mirror": True,
        "meta": {"hold_s": 3 / FPS, "strike_s": 6 / FPS, "back_s": 10 / FPS, "hand": "foot_r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (3, (0.05, -0.04, -0.01)), (6, (0.065, -0.03, -0.03)), (9, (0.05, -0.05, 0.0)),
                 (11, (0.02, -0.09, 0.05)), (14, (0.01, -0.06, 0.02)), (18, (0, -0.015, 0))],
        "yaw": [(0, 0), (3, -3), (6, -5), (11, 3), (18, 0)],
        "roll": [(0, 0), (3, -4), (6, -5), (9, -3), (11, 0), (18, 0)],
        "hips": [(0, 0), (3, -3), (6, -7), (9, -2), (11, 5), (14, 3), (18, 0)],
        "chest": [(0, 0), (3, -4), (6, -6), (9, -2), (11, 5), (14, 3), (18, 0)],
        "side": [(0, 0), (3, 3), (6, 4), (11, 0), (18, 0)],
        "head": [(0, 0), (3, 6), (6, 8), (9, 4), (11, 0), (18, 0)],
        "clav_r": [(0, (0, 0)), (6, (2, -6)), (10, (-6, 4)), (18, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (2, -6)), (10, (-6, 4)), (18, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.2, 0.9, 0.16)), (6, (-0.17, 1.06, 0.28)), (10, (-0.18, 1.03, -0.02)), (14, (-0.19, 0.92, 0.04)),
                   (18, HR)],
        "hand_l": [(0, HL), (3, (0.2, 0.9, 0.16)), (6, (0.17, 1.06, 0.28)), (10, (0.18, 1.03, -0.02)), (14, (0.19, 0.92, 0.04)),
                   (18, HL)],
        "face_r": [(0, "stand"), (3, "chamber"), (14, "chamber"), (18, "stand")],
        "face_l": [(0, "stand"), (3, "chamber"), (14, "chamber"), (18, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.8, -0.6, -0.4)), (10, (-0.3, -0.4, -1.0)), (18, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.8, -0.6, -0.4)), (10, (0.3, -0.4, -1.0)), (18, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.2), (12, -0.2), (18, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.2), (12, -0.2), (18, 0.4)],
        "foot_r": [(0, FR), (2, (-0.14, 0.11, 0.0)), (3, (-0.14, 0.15, 0.07)), (5, (-0.155, 0.3, 0.42)), (6, (-0.16, 0.37, 0.53)),
                   (8, (-0.15, 0.3, 0.38)), (10, (-0.145, 0.15, 0.2)), (11, (-0.14, 0.077, 0.12)), (13, (-0.14, 0.077, 0.12)),
                   (15, (-0.135, 0.11, 0.03)), (17, FR), (18, FR)],
        "heel_r": [(0, 0), (2, 14), (3, 4), (5, -18), (6, -26), (8, -14), (10, -4), (11, 0), (13, 0), (14, 10), (16, 0), (18, 0)],
        "fyaw_r": [(0, 7), (6, 0), (11, 7), (18, 7)],
        "knee_r": [(0, "auto"), (2, (-0.15, 0.3, 1.0)), (13, (-0.15, 0.3, 1.0)), (16, "auto")],
        "foot_l": [(0, FL), (18, FL)],
        "fyaw_l": [(0, 7), (6, 12), (12, 9), (18, 7)],
        "knee_l": [(0, "auto"), (3, (0.3, 0.0, 1.0)), (12, (0.3, 0.0, 1.0)), (16, "auto")],
    },
    # the uproot (Column): the left knee up and the foot stamped down ahead into a deep bow stance, the body bowed down over it
    # with both palms pressed flat by the deck (held: the stone gripped under it); then the palms sweep up and out, wide apart
    # and far ahead, the fingers at the mark, the body rising behind them (the column torn up out at range); held up there.
    # Unlike the raise (the wall: the right foot stamped out wide, the palms rising close before the chest), it reaches out.
    # strike_s: the palms up and out
    "earth_uproot": {
        "length": 42, "meta": {"hold_s": 10 / FPS, "strike_s": 14 / FPS, "back_s": 26 / FPS, "hand": "both", "mask": "full",
                               "root": "place"},
        "root": [(0, (0, -0.015, 0)), (4, (-0.04, -0.03, -0.02)), (8, (0.0, -0.2, 0.12)), (10, (0.0, -0.235, 0.12)),
                 (14, (0.0, -0.11, 0.19)), (17, (0.0, -0.09, 0.21)), (26, (0.0, -0.1, 0.19)), (34, (0.0, -0.04, 0.05)),
                 (42, (0, -0.015, 0))],
        "roll": [(0, 0), (4, -4), (8, 0), (42, 0)],
        "hips": [(0, 0), (4, -4), (8, 20), (10, 24), (14, 6), (17, 4), (26, 4), (42, 0)],
        "chest": [(0, 0), (4, -6), (8, 16), (10, 20), (14, -3), (17, -7), (26, -5), (42, 0)],
        "head": [(0, 0), (4, 4), (8, -10), (10, -16), (14, -6), (17, -9), (26, -7), (42, 0)],
        "clav_r": [(0, (0, 0)), (4, (-4, 4)), (8, (10, 10)), (10, (10, 12)), (14, (8, -12)), (17, (8, -18)), (26, (6, -14)),
                   (42, (0, 0))],
        "clav_l": [(0, (0, 0)), (4, (-4, 4)), (8, (10, 10)), (10, (10, 12)), (14, (8, -12)), (17, (8, -18)), (26, (6, -14)),
                   (42, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.2, 1.04, 0.06)), (8, (-0.24, 0.6, 0.38)), (10, (-0.24, 0.56, 0.42)), (12, (-0.3, 0.88, 0.58)),
                   (14, (-0.355, 1.31, 0.63)), (17, (-0.36, 1.42, 0.555)), (26, (-0.345, 1.39, 0.535)), (34, (-0.22, 1.0, 0.22)), (42, HR)],
        "hand_l": [(0, HL), (4, (0.2, 1.04, 0.06)), (8, (0.24, 0.6, 0.38)), (10, (0.24, 0.56, 0.42)), (12, (0.3, 0.88, 0.58)),
                   (14, (0.355, 1.31, 0.63)), (17, (0.36, 1.42, 0.555)), (26, (0.345, 1.39, 0.535)), (34, (0.22, 1.0, 0.22)), (42, HL)],
        "face_r": [(0, "stand"), (4, "chamber"), (7, "press_down"), (11, "press_down"), (14, "lift_out"), (28, "lift_out"),
                   (42, "stand")],
        "face_l": [(0, "stand"), (4, "chamber"), (7, "press_down"), (11, "press_down"), (14, "lift_out"), (28, "lift_out"),
                   (42, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (8, (-1.0, 0.3, -0.2)), (14, (-0.8, -0.6, 0.0)), (42, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (8, (1.0, 0.3, -0.2)), (14, (0.8, -0.6, 0.0)), (42, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, 0.0), (7, -0.4), (11, -0.2), (14, -0.5), (30, -0.5), (42, 0.4)],
        "grip_l": [(0, 0.4), (4, 0.0), (7, -0.4), (11, -0.2), (14, -0.5), (30, -0.5), (42, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.2, 0.06)), (5, (0.15, 0.3, 0.16)), (8, (0.17, 0.077, 0.38)), (30, (0.17, 0.077, 0.38)),
                   (34, (0.15, 0.14, 0.16)), (38, FL), (42, FL)],
        "heel_l": [(0, 0), (3, 12), (5, -8), (7, -3), (8, 0), (30, 0), (33, 10), (37, 0), (42, 0)],
        "fyaw_l": [(0, 7), (8, 6), (30, 6), (38, 7)],
        "knee_l": [(0, "auto"), (2, (0.15, 0.3, 1.0)), (34, (0.15, 0.3, 1.0)), (38, "auto")],
        "foot_r": [(0, FR), (8, (-0.15, 0.077, -0.1)), (30, (-0.15, 0.077, -0.1)), (38, FR)],
        "fyaw_r": [(0, 7), (8, 30), (30, 30), (38, 7)],
        "heel_r": [(0, 0), (10, 0), (14, 10), (26, 8), (34, 0), (42, 0)],
        "knee_r": [(0, "auto"), (8, (-0.4, 0.0, 1.0)), (30, (-0.4, 0.0, 1.0)), (36, "auto")],
    },
    # the Turn (water's guard): turned hard to the right, both hands low out by the right hip with the palms out to meet the
    # shot (held: the window); the arms swing it round the body in a wide circle, across the front at the waist and up round to
    # the left, the body winding with them; then both hands fling it out ahead from the chest (sent back along the aim).
    # strike_s: the fling
    "water_turn": {
        "length": 36,
        "meta": {"hold_s": 5 / FPS, "strike_s": 14 / FPS, "back_s": 24 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (5, (-0.03, -0.13, 0.0)), (9, (0.02, -0.15, 0.02)), (12, (0.05, -0.14, 0.0)),
                 (14, (0.0, -0.13, 0.14)), (18, (0.0, -0.135, 0.15)), (24, (0.0, -0.125, 0.13)), (30, (0.0, -0.04, 0.03)),
                 (36, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -34), (9, 0), (12, 40), (14, 2), (18, -4), (24, -3), (36, 0)],
        "twist": [(0, 0), (5, -18), (9, 6), (12, 26), (14, -4), (18, -4), (36, 0)],
        "hips": [(0, 0), (5, 10), (9, 8), (12, 4), (14, 8), (18, 9), (24, 7), (36, 0)],
        "chest": [(0, 0), (5, 6), (9, 4), (12, 0), (14, 10), (18, 12), (24, 9), (36, 0)],
        "side": [(0, 0), (5, -6), (9, 2), (12, 8), (14, 0), (36, 0)],
        "head": [(0, 0), (5, 2), (14, -2), (36, 0)],
        "clav_r": [(0, (0, 0)), (5, (8, 4)), (9, (10, 0)), (12, (8, -8)), (14, (14, -6)), (24, (12, -5)), (36, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, 4)), (9, (6, 0)), (12, (-4, -8)), (14, (14, -6)), (24, (12, -5)), (36, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.26, 0.98, 0.18)), (5, (-0.36, 0.94, 0.12)), (9, (-0.12, 0.98, 0.48)), (12, (0.14, 1.18, 0.26)),
                   (14, (-0.14, 1.24, 0.66)), (18, (-0.16, 1.22, 0.63)), (24, (-0.16, 1.18, 0.58)), (30, (-0.2, 0.98, 0.22)), (36, HR)],
        "hand_l": [(0, HL), (3, (0.0, 0.98, 0.3)), (5, (-0.1, 0.94, 0.32)), (9, (0.24, 0.98, 0.4)), (12, (0.38, 1.24, 0.02)),
                   (14, (0.14, 1.24, 0.66)), (18, (0.16, 1.22, 0.63)), (24, (0.16, 1.18, 0.58)), (30, (0.2, 0.98, 0.22)), (36, HL)],
        "face_r": [(0, "stand"), (3, "push"), (6, "push"), (9, "float"), (12, "palm_down"), (14, "push"), (26, "push"),
                   (36, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (6, "push"), (9, "float"), (12, "palm_down"), (14, "push"), (26, "push"),
                   (36, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.8, -0.7, -0.3)), (12, (-0.6, -0.8, 0.2)), (14, (-0.8, -0.6, -0.1)),
                   (36, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.8, -0.7, -0.3)), (12, (0.9, -0.6, -0.3)), (14, (0.8, -0.6, -0.1)),
                   (36, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.3), (28, -0.3), (36, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.3), (28, -0.3), (36, 0.4)],
        "foot_l": [(0, FL), (2, (0.14, 0.12, 0.04)), (4, (0.16, 0.077, 0.2)), (30, (0.16, 0.077, 0.2)), (33, (0.14, 0.12, 0.08)),
                   (35, FL), (36, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 0), (9, 0), (12, 10), (14, 0), (30, 0), (32, 8), (35, 0)],
        "fyaw_l": [(0, 7), (5, -12), (12, 26), (14, 6), (30, 6), (35, 7)],
        "knee_l": [(0, "auto"), (2, (0.25, 0.0, 1.0)), (32, (0.25, 0.0, 1.0)), (35, "auto")],
        "foot_r": [(0, FR), (4, (-0.17, 0.077, -0.11)), (30, (-0.17, 0.077, -0.11)), (35, FR)],
        "fyaw_r": [(0, 7), (4, 30), (5, 34), (12, 50), (14, 30), (30, 30), (35, 7)],
        "heel_r": [(0, 0), (5, 0), (9, 6), (12, 18), (14, 8), (26, 6), (32, 0)],
        "knee_r": [(0, "auto"), (4, (-0.45, 0.0, 1.0)), (30, (-0.45, 0.0, 1.0)), (34, "auto")],
    },
    # the Turn's hold (a loop while the guard stands): the short tai chi bow stance, both hands rolling a ball of water round a
    # level circle before the waist, the body turning a little with it
    "water_turn_hold": {
        "length": 48, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": _ring(EIGHTHS(48), lambda a: _r3((0.01 * math.sin(a), -0.1, 0.01 * math.cos(a)))),
        "yaw": _ring(EIGHTHS(48), lambda a: round(-10 + 8 * math.sin(a), 3)),
        "twist": _ring(EIGHTHS(48), lambda a: round(-4 + 6 * math.sin(a), 3)),
        "hips": [(0, 3), (48, 3)], "chest": [(0, 2), (48, 2)], "head": [(0, 1), (48, 1)],
        "clav_r": [(0, (4, 0)), (48, (4, 0))], "clav_l": [(0, (4, 0)), (48, (4, 0))],
        "hand_r": _ring(EIGHTHS(48), lambda a: _r3((-0.13 + 0.12 * math.sin(a), 1.0 + 0.03 * math.cos(a), 0.34 + 0.1 * math.cos(a)))),
        "hand_l": _ring(EIGHTHS(48), lambda a: _r3((0.13 + 0.12 * math.sin(a), 1.0 + 0.03 * math.cos(a), 0.34 + 0.1 * math.cos(a)))),
        "face_r": [(0, "float"), (48, "float")], "face_l": [(0, "float"), (48, "float")],
        "pole_r": [(0, (-0.8, -0.7, -0.3)), (48, (-0.8, -0.7, -0.3))], "pole_l": [(0, (0.8, -0.7, -0.3)), (48, (0.8, -0.7, -0.3))],
        "grip_r": [(0, -0.15), (48, -0.15)], "grip_l": [(0, -0.15), (48, -0.15)],
        "foot_l": [(0, (0.14, 0.077, 0.15)), (48, (0.14, 0.077, 0.15))],
        "foot_r": [(0, (-0.15, 0.077, -0.12)), (48, (-0.15, 0.077, -0.12))],
        "fyaw_l": [(0, 4), (48, 4)], "fyaw_r": [(0, 30), (48, 30)],
        "knee_l": [(0, (0.25, 0.0, 1.0)), (48, (0.25, 0.0, 1.0))], "knee_r": [(0, (-0.45, 0.0, 1.0)), (48, (-0.45, 0.0, 1.0))],
    },
    # ---------------------------------------------------------------- air
    # the Pull: a step in and both palms out ahead at the shoulders' height, open (held: the wind caught); the fingers close on
    # it and the hands are dragged back to the hips as the right foot steps back and the body leans away.  strike_s: the hands
    # at the hips
    "air_pull": {
        "length": 34,
        "meta": {"hold_s": 6 / FPS, "strike_s": 11 / FPS, "back_s": 22 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (6, (0.0, -0.06, 0.08)), (8, (0.0, -0.07, 0.04)), (11, (0.0, -0.12, -0.13)),
                 (14, (0.0, -0.13, -0.15)), (22, (0.0, -0.12, -0.14)), (28, (0.0, -0.05, -0.03)), (34, (0, -0.015, 0))],
        "hips": [(0, 0), (6, 8), (8, 6), (11, -4), (14, -6), (22, -5), (34, 0)],
        "chest": [(0, 0), (6, 10), (8, 6), (11, -6), (14, -8), (22, -6), (34, 0)],
        "head": [(0, 0), (6, -4), (11, 4), (14, 5), (22, 4), (34, 0)],
        "clav_r": [(0, (0, 0)), (6, (16, -6)), (11, (-10, 2)), (14, (-12, 2)), (22, (-10, 2)), (34, (0, 0))],
        "clav_l": [(0, (0, 0)), (6, (16, -6)), (11, (-10, 2)), (14, (-12, 2)), (22, (-10, 2)), (34, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.2, 1.15, 0.3)), (6, (-0.2, 1.3, 0.6)), (8, (-0.21, 1.24, 0.48)), (11, (-0.24, 0.98, -0.02)),
                   (14, (-0.25, 0.96, -0.06)), (22, (-0.25, 0.96, -0.05)), (28, (-0.21, 0.88, 0.04)), (34, HR)],
        "hand_l": [(0, HL), (3, (0.2, 1.15, 0.3)), (6, (0.2, 1.3, 0.6)), (8, (0.21, 1.24, 0.48)), (11, (0.24, 0.98, -0.02)),
                   (14, (0.25, 0.96, -0.06)), (22, (0.25, 0.96, -0.05)), (28, (0.21, 0.88, 0.04)), (34, HL)],
        "face_r": [(0, "stand"), (3, "push"), (7, "push"), (9, "claw"), (11, "chamber"), (24, "chamber"), (34, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (7, "push"), (9, "claw"), (11, "chamber"), (24, "chamber"), (34, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.8, -0.6, -0.1)), (11, (-0.5, -0.2, -1.0)), (34, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.8, -0.6, -0.1)), (11, (0.5, -0.2, -1.0)), (34, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.4), (7, -0.4), (9, 0.7), (11, 0.85), (24, 0.85), (34, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.4), (7, -0.4), (9, 0.7), (11, 0.85), (24, 0.85), (34, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.12, 0.04)), (5, (0.15, 0.077, 0.16)), (26, (0.15, 0.077, 0.16)), (30, (0.14, 0.11, 0.06)),
                   (33, FL), (34, FL)],
        "heel_l": [(0, 0), (3, 8), (4, -4), (5, 0), (11, 0), (13, -8), (22, -6), (26, 0), (29, 8), (32, 0)],
        "knee_l": [(0, "auto"), (3, (0.25, 0.2, 1.0)), (30, (0.25, 0.2, 1.0)), (33, "auto")],
        "foot_r": [(0, FR), (7, FR), (9, (-0.15, 0.13, -0.14)), (11, (-0.16, 0.077, -0.32)), (26, (-0.16, 0.077, -0.32)),
                   (30, (-0.14, 0.12, -0.15)), (33, FR), (34, FR)],
        "heel_r": [(0, 0), (7, 0), (9, 15), (11, 0), (26, 0), (29, 10), (32, 0)],
        "fyaw_r": [(0, 7), (11, 30), (26, 30), (33, 7)],
        "knee_r": [(0, "auto"), (8, (-0.4, 0.0, 1.0)), (30, (-0.4, 0.0, 1.0)), (33, "auto")],
    },
    # the Slip (the dodge, a circle walker's pivot step; the game carries the body): sunk and gathered (held); a long step out
    # to the right with the toes turned out, the body lunging low after it and leaning into the circle, the right palm thrown
    # out wide at the shoulder's height turned in to the circle's centre and the left by the right elbow; the left foot hooks
    # in after it, toes in.  strike_s: the step set down (its twin to the left)
    "air_slip": {
        "length": 26, "mirror": True,
        "meta": {"hold_s": 3 / FPS, "strike_s": 8 / FPS, "back_s": 16 / FPS, "hand": "r", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, (0, -0.015, 0)), (3, (0.05, -0.1, 0.0)), (6, (-0.1, -0.17, 0.02)), (8, (-0.2, -0.2, 0.03)),
                 (11, (-0.19, -0.19, 0.02)), (16, (-0.17, -0.17, 0.02)), (22, (-0.03, -0.04, 0.0)), (26, (0, -0.015, 0))],
        "yaw": [(0, 0), (3, 8), (8, -26), (11, -30), (16, -26), (26, 0)],
        "twist": [(0, 0), (3, 6), (8, -10), (16, -8), (26, 0)],
        "side": [(0, 0), (3, 4), (8, -12), (11, -12), (16, -10), (26, 0)],
        "roll": [(0, 0), (3, 3), (8, -4), (16, -3), (26, 0)],
        "hips": [(0, 0), (3, 8), (8, 6), (16, 5), (26, 0)],
        "chest": [(0, 0), (3, 4), (8, 2), (26, 0)],
        "clav_r": [(0, (0, 0)), (8, (2, -12)), (16, (2, -10)), (26, (0, 0))],
        "clav_l": [(0, (0, 0)), (8, (14, -4)), (16, (12, -3)), (26, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.12, 1.08, 0.26)), (6, (-0.42, 1.18, 0.24)), (8, (-0.64, 1.18, 0.18)), (16, (-0.63, 1.17, 0.17)),
                   (22, (-0.3, 0.98, 0.14)), (26, HR)],
        "hand_l": [(0, HL), (3, (0.1, 1.06, 0.28)), (8, (-0.26, 1.04, 0.22)), (16, (-0.25, 1.03, 0.21)), (22, (0.1, 0.94, 0.14)),
                   (26, HL)],
        "face_r": [(0, "stand"), (3, "push"), (6, "bagua"), (19, "bagua"), (26, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (19, "push"), (26, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.4, -1.0, -0.2)), (19, (-0.4, -1.0, -0.2)), (26, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.6, -1.0, -0.2)), (19, (0.6, -1.0, -0.2)), (26, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.3), (20, -0.3), (26, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.3), (20, -0.3), (26, 0.4)],
        "foot_r": [(0, FR), (3, FR), (5, (-0.28, 0.13, 0.06)), (7, (-0.52, 0.077, 0.06)), (18, (-0.52, 0.077, 0.06)),
                   (21, (-0.32, 0.12, 0.02)), (24, FR), (26, FR)],
        "fyaw_r": [(0, 7), (5, 30), (7, 50), (18, 50), (24, 7)],
        "heel_r": [(0, 0), (4, 12), (6, -6), (7, 0), (18, 0), (20, 10), (23, 0)],
        "knee_r": [(0, "auto"), (4, (-0.6, 0.1, 1.0)), (20, (-0.6, 0.1, 1.0)), (24, "auto")],
        "foot_l": [(0, FL), (8, FL), (10, (0.04, 0.11, 0.03)), (12, (-0.1, 0.077, 0.05)), (17, (-0.1, 0.077, 0.05)),
                   (20, (0.03, 0.11, 0.0)), (23, FL), (26, FL)],
        "fyaw_l": [(0, 7), (8, 4), (10, -10), (12, -30), (17, -30), (23, 7)],
        "heel_l": [(0, 0), (6, 6), (8, 14), (11, -4), (12, 0), (17, 0), (19, 10), (22, 0)],
        "knee_l": [(0, "auto"), (6, (0.1, 0.0, 1.0)), (20, (0.0, 0.1, 1.0)), (23, "auto")],
    },
    # the Slip back: sunk (held), the right foot steps back and out round behind with its toes turned out, the body turning
    # side-on after it, the left palm leading out ahead and the right by the chest; the left foot turned in on its ball
    "air_slip_back": {
        "length": 26,
        "meta": {"hold_s": 3 / FPS, "strike_s": 8 / FPS, "back_s": 16 / FPS, "hand": "l", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, (0, -0.015, 0)), (3, (0.0, -0.08, 0.02)), (6, (-0.02, -0.1, -0.06)), (8, (-0.03, -0.12, -0.14)),
                 (11, (-0.03, -0.115, -0.13)), (16, (-0.03, -0.11, -0.12)), (22, (0.0, -0.04, -0.02)), (26, (0, -0.015, 0))],
        "yaw": [(0, 0), (3, 4), (8, -30), (11, -32), (16, -28), (26, 0)],
        "twist": [(0, 0), (8, -8), (16, -6), (26, 0)],
        "hips": [(0, 0), (3, 6), (8, 2), (16, 2), (26, 0)],
        "chest": [(0, 0), (3, 4), (8, -2), (16, -1), (26, 0)],
        "clav_r": [(0, (0, 0)), (8, (6, -4)), (16, (5, -3)), (26, (0, 0))],
        "clav_l": [(0, (0, 0)), (8, (14, -8)), (16, (12, -6)), (26, (0, 0))],
        "hand_l": [(0, HL), (3, (0.12, 1.15, 0.3)), (8, (0.135, 1.3, 0.39)), (16, (0.135, 1.295, 0.385)), (22, (0.18, 1.0, 0.15)),
                   (26, HL)],
        "hand_r": [(0, HR), (3, (-0.12, 1.1, 0.25)), (8, (-0.06, 1.13, 0.21)), (16, (-0.06, 1.12, 0.21)), (22, (-0.18, 0.95, 0.15)),
                   (26, HR)],
        "face_r": [(0, "stand"), (3, "push"), (19, "push"), (26, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (19, "push"), (26, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (6, (-0.6, -1.0, -0.2)), (19, (-0.6, -1.0, -0.2)), (26, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (6, (0.7, -0.8, 0.0)), (19, (0.7, -0.8, 0.0)), (26, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.3), (20, -0.3), (26, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.3), (20, -0.3), (26, 0.4)],
        "foot_r": [(0, FR), (3, FR), (5, (-0.18, 0.13, -0.14)), (7, (-0.25, 0.077, -0.34)), (18, (-0.25, 0.077, -0.34)),
                   (21, (-0.18, 0.12, -0.15)), (24, FR), (26, FR)],
        "fyaw_r": [(0, 7), (5, 30), (7, 50), (18, 50), (24, 7)],
        "heel_r": [(0, 0), (4, 12), (6, 8), (7, 0), (18, 0), (20, 10), (23, 0)],
        "knee_r": [(0, "auto"), (4, (-0.5, 0.0, 1.0)), (20, (-0.5, 0.0, 1.0)), (24, "auto")],
        "foot_l": [(0, FL), (26, FL)],
        "fyaw_l": [(0, 7), (8, -12), (18, -12), (24, 7)],
        "heel_l": [(0, 0), (6, 0), (8, 10), (18, 8), (23, 0)],
    },
    # the Wind Wall: a step in, both palms drawn in before the chest turned out (held); driven out flat together ahead, then
    # swept apart wide to the sides (the wall spread across the line); held.  strike_s: the palms out
    "air_wall": {
        "length": 38,
        "meta": {"hold_s": 7 / FPS, "strike_s": 11 / FPS, "back_s": 26 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (5, (0.0, -0.07, -0.02)), (7, (0.0, -0.08, -0.03)), (11, (0.0, -0.13, 0.12)),
                 (15, (0.0, -0.14, 0.13)), (18, (0.0, -0.145, 0.13)), (26, (0.0, -0.13, 0.12)), (32, (0.0, -0.04, 0.02)),
                 (38, (0, -0.015, 0))],
        "hips": [(0, 0), (7, -2), (11, 6), (18, 6), (26, 5), (38, 0)],
        "chest": [(0, 0), (7, -4), (11, 8), (15, 6), (18, 5), (26, 4), (38, 0)],
        "head": [(0, 0), (7, -2), (11, -2), (38, 0)],
        "clav_r": [(0, (0, 0)), (7, (-6, -4)), (11, (16, -4)), (15, (6, -6)), (18, (0, -6)), (26, (0, -5)), (38, (0, 0))],
        "clav_l": [(0, (0, 0)), (7, (-6, -4)), (11, (16, -4)), (15, (6, -6)), (18, (0, -6)), (26, (0, -5)), (38, (0, 0))],
        "hand_r": [(0, HR), (4, (-0.15, 1.2, 0.12)), (7, (-0.1, 1.28, 0.12)), (11, (-0.07, 1.31, 0.62)), (15, (-0.36, 1.3, 0.46)),
                   (18, (-0.48, 1.28, 0.32)), (26, (-0.47, 1.26, 0.3)), (32, (-0.25, 0.95, 0.15)), (38, HR)],
        "hand_l": [(0, HL), (4, (0.15, 1.2, 0.12)), (7, (0.1, 1.28, 0.12)), (11, (0.07, 1.31, 0.62)), (15, (0.36, 1.3, 0.46)),
                   (18, (0.48, 1.28, 0.32)), (26, (0.47, 1.26, 0.3)), (32, (0.25, 0.95, 0.15)), (38, HL)],
        "face_r": [(0, "stand"), (4, "push"), (12, "push"), (16, "sweep_out"), (28, "sweep_out"), (38, "stand")],
        "face_l": [(0, "stand"), (4, "push"), (12, "push"), (16, "sweep_out"), (28, "sweep_out"), (38, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (7, (-0.8, -0.8, -0.3)), (11, (-0.8, -0.6, -0.1)), (18, (-0.3, -1.0, -0.2)),
                   (38, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (7, (0.8, -0.8, -0.3)), (11, (0.8, -0.6, -0.1)), (18, (0.3, -1.0, -0.2)),
                   (38, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (4, -0.5), (30, -0.5), (38, 0.4)],
        "grip_l": [(0, 0.4), (4, -0.5), (30, -0.5), (38, 0.4)],
        "foot_l": [(0, FL), (3, (0.14, 0.12, 0.04)), (6, (0.15, 0.077, 0.22)), (28, (0.15, 0.077, 0.22)), (31, (0.14, 0.12, 0.08)),
                   (35, FL), (38, FL)],
        "heel_l": [(0, 0), (3, 8), (5, -4), (6, 0), (28, 0), (30, 8), (34, 0)],
        "knee_l": [(0, "auto"), (3, (0.2, 0.2, 1.0)), (32, (0.2, 0.2, 1.0)), (35, "auto")],
        "foot_r": [(0, FR), (6, (-0.15, 0.077, -0.08)), (28, (-0.15, 0.077, -0.08)), (35, FR)],
        "fyaw_r": [(0, 7), (6, 30), (28, 30), (35, 7)],
        "heel_r": [(0, 0), (8, 0), (11, 12), (26, 10), (34, 0)],
    },
    # the Wind Guard (air's guard): the arms drawn round into a circle before the body, the right palm high by the brow and
    # the left low by the belly, both turned out (held: the window); the palms roll round the circle, the high one down and
    # the low one up, meet before the chest and bounce out ahead together (the shot sent back), light on the feet
    "air_guard": {
        "length": 32,
        "meta": {"hold_s": 5 / FPS, "strike_s": 10 / FPS, "back_s": 18 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (3, (0.0, -0.05, 0.0)), (5, (0.0, -0.07, -0.03)), (8, (0.0, -0.09, 0.0)),
                 (10, (0.0, -0.1, 0.1)), (14, (0.0, -0.1, 0.11)), (18, (0.0, -0.095, 0.1)), (25, (0.0, -0.04, 0.02)),
                 (32, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -12), (8, -4), (10, 4), (18, 3), (32, 0)],
        "hips": [(0, 0), (5, -2), (8, 2), (10, 6), (18, 5), (32, 0)],
        "chest": [(0, 0), (5, -4), (8, 2), (10, 8), (14, 9), (18, 7), (32, 0)],
        "side": [(0, 0), (5, 3), (8, -2), (10, 0), (32, 0)],
        "head": [(0, 0), (5, -2), (10, -2), (32, 0)],
        "clav_r": [(0, (0, 0)), (5, (4, -16)), (8, (4, -2)), (10, (14, -2)), (18, (12, -2)), (32, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, 4)), (8, (4, -6)), (10, (14, -2)), (18, (12, -2)), (32, (0, 0))],
        "hand_r": [(0, HR), (2, (-0.15, 1.2, 0.28)), (5, (-0.17, 1.46, 0.29)), (7, (-0.33, 1.26, 0.34)), (8, (-0.15, 1.12, 0.3)),
                   (10, (-0.1, 1.28, 0.6)), (14, (-0.1, 1.27, 0.6)), (18, (-0.11, 1.26, 0.57)), (25, (-0.2, 1.0, 0.2)), (32, HR)],
        "hand_l": [(0, HL), (2, (0.15, 1.0, 0.26)), (5, (0.12, 0.96, 0.36)), (7, (0.32, 1.22, 0.34)), (8, (0.15, 1.2, 0.3)),
                   (10, (0.1, 1.28, 0.6)), (14, (0.1, 1.27, 0.6)), (18, (0.11, 1.26, 0.57)), (25, (0.2, 1.0, 0.2)), (32, HL)],
        "face_r": [(0, "stand"), (2, "push"), (22, "push"), (32, "stand")],
        "face_l": [(0, "stand"), (2, "float"), (5, "float"), (7, "push"), (22, "push"), (32, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-1.0, -0.2, -0.2)), (8, (-0.8, -0.8, -0.2)), (10, (-0.8, -0.6, -0.1)),
                   (32, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (1.0, -0.6, 0.0)), (8, (0.8, -0.8, -0.2)), (10, (0.8, -0.6, -0.1)),
                   (32, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (2, -0.4), (24, -0.4), (32, 0.4)],
        "grip_l": [(0, 0.4), (2, -0.4), (24, -0.4), (32, 0.4)],
        "foot_l": [(0, FL), (3, (0.13, 0.11, 0.05)), (5, (0.13, 0.077, 0.15)), (24, (0.13, 0.077, 0.15)), (27, (0.13, 0.11, 0.06)),
                   (30, FL), (32, FL)],
        "heel_l": [(0, 0), (3, 8), (4, -2), (5, 4), (24, 4), (26, 8), (29, 0)],
        "foot_r": [(0, FR), (5, (-0.14, 0.077, -0.08)), (27, (-0.14, 0.077, -0.08)), (31, FR)],
        "fyaw_r": [(0, 7), (5, 20), (27, 20), (31, 7)],
        "heel_r": [(0, 0), (5, 8), (10, 14), (18, 12), (26, 0)],
    },
    # the Wind Guard's hold (a loop while the guard stands, the spec's air-shield hold): the circle walker standing light, both
    # palms turning round a circle each before the chest (the right one way, the left the other)
    "air_shield_hold": {
        "length": 40, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"},
        "root": _ring(EIGHTHS(40), lambda a: _r3((0.0, -0.045 + 0.008 * math.sin(a), 0.0))),
        "yaw": [(0, 0), (40, 0)], "hips": [(0, 2), (40, 2)], "chest": [(0, 1), (40, 1)],
        "clav_r": [(0, (4, -4)), (40, (4, -4))], "clav_l": [(0, (4, -4)), (40, (4, -4))],
        "hand_r": _ring(EIGHTHS(40), lambda a: _r3((-0.17 + 0.09 * math.cos(a), 1.24 + 0.09 * math.sin(a), 0.34 + 0.02 * math.sin(a)))),
        "hand_l": _ring(EIGHTHS(40), lambda a: _r3((0.17 - 0.09 * math.cos(a), 1.24 + 0.09 * math.sin(a), 0.34 + 0.02 * math.sin(a)))),
        "face_r": [(0, "push"), (40, "push")], "face_l": [(0, "push"), (40, "push")],
        "pole_r": [(0, (-0.7, -0.8, 0.0)), (40, (-0.7, -0.8, 0.0))], "pole_l": [(0, (0.7, -0.8, 0.0)), (40, (0.7, -0.8, 0.0))],
        "grip_r": [(0, -0.35), (40, -0.35)], "grip_l": [(0, -0.35), (40, -0.35)],
        "foot_l": [(0, (0.12, 0.077, 0.08)), (40, (0.12, 0.077, 0.08))],
        "foot_r": [(0, (-0.14, 0.077, -0.06)), (40, (-0.14, 0.077, -0.06))],
        "fyaw_l": [(0, 2), (40, 2)], "fyaw_r": [(0, 14), (40, 14)],
        "heel_l": [(0, 6), (40, 6)], "heel_r": [(0, 8), (40, 8)],
    },
    # the Slice: light on the feet, the right hand cocked back by the ear with the palm down (held); it slices out flat ahead
    # and across at the chest's height, the edge of the hand leading, the left palm by the right elbow.  strike_s: the hand
    # out ahead (its twin to the left)
    "air_slice": {
        "length": 28, "mirror": True,
        "meta": {"hold_s": 5 / FPS, "strike_s": 8 / FPS, "back_s": 16 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (3, (0.0, -0.05, -0.01)), (5, (0.0, -0.06, -0.03)), (8, (0.0, -0.08, 0.1)),
                 (11, (0.0, -0.085, 0.12)), (16, (0.0, -0.08, 0.1)), (23, (0.0, -0.03, 0.02)), (28, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, -24), (8, 10), (11, 18), (16, 15), (28, 0)],
        "twist": [(0, 0), (5, -16), (8, 8), (11, 14), (16, 12), (28, 0)],
        "hips": [(0, 0), (5, 2), (8, 6), (16, 5), (28, 0)],
        "chest": [(0, 0), (5, 2), (8, 7), (16, 6), (28, 0)],
        "side": [(0, 0), (5, 5), (8, -3), (16, -2), (28, 0)],
        "head": [(0, 0), (5, -2), (8, -3), (28, 0)],
        "clav_r": [(0, (0, 0)), (5, (-6, -12)), (8, (14, -4)), (11, (16, -3)), (16, (12, -3)), (28, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (8, -2)), (8, (10, -2)), (16, (8, -2)), (28, (0, 0))],
        "hand_r": [(0, HR), (3, (-0.25, 1.25, 0.05)), (5, (-0.3, 1.44, -0.02)), (7, (-0.15, 1.36, 0.42)), (8, (0.04, 1.29, 0.66)),
                   (11, (0.17, 1.25, 0.54)), (16, (0.16, 1.23, 0.48)), (23, (-0.15, 0.98, 0.18)), (28, HR)],
        "hand_l": [(0, HL), (3, (0.12, 1.12, 0.3)), (5, (0.1, 1.2, 0.36)), (8, (0.04, 1.12, 0.3)), (16, (0.05, 1.12, 0.3)),
                   (23, (0.18, 0.95, 0.12)), (28, HL)],
        "face_r": [(0, "stand"), (3, "slice_back"), (6, "slice_back"), (8, "slice"), (18, "slice"), (28, "stand")],
        "face_l": [(0, "stand"), (3, "push"), (18, "push"), (28, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-1.0, 0.0, -0.4)), (8, (-0.6, -0.6, 0.0)), (28, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.6, -1.0, -0.2)), (28, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (3, -0.5), (22, -0.5), (28, 0.4)],
        "grip_l": [(0, 0.4), (3, -0.3), (22, -0.3), (28, 0.4)],
        "foot_l": [(0, FL), (2, (0.13, 0.12, 0.05)), (4, (0.14, 0.077, 0.18)), (19, (0.14, 0.077, 0.18)), (22, (0.13, 0.12, 0.07)),
                   (25, FL), (28, FL)],
        "heel_l": [(0, 0), (2, 8), (3, -4), (4, 4), (19, 4), (21, 8), (24, 0)],
        "knee_l": [(0, "auto"), (2, (0.2, 0.2, 1.0)), (22, (0.2, 0.2, 1.0)), (25, "auto")],
        "foot_r": [(0, FR), (4, (-0.14, 0.077, -0.08)), (20, (-0.14, 0.077, -0.08)), (25, FR)],
        "fyaw_r": [(0, 7), (4, 30), (8, 36), (20, 36), (25, 7)],
        "heel_r": [(0, 0), (4, 10), (8, 22), (16, 18), (24, 0)],
    },
    # ---------------------------------------------------------------- water (the ride and the glide; the game carries the body)
    # the Surf (a loop while riding the wave, legs_always): side-on and crouched low on a wide staggered stance, the left arm
    # out ahead and the right back for the balance, the body riding the wave's bob
    "water_surf": {
        "length": 48, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place", "legs_always": 1.0},
        "root": [(0, (0.0, -0.24, 0.0)), (12, (0.01, -0.265, 0.01)), (24, (0.0, -0.245, 0.0)), (36, (-0.01, -0.265, -0.01)),
                 (48, (0.0, -0.24, 0.0))],
        "yaw": [(0, -32), (24, -28), (48, -32)],
        "twist": [(0, 6), (24, 3), (48, 6)],
        "hips": [(0, 14), (12, 17), (24, 14), (36, 17), (48, 14)],
        "chest": [(0, 6), (12, 4), (24, 6), (36, 4), (48, 6)],
        "roll": [(0, 0), (12, 2), (24, 0), (36, -2), (48, 0)],
        "head": [(0, -10), (12, -12), (24, -10), (36, -12), (48, -10)],
        "clav_r": [(0, (-4, -6)), (48, (-4, -6))], "clav_l": [(0, (8, -6)), (48, (8, -6))],
        "hand_l": [(0, (0.24, 1.02, 0.42)), (12, (0.25, 0.97, 0.43)), (24, (0.24, 1.02, 0.42)), (36, (0.23, 1.05, 0.41)),
                   (48, (0.24, 1.02, 0.42))],
        "hand_r": [(0, (-0.38, 0.92, -0.08)), (12, (-0.38, 0.97, -0.08)), (24, (-0.38, 0.92, -0.08)), (36, (-0.37, 0.88, -0.08)),
                   (48, (-0.38, 0.92, -0.08))],
        "face_r": [(0, "arms_out"), (48, "arms_out")], "face_l": [(0, "palm_down"), (48, "palm_down")],
        "pole_r": [(0, (-0.5, -1.0, -0.4)), (48, (-0.5, -1.0, -0.4))], "pole_l": [(0, (0.5, -1.0, -0.2)), (48, (0.5, -1.0, -0.2))],
        "grip_r": [(0, -0.3), (48, -0.3)], "grip_l": [(0, -0.3), (48, -0.3)],
        "foot_l": [(0, (0.16, 0.077, 0.22)), (48, (0.16, 0.077, 0.22))],
        "foot_r": [(0, (-0.18, 0.077, -0.2)), (48, (-0.18, 0.077, -0.2))],
        "fyaw_l": [(0, -6), (48, -6)], "fyaw_r": [(0, 50), (48, 50)],
        "knee_l": [(0, (0.35, 0.0, 1.0)), (48, (0.35, 0.0, 1.0))], "knee_r": [(0, (-0.6, 0.0, 1.0)), (48, (-0.6, 0.0, 1.0))],
    },
    # the Skate (a skater's push-off on the water's ice; legs_always): crouched and gathered (held); the right leg drives out
    # to the side and back off the deck, the body low and leaning ahead over the bent left leg, the left arm swinging out ahead
    # and the right back (the glide, held); gathered in again.  strike_s: the push out
    "water_skate": {
        "length": 30,
        "meta": {"hold_s": 5 / FPS, "strike_s": 9 / FPS, "back_s": 20 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, (0, -0.015, 0)), (5, (0.0, -0.16, 0.02)), (9, (0.06, -0.2, 0.06)), (16, (0.06, -0.2, 0.06)),
                 (20, (0.05, -0.18, 0.05)), (25, (0.01, -0.05, 0.01)), (30, (0, -0.015, 0))],
        "yaw": [(0, 0), (5, 4), (9, -10), (16, -10), (20, -8), (30, 0)],
        "hips": [(0, 0), (5, 14), (9, 22), (16, 21), (20, 18), (30, 0)],
        "chest": [(0, 0), (5, 8), (9, 10), (16, 10), (20, 8), (30, 0)],
        "side": [(0, 0), (9, 4), (16, 4), (30, 0)],
        "head": [(0, 0), (5, -10), (9, -14), (16, -13), (20, -11), (30, 0)],
        "clav_r": [(0, (0, 0)), (5, (6, 4)), (9, (-10, 4)), (16, (-10, 4)), (30, (0, 0))],
        "clav_l": [(0, (0, 0)), (5, (6, 4)), (9, (16, -4)), (16, (16, -4)), (30, (0, 0))],
        "hand_r": [(0, HR), (5, (-0.2, 0.92, 0.26)), (9, (-0.28, 0.86, -0.12)), (16, (-0.28, 0.86, -0.11)), (20, (-0.24, 0.88, 0.0)),
                   (25, (-0.2, 0.84, 0.08)), (30, HR)],
        "hand_l": [(0, HL), (5, (0.15, 0.92, 0.26)), (9, (0.03, 1.11, 0.66)), (16, (0.03, 1.1, 0.65)), (20, (0.1, 1.0, 0.4)),
                   (25, (0.19, 0.86, 0.12)), (30, HL)],
        "face_r": [(0, "stand"), (5, "palm_down"), (9, "arms_out"), (20, "arms_out"), (30, "stand")],
        "face_l": [(0, "stand"), (5, "palm_down"), (20, "palm_down"), (30, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (5, (-0.8, -0.6, -0.2)), (9, (-0.6, -1.0, 0.0)), (30, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (5, (0.8, -0.6, -0.2)), (9, (0.6, -0.8, 0.0)), (30, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (5, -0.3), (24, -0.3), (30, 0.4)],
        "grip_l": [(0, 0.4), (5, -0.3), (24, -0.3), (30, 0.4)],
        "foot_r": [(0, FR), (5, (-0.14, 0.077, -0.04)), (7, (-0.24, 0.095, -0.12)), (9, (-0.42, 0.1, -0.22)),
                   (16, (-0.41, 0.1, -0.21)), (20, (-0.26, 0.13, -0.1)), (24, FR), (30, FR)],
        "fyaw_r": [(0, 7), (5, 20), (9, 45), (16, 45), (24, 7)],
        "heel_r": [(0, 0), (5, 6), (9, -4), (16, -4), (20, 6), (23, 0)],
        "knee_r": [(0, "auto"), (5, (-0.6, 0.0, 1.0)), (20, (-0.6, 0.0, 1.0)), (24, "auto")],
        "foot_l": [(0, FL), (30, FL)],
        "fyaw_l": [(0, 7), (5, 10), (9, 16), (20, 16), (26, 7)],
        "knee_l": [(0, "auto"), (4, (0.3, 0.0, 1.0)), (24, (0.3, 0.0, 1.0)), (27, "auto")],
    },
}
CLIPS.update(SET3)

## ---------------------------------------------------------------- the fourth set (round 3, P1's air and hit states: the %
## ring's tumble, flinch, double jump, fall, fast fall, helpless fall, air dodge, air legs and the two landings; authored the
## same way, key poses typed here, nothing read). The airborne clips start and end on AIR (the plain fall's own first frame),
## so they hand over to each other and to the fall loop without a jump; the landings start on the deck from it and end on
## the STAND. A loop's channels are written as functions of its phase (a radian round the loop) sampled at its eighths, each
## part a little behind the one that drives it (the hands behind the elbows behind the chest), so nothing stops dead.
FACING.update({
    "loose_up": ((-0.15, 0.95, -0.12), (0.1, 0.1, 1.0)),     # an arm trailing up limp, the fingers up, the palm forward
    "flung_up": ((-0.75, 0.6, -0.1), (0.0, 0.1, 1.0)),       # an arm flung up and out, the fingers out, the palm forward
    "tuck_shin": ((0.15, -0.6, 0.78), (0.95, 0.0, -0.2)),    # the hand on the shin in a tuck, the fingers down and forward
    "arrow": ((0.05, -1.0, -0.05), (0.98, 0.0, 0.15)),       # pressed to the thigh in the dive, the fingers down, the palm in
    "dive": ((0.0, -0.87, -0.5), (0.98, 0.0, 0.0)),          # swept back along the side in the dive, the wrist straight, palm in
    "balance": ((-0.85, -0.15, 0.45), (0.0, -1.0, 0.1)),     # out to the side for the balance, the palm down
    "cross": ((0.85, 0.35, 0.3), (0.0, 0.1, -1.0)),          # crossed before the chest in the dodge, the palm in to the body
    "knee": ((0.1, -0.55, 0.83), (0.0, -1.0, 0.0)),          # braced on the knee, the fingers forward and down, the palm on it
    "jolt": ((-0.25, 0.4, 0.88), (0.0, -0.9, 0.4)),          # jolted up and out by a hit, the fingers forward, the palm down
})


def _loop(length, fn, keys=None, step=1):
    """A loop's channels from fn(phase) -> {channel: value}: each sampled every `step` frames (the seam's first again at the
    last; every frame by default, so a second harmonic and a lag of a frame or two keep their shape). `keys` limits them."""
    frames = list(range(0, length + 1, step))
    first = fn(0.0)
    out = {}
    for ch in (keys or first.keys()):
        out[ch] = _ring(frames, lambda a, c=ch: _rv(fn(a)[c]))
    return out


def _rv(v):
    return _r3(v) if isinstance(v, (tuple, list)) else round(float(v), 3)


def _add(v, d):
    return tuple(a + b for a, b in zip(v, d))


def _s(a, ph=0.0):
    return math.sin(a + ph)


def _c(a, ph=0.0):
    return math.cos(a + ph)


## The plain fall (own-bend-fall, a loop of 20 frames) as a function of its phase: the athlete in control in the air, a
## little bowed over the hips, the arms open wide in a true balance a little over the shoulders' height (the elbows soft, the
## palms down), the legs ready under him (the right knee ahead, the left foot trailing back), the toes hanging; paddling:
## the legs turn a bicycle big enough to read from the stands, the chest breathes behind them, the arms see-saw two frames
## behind the chest (opposite each other) and the head settles last; the head and the hands carry a smaller second beat of
## their own so the extremities never ride one sine with the chest.
def fall_at(a):
    lag = 2 * math.pi * 2 / 20   # two frames of the 20
    return {
        "root": (0.0, 0.008 * _s(a), 0.0),
        "hips": 7.0 + 1.5 * _s(a), "chest": 5.0 + 3.0 * _s(a, -0.7), "roll": 1.5 * _s(a, -1.2), "twist": 3.0 * _s(a, -0.9),
        "head": 7.0 + 2.0 * _s(a, -1.5) + 0.8 * _s(2 * a, -2.2),
        "clav_r": (2.0 * _s(a, -1.4), -12.0 + 3.0 * _s(a, -1.4)), "clav_l": (-2.0 * _s(a, -1.4), -12.0 - 3.0 * _s(a, -1.4)),
        # (pass 3: a touch lower and forward, the elbows broken downward, the fingers relaxed, and the two hands see-sawing
        # by different amounts, so the arms are a fighter's balance, never an airplane's mirror-perfect wings)
        "hand_r": _add((-0.6, 1.3, 0.1), (0.025 * _c(a, -0.7 - lag), 0.07 * _s(a, -0.7 - lag) + 0.028 * _s(2 * a, -2.4),
                                             0.03 * _c(a, -0.7 - lag))),
        "hand_l": _add((0.6, 1.31, 0.08), (-0.02 * _c(a, -0.7 - lag + math.pi), 0.05 * _s(a, -0.7 - lag + math.pi)
                                           + 0.022 * _s(2 * a, -1.0), -0.025 * _c(a, -0.7 - lag + math.pi))),
        "face_r": "balance", "face_l": "balance",
        "pole_r": (-0.6, -0.5, -0.4), "pole_l": (0.6, -0.5, -0.4),
        "grip_r": 0.15, "grip_l": 0.15,
        "foot_r": _add((-0.14, 0.27, 0.1), (0.0, 0.08 * _s(a), 0.13 * _c(a))),
        "foot_l": _add((0.14, 0.33, -0.1), (0.0, -0.08 * _s(a), -0.13 * _c(a))),
        "heel_r": 26.0 + 6.0 * _s(a, -0.5), "heel_l": 30.0 - 6.0 * _s(a, -0.5),
        "fyaw_r": 6.0, "fyaw_l": 8.0,
        "knee_r": (-0.2, 0.15, 1.0), "knee_l": (0.2, 0.1, 1.0),
    }


AIR = dict(STAND)
AIR.update({k: _rv(v) if not isinstance(v, str) else v for k, v in fall_at(0.0).items()})
AR, AL = AIR["hand_r"], AIR["hand_l"]
AFR, AFL = AIR["foot_r"], AIR["foot_l"]


## The helpless fall (own-bend-helpless, a loop of 24 frames): spent and limp, nothing like the fall: the arms trailing high
## over the head as the air drags them (a tall V, the elbows soft, the shoulders hunched up under them), the back arched and
## the head thrown back looking up, the legs hanging long and limp under him (the knees soft, the toes dangling); the whole
## body always lying back off the vertical (a body falling, never a man standing) and wallowing slowly round a cone (a slow
## pitch and roll a quarter turn apart, and a lazy turn), the limbs lagging it one after another.
def _yawv(v, deg):
    """A place or a way in the character's frame turned about the vertical by deg (+ to the left), as the yaw turns the body."""
    r = math.radians(deg)
    return (v[0] * math.cos(r) + v[2] * math.sin(r), v[1], -v[0] * math.sin(r) + v[2] * math.cos(r))


## Pass 3: lying back 22 degrees or more at every frame (-34 +/- 12: never near the upright "hooray"), the arms trailing up
## in the WORLD (the hands keyed ahead of the shoulders in the body's frame, so with the body lying back they hang straight up
## on the drag), the elbows bent about 30-50 degrees, the hands dangling from the wrists (the palms back and down, the fingers
## curled), never level (the left 0.12 m lower and on its own beat), the head lolling a few frames behind the chest's side bend,
## the knees soft and the left foot trailing: dead weight.
FACING["limp_up"] = ((0.1, 0.94, -0.3), (0.05, -0.3, -0.95))   # a limp hand on a trailing arm, flopped back, the palm back and down
HELPLESS_LAG = 2 * math.pi * 3 / 24                            # the head three frames behind the chest's side bend
## The feet's places (the ankles' before the heel lift): the right knee bent about 15 degrees, the left about 25 and trailing.
HELPLESS_FOOT_R = (-0.15, 0.085, 0.01)
HELPLESS_FOOT_L = (0.16, 0.12, -0.21)


def _swing(v, u, w):
    """The arm's reach v swung u and w (m) across its own line at the hand, its length kept (a limp arm's sway that never
    pumps the elbow straight and bent)."""
    n = math.sqrt(sum(x * x for x in v))
    d = [x / n for x in v]
    t1 = (d[1], -d[0], 0.0)                     # across the line, level (d x the forward axis)
    m = math.sqrt(t1[0] ** 2 + t1[1] ** 2)
    t1 = (t1[0] / m, t1[1] / m, 0.0)
    t2 = (d[1] * t1[2] - d[2] * t1[1], d[2] * t1[0] - d[0] * t1[2], d[0] * t1[1] - d[1] * t1[0])
    p = [v[i] + u * t1[i] + w * t2[i] for i in range(3)]
    k = n / math.sqrt(sum(x * x for x in p))
    return tuple(x * k for x in p)


def helpless_at(a):
    yaw = 22.0 * _s(a, 0.6)
    side_ph = 0.67                                               # the chest's side bend 6 cos(a - 0.9) as a sine's phase
    return {
        "flip": -34.0 + 12.0 * _s(a), "cart": 24.0 * _c(a), "yaw": yaw,
        "root": (0.0, 0.03, 0.0),
        "hips": -9.0 + 2.0 * _s(a, -0.5), "chest": -14.0 + 5.0 * _s(a, -1.0), "side": 6.0 * _s(a, side_ph),
        "twist": 8.0 * _s(a, -1.0), "head": -20.0 + 7.0 * _s(a, -1.6), "look": 10.0 * _s(a, -1.4),
        "tilt": 10.0 * _s(a, side_ph - HELPLESS_LAG),
        "clav_r": (-6.0, -26.0 + 5.0 * _s(a, -1.8)), "clav_l": (-6.0, -24.0 - 5.0 * _s(2 * a, -1.8)),
        # (the arms keyed as their reach from the shoulders in the chest's frame ("hands_from": the body's sway carries them
        # whole): up and a little ahead of the lying-back body, so in the world they trail straight up on the drag, the elbows
        # bent about 35-50 degrees; the left lower and out wider, on its own beat with a second
        # harmonic, so the V is never level or mirrored)
        "hand_r": _swing((-0.174, 0.377, 0.24), 0.05 * _s(a, 0.41), 0.04 * _c(a, 0.41)),
        "hand_l": _swing((0.34, 0.24, 0.2), 0.045 * _s(a, 3.55) + 0.02 * _s(2 * a, 1.0), 0.035 * _c(a, 3.55)),
        "face_r": "limp_up", "face_l": "limp_up",
        "pole_r": (-1.0, -0.4, -0.3), "pole_l": (1.0, -0.4, -0.3),
        "grip_r": 0.05 + 0.08 * _s(a, -2.2), "grip_l": 0.08 + 0.08 * _s(2 * a, 1.0),
        # the legs hang limp, the knees soft (the right a little, the left more), the left foot trailing back; each swings a
        # little after the hips that carry it; the toes dangling, not pointed
        "foot_r": _yawv(_add(HELPLESS_FOOT_R, (0.02 * _s(a, -0.6), 0.01 * _s(a, -0.6), 0.03 * _c(a, -0.6))), yaw),
        "foot_l": _yawv(_add(HELPLESS_FOOT_L, (-0.02 * _s(a, 2.2), 0.01 * _s(a, 2.2), 0.03 * _c(a, 2.2))), yaw),
        "heel_r": 34.0 + 6.0 * _s(a, -1.2), "heel_l": 30.0 + 6.0 * _s(a, 1.9),
        "fyaw_r": 14.0 - yaw, "fyaw_l": 18.0 + yaw,
        "knee_r": _yawv((-0.3, 0.0, 1.0), yaw), "knee_l": _yawv((0.35, 0.0, 1.0), yaw),
    }


## The air legs (own-bend-air-legs, a loop of 24 frames on the legs' bones only): an aerial tuck in two different shapes: the
## right knee raised high and ahead, the left heel drawn back under the seat (its shin angled back, never hanging under a
## level thigh like a man sat on a chair), the toes pointed and flickering; the trailing leg carries a second beat of its own
## so the two never mirror one sine.
def air_legs_at(a):
    return {
        "foot_r": _add((-0.13, 0.58, 0.2), (0.0, 0.045 * _s(a), 0.06 * _c(a))),
        "foot_l": _add((0.14, 0.5, -0.08), (0.0, -0.045 * _s(a, 0.8) + 0.018 * _s(2 * a, 0.3),
                                            -0.05 * _c(a, 0.8) + 0.02 * _c(2 * a))),
        "heel_r": 34.0 + 8.0 * _s(a, -0.6), "heel_l": 45.0 + 8.0 * _s(a, 1.0) + 3.0 * _s(2 * a),
        "fyaw_r": 4.0, "fyaw_l": 10.0,
        "knee_r": (-0.12, 0.3, 1.0), "knee_l": (0.18, 0.3, 1.0),
    }


## The fast fall (own-bend-fall-fast, a loop of 16 frames): the tucked arrow: the body long and straight, only a little bowed,
## the face up enough to watch the landing, both arms swept straight back from the shoulders in a narrow V (the elbows nearly
## straight, the palms back), the knees drawn up a little with the feet pressed together under him, the toes pointed: a
## compact spike at a glance, against the fall's wide balance and the helpless fall's tall V; the wind shivers him twice a
## loop (the hands a frame behind the chest, the head two).
FACING["swept"] = ((-0.08, -0.75, -0.66), (0.6, 0.53, -0.6))   # swept back from the shoulder, the fingers trailing, the palm back


## Pass 3: the spike: the whole body pitched 12 degrees into the dive (flip), the head down to watch the landing, the arms
## swept back AND out from the shoulders (an arrowhead from behind, a long back-swept line from the side), the legs long and
## straight together with the same small bend (neither knee leads), the toes pointed; the wind buffets him: the chest shivers
## twice a loop, the hands 0.05 m two frames behind it, the head shaken at the third harmonic.
FALL_FAST_FOOT = (0.05, 0.062, -0.1)   # the left ankle's place before the heel lift (the right's mirrored): the legs near straight


def fall_fast_at(a):
    b = 2 * a
    fr = 2 * math.pi * 2 / 16          # a frame at the shiver's two beats a loop
    fx, fy, fz = FALL_FAST_FOOT
    return {
        "flip": 12.0, "root": (0.0, 0.03, 0.0),
        "hips": 2.0, "chest": 2.0 + 3.0 * _s(b), "head": 14.0 + 2.0 * _s(b, -fr), "roll": 0.8 * _s(b, 1.0),
        "look": 4.0 * _s(3 * a, 0.5), "twist": 1.5 * _s(a, 0.4),
        "clav_r": (-26.0, 6.0), "clav_l": (-26.0, 6.0),
        "hand_r": _add((-0.388, 1.055, -0.347), (0.012 * _s(a, 1.0), 0.05 * _s(b, -2 * fr), 0.02 * _c(b, -2 * fr))),
        "hand_l": _add((0.388, 1.055, -0.347), (-0.012 * _s(a, 2.0), 0.05 * _s(b, -2 * fr + 0.6), 0.02 * _c(b, -2 * fr + 0.6))),
        "face_r": "swept", "face_l": "swept",
        "pole_r": (-0.6, 0.2, -1.0), "pole_l": (0.6, 0.2, -1.0),
        "grip_r": 0.15, "grip_l": 0.15,
        "foot_r": _add((-fx, fy, fz), (0.0, 0.006 * _s(b, -0.5), 0.01 * _c(b, -0.5))),
        "foot_l": _add((fx, fy, fz), (0.0, 0.006 * _s(b, 1.5), 0.01 * _c(b, 1.5))),
        "heel_r": 72.0 + 3.0 * _s(b, -0.8), "heel_l": 72.0 + 3.0 * _s(b, 0.2), "fyaw_r": 0.0, "fyaw_l": 0.0,
        "knee_r": (0.0, 0.0, 1.0), "knee_l": (0.0, 0.0, 1.0),
    }


def _lerp(p, q, t):
    if isinstance(p, (tuple, list)):
        return tuple(x + (y - x) * t for x, y in zip(p, q))
    return p + (q - p) * t


def _win(f, up0, up1, dn0, dn1, n):
    """A window round a loop of n frames: 0, eased up from up0 to up1, 1 until dn0, eased down to 0 by dn1 (wraps)."""
    d = (f - up0) % n
    r, h, fl = up1 - up0, dn0 - up0, dn1 - up0
    if d < r:
        x = d / r
        return x * x * (3 - 2 * x)
    if d <= h:
        return 1.0
    if d < fl:
        x = (d - h) / (fl - h)
        return 1.0 - x * x * (3 - 2 * x)
    return 0.0


## The tumble's turn (own-bend-tumble, 24 frames, one whole backward somersault a loop): the figure's own pitch turns at
## TUMBLE_RATE deg a frame on average, swinging by TUMBLE_SWING either way, fastest at TUMBLE_FAST (the middle of the tuck)
## and slowest twelve frames away (the open, flung pose): the angular momentum read of a thrown body. The somersault channel
## is that pitch less half the trunk's own curl (the hips' bow and half the chest's), so the curl into the tuck adds to the
## turn instead of fighting it. TUMBLE_LEAD sets where in the turn the loop starts (lying back, just after the upright ball).
TUMBLE_RATE = 15.0
TUMBLE_SWING = 9.0
TUMBLE_FAST = 17.0
TUMBLE_LEAD = -15.0
## The root's drift (m, the world's up): up while open, down in the tuck, so the turn has no fixed axle through the hips.
TUMBLE_DRIFT = 0.03


def tumble_at(f):
    n = 24
    a = 2 * math.pi * f / n
    tl = _win(f, 8, 14, 21, 24, n)            # the legs: drawn up f8-14, held through the upright pass, flung out f21-24
    ta = _win(f, 10, 16, 20, 24, n)           # the arms: onto the shins f10-16, flung fully out f20-f24 (open at the seam)
    tt = _win(f, 9, 15, 21, 25, n)            # the trunk's curl between them
    th = _win(f - 2, 9, 15, 21, 25, n)        # the head two frames behind the trunk (it whips through)
    o = math.sin(math.pi * f / 12.0) ** 2     # the open pose's drift while flung (the arms swept back as he turns)
    hips = _lerp(-10.0 - 4.0 * o, 24.0, tt)
    chest = _lerp(-14.0 - 4.0 * o, 26.0, tt)
    pitch = -TUMBLE_RATE * f - TUMBLE_SWING * n / (2 * math.pi) * math.sin(2 * math.pi * (f - TUMBLE_FAST) / n) + TUMBLE_LEAD
    flip = pitch + TUMBLE_RATE * f - 0.5 * (hips + 0.5 * chest)
    total = math.radians(-TUMBLE_RATE * f + flip)
    d = TUMBLE_DRIFT - 2 * TUMBLE_DRIFT * tt
    sa, sl = math.sin(math.pi * ta), math.sin(math.pi * tl)
    return {
        "flip": flip, "cart": 14.0 * _s(a, 0.8), "twist": 10.0 * _s(a, 1.6),
        # (the world's up drift carried into the turned body's frame)
        "root": (0.0, d * math.cos(total), -d * math.sin(total)),
        "hips": hips, "chest": chest, "head": _lerp(-18.0 - 3.0 * o, 20.0, th), "side": _lerp(4.0 + 2.0 * o, -3.0, tt),
        "clav_r": _lerp(_lerp((-6.0, -22.0), (-8.0, -26.0), o), (10.0, 6.0), ta),
        "clav_l": _lerp(_lerp((-4.0, -18.0), (-8.0, -24.0), o), (10.0, 6.0), ta),
        # (each hand on an arc out round the body between the flung pose and the shins, not through the chest)
        "hand_r": _add(_lerp(_lerp((-0.6, 1.38, -0.24), (-0.6, 1.32, -0.29), o), (-0.17, 0.86, 0.42), ta),
                       (-0.13 * sa, 0.06 * sa, 0.05 * sa)),
        "hand_l": _add(_lerp(_lerp((0.58, 1.34, -0.17), (0.57, 1.3, -0.23), o), (0.2, 0.9, 0.4), ta),
                       (0.13 * sa, 0.06 * sa, 0.05 * sa)),
        "pole_r": _lerp((-0.3, -0.8, -0.6), (-1.0, 0.0, 0.2), ta), "pole_l": _lerp((0.3, -0.8, -0.6), (1.0, 0.0, 0.2), ta),
        "grip_r": _lerp(-0.45 - 0.05 * o, 0.7, ta), "grip_l": _lerp(-0.4 - 0.1 * o, 0.7, ta),
        "foot_r": _add(_lerp(_lerp((-0.2, 0.4, 0.24), (-0.27, 0.27, 0.14), o), (-0.13, 0.6, 0.27), tl), (0.0, 0.0, 0.05 * sl)),
        "foot_l": _add(_lerp(_lerp((0.22, 0.31, 0.05), (0.3, 0.25, -0.1), o), (0.14, 0.57, 0.23), tl), (0.0, 0.0, 0.05 * sl)),
        "heel_r": _lerp(30.0 + 10.0 * o, 32.0, tl), "heel_l": _lerp(34.0 + 10.0 * o, 30.0, tl),
        "fyaw_r": 16.0, "fyaw_l": 20.0,
        "knee_r": (-0.35, 0.3, 1.0), "knee_l": (0.4, 0.3, 1.0),
    }


def _frames(length, fn, keys):
    """A loop's channels keyed at every frame from fn(frame) (the seam's frame is the first's again)."""
    out = {}
    for ch in keys:
        out[ch] = [(f, _rv(fn(f % length)[ch])) for f in range(length + 1)]
    return out


def _up(v, dy):
    return (v[0], v[1] + dy, v[2])


SET4 = {
    # the tumble (a long launch: hitstun past the knock's own hold): one whole backward somersault a loop, typed as a turn
    # rate (tumble_at): flung wide open while the turn is slow, pulled into a tuck as it quickens, the tuck held through the
    # fastest part and through the upright pass (a ball, never a man standing), then flung open again; the legs lead, the
    # arms follow two frames behind, the head whips through two frames behind the trunk; the root drifts up while open and
    # down in the tuck. Distinct from the knock-slide (on the feet) and the knock-air (one hop) at a glance: the whole body turns.
    "tumble": dict({"length": 24, "loop": True, "flip_turns": -1.0, "base": AIR,
                    "meta": {"hand": "both", "mask": "full", "root": "place"}},
                   **_frames(24, tumble_at, [k for k in tumble_at(0.0)]),
                   face_r=[(0, "flail"), (2, "flung_up"), (10, "flung_up"), (15, "tuck_shin"), (20, "tuck_shin"), (24, "flail")],
                   face_l=[(0, "flail"), (2, "flung_up"), (10, "flung_up"), (15, "tuck_shin"), (20, "tuck_shin"), (24, "flail")]),
    # the flinch (a light hit that leaves him on his feet; upper mask, 0.3 s): the hit snaps the chest back and turns it, the
    # head whipped back a beat behind; the reversal spread over three frames into the cringe: the shoulders hunched, a
    # forearm guard (loose fists crossed up before the chin, the elbows in front of the ribs, the chin tucked behind it),
    # wide enough to read from the stands; then eased out through the stand, the arms dropping last and the head after them.
    # strike_s: the hit; hold_s: the cringe; back_s: the release
    "flinch": {
        "length": 9,
        "meta": {"strike_s": 1 / FPS, "hold_s": 3 / FPS, "back_s": 5 / FPS, "hand": "both", "mask": "upper", "root": "place"},
        "root": [(0, (0, -0.015, 0)), (1, (0.0, -0.025, -0.03)), (3, (0.0, -0.035, -0.02)), (5, (0.0, -0.028, -0.01)),
                 (9, (0, -0.015, 0))],
        "hips": [(0, 0), (1, -5), (3, 2), (5, 1), (9, 0)],
        "chest": [(0, 0), (1, -16), (2, -11), (3, 0), (4, 7), (5, 6), (7, 2), (9, 0)],
        "twist": [(0, 0), (1, 10), (3, 6), (5, 3), (9, 0)],
        "side": [(0, 0), (1, 4), (3, 3), (6, 1), (9, 0)],
        # (pass 3: the cringe is a ring fighter's forearm guard, not a civilian's "whoa": loose fists, the forearms crossed up
        # before the chin, the elbows in front of the ribs, the chin tucked down behind the guard; the head's whip back kept)
        "head": [(0, 0), (1, -6), (2, -16), (3, 4), (4, 6), (5, 7), (6, 6), (8, 2), (9, 0)],
        "clav_r": [(0, (0, 0)), (1, (2, -8)), (3, (12, -14)), (5, (10, -11)), (7, (4, -5)), (9, (0, 0))],
        "clav_l": [(0, (0, 0)), (1, (2, -8)), (3, (12, -13)), (5, (10, -10)), (7, (4, -5)), (9, (0, 0))],
        "hand_r": [(0, HR), (1, (-0.23, 0.97, 0.17)), (2, (-0.17, 1.17, 0.22)), (3, (-0.09, 1.3, 0.28)), (4, (-0.095, 1.29, 0.278)),
                   (5, (-0.11, 1.255, 0.265)), (6, (-0.16, 1.13, 0.2)), (7, (-0.2, 0.99, 0.13)), (8, (-0.2, 0.86, 0.085)), (9, HR)],
        "hand_l": [(0, HL), (1, (0.23, 0.95, 0.15)), (2, (0.17, 1.17, 0.23)), (3, (0.09, 1.32, 0.3)), (4, (0.095, 1.31, 0.298)),
                   (5, (0.11, 1.275, 0.285)), (6, (0.16, 1.14, 0.21)), (7, (0.2, 0.99, 0.13)), (8, (0.2, 0.85, 0.085)), (9, HL)],
        "face_r": [(0, "stand"), (1, "jolt"), (3, "guard"), (5, "guard"), (9, "stand")],
        "face_l": [(0, "stand"), (1, "jolt"), (3, "guard"), (5, "guard"), (9, "stand")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (1, (-0.7, -0.4, -0.6)), (3, (-0.8, -0.5, 0.3)), (5, (-0.8, -0.5, 0.25)),
                   (7, (-0.5, -0.4, -0.6)), (9, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (1, (0.7, -0.4, -0.6)), (3, (0.8, -0.5, 0.3)), (5, (0.8, -0.5, 0.25)),
                   (7, (0.5, -0.4, -0.6)), (9, (0.35, -0.1, -1.0))],
        "grip_r": [(0, 0.4), (1, -0.4), (3, 0.5), (5, 0.5), (7, 0.45), (9, 0.4)],
        "grip_l": [(0, 0.4), (1, -0.4), (3, 0.5), (5, 0.5), (7, 0.45), (9, 0.4)],
    },
    # the double jump (the tucked knees-up spring): from the fall a gather over three frames (the knees, the hips and the
    # chest drawn up and over, the hands lifted), then the push: the legs kick down hard against the air, the toes pointed,
    # the body stretched into an arch (the chest and the hips back, the face up), the arms swept back and down behind the hips
    # in a V; the arms swing out round and up through the shoulders' height in one loop and the knees snap up under the seat,
    # the heels tight under it, the hands pulled in onto the knees: a ball by f6, held to f8 at the height of the spring;
    # opened out into the fall again, the legs first, then the arms, the face last.  hold_s: the gather; strike_s: the push
    "jump_double": {
        "length": 12, "base": AIR,
        "meta": {"hold_s": 2 / FPS, "strike_s": 3 / FPS, "back_s": 8 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, AIR["root"]), (2, (0.0, 0.03, 0.0)), (3, (0.0, -0.04, 0.0)), (6, (0.0, 0.05, 0.0)), (8, (0.0, 0.04, 0.0)),
                 (12, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, AIR["hips"] + 6), (3, -11), (4, 4), (5, 14), (6, 20), (8, 18), (10, 12), (12, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, AIR["chest"] + 6), (3, -13), (4, 6), (5, 14), (6, 18), (8, 15), (10, 9),
                  (12, AIR["chest"])],
        "head": [(0, AIR["head"]), (2, AIR["head"] + 3), (3, -9), (4, -3), (6, 6), (8, 8), (10, 6), (12, AIR["head"])],
        "clav_r": [(0, AIR["clav_r"]), (1, (-2, -14)), (3, (-10, 8)), (4, (0, -14)), (6, (10, 0)), (8, (10, 0)),
                   (12, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (1, (-2, -14)), (3, (-10, 8)), (4, (0, -14)), (6, (10, 0)), (8, (10, 0)),
                   (12, AIR["clav_l"])],
        # (the hands: up 0.1 m in the gather, then down and back over f1-f3 into the push's V, out round the side at f4 and on
        # up and in onto the knees: one loop, no V-shaped pop)
        "hand_r": [(0, AR), (1, _up(AR, 0.1)), (2, (-0.47, 1.16, -0.06)), (3, (-0.34, 0.86, -0.44)), (4, (-0.48, 1.15, 0.0)),
                   (5, (-0.32, 1.12, 0.28)), (6, (-0.17, 0.99, 0.36)), (8, (-0.18, 0.98, 0.35)), (10, (-0.36, 1.12, 0.24)),
                   (12, AR)],
        "hand_l": [(0, AL), (1, _up(AL, 0.1)), (2, (0.47, 1.17, -0.07)), (3, (0.35, 0.85, -0.445)), (4, (0.48, 1.16, 0.0)),
                   (5, (0.32, 1.12, 0.27)), (6, (0.17, 0.99, 0.35)), (8, (0.18, 0.98, 0.34)), (10, (0.36, 1.13, 0.23)),
                   (12, AL)],
        "face_r": [(0, "balance"), (1, "balance"), (3, "stand"), (4, "flung_up"), (6, "knee"), (8, "knee"), (12, "balance")],
        "face_l": [(0, "balance"), (1, "balance"), (3, "stand"), (4, "flung_up"), (6, "knee"), (8, "knee"), (12, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-0.3, 0.0, -1.0)), (4, (-1.0, -0.3, -0.3)), (6, (-1.0, -0.2, 0.2)), (8, (-1.0, -0.2, 0.2)),
                   (12, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (3, (0.3, 0.0, -1.0)), (4, (1.0, -0.3, -0.3)), (6, (1.0, -0.2, 0.2)), (8, (1.0, -0.2, 0.2)),
                   (12, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (3, 0.6), (4, -0.3), (6, 0.5), (8, 0.5), (12, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (3, 0.6), (4, -0.3), (6, 0.5), (8, 0.5), (12, AIR["grip_l"])],
        "foot_r": [(0, AFR), (2, _add(AFR, (0.0, 0.12, 0.03))), (3, (-0.13, -0.01, -0.15)), (4, (-0.12, 0.38, 0.12)),
                   (5, (-0.12, 0.54, 0.06)), (6, (-0.12, 0.62, 0.02)), (8, (-0.12, 0.6, 0.03)), (10, (-0.14, 0.42, 0.12)), (12, AFR)],
        "foot_l": [(0, AFL), (2, _add(AFL, (0.0, 0.12, 0.03))), (3, (0.13, 0.0, -0.17)), (4, (0.13, 0.36, 0.08)),
                   (5, (0.13, 0.52, 0.03)), (6, (0.13, 0.6, 0.0)), (8, (0.13, 0.58, 0.01)), (11, (0.15, 0.4, -0.08)), (12, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (2, AIR["heel_r"] + 6), (3, 70), (4, 50), (6, 40), (8, 40), (12, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (2, AIR["heel_l"] + 6), (3, 70), (4, 50), (6, 40), (8, 40), (12, AIR["heel_l"])],
        "knee_r": [(0, AIR["knee_r"]), (3, (-0.1, 0.0, 1.0)), (6, (-0.15, 0.15, 1.0)), (8, (-0.15, 0.15, 1.0)), (12, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (3, (0.1, 0.0, 1.0)), (6, (0.15, 0.15, 1.0)), (8, (0.15, 0.15, 1.0)), (12, AIR["knee_l"])],
    },
    "fall": dict({"length": 20, "loop": True, "base": AIR, "meta": {"hand": "both", "mask": "full", "root": "place"}},
                 **_loop(20, fall_at, [k for k in fall_at(0.0) if not k.startswith("face_")]),
                 face_r=[(0, "balance"), (20, "balance")], face_l=[(0, "balance"), (20, "balance")]),
    "fall_fast": dict({"length": 16, "loop": True, "base": AIR, "meta": {"hand": "both", "mask": "full", "root": "place"}},
                      **_loop(16, fall_fast_at, [k for k in fall_fast_at(0.0) if not k.startswith("face_")]),
                      face_r=[(0, "swept"), (16, "swept")], face_l=[(0, "swept"), (16, "swept")]),
    "helpless": dict({"length": 24, "loop": True, "base": AIR, "hands_from": "shoulder", "meta": {"hand": "both", "mask": "full", "root": "place"}},
                     **_loop(24, helpless_at, [k for k in helpless_at(0.0) if not k.startswith("face_")]),
                     face_r=[(0, "limp_up"), (24, "limp_up")], face_l=[(0, "limp_up"), (24, "limp_up")]),
    # the air dodge (a sharp tucked twist; the code moves him): from the fall the body snaps in from the middle out: the hips
    # and the chest first, the knees a frame later, the arms crossed before the chest after them and the head last; the head
    # leads the turn (looking round ahead of the body) and the tuck tightens at the turn's fastest, then the head lands on the
    # new heading first and the body comes round after it; it opens back into the fall, the legs first, the arms after.
    # hold_s: the snap in; strike_s: tucked (untouchable from here); back_s: opening
    "air_dodge": {
        "length": 15, "base": AIR,
        "meta": {"hold_s": 1 / FPS, "strike_s": 2 / FPS, "back_s": 9 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "spin": [(0, 0), (2, 30), (5, 200), (8, 330), (10, 360), (15, 360)],
        "look": [(0, 0), (1, 8), (2, 20), (5, 24), (8, 30), (9, 13), (10, 0), (15, 0)],
        "root": [(0, AIR["root"]), (2, (0.0, 0.06, 0.0)), (5, (0.0, 0.075, 0.0)), (9, (0.0, 0.06, 0.0)), (15, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, 16), (5, 20), (9, 15), (12, 10), (15, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, 20), (5, 23), (9, 18), (12, 9), (15, AIR["chest"])],
        "head": [(0, AIR["head"]), (1, AIR["head"] - 1), (3, 8), (4, 10), (9, 10), (13, 7), (15, AIR["head"])],
        "twist": [(0, 0), (2, 8), (9, 6), (15, 0)],
        "clav_r": [(0, AIR["clav_r"]), (2, (8, 0)), (3, (14, 8)), (10, (12, 6)), (15, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (8, 0)), (3, (14, 8)), (10, (12, 6)), (15, AIR["clav_l"])],
        "hand_r": [(0, AR), (2, (-0.2, 1.22, 0.27)), (3, (0.1, 1.26, 0.24)), (5, (0.11, 1.245, 0.23)), (9, (0.1, 1.25, 0.24)),
                   (12, (-0.3, 1.2, 0.22)), (15, AR)],
        "hand_l": [(0, AL), (2, (0.2, 1.25, 0.24)), (3, (-0.08, 1.3, 0.2)), (5, (-0.09, 1.285, 0.19)), (9, (-0.08, 1.29, 0.2)),
                   (12, (0.3, 1.26, 0.18)), (15, AL)],
        "face_r": [(0, "balance"), (3, "cross"), (10, "cross"), (15, "balance")],
        "face_l": [(0, "balance"), (3, "cross"), (10, "cross"), (15, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-0.8, -0.6, 0.2)), (10, (-0.8, -0.6, 0.2)), (15, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (3, (0.8, -0.6, 0.2)), (10, (0.8, -0.6, 0.2)), (15, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (3, 0.9), (10, 0.9), (15, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (3, 0.9), (10, 0.9), (15, AIR["grip_l"])],
        "foot_r": [(0, AFR), (2, (-0.11, 0.48, 0.22)), (3, (-0.11, 0.6, 0.26)), (5, (-0.11, 0.63, 0.27)), (9, (-0.11, 0.59, 0.25)),
                   (12, (-0.13, 0.4, 0.18)), (15, AFR)],
        "foot_l": [(0, AFL), (2, (0.11, 0.44, 0.15)), (3, (0.11, 0.56, 0.2)), (5, (0.11, 0.59, 0.21)), (9, (0.11, 0.55, 0.19)),
                   (12, (0.13, 0.42, 0.04)), (15, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (3, 36), (12, 30), (15, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (3, 36), (12, 30), (15, AIR["heel_l"])],
        "knee_r": [(0, AIR["knee_r"]), (2, (-0.1, 0.5, 1.0)), (10, (-0.1, 0.5, 1.0)), (15, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (2, (0.1, 0.5, 1.0)), (10, (0.1, 0.5, 1.0)), (15, AIR["knee_l"])],
    },
    "air_legs": dict({"length": 24, "loop": True, "bones": "legs", "base": AIR,
                      "meta": {"hand": "both", "mask": "lower", "root": "place"}}, **_loop(24, air_legs_at)),
    # the light landing (from the fall: a plain landing, short lag): the toes take the deck, the heels roll down, the knees
    # give and the hips sink and sit back a little as the chest leans over the knees (the weight kept over the feet), the arms
    # come down from the fall's balance in front a beat behind the body; up through the stand, the arms and the head settling
    # last.  strike_s: the heels down; hold_s: the lowest; back_s: rising
    "land_light": {
        "length": 10,
        "meta": {"strike_s": 1 / FPS, "hold_s": 3 / FPS, "back_s": 5 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.01, 0.0)), (1, (0.0, -0.06, -0.015)), (3, (0.0, -0.14, -0.04)), (5, (0.0, -0.115, -0.035)),
                 (8, (0.0, -0.035, -0.01)), (10, (0, -0.015, 0))],
        "hips": [(0, 5), (1, 9), (3, 17), (5, 14), (8, 4), (10, 0)],
        "chest": [(0, 4), (1, 5), (3, 9), (5, 8), (8, 2), (10, 0)],
        "head": [(0, 6), (2, 11), (4, 7), (7, 1), (10, 0)],
        "clav_r": [(0, AIR["clav_r"]), (3, (6, 4)), (6, (3, 2)), (10, (0, 0))],
        "clav_l": [(0, AIR["clav_l"]), (3, (6, 4)), (6, (3, 2)), (10, (0, 0))],
        "hand_r": [(0, AR), (2, (-0.42, 1.0, 0.2)), (4, (-0.32, 0.84, 0.24)), (7, (-0.24, 0.8, 0.14)), (10, HR)],
        "hand_l": [(0, AL), (2, (0.42, 1.02, 0.18)), (4, (0.32, 0.86, 0.22)), (7, (0.24, 0.8, 0.13)), (10, HL)],
        "face_r": [(0, "balance"), (3, "palm_down"), (10, "stand")], "face_l": [(0, "balance"), (3, "palm_down"), (10, "stand")],
        "pole_r": [(0, AIR["pole_r"]), (4, (-0.6, -0.5, -0.6)), (10, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, AIR["pole_l"]), (4, (0.6, -0.5, -0.6)), (10, (0.35, -0.1, -1.0))],
        "grip_r": [(0, AIR["grip_r"]), (4, 0.2), (10, 0.4)], "grip_l": [(0, AIR["grip_l"]), (4, 0.2), (10, 0.4)],
        "foot_r": [(0, FR), (10, FR)], "foot_l": [(0, FL), (10, FL)],
        "heel_r": [(0, 14), (1, 0), (10, 0)], "heel_l": [(0, 16), (1, 0), (10, 0)],
        "knee_r": [(0, "auto"), (2, (-0.25, 0.0, 1.0)), (6, (-0.25, 0.0, 1.0)), (9, "auto")],
        "knee_l": [(0, "auto"), (2, (0.25, 0.0, 1.0)), (6, (0.25, 0.0, 1.0)), (9, "auto")],
    },
    # the heavy landing (the landing lag of a Slam, a missed air cast or the helpless fall: the punish window, and it must read
    # as one at a glance): from the fall's balance he slams down into a deep squat, the hips dropping hard and sitting back
    # (the weight kept over the feet); the impact travels up through him: the palms slap onto the thighs above the knees
    # first, the chest keeps sagging over them two frames after, the head hangs last; held there, sagging (the window); then a
    # slow, heavy push up off the thighs, eased in (the root's rise slow at first, its fastest in the middle, eased out at the
    # stand), the hands pressed into the thighs until f12; settling at different times: the chest overshoots back at f14 and
    # settles, the hands reach the stand at f15, the head comes up last (a touch past at f14, level at f16).
    # strike_s: the impact; hold_s: the bottom; back_s: the push up
    "land_heavy": {
        "length": 16,
        "meta": {"strike_s": 1 / FPS, "hold_s": 3 / FPS, "back_s": 8 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, (0.0, -0.02, 0.0)), (1, (0.0, -0.15, -0.045)), (3, (0.0, -0.31, -0.11)), (5, (0.0, -0.335, -0.115)),
                 (8, (0.0, -0.32, -0.11)), (10, (0.0, -0.285, -0.1)), (12, (0.0, -0.18, -0.065)), (14, (0.0, -0.07, -0.022)),
                 (16, (0, -0.015, 0))],
        "hips": [(0, 4), (1, 18), (3, 40), (5, 42), (8, 40), (10, 36), (12, 23), (14, 7), (16, 0)],
        "chest": [(0, 2), (1, 4), (3, 13), (5, 19), (8, 16), (10, 13), (12, 6), (14, -3), (16, 0)],
        "head": [(0, AIR["head"]), (1, 1), (3, 8), (5, 20), (8, 18), (10, 15), (12, 9), (14, 4), (16, 0)],
        "side": [(0, 0), (3, -3), (8, -2), (12, -1), (16, 0)],
        "clav_r": [(0, AIR["clav_r"]), (2, (6, 0)), (4, (12, 8)), (8, (10, 6)), (12, (7, 4)), (15, (1, 0)), (16, (0, 0))],
        "clav_l": [(0, AIR["clav_l"]), (2, (6, 0)), (4, (12, 8)), (8, (10, 6)), (12, (7, 4)), (15, (1, 0)), (16, (0, 0))],
        "hand_r": [(0, AR), (1, (-0.42, 1.06, 0.18)), (2, (-0.2, 0.56, 0.23)), (3, (-0.17, 0.47, 0.22)), (5, (-0.17, 0.455, 0.22)),
                   (8, (-0.17, 0.46, 0.22)), (10, (-0.175, 0.485, 0.215)), (11, (-0.177, 0.525, 0.21)), (12, (-0.182, 0.61, 0.19)), (13, (-0.195, 0.69, 0.15)),
                   (14, (-0.195, 0.76, 0.1)), (15, HR), (16, HR)],
        "hand_l": [(0, AL), (1, (0.42, 1.08, 0.18)), (2, (0.2, 0.56, 0.23)), (3, (0.17, 0.47, 0.22)), (5, (0.17, 0.455, 0.22)),
                   (8, (0.17, 0.46, 0.22)), (10, (0.175, 0.485, 0.215)), (11, (0.177, 0.525, 0.21)), (12, (0.182, 0.61, 0.19)), (13, (0.195, 0.69, 0.15)),
                   (14, (0.195, 0.76, 0.1)), (15, HL), (16, HL)],
        "face_r": [(0, "balance"), (2, "knee"), (12, "knee"), (15, "stand"), (16, "stand")],
        "face_l": [(0, "balance"), (2, "knee"), (12, "knee"), (15, "stand"), (16, "stand")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-1.0, 0.3, -0.2)), (12, (-1.0, 0.3, -0.2)), (15, (-0.35, -0.1, -1.0)), (16, (-0.35, -0.1, -1.0))],
        "pole_l": [(0, AIR["pole_l"]), (3, (1.0, 0.3, -0.2)), (12, (1.0, 0.3, -0.2)), (15, (0.35, -0.1, -1.0)), (16, (0.35, -0.1, -1.0))],
        "grip_r": [(0, AIR["grip_r"]), (3, -0.1), (12, -0.1), (15, 0.4), (16, 0.4)],
        "grip_l": [(0, AIR["grip_l"]), (3, -0.1), (12, -0.1), (15, 0.4), (16, 0.4)],
        "foot_r": [(0, FR), (16, FR)], "foot_l": [(0, FL), (16, FL)],
        "fyaw_r": [(0, 7), (16, 7)], "fyaw_l": [(0, 7), (16, 7)],
        "heel_r": [(0, 12), (1, 0), (16, 0)], "heel_l": [(0, 14), (1, 0), (16, 0)],
        "knee_r": [(0, "auto"), (2, (-0.35, 0.0, 1.0)), (12, (-0.35, 0.0, 1.0)), (15, "auto")],
        "knee_l": [(0, "auto"), (2, (0.35, 0.0, 1.0)), (12, (0.35, 0.0, 1.0)), (15, "auto")],
    },
}
CLIPS.update(SET4)


## ---------------------------------------------------------------- the fifth set (round 3, P1's edge and ground dodges: the
## deck's edge (the grab, the hang, the climb, the roll in, the jump and the attack from it), the ground rolls and the duck;
## authored the same way, key poses typed here, nothing read). The edge clips are keyed in the HANG'S FRAME: the origin where
## the game snaps a hanger (spec 5.3: the feet's origin LIP_Y under the lip, LIP_Z out from the deck's face, facing the deck),
## so the lip is at (y LIP_Y, z LIP_Z) in the character's frame and the deck's top is the plane y LIP_Y ahead of it; their
## metas lip_y and lip_out say so for the code. The get-ups (climb, roll, attack) end standing on the deck CLIMB_IN in from
## the lip (meta end_in: the root's place there, (0, LIP_Y, LIP_Z + CLIMB_IN)); the edge jump ends on AIR (the fall's first
## pose) at the origin, the code's jump carrying him up. The ground rolls turn the tucked figure about its ball's middle
## (pivot) on the deck (ground: the lowest of the body's surface kept on the deck, a contact like the IK's) while the code
## carries him; facing kept (no yaw). Fire Northern Shaolin, earth Hung Gar, water tai chi and air Baguazhang are style
## labels only (the edge attack's low sweep is a Shaolin/Hung Gar ground sweep in form); these are every element's.
LIP_Y = 2.0
LIP_Z = 0.35
## A palm laid flat on the deck (the palm bone over the stone).
DECK_PALM = LIP_Y + 0.03
## Where the get-ups stand: CLIMB_IN m in from the lip (spec 5.3: the climb stands 0.6 m in).
CLIMB_IN = 0.6
EDGE_META = {"hand": "both", "mask": "full", "root": "place", "legs_always": 1.0, "lip_y": LIP_Y, "lip_out": LIP_Z}


def _deck(v):
    """A stand place carried onto the deck where the get-ups stand (CLIMB_IN m in from the lip, on its top)."""
    return (v[0], v[1] + LIP_Y, v[2] + LIP_Z + CLIMB_IN)


def _mx(v):
    return (-v[0], v[1], v[2])


DFR, DFL, DHR, DHL = _deck(FR), _deck(FL), _deck(HR), _deck(HL)
DROOT = _deck(STAND["root"])
FACING.update({
    "deck": ((0.1, -0.03, 1.0), (0.0, -1.0, 0.0)),            # laid flat on the deck, the fingers forward and a little in
    "lip_reach": ((0.05, 0.55, 0.83), (0.0, -0.83, 0.55)),    # reaching up and over for the lip, the palm down and ahead
    "press": ((0.15, -0.2, 0.97), (0.0, -1.0, -0.2)),         # pressing down on the deck beside the body, the fingers ahead
    "deck_out": ((-0.6, -0.03, 0.8), (0.0, -1.0, 0.0)),       # flat on the deck, the fingers turned out (a low crouch's prop)
    "sky": ((0.0, 1.0, 0.1), (0.95, 0.0, 0.3)),               # flung up overhead, the fingers up, the palm in
    "hug": ((0.6, -0.5, 0.62), (0.0, -0.3, -0.95)),           # round the shin in a tuck, the palm on it
    "ears": ((0.1, 0.35, -0.93), (0.0, 0.95, 0.3)),           # by the ear for a back roll's push, the fingers back, the palm up
    "ward": ((0.25, 0.9, 0.35), (0.3, 0.1, -0.95)),           # a forearm up before the face, the palm toward it
    "fling": ((-0.35, 0.9, 0.25), (0.75, 0.15, 0.62)),        # swung up and out past the shoulder, open, the palm in and ahead
})

## The hang (own-bend-edge-hang, a loop of 30 frames): the forearms laid across the lip's coping, the palms flat on the deck
## ahead and the elbows on the nose of the stone, the shoulders shrugged up under the load and the head well over the lip
## (the head up, eyes on the deck); the lower body a climber's Z pressed into the stone: the hips held out off the face, the
## knees folded to about a right angle and turned out, the balls of both feet pressed high on the face (the left a little
## higher), so the line from the feet through the hips to the shoulders is a bent bow; the sway: the hips swing side to side
## (5 cm) and the trunk rolls and twists after them, a breath lifts the chest and the shoulders twice a loop, the head glances
## a quarter loop behind the hips, the heels re-press in turn as the hips swing over each foot, the right hand flexes its
## grip at f12-f18 (the palm unmoved) and the head lifts to check along the deck at f19-f28; the palms and the balls of the
## feet never move (they hold the stone).
## (pass 3: a climber's line instead of a frog squat: the right foot high with its knee folded and pulled in, the left
## foot 22 cm lower down the face with the leg running long down the stone; the hips swing 8 cm, the chest rolls after them
## and the head glances last; a 1.5 cm settle on the arms as the hips cross the middle; the check: the head turned 25 degrees
## along the deck and the chest lifted, looking for an opening)
HANG_PALM_R = (-0.22, DECK_PALM, 0.56)
HANG_FOOT_R = (-0.16, 1.3, 0.18)
HANG_FOOT_L = (0.16, 1.08, 0.18)
## The head's glance a quarter loop behind the hips' swing.
HANG_LAG = math.pi / 2


def _bump(a, f0, f1, n=30):
    """A smooth hump (0 outside frames f0..f1 of an n-frame loop, 1 at their middle) at the loop's phase a."""
    f = (a / (2 * math.pi) * n) % n
    if f <= f0 or f >= f1:
        return 0.0
    return math.sin(math.pi * (f - f0) / (f1 - f0)) ** 2


def hang_at(a):
    regrip = _bump(a, 12, 18)
    check = _bump(a, 18, 28)
    breath = _s(2 * a, 0.5)
    settle = _bump(a, 3, 9) + _bump(a, 18, 24)
    return {
        "root": (0.08 * _s(a), 0.9 + 0.015 * breath - 0.015 * settle, -0.02 + 0.01 * _c(a)),
        "hips": 24.0 + 1.5 * _s(a, -0.4), "roll": 5.0 * _s(a, -1.0), "chest": 7.0 + 1.5 * _s(2 * a, -0.8) - 3.0 * check,
        "side": -2.5 * _s(a, -1.1), "twist": 4.0 * _s(a, -1.2),
        "head": -18.0 + 2.0 * _s(2 * a, -1.6) - 8.0 * check, "look": 12.0 * _s(a, -HANG_LAG) + 25.0 * check,
        "clav_r": (6.0, -18.0 + 2.0 * _s(a, -0.6) - 1.5 * breath), "clav_l": (6.0, -18.0 - 2.0 * _s(a, -0.6) - 1.5 * breath),
        "hand_r": HANG_PALM_R, "hand_l": _mx(HANG_PALM_R),
        "face_r": "deck", "face_l": "deck",
        "pole_r": (-0.35, -1.0, -0.1), "pole_l": (0.35, -1.0, -0.1),
        # (the flex: the fingers lifted off the stone and laid back, the palm pressing)
        "grip_r": 0.3 - 0.45 * regrip, "grip_l": 0.3,
        "foot_r": HANG_FOOT_R, "foot_l": HANG_FOOT_L,
        "heel_r": 10.0 - 4.0 * _s(a), "heel_l": 14.0 + 4.0 * _s(a), "fyaw_r": 12.0, "fyaw_l": 10.0,
        "knee_r": (-0.3, 0.1, 1.0), "knee_l": (0.25, 0.0, 1.0),
    }


HANG = dict(STAND)
HANG.update({k: _rv(v) if not isinstance(v, str) else v for k, v in hang_at(0.0).items()})
GR, GL = HANG["hand_r"], HANG["hand_l"]
GFR, GFL = HANG["foot_r"], HANG["foot_l"]


def _h(key, *more):
    """The hang's first value of a channel as a key at frame 0 (and at the frames `more`)."""
    return [(fr, HANG[key]) for fr in (0,) + more]


def _turned(v, deg, piv, axis):
    """A place turned by deg about the X (flip) or the Z (cart) axis through piv, as pose() turns a tumbling figure."""
    r = math.radians(deg)
    d = [v[i] - piv[i] for i in range(3)]
    if axis == "x":
        y, z = d[1] * math.cos(r) - d[2] * math.sin(r), d[1] * math.sin(r) + d[2] * math.cos(r)
        d = [d[0], y, z]
    else:
        x, y = d[0] * math.cos(r) - d[1] * math.sin(r), d[0] * math.sin(r) + d[1] * math.cos(r)
        d = [x, y, d[2]]
    return tuple(round(piv[i] + d[i], 4) for i in range(3))


def _unturn(w, deg, piv, axis="x"):
    """The key that a flip (axis x) or a cart (axis z) of deg about piv turns onto the place w: a hand keyed to land where
    the deck is while the figure turns."""
    return _turned(w, -deg, piv, axis)


def _unturn_way(face, deg, axis="x", side="r"):
    """A named facing as the facing that the turn of deg carries onto it (the right hand's, or the left's mirrored: a typed
    facing is not mirrored by the left hand as a name is)."""
    f, n = FACING[face]
    if side == "l":
        f, n = _mx(f), _mx(n)
    return (_turned(f, -deg, (0, 0, 0), axis), _turned(n, -deg, (0, 0, 0), axis))


## The heel lift's carry of the ankle (pose(): a lifted heel turns the foot about its ball): the ankle's place to key so the
## ankle lands at `ankle` with the heel lifted by `heel` degrees (no toe-out). A foot laid back on the deck (a knee down, the
## shin along the deck, the toes over the nose) is a heel lift past 90.
FOOT_BALL = (0.0, -0.058, 0.101)


def _heel_place(ankle, heel):
    r = math.radians(heel)
    by, bz = FOOT_BALL[1], FOOT_BALL[2]
    ry, rz = by * math.cos(r) - bz * math.sin(r), by * math.sin(r) + bz * math.cos(r)
    return (ankle[0], round(ankle[1] - (by - ry), 4), round(ankle[2] - (bz - rz), 4))


## The edge jump's lift (spec 5.3: vy 11.8 at once; the ring's gravity): the code carries the hanger up from the press of
## Space. The clip's keys are the body over the code's carry (as every clip's are); `lift` is that carry and `lift_w` the
## share of it the clip takes back off (a uniform shift of the whole figure, the rotations as keyed), so the hands stay on the
## deck and the feet on the face through the coil and the push before the body goes with the code (intangible 0-0.12 s).
EDGE_JUMP_VY = 11.8
EDGE_JUMP_G = 19.9


def _rise(f, vy=EDGE_JUMP_VY, g=EDGE_JUMP_G):
    t = f / FPS
    return vy * t - 0.5 * g * t * t


## The climb's right ankle while the knee is on the deck by the lip: the shin laid back across the coping's nose (resting on it),
## the foot past the face.
CLIMB_DRAPE = (-0.2, LIP_Y - 0.08, LIP_Z - 0.2)

SET5 = {
    # the grab (6 f): caught high off the face, both arms long and spread up over the lip; the hands slap down flat on the
    # deck (the catch) and the arms take the weight with a jolt: the body sags until the chin dips to the lip, the elbows
    # give deep and the shoulders shrug up under the load, while the legs, trailing out behind, swing in under the lip like a
    # pendulum: the hips swing in past the hang toward the face, the balls of the feet strike the face (the heels dropping as
    # they take it) and the hips bounce back out into the hang; the head a frame behind the hips.  hold_s: the reach;
    # strike_s: the hands on the deck; back_s: the feet on the face
    "edge_grab": {
        "length": 6, "base": HANG, "substeps": 4,
        "meta": dict(EDGE_META, hold_s=1 / FPS, strike_s=2 / FPS, back_s=4 / FPS),
        "root": [(0, (0.0, 1.06, -0.08)), (1, (0.0, 0.95, 0.02)), (2, (0.0, 0.92, 0.05)), (3, (0.0, 0.8, 0.08)),
                 (4, (0.0, 0.85, 0.05)), (5, (0.0, 0.91, 0.0)), (6, HANG["root"])],
        "hips": [(0, -4), (1, 4), (2, 12), (3, 22), (4, 28), (5, 26), (6, HANG["hips"])],
        # (the catch square to the lip; the hang's sway comes in as the hips bounce back out)
        "roll": [(0, 0.0), (3, 0.0), (6, HANG["roll"])], "twist": [(0, 0.0), (3, 0.0), (6, HANG["twist"])],
        "side": [(0, 0.0), (3, 0.0), (6, HANG["side"])], "look": [(0, 0.0), (3, 0.0), (6, HANG["look"])],
        "chest": [(0, -2), (1, 2), (2, 6), (3, 11), (4, 9), (6, HANG["chest"])],
        "head": [(0, -28), (1, -26), (2, -18), (3, -10), (4, -20), (5, -21), (6, HANG["head"])],
        "clav_r": [(0, (2, -24)), (1, (6, -20)), (2, (8, -16)), (3, (10, -26)), (4, (8, -21)), (6, HANG["clav_r"])],
        "clav_l": [(0, (2, -24)), (1, (6, -20)), (2, (8, -16)), (3, (10, -26)), (4, (8, -21)), (6, HANG["clav_l"])],
        "hand_r": [(0, (-0.43, 2.54, 0.18)), (1, (-0.24, 2.12, 0.48)), (2, GR), (6, GR)],
        "hand_l": [(0, (0.44, 2.63, 0.17)), (1, (0.24, 2.14, 0.47)), (2, GL), (6, GL)],
        "face_r": [(0, "lip_reach"), (1, "lip_reach"), (2, "deck"), (6, "deck")],
        "face_l": [(0, "lip_reach"), (1, "lip_reach"), (2, "deck"), (6, "deck")],
        "pole_r": [(0, (-0.7, -0.5, -0.3)), (2, (-0.5, -1.0, -0.2)), (3, (-0.45, -1.0, -0.5)), (6, HANG["pole_r"])],
        "pole_l": [(0, (0.7, -0.5, -0.3)), (2, (0.5, -1.0, -0.2)), (3, (0.45, -1.0, -0.5)), (6, HANG["pole_l"])],
        "grip_r": [(0, -0.3), (1, -0.4), (2, 0.5), (4, 0.35), (6, HANG["grip_r"])],
        "grip_l": [(0, -0.3), (1, -0.4), (2, 0.5), (4, 0.35), (6, HANG["grip_l"])],
        "foot_r": [(0, (-0.14, 1.3, -0.32)), (2, (-0.15, 1.2, -0.24)), (3, (-0.16, 1.24, 0.07)), (4, GFR), (6, GFR)],
        "foot_l": [(0, (0.15, 1.18, -0.39)), (2, (0.16, 1.08, -0.28)), (3, (0.16, 1.06, 0.06)), (4, GFL), (6, GFL)],
        "heel_r": [(0, 28), (2, 22), (3, 12), (4, 0), (6, HANG["heel_r"])],
        "heel_l": [(0, 32), (2, 24), (3, 14), (4, 2), (6, HANG["heel_l"])],
        "fyaw_r": [(0, 6), (4, HANG["fyaw_r"])], "fyaw_l": [(0, 8), (4, HANG["fyaw_l"])],
        "knee_r": [(0, (-0.2, 0.0, 1.0)), (3, (-0.4, 0.2, 1.0)), (6, HANG["knee_r"])],
        "knee_l": [(0, (0.2, 0.0, 1.0)), (3, (0.35, 0.1, 1.0)), (6, HANG["knee_l"])],
    },
    "edge_hang": dict({"length": 30, "loop": True, "base": HANG, "meta": dict(EDGE_META)},
                      **_loop(30, hang_at, [k for k in hang_at(0.0) if not k.startswith("face_")]),
                      face_r=[(0, "deck"), (30, "deck")], face_l=[(0, "deck"), (30, "deck")]),
    # the climb (15 f, 0.5 s), a mantle: a dip (the elbows sink, loading), then the arms press the body up the face, the feet
    # walking up it with the knees turned out (clear of the stone), until the hips are up at the lip with the trunk leant
    # well over the hands; the right knee comes up and is set on the nose of the coping, the shin hanging down the face; the
    # weight rocks forward onto that knee (it rolls onto the deck, the shin draped back over the nose) as the left foot swings
    # up onto the deck ahead, the right hand lifting and the left coming onto the left thigh, the hips shifted left over the
    # left foot; a held load (the left hand pressing the thigh), then he drives up off the left leg (eased out) and the right
    # foot steps through to the stand CLIMB_IN in, the rise carried a touch past (onto the toes) and settled, the chest a
    # touch back; the head up first, the arms landing two frames after the hips.
    # hold_s: the press; strike_s: the knee on the nose; back_s: the load before the drive
    "edge_climb": {
        "length": 15, "base": HANG,
        "meta": dict(EDGE_META, hold_s=3 / FPS, strike_s=6 / FPS, back_s=9 / FPS, end_in=CLIMB_IN),
        "root": [(0, HANG["root"]), (1, (0.0, 0.85, 0.0)), (2, (0.0, 0.95, 0.02)), (3, (0.0, 1.06, 0.04)), (4, (0.0, 1.16, 0.05)),
                 (5, (0.0, 1.21, 0.05)), (6, (0.0, 1.24, 0.06)), (7, (0.02, 1.34, 0.24)), (8, (0.05, 1.5, 0.4)),
                 (9, (0.05, 1.55, 0.5)), (10, (0.05, 1.555, 0.56)), (11, (0.04, 1.73, 0.76)), (12, (0.02, 1.87, 0.88)),
                 (13, (0.01, 1.96, 0.93)), (14, (0.0, 1.997, 0.95)), (15, DROOT)],
        "hips": [(0, HANG["hips"]), (1, 26), (3, 30), (5, 36), (6, 40), (7, 52), (8, 38), (9, 30), (10, 30), (11, 20), (12, 10),
                 (13, 3), (14, -1), (15, 0)],
        "chest": [(0, HANG["chest"]), (1, 8), (3, 16), (5, 12), (6, 10), (7, 10), (8, 10), (9, 12), (10, 12), (11, 7), (12, 2),
                  (13, -1), (14, -3), (15, 0)],
        "head": [(0, HANG["head"]), (1, -22), (3, -26), (5, -30), (6, -30), (7, -20), (8, -20), (9, -18), (10, -14), (11, -6),
                 (12, -1), (14, 1), (15, 0)],
        "roll": [(0, HANG["roll"]), (3, -2), (5, -4), (6, -6), (8, 3), (10, 2), (15, 0)],
        "clav_r": [(0, HANG["clav_r"]), (1, (6, -22)), (3, (4, 4)), (5, (4, 10)), (7, (4, 10)), (9, (2, 6)), (11, (0, 0)),
                   (15, (0, 0))],
        "clav_l": [(0, HANG["clav_l"]), (1, (6, -22)), (3, (4, 4)), (5, (4, 10)), (7, (4, 10)), (9, (2, 6)), (11, (0, 0)),
                   (15, (0, 0))],
        "hand_r": [(0, GR), (7, GR), (8, (-0.3, 2.42, 0.64)), (10, (-0.32, 2.56, 0.8)), (12, (-0.28, 2.7, 0.95)),
                   (14, _add(DHR, (-0.04, 0.035, 0.04))), (15, DHR)],
        "hand_l": [(0, GL), (7, GL), (8, (0.19, 2.5, 0.66)), (9, (0.19, 2.52, 0.72)), (10, (0.19, 2.53, 0.76)),
                   (12, (0.24, 2.72, 0.92)), (14, _add(DHL, (0.03, 0.035, 0.03))), (15, DHL)],
        "face_r": [(0, "deck"), (7, "deck"), (9, "stand"), (15, "stand")],
        "face_l": [(0, "deck"), (7, "deck"), (8, "knee"), (10, "knee"), (12, "stand"), (15, "stand")],
        "pole_r": [(0, HANG["pole_r"]), (3, (-0.4, -0.2, -1.0)), (7, (-0.4, -0.2, -1.0)), (9, (-0.6, -0.4, -0.4)),
                   (12, (-0.4, -0.2, -1.0)), (15, STAND["pole_r"])],
        "pole_l": [(0, HANG["pole_l"]), (3, (0.4, -0.2, -1.0)), (7, (0.4, -0.2, -1.0)), (8, (1.0, 0.2, -0.2)),
                   (10, (1.0, 0.2, -0.2)), (12, (0.4, -0.2, -1.0)), (15, STAND["pole_l"])],
        "grip_r": [(0, HANG["grip_r"]), (7, 0.2), (9, 0.4), (15, 0.4)],
        "grip_l": [(0, HANG["grip_l"]), (7, 0.2), (8, 0.3), (15, 0.4)],
        # (the right foot walks up the face as the knee comes up (f3-f5), hangs from the knee on the nose (f6), is draped back
        # over the nose as the knee rolls onto the deck (f7-f9), then comes up over the nose and steps through; the left foot
        # walks up the face, swings up over the nose and is planted ahead where it will stand)
        "foot_r": [(0, GFR), (1, GFR), (3, (-0.21, 1.46, 0.18)), (4, (-0.23, 1.62, 0.2)), (5, (-0.22, 1.74, 0.24)),
                   (6, (-0.2, 1.72, 0.27)), (7, CLIMB_DRAPE), (9, CLIMB_DRAPE), (10, (-0.17, 2.14, 0.32)),
                   (11, _heel_place((-0.14, 2.28, 0.7), 30)), (12, _heel_place((-0.13, 2.16, 0.88), 10)), (13, DFR), (15, DFR)],
        "foot_l": [(0, GFL), (1, GFL), (3, (0.19, 1.4, 0.17)), (5, (0.21, 1.62, 0.17)), (6, (0.22, 1.8, 0.2)),
                   (7, (0.19, 2.24, 0.52)), (8, DFL), (15, DFL)],
        "heel_r": [(0, HANG["heel_r"]), (3, 20), (5, 30), (6, 30), (7, 20), (9, 20), (10, 40), (11, 30), (12, 10), (13, 0), (14, 5),
                   (15, 0)],
        "heel_l": [(0, HANG["heel_l"]), (3, HANG["heel_l"]), (5, 10), (7, 20), (8, 0), (13, 0), (14, 5), (15, 0)],
        "fyaw_r": [(0, HANG["fyaw_r"]), (5, 10), (6, 4), (9, 4), (11, 4), (15, 7)],
        "fyaw_l": [(0, HANG["fyaw_l"]), (6, 20), (7, 10), (8, 7), (15, 7)],
        "knee_r": [(0, HANG["knee_r"]), (3, (-0.55, 0.2, 0.8)), (5, (-0.4, 0.6, 0.7)), (6, (-0.2, 0.3, 1.0)), (7, (-0.2, -0.3, 1.0)),
                   (9, (-0.2, -0.3, 1.0)), (11, (-0.2, 0.0, 1.0)), (14, "auto")],
        "knee_l": [(0, HANG["knee_l"]), (3, (0.55, 0.2, 0.8)), (6, (0.6, 0.4, 0.6)), (7, (0.4, 0.6, 0.8)), (8, (0.2, 0.3, 1.0)),
                   (9, (0.2, 0.0, 1.0)), (13, "auto")],
    },
    # the edge jump (9 f): a real coil on the face (the hips sink 8 cm, the elbows deep, the knees folded up the face), then
    # the push: the hands drive the deck down and the legs kick off the face (straight, up on the toes), the arms locking
    # straight down by the hips while the hands are still on the deck (f2-f3: the clip takes back the code's carry, `lift`),
    # released at f3: the arms are flung up overhead, the body springs up long past the lip and the knees come up under it as
    # a reaction (from f5), opened out into the fall's balance.  hold_s: the coil; strike_s: the push (the jump); back_s:
    # the arms overhead, opening
    "edge_jump": {
        "length": 9, "base": HANG, "lift": (EDGE_JUMP_VY, EDGE_JUMP_G),
        "meta": dict(EDGE_META, hold_s=1 / FPS, strike_s=2 / FPS, back_s=5 / FPS),
        "lift_w": [(0, 1.0), (3, 1.0), (5, 0.0), (9, 0.0)],
        # (the body over the deck: f0-f3 where the clip holds it, then over the code's carry; the world's path (hang frame) is
        # 0.90, 0.82, 0.95, 1.13, 1.47, 1.78, 2.02, 2.24, 2.45, 2.64: the push the fastest, then gravity's even slowing)
        # (pass 3: the coil 13 cm deep with the elbows folded back and the head dropped; the arms locked straight down at the
        # strike (f2) with the legs driven off the face; the arms swung up wide past the shoulders, open, f3-f5 one arc)
        "root": [(0, HANG["root"]), (1, (0.0, 0.77, 0.02)), (2, (0.0, 1.08, 0.1)), (3, (0.0, 1.085, 0.14)),
                 (4, (0.0, round(1.47 - 0.5 * _rise(4), 3), 0.08)), (5, (0.0, round(1.78 - _rise(5), 3), 0.04)),
                 (6, (0.0, round(2.02 - _rise(6), 3), 0.03)), (7, (0.0, round(2.24 - _rise(7), 3), 0.02)),
                 (8, (0.0, round(2.45 - _rise(8), 3), 0.01)), (9, AIR["root"])],
        # (the hang's sway squared up in the coil, so both arms lock alike in the push)
        "roll": [(0, HANG["roll"]), (2, 0.0), (9, AIR["roll"])], "twist": [(0, HANG["twist"]), (2, 0.0), (9, AIR["twist"])],
        "side": [(0, HANG["side"]), (2, 0.0), (9, AIR["side"])],
        "hips": [(0, HANG["hips"]), (1, 30), (2, 14), (3, 10), (4, -2), (5, -6), (7, 4), (9, AIR["hips"])],
        "chest": [(0, HANG["chest"]), (1, 12), (2, 0), (3, -2), (4, -8), (5, -8), (7, 2), (9, AIR["chest"])],
        "head": [(0, HANG["head"]), (1, -28), (2, -20), (3, -12), (4, -4), (5, 2), (7, 6), (9, AIR["head"])],
        "clav_r": [(0, HANG["clav_r"]), (1, (8, -14)), (2, (0, 14)), (3, (0, 16)), (4, (-4, -14)), (5, (-4, -26)), (7, (0, -16)),
                   (9, AIR["clav_r"])],
        "clav_l": [(0, HANG["clav_l"]), (1, (8, -14)), (2, (0, 14)), (3, (0, 16)), (4, (-4, -14)), (5, (-4, -26)), (7, (0, -16)),
                   (9, AIR["clav_l"])],
        "hand_r": [(0, GR), (3, GR), (4, (-0.45, round(2.58 - 0.5 * _rise(4), 3), 0.24)), (5, (-0.34, 1.8, 0.06)),
                   (7, (-0.5, 1.52, 0.1)), (9, AR)],
        "hand_l": [(0, GL), (3, GL), (4, (0.45, round(2.59 - 0.5 * _rise(4), 3), 0.22)), (5, (0.35, 1.79, 0.04)),
                   (7, (0.51, 1.51, 0.08)), (9, AL)],
        "face_r": [(0, "deck"), (3, "deck"), (4, "fling"), (5, "sky"), (9, "balance")],
        "face_l": [(0, "deck"), (3, "deck"), (4, "fling"), (5, "sky"), (9, "balance")],
        "pole_r": [(0, HANG["pole_r"]), (1, (-0.45, -1.0, -0.7)), (2, (-0.4, -0.2, -1.0)), (3, (-0.4, 0.0, -1.0)), (5, (-1.0, 0.0, 0.0)),
                   (9, AIR["pole_r"])],
        "pole_l": [(0, HANG["pole_l"]), (1, (0.45, -1.0, -0.7)), (2, (0.4, -0.2, -1.0)), (3, (0.4, 0.0, -1.0)), (5, (1.0, 0.0, 0.0)),
                   (9, AIR["pole_l"])],
        "grip_r": [(0, HANG["grip_r"]), (3, 0.1), (4, -0.3), (5, -0.4), (9, AIR["grip_r"])],
        "grip_l": [(0, HANG["grip_l"]), (3, 0.1), (4, -0.3), (5, -0.4), (9, AIR["grip_l"])],
        "foot_r": [(0, GFR), (1, _up(GFR, 0.04)), (2, (-0.13, 1.18, 0.17)), (3, (-0.13, 1.16, 0.16)),
                   (4, (-0.12, round(1.75 - 0.5 * _rise(4), 3), 0.1)), (5, (-0.13, 0.44, 0.12)), (7, (-0.14, 0.38, 0.16)),
                   (9, AFR)],
        "foot_l": [(0, GFL), (1, _up(GFL, 0.04)), (2, (0.13, 1.14, 0.165)), (3, (0.13, 1.14, 0.15)),
                   (4, (0.12, round(1.79 - 0.5 * _rise(4), 3), 0.08)), (5, (0.13, 0.48, 0.06)), (7, (0.14, 0.44, 0.0)),
                   (9, AFL)],
        "heel_r": [(0, HANG["heel_r"]), (1, 4), (2, 50), (3, 56), (4, 60), (5, 45), (7, 35), (9, AIR["heel_r"])],
        "heel_l": [(0, HANG["heel_l"]), (1, 6), (2, 52), (3, 58), (4, 62), (5, 47), (7, 37), (9, AIR["heel_l"])],
        "fyaw_r": [(0, HANG["fyaw_r"]), (3, 4), (9, AIR["fyaw_r"])], "fyaw_l": [(0, HANG["fyaw_l"]), (3, 4), (9, AIR["fyaw_l"])],
        "knee_r": [(0, HANG["knee_r"]), (1, (-0.6, 0.3, 1.0)), (3, (-0.1, 0.0, 1.0)), (5, (-0.2, 0.3, 1.0)), (9, AIR["knee_r"])],
        "knee_l": [(0, HANG["knee_l"]), (1, (0.6, 0.3, 1.0)), (3, (0.1, 0.0, 1.0)), (5, (0.2, 0.3, 1.0)), (9, AIR["knee_l"])],
    },
    # the roll in (22 f, 0.75 s): a dip, then the arms spring the body up over the lip to an apex (f4-f5: the hips over the
    # hands, the knees tucked, the head carried out ahead of the hands, a beat), the hands hop forward and are planted on the
    # deck ahead (f5-f7, the elbows giving), the chin tucked onto the chest and the trunk rolled onto its right side so the
    # right shoulder blade takes the deck (not the head): a forward roll along the diagonal from the right shoulder to the
    # left hip in a tight ball, the hands round the shins from f8 (the code carries him in), the feet come round under him
    # into a crouch and he rises to the stand CLIMB_IN in, a touch past (onto the toes) and settled, the arms two frames
    # behind.  hold_s: the apex over the lip (the code's travel may start); strike_s: the shoulder on the deck; back_s: on his
    # feet again (the travel done)
    "edge_roll": dict({
        "length": 22, "base": HANG, "floor": LIP_Y,
        "meta": dict(EDGE_META, hold_s=5 / FPS, strike_s=7 / FPS, back_s=15 / FPS, end_in=CLIMB_IN),
        # (pass 3: the apex held up over the lip at f4-f5 with the face still forward, the chin tucked from f6; the turn about
        # a higher middle so the hips travel one arc; the ball closed through the turn (the heels at the seat, the knees
        # together); the shoulder-roll twist faded by f8; the head tipped well off the line so the hat clears the deck)
        "flip": [(0, 0), (5, 0), (6, 48), (7, 122), (9, 196), (11, 256), (13, 325), (14, 352), (15, 360), (22, 360)],
        "ground": [(0, 0), (5, 0), (6, 1), (13, 1), (14, 0.5), (15, 0), (22, 0)],
        "pivot": [(0, (0.0, LIP_Y + 0.55, 0.95)), (22, (0.0, LIP_Y + 0.55, 0.95))],
        "root": [(0, HANG["root"]), (1, (0.0, 0.85, 0.0)), (3, (0.0, 1.26, 0.28)), (4, (0.0, 1.48, 0.45)), (5, (0.0, 1.43, 0.63)),
                 (7, (0.0, 1.55, 0.8)), (13, (0.0, 1.55, 0.8)), (15, (0.0, 1.62, 0.92)), (17, (0.0, 1.84, 0.95)),
                 (19, (0.0, 1.997, 0.95)), (21, (0.0, 1.982, 0.95)), (22, DROOT)],
        "hips": [(0, HANG["hips"]), (1, 26), (3, 40), (4, 64), (5, 56), (6, 42), (7, 46), (13, 46), (15, 34), (17, 16), (19, 0),
                 (21, -1), (22, 0)],
        "chest": [(0, HANG["chest"]), (1, 8), (3, 20), (4, 24), (5, 30), (6, 44), (7, 52), (13, 52), (15, 20), (17, 8), (19, -2),
                  (21, 0.5), (22, 0)],
        "head": [(0, HANG["head"]), (1, -20), (3, -12), (4, 10), (5, 10), (6, 50), (7, 88), (12, 88), (13, 60), (15, 18), (17, 6),
                 (19, -2), (21, 0.5), (22, 0)],
        "roll": [(0, HANG["roll"]), (4, 0), (6, 8), (8, 4), (12, 0), (22, 0)],
        "twist": [(0, HANG["twist"]), (4, 0), (5, 6), (6, 26), (8, 12), (12, 0), (22, 0)],
        # (the head turned and tipped away from the right shoulder, off the roll's line, so the shoulder blade meets the deck)
        "tilt": [(0, 0), (4, 0), (5, 8), (6, 15), (9, 15), (12, 0), (22, 0)],
        "side": [(0, HANG["side"]), (4, 0), (6, -20), (9, -20), (12, 0), (22, 0)],
        "look": [(0, HANG["look"]), (4, 0), (6, 75), (9, 75), (12, 0), (22, 0)],
        "clav_r": [(0, HANG["clav_r"]), (3, (4, 6)), (5, (8, 10)), (7, (12, 6)), (13, (12, 6)), (16, (6, 2)), (22, (0, 0))],
        "clav_l": [(0, HANG["clav_l"]), (3, (4, 6)), (5, (8, 10)), (7, (12, 6)), (13, (12, 6)), (16, (6, 2)), (22, (0, 0))],
        "hand_r": [(0, GR), (3, GR), (4, (-0.21, 2.12, 0.7)), (5, (-0.2, DECK_PALM, 0.98)),
                   (6, _unturn((-0.2, DECK_PALM + 0.07, 0.97), 48, (0.0, LIP_Y + 0.55, 0.95))),
                   (7, _unturn((-0.2, DECK_PALM + 0.1, 0.92), 122, (0.0, LIP_Y + 0.55, 0.95))), (9, (-0.16, 2.42, 1.08)),
                   (13, (-0.16, 2.42, 1.08)), (15, (-0.26, 2.62, 1.3)), (18, (-0.25, 2.8, 1.12)), (20, _add(DHR, (-0.025, 0.045, 0.06))),
                   (22, DHR)],
        "hand_l": [(0, GL), (3, GL), (4, (0.21, 2.12, 0.7)), (5, (0.2, DECK_PALM, 0.98)),
                   (6, _unturn((0.2, DECK_PALM + 0.07, 0.97), 48, (0.0, LIP_Y + 0.55, 0.95))),
                   (7, _unturn((0.2, DECK_PALM + 0.1, 0.92), 122, (0.0, LIP_Y + 0.55, 0.95))), (9, (0.16, 2.42, 1.08)),
                   (13, (0.16, 2.42, 1.08)), (15, (0.26, 2.62, 1.28)), (18, (0.25, 2.8, 1.12)), (20, _add(DHL, (0.025, 0.045, 0.06))),
                   (22, DHL)],
        "face_r": [(0, "deck"), (5, "deck"), (6, _unturn_way("deck", 48)), (7, _unturn_way("deck", 122)), (9, "hug"), (13, "hug"),
                   (15, "balance"), (19, "balance"), (21, "stand"), (22, "stand")],
        "face_l": [(0, "deck"), (5, "deck"), (6, _unturn_way("deck", 48, side="l")), (7, _unturn_way("deck", 122, side="l")),
                   (9, "hug"), (13, "hug"),
                   (15, "balance"), (19, "balance"), (21, "stand"), (22, "stand")],
        "pole_r": [(0, HANG["pole_r"]), (3, (-0.4, -0.2, -1.0)), (5, (-0.6, -0.3, -0.5)), (7, (-1.0, 0.2, -0.3)), (9, (-1.0, 0.0, 0.0)),
                   (13, (-1.0, 0.0, 0.0)), (16, (-0.8, -0.5, -0.3)), (22, STAND["pole_r"])],
        "pole_l": [(0, HANG["pole_l"]), (3, (0.4, -0.2, -1.0)), (5, (0.6, -0.3, -0.5)), (7, (1.0, 0.2, -0.3)), (9, (1.0, 0.0, 0.0)),
                   (13, (1.0, 0.0, 0.0)), (16, (0.8, -0.5, -0.3)), (22, STAND["pole_l"])],
        "grip_r": [(0, HANG["grip_r"]), (4, 0.2), (5, 0.1), (7, 0.1), (9, 0.6), (13, 0.6), (15, 0.1), (22, 0.4)],
        "grip_l": [(0, HANG["grip_l"]), (4, 0.2), (5, 0.1), (7, 0.1), (9, 0.6), (13, 0.6), (15, 0.1), (22, 0.4)],
        "foot_r": [(0, GFR), (1, GFR), (3, (-0.2, 1.66, 0.12)), (4, (-0.14, 2.2, 0.3)), (5, (-0.12, 2.22, 0.5)),
                   (6, (-0.12, 2.23, 0.76)), (7, (-0.12, 2.22, 0.75)), (13, (-0.12, 2.22, 0.75)),
                   (15, DFR), (22, DFR)],
        "foot_l": [(0, GFL), (1, GFL), (3, (0.2, 1.62, 0.12)), (4, (0.14, 2.21, 0.29)), (5, (0.12, 2.23, 0.49)),
                   (6, (0.12, 2.23, 0.76)), (7, (0.12, 2.22, 0.75)), (13, (0.12, 2.22, 0.75)),
                   (15, DFL), (22, DFL)],
        "heel_r": [(0, HANG["heel_r"]), (3, 30), (7, 40), (13, 40), (15, 0), (18, 0), (19, 5), (21, 0), (22, 0)],
        "heel_l": [(0, HANG["heel_l"]), (3, 30), (7, 40), (13, 40), (15, 0), (18, 0), (19, 5), (21, 0), (22, 0)],
        "fyaw_r": [(0, HANG["fyaw_r"]), (5, 4), (14, 4), (22, 7)], "fyaw_l": [(0, HANG["fyaw_l"]), (5, 4), (14, 4), (22, 7)],
        "knee_r": [(0, HANG["knee_r"]), (3, (-1.0, 0.3, 0.3)), (4, (-0.5, 0.5, 1.0)), (6, (-0.2, 0.8, 0.6)), (13, (-0.2, 0.8, 0.6)),
                   (16, (-0.25, 0.0, 1.0)), (21, "auto")],
        "knee_l": [(0, HANG["knee_l"]), (3, (1.0, 0.3, 0.3)), (4, (0.5, 0.5, 1.0)), (6, (0.2, 0.8, 0.6)), (13, (0.2, 0.8, 0.6)),
                   (16, (0.25, 0.0, 1.0)), (21, "auto")],
    }),
    # the edge attack (18 f, 0.6 s): a dip and a hard press up, the left hand hopping forward onto the deck and the left foot
    # planted by it in a deep crouch, the right leg stretched out low to the side and the right arm thrown back and up for the
    # balance (the wind-up, the hips turned away); then the low sweep (Northern Shaolin / Hung Gar's ground sweep): the whole
    # trunk turns over the bent left leg, the head low and the eyes along the sweep, the straight right leg swept round flat
    # along the deck from the right side across the front to the left, slowing at its end, the right arm whipping across the
    # other way as the counterweight (overshooting, settling); the leg drawn in under him and stood up CLIMB_IN in.
    # hold_s: crouched, the leg out; strike_s: the sweep straight ahead; back_s: the leg at the end of the sweep
    "edge_attack": {
        "length": 18, "base": HANG,
        "meta": dict(EDGE_META, hold_s=6 / FPS, strike_s=9 / FPS, back_s=12 / FPS, end_in=CLIMB_IN, hand="foot_r"),
        "root": [(0, HANG["root"]), (1, (0.0, 0.85, 0.0)), (3, (0.0, 1.12, 0.14)), (4, (0.0, 1.27, 0.34)), (5, (0.0, 1.39, 0.56)),
                 (6, (0.02, 1.405, 0.66)), (7, (-0.03, 1.37, 0.74)), (8, (-0.02, 1.35, 0.82)), (9, (0.02, 1.35, 0.86)),
                 (10, (0.07, 1.35, 0.84)), (11, (0.18, 1.34, 0.8)), (12, (0.14, 1.44, 0.78)),
                 (14, (0.0, 1.84, 0.9)), (16, (0.0, 1.997, 0.95)), (17, (0.0, 1.983, 0.95)), (18, DROOT)],
        "yaw": [(0, 0), (5, -8), (6, -20), (8, -6), (9, 10), (11, 45), (12, 42), (14, 12), (16, -2), (18, 0)],
        "hips": [(0, HANG["hips"]), (1, 26), (3, 30), (5, 54), (6, 60), (9, 60), (11, 56), (12, 48), (14, 16), (16, 1), (18, 0)],
        "chest": [(0, HANG["chest"]), (1, 8), (3, 16), (5, 22), (6, 22), (8, 18), (10, 18), (11, 18), (12, 14), (14, 6), (16, -2),
                  (18, 0)],
        "side": [(0, HANG["side"]), (5, 10), (6, 20), (9, 20), (11, 21), (12, 12), (14, 2), (18, 0)],
        "head": [(0, HANG["head"]), (1, -20), (3, -20), (5, -28), (6, -30), (9, -26), (12, -22), (14, -6), (16, 1), (18, 0)],
        "look": [(0, HANG["look"]), (6, -10), (8, 4), (9, 12), (11, 20), (13, 8), (16, 0), (18, 0)],
        "clav_r": [(0, HANG["clav_r"]), (3, (4, 6)), (6, (-4, -10)), (10, (8, -4)), (12, (4, -2)), (15, (2, 2)), (18, (0, 0))],
        "clav_l": [(0, HANG["clav_l"]), (3, (4, 6)), (6, (10, 24)), (11, (10, 28)), (12, (10, 22)), (15, (2, 2)), (18, (0, 0))],
        "hand_r": [(0, GR), (3, GR), (4, (-0.34, 2.36, 0.72)), (6, (-0.54, 2.66, 0.66)), (8, (-0.37, 2.64, 0.8)), (10, (0.1, 2.5, 1.0)),
                   (11, (0.14, 2.5, 1.0)), (12, (0.17, 2.53, 0.98)), (14, (-0.18, 2.7, 1.02)), (16, _add(DHR, (-0.02, 0.03, 0.03))),
                   (18, DHR)],
        "hand_l": [(0, GL), (3, GL), (4, (0.22, 2.2, 0.8)), (5, (0.145, 2.05, 0.97)), (10, (0.145, 2.05, 0.97)), (11, (0.18, 2.12, 0.975)),
                   (13, (0.26, 2.5, 1.0)), (14, (0.28, 2.72, 1.06)), (16, _add(DHL, (0.0, 0.03, 0.02))), (18, DHL)],
        "face_r": [(0, "deck"), (3, "deck"), (5, "balance"), (12, "balance"), (15, "stand"), (18, "stand")],
        "face_l": [(0, "deck"), (3, "deck"), (5, "deck_out"), (12, "deck_out"), (15, "stand"), (18, "stand")],
        "pole_r": [(0, HANG["pole_r"]), (3, (-0.4, -0.2, -1.0)), (5, (-0.6, -0.6, -0.4)), (10, (-0.2, -1.0, -0.2)),
                   (12, (-0.4, -0.8, -0.3)), (18, STAND["pole_r"])],
        "pole_l": [(0, HANG["pole_l"]), (3, (0.4, -0.2, -1.0)), (5, (1.0, 0.0, -0.3)), (12, (1.0, 0.0, -0.3)),
                   (18, STAND["pole_l"])],
        "grip_r": [(0, HANG["grip_r"]), (4, -0.2), (6, 0.1), (12, 0.1), (15, 0.4), (18, 0.4)],
        "grip_l": [(0, HANG["grip_l"]), (4, -0.2), (5, 0.1), (12, 0.1), (15, 0.4), (18, 0.4)],
        # (the right leg: up the face, stretched out low to the side, swept round flat at the shin's height over the deck from
        # the right across the front to the left of the planted left foot, slowing at its end, then lifted in over the left
        # foot and drawn in under him; the left foot planted under him in the crouch)
        # (pass 3: swept round at full leg length, about 0.85 m from the planted left foot, through about 160 degrees)
        "foot_r": [(0, GFR), (1, GFR), (3, (-0.24, 1.48, 0.16)), (4, (-0.42, 1.92, 0.22)), (5, (-0.5, 2.14, 0.44)), (6, (-0.66, 2.1, 0.62)),
                   (7, (-0.7, 2.1, 1.02)), (8, (-0.52, 2.1, 1.32)), (9, (-0.08, 2.1, 1.52)), (10, (0.34, 2.1, 1.42)),
                   (11, (0.69, 2.1, 1.12)), (12, (0.72, 2.1, 0.84)), (13, (0.45, 2.22, 0.98)), (14, (-0.05, 2.16, 0.95)), (16, DFR),
                   (18, DFR)],
        "foot_l": [(0, GFL), (2, GFL), (3, (0.2, 1.38, 0.17)), (4, (0.2, 1.96, 0.26)), (5, (0.17, 2.077, 0.7)), (12, (0.17, 2.077, 0.7)),
                   (14, (0.15, 2.077, 0.82)), (16, DFL), (18, DFL)],
        "heel_r": [(0, HANG["heel_r"]), (3, 10), (5, 30), (6, 20), (11, 20), (12, 24), (14, 10), (16, 0), (18, 0)],
        "heel_l": [(0, HANG["heel_l"]), (3, HANG["heel_l"]), (5, 0), (14, 0), (16, 4), (17, 0), (18, 0)],
        "fyaw_r": [(0, HANG["fyaw_r"]), (5, -10), (11, -10), (16, 7)], "fyaw_l": [(0, HANG["fyaw_l"]), (5, 30), (12, 30), (16, 7)],
        "knee_r": [(0, HANG["knee_r"]), (3, (-1.0, 0.2, 0.3)), (5, (-0.3, 1.0, 0.2)), (12, (-0.3, 1.0, 0.2)), (14, (-0.2, 0.0, 1.0)),
                   (17, "auto")],
        "knee_l": [(0, HANG["knee_l"]), (3, (1.0, 0.2, 0.3)), (4, (1.0, 0.5, 0.4)), (5, (0.6, 0.2, 1.0)), (12, (0.6, 0.2, 1.0)), (15, "auto")],
    },
}
# (the hang's own sway at its first frame, the trunk's roll, side bend and twist and the head's glance, eased out over the
# first two thirds of a get-up, which ends on the stand, or of the jump, which ends on the fall, where a clip leaves them out)
for _k in ("edge_climb", "edge_roll", "edge_attack", "edge_jump"):
    _end = AIR if _k == "edge_jump" else STAND
    _n = SET5[_k]["length"]
    for _ch in ("roll", "side", "twist", "look"):
        if _ch not in SET5[_k]:
            SET5[_k][_ch] = [(0, HANG[_ch]), (_n * 2 // 3, _end[_ch]), (_n, _end[_ch])]
CLIPS.update(SET5)


## The ground rolls' tucked ball (the figure upright as if squatting; the flip or the cart turns it about ROLL_PIVOT): the hips
## sunk to the heels, the back rounded over the knees, the chin tucked onto the chest, the knees drawn in to it, the hands
## round the shins.
ROLL_PIVOT = (0.0, 0.5, 0.18)
TUCK = {"root": (0.0, -0.45, 0.05), "hips": 48.0, "chest": 44.0, "head": 85.0, "clav": (10.0, 6.0),
        "hand_r": (-0.15, 0.37, 0.38), "foot_r": (-0.12, 0.2, 0.1), "heel": 34.0}
## The forward roll's closed ball (pass 3; the same upright squat frame): the back rounder, the heels at the seat under the
## hips and the knees lifted up to the chest (their poles up and ahead), the hands on the shins.
BALL = {"chest": 54.0, "foot_r": (-0.12, 0.22, 0.0), "hand_r": (-0.16, 0.42, 0.32), "knee_r": (-0.2, 0.8, 0.6)}
## The rise out of a roll: a crouch on both feet, the arms out ahead for the balance.
CROUCH = {"root": (0.0, -0.4, 0.05), "hips": 30.0, "chest": 14.0, "head": 8.0, "hand_r": (-0.24, 0.62, 0.42)}
## The forward and the back roll's turn at every frame of the roll (deg; the side roll's cart its own, below).
ROLL_TURN = [(0, 0), (2, 0), (3, 30), (4, 66), (5, 105), (6, 148), (7, 190), (8, 228), (9, 262), (10, 295), (11, 325), (12, 350),
             (13, 360), (18, 360)]
## The side roll's cart: tipped onto the right shoulder and hip (f3-f6), three quarters onto the back at the strike (f7),
## quickening over the back and the left side, up.
SIDE_TURN = [(0, 0), (2, 0), (3, 30), (4, 70), (5, 100), (6, 124), (7, 145), (8, 185), (9, 230), (10, 280), (11, 320), (12, 350),
             (13, 360), (18, 360)]
## The deck's palm (a palm laid flat on the floor of a ground roll).
FLOOR_PALM = 0.03


def _roll(kind):
    """A ground roll (18 f, facing kept; kind "f", "b" or "side"): dropped into the ball (f0-f2), turned whole through 360
    degrees over f3-f13 on the deck (the ground contact: its lowest surface kept on the deck), the feet planted at f13 (the
    side roll's left at f12) in a crouch, risen to the stand by f17 a touch past it (onto the toes) and settled at f18, the
    arms two frames behind the trunk."""
    sign = -1 if kind == "b" else 1
    turn = "cart" if kind == "side" else "flip"
    table = SIDE_TURN if kind == "side" else ROLL_TURN
    t = [(fr, v * sign) for fr, v in table]
    # (the forward roll's ball: the heels drawn in at the seat and the knees lifted to the chest, the hands on the shins)
    hr, hl = BALL["hand_r"], _mx(BALL["hand_r"])
    fr, fl = BALL["foot_r"], _mx(BALL["foot_r"])
    c = {
        "length": 18, "pivot": [(0, ROLL_PIVOT), (18, ROLL_PIVOT)],
        "meta": {"hold_s": 2 / FPS, "strike_s": 7 / FPS, "back_s": 13 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        turn: t,
        "ground": [(0, 0), (2, 0), (3, 1), (12, 1), (13, 0), (18, 0)],
        # (pass 3: the drop eased in over f0-f3 behind a short step of the right foot, the palms planted at f2-f3; the ball held
        # closed through the turn (the feet at the seat, no letting out), the shoulder roll's twist and roll halved so the legs
        # stay together upside down)
        "root": [(0, STAND["root"]), (1, (0.0, -0.12, 0.06)), (2, (0.0, -0.32, 0.12)), (3, TUCK["root"]), (12, TUCK["root"]),
                 (13, CROUCH["root"]), (15, (0.0, -0.16, 0.02)), (16, (0.0, -0.035, 0.0)), (17, (0.0, -0.004, 0.0)),
                 (18, STAND["root"])],
        "hips": [(0, 0), (1, 12), (2, 36), (3, TUCK["hips"]), (12, TUCK["hips"]), (13, CROUCH["hips"]), (15, 12), (16, 2), (17, -1),
                 (18, 0)],
        "chest": [(0, 0), (1, 8), (2, 32), (3, BALL["chest"]), (12, BALL["chest"]), (13, CROUCH["chest"]), (15, 5), (16, 0),
                  (17, -2), (18, 0)],
        "head": [(0, 0), (1, 10), (2, 34), (3, 70), (4, TUCK["head"]), (11, TUCK["head"]), (12, 60), (13, 14), (15, 3), (18, 0)],
        # (the shoulder roll's diagonal: the trunk rolled onto its right side, so the right shoulder blade meets the deck and
        # the roll runs over the back to the left hip)
        "roll": [(0, 0), (2, 0), (3, 2), (4, 4), (9, 4), (12, 0), (18, 0)],
        "twist": [(0, 0), (2, 4), (3, 10), (4, 14), (9, 14), (12, 0), (18, 0)],
        # (the head turned and tipped away from that shoulder, off the roll's line)
        "tilt": [(0, 0), (2, 0), (3, 20), (4, 40), (9, 40), (12, 0), (18, 0)],
        "look": [(0, 0), (2, 0), (4, 20), (9, 20), (12, 0), (18, 0)],
        "clav_r": [(0, (0, 0)), (2, (18, 8)), (3, (22, 6)), (9, (22, 6)), (12, TUCK["clav"]), (14, (4, 2)), (18, (0, 0))],
        "clav_l": [(0, (0, 0)), (2, (18, 8)), (3, TUCK["clav"]), (12, TUCK["clav"]), (14, (4, 2)), (18, (0, 0))],
        # (the palms on the deck ahead of the feet at the drop, the elbows giving as he goes over them, then round the shins)
        "hand_r": [(0, HR), (1, (-0.215, 0.71, 0.28)), (2, (-0.2, 0.36, 0.5)),
                   (3, _unturn((-0.22, FLOOR_PALM, 0.42), 30, ROLL_PIVOT)),
                   (4, _unturn((-0.22, -0.03, 0.36), 66, ROLL_PIVOT)), (5, _unturn((-0.24, -0.01, 0.28), 105, ROLL_PIVOT)), (7, hr),
                   (12, hr), (13, CROUCH["hand_r"]),
                   (15, (-0.26, 0.71, 0.32)), (16, (-0.24, 0.83, 0.19)), (17, (-0.21, 0.8, 0.11)), (18, HR)],
        "hand_l": [(0, HL), (1, (0.22, 0.7, 0.28)), (2, (0.2, 0.37, 0.5)),
                   (3, _unturn((0.22, FLOOR_PALM, 0.42), 30, ROLL_PIVOT)),
                   (4, _unturn((0.22, -0.03, 0.36), 66, ROLL_PIVOT)), (5, _unturn((0.24, 0.0, 0.28), 105, ROLL_PIVOT)), (7, hl),
                   (12, hl), (13, _mx(CROUCH["hand_r"])),
                   (15, (0.26, 0.72, 0.32)), (16, (0.24, 0.83, 0.19)), (17, (0.21, 0.8, 0.11)), (18, HL)],
        "face_r": [(0, "stand"), (1, "palm_down"), (2, "deck"), (3, _unturn_way("deck", 30)), (4, _unturn_way("deck", 66)),
                   (5, _unturn_way("deck", 105)), (7, "hug"), (12, "hug"),
                   (13, "balance"), (16, "balance"), (18, "stand")],
        "face_l": [(0, "stand"), (1, "palm_down"), (2, "deck"), (3, _unturn_way("deck", 30, side="l")),
                   (4, _unturn_way("deck", 66, side="l")), (5, _unturn_way("deck", 105, side="l")), (7, "hug"), (12, "hug"),
                   (13, "balance"), (16, "balance"), (18, "stand")],
        "pole_r": [(0, STAND["pole_r"]), (2, (-0.8, -0.2, -0.4)), (3, (-1.0, 0.0, -0.2)), (5, (-1.0, -0.2, 0.0)), (12, (-1.0, -0.2, 0.0)),
                   (14, (-0.8, -0.5, -0.3)), (18, STAND["pole_r"])],
        "pole_l": [(0, STAND["pole_l"]), (2, (0.8, -0.2, -0.4)), (3, (1.0, 0.0, -0.2)), (5, (1.0, -0.2, 0.0)), (12, (1.0, -0.2, 0.0)),
                   (14, (0.8, -0.5, -0.3)), (18, STAND["pole_l"])],
        "grip_r": [(0, 0.4), (2, 0.0), (5, 0.0), (7, 0.6), (12, 0.6), (13, 0.15), (18, 0.4)],
        "grip_l": [(0, 0.4), (2, 0.0), (5, 0.0), (7, 0.6), (12, 0.6), (13, 0.15), (18, 0.4)],
        # (the lead-in: the right foot steps 15 cm forward at f1-f2; then both feet held at the seat through the turn)
        "foot_r": [(0, FR), (1, _add(FR, (0.0, 0.05, 0.08))), (2, _add(FR, (0.0, 0.0, 0.15))), (3, fr), (11, fr),
                   (13, FR), (18, FR)],
        "foot_l": [(0, FL), (2, FL), (3, fl), (11, fl), (13, FL), (18, FL)],
        "heel_r": [(0, 0), (1, 20), (2, 10), (3, TUCK["heel"]), (11, TUCK["heel"]), (13, 0), (16, 0), (17, 4), (18, 0)],
        "heel_l": [(0, 0), (2, 25), (3, TUCK["heel"]), (11, TUCK["heel"]), (13, 0), (16, 0), (17, 4), (18, 0)],
        "knee_r": [(0, "auto"), (2, (-0.25, 0.0, 1.0)), (3, BALL["knee_r"]), (11, BALL["knee_r"]), (13, (-0.25, 0.0, 1.0)),
                   (14, (-0.25, 0.0, 1.0)), (17, "auto")],
        "knee_l": [(0, "auto"), (2, (0.25, 0.0, 1.0)), (3, _mx(BALL["knee_r"])), (11, _mx(BALL["knee_r"])), (13, (0.25, 0.0, 1.0)),
                   (14, (0.25, 0.0, 1.0)), (17, "auto")],
    }
    if kind == "b":
        # (sat back: the trunk stays up over the seat, the back rounded and the chin in, the hands up by the ears from the drop
        # and the knees pulled in to the chest by f5; upside down the palms are planted by the head (the elbows up) and the arms
        # push (f9-f11), lifting the head clear while the legs pike over in an arc and the feet plant at f12)
        c["roll"] = [(0, 0), (18, 0)]
        # (pass 3: over the top quicker at the end, so the head is up off the deck before the feet land)
        c["flip"] = [(fr, v) for fr, v in t if fr < 10] + [(10, -310), (11, -345), (12, -358), (13, -360), (18, -360)]
        for k in ("tilt", "look", "twist"):
            c.pop(k)
        c["root"] = [(0, STAND["root"]), (1, (0.0, -0.14, -0.04)), (2, (0.0, -0.36, -0.1)), (3, TUCK["root"]), (12, TUCK["root"]),
                     (13, CROUCH["root"]), (15, (0.0, -0.16, 0.02)), (16, (0.0, -0.035, 0.0)), (17, (0.0, -0.004, 0.0)),
                     (18, STAND["root"])]
        c["hips"] = [(0, 0), (1, 4), (2, 12), (3, 30), (12, 30), (13, CROUCH["hips"]), (15, 12), (16, 2), (17, -1), (18, 0)]
        c["chest"] = [(0, 0), (1, 10), (2, 26), (3, TUCK["chest"]), (12, TUCK["chest"]), (13, CROUCH["chest"]), (15, 5), (16, 0),
                      (17, -2), (18, 0)]
        # (pass 3: the knees drawn together to the chest (f5-f7) and the hands kept by the ears, compact; the palms planted from
        # f7 and the head pitched further in, so the push lifts the hat clear of the deck)
        c["head"] = [(0, 0), (1, 10), (2, 24), (3, 34), (6, 48), (7, 65), (10, 65), (11, 35), (12, 18), (13, 8), (15, 3), (18, 0)]
        c["knee_r"] = [(0, "auto"), (2, (-0.15, 0.0, 1.0)), (14, (-0.15, 0.0, 1.0)), (17, "auto")]
        c["knee_l"] = [(0, "auto"), (2, (0.15, 0.0, 1.0)), (14, (0.15, 0.0, 1.0)), (17, "auto")]
        c["pole_r"] = [(0, STAND["pole_r"]), (2, (-1.0, 0.0, 0.4)), (5, (-0.6, 0.0, 1.0)), (11, (-0.6, 0.0, 1.0)),
                       (14, (-0.8, -0.5, -0.3)), (18, STAND["pole_r"])]
        c["pole_l"] = [(0, STAND["pole_l"]), (2, (1.0, 0.0, 0.4)), (5, (0.6, 0.0, 1.0)), (11, (0.6, 0.0, 1.0)),
                       (14, (0.8, -0.5, -0.3)), (18, STAND["pole_l"])]
        for s, hx in (("r", -0.2), ("l", 0.2)):
            c["hand_" + s] = [(0, STAND["hand_" + s]), (1, (hx * 1.1, 0.98, 0.14)), (2, (hx, 0.95, 0.04)), (4, (hx, 1.0, 0.24)),
                              (5, (hx, 0.98, 0.3)), (6, (hx, 0.97, 0.32)),
                              (7, _unturn((hx, -0.02, 0.06), -190, ROLL_PIVOT)),
                              (8, _unturn((hx, -0.02, 0.14), -228, ROLL_PIVOT)), (9, _unturn((hx, -0.05, 0.3), -262, ROLL_PIVOT)),
                              (10, _unturn((hx, -0.03, 0.42), -295, ROLL_PIVOT)), (11, (hx, 1.02, 0.42)), (12, (hx * 1.2, 0.72, 0.42)), (13, (hx * 1.2, 0.62, 0.42)),
                              (15, (hx * 1.3, 0.71, 0.32)), (16, (hx * 1.2, 0.83, 0.19)), (17, (hx * 1.05, 0.8, 0.11)),
                              (18, STAND["hand_" + s])]
            c["face_" + s] = [(0, "stand"), (1, "ears"), (11, "ears"), (13, "balance"), (16, "balance"), (18, "stand")]
            c["grip_" + s] = [(0, 0.4), (2, 0.0), (11, 0.0), (13, 0.15), (18, 0.4)]
        for s, fx in (("r", -0.12), ("l", 0.12)):
            c["foot_" + s] = [(0, STAND["foot_" + s]), (2, STAND["foot_" + s]), (4, (fx, 0.3, 0.12)), (5, (fx, 0.45, 0.3)),
                              (7, (fx, 0.6, 0.46)), (9, (fx, 0.74, 0.5)), (10, (fx, 0.62, 0.44)), (11, (fx, 0.34, 0.22)),
                              (12, STAND["foot_" + s]), (18, STAND["foot_" + s])]
            c["heel_" + s] = [(0, 0), (2, 25), (4, 40), (11, 40), (12, 8), (13, 0), (16, 0), (17, 4), (18, 0)]
    if kind == "side":
        # (the weight shifted over the right foot first and the right hand reaching down beside it to take the deck; tipped
        # onto the right shoulder and hip, the back curled to the left so the knees draw toward the left shoulder, kept low
        # and across the body; three quarters onto the back at the strike, quickening over; the left leg lands first, then
        # the right, the hips settling a touch past to the left)
        # (pass 3: the weight shift reads first: the hips carried out over the right foot and the trunk leant to the right
        # (f1-f2), the left leg long, so he topples sideways over the right foot instead of diving forward; then a flat barrel
        # low on the deck, the thighs laid across the belly toward the left shoulder (the knees across and down, not up);
        # the head curled to the up side, the cheek clear; the cart easing into its quickening)
        c["root"] = [(0, STAND["root"]), (1, (-0.1, -0.12, 0.03)), (2, (-0.25, -0.34, 0.05)), (3, (-0.17, -0.45, 0.05)), (5, (-0.04, -0.45, 0.05)),
                     (12, TUCK["root"]), (13, CROUCH["root"]), (14, (0.04, -0.25, 0.03)), (15, (0.01, -0.15, 0.02)),
                     (16, (0.0, -0.035, 0.0)), (17, (0.0, -0.004, 0.0)), (18, STAND["root"])]
        c["roll"] = [(0, 0), (1, 6), (2, 14), (4, 10), (8, 0), (18, 0)]
        for k in ("tilt", "look", "twist"):
            c.pop(k)
        c["hips"] = [(0, 0), (1, 10), (2, 25), (3, 48), (5, 56), (12, 56), (13, CROUCH["hips"]), (15, 12), (16, 2), (17, -1),
                     (18, 0)]
        c["chest"] = [(0, 0), (1, 6), (2, 18), (3, 36), (5, TUCK["chest"]), (12, TUCK["chest"]), (13, CROUCH["chest"]), (15, 5),
                      (16, 0), (17, -2), (18, 0)]
        c["side"] = [(0, 0), (1, -6), (2, -10), (3, -10), (4, -16), (8, -16), (10, -6), (12, 0), (18, 0)]
        c["head"] = [(0, 0), (1, 6), (2, 18), (3, 50), (4, 72), (11, 72), (12, 50), (13, 14), (15, 3), (18, 0)]
        c["hand_r"] = [(0, HR), (1, (-0.3, 0.71, 0.15)), (2, (-0.43, 0.45, 0.19)),
                       (3, _unturn((-0.37, FLOOR_PALM + 0.07, 0.17), 30, ROLL_PIVOT, "z")), (5, (-0.06, 0.37, 0.38)), (12, (-0.06, 0.37, 0.38)),
                       (13, CROUCH["hand_r"]), (15, (-0.26, 0.71, 0.32)), (16, (-0.24, 0.83, 0.19)), (17, (-0.21, 0.8, 0.11)), (18, HR)]
        c["hand_l"] = [(0, HL), (1, (0.22, 0.7, 0.2)), (2, (0.15, 0.56, 0.36)), (4, (0.24, 0.37, 0.38)), (12, (0.24, 0.37, 0.38)),
                       (13, _mx(CROUCH["hand_r"])), (15, (0.26, 0.72, 0.32)), (16, (0.24, 0.83, 0.19)), (17, (0.21, 0.8, 0.11)), (18, HL)]
        c["face_r"] = [(0, "stand"), (1, "palm_down"), (2, "deck"), (3, _unturn_way("deck", 30, "z")), (5, "hug"), (12, "hug"),
                       (13, "balance"), (16, "balance"), (18, "stand")]
        c["face_l"] = [(0, "stand"), (2, "hug"), (12, "hug"), (13, "balance"), (16, "balance"), (18, "stand")]
        c["foot_r"] = [(0, FR), (2, FR), (4, (0.05, 0.27, 0.1)), (5, (0.05, 0.25, 0.12)), (11, (0.05, 0.25, 0.12)), (13, FR),
                       (18, FR)]
        c["foot_l"] = [(0, FL), (1, _add(FL, (0.03, 0.02, 0.0))), (2, _add(FL, (0.06, 0.04, -0.02))), (4, (0.22, 0.3, 0.04)),
                       (5, (0.2, 0.28, 0.05)), (10, (0.2, 0.28, 0.05)), (12, FL), (18, FL)]
        c["heel_r"] = [(0, 0), (2, 15), (4, TUCK["heel"]), (11, TUCK["heel"]), (13, 0), (16, 0), (17, 4), (18, 0)]
        c["heel_l"] = [(0, 0), (1, 10), (2, 30), (4, TUCK["heel"]), (10, TUCK["heel"]), (12, 0), (16, 0), (17, 4), (18, 0)]
        c["knee_r"] = [(0, "auto"), (2, (-0.1, 0.2, 1.0)), (4, (0.9, 0.3, 0.3)), (11, (0.9, 0.3, 0.3)), (14, (-0.25, 0.0, 1.0)),
                       (17, "auto")]
        c["knee_l"] = [(0, "auto"), (1, (0.15, 0.0, 1.0)), (2, (0.1, -0.1, 1.0)), (4, (0.9, 0.3, 0.3)), (10, (0.9, 0.3, 0.3)),
                       (13, (0.25, 0.0, 1.0)), (17, "auto")]
        c["meta"] = dict(c["meta"], travel="right")
        c["mirror"] = True
    return c


## The duck's forearms: in tight against the chest, the hands by the sides of the head, the fingers up, the palms in.
FACING["cover"] = ((0.12, 0.92, -0.36), (1.0, 0.0, 0.12))
## The duck's open guard (pass 3): the forearms up before the face, the fingers up and back with the sway, the palms out.
FACING["guard_out"] = ((0.15, 0.9, -0.4), (0.1, 0.4, 0.91))

SET5B = {
    # the forward roll (18 f; 3.5 m in 0.45 s by the code, facing kept): sunk into a crouch with the palms laid on the deck
    # ahead (the elbows giving), the chin tucked onto the chest; a shoulder roll: over the right shoulder blade and the
    # rounded back to the left hip in a tight ball; the feet come round under him and plant at the travel's end in a crouch;
    # up to the stand, a touch past and settled.  hold_s: the drop; strike_s: on the back; back_s: on his feet
    "roll_f": _roll("f"),
    # the back roll (18 f, facing kept): sat back into a crouch, the hands up by the ears and the knees in to the chest;
    # rolled back over the rounded back and the shoulders, the palms planted by the head pushing (the head kept clear) as the
    # legs pike over in an arc; the feet planted in a crouch, up
    "roll_b": _roll("b"),
    # the side roll (18 f, to his right; its twin to the left; facing kept): the weight over the right foot and the right hand
    # down beside it, tipped onto the right shoulder and hip, rolled over the back with the knees across the body toward the
    # left shoulder, kept low, and up off the left leg first, then the right
    "roll_side": _roll("side"),
    # the duck (14 f; intangible 0.04-0.30 s by the code): a deep sway down and back: the knees bend deep and drive forward
    # over the toes, the hips drop fast (most of the way by f2) and the trunk sways back from them (the root a little forward
    # to keep the weight over the feet), the head drawn down and back, the forearms pulled in tight to the chest with the
    # hands by the sides of the head; a moving hold at the bottom (the head still sinking, the chest drifting back), the head
    # leading the return at f8; the chest coming up a touch past and settling, the hands a frame or two behind it, a last
    # small dip in the knees.  hold_s: going down; strike_s: the lowest; back_s: the return
    "duck": {
        "length": 14,
        "meta": {"hold_s": 3 / FPS, "strike_s": 4 / FPS, "back_s": 9 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        # (pass 3: the mass kept over the mid-foot (the root forward 13 cm, the knees driven out over the toes); a moving hold:
        # still sinking f4-f8, the chest drifting back and caught; the shoulders turned 15 degrees at the bottom, a slip, not a
        # flinch; the hands open, palms out, the forearms a guard before the face, a frame or two behind the chest each way)
        "root": [(0, STAND["root"]), (1, (0.0, -0.13, 0.04)), (2, (0.0, -0.31, 0.08)), (3, (0.0, -0.41, 0.1)),
                 (4, (0.0, -0.45, 0.11)), (6, (0.0, -0.48, 0.115)), (8, (0.0, -0.5, 0.115)), (9, (0.0, -0.46, 0.105)),
                 (11, (0.0, -0.15, 0.04)), (12, (0.0, -0.012, 0.0)), (13, (0.0, -0.027, -0.004)), (14, STAND["root"])],
        "hips": [(0, 0), (1, 2), (2, -7), (3, -14), (4, -18), (8, -19), (9, -16), (11, -3), (12, 1), (14, 0)],
        "chest": [(0, 0), (1, -4), (2, -17), (3, -28), (4, -34), (6, -38), (8, -36), (9, -31), (11, -8), (12, 3), (13, 1.5), (14, 0)],
        "twist": [(0, 0), (3, 4), (5, 12), (7, 15), (9, 11), (11, 2), (13, -1), (14, 0)],
        "head": [(0, 0), (1, 6), (2, 18), (3, 26), (4, 30), (7, 32), (8, 30), (9, 24), (11, 10), (13, 2), (14, 0)],
        "clav_r": [(0, (0, 0)), (2, (6, -4)), (3, (10, -8)), (5, (14, -10)), (9, (14, -10)), (12, (4, 0)), (14, (0, 0))],
        "clav_l": [(0, (0, 0)), (2, (6, -4)), (3, (10, -8)), (5, (14, -10)), (9, (14, -10)), (12, (4, 0)), (14, (0, 0))],
        "hand_r": [(0, HR), (1, (-0.21, 0.84, 0.16)), (2, (-0.18, 0.92, 0.16)), (3, (-0.14, 0.95, 0.12)), (4, (-0.12, 0.92, 0.06)),
                   (5, (-0.11, 0.89, 0.03)), (8, (-0.11, 0.87, 0.02)), (9, (-0.11, 0.88, 0.03)), (10, (-0.12, 0.92, 0.06)),
                   (11, (-0.14, 1.06, 0.12)), (12, (-0.2, 1.02, 0.12)), (13, (-0.21, 0.88, 0.09)), (14, HR)],
        "hand_l": [(0, HL), (1, (0.21, 0.85, 0.16)), (2, (0.18, 0.93, 0.16)), (3, (0.14, 0.96, 0.12)), (4, (0.12, 0.93, 0.06)),
                   (5, (0.11, 0.9, 0.03)), (8, (0.11, 0.88, 0.02)), (9, (0.11, 0.89, 0.03)), (10, (0.12, 0.93, 0.06)),
                   (11, (0.14, 1.07, 0.12)), (12, (0.2, 1.03, 0.12)), (13, (0.21, 0.89, 0.09)), (14, HL)],
        "face_r": [(0, "stand"), (3, "guard_out"), (10, "guard_out"), (13, "stand"), (14, "stand")],
        "face_l": [(0, "stand"), (3, "guard_out"), (10, "guard_out"), (13, "stand"), (14, "stand")],
        "pole_r": [(0, STAND["pole_r"]), (2, (-0.5, -1.0, 0.3)), (10, (-0.5, -1.0, 0.3)), (13, STAND["pole_r"]), (14, STAND["pole_r"])],
        "pole_l": [(0, STAND["pole_l"]), (2, (0.5, -1.0, 0.3)), (10, (0.5, -1.0, 0.3)), (13, STAND["pole_l"]), (14, STAND["pole_l"])],
        "grip_r": [(0, 0.4), (3, 0.1), (10, 0.1), (14, 0.4)], "grip_l": [(0, 0.4), (3, 0.1), (10, 0.1), (14, 0.4)],
        "foot_r": [(0, FR), (14, FR)], "foot_l": [(0, FL), (14, FL)],
        # (up onto the balls of the feet as the knees drive out over the toes, the balls planted; down again on the return)
        "heel_r": [(0, 0), (1, 4), (2, 16), (3, 26), (4, 30), (9, 30), (11, 10), (12, 0), (14, 0)],
        "heel_l": [(0, 0), (1, 4), (2, 16), (3, 26), (4, 30), (9, 30), (11, 10), (12, 0), (14, 0)],
        "knee_r": [(0, "auto"), (2, (-0.6, 0.2, 0.9)), (11, (-0.6, 0.2, 0.9)), (13, "auto")],
        "knee_l": [(0, "auto"), (2, (0.6, 0.2, 0.9)), (11, (0.6, 0.2, 0.9)), (13, "auto")],
    },
}
CLIPS.update(SET5B)


## The installed names (install_bend.gd reads them from the json): own-bend-<element | throw | knock>-<name>, the mirrored twin
## with -l.
def game_name(key):
    if key.endswith("_l"):
        return "own-bend-" + key[:-2].replace("_", "-") + "-l"
    return "own-bend-" + key.replace("_", "-")


# ---------------------------------------------------------------- interpolation
def _cubic(xs, ys, x):
    """A monotone cubic (Fritsch-Carlson) through the keys: no overshoot, and the motion carries through a key unless the
    neighbours hold it (a value repeated)."""
    n = len(xs)
    if n == 1 or x <= xs[0]:
        return ys[0]
    if x >= xs[-1]:
        return ys[-1]
    d = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(n - 1)]
    m = [d[0]] + [0.0 if d[i - 1] * d[i] <= 0 else (d[i - 1] + d[i]) / 2 for i in range(1, n - 1)] + [d[-1]]
    m[0] = 0.0
    m[-1] = 0.0
    for i in range(n - 1):
        if d[i] == 0:
            m[i] = 0.0
            m[i + 1] = 0.0
        else:
            a, b = m[i] / d[i], m[i + 1] / d[i]
            s = a * a + b * b
            if s > 9:
                t = 3 / math.sqrt(s)
                m[i], m[i + 1] = t * a * d[i], t * b * d[i]
    for i in range(n - 1):
        if xs[i] <= x <= xs[i + 1]:
            h = xs[i + 1] - xs[i]
            t = (x - xs[i]) / h
            h00, h10 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t
            h01, h11 = -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
            return h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]
    return ys[-1]


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def seg(keys, f):
    if f <= keys[0][0]:
        return keys[0][1], keys[0][1], 0.0
    for a, b in zip(keys, keys[1:]):
        if f <= b[0]:
            return a[1], b[1], smooth((f - a[0]) / (b[0] - a[0]))
    return keys[-1][1], keys[-1][1], 0.0


def _periodic(xs, ys, x, period):
    """A loop's cubic through the keys (a stance): the tangents taken across the seam (the last key is the first's, at
    `period`), so the loop carries on through its start instead of easing to a stop there; flat where a key is a turn."""
    n = len(xs)
    if n < 3:
        return _cubic(xs, ys, x)
    x = x % period
    d = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(n - 1)]
    m = [0.0] * n
    for i in range(n):
        a = d[i - 1] if i > 0 else d[-1]
        b = d[i] if i < n - 1 else d[0]
        m[i] = 0.0 if a * b <= 0 else (a + b) / 2
    for i in range(n - 1):
        if xs[i] <= x <= xs[i + 1]:
            h = xs[i + 1] - xs[i]
            t = (x - xs[i]) / h
            h00, h10 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t
            h01, h11 = -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
            return h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]
    return ys[-1]


def chan(clip, key):
    return clip.get(key) or [(0, clip.get("base", STAND)[key])]


def num(clip, key, f):
    keys = chan(clip, key)
    xs = [k[0] for k in keys]
    v0 = keys[0][1]
    loop = clip.get("loop") and len(keys) > 2 and xs[-1] == clip["length"]

    def one(ys):
        return _periodic(xs, ys, f, clip["length"]) if loop else _cubic(xs, ys, f)
    if isinstance(v0, (tuple, list)):
        return Vector([one([k[1][i] for k in keys]) for i in range(len(v0))])
    return one([float(k[1]) for k in keys])


def q_axis(axis, deg):
    return Quaternion(Vector(axis), math.radians(deg))


def mirror_v(v):
    return Vector((-v[0], v[1], v[2]))


# ---------------------------------------------------------------- the rig
REST = {nm: SK.rest_q[nm].copy() for nm in SK.names}
ROOT_REST = SK.rest_t["root"].copy()
P_REST, G_REST = SK.fk(REST, ROOT_REST)


def gq(rots, nm):
    """A bone's global rotation (its chain's product; no positions)."""
    q = Quaternion()
    chain = []
    while nm is not None:
        chain.append(nm)
        nm = SK.parent.get(nm)
    for c in reversed(chain):
        q = q @ rots[c]
    return q


def turn(rots, bone, q):
    """Bone `bone` turned by the global rotation `q` (its children with it)."""
    par = SK.parent[bone]
    gp = gq(rots, par)
    rots[bone] = gp.inverted() @ (q @ gp @ rots[bone])


def set_global(rots, bone, q):
    rots[bone] = gq(rots, SK.parent[bone]).inverted() @ q


def hand_frame(side):
    """The hand's own axes in its wrist's frame at the rest: the fingers' way (to the middle knuckle) and the palm's (the side the
    fingers close toward)."""
    w = side + "_wrist"
    inv = G_REST[w].inverted()
    fing = (P_REST[side + "_middlea"] - P_REST[w]).normalized()
    across = (P_REST[side + "_indexa"] - P_REST[side + "_pinkyb"]).normalized()
    n = fing.cross(across).normalized()
    tip = P_REST[side + "_middlec"] - P_REST[side + "_middlea"]
    bend = tip - fing * tip.dot(fing)
    if bend.length > 0.004:
        if n.dot(bend) < 0:
            n = -n
    else:
        medial = Vector((-1.0 if P_REST[w].x > 0 else 1.0, 0.0, 0.0))
        if n.dot(medial) < 0:
            n = -n
    return inv @ fing, inv @ n


HAND_LOCAL = {s: hand_frame(s) for s in "lr"}
## A joint's child along its finger (the thumb's line is from a joint to the next).
CHILD = {SK.parent[n]: n for n in SK.names if SK.parent.get(n) and "thumb" in n and "thumb" in SK.parent[n]}


def basis(f, n):
    f = Vector(f).normalized()
    n = (Vector(n) - f * Vector(n).dot(f)).normalized()
    return Matrix((f, n, f.cross(n))).transposed()


def facing_q(side, v):
    """The wrist's global rotation for a facing: a name (the right hand's, mirrored for the left) or ((fingers), (palm))."""
    f, n = FACING[v] if isinstance(v, str) else v
    if side == "l" and isinstance(v, str):
        f, n = mirror_v(f), mirror_v(n)
    fl, nl = HAND_LOCAL[side]
    return (basis(f, n) @ basis(fl, nl).inverted()).to_quaternion().normalized()


def facing_at(clip, side, f):
    a, b, u = seg(chan(clip, "face_" + side), f)
    qa, qb = facing_q(side, a), facing_q(side, b)
    if qa.dot(qb) < 0:
        qb = -qb
    return qa.slerp(qb, u)


def finger_axes(rots, side):
    """The knuckles' line (the fingers close about it) and the palm's way, global, from the wrist's rotation now."""
    gw = gq(rots, side + "_wrist")
    fl, nl = HAND_LOCAL[side]
    f, n = gw @ fl, gw @ nl
    return f.cross(n).normalized(), n


def knee_pole(clip, side, f, hip, yaw_deg, qs=None):
    a, b, u = seg(chan(clip, "knee_" + side), f)
    sg = 1.0 if side == "l" else -1.0
    auto = q_axis((0, 1, 0), sg * yaw_deg) @ Vector((sg * 0.18, 0.0, 1.0))

    def val(v):
        return auto.normalized() if isinstance(v, str) else Vector(v).normalized()
    v = val(a).lerp(val(b), u).normalized()
    return hip + (qs @ v if qs is not None else v)


## The last pose's limbs, for the reach report (--fit): side+"_arm" / side+"_leg" -> (base joint, IK target, reach, the
## channel's place: the palm's or the ankle's).
DIAG = {}


## The height (m) of the point an airborne figure turns about (flip, cart): the hips' height on the stand, so a somersault
## turns about the body's middle.
PIVOT_Y = 0.98


def tumbling(clip):
    """An airborne clip that turns the whole figure (keys flip or cart, or flip_turns; or barrel, the sixth set's log roll)."""
    return "flip" in clip or "cart" in clip or "flip_turns" in clip or "barrel" in clip


def flip_at(clip, f):
    """The somersault's angle at f (deg): flip_turns whole turns spread evenly over the clip (a loop's steady tumble, the last
    frame's turn the first's) plus the flip channel's keys on top (the turn quickening as the body tucks, slowing as it opens)."""
    base = 360.0 * clip.get("flip_turns", 0.0) * f / clip["length"]
    return base + (num(clip, "flip", f) if "flip" in clip else 0.0)


def pivot_at(clip, f):
    """The point the flip and the cart turn the figure about (the character's frame): the pivot channel's keys (a ground roll
    turns about its tucked ball's middle, low), else the hips' height over the stand's middle."""
    return Vector(num(clip, "pivot", f)) if "pivot" in clip else Vector((0.0, PIVOT_Y, 0.0))


## The body's surface round its joints (m, a sphere a joint; the head's about the middle of its two bones) for the ground
## contact of a roll (the ground channel) and the --points report: the lowest of them is where the body meets the deck.
SURF = {"heada": 0.11, "neck": 0.07, "spinea": 0.12, "spineb": 0.11, "spinec": 0.11, "spined": 0.11, "pelvis": 0.12,
        "l_shoulder": 0.07, "r_shoulder": 0.07, "l_elbow": 0.045, "r_elbow": 0.045, "l_wrist": 0.035, "r_wrist": 0.035,
        "l_palm": 0.025, "r_palm": 0.025, "l_upper_leg": 0.09, "r_upper_leg": 0.09, "l_knee": 0.055, "r_knee": 0.055,
        "l_ankle": 0.045, "r_ankle": 0.045, "l_heel": 0.0, "r_heel": 0.0, "l_ball": 0.02, "r_ball": 0.02}


def head_middle(P):
    """The skull's middle: past the head's base along its two bones (its sphere's centre)."""
    if "headb" in P:
        return P["heada"] + (P["headb"] - P["heada"]) * 0.5 + (P["headb"] - P["neck"]).normalized() * 0.03
    return P["heada"]


## The tricorne's corners and crown on the rig's headb at rest (m, the character's frame, read off the glb's Hat mesh: x
## +-0.16, y 1.535-1.627, z -0.095-0.205): --points prints the hat's lowest point, so a roll keeps the brim, not only the
## skull, clear of the deck (a report only; the ground contact stays the body's).
HAT_REST = [(0.0, 1.54, 0.2), (0.16, 1.54, -0.02), (-0.16, 1.54, -0.02), (0.0, 1.55, -0.095), (0.0, 1.627, 0.03)]


def hat_low(P, G):
    """The hat's lowest point (m) with the head as posed (P, G from SK.fk)."""
    if "headb" not in P:
        return 9.0
    q = G["headb"] @ G_REST["headb"].inverted()
    return min((P["headb"] + q @ (Vector(v) - P_REST["headb"])).y for v in HAT_REST)


def hat_points(P, G):
    """The hat's typed points (HAT_REST) with the head as posed (a report only: --points prints the hat's farthest point
    ahead and how near each palm comes to it)."""
    if "headb" not in P:
        return []
    q = G["headb"] @ G_REST["headb"].inverted()
    return [P["headb"] + q @ (Vector(v) - P_REST["headb"]) for v in HAT_REST]


def surface_low(P):
    """The lowest point of the body's surface (SURF): (its height, the joint)."""
    best = (1e9, "")
    for nm, r in SURF.items():
        if nm not in P:
            continue
        p = head_middle(P) if nm == "heada" else P[nm]
        if p.y - r < best[0]:
            best = (p.y - r, nm)
    return best


# ---------------------------------------------------------------- one frame
def pose(clip, f):
    rots = {k: v.copy() for k, v in REST.items()}
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    # spin: the whole figure turned about the vertical through the stand's middle, the feet's and the hands' places with it
    # (a turn on the spot: Baguazhang's circles); 0 for every clip that does not key it
    spin = num(clip, "spin", f) if "spin" in clip else 0.0
    qs = q_axis(Y, spin)
    yaw, twist = num(clip, "yaw", f), num(clip, "twist", f)
    look = num(clip, "look", f)
    if tumbling(clip):
        # an airborne figure turned whole about the pivot (the hips' height over the stand's middle): flip its somersault
        # (+ the head forward and down, - backward), cart its cartwheel (+ the left side up), after the spin; every place and
        # way the keys give (the palms, the ankles, the poles, the facings) turns with it, so the keys stay the body's own pose
        Q = qs @ q_axis(X, flip_at(clip, f)) @ q_axis(Z, num(clip, "cart", f) if "cart" in clip else 0.0)
        # (barrel: the figure turned about its own long axis after the flip and the cart, a log roll along the deck; only
        # the sixth set's clips key it, so every other clip's Q is as before)
        if "barrel" in clip:
            Q = Q @ q_axis(Y, num(clip, "barrel", f))
        piv = pivot_at(clip, f)

        def xf(v):
            return piv + Q @ (Vector(v) - piv)
        up = Q @ Y
        root = xf(ROOT_REST + num(clip, "root", f))
        qbody = Q @ q_axis(Y, yaw + twist)
        qhead = Q @ q_axis(Y, (yaw + twist) * 0.2 + look)
    else:
        Q = qs

        def xf(v):
            return qs @ v
        up = Y
        root = ROOT_REST + qs @ num(clip, "root", f)
        qbody = q_axis(Y, spin + yaw + twist)
        qhead = q_axis(Y, spin + (yaw + twist) * 0.2 + look)
    qyaw = q_axis(Y, yaw)
    # the whole body: the yaw, the hips' bow and tilt (the legs are planted again below)
    rots["root"] = Q @ qyaw @ q_axis(X, num(clip, "hips", f)) @ q_axis(Z, num(clip, "roll", f)) @ rots["root"]
    # the spine: its turn, then its pitch and side bend about the turned body's own axes, a share a vertebra
    for nm, share in SPINE:
        turn(rots, nm, q_axis(up, twist * share))
    for nm, share in SPINE:
        turn(rots, nm, q_axis(qbody @ X, num(clip, "chest", f) * share) @ q_axis(qbody @ Z, num(clip, "side", f) * share))
    # the head: kept on the mark through the body's turn (look turns it), its pitch about its own facing
    for nm, share in NECK:
        turn(rots, nm, q_axis(up, (-(yaw + twist) * 0.8 + look) * share))
    for nm, share in NECK:
        turn(rots, nm, q_axis(qhead @ X, num(clip, "head", f) * share))
    # the head's own side tilt (a lolling head; only the clips that key it, so the others' heads are as before)
    if "tilt" in clip:
        for nm, share in NECK:
            turn(rots, nm, q_axis(qhead @ Z, num(clip, "tilt", f) * share))
    for s, sg in (("l", -1.0), ("r", 1.0)):
        cl = num(clip, "clav_" + s, f)
        turn(rots, s + "_clavicle", q_axis(qbody @ Y, sg * cl.x) @ q_axis(qbody @ Z, sg * cl.y))
    # the legs: each ankle to its place, the foot turned out and its heel lifted about the ball (the toes kept on the ground
    # when it is down), the knee toward its pole
    P, G = SK.fk(rots, root)
    for s in "lr":
        sg = 1.0 if s == "l" else -1.0
        fa, fb, fu = seg(chan(clip, "foot_" + s), f)
        place = xf(num(clip, "foot_" + s, f))
        fyaw = num(clip, "fyaw_" + s, f)
        heel = num(clip, "heel_" + s, f)
        qy = Q @ q_axis(Y, sg * fyaw)
        lat = qy @ X
        ball0 = P_REST[s + "_ball"] - P_REST[s + "_ankle"]           # the ball from the ankle, the foot flat (world)
        ball = place + qy @ ball0
        qh = q_axis(lat, heel)
        pivot = ball if heel >= 0 else place + qy @ (P_REST[s + "_heel"] - P_REST[s + "_ankle"])
        ankle = pivot + qh @ (place - pivot)
        ga = qh @ qy @ G_REST[s + "_ankle"]
        P, G = SK.fk(rots, root)
        hip = P[s + "_upper_leg"]
        DIAG[s + "_leg"] = (hip.copy(), ankle.copy(), (P_REST[s + "_knee"] - P_REST[s + "_upper_leg"]).length +
                            (P_REST[s + "_ankle"] - P_REST[s + "_knee"]).length, place.copy())
        for _ in range(2):
            rigkit.ik2(rots, root, s + "_upper_leg", s + "_knee", s + "_ankle", ankle, knee_pole(clip, s, f, hip, fyaw, Q))
        set_global(rots, s + "_ankle", ga)
        # the toes flat on the ground while the ball is on it, else with the foot
        on = 1.0 - smooth((ball.y - 0.04) / 0.08)
        gb = (qy @ G_REST[s + "_ball"]).slerp(qh @ qy @ G_REST[s + "_ball"], 1.0 - on) if heel > 0 else qh @ qy @ G_REST[s + "_ball"]
        # (toes "foot": the toes always with the foot; a figure lying on the deck (the sixth set) sets its sole flat on the
        # deck with a heel lift in its own frame, where the stand's "toes flat on the ground" would bend them up off it)
        if clip.get("toes") == "foot":
            gb = qh @ qy @ G_REST[s + "_ball"]
        set_global(rots, s + "_ball", gb)
    # the arms: each palm to its place, facing its way, the elbow toward its pole
    for s in "lr":
        gw = Q @ facing_at(clip, s, f)
        P, G = SK.fk(rots, root)
        if clip.get("hands_from") == "shoulder":
            # (a limp arm trailing from its shoulder: the hand keyed as the arm's reach from the shoulder in the turned chest's
            # frame, so the spine's sway carries the arm whole and the elbow keeps its bend instead of pumping)
            gw = qbody @ facing_at(clip, s, f)
            palm_t = P[s + "_shoulder"] + qbody @ num(clip, "hand_" + s, f)
        else:
            palm_t = xf(num(clip, "hand_" + s, f))
        wrist_t = palm_t - gw @ SK.rest_t[s + "_palm"]
        pole_v = (qbody if clip.get("hands_from") == "shoulder" else Q) @ num(clip, "pole_" + s, f)
        DIAG[s + "_arm"] = (P[s + "_shoulder"].copy(), wrist_t.copy(), (P_REST[s + "_elbow"] - P_REST[s + "_shoulder"]).length +
                            (P_REST[s + "_wrist"] - P_REST[s + "_elbow"]).length, palm_t.copy())
        for _ in range(2):
            P, G = SK.fk(rots, root)
            rigkit.ik2(rots, root, s + "_shoulder", s + "_elbow", s + "_wrist", wrist_t, P[s + "_shoulder"] + pole_v)
        set_global(rots, s + "_wrist", gw)
        # the fingers: closed about the knuckles' line toward the palm by the grip (a share of a fist's), each joint after its
        # parent (the thumb about its own line)
        g = max(-0.6, min(1.0, num(clip, "grip_" + s, f)))
        k, n = finger_axes(rots, s)
        for dg, joints in CURL.items():
            for j, deg in joints.items():
                nm = "%s_%s%s" % (s, dg, j)
                if nm not in rots:
                    continue
                if dg == "thumb":
                    tdir = (gq(rots, nm) @ SK.rest_t[CHILD.get(nm, nm)]).normalized() if nm in CHILD else \
                        (gq(rots, SK.parent[nm]) @ SK.rest_t[nm]).normalized()
                    axis = tdir.cross(n)
                    if axis.length < 1e-4:
                        continue
                    turn(rots, nm, q_axis(axis.normalized(), deg * g))
                else:
                    turn(rots, nm, q_axis(k, deg * g))
    # the ground contact of a roll (only the clips that key it): the whole figure lifted or lowered by the ground channel's
    # share of the gap between the deck (the clip's floor, 0 but for the edge's deck top) and its lowest surface (SURF), so a
    # tucked ball rolls on the deck instead of sinking into it or floating; a uniform shift, so the joints' rotations (and the
    # IK) are unchanged
    if "ground" in clip:
        w = num(clip, "ground", f)
        if w > 0.0:
            P, _ = SK.fk(rots, root)
            root = root + Vector((0.0, (clip.get("floor", 0.0) - surface_low(P)[0]) * w, 0.0))
    # the code's carry taken back (only the clips that key it: the edge jump): the whole figure lowered by the lift_w share of
    # the code's own lift (lift: its vy and gravity, from the clip's start), so the hands stay on the deck through the push
    # while the code is already carrying the body up; a uniform shift, the rotations as keyed
    if "lift" in clip:
        vy, g = clip["lift"]
        t = f / FPS
        w = num(clip, "lift_w", f) if "lift_w" in clip else 1.0
        root = root - Vector((0.0, (vy * t - 0.5 * g * t * t) * w, 0.0))
    return rots, root


def keyed():
    out = ["root", "spinea", "spineb", "spinec", "spined", "neck", "heada", "headb"]
    out += [n for n in STILL if n in SK.rest_q]
    for s in "lr":
        out += ["%s_%s" % (s, b) for b in ARM + LEG if "%s_%s" % (s, b) in SK.rest_q]
        out += ["%s_%s" % (s, n) for n in STILL if "%s_%s" % (s, n) in SK.rest_q]
        out += ["%s_%s%s" % (s, dg, j) for dg, js in CURL.items() for j in js if "%s_%s%s" % (s, dg, j) in SK.rest_q]
    seen, res = set(), []
    for n in out:
        if n not in seen:
            seen.add(n)
            res.append(n)
    return res


# ---------------------------------------------------------------- the mirrored twin
SIDED = ["clav", "hand", "face", "pole", "grip", "foot", "fyaw", "heel", "knee"]


def mirror_clip(clip):
    """The clip's twin for the other hand: the sides swapped, every place mirrored across the body's middle, every turn
    reversed (a named facing mirrors itself, being the right hand's for the right and mirrored for the left)."""
    out = {"length": clip["length"], "meta": dict(clip["meta"])}
    if clip.get("loop"):
        out["loop"] = True
    h = out["meta"].get("hand")
    if isinstance(h, str):
        out["meta"]["hand"] = {"r": "l", "l": "r", "foot_r": "foot_l", "foot_l": "foot_r"}.get(h, h)
    # (a side roll's travel, the way it rolls in the character's frame: right for the keys, left for the twin)
    if "travel" in out["meta"]:
        out["meta"]["travel"] = {"right": "left", "left": "right"}.get(out["meta"]["travel"], out["meta"]["travel"])

    def mv(v):
        if isinstance(v, str):
            return v
        if isinstance(v, tuple) and len(v) == 2 and isinstance(v[0], tuple):
            return (tuple(mirror_v(v[0])), tuple(mirror_v(v[1])))
        if isinstance(v, tuple) and len(v) == 3:
            return (-v[0], v[1], v[2])
        return v
    for key, keys in clip.items():
        if key in ("length", "meta", "mirror", "loop", "base", "twin_keys", "twin_ends", "twin_tail"):
            continue
        if key in ("flip_turns", "bones", "hands_from", "floor", "lift", "substeps", "toes", "twin_start"):
            out[key] = keys
            continue
        if key in ("yaw", "twist", "roll", "side", "look", "spin", "cart", "tilt", "barrel"):
            out[key] = [(fr, -v) for fr, v in keys]
        elif key in ("root", "pivot"):
            out[key] = [(fr, mv(v)) for fr, v in keys]
        elif "_" in key and key.split("_")[0] in SIDED:
            base, s = key.rsplit("_", 1)
            other = base + "_" + ("l" if s == "r" else "r")
            out[other] = [(fr, mv(v)) for fr, v in keys]
        else:
            out[key] = list(keys)
    # (twin_start n: the twin's first n frames are the original's own, unmirrored, so a twin that starts from an
    # asymmetric pose (the getup roll from the lie) starts from that same pose and gathers into its mirrored keys)
    n = int(clip.get("twin_start", 0))
    if n:
        for key, keys in list(out.items()):
            if isinstance(keys, list) and isinstance(clip.get(key), list):
                out[key] = [k for k in clip[key] if k[0] < n] + [k for k in keys if k[0] >= n]
    # (twin_tail n: the twin's keys from frame n on are the original's own, unmirrored, so a twin that strikes with the
    # other hand ends on the original's own pose (the Pop's twin: the right hand on the stone where the code holds it))
    n = int(clip.get("twin_tail", 0))
    if n:
        for key, keys in list(out.items()):
            own = clip.get(key)
            if isinstance(keys, list) and isinstance(own, list):
                out[key] = [k for k in keys if k[0] < n] + [k for k in own if k[0] >= n]
    # (twin_keys: channels typed for the twin alone, in its own frame, in place of its mirrored ones: a correction the
    # mirror needs (the tech roll's twin's hips tilted so the coat's skirt hangs on its kneel))
    for key, keys in clip.get("twin_keys", {}).items():
        out[key] = list(keys)
    # (twin_ends: the twin's first and last keys are the original's own, unmirrored, and its unkeyed channels its base's, so
    # a twin cast from an asymmetric pose (a Slam from the fall's first pose, AIR) leaves and lands on that same pose)
    if clip.get("twin_ends"):
        out["base"] = clip.get("base", STAND)
        n_end = clip["length"]
        for key, keys in list(out.items()):
            own = clip.get(key)
            if not (isinstance(keys, list) and keys and isinstance(own, list) and own):
                continue
            # (a whole turn on the spot (spin: the eighth set's earth air hit) ends at -360 in the twin, the same pose as the
            # original's +360: kept mirrored, or the twin's last frame would wind two turns back in one)
            if key == "spin":
                continue
            keys = list(keys)
            if keys[0][0] == 0 and own[0][0] == 0:
                keys[0] = (0, own[0][1])
            if keys[-1][0] == n_end and own[-1][0] == n_end:
                keys[-1] = (n_end, own[-1][1])
            out[key] = keys
    return out


def all_clips():
    out = {}
    for name, clip in CLIPS.items():
        out[name] = clip
        if clip.get("mirror"):
            out[name + "_l"] = mirror_clip(clip)
    return out


## ---------------------------------------------------------------- the sixth set (round 3, P2: the four Rises, the scramble up
## the deck's face, breaking the fall (the slap, its roll and the wall's), lying and getting up (the lie, the getup, its roll
## and its attack) and the spiked and bounce knocks; authored the same way, key poses typed here, nothing read). The Rises and
## the airborne knocks start (and the knocks end) on AIR, the fall's first pose; the scramble ends exactly on the hang's first
## pose (HANG); the breaks and the getups end on the STAND; the bounce ends on the lie's first pose (LIE), which the getups
## start from. The figures lying on the deck (the lie, the bounce, the getups) are keyed in the DECK'S frame (_wclip below):
## the pelvis's place and the figure's turn (flip, cart, barrel) with the hands and the feet where they are on the deck,
## turned back into the figure's own keys at every frame, so a palm or a sole laid on the deck stays there while the body
## turns over it. Fire Northern Shaolin (the rocket's rising punch, the getup's carp skip-up), earth Hung Gar (the horse on
## the column, the fists driven down), water tai chi (the cloud hands' circles rising) and air Baguazhang (the spinning
## crane, the glide) are style labels for the typed key poses only.
PELV_REST = (round(P_REST["pelvis"].x, 4), round(P_REST["pelvis"].y, 4), round(P_REST["pelvis"].z, 4))
## The stand's pelvis (the place a getup ends on).
PELV_STAND = (PELV_REST[0], round(PELV_REST[1] + STAND["root"][1], 4), PELV_REST[2])
_X3, _Y3, _Z3 = Vector((1.0, 0.0, 0.0)), Vector((0.0, 1.0, 0.0)), Vector((0.0, 0.0, 1.0))
FACING.update({
    "wall": ((0.08, 1.0, 0.0), (0.0, 0.0, 1.0)),             # flat on a face ahead (the deck's or a wall), the fingers up
    "rocket": ((0.05, 0.75, 0.66), (0.98, 0.0, -0.1)),       # a fist punched up and ahead, the knuckles leading, the palm in
})


def _kv(keys, f, loop_len=None):
    """Typed keys [(frame, value)] at frame f by the clips' own monotone cubic (periodic across loop_len for a loop)."""
    xs = [k[0] for k in keys]
    v0 = keys[0][1]

    def one(ys):
        if loop_len is not None and len(keys) > 2 and xs[-1] == loop_len:
            return _periodic(xs, ys, f, loop_len)
        return _cubic(xs, ys, f)
    if isinstance(v0, (tuple, list)):
        return tuple(one([k[1][i] for k in keys]) for i in range(len(v0)))
    return one([float(k[1]) for k in keys])


def _turnq(flip, cart=0.0, barrel=0.0):
    """The figure's turn as pose() composes it (the flip, then the cart, then the barrel about its own long axis)."""
    return q_axis(_X3, flip) @ q_axis(_Z3, cart) @ q_axis(_Y3, barrel)


def _heel_key(side, ankle, heel, fyaw=0.0):
    """The foot's key (its flat place) that lands the ankle exactly at `ankle` with the heel lifted by `heel` degrees (about
    the ball; below 0 the toes up about the heel's back) and turned out by fyaw, as pose() lifts it (the figure's frame)."""
    sg = 1.0 if side == "l" else -1.0
    qy = q_axis(_Y3, sg * fyaw)
    qh = q_axis(qy @ _X3, heel)
    b = qy @ ((P_REST[side + "_ball"] if heel >= 0 else P_REST[side + "_heel"]) - P_REST[side + "_ankle"])
    return _r3(tuple(Vector(ankle) - b + qh @ b))


def _tag(v):
    """A place's frame: ('b', place) the figure's own, ('w', place) or a bare place the deck's."""
    if isinstance(v, tuple) and len(v) == 2 and v[0] in ("w", "b"):
        return v[0], v[1]
    return "w", v


def _wclip(length, keys, loop=False):
    """A clip keyed in the deck's frame: `pelvis` (the pelvis's place on or over the deck: the point the figure turns about,
    the root carried so the pelvis sits on it), flip / cart / barrel (the figure's turn), hand_r/l (the palms) and foot_r/l
    (the ankles, where they land with their heel lift and toe-out) as places on the deck (('b', place) a place in the
    figure's own frame, carried with it), face_r/l a facing name (the figure's own) or ('w', fingers, palm) on the deck,
    pole_r/l and knee_r/l in the figure's frame (('w', way) on the deck); a channel may be a function of the frame. Every
    other channel is the figure's own, passed through. Returns the clip's channels keyed at every frame."""
    def ev(ch, f, default=None):
        ks = keys.get(ch)
        if ks is None:
            return default
        if callable(ks):
            return ks(f)
        return _kv(ks, f, length if loop else None)

    def turn_at(f):
        return _turnq(ev("flip", f, 0.0), ev("cart", f, 0.0), ev("barrel", f, 0.0)), Vector(ev("pelvis", f, PELV_STAND))

    def tobody(w, f):
        R, piv = turn_at(f)
        return tuple(piv + R.inverted() @ (Vector(w) - piv))

    def toworld(b, f):
        R, piv = turn_at(f)
        return tuple(piv + R @ (Vector(b) - piv))

    def shift(f):
        # (the figure's own places are the stand's, carried with the pelvis: the root's offset puts the pelvis on its place)
        return Vector(ev("pelvis", f, PELV_STAND)) - Vector(PELV_REST)

    def place(ch, f):
        ks = keys[ch]
        if callable(ks):
            tg, p = _tag(ks(f))
            return tuple(Vector(p) + shift(f)) if tg == "b" else tobody(p, f)
        xs = [k[0] for k in ks]
        tags = [_tag(v)[0] for _, v in ks]
        W, B = [], []
        for fr, v in ks:
            tg, p = _tag(v)
            if tg == "w":
                W.append((fr, p))
                B.append((fr, tuple(Vector(tobody(p, fr)) - shift(fr))))
            else:
                W.append((fr, toworld(tuple(Vector(p) + shift(fr)), fr)))
                B.append((fr, p))
        i = max([j for j in range(len(xs)) if xs[j] <= f] or [0])
        nxt = tags[i + 1] if i + 1 < len(xs) else tags[i]
        if tags[i] == "w" and nxt == "w":
            return tobody(_kv(W, f, length if loop else None), f)
        return tuple(Vector(_kv(B, f, length if loop else None)) + shift(f))

    def way_q(v, side, fr):
        R, _ = turn_at(fr)
        if isinstance(v, str):
            fb, nb = FACING[v]
            if side == "l":
                fb, nb = mirror_v(fb), mirror_v(nb)
            fw, nw = R @ Vector(fb), R @ Vector(nb)
        else:
            fw, nw = Vector(v[1]), Vector(v[2])
        return basis(fw, nw).to_quaternion()

    def facing(ch, f):
        side = ch[-1]
        ks = keys[ch]
        if callable(ks):
            v = ks(f)
            pairs = [(f, v)]
        else:
            pairs = ks
        if f <= pairs[0][0]:
            q = way_q(pairs[0][1], side, pairs[0][0])
        elif f >= pairs[-1][0]:
            q = way_q(pairs[-1][1], side, pairs[-1][0])
        else:
            for (fa, va), (fb, vb) in zip(pairs, pairs[1:]):
                if fa <= f <= fb:
                    qa, qb = way_q(va, side, fa), way_q(vb, side, fb)
                    if qa.dot(qb) < 0:
                        qb = -qb
                    q = qa.slerp(qb, smooth((f - fa) / (fb - fa)))
                    break
        R, _ = turn_at(f)
        m = (R.inverted() @ q).to_matrix()
        return (_r3(tuple(m.col[0])), _r3(tuple(m.col[1])))

    def way(v, fr):
        if isinstance(v, tuple) and len(v) == 2 and v[0] == "w":
            R, _ = turn_at(fr)
            return _r3(tuple(R.inverted() @ Vector(v[1])))
        return v

    out = {}
    frames = range(length + 1)
    for ch in ("flip", "cart", "barrel"):
        if ch in keys:
            out[ch] = [(f, round(ev(ch, f), 3)) for f in frames]
    if "flip" not in out:
        out["flip"] = [(0, 0.0), (length, 0.0)]
    out["pivot"] = [(f, _r3(tuple(turn_at(f)[1]))) for f in frames]
    out["root"] = [(f, _r3(tuple(turn_at(f)[1] - Vector(PELV_REST)))) for f in frames]
    for s in "rl":
        if "hand_" + s in keys:
            out["hand_" + s] = [(f, _r3(place("hand_" + s, f))) for f in frames]
        if "foot_" + s in keys:
            out["foot_" + s] = [(f, _heel_key(s, place("foot_" + s, f), ev("heel_" + s, f, 0.0), ev("fyaw_" + s, f, 7.0)))
                                for f in frames]
        if "face_" + s in keys:
            out["face_" + s] = [(f, facing("face_" + s, f)) for f in frames]
        for ch in ("pole_" + s, "knee_" + s):
            if ch in keys:
                ks = keys[ch]
                out[ch] = [(f, way(ks(f), f)) for f in frames] if callable(ks) else [(fr, way(v, fr)) for fr, v in ks]
    for ch, ks in keys.items():
        if ch in out or ch in ("pelvis",) or ch.startswith(("hand_", "foot_", "face_", "pole_", "knee_")):
            continue
        out[ch] = [(f, _rv(ks(f))) for f in frames] if callable(ks) else ks
    return out


# ---------------------------------------------------------------- the lie
## The lie (own-bend-lie, a loop of 40 frames): dazed on his back on the deck, the head toward his back (-Z) and the pelvis
## LIE_PELVIS: the right knee up with its sole flat on the deck, the left leg long and rolled out, the right arm flung
## out on the deck palm up, the left hand fallen on the belly, the head rolled toward the left; a slow breath lifts the chest
## and the hand on the belly, the raised knee sags out and back a beat behind it, the fingers stir, the head rolls a little.
## Pass 2 (the critic's notes): the back, the head and the flung arm on the deck within 5 mm (pass 1's 1.9 cm was the head
## pitched back INTO the deck: the head now lifts off it and lolls back only to it); the right foot
## set out 0.44 m beyond the seat so the thigh lies back at a slant (drawn in, it stood straight up with the coat's skirt
## standing beside it as a slab) and the knee fallen out; the daze made
## readable at the game camera: the head rolls +/-8 degrees and lifts to look down the body toward the foe and lolls back,
## the raised knee sways +/-8 cm, and the flung right hand stirs once (lifted 4 cm and fallen, LIE_STIR).
LIE_PELVIS = (0.0, 0.1225, -0.3)
LIE_LEN = 40
## Pass 3 (the critic's notes: the stir at 0.67-0.93 s came after most getups had started, the lie plays 0.4-1.0 s): the
## daze's one beat moved early (LIE_STIR, f6-f14, its peak at f10) and made bigger: the head lifts LIE_LIFT degrees to look
## down the body, the flung hand rises 10 cm and falls, and the raised knee sags out (its pole LIE_SAG further out and down)
## on the same beat.
LIE_STIR = (6, 14)
LIE_LIFT = 16.0
LIE_SAG = 0.9


def _lie_stir(f):
    if LIE_STIR[0] < f < LIE_STIR[1]:
        return math.sin(math.pi * (f - LIE_STIR[0]) / (LIE_STIR[1] - LIE_STIR[0])) ** 2
    return 0.0


def lie_at(f):
    a = 2 * math.pi * f / LIE_LEN
    st = _lie_stir(f)
    return {
        "flip": -90.0, "pelvis": _add(LIE_PELVIS, (0.0, 0.002 * _s(a), 0.0)),
        "hips": 0.0, "chest": 2.0 + 1.5 * _s(a), "head": 9.0 + 5.0 * _s(a, -1.0) + LIE_LIFT * st, "look": 20.0 + 12.0 * _s(a, -1.6),
        "tilt": 5.0 * _s(a), "side": 1.0 * _s(a, -0.6), "twist": 0.0,
        "clav_r": (0.0, 0.0), "clav_l": (2.0, 2.0 + 1.5 * _s(a, -0.4)),
        "hand_r": (-0.63, 0.035 + 0.1 * st, -0.6 + 0.02 * st), "hand_l": (0.06, 0.25 + 0.012 * _s(a, -0.5), -0.36),
        "face_r": ("w", (-0.85, 0.0, -0.5), (0.0, 1.0, 0.0)), "face_l": ("w", (-0.9, -0.1, 0.35), (0.0, -1.0, 0.1)),
        "pole_r": (-1.0, 0.0, 0.5), "pole_l": (1.0, 0.0, -0.3),
        "grip_r": 0.25 + 0.1 * _s(a, 2.0) + 0.35 * st, "grip_l": 0.3 + 0.05 * _s(a, 0.5),
        "foot_r": (-0.24, 0.078, 0.14), "foot_l": (0.2, 0.065, 0.4),
        "heel_r": 90.0, "heel_l": 25.0, "fyaw_r": 8.0, "fyaw_l": 28.0,
        "knee_r": (-0.8 - 0.55 * _s(a, -1.2) - LIE_SAG * st, 0.4 - 0.3 * st, 1.0), "knee_l": (0.45, 0.0, 1.0),
    }


LIE = lie_at(0)


def _lie_keys(ch, *frames):
    """The lie's first value of a channel as keys at the frames given (a getup's start, the bounce's end)."""
    v = LIE[ch]
    return [(fr, v) for fr in frames]


# ---------------------------------------------------------------- the glide (the air Rise's loop)
## The air Rise's glide (frames 14-44 of own-bend-rise-air, a loop: meta loop_from_s): the spent body laid forward into the
## wind (the flip), the arms spread wide as wings (the palms down, the fingers spread), the legs trailing long and together,
## the toes pointed; it banks slowly from side to side (cart), the low wing dipping a few frames behind the bank, the head
## looking into the turn after it, the legs scissoring a little.
GLIDE_LEN = 30


## (pass 3, the critic's notes: the straight level wings read as the T pose at 15 m) the wings swept back and raised into a
## dihedral, the elbows bent and dropped, the wrists cocked back with the fingers trailing ("wing"), the chest arched
## further, and the wingtips flexing twice a bank (GLIDE_FLEX), each hand GLIDE_TIP_LAG frames behind it.
GLIDE_FLEX = 0.02
GLIDE_TIP_LAG = 4
FACING["wing"] = ((-0.92, 0.24, -0.3), (0.22, -0.97, 0.0))   # a wing swept back: the wrist cocked, the fingers trailing, the palm down


def glide_at(a):
    # (pass 2: banking 18 degrees; pass 3: the wings swept back to z -0.26 and up into a dihedral (y 1.47), the elbows bent)
    lag = 2 * math.pi * 3 / GLIDE_LEN
    tip = 2 * math.pi * GLIDE_TIP_LAG / GLIDE_LEN
    return {
        "flip": 34.0 + 2.0 * _s(a, -0.5), "cart": 18.0 * _s(a),
        "hips": 2.0, "chest": -20.0 + 1.5 * _s(2 * a, -0.6), "head": -30.0 + 2.0 * _s(a, -1.4),
        "look": -9.0 * _s(a, -lag * 1.5), "twist": 1.5 * _s(a, -lag),
        "clav_r": (-8.0, -14.0 + 1.0 * _s(a, -lag)), "clav_l": (-8.0, -14.0 - 1.0 * _s(a, -lag)),
        "hand_r": (-0.6, 1.45 - 0.01 * _s(a, -lag) + GLIDE_FLEX * _s(2 * (a - tip)), -0.2 + 0.02 * _c(a, -lag)),
        "hand_l": (0.6, 1.45 + 0.01 * _s(a, -lag) + GLIDE_FLEX * _s(2 * (a - tip), math.pi), -0.2 - 0.02 * _c(a, -lag)),
        "face_r": "wing", "face_l": "wing",
        "pole_r": (-0.3, -0.8, -0.5), "pole_l": (0.3, -0.8, -0.5),
        "grip_r": -0.35, "grip_l": -0.35,
        "foot_r": _heel_key("r", (-0.075, 0.13 + 0.02 * _s(a, -1.0), -0.06 + 0.04 * _c(a, -1.0)), 55.0, 4.0),
        "foot_l": _heel_key("l", (0.075, 0.13 - 0.02 * _s(a, -1.0), -0.06 - 0.04 * _c(a, -1.0)), 55.0, 4.0),
        "heel_r": 55.0, "heel_l": 55.0, "fyaw_r": 4.0, "fyaw_l": 4.0,
        "knee_r": (-0.1, 0.0, 1.0), "knee_l": (0.1, 0.0, 1.0),
    }


GLIDE = {k: (_rv(v) if not isinstance(v, str) else v) for k, v in glide_at(0.0).items()}


def _rise_air():
    """own-bend-rise-air: the typed spin up (f0-f13) and the glide loop (f14-f44) joined (the glide keyed at every frame).
    Pass 2: the whirl a Baguazhang palm change (the critic: the crane read as the water Rise's rooster): the trunk wrung hard
    against the turn, the right palm thrust out flat at the shoulder's height beyond it, the left palm guarding under the
    right elbow, both feet tucked up together; a wide horizontal blade turning, not a vertical line."""
    c = {
        "length": 44, "base": AIR,
        "meta": {"hold_s": 2 / FPS, "strike_s": 3 / FPS, "back_s": 14 / FPS, "loop_from_s": 14 / FPS, "hand": "both",
                 "mask": "full", "root": "place"},
        # (the whirl: wound up the other way, then one whole turn, fastest in its middle, settling a touch past)
        "spin": [(0, 0), (2, -25), (4, 40), (6, 150), (8, 262), (10, 334), (12, 362), (14, 360), (44, 360)],
        "root": [(0, AIR["root"]), (2, (0.0, -0.03, 0.0)), (4, (0.0, 0.05, 0.0)), (8, (0.0, 0.08, 0.0)), (12, (0.0, 0.04, 0.0)),
                 (14, (0.0, 0.0, 0.0)), (44, (0.0, 0.0, 0.0))],
        "yaw": [(0, 0), (44, 0)], "roll": [(0, 0), (44, 0)], "side": [(0, 0), (3, 4), (8, 8), (12, 0), (44, 0)],
    }
    typed = {
        "flip": [(0, 0.0), (11, 0.0)],
        "cart": [(0, 0.0), (11, 0.0)],
        "hips": [(0, AIR["hips"]), (2, 14), (4, 6), (8, 4), (11, 2)],
        "chest": [(0, AIR["chest"]), (2, 12), (4, 2), (8, -2), (11, -6)],
        "head": [(0, AIR["head"]), (2, 10), (4, -4), (8, -8), (11, -16)],
        # (the head leads the turn; the trunk wrung against it, the right shoulder back behind the thrust palm)
        "look": [(0, 0), (2, -14), (4, 26), (8, 30), (11, 6)],
        "twist": [(0, 0), (2, 14), (4, -22), (6, -30), (9, -30), (11, -6)],
        "clav_r": [(0, AIR["clav_r"]), (2, (10, 6)), (4, (4, -6)), (9, (4, -8)), (11, (-6, -12))],
        "clav_l": [(0, AIR["clav_l"]), (2, (10, 6)), (4, (12, 6)), (9, (12, 6)), (11, (-6, -10))],
        "hand_r": [(0, AR), (2, (0.08, 1.12, 0.26)), (4, (-0.39, 1.37, 0.18)), (6, (-0.57, 1.42, 0.07)), (9, (-0.575, 1.425, 0.06)),
                   (11, (-0.52, 1.34, -0.05))],
        "hand_l": [(0, AL), (2, (-0.06, 1.17, 0.24)), (4, (-0.12, 1.19, 0.27)), (6, (-0.22, 1.21, 0.22)), (9, (-0.22, 1.22, 0.21)),
                   (11, (0.48, 1.3, 0.0))],
        "face_r": [(0, "balance"), (2, "cross"), (5, "bagua"), (9, "bagua"), (12, "wing")],
        "face_l": [(0, "balance"), (2, "cross"), (5, "press_down"), (9, "press_down"), (12, "wing")],
        "pole_r": [(0, AIR["pole_r"]), (2, (-0.8, -0.5, 0.2)), (5, (-0.3, -1.0, -0.2)), (9, (-0.3, -1.0, -0.2)), (11, (-0.3, -0.8, -0.5))],
        "pole_l": [(0, AIR["pole_l"]), (2, (0.8, -0.5, 0.2)), (5, (0.7, -0.7, 0.0)), (9, (0.7, -0.7, 0.0)), (11, (0.3, -0.8, -0.5))],
        "grip_r": [(0, AIR["grip_r"]), (2, 0.7), (5, -0.3), (9, -0.3), (11, -0.3)],
        "grip_l": [(0, AIR["grip_l"]), (2, 0.7), (5, -0.2), (9, -0.2), (11, -0.3)],
        # (both feet tucked up together under him through the whirl)
        "foot_r": [(0, AFR), (2, (-0.12, 0.38, 0.14)), (4, (-0.08, 0.34, 0.08)), (9, (-0.08, 0.33, 0.07)), (11, (-0.075, 0.16, -0.04))],
        "foot_l": [(0, AFL), (2, (0.12, 0.42, 0.1)), (4, (0.08, 0.36, 0.06)), (9, (0.08, 0.35, 0.05)), (11, (0.075, 0.17, -0.06))],
        "heel_r": [(0, AIR["heel_r"]), (2, 30), (4, 48), (11, 55)], "heel_l": [(0, AIR["heel_l"]), (2, 30), (4, 48), (11, 55)],
        "fyaw_r": [(0, AIR["fyaw_r"]), (4, 4), (11, 4)], "fyaw_l": [(0, AIR["fyaw_l"]), (4, 4), (11, 4)],
        "knee_r": [(0, AIR["knee_r"]), (4, (-0.1, 0.2, 1.0)), (9, (-0.1, 0.2, 1.0)), (11, (-0.1, 0.0, 1.0))],
        "knee_l": [(0, AIR["knee_l"]), (4, (0.1, 0.2, 1.0)), (9, (0.1, 0.2, 1.0)), (11, (0.1, 0.0, 1.0))],
    }
    for ch, ks in typed.items():
        c[ch] = list(ks) + [(14 + i, GLIDE[ch] if isinstance(GLIDE[ch], str) else _rv(glide_at(2 * math.pi * i / GLIDE_LEN)[ch]))
                            for i in range(GLIDE_LEN + 1)]
    for s in "rl":
        c["face_" + s] = typed["face_" + s] + [(44, GLIDE["face_" + s])]
    return c


# ---------------------------------------------------------------- the water Rise's circles and the white crane
## Each arm swung round a big circle about its own shoulder (tai chi's cloud hands, the elbow soft: the hand WATER_ARM from
## the shoulder on a cone WATER_CONE degrees about an axis out to its side, forward and a little up, so the circle stands out
## from the body at 15 m and its inward half bulges well forward of the chest): the right from the bottom out to his right,
## over the top, in before the face and round again, out to his right again and up (WATER_TURNS); the left the same on its
## own side, WATER_LAG of the swirl behind it, one turn to end low.
## Pass 3 (the critic's notes: the circles were invisible at 15 m, the legs locked on tiptoe, the peak the earth throw's V):
## the trunk drives the reach: it twists WATER_TWIST and side-bends WATER_SIDE after the lead (right) hand and the hips sway
## WATER_SWAY toward it, so the circle is carried WATER_REACH wider than the arm alone and its centre rides with the body;
## the knees soft on flat feet with a surge bob (WATER_BOB, the root's height through the swirl) so the column is felt
## pushing up through the legs; the left hand one turn only, ending low; and the peak tai chi's white crane spreads its wings:
## the right palm high over the head and out (WATER_TOP), the left pressed down by the left hip (WATER_PRESS), the trunk
## turned 30 degrees and leant 10 toward the high hand: a spiral that is water's alone.
WATER_SWIRL = (4, 17)
WATER_SHOULDER = (-0.14, 1.34, 0.0)
WATER_AXIS = (-0.5, 0.28, 0.82)
WATER_ARM = 0.395
WATER_CONE = 62.0
WATER_LAG = 0.28
WATER_REACH = 0.03
WATER_TWIST = 25.0
WATER_SIDE = 12.0
WATER_SWAY = 0.055
WATER_TURNS = {"r": 1.4, "l": 1.0}
WATER_BOB = [(4, -0.06), (6, -0.045), (10, -0.005), (14, -0.035), (17, -0.02)]
WATER_TOP = (-0.4, 1.6, -0.06)
WATER_PRESS = (0.3, 0.95, 0.15)
FACING["sky_cup"] = ((0.8, 0.45, 0.25), (-0.35, 0.85, 0.1))   # a hand held up over the head, the fingers in, the palm up


def _ease(t):
    t = max(0.0, min(1.0, t))
    return t - math.sin(2 * math.pi * t) / (2 * math.pi)


def _cone_hand(ph, side, centre=WATER_SHOULDER):
    """The hand's place on its circle at phase ph (-pi/2 the bottom, 0 out to the side, pi/2 the top, pi in before the body):
    the right's, mirrored across the body for the left; the circle about `centre` (the right shoulder's, riding the body)."""
    ax = Vector(WATER_AXIS).normalized()
    out = Vector((-1.0, 0.0, 0.0))
    u = (out - ax * out.dot(ax)).normalized()
    v = ax.cross(u)
    if v.y < 0:
        v = -v
    al = math.radians(WATER_CONE)
    p = Vector(centre) + WATER_ARM * math.cos(al) * ax + (WATER_ARM * math.sin(al) + WATER_REACH) * (math.cos(ph) * u + math.sin(ph) * v)
    return (round(p.x if side == "r" else -p.x, 4), round(p.y, 4), round(p.z, 4))


def _water_phase(f, side):
    t = (f - WATER_SWIRL[0]) / (WATER_SWIRL[1] - WATER_SWIRL[0])
    s = _ease(t) if side == "r" else _ease((t - WATER_LAG) / (1.0 - WATER_LAG))
    return -math.pi / 2 + 2 * math.pi * WATER_TURNS[side] * s


def water_swirl(f):
    out = {}
    ph_r = _water_phase(f, "r")
    # (the body following the lead hand: the hips sway toward it, the trunk turns and leans after it; the eyes two frames
    # behind it; each circle's centre riding the sway and the bob)
    sway = -WATER_SWAY * math.cos(ph_r)
    bob = _kv(WATER_BOB, f)
    for side in "rl":
        ph = _water_phase(f, side)
        # (the left's circle is the right's about the mirrored left shoulder, mirrored back)
        cx = WATER_SHOULDER[0] + (sway if side == "r" else -sway)
        h = _cone_hand(ph, "r", (cx, WATER_SHOULDER[1] + bob + 0.03, WATER_SHOULDER[2]))
        out["hand_" + side] = h if side == "r" else (-h[0], h[1], h[2])
        out["ph_" + side] = ph
    ph2 = _water_phase(f - 2, "r")
    out["twist"] = -WATER_TWIST * math.cos(ph_r)
    out["side"] = WATER_SIDE * math.cos(ph_r)
    out["look"] = -14.0 * math.cos(ph2)
    out["roll"] = 4.0 * math.sin(ph_r)
    out["root"] = (round(sway, 4), round(bob, 4), 0.0)
    return out


def _rise_water():
    c = {
        "length": 28, "base": AIR,
        "meta": {"hold_s": 2 / FPS, "strike_s": 4 / FPS, "back_s": 21 / FPS, "hand": "both", "mask": "full", "root": "place"},
        # (pass 3: the sink a deep crouch, eased out over f2-f5; then the soft knees and the surge bob through the swirl, the
        # hips swaying after the lead hand; tall but soft at the crane)
        "root": [(0, AIR["root"]), (2, (0.0, -0.14, 0.0)), (3, (0.0, -0.13, 0.0))]
                + [(f, water_swirl(f)["root"]) for f in range(WATER_SWIRL[0], WATER_SWIRL[1] + 1)]
                + [(19, (0.0, -0.015, 0.0)), (21, (0.0, -0.008, 0.0)), (24, (0.0, 0.0, 0.0)), (28, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, 20), (4, 12), (6, 6), (10, 3), (16, 0), (19, -3), (21, -4), (24, -1), (28, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, 12), (4, 6), (10, 0), (16, -5), (19, -8), (21, -9), (24, -3), (28, AIR["chest"])],
        "head": [(0, AIR["head"]), (2, 18), (4, 10), (10, -2), (16, -12), (19, -20), (21, -22), (24, -6), (28, AIR["head"])],
        "clav_r": [(0, AIR["clav_r"]), (2, (6, 4)), (4, (2, 0)), (12, (0, -12)), (17, (-2, -32)), (19, (-3, -34)), (21, (-3, -36)),
                   (24, (-2, -14)), (28, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (6, 4)), (4, (2, 0)), (13, (0, -10)), (16, (2, -2)), (19, (4, 6)), (21, (4, 7)),
                   (24, (0, -4)), (28, AIR["clav_l"])],
        "face_r": [(0, "balance"), (2, "press_down"), (4, "press_down"), (7, "push"), (13, "push"), (17, "sky_cup"), (21, "sky_cup"),
                   (28, "balance")],
        "face_l": [(0, "balance"), (2, "press_down"), (6, "press_down"), (9, "push"), (14, "push"), (17, "press_down"),
                   (21, "press_down"), (28, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (4, (-1.0, -0.6, -0.2)), (14, (-1.0, -0.3, -0.1)), (17, (-1.0, 0.25, 0.1)), (21, (-1.0, 0.25, 0.1)),
                   (28, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (4, (1.0, -0.6, -0.2)), (15, (1.0, -0.3, -0.1)), (18, (1.0, -0.2, -0.5)), (21, (1.0, -0.2, -0.5)),
                   (28, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (2, 0.1), (10, -0.15), (16, -0.3), (21, -0.3), (28, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (2, 0.1), (10, -0.15), (17, -0.25), (21, -0.25), (28, AIR["grip_l"])],
        # (the legs drawn in the sink, then set flat on the column on both feet with the knees soft, riding its surge)
        "foot_r": [(0, AFR), (2, (-0.12, 0.34, 0.14)), (4, (-0.11, 0.085, 0.04)), (21, (-0.11, 0.085, 0.04)), (24, (-0.13, 0.22, 0.12)),
                   (28, AFR)],
        "foot_l": [(0, AFL), (2, (0.12, 0.36, 0.02)), (4, (0.11, 0.085, -0.02)), (21, (0.11, 0.085, -0.02)), (25, (0.13, 0.3, -0.04)),
                   (28, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (2, 24), (4, 4), (21, 4), (24, 20), (28, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (2, 24), (4, 4), (21, 4), (25, 20), (28, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (4, 12), (21, 12), (28, AIR["fyaw_r"])], "fyaw_l": [(0, AIR["fyaw_l"]), (4, 12), (21, 12), (28, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (4, (-0.25, 0.0, 1.0)), (21, (-0.25, 0.0, 1.0)), (28, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (4, (0.25, 0.0, 1.0)), (21, (0.25, 0.0, 1.0)), (28, AIR["knee_l"])],
    }
    a0, a1 = WATER_SWIRL
    for s, press, mid, top in (("r", (-0.2, 0.85, 0.2), (-0.44, 1.5, 0.12), WATER_TOP),
                               ("l", (0.2, 0.86, 0.19), (0.44, 1.12, 0.08), WATER_PRESS)):
        # (the left's circle starts later: it is held pressed down a little longer)
        lead = [(0, AR if s == "r" else AL), (2, press)] + ([(5, press)] if s == "l" else [])
        swirl = [(f, water_swirl(f)["hand_" + s]) for f in range(a0 + (3 if s == "l" else 0), a1 + 1)]
        # (the crane: the right palm carried on up and out over the head; the left pressed down by the hip, pressing on)
        hold = (0.0, 0.015, 0.0) if s == "r" else (0.0, -0.02, 0.0)
        c["hand_" + s] = lead + swirl + [(19, top), (21, _add(top, hold)), (24, mid), (28, AR if s == "r" else AL)]
    # (the trunk after the lead hand through the swirl, then turned 30 degrees and leant 10 toward the high hand at the crane)
    peak = {"twist": (-30.0, -32.0, -10.0), "side": (10.0, 11.0, 3.0), "look": (-14.0, -16.0, -4.0), "roll": (0.0, 0.0, 0.0)}
    for ch, (p19, p21, p24) in peak.items():
        c[ch] = ([(0, 0.0), (2, 0.0)] + [(f, round(water_swirl(f)[ch], 2)) for f in range(a0, a1 + 1)]
                 + [(19, p19), (21, p21), (24, p24), (28, 0.0)])
    return c


# ---------------------------------------------------------------- the edge scramble
## The scramble's feet on the deck's face (the ankle's place, the balls on the stone).
SCR_FACE_Z = 0.19


def _tech_slap():
    """The breakfall's three-point slap on the deck (the tech's moment of contact, and the tech roll's second frame): the
    right knee down, the left foot planted ahead, the right arm flung straight out to the side at 45 degrees and its palm
    slapped flat on the deck, the left arm flung up and back for the balance, the trunk leant to the right over the slap
    with the head kept up over the hips and the eyes on the foe. Pass 3 (the critic's notes: hips 64 and the head at the
    knee's height read as a collapse onto the hands and knees): bowed 42 at the slap and 38 on the rebound, the palm out
    wide, the head up: a controlled skill."""
    return {
        "root": (0.0, -0.5, 0.03), "hips": 36.0, "chest": 10.0, "side": 38.0, "twist": -6.0, "head": -34.0, "look": -15.0,
        "roll": 20.0, "yaw": 0.0, "tilt": -30.0,
        "clav_r": (4.0, 20.0), "clav_l": (-10.0, -24.0),
        "hand_r": (-0.43, 0.035, 0.21), "hand_l": (0.02, 1.08, 0.08),
        "face_r": "deck_out", "face_l": "flung_up",
        "pole_r": (-0.4, 0.8, -0.4), "pole_l": (0.6, -0.6, -0.5),
        "grip_r": -0.4, "grip_l": -0.3,
        # (sat low on the right heel, its knee on the deck ahead of it, the toes tucked under; the left foot planted ahead)
        "foot_r": _heel_key("r", (-0.14, 0.1, -0.27), 80.0, 4.0), "heel_r": 80.0, "fyaw_r": 4.0,
        "foot_l": _heel_key("l", (0.18, 0.077, 0.34), 0.0, 14.0), "heel_l": 0.0, "fyaw_l": 14.0,
        "knee_r": (-0.15, -0.3, 1.0), "knee_l": (0.35, 0.3, 1.0),
    }


SLAP = _tech_slap()
## The breaks' airborne entry (the tech's first frame, and the tech roll's: both enter the same way from the tumble): coming
## down flung open, the knees bent for the deck, the arms out.
TECH0 = {
    "root": (0.0, -0.18, 0.0), "hips": 22.0, "chest": 14.0, "side": -4.0, "twist": -2.0, "head": 14.0, "look": 0.0, "roll": 0.0,
    "yaw": 0.0, "tilt": 0.0, "clav_r": (-6.0, -20.0), "clav_l": (-6.0, -20.0),
    "hand_r": (-0.52, 1.25, -0.1), "hand_l": (0.52, 1.28, -0.12), "face_r": "flail", "face_l": "flail",
    "pole_r": (-0.6, -0.6, -0.5), "pole_l": (0.6, -0.6, -0.5), "grip_r": -0.3, "grip_l": -0.3,
    "foot_r": (-0.15, 0.24, -0.2), "foot_l": (0.17, 0.14, 0.26), "heel_r": 30.0, "heel_l": 20.0, "fyaw_r": 6.0, "fyaw_l": 8.0,
    "knee_r": (-0.2, 0.0, 1.0), "knee_l": (0.3, 0.2, 1.0),
}


def _tech_roll():
    """own-bend-tech-roll: the side roll (_roll("side")) entered from the breakfall's slap instead of the stand: its first
    three frames (the stand and the weight shift) replaced by the slap, the ball reached two frames after it as before.
    Pass 3 (the critic's notes: from the tumble straight onto the kneeling slap was a one-frame pop): the tech's own airborne
    frame first (TECH0), so the two breaks enter the same way; everything after it one frame later (19 frames, its moments
    one frame later too). The twin's hips tilted 4 degrees down on its slap (twin_keys) so the coat's skirt hangs."""
    c = _roll("side")
    for ch, ks in list(c.items()):
        if not isinstance(ks, list) or ch in ("pivot", "ground", "cart"):
            continue
        rest = [(fr, v) for fr, v in ks if fr >= 3]
        if ch in SLAP and rest:
            c[ch] = [(0, SLAP[ch])] + rest
    for ch in ("hips", "chest", "side", "twist", "head", "roll", "yaw", "look"):
        if ch not in c:
            c[ch] = [(0, SLAP[ch]), (3, 0.0), (18, 0.0)]
    # (the right hand off the deck from the slap, round in over the shoulder to take the deck again as he tips over)
    c["hand_r"] = [k for k in c["hand_r"] if k[0] != 3]
    c["hand_r"] += [(2, (-0.43, 0.17, 0.24)), (3, _unturn((-0.31, 0.14, 0.21), 30, ROLL_PIVOT, "z"))]
    c["hand_r"].sort(key=lambda k: k[0])
    # (one frame later, the airborne entry first)
    for ch, ks in list(c.items()):
        if isinstance(ks, list):
            first = TECH0.get(ch, 0.0 if ch in ("ground", "cart") else ks[0][1])
            c[ch] = [(0, first)] + [(fr + 1, v) for fr, v in ks]
    c["length"] = 19
    c["meta"] = dict(c["meta"], hold_s=2 / FPS, strike_s=8 / FPS, back_s=14 / FPS)
    # (the twin's slap tilt mirrored, 4 degrees more on its kneel)
    c["twin_keys"] = {"roll": [(fr, -v - (4.0 if fr in (1, 2) else 0.0)) for fr, v in c["roll"]]}
    return c


SET6 = {
    # the earth Rise (Pillar): from the fall the legs reach down wide for the column rising out of the water; it takes him
    # (f5) and he slams into a deep Hung Gar horse on its top, both fists driven down outside the knees at the stone (the 0.2 s
    # tell held), the whole figure leaning 20 degrees forward with the column toward the lip; carried up, sinking further
    # into the horse as it drives (the load: the fists grinding in, then lifting at the last), then thrown off its top: the legs
    # drive straight up onto the toes, the right fist driven up over the head as the left is chambered at the hip (pass 3), the chest arched; the feet leave it and he
    # opens into the fall, the knees tucked, the head thrown back last.  hold_s: in the horse; strike_s: thrown off the top;
    # back_s: free of the column
    "rise_earth": {
        "length": 32, "base": AIR,
        "meta": {"hold_s": 6 / FPS, "strike_s": 20 / FPS, "back_s": 24 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "pivot": [(0, (0.0, 0.08, 0.02)), (32, (0.0, 0.08, 0.02))],
        "flip": [(0, 0), (4, 0), (6, 9), (9, 20), (19, 20), (21, 14), (24, 4), (28, 0), (32, 0)],
        # (pass 2: a grinding press at f13 and a lift of the load at f17, so the hold is alive)
        "root": [(0, AIR["root"]), (3, (0.0, 0.03, 0.0)), (5, (0.0, -0.06, 0.0)), (6, (0.0, -0.26, 0.0)), (8, (0.0, -0.41, 0.0)),
                 (10, (0.0, -0.37, 0.0)), (13, (0.0, -0.4, 0.0)), (16, (0.0, -0.385, 0.0)), (18, (0.0, -0.44, 0.0)),
                 (19, (0.0, -0.45, 0.0)), (20, (0.0, -0.14, 0.0)), (21, (0.0, -0.04, 0.0)), (23, (0.0, 0.06, 0.0)),
                 (27, (0.0, 0.03, 0.0)), (32, AIR["root"])],
        "hips": [(0, AIR["hips"]), (3, 4), (5, 10), (6, 22), (8, 30), (10, 27), (13, 30), (16, 28), (19, 34), (20, 12), (21, -6),
                 (23, -12), (25, -6), (28, 0), (32, AIR["hips"])],
        # (pass 2: the chest arched hard over the throw, hurled off the stone)
        "chest": [(0, AIR["chest"]), (3, 2), (6, 8), (8, 14), (10, 11), (13, 14), (16, 12), (19, 16), (20, 2), (21, -12), (23, -20),
                  (25, -14), (28, -3), (32, AIR["chest"])],
        # (the head two frames behind the chest: still down at the throw, thrown back after it)
        "head": [(0, AIR["head"]), (3, 16), (5, 6), (7, -26), (10, -36), (19, -40), (21, -36), (23, -18), (25, -10), (28, -4),
                 (32, AIR["head"])],
        # (pass 3: an asymmetric Hung Gar throw, not a cheer: the trunk twisted and side-bent toward the right as the
        # right fist drives up as a rising bridge hand and the left elbow is pulled down and back to the hip)
        "twist": [(0, 0), (8, -3), (19, -6), (21, -9), (23, -17), (25, -15), (28, -5), (32, 0)],
        "side": [(0, 0), (19, 0), (21, 6), (23, 13), (25, 12), (28, 3), (32, 0)],
        # (pass 2: the clavicles pressed down while the fists drive the stone: a wide triangle)
        "clav_r": [(0, AIR["clav_r"]), (6, (10, 20)), (8, (10, 20)), (17, (10, 18)), (19, (-2, 6)), (20, (-4, -6)), (21, (-6, -18)),
                   (23, (-8, -32)), (25, (-8, -32)), (28, (-4, -14)), (32, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (6, (10, 20)), (8, (10, 20)), (17, (10, 18)), (19, (-2, 8)), (21, (2, 6)), (23, (-6, 10)),
                   (26, (-6, 10)), (29, (-2, -6)), (32, AIR["clav_l"])],
        # (pass 2: the fists driven down OUTSIDE the knees with the elbows nearly locked; pressed and lifted through the load.
        # Pass 3: the right fist carried out in FRONT on its way up (f20 0.42 m ahead), clear of the face and the hat, and
        # driven straight up over the head as the bridge hand (f23); the left fist rising a frame behind it, then its elbow
        # pulled down and back so the fist is chambered at the hip)
        "hand_r": [(0, AR), (3, (-0.4, 1.05, 0.2)), (5, (-0.36, 0.95, 0.32)), (6, (-0.42, 0.6, 0.32)), (8, (-0.43, 0.445, 0.24)),
                   (10, (-0.43, 0.445, 0.24)), (13, (-0.435, 0.415, 0.245)), (15, (-0.43, 0.44, 0.24)), (17, (-0.42, 0.475, 0.25)),
                   (19, (-0.38, 0.84, 0.36)), (20, (-0.38, 1.3, 0.42)), (21, (-0.36, 1.42, 0.2)), (23, (-0.4, 1.62, -0.02)),
                   (25, (-0.41, 1.64, -0.04)), (28, (-0.5, 1.44, 0.06)), (32, AR)],
        "hand_l": [(0, AL), (3, (0.4, 1.05, 0.2)), (5, (0.36, 0.95, 0.32)), (6, (0.42, 0.6, 0.32)), (8, (0.43, 0.445, 0.24)),
                   (10, (0.43, 0.445, 0.24)), (13, (0.435, 0.415, 0.245)), (15, (0.43, 0.44, 0.24)), (17, (0.42, 0.475, 0.25)),
                   (19, (0.39, 0.64, 0.32)), (20, (0.32, 0.85, 0.3)), (21, (0.36, 1.02, 0.28)), (23, (0.32, 1.0, -0.12)),
                   (26, (0.33, 0.98, -0.14)), (29, (0.5, 1.28, -0.02)), (32, AL)],
        "face_r": [(0, "balance"), (3, "fist_gather"), (6, "fist_down"), (17, "fist_down"), (20, "rocket"), (22, "fist_up"),
                   (26, "fist_up"), (30, "balance"), (32, "balance")],
        "face_l": [(0, "balance"), (3, "fist_gather"), (6, "fist_down"), (17, "fist_down"), (20, "rocket"), (23, "chamber"),
                   (27, "chamber"), (31, "balance"), (32, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (6, (-1.0, 0.0, -0.5)), (17, (-1.0, 0.0, -0.5)), (19, (-0.6, -0.4, -0.8)), (21, (-0.9, -0.5, -0.1)),
                   (23, (-1.0, -0.2, 0.1)), (26, (-1.0, -0.2, 0.1)), (32, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (6, (1.0, 0.0, -0.5)), (17, (1.0, 0.0, -0.5)), (20, (0.6, -0.4, -0.8)), (23, (0.4, -0.5, -1.0)),
                   (27, (0.4, -0.5, -1.0)), (32, AIR["pole_l"])],
        # (pass 3: Hung Gar's closed fists kept through the throw)
        "grip_r": [(0, AIR["grip_r"]), (4, 0.8), (6, 1.0), (25, 1.0), (28, 0.3), (32, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (4, 0.8), (6, 1.0), (27, 1.0), (30, 0.3), (32, AIR["grip_l"])],
        # (the left leg a frame or two behind the right off the stone; both knees tucked up as he is hurled off, f25-f26)
        "foot_r": [(0, AFR), (3, (-0.24, 0.17, 0.08)), (5, (-0.31, 0.077, 0.0)), (21, (-0.31, 0.077, 0.0)), (23, (-0.22, 0.24, 0.04)),
                   (25, (-0.15, 0.4, 0.14)), (27, (-0.14, 0.38, 0.16)), (32, AFR)],
        "foot_l": [(0, AFL), (3, (0.24, 0.18, 0.0)), (5, (0.31, 0.077, 0.02)), (21, (0.31, 0.077, 0.02)), (22, (0.29, 0.13, 0.03)), (24, (0.22, 0.24, -0.02)),
                   (26, (0.15, 0.4, 0.06)), (28, (0.14, 0.38, -0.04)), (32, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (3, 22), (5, 0), (19, 0), (20, 24), (21, 46), (23, 52), (27, 40), (32, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (3, 22), (5, 0), (19, 0), (20, 12), (21, 30), (22, 46), (24, 52), (28, 40), (32, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (4, 26), (21, 26), (26, 10), (32, AIR["fyaw_r"])],
        "fyaw_l": [(0, AIR["fyaw_l"]), (4, 26), (22, 26), (27, 10), (32, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (4, (-0.75, 0.1, 0.7)), (19, (-0.75, 0.1, 0.7)), (21, (-0.3, 0.0, 1.0)), (32, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (4, (0.75, 0.1, 0.7)), (20, (0.75, 0.1, 0.7)), (22, (0.3, 0.0, 1.0)), (32, AIR["knee_l"])],
    },
    # the water Rise (Fountain): a deep sink (the palms pressed down before the belly, the knees drawn: the 0.12 s tell), the
    # legs reach down onto the water column on both flat feet, the knees soft, riding its surge as it lifts him; the arms
    # swirl round two big circles out in front of the body (tai chi's cloud hands: the right from the bottom out to his
    # right and over, the left WATER_LAG behind), the trunk turning, leaning and the hips swaying after the leading hand and
    # the eyes two frames after it, into the white crane at the top (pass 3): the right palm high over the head and out, the
    # left pressed down by the hip, the trunk turned and leant toward the high hand (a moving hold); they open out into the
    # fall.  hold_s: the sink; strike_s: the column takes him; back_s: the top
    "rise_water": _rise_water(),
    # the fire Rise (Jet): the hover tell (8 f): the knees drawn up high under him, both fists chambered at the hips with
    # the elbows back, the chest swelling and the head thrown back on the roar, a small bob; then the burst (10 f): snapped
    # long and straight along it in two frames, leant 25 degrees into the flight, the legs straight and together with the
    # toes pointed (the jet's nozzle), the right fist punched up and ahead leading the body (Northern Shaolin's rising
    # punch), the left fist kept at the hip, the eyes along the burst; then opened into the fall.  hold_s: the hover;
    # strike_s: the burst; back_s: the burst spent
    "rise_fire": {
        "length": 24, "base": AIR,
        "meta": {"hold_s": 4 / FPS, "strike_s": 8 / FPS, "back_s": 18 / FPS, "hand": "r", "mask": "full", "root": "place"},
        "flip": [(0, 0), (7, 0), (8, 16), (9, 25), (18, 25), (21, 8), (24, 0)],
        "root": [(0, AIR["root"]), (3, (0.0, 0.05, 0.0)), (5, (0.0, 0.075, 0.0)), (7, (0.0, 0.05, 0.0)), (8, (0.0, 0.07, 0.0)),
                 (10, (0.0, 0.09, 0.0)), (18, (0.0, 0.1, 0.0)), (21, (0.0, 0.04, 0.0)), (24, AIR["root"])],
        # (pass 2: the hover a hard crunch, then the roar with the head thrown back: the punishable tell at 15 m)
        "hips": [(0, AIR["hips"]), (3, 18), (5, 24), (7, 17), (8, 2), (10, -3), (18, -3), (21, 4), (24, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (3, 5), (5, 10), (7, 0), (8, -4), (10, -7), (18, -9), (21, 0), (24, AIR["chest"])],
        "head": [(0, AIR["head"]), (3, 4), (5, 8), (7, -16), (8, -12), (10, -20), (18, -24), (21, -6), (24, AIR["head"])],
        # (the right shoulder leads the burst, and keeps turning into it through the hold)
        "twist": [(0, 0), (3, 0), (7, -6), (8, 8), (10, 15), (18, 18), (22, 0), (24, 0)],
        "clav_r": [(0, AIR["clav_r"]), (3, (-10, 4)), (5, (-12, 2)), (7, (-12, 4)), (8, (6, -24)), (10, (10, -30)), (18, (10, -32)),
                   (21, (0, -16)), (24, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (3, (-10, 4)), (5, (-12, 2)), (7, (-12, 4)), (10, (-12, 6)), (18, (-12, 6)), (21, (-4, -8)),
                   (24, AIR["clav_l"])],
        # (the rising punch travels in front of the right shoulder on a forward arc, the face clear, and keeps driving on
        # along the burst through the hold)
        "hand_r": [(0, AR), (3, (-0.2, 0.96, -0.02)), (7, (-0.2, 0.94, -0.05)), (8, (-0.27, 1.5, 0.38)), (9, (-0.1, 1.86, 0.15)),
                   (13, (-0.09, 1.875, 0.155)), (18, (-0.075, 1.9, 0.17)), (21, (-0.45, 1.45, 0.12)), (24, AR)],
        # (the left fist settles at the hip, out and a little back, two frames late with an overshoot)
        "hand_l": [(0, AL), (3, (0.2, 0.96, -0.02)), (7, (0.2, 0.94, -0.05)), (8, (0.21, 0.95, -0.06)), (10, (0.3, 0.955, -0.15)),
                   (12, (0.28, 0.98, -0.12)), (18, (0.28, 0.985, -0.12)), (21, (0.42, 1.15, 0.0)), (24, AL)],
        "face_r": [(0, "balance"), (3, "chamber"), (7, "chamber"), (9, "rocket"), (18, "rocket"), (22, "balance"), (24, "balance")],
        "face_l": [(0, "balance"), (3, "chamber"), (18, "chamber"), (22, "balance"), (24, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-0.4, -0.3, -1.0)), (7, (-0.4, -0.3, -1.0)), (9, (-1.0, 0.0, -0.2)), (18, (-1.0, 0.0, -0.2)),
                   (24, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (3, (0.4, -0.3, -1.0)), (7, (0.4, -0.3, -1.0)), (10, (0.8, -0.3, -0.6)), (18, (0.8, -0.3, -0.6)),
                   (24, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (3, 1.0), (18, 1.0), (21, 0.2), (24, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (3, 1.0), (18, 1.0), (21, 0.2), (24, AIR["grip_l"])],
        # (the legs snap long a frame after the trunk; through the burst they scissor a little, feet alternating)
        "foot_r": [(0, AFR), (3, (-0.13, 0.5, 0.2)), (5, (-0.13, 0.53, 0.2)), (7, (-0.13, 0.55, 0.21)), (8, (-0.12, 0.42, 0.14)),
                   (9, _heel_key("r", (-0.09, 0.24, 0.02), 62.0, 2.0)), (10, _heel_key("r", (-0.08, 0.184, -0.02), 66.0, 2.0)),
                   (11, _heel_key("r", (-0.08, 0.186, 0.01), 66.0, 2.0)), (14, _heel_key("r", (-0.08, 0.184, -0.05), 66.0, 2.0)),
                   (17, _heel_key("r", (-0.08, 0.186, 0.01), 66.0, 2.0)), (18, _heel_key("r", (-0.08, 0.185, 0.0), 66.0, 2.0)),
                   (21, (-0.13, 0.3, 0.12)), (24, AFR)],
        "foot_l": [(0, AFL), (3, (0.13, 0.46, 0.12)), (5, (0.13, 0.5, 0.12)), (7, (0.13, 0.51, 0.13)), (8, (0.12, 0.4, 0.08)),
                   (9, _heel_key("l", (0.09, 0.24, 0.0), 62.0, 2.0)), (10, _heel_key("l", (0.08, 0.177, -0.03), 66.0, 2.0)),
                   (11, _heel_key("l", (0.08, 0.175, -0.06), 66.0, 2.0)), (14, _heel_key("l", (0.08, 0.177, 0.0), 66.0, 2.0)),
                   (17, _heel_key("l", (0.08, 0.175, -0.06), 66.0, 2.0)), (18, _heel_key("l", (0.08, 0.176, -0.05), 66.0, 2.0)),
                   (21, (0.13, 0.33, -0.1)), (24, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (3, 30), (8, 36), (9, 62), (10, 66), (18, 66), (24, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (3, 30), (8, 36), (9, 62), (10, 66), (18, 66), (24, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (9, 2), (18, 2), (24, AIR["fyaw_r"])], "fyaw_l": [(0, AIR["fyaw_l"]), (9, 2), (18, 2), (24, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (3, (-0.25, 0.3, 1.0)), (8, (-0.25, 0.3, 1.0)), (10, (-0.05, 0.0, 1.0)), (18, (-0.05, 0.0, 1.0)),
                   (24, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (3, (0.25, 0.3, 1.0)), (8, (0.25, 0.3, 1.0)), (10, (0.05, 0.0, 1.0)), (18, (0.05, 0.0, 1.0)),
                   (24, AIR["knee_l"])],
    },
    # the air Rise (Updraft): wound up the other way (the arms crossed before the chest, the knees drawn), then whirled up
    # through one whole turn as a Baguazhang palm change (the trunk wrung hard, the right palm thrust out flat at the
    # shoulder's height beyond the turn, the left palm guarding under the right elbow, both feet tucked up together, the
    # head leading the turn), unfurled into the glide (from f14 a loop to the end: meta loop_from_s):
    # laid forward into the wind with the arms spread as wings, banking slowly from side to side.  hold_s: the wind-up;
    # strike_s: the whirl starts; back_s: the glide
    "rise_air": _rise_air(),
    # the scramble (18 f): a Rise that meets the deck's face below the lip: carried up close along the face by the Rise
    # with both arms up, the right hand thrown up over the lip at the top of the rise (f2) and slapped down flat on the deck
    # (f3: a foe on the deck sees the hand land in the first 0.1 s), the head up over the lip looking along the deck; the
    # body sags onto that straight arm as the left palm slaps the face under the lip for a brace and the right foot kicks
    # onto the face (scrabbling, slipping and re-planted higher), the left foot planted; then the left hand thrown over the
    # lip and down onto the deck (f7-f8), and the body hauled up the face on both past the hang and settled into the hang's
    # first pose exactly (the code's slide up the face to the hang takes 0.3 s; the clip carries the last 0.45 m of the haul
    # itself). Pass 3 (the critic's notes): the right hand over the lip at f2 instead of f6, each hand's last frame before
    # the deck its apex over the landing (an arc over the lip and down, not a jump up and a drop).
    # hold_s: the right hand over the lip; strike_s: it lands on the deck; back_s: hauled up, settling
    "edge_scramble": {
        "length": 18, "base": HANG,
        "meta": dict(EDGE_META, hold_s=2 / FPS, strike_s=3 / FPS, back_s=12 / FPS, haul_m=0.45),
        # (the Rise's momentum carries him up the face to the right hand's slap (f3), he sags onto the arm (f5), then the haul)
        "root": [(0, (0.0, 0.43, -0.06)), (1, (0.0, 0.6, -0.03)), (2, (0.0, 0.73, -0.01)), (3, (0.0, 0.79, 0.0)), (4, (0.0, 0.775, 0.0)),
                 (5, (0.0, 0.765, 0.0)), (6, (0.0, 0.79, 0.0)), (8, (0.0, 0.87, -0.01)), (10, (0.0, 0.95, -0.02)), (12, (0.0, 0.94, -0.02)),
                 (14, (0.0, 0.905, -0.015)), (18, HANG["root"])],
        "hips": [(0, 2), (2, 10), (3, 14), (5, 16), (7, 20), (10, 28), (12, 27), (18, HANG["hips"])],
        "chest": [(0, -6), (2, 2), (3, 6), (5, 8), (7, 12), (10, 11), (13, 8), (18, HANG["chest"])],
        "head": [(0, -34), (1, -26), (3, -10), (5, -14), (7, -18), (8, -22), (10, -14), (12, -20), (18, HANG["head"])],
        "roll": [(0, 0.0), (2, -6), (4, 5), (6, -4), (8, 4), (11, 0), (18, HANG["roll"])],
        "twist": [(0, 0.0), (2, -8), (4, 5), (7, -4), (9, 3), (12, 0), (18, HANG["twist"])],
        "side": [(0, 0.0), (2, 4), (4, -3), (7, 2), (12, 0), (18, HANG["side"])],
        "look": [(0, 0.0), (2, -6), (4, 8), (8, -4), (12, 0), (18, HANG["look"])],
        "clav_r": [(0, (0, -28)), (1, (4, -26)), (2, (6, -24)), (3, (8, -14)), (5, (8, -16)), (8, (8, -20)), (11, (8, -14)),
                   (14, (6, -20)), (18, HANG["clav_r"])],
        "clav_l": [(0, (0, -30)), (2, (2, -20)), (4, (4, -10)), (6, (4, -12)), (7, (2, -26)), (8, (6, -20)), (10, (8, -20)),
                   (13, (6, -16)), (18, HANG["clav_l"])],
        # (each hand's arc: up past the lip, its apex over the place it lands, slapped down onto the deck)
        "hand_r": [(0, (-0.3, 2.0, 0.18)), (1, (-0.3, 2.17, 0.33)), (2, (-0.28, 2.27, 0.47)), (3, GR), (18, GR)],
        "hand_l": [(0, (0.28, 2.05, 0.17)), (2, (0.27, 1.98, 0.27)), (3, (0.24, 1.95, 0.32)), (6, (0.24, 1.95, 0.32)),
                   (7, (0.28, 2.26, 0.52)), (8, GL), (18, GL)],
        "face_r": [(0, "lip_reach"), (2, "lip_reach"), (3, "deck"), (18, "deck")],
        "face_l": [(0, "lip_reach"), (2, "lip_reach"), (3, "wall"), (6, "wall"), (7, "lip_reach"), (8, "deck"), (18, "deck")],
        "pole_r": [(0, (-0.6, -0.6, -0.4)), (2, (-1.0, -0.3, -0.2)), (3, (-0.5, -1.0, -0.2)), (18, HANG["pole_r"])],
        "pole_l": [(0, (0.6, -0.6, -0.4)), (3, (0.8, -0.5, -0.3)), (6, (0.8, -0.6, -0.3)), (7, (1.0, -0.3, -0.2)), (8, (0.5, -1.0, -0.2)),
                   (18, HANG["pole_l"])],
        "grip_r": [(0, -0.3), (2, -0.45), (3, 0.45), (7, 0.35), (18, HANG["grip_r"])],
        "grip_l": [(0, -0.3), (3, -0.45), (6, -0.4), (8, 0.45), (12, 0.35), (18, HANG["grip_l"])],
        # (the scrabble: the right foot kicked onto the face at f2, slipping 4 cm at f4, off it at f5 and re-planted higher
        # at f7; the left planted at f4 and walked up at f9; both onto the hang's places by f11-f13; a planted ball keeps its
        # place: the foot keys are the deck's frame and its heel lifts about the ball)
        "foot_r": [(0, (-0.14, 0.6, -0.02)), (2, (-0.16, 1.02, SCR_FACE_Z)), (3, (-0.16, 1.02, SCR_FACE_Z)), (4, (-0.16, 0.98, SCR_FACE_Z)),
                   (5, (-0.15, 1.06, 0.08)), (7, (-0.16, 1.22, SCR_FACE_Z)), (10, (-0.16, 1.22, SCR_FACE_Z)), (13, GFR), (18, GFR)],
        "foot_l": [(0, (0.14, 0.54, -0.08)), (2, (0.15, 0.8, 0.04)), (4, (0.16, 1.0, SCR_FACE_Z)), (7, (0.16, 1.0, SCR_FACE_Z)),
                   (9, (0.155, 1.07, 0.12)), (11, GFL), (18, GFL)],
        "heel_r": [(0, 30), (2, 4), (3, 4), (4, 14), (5, 30), (7, 4), (10, 6), (13, HANG["heel_r"]), (18, HANG["heel_r"])],
        "heel_l": [(0, 32), (2, 24), (4, 4), (7, 6), (9, 24), (11, HANG["heel_l"]), (18, HANG["heel_l"])],
        "fyaw_r": [(0, 6), (2, HANG["fyaw_r"]), (18, HANG["fyaw_r"])], "fyaw_l": [(0, 8), (4, HANG["fyaw_l"]), (18, HANG["fyaw_l"])],
        "knee_r": [(0, (-0.2, 0.0, 1.0)), (2, (-0.4, 0.3, 1.0)), (5, (-0.4, 0.5, 1.0)), (7, (-0.35, 0.2, 1.0)), (18, HANG["knee_r"])],
        "knee_l": [(0, (0.2, 0.0, 1.0)), (4, (0.35, 0.3, 1.0)), (9, (0.35, 0.5, 1.0)), (11, (0.3, 0.1, 1.0)), (18, HANG["knee_l"])],
    },
    # breaking the fall on the deck (E just as he lands: up at once): he comes down out of the tumble flung open and takes the
    # deck in a three-point breakfall (the right knee down, the left foot planted ahead, the right arm flung straight out to
    # the side and its palm slapped flat on the deck, the left arm flung up and back, the head up with the eyes on the foe),
    # the slap's rebound drives him straight up (the right foot stepping in under him) through the stand a touch past onto
    # the toes, the arms swinging on forward past the stand and the chest rocking back, a dip and a settle on the last
    # frames (pass 3: the follow-through ends on f14, not f9).  strike_s: the slap; hold_s: its rebound; back_s: driving up
    "tech": {
        "length": 14,
        "meta": {"strike_s": 1 / FPS, "hold_s": 2 / FPS, "back_s": 4 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, TECH0["root"]), (1, SLAP["root"]), (2, (0.0, -0.41, 0.03)), (3, (0.0, -0.3, 0.03)), (4, (0.0, -0.21, 0.03)),
                 (6, (0.0, -0.07, 0.01)), (8, (0.0, 0.006, 0.0)), (9, (0.0, 0.0, 0.0)), (11, (0.0, -0.03, 0.0)), (13, (0.0, -0.012, 0.0)),
                 (14, STAND["root"])],
        "hips": [(0, TECH0["hips"]), (1, SLAP["hips"]), (2, 34), (3, 28), (4, 20), (6, 8), (8, -2), (10, 1.5), (12, 0.5), (14, 0)],
        "chest": [(0, TECH0["chest"]), (1, SLAP["chest"]), (2, 14), (4, 8), (6, 2), (9, -4), (12, 1.5), (14, 0)],
        "side": [(0, TECH0["side"]), (1, SLAP["side"]), (2, 28), (4, 10), (7, 0), (14, 0)],
        "roll": [(0, 0.0), (1, SLAP["roll"]), (2, 16), (4, 4), (6, 0), (14, 0)],
        "twist": [(0, TECH0["twist"]), (1, SLAP["twist"]), (3, -5), (6, 0), (14, 0)],
        "head": [(0, TECH0["head"]), (1, SLAP["head"]), (2, -28), (4, -14), (6, -4), (8, 2), (10, -1), (12, 0.5), (14, 0)],
        "tilt": [(0, 0.0), (1, SLAP["tilt"]), (2, -26), (4, -10), (7, 0), (14, 0)],
        "look": [(0, 0.0), (1, SLAP["look"]), (3, -12), (6, -4), (9, 0), (14, 0)],
        "clav_r": [(0, TECH0["clav_r"]), (1, SLAP["clav_r"]), (3, (6, 8)), (6, (2, 0)), (14, (0, 0))],
        "clav_l": [(0, TECH0["clav_l"]), (1, SLAP["clav_l"]), (3, (-8, -20)), (6, (0, -6)), (10, (0, 0)), (14, (0, 0))],
        # (the slapping palm held a frame on the deck, then up past the hip; both hands swinging on forward to z 0.14 at
        # f10 and back to the stand at f13)
        "hand_r": [(0, TECH0["hand_r"]), (1, SLAP["hand_r"]), (2, (-0.43, 0.19, 0.22)), (3, (-0.4, 0.42, 0.25)), (4, (-0.37, 0.6, 0.26)),
                   (5, (-0.36, 0.72, 0.26)), (7, (-0.3, 0.92, 0.2)), (9, (-0.24, 0.86, 0.16)), (10, (-0.22, 0.83, 0.14)), (13, HR), (14, HR)],
        "hand_l": [(0, TECH0["hand_l"]), (1, SLAP["hand_l"]), (2, (0.1, 1.1, 0.1)), (3, (0.3, 1.08, 0.08)), (4, (0.44, 0.98, 0.06)),
                   (6, (0.42, 1.0, 0.08)),
                   (8, (0.3, 0.9, 0.14)), (10, (0.22, 0.83, 0.14)), (13, HL), (14, HL)],
        "face_r": [(0, "flail"), (1, "deck_out"), (2, "deck_out"), (4, "palm_down"), (7, "balance"), (11, "stand"), (14, "stand")],
        "face_l": [(0, "flail"), (1, "flung_up"), (3, "flung_up"), (6, "balance"), (11, "stand"), (14, "stand")],
        "pole_r": [(0, TECH0["pole_r"]), (1, SLAP["pole_r"]), (2, SLAP["pole_r"]), (4, (-1.0, 0.0, -0.3)), (7, (-0.6, -0.5, -0.6)),
                   (14, STAND["pole_r"])],
        "pole_l": [(0, TECH0["pole_l"]), (1, SLAP["pole_l"]), (4, (0.6, -0.6, -0.5)), (8, (0.5, -0.4, -0.8)), (14, STAND["pole_l"])],
        "grip_r": [(0, -0.3), (1, -0.4), (3, -0.3), (6, 0.1), (14, 0.4)], "grip_l": [(0, -0.3), (2, -0.3), (6, 0.1), (14, 0.4)],
        # (the right knee to the deck, the toes tucked under, then stepped through to the stand; the left planted ahead, then
        # drawn back in as he rises)
        "foot_r": [(0, TECH0["foot_r"]), (1, SLAP["foot_r"]), (3, SLAP["foot_r"]), (5, _heel_key("r", (-0.14, 0.14, -0.14), 30.0, 6.0)),
                   (6, FR), (14, FR)],
        "foot_l": [(0, TECH0["foot_l"]), (1, SLAP["foot_l"]), (4, SLAP["foot_l"]), (6, (0.15, 0.12, 0.12)), (7, FL), (14, FL)],
        "heel_r": [(0, TECH0["heel_r"]), (1, SLAP["heel_r"]), (3, SLAP["heel_r"]), (5, 30), (6, 0), (8, 5), (10, 0), (14, 0)],
        "heel_l": [(0, TECH0["heel_l"]), (1, 0), (4, 0), (5, 14), (7, 0), (8, 5), (10, 0), (14, 0)],
        "fyaw_r": [(0, TECH0["fyaw_r"]), (1, SLAP["fyaw_r"]), (5, 6), (6, 7), (14, 7)],
        "fyaw_l": [(0, TECH0["fyaw_l"]), (1, SLAP["fyaw_l"]), (5, 10), (7, 7), (14, 7)],
        "knee_r": [(0, TECH0["knee_r"]), (1, SLAP["knee_r"]), (3, SLAP["knee_r"]), (6, (-0.2, 0.0, 1.0)), (9, "auto")],
        "knee_l": [(0, TECH0["knee_l"]), (1, SLAP["knee_l"]), (4, SLAP["knee_l"]), (7, (0.25, 0.0, 1.0)), (9, "auto")],
    },
    # breaking the fall with a roll (2.5 m in 0.4 s by the code, to his right; its twin to the left): the slap's
    # three-point breakfall, and its momentum carried straight on into the side roll over the right shoulder and the back,
    # up off the left leg first and on to the stand.  hold_s: into the ball; strike_s: over the back; back_s: on his feet
    "tech_roll": _tech_roll(),
    # breaking the fall on a wall (the deck's face, an ice or earth wall, a Column: E as he meets it): flung open into it, he
    # takes the wall like a cat, the soles and the palms flat on it, the knees and the elbows folding deep (stuck 0.1 s);
    # then the legs drive and the arms shove him off it (the code springs him at vy +3), the head and the eyes turned up
    # and back the way he goes, the arms flung up and open and the legs trailing, into the fall. The wall WALL_Z ahead
    # (meta wall_z).  strike_s: the plant; hold_s: stuck; back_s: the push
    "tech_wall": {
        "length": 15, "base": AIR,
        "meta": {"strike_s": 1 / FPS, "hold_s": 3 / FPS, "back_s": 5 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "wall_z": 0.5},
        # (pass 2: a cat taking the wall: the hips pressed in toward it and low, the knees and the elbows splayed wide, the
        # head turning back over the shoulder the way he will spring as the anticipation; the palms push off first (f4-f5),
        # the soles a frame later (f6), the arms flung up and open, the legs trailing to f9)
        # (pass 3: the head kept back off the wall (the hat brim 8 cm and more off it): the hips held 7 cm in, the chest upright,
        # the head tipped back to look up and turned back over the shoulder from the first contact; the palms spread wide
        # and high with the elbows splayed: a cat on the wall, not a face pressed to glass)
        "root": [(0, AIR["root"]), (1, (0.0, -0.04, 0.08)), (2, (0.0, -0.07, 0.085)), (3, (0.0, -0.08, 0.085)), (4, (0.0, -0.05, 0.085)),
                 (5, (0.0, 0.0, -0.06)), (6, (0.0, 0.03, -0.13)), (8, (0.0, 0.05, -0.12)), (11, (0.0, 0.02, -0.04)), (15, AIR["root"])],
        "hips": [(0, -6), (1, 18), (2, 20), (3, 21), (4, 15), (5, 2), (6, -8), (8, -12), (11, -2), (15, AIR["hips"])],
        "chest": [(0, -10), (1, 2), (2, 2), (3, 2), (4, 0), (5, -8), (6, -14), (8, -16), (11, -4), (15, AIR["chest"])],
        "head": [(0, -12), (1, -22), (2, -30), (3, -30), (5, -30), (7, -24), (10, -6), (15, AIR["head"])],
        "look": [(0, 0), (1, 22), (2, 28), (3, 34), (5, 36), (8, 20), (12, 4), (15, 0)],
        "twist": [(0, 0), (2, 2), (3, 6), (5, 10), (9, 4), (15, 0)],
        "clav_r": [(0, (-6, -22)), (1, (8, 4)), (3, (12, 10)), (4, (10, 6)), (5, (-2, -12)), (7, (-8, -28)), (11, (-4, -14)), (15, AIR["clav_r"])],
        "clav_l": [(0, (-6, -22)), (1, (8, 4)), (3, (12, 10)), (4, (10, 6)), (5, (-2, -12)), (7, (-8, -28)), (11, (-4, -14)), (15, AIR["clav_l"])],
        "hand_r": [(0, (-0.5, 1.32, -0.18)), (1, (-0.45, 1.41, 0.47)), (4, (-0.45, 1.41, 0.47)), (5, (-0.44, 1.48, 0.21)),
                   (7, (-0.48, 1.57, -0.12)), (10, (-0.58, 1.44, -0.04)), (15, AR)],
        "hand_l": [(0, (0.5, 1.34, -0.16)), (1, (0.45, 1.42, 0.47)), (4, (0.45, 1.42, 0.47)), (5, (0.42, 1.48, 0.19)),
                   (7, (0.48, 1.58, -0.12)), (10, (0.58, 1.45, -0.04)), (15, AL)],
        "face_r": [(0, "flail"), (1, "wall"), (4, "wall"), (6, "flung_up"), (9, "flung_up"), (12, "balance"), (15, "balance")],
        "face_l": [(0, "flail"), (1, "wall"), (4, "wall"), (6, "flung_up"), (9, "flung_up"), (12, "balance"), (15, "balance")],
        "pole_r": [(0, (-0.4, -0.6, -0.6)), (1, (-1.0, -0.1, 0.0)), (4, (-1.0, -0.2, 0.0)), (6, (-1.0, 0.0, -0.3)), (15, AIR["pole_r"])],
        "pole_l": [(0, (0.4, -0.6, -0.6)), (1, (1.0, -0.1, 0.0)), (4, (1.0, -0.2, 0.0)), (6, (1.0, 0.0, -0.3)), (15, AIR["pole_l"])],
        "grip_r": [(0, -0.3), (1, -0.45), (4, -0.45), (6, -0.3), (15, AIR["grip_r"])],
        "grip_l": [(0, -0.3), (1, -0.45), (4, -0.45), (6, -0.3), (15, AIR["grip_l"])],
        # (the soles flat on the wall: the toes up about the heels (heel -80), the balls of the feet touching it (the ball
        # 2 cm in from the wall, its own radius); held through the push (f5) while the legs straighten, off at f6, trailing)
        "foot_r": [(0, (-0.18, 0.32, 0.12)), (1, _heel_key("r", (-0.2, 0.56, 0.41), -80.0, 14.0)),
                   (5, _heel_key("r", (-0.2, 0.56, 0.41), -80.0, 14.0)), (6, (-0.19, 0.46, 0.3)), (8, (-0.15, 0.34, 0.12)),
                   (10, (-0.13, 0.28, 0.12)), (15, AFR)],
        "foot_l": [(0, (0.18, 0.36, 0.04)), (1, _heel_key("l", (0.2, 0.58, 0.41), -80.0, 14.0)),
                   (5, _heel_key("l", (0.2, 0.58, 0.41), -80.0, 14.0)), (6, (0.19, 0.48, 0.28)), (9, (0.15, 0.36, -0.02)),
                   (11, (0.14, 0.33, -0.1)), (15, AFL)],
        "heel_r": [(0, 30), (1, -80), (5, -80), (6, -20), (7, 20), (9, 40), (15, AIR["heel_r"])],
        "heel_l": [(0, 30), (1, -80), (5, -80), (6, -20), (7, 20), (9, 40), (15, AIR["heel_l"])],
        "fyaw_r": [(0, 6), (1, 14), (5, 14), (8, 6), (15, AIR["fyaw_r"])], "fyaw_l": [(0, 8), (1, 14), (5, 14), (8, 8), (15, AIR["fyaw_l"])],
        "knee_r": [(0, (-0.3, 0.0, 1.0)), (1, (-0.85, 0.5, 0.4)), (3, (-0.85, 0.55, 0.35)), (5, (-0.4, 0.3, 1.0)), (15, AIR["knee_r"])],
        "knee_l": [(0, (0.3, 0.0, 1.0)), (1, (0.85, 0.5, 0.4)), (3, (0.85, 0.55, 0.35)), (5, (0.4, 0.3, 1.0)), (15, AIR["knee_l"])],
    },

    # the spiked knock (driven down from above): the hit folds him hard (struck at f1, the deepest fold at f2-f3: the chest
    # and the head slammed down over the hips, the arms whipped up behind over the back, the legs kicked back), then he is
    # snapped into a feet-first plunge (f5, the legs a frame behind the trunk): driven, not dropped (pass 3, the critic's
    # notes): the trunk tipped 6-12 degrees off the vertical and wobbling slowly, the chest arched back with the head pressed
    # down watching the water come, the arms whipped up past the hold (f6) and settling, the elbows bent and the hands about
    # 0.45 m apart flailing out of step, the knees a little bent, the legs scissoring in the rush (hold_s, while it lasts);
    # opened back into the fall.
    # strike_s: the hit; hold_s: the plunge; back_s: the recovery
    "knock_spiked": {
        "length": 22, "base": AIR,
        "meta": {"strike_s": 1 / FPS, "hold_s": 5 / FPS, "back_s": 14 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "flip": [(0, 0), (1, 6), (3, 14), (5, 6), (8, 9), (11, 12), (14, 4), (18, 3), (22, 0)],
        "cart": [(0, 0), (5, 0), (8, -4), (11, 3), (14, -2), (18, 0), (22, 0)],
        "root": [(0, AIR["root"]), (1, (0.0, 0.05, -0.04)), (3, (0.0, 0.02, -0.03)), (5, (0.0, 0.0, 0.0)), (14, (0.0, -0.01, 0.0)),
                 (18, (0.0, 0.01, 0.0)), (22, AIR["root"])],
        "hips": [(0, AIR["hips"]), (1, 30), (2, 40), (3, 40), (4, 8), (5, -4), (9, -5), (14, -4), (18, 2), (22, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (1, 28), (2, 36), (3, 35), (4, 2), (5, -12), (9, -12), (14, -11), (18, 0), (22, AIR["chest"])],
        "head": [(0, AIR["head"]), (1, 22), (2, 40), (3, 40), (5, 30), (7, 38), (10, 42), (14, 42), (18, 12), (22, AIR["head"])],
        "look": [(0, 0), (5, 0), (9, 8), (14, 12), (18, 4), (22, 0)],
        "clav_r": [(0, AIR["clav_r"]), (1, (-10, -20)), (3, (-12, -24)), (5, (-10, -34)), (6, (-10, -38)), (9, (-10, -32)),
                   (14, (-10, -33)), (18, (-2, -16)), (22, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (1, (-10, -20)), (3, (-12, -24)), (5, (-10, -33)), (7, (-10, -38)), (10, (-10, -32)),
                   (14, (-10, -33)), (18, (-2, -16)), (22, AIR["clav_l"])],
        # (whipped up past the hold, f6-f7, and settled by f9 with the elbows bent; then each hand flailing on its own beat)
        "hand_r": [(0, AR), (1, (-0.3, 1.28, -0.12)), (2, (-0.26, 1.3, 0.06)), (3, (-0.25, 1.32, 0.08)), (5, (-0.21, 1.74, 0.02)),
                   (6, (-0.2, 1.83, 0.0)), (9, (-0.21, 1.77, 0.05)), (11, (-0.28, 1.74, -0.03)), (13, (-0.2, 1.78, 0.05)),
                   (14, (-0.23, 1.76, 0.02)), (18, (-0.5, 1.5, -0.04)), (22, AR)],
        "hand_l": [(0, AL), (1, (0.3, 1.3, -0.11)), (2, (0.26, 1.31, 0.07)), (3, (0.25, 1.33, 0.09)), (5, (0.2, 1.7, 0.01)),
                   (7, (0.21, 1.83, 0.0)), (8, (0.26, 1.78, -0.03)), (10, (0.19, 1.74, 0.05)), (12, (0.27, 1.77, -0.02)),
                   (14, (0.23, 1.76, 0.01)), (18, (0.5, 1.52, -0.04)), (22, AL)],
        "face_r": [(0, "balance"), (1, "flung_up"), (3, "loose_up"), (5, "sky"), (14, "sky"), (19, "balance"), (22, "balance")],
        "face_l": [(0, "balance"), (1, "flung_up"), (3, "loose_up"), (5, "sky"), (14, "sky"), (19, "balance"), (22, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (1, (-0.6, -0.4, -0.7)), (3, (-0.8, 0.2, -0.5)), (5, (-1.0, 0.0, 0.1)), (9, (-1.0, -0.2, 0.2)),
                   (14, (-1.0, -0.2, 0.2)), (22, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (1, (0.6, -0.4, -0.7)), (3, (0.8, 0.2, -0.5)), (5, (1.0, 0.0, 0.1)), (9, (1.0, -0.2, 0.2)),
                   (14, (1.0, -0.2, 0.2)), (22, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (1, -0.4), (5, -0.1), (7, -0.3), (10, 0.05), (12, -0.25), (14, -0.15), (22, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (1, -0.4), (5, -0.15), (8, 0.05), (11, -0.3), (13, 0.0), (14, -0.1), (22, AIR["grip_l"])],
        # (the legs kicked back by the fold, a frame behind the trunk's snap, then together under him with the knees a little
        # bent, the toes pointed down, scissoring 4 cm)
        "foot_r": [(0, AFR), (1, (-0.14, 0.32, -0.24)), (2, (-0.12, 0.36, -0.3)), (3, (-0.11, 0.34, -0.28)), (4, (-0.1, 0.3, -0.24)),
                   (5, (-0.09, 0.2, -0.1)), (6, _heel_key("r", (-0.07, 0.088, 0.02), 60.0, 4.0)),
                   (8, _heel_key("r", (-0.07, 0.088, 0.05), 60.0, 4.0)), (10, _heel_key("r", (-0.07, 0.088, -0.02), 60.0, 4.0)),
                   (13, _heel_key("r", (-0.07, 0.088, 0.05), 60.0, 4.0)), (14, _heel_key("r", (-0.07, 0.088, 0.04), 60.0, 4.0)),
                   (18, (-0.13, 0.26, 0.14)), (22, AFR)],
        "foot_l": [(0, AFL), (1, (0.14, 0.34, -0.28)), (2, (0.12, 0.38, -0.33)), (3, (0.11, 0.36, -0.3)), (4, (0.1, 0.32, -0.26)),
                   (5, (0.09, 0.22, -0.12)), (6, _heel_key("l", (0.07, 0.088, 0.01), 60.0, 4.0)),
                   (8, _heel_key("l", (0.07, 0.088, -0.02), 60.0, 4.0)), (10, _heel_key("l", (0.07, 0.088, 0.05), 60.0, 4.0)),
                   (13, _heel_key("l", (0.07, 0.088, -0.01), 60.0, 4.0)), (14, _heel_key("l", (0.07, 0.088, 0.0), 60.0, 4.0)),
                   (18, (0.13, 0.3, -0.14)), (22, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (1, 40), (3, 46), (5, 52), (6, 60), (14, 60), (18, 34), (22, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (1, 40), (3, 46), (5, 52), (6, 60), (14, 60), (18, 34), (22, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (5, 3), (14, 3), (22, AIR["fyaw_r"])], "fyaw_l": [(0, AIR["fyaw_l"]), (5, 3), (14, 3), (22, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (1, (-0.2, -0.3, 1.0)), (4, (-0.2, -0.3, 1.0)), (6, (-0.08, 0.0, 1.0)), (14, (-0.08, 0.0, 1.0)),
                   (22, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (1, (0.2, -0.3, 1.0)), (4, (0.2, -0.3, 1.0)), (6, (0.08, 0.0, 1.0)), (14, (0.08, 0.0, 1.0)),
                   (22, AIR["knee_l"])],
    },
}

## The lying ones, keyed on the deck (_wclip).
SET6.update({
    # the lie (a loop): dazed on his back (lie_at), breathing
    "lie": dict({"length": LIE_LEN, "loop": True, "toes": "foot", "meta": {"hand": "both", "mask": "full", "root": "place",
                                                                         "legs_always": 1.0, "lying": 1.0}},
                **_wclip(LIE_LEN, {k: (lambda f, k=k: lie_at(f)[k]) for k in LIE}, loop=True)),
    # the bounce (the back meets the deck falling fast): he comes down flat on his back with the limbs trailing up high
    # (the hands 0.8 m and the feet 0.6 m over the deck, the legs nearly straight); the trunk stops and the limbs slam down
    # after it 0.5 m and more (the backs of the hands and the heels hitting, the legs splayed straight), the head hitting a
    # frame after the trunk and whipping up a frame after that; the bounce lifts the trunk flat and stiff off the deck while
    # the heels and the backs of the hands stay on it (the limbs trail), eased over its top; they leave the deck two frames
    # after the trunk's peak, slam back down first (f9-f10) and the trunk lands after them (f11); the right knee drawn up
    # into the lie only then (f11-f14), the head lolling back last. Pass 3 (the critic's notes: the whole figure went up
    # together, a levitation).  strike_s: the back on the deck; hold_s: the slam; back_s: falling back
    "knock_bounce": dict({"length": 18, "toes": "foot",
                          "meta": {"strike_s": 1 / FPS, "hold_s": 2 / FPS, "back_s": 8 / FPS, "hand": "both", "mask": "full",
                                   "root": "place", "legs_always": 1.0, "lying": 1.0}},
                         **_wclip(18, {
                             "pelvis": [(0, (0.0, 0.21, -0.3)), (1, LIE_PELVIS), (2, (0.0, 0.117, -0.3)), (3, (0.0, 0.16, -0.3)),
                                        (4, (0.0, 0.24, -0.3)), (5, (0.0, 0.31, -0.3)), (6, (0.0, 0.33, -0.3)), (7, (0.0, 0.31, -0.3)),
                                        (8, (0.0, 0.26, -0.3)), (9, (0.0, 0.21, -0.3)), (10, (0.0, 0.15, -0.3)), (11, LIE_PELVIS),
                                        (12, (0.0, 0.118, -0.3)), (14, LIE["pelvis"]), (18, LIE["pelvis"])],
                             "flip": [(0, -84), (1, -90), (4, -88), (6, -87), (8, -88), (11, -90), (18, -90)],
                             "hips": [(0, 10), (1, 0), (2, 2), (4, 4), (6, 5), (8, 4), (11, 1), (13, -1), (15, 0), (18, LIE["hips"])],
                             "chest": [(0, 6), (1, 2), (2, 4), (4, 4), (6, 4), (8, 4), (11, 0), (13, 3), (16, LIE["chest"]),
                                       (18, LIE["chest"])],
                             "head": [(0, 18), (1, 8), (2, -6), (3, 24), (4, 16), (6, 8), (9, 4), (11, -12), (13, -4),
                                      (16, LIE["head"]), (18, LIE["head"])],
                             "look": [(0, 0), (8, 6), (13, 16), (18, LIE["look"])], "side": [(0, 0), (18, LIE["side"])],
                             "twist": [(0, 0), (18, 0)],
                             "clav_r": [(0, (-6, -24)), (2, (4, 8)), (6, (4, 4)), (12, (0, 2)), (18, LIE["clav_r"])],
                             "clav_l": [(0, (-6, -24)), (2, (4, 8)), (6, (4, 4)), (12, (2, 3)), (18, LIE["clav_l"])],
                             "hand_r": [(0, (-0.36, 0.64, -0.55)), (1, (-0.5, 0.37, -0.59)), (2, (-0.6, 0.035, -0.6)),
                                        (4, (-0.55, 0.05, -0.58)), (6, (-0.53, 0.07, -0.57)), (7, (-0.56, 0.16, -0.58)),
                                        (8, (-0.6, 0.2, -0.6)), (9, (-0.6, 0.045, -0.6)), (10, (-0.63, 0.035, -0.6)),
                                        (18, LIE["hand_r"])],
                             "hand_l": [(0, (0.36, 0.64, -0.54)), (1, (0.5, 0.37, -0.57)), (2, (0.6, 0.035, -0.58)),
                                        (4, (0.55, 0.05, -0.56)), (6, (0.53, 0.07, -0.55)), (7, (0.56, 0.16, -0.56)),
                                        (8, (0.58, 0.2, -0.56)), (9, (0.6, 0.04, -0.56)), (10, (0.6, 0.035, -0.55)),
                                        (12, (0.4, 0.12, -0.45)), (15, LIE["hand_l"]), (18, LIE["hand_l"])],
                             "face_r": [(0, "flail"), (2, ("w", (-0.9, 0.0, -0.3), (0.0, 1.0, 0.0))),
                                        (6, ("w", (-0.9, 0.0, -0.3), (0.0, 1.0, 0.0))), (8, ("w", (-0.85, -0.2, -0.4), (0.0, 0.9, -0.3))),
                                        (10, ("w", (-0.9, 0.0, -0.3), (0.0, 1.0, 0.0))), (12, LIE["face_r"]), (18, LIE["face_r"])],
                             "face_l": [(0, "flail"), (2, ("w", (0.9, 0.0, -0.3), (0.0, 1.0, 0.0))),
                                        (6, ("w", (0.9, 0.0, -0.3), (0.0, 1.0, 0.0))), (8, ("w", (0.85, -0.2, -0.4), (0.0, 0.9, -0.3))),
                                        (10, ("w", (0.9, 0.0, -0.3), (0.0, 1.0, 0.0))), (13, LIE["face_l"]), (18, LIE["face_l"])],
                             "pole_r": [(0, (-0.6, 0.0, -0.8)), (2, (-1.0, 0.0, 0.5)), (6, (-1.0, 0.0, 0.3)), (12, LIE["pole_r"]), (18, LIE["pole_r"])],
                             "pole_l": [(0, (0.6, 0.0, -0.8)), (2, (1.0, 0.0, 0.5)), (6, (1.0, 0.0, 0.3)), (13, LIE["pole_l"]), (18, LIE["pole_l"])],
                             "grip_r": [(0, -0.3), (2, -0.4), (6, -0.2), (9, -0.4), (12, LIE["grip_r"]), (18, LIE["grip_r"])],
                             "grip_l": [(0, -0.3), (2, -0.4), (6, -0.2), (9, -0.4), (13, LIE["grip_l"]), (18, LIE["grip_l"])],
                             # (the legs splayed straight on the heels, trailing the trunk's lift, up a frame late and
                             # slammed back first; the right knee drawn up into the lie only after the trunk has landed)
                             "foot_r": [(0, (-0.17, 0.53, 0.38)), (1, (-0.2, 0.3, 0.46)), (2, (-0.22, 0.075, 0.495)),
                                        (4, (-0.22, 0.077, 0.478)), (6, (-0.22, 0.08, 0.462)), (7, (-0.22, 0.15, 0.455)),
                                        (8, (-0.22, 0.2, 0.45)), (9, (-0.22, 0.09, 0.47)), (10, (-0.22, 0.075, 0.485)), (11, (-0.22, 0.077, 0.42)),
                                        (13, (-0.23, 0.12, 0.2)), (14, LIE["foot_r"]), (18, LIE["foot_r"])],
                             "foot_l": [(0, (0.17, 0.52, 0.4)), (1, (0.2, 0.28, 0.47)), (2, (0.22, 0.068, 0.5)),
                                        (4, (0.22, 0.07, 0.48)), (6, (0.22, 0.075, 0.462)), (7, (0.22, 0.14, 0.455)),
                                        (8, (0.22, 0.19, 0.45)), (9, (0.22, 0.085, 0.47)), (10, (0.22, 0.068, 0.485)), (12, (0.21, 0.066, 0.44)),
                                        (14, LIE["foot_l"]), (18, LIE["foot_l"])],
                             "heel_r": [(0, 30), (2, 34), (10, 34), (12, 70), (14, 90), (18, 90)],
                             "heel_l": [(0, 30), (2, 28), (18, 25)],
                             "fyaw_r": [(0, 8), (2, 16), (10, 16), (18, LIE["fyaw_r"])], "fyaw_l": [(0, 14), (2, 22), (12, LIE["fyaw_l"]), (18, LIE["fyaw_l"])],
                             "knee_r": [(0, (-0.2, 0.0, 1.0)), (2, (-0.35, 0.0, 1.0)), (10, (-0.35, 0.0, 1.0)), (14, LIE["knee_r"]),
                                        (18, LIE["knee_r"])],
                             "knee_l": [(0, (0.2, 0.0, 1.0)), (2, (0.35, 0.0, 1.0)), (14, LIE["knee_l"]), (18, LIE["knee_l"])],
                         })),
})


def _getup():
    """own-bend-getup: from the lie, the carp skip-up (Northern Shaolin's kip): the knees drawn to the chest and the palms
    planted by the ears, rolled back onto the shoulders with the legs piked right over the face (the coil, the feet past the
    head), then the legs whipped over and down as the palms shove, the back arched with the hips at their highest (f6), sprung
    off the deck and landed on both feet in a crouch under where the hips were (f9); up through the stand a touch past and
    settled. Pass 2 (the critic's notes): the coil's feet beyond the head, and the arch its own key so the kip reads."""
    k = {
        # (pass 3: the shove grown over two frames (f5 an in-between: the pelvis 0.30 m, the flip -115); the landing ridden:
        # the crouch held f9-f11, the rise f11-f15 up onto the toes a touch past the stand with the arms swinging forward,
        # a 1.5 cm settle at f17 and the stand on the last frame)
        "pelvis": [(0, LIE["pelvis"]), (2, (0.0, 0.12, -0.34)), (3, (0.0, 0.16, -0.42)), (4, (0.0, 0.205, -0.48)), (5, (0.0, 0.34, -0.45)),
                   (6, (0.0, 0.5, -0.4)), (7, (0.0, 0.55, -0.3)), (8, (0.0, 0.57, -0.16)), (9, (0.0, 0.48, -0.06)),
                   (11, (0.0, 0.5, -0.02)), (13, (0.0, 0.72, 0.012)), (15, (0.0, 0.895, 0.021)), (17, (0.0, 0.866, 0.021)),
                   (19, (0.0, 0.879, 0.021)), (20, PELV_STAND)],
        "flip": [(0, -90), (2, -102), (4, -136), (5, -115), (6, -100), (7, -74), (8, -32), (9, -8), (11, 0), (20, 0)],
        "hips": [(0, LIE["hips"]), (2, 16), (4, 22), (5, 6), (6, -20), (7, -12), (8, 6), (9, 38), (11, 36), (13, 20), (15, -2),
                 (17, 1), (19, 0.3), (20, 0)],
        "chest": [(0, LIE["chest"]), (2, 22), (4, 26), (5, 8), (6, -14), (7, -10), (8, 4), (9, 16), (11, 16), (13, 8), (15, -3),
                  (17, 1), (19, 0.3), (20, 0)],
        "head": [(0, LIE["head"]), (2, 30), (4, 40), (5, 22), (6, 2), (7, -4), (8, -4), (9, -14), (11, -10), (13, -4), (15, 2),
                 (17, -1), (20, 0)],
        "look": [(0, LIE["look"]), (2, 6), (4, 0), (20, 0)], "side": [(0, LIE["side"]), (3, 0), (20, 0)], "twist": [(0, 0), (20, 0)],
        "tilt": [(0, LIE["tilt"]), (3, 0), (20, 0)],
        "clav_r": [(0, LIE["clav_r"]), (2, (-6, -20)), (5, (-6, -22)), (6, (-4, -18)), (7, (6, 0)), (9, (10, 6)), (13, (4, 2)),
                   (17, (0, 0)), (20, (0, 0))],
        "clav_l": [(0, LIE["clav_l"]), (2, (-6, -20)), (5, (-6, -22)), (6, (-4, -18)), (7, (6, 0)), (9, (10, 6)), (13, (4, 2)),
                   (17, (0, 0)), (20, (0, 0))],
        # (the palms planted by the ears and still shoving through the arch, off at f7)
        "hand_r": [(0, LIE["hand_r"]), (1, (-0.44, 0.14, -0.72)), (2, (-0.21, 0.035, -0.78)), (6, (-0.21, 0.035, -0.78)),
                   (7, (-0.27, 0.22, -0.6)), (8, (-0.32, 0.62, -0.05)), (9, (-0.32, 0.62, 0.3)), (11, (-0.3, 0.72, 0.32)),
                   (13, (-0.27, 0.8, 0.3)), (15, (-0.22, 0.92, 0.18)), (17, (-0.2, 0.84, 0.1)), (19, HR), (20, HR)],
        "hand_l": [(0, LIE["hand_l"]), (2, (0.21, 0.035, -0.78)), (6, (0.21, 0.035, -0.78)), (7, (0.27, 0.22, -0.6)),
                   (8, (0.32, 0.62, -0.05)), (9, (0.32, 0.62, 0.3)), (11, (0.3, 0.72, 0.32)), (13, (0.27, 0.8, 0.3)),
                   (15, (0.22, 0.92, 0.18)), (17, (0.2, 0.84, 0.1)), (19, HL), (20, HL)],
        "face_r": [(0, LIE["face_r"]), (2, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))), (6, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))),
                   (9, "balance"), (13, "balance"), (18, "stand"), (20, "stand")],
        "face_l": [(0, LIE["face_l"]), (2, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))), (6, ("w", (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))),
                   (9, "balance"), (13, "balance"), (18, "stand"), (20, "stand")],
        "pole_r": [(0, LIE["pole_r"]), (2, ("w", (-0.3, 1.0, 0.0))), (6, ("w", (-0.3, 1.0, 0.0))), (8, (-0.8, -0.4, -0.4)),
                   (13, (-0.6, -0.5, -0.6)), (20, STAND["pole_r"])],
        "pole_l": [(0, LIE["pole_l"]), (2, ("w", (0.3, 1.0, 0.0))), (6, ("w", (0.3, 1.0, 0.0))), (8, (0.8, -0.4, -0.4)),
                   (13, (0.6, -0.5, -0.6)), (20, STAND["pole_l"])],
        "grip_r": [(0, LIE["grip_r"]), (2, -0.2), (6, -0.2), (8, 0.1), (13, 0.2), (20, 0.4)],
        "grip_l": [(0, LIE["grip_l"]), (2, -0.2), (6, -0.2), (8, 0.1), (13, 0.2), (20, 0.4)],
        # (the coil: the feet piked over beyond the head; then whipped up past the vertical over the arched back and down
        # under him onto the deck)
        "foot_r": [(0, LIE["foot_r"]), (2, (-0.12, 0.42, -0.4)), (4, (-0.11, 0.42, -1.1)), (5, (-0.11, 0.52, -1.0)),
                   (6, (-0.13, 0.9, -0.3)), (7, (-0.13, 0.52, -0.12)), (8, (-0.13, 0.16, -0.05)), (9, (-0.13, 0.077, -0.04)),
                   (20, (-0.13, 0.077, -0.04))],
        "foot_l": [(0, LIE["foot_l"]), (2, (0.12, 0.42, -0.4)), (4, (0.11, 0.42, -1.1)), (5, (0.11, 0.52, -1.0)),
                   (6, (0.13, 0.9, -0.3)), (7, (0.13, 0.52, -0.12)), (8, (0.13, 0.16, -0.05)), (9, (0.13, 0.077, -0.04)),
                   (20, (0.13, 0.077, -0.04))],
        "heel_r": [(0, LIE["heel_r"]), (2, 40), (4, 50), (7, 40), (8, 24), (9, 8), (11, 0), (13, 0), (15, 6), (17, 0), (20, 0)],
        "heel_l": [(0, LIE["heel_l"]), (2, 40), (4, 50), (7, 40), (8, 24), (9, 8), (11, 0), (13, 0), (15, 6), (17, 0), (20, 0)],
        "fyaw_r": [(0, LIE["fyaw_r"]), (4, 6), (9, 10), (20, 7)], "fyaw_l": [(0, LIE["fyaw_l"]), (4, 6), (9, 10), (20, 7)],
        "knee_r": [(0, LIE["knee_r"]), (2, (-0.2, 0.3, 1.0)), (7, (-0.2, 0.2, 1.0)), (9, (-0.35, 0.0, 1.0)), (13, (-0.3, 0.0, 1.0)),
                   (17, "auto")],
        "knee_l": [(0, LIE["knee_l"]), (2, (0.2, 0.3, 1.0)), (7, (0.2, 0.2, 1.0)), (9, (0.35, 0.0, 1.0)), (13, (0.3, 0.0, 1.0)),
                   (17, "auto")],
    }
    return dict({"length": 20, "toes": "foot",
                 "meta": {"hold_s": 4 / FPS, "strike_s": 9 / FPS, "back_s": 11 / FPS, "hand": "both", "mask": "full", "root": "place",
                          "legs_always": 1.0}}, **_wclip(20, k))


## The getup roll's log roll: the turn about the long axis (to his right) and how far it lifts the pelvis on his side. Pass 2:
## two whole turns (the code carries him 2.5 m: a turn of the trunk's round covers about 1.25 m), fastest in the first.
## Pass 3 (the critic's notes: the roll stopped dead on the back and a separate sit-up popped him up): the last half turn
## eases out over f11-f16 instead of stopping, and the rock up to the feet starts while it is still turning (f13).
GROLL_BARREL = [(0, 0), (2, 0), (3, -40), (4, -105), (5, -180), (6, -250), (7, -315), (8, -375), (9, -430), (10, -485), (11, -540),
                (12, -600), (13, -652), (14, -690), (15, -712), (16, -720), (26, -720)]
GROLL_SIDE_LIFT = 0.21
## ... and face down (the head and the crossed arms in front of the chest).
GROLL_FRONT_LIFT = 0.17
## The roll's lead: the shoulders turn ahead of the hips each half turn and the hips catch up (twist, deg).
GROLL_TWIST = [(0, 0), (2, 0), (3, -15), (4, -12), (5, 4), (6, -14), (7, -10), (8, 5), (9, -14), (10, -10), (11, 4), (12, -12),
               (13, -8), (14, -2), (16, 0), (26, 0)]
## The roll's legs: the knees bent about 30 degrees (the ankle's place in the figure's frame), the left drawn up further
## behind for the push each time he comes face down.
GROLL_LEG = (0.08, 0.11, -0.08)
GROLL_PUSH = (0.09, 0.3, -0.16)


def _face_down(f):
    """How face down the log roll has him (0 on his back or side, 1 flat on his front)."""
    return max(0.0, -math.cos(math.radians(_kv(GROLL_BARREL, f)))) ** 2


def _getup_roll():
    """own-bend-getup-roll (to his right; its twin to the left): from the lie the arms tucked on the chest with the elbows
    wide and the knees bent, two whole log rolls along the deck (the code carries him 2.5 m), the head and the shoulders
    leading each half turn with a visible lift (GROLL_SIDE_LIFT) and the hips following (GROLL_TWIST), the palms opened out
    to brace on the deck and the left knee drawn up to push each time he comes face down. Pass 3: the roll's momentum
    carried into the rise: as the last half turn eases out on his back (f13-f16) he rocks back with the knees drawn to the
    chest and the arms flung up over the head, then rocks forward over the seat, the arms swinging forward to drive it
    (f16-f19), the feet planted under him in a crouch (f18-f21), and up through the stand onto the toes and settled."""
    base = [(0, LIE["pelvis"]), (2, LIE_PELVIS), (13, LIE_PELVIS), (14, (0.0, 0.13, -0.29)), (15, (0.0, 0.155, -0.3)),
            (16, (0.0, 0.15, -0.25)), (17, (0.0, 0.17, -0.17)), (18, (0.0, 0.25, -0.09)), (19, (0.0, 0.36, -0.04)),
            (20, (0.0, 0.45, -0.01)), (21, (0.0, 0.5, 0.005)), (23, (0.0, 0.74, 0.018)), (25, (0.0, 0.893, 0.021)), (26, PELV_STAND)]

    def pelvis(f):
        b = _kv(GROLL_BARREL, f)
        return _add(_kv(base, f), (0.0, GROLL_SIDE_LIFT * abs(math.sin(math.radians(b)))
                                     + GROLL_FRONT_LIFT * max(0.0, -math.cos(math.radians(b))), 0.0))
    # (in the roll the hands from tucked on the chest out to a brace before the shoulders as he comes face down, and the
    # left foot drawn up behind with the knee bent for the push; in the figure's own frame, carried with it)
    hands, feet = {"r": [], "l": []}, {"r": [], "l": []}
    for f in range(2, 14):
        w = _face_down(f)
        for s, sg in (("r", -1.0), ("l", 1.0)):
            chest = (-sg * 0.06, 1.18 if s == "r" else 1.14, 0.2 if s == "r" else 0.22)
            brace = (sg * 0.26, 1.06, 0.248)
            hands[s].append((f, ("b", _r3(_lerp(chest, brace, w)))))
            # (the knees bend from the first turn on: on his back at f2 a bent shin would put the heel through the deck)
            leg = (sg * GROLL_LEG[0], GROLL_LEG[1], GROLL_LEG[2]) if f > 2 else (sg * 0.07, 0.1, -0.02)
            bent = (sg * GROLL_PUSH[0], GROLL_PUSH[1], GROLL_PUSH[2]) if s == "l" else leg
            feet[s].append((f, ("b", _r3(_lerp(leg, bent, w)))))
    k = {
        "pelvis": pelvis, "barrel": GROLL_BARREL, "twist": GROLL_TWIST,
        # (pass 3: the rolling body kept on the deck by its own lowest surface (the shoulder, the hip, a braced elbow))
        "ground": [(0, 0.0), (2, 0.0), (3, 1.0), (13, 1.0), (15, 0.0), (26, 0.0)],
        "flip": [(0, -90), (13, -90), (14, -96), (15, -98), (16, -86), (17, -66), (18, -44), (19, -24), (20, -10), (21, -2), (22, 0),
                 (26, 0)],
        "hips": [(0, LIE["hips"]), (2, 6), (13, 6), (14, 20), (15, 30), (16, 36), (17, 40), (18, 44), (19, 46), (20, 42), (21, 36),
                 (23, 16), (25, -2), (26, 0)],
        "chest": [(0, LIE["chest"]), (2, 10), (13, 10), (14, 20), (15, 24), (16, 24), (18, 22), (20, 18), (21, 14), (23, 4), (25, -2),
                  (26, 0)],
        "head": [(0, LIE["head"]), (2, 6), (13, 8), (14, 22), (15, 26), (16, 18), (17, 6), (18, -6), (19, -12), (21, -10), (23, -3),
                 (25, 1), (26, 0)],
        "look": [(0, LIE["look"]), (2, -8), (3, -22), (12, -22), (14, -8), (16, 0), (26, 0)],
        "side": [(0, LIE["side"]), (2, 0), (26, 0)], "tilt": [(0, LIE["tilt"]), (2, 0), (26, 0)],
        "clav_r": [(0, LIE["clav_r"]), (2, (14, 8)), (13, (14, 8)), (15, (-6, -24)), (17, (8, -6)), (19, (10, 4)), (22, (2, 0)),
                   (26, (0, 0))],
        "clav_l": [(0, LIE["clav_l"]), (2, (14, 8)), (13, (14, 8)), (15, (-6, -24)), (17, (8, -6)), (19, (10, 4)), (22, (2, 0)),
                   (26, (0, 0))],
        # (rocked back: the arms flung up over the head (f15), then swung forward over the knees to drive the rock (f17-f19),
        # out ahead for the balance in the crouch, down to the stand; in the figure's own frame)
        "hand_r": [(0, LIE["hand_r"])] + hands["r"] + [(15, (-0.25, 0.06, -1.05)), (17, ("b", (-0.3, 1.38, 0.4))),
                                                        (19, ("b", (-0.3, 1.02, 0.5))), (21, ("b", (-0.3, 0.92, 0.44))),
                                                        (23, ("b", (-0.26, 0.86, 0.26))), (25, ("b", (-0.21, 0.84, 0.12))),
                                                        (26, ("b", HR))],
        "hand_l": [(0, LIE["hand_l"])] + hands["l"] + [(15, (0.25, 0.06, -1.05)), (17, ("b", (0.3, 1.38, 0.4))),
                                                        (19, ("b", (0.3, 1.02, 0.5))), (21, ("b", (0.3, 0.92, 0.44))),
                                                        (23, ("b", (0.26, 0.86, 0.26))), (25, ("b", (0.21, 0.84, 0.12))),
                                                        (26, ("b", HL))],
        "face_r": [(0, LIE["face_r"]), (2, "cross"), (4, "cross"), (5, "push"), (6, "cross"), (10, "cross"), (11, "push"),
                   (12, "cross"), (13, "cross"), (15, "sky"), (17, "push"), (19, "balance"), (23, "balance"), (25, "stand"), (26, "stand")],
        "face_l": [(0, LIE["face_l"]), (2, "cross"), (4, "cross"), (5, "push"), (6, "cross"), (10, "cross"), (11, "push"),
                   (12, "cross"), (13, "cross"), (15, "sky"), (17, "push"), (19, "balance"), (23, "balance"), (25, "stand"), (26, "stand")],
        # (the elbows wide in the roll)
        "pole_r": [(0, LIE["pole_r"]), (2, (-1.0, -0.2, 0.3)), (4, (-1.0, -0.2, 0.3)), (5, (-0.6, -0.8, -0.2)), (6, (-1.0, -0.2, 0.3)),
                   (10, (-1.0, -0.2, 0.3)), (11, (-0.6, -0.8, -0.2)), (12, (-1.0, -0.2, 0.3)), (13, (-1.0, -0.2, 0.3)),
                   (15, (-1.0, 0.2, 0.0)), (17, (-0.8, -0.5, -0.2)), (19, (-0.8, -0.4, -0.4)), (26, STAND["pole_r"])],
        "pole_l": [(0, LIE["pole_l"]), (2, (1.0, -0.2, 0.3)), (4, (1.0, -0.2, 0.3)), (5, (0.6, -0.8, -0.2)), (6, (1.0, -0.2, 0.3)),
                   (10, (1.0, -0.2, 0.3)), (11, (0.6, -0.8, -0.2)), (12, (1.0, -0.2, 0.3)), (13, (1.0, -0.2, 0.3)),
                   (15, (1.0, 0.2, 0.0)), (17, (0.8, -0.5, -0.2)), (19, (0.8, -0.4, -0.4)), (26, STAND["pole_l"])],
        "grip_r": [(0, LIE["grip_r"]), (2, 0.6), (4, 0.4), (5, -0.2), (6, 0.5), (10, 0.5), (11, -0.2), (12, 0.5), (13, 0.5),
                   (15, -0.3), (19, -0.1), (23, 0.2), (26, 0.4)],
        "grip_l": [(0, LIE["grip_l"]), (2, 0.6), (4, 0.4), (5, -0.2), (6, 0.5), (10, 0.5), (11, -0.2), (12, 0.5), (13, 0.5),
                   (15, -0.3), (19, -0.1), (23, 0.2), (26, 0.4)],
        # (rocked back the knees drawn to the chest (f14-f16, the figure's frame), then the feet planted under him on the
        # deck (f18) in a crouch and stood up on them)
        "foot_r": [(0, LIE["foot_r"])] + feet["r"] + [(15, ("b", (-0.1, 0.42, 0.16))), (16, ("b", (-0.11, 0.36, 0.14))),
                                                       (17, (-0.15, 0.13, -0.1)), (18, (-0.15, 0.077, -0.05)), (22, (-0.15, 0.077, -0.05)), (26, (-0.13, 0.077, -0.04))],
        "foot_l": [(0, LIE["foot_l"])] + feet["l"] + [(15, ("b", (0.1, 0.42, 0.16))), (16, ("b", (0.11, 0.36, 0.14))),
                                                       (17, (0.15, 0.13, -0.1)), (18, (0.15, 0.077, -0.05)), (22, (0.15, 0.077, -0.05)), (26, (0.13, 0.077, -0.04))],
        "heel_r": [(0, LIE["heel_r"]), (2, 40), (13, 40), (16, 46), (18, 34), (20, 14), (22, 0), (24, 0), (25, 5), (26, 0)],
        "heel_l": [(0, LIE["heel_l"]), (2, 40), (13, 40), (16, 46), (18, 34), (20, 14), (22, 0), (24, 0), (25, 5), (26, 0)],
        "fyaw_r": [(0, LIE["fyaw_r"]), (2, 4), (13, 4), (18, 10), (26, 7)], "fyaw_l": [(0, LIE["fyaw_l"]), (2, 4), (13, 4), (18, 10), (26, 7)],
        "knee_r": [(0, LIE["knee_r"]), (2, (-0.15, 0.0, 1.0)), (13, (-0.15, 0.0, 1.0)), (16, (-0.25, 0.0, 1.0)), (19, (-0.35, 0.0, 1.0)),
                   (23, "auto")],
        "knee_l": [(0, LIE["knee_l"]), (2, (0.15, 0.0, 1.0)), (13, (0.15, 0.0, 1.0)), (16, (0.25, 0.0, 1.0)), (19, (0.35, 0.0, 1.0)),
                   (23, "auto")],
    }
    return dict({"length": 26, "toes": "foot", "mirror": True, "twin_start": 2,
                 "meta": {"hold_s": 2 / FPS, "strike_s": 5 / FPS, "back_s": 15 / FPS, "hand": "both", "mask": "full", "root": "place",
                          "legs_always": 1.0, "travel": "right"}}, **_wclip(26, k))


## The getup attack's sweep (pass 3, the critic's notes: the bent leg under the coat did not read at 15 m): the right leg
## STRAIGHT, its ankle swung round the right hip itself at the shin's height (GA_FOOT_Y), GA_SLACK short of the leg's
## full reach (a knee a few degrees off straight), the angle (deg, 0 to his left, 90 straight ahead, 180 to his right) at
## each frame: wound up behind to his right (200), swept round the front 220 degrees and held two frames out behind to his
## left (-20). The hip's place each frame is the rig's own: _hip_at turns its rest place by the clip's typed turn exactly
## as pose() does (typed numbers in, typed numbers out).
GA_ARC = [(4, 200), (5, 182), (6, 145), (7, 92), (8, 36), (9, -20), (10, -20)]
GA_FOOT_Y = 0.1
GA_SLACK = 0.0012
LEG_R = ((P_REST["r_knee"] - P_REST["r_upper_leg"]).length + (P_REST["r_ankle"] - P_REST["r_knee"]).length)


def _hip_at(side, pelvis, flip, yaw, hips, roll=0.0):
    """The hip joint's place (the deck's frame) for a _wclip figure at its pelvis' place with that turn and bow: the root
    turned as pose() turns it, the hip carried rigidly with it from the rest."""
    Q = q_axis(_X3, flip)
    R = Q @ q_axis(_Y3, yaw) @ q_axis(_X3, hips) @ q_axis(_Z3, roll)
    root = Vector(pelvis) + Q @ (ROOT_REST - Vector(PELV_REST))
    return root + R @ (P_REST[side + "_upper_leg"] - ROOT_REST)


def _ga_foot(f, k):
    """The sweeping ankle's place at frame f: GA_ARC's angle about the right hip, the leg GA_SLACK short of straight."""
    hip = _hip_at("r", _kv(k["pelvis"], f), _kv(k["flip"], f), _kv(k["yaw"], f), _kv(k["hips"], f))
    dy = hip.y - GA_FOOT_Y
    r = math.sqrt(max(0.0, (LEG_R - GA_SLACK) ** 2 - dy * dy))
    a = math.radians(_kv(GA_ARC, f))
    return (round(hip.x + r * math.cos(a), 4), GA_FOOT_Y, round(hip.z + r * math.sin(a), 4))


def _getup_attack():
    """own-bend-getup-attack: from the lie, sat up and turned onto the left hand and the left foot with the hips lifted
    high off the deck (a crab, the pelvis 0.45 m up and shifted 7 cm over the planted hand and foot: the base the sweep
    swings from), the straight right leg wound up out behind to the right with the body turned after it (yaw -45) and the
    right arm flung out wide, then the leg swept round low at the shin's height across the front and out behind to the
    left (220 degrees, the strike straight ahead), the body turning with it to +45 and the right arm whipping across low with
    it and on past the body, the trunk twisted against it and overshooting after (f11); the leg held out two frames with
    the toes pointed, drawn in under him and planted, up off both feet to the stand."""
    k = {
        "pelvis": [(0, LIE["pelvis"]), (1, (0.01, 0.17, -0.3)), (2, (0.03, 0.28, -0.3)), (4, (0.08, 0.44, -0.27)),
                   (7, (0.07, 0.46, -0.26)), (10, (0.06, 0.45, -0.24)), (11, (0.04, 0.44, -0.2)), (12, (0.02, 0.48, -0.12)),
                   (13, (0.0, 0.52, -0.06)), (16, (0.0, 0.82, 0.015)), (18, (0.0, 0.886, 0.021)), (20, PELV_STAND)],
        "flip": [(0, -90), (2, -80), (4, -82), (7, -81), (10, -80), (11, -62), (12, -18), (13, -5), (14, 0), (20, 0)],
        "yaw": [(0, 0), (2, 10), (4, -40), (5, -45), (6, -28), (7, 2), (8, 28), (9, 44), (10, 45), (11, 32), (13, 10), (16, 1), (20, 0)],
        "hips": [(0, LIE["hips"]), (2, 4), (4, 2), (7, 2), (10, 4), (12, 30), (13, 40), (16, 12), (18, -1), (20, 0)],
        "chest": [(0, LIE["chest"]), (2, 4), (4, 0), (7, 0), (10, 2), (12, 18), (13, 16), (16, 4), (18, -2), (20, 0)],
        "side": [(0, LIE["side"]), (2, 10), (4, 14), (7, 12), (10, 6), (13, 0), (20, 0)],
        "head": [(0, LIE["head"]), (2, 20), (4, 26), (7, 24), (10, 22), (12, -10), (14, -10), (17, -1), (20, 0)],
        "look": [(0, LIE["look"]), (2, 10), (4, -24), (6, -14), (7, 4), (9, 20), (11, 14), (14, 0), (20, 0)],
        "tilt": [(0, LIE["tilt"]), (2, 0), (20, 0)],
        # (the trunk wound against the sweep, then overshooting the sweep's way after the leg stops (f11), settled by f15)
        "twist": [(0, 0), (2, 8), (4, 22), (6, 10), (7, -6), (9, -16), (10, -18), (11, -24), (13, -10), (15, 0), (20, 0)],
        "clav_r": [(0, LIE["clav_r"]), (4, (-8, -16)), (7, (6, -4)), (10, (10, 2)), (14, (4, 2)), (20, (0, 0))],
        "clav_l": [(0, LIE["clav_l"]), (2, (-4, 6)), (10, (-4, 6)), (14, (2, 2)), (20, (0, 0))],
        # (the right arm flung out wide to his right for the wind-up, whipping across low with the sweep and on past the
        # body to his left, then swung back through to the stand)
        "hand_r": [(0, LIE["hand_r"]), (2, (-0.42, 0.36, -0.5)), (4, (-0.56, 0.4, -0.5)), (5, (-0.5, 0.4, -0.4)),
                   (6, (-0.39, 0.4, -0.27)), (7, (-0.13, 0.4, -0.19)), (8, (0.12, 0.43, -0.26)), (9, (0.25, 0.46, -0.36)),
                   (10, (0.27, 0.47, -0.38)), (11, (0.25, 0.54, -0.26)), (13, (0.02, 0.64, 0.2)), (16, (-0.24, 0.82, 0.18)), (20, HR)],
        "hand_l": [(0, LIE["hand_l"]), (2, (0.22, 0.035, -0.66)), (10, (0.22, 0.035, -0.66)), (11, (0.26, 0.22, -0.54)),
                   (12, (0.29, 0.47, -0.24)), (13, (0.3, 0.55, 0.05)), (14, (0.3, 0.62, 0.22)), (16, (0.24, 0.82, 0.18)), (20, HL)],
        "face_r": [(0, LIE["face_r"]), (2, "balance"), (12, "balance"), (17, "stand"), (20, "stand")],
        "face_l": [(0, LIE["face_l"]), (2, ("w", (0.45, 0.0, 0.89), (0.0, -1.0, 0.0))), (10, ("w", (0.45, 0.0, 0.89), (0.0, -1.0, 0.0))),
                   (13, "balance"), (17, "stand"), (20, "stand")],
        "pole_r": [(0, LIE["pole_r"]), (2, (-1.0, -0.4, -0.3)), (12, (-0.8, -0.5, -0.3)), (20, STAND["pole_r"])],
        "pole_l": [(0, LIE["pole_l"]), (2, ("w", (0.6, 0.4, 0.6))), (11, ("w", (0.6, 0.4, 0.6))), (13, (0.8, -0.4, -0.4)),
                   (20, STAND["pole_l"])],
        "grip_r": [(0, LIE["grip_r"]), (3, 0.3), (12, 0.3), (20, 0.4)],
        "grip_l": [(0, LIE["grip_l"]), (2, -0.3), (11, -0.3), (14, 0.2), (20, 0.4)],
        "foot_l": [(0, LIE["foot_l"]), (2, (0.26, 0.077, 0.02)), (12, (0.26, 0.077, 0.02)), (14, (0.14, 0.077, -0.04)),
                   (20, (0.13, 0.077, -0.04))],
        # (the right toes pointed through the sweep)
        "heel_r": [(0, LIE["heel_r"]), (2, 80), (3, 76), (11, 76), (12, 30), (13, 0), (16, 0), (17, 5), (19, 0), (20, 0)],
        # (the left sole flat on the deck under the turned figure: its lift the figure's tilt back)
        "heel_l": [(0, LIE["heel_l"]), (2, 80), (4, 82), (7, 81), (10, 80), (11, 62), (12, 18), (13, 5), (14, 0), (16, 0), (17, 5),
                   (19, 0), (20, 0)],
        "fyaw_r": [(0, LIE["fyaw_r"]), (3, 0), (11, 0), (13, 7), (20, 7)], "fyaw_l": [(0, LIE["fyaw_l"]), (2, 20), (12, 20), (14, 7), (20, 7)],
        "knee_r": [(0, LIE["knee_r"]), (2, ("w", (0.0, 1.0, 0.2))), (11, ("w", (0.0, 1.0, 0.2))), (13, (-0.3, 0.0, 1.0)), (17, "auto")],
        "knee_l": [(0, LIE["knee_l"]), (2, ("w", (0.4, 1.0, 0.2))), (12, ("w", (0.4, 1.0, 0.2))), (14, (0.3, 0.0, 1.0)), (17, "auto")],
    }
    k["foot_r"] = ([(0, LIE["foot_r"]), (2, (-0.42, 0.09, -0.2))] + [(fr, _ga_foot(fr, k)) for fr in range(GA_ARC[0][0], GA_ARC[-1][0] + 1)]
                   + [(11, (0.16, 0.2, -0.12)), (12, (-0.1, 0.12, 0.0)), (13, (-0.14, 0.077, -0.03)), (20, (-0.13, 0.077, -0.04))])
    return dict({"length": 20, "toes": "foot",
                 "meta": {"hold_s": 4 / FPS, "strike_s": 7 / FPS, "back_s": 10 / FPS, "hand": "foot_r", "mask": "full",
                          "root": "place", "legs_always": 1.0}}, **_wclip(20, k))


SET6.update({
    # the getup (W or Space from the lie; intangible 0.3 s by the code): the carp skip-up.  hold_s: coiled on the
    # shoulders; strike_s: the feet land; back_s: rising
    "getup": _getup(),
    # the getup roll (E and a way from the lie: 2.5 m by the code; to his right, its twin to the left): a log roll.
    # hold_s: gathered; strike_s: face down in the roll; back_s: sat up
    "getup_roll": _getup_roll(),
    # the getup attack (a click from the lie: a low sweep while rising, 5%).  hold_s: the leg out to the right; strike_s:
    # the sweep straight ahead; back_s: the leg drawn in
    "getup_attack": _getup_attack(),
})
CLIPS.update(SET6)


## ---------------------------------------------------------------- the seventh set (round 3, P2: the Pop's rising hand, the
## four Slams, the four held guards and the teeter; authored the same way, key poses typed here, nothing read). The Slams are
## casts let go in the air (spec 6.2): they start and end on AIR, the fall's first pose, so they hand over to the fall loop;
## each holds its wind-up at hold_s while the lock fills (0.3-0.35 s) and strikes three frames after the release (strike_s
## 0.2 s), so the big wind-up is what the foe reads and the hit comes at once. The guard holds are loops of round 2's four
## guard poses held (the catch's, the Turn's, the Parry's and the Wind Guard's) with each element's own life in them. The
## teeter is a one-shot the code holds at its end while he leans at the lip. Earth Hung Gar (the horse, the double hammer
## fist), water tai chi (the gathered arms pressing down, the ward-off), fire Northern Shaolin (the axe kick, the knife hand)
## and air Baguazhang (the coiled palms, the turning wheel) are style labels for the typed key poses only.
FACING.update({
    "hammer_up": ((0.0, 0.9, -0.42), (1.0, 0.0, 0.0)),        # a fist cocked up overhead, the forearm up and back, the palm in
    "rain_up": ((-0.5, 0.85, 0.12), (0.85, 0.45, 0.0)),       # an arm raised up and out in a V, the palm up and in (gathering)
    "coil_down": ((0.55, 0.0, 0.83), (0.0, -1.0, 0.0)),       # a palm drawn up by the shoulder, the fingers in and ahead, palm down
    "stone_hold": ((0.05, 0.97, -0.15), (0.12, 0.35, 0.93)),  # behind and under a stone held out ahead, the palm on it, the fingers cupped up over its crown
    "press_out": ((-0.85, -0.08, 0.5), (0.0, -1.0, 0.0)),      # pressed down out to the side, the palm down, the fingers pointing out
})


## The Pop's stone, where the code holds it (BendR3.pop_stone: 0.55 m ahead, 0.45 m to the right, 1.25 m up; radius 0.22 m),
## in the clip's frame (+X the character's left): the rising hand ends behind and under it, the palm on its surface.
POP_STONE = (-0.45, 1.25, 0.55)
POP_STONE_R = 0.22
POP_PALM = (-0.45, 1.17, 0.345)


def _ease_out(t):
    t = max(0.0, min(1.0, t))
    return 1.0 - (1.0 - t) * (1.0 - t)


def _each(length, fn, keys):
    """A one-shot's channels keyed at every frame from fn(frame) (frames 0..length); a facing (a name or (fingers, palm)) kept."""
    def kept(v):
        return isinstance(v, str) or (isinstance(v, tuple) and len(v) == 2 and isinstance(v[0], tuple))
    out = {ch: [] for ch in keys}
    for f in range(length + 1):
        d = fn(f)
        for ch in keys:
            out[ch].append((f, d[ch] if kept(d[ch]) else _rv(d[ch])))
    return out


## The teeter (own-bend-teeter, 15 frames, held at its end by the code while he leans at the lip): the whole body tipped out
## from the ankles over the balls of the feet (eased in over three frames), then both long arms windmilling backward from
## the shoulders (forward, up, over and down behind) to win the balance back, the right leading and the left a beat behind,
## spun up and eased out at different frames; caught leaning out with the right arm up and back and the left out ahead, the
## chest lifted, one heel up, the head looking down at the water. (Pass 2: the lurch from the ankles, not folded at the
## hips; the circles about the shoulders themselves with long arms, spun up and down so no frame steps more than 55 degrees.)
TEETER_LEN = 15
## (Pass 3: the arms start after the lurch, the right at f2 and the left at f3, and both settle into the held end up and out
## in a wide flailing V (the right at 110 degrees, just past straight up, the left at 100); the whole body tipped further out
## from the ankles (the hips 0.15 m and more past the start), up on both toes; the wobble in overlapping waves: the hips a
## frame behind the root, the chest two, the head one behind the chest.)
TEETER_TURN = (575.0, 560.0)      # each arm's windmill (deg: right, left), from hanging (-90: down) to its caught place
TEETER_SPAN = ((2, 15), (3, 15))  # the frames each arm turns over (after the lurch; the left a beat behind)
TEETER_RAMPS = ((3, 3), (2, 2))   # frames each arm takes to spin up and to settle (the left, later, whipped up faster)
TEETER_R = 0.44                   # the windmill's radius (m): the arm long from the shoulder
TEETER_OUT = (0.06, 0.03, 0.0)    # its centre from the shoulder (m: out to the side, up, ahead), so the arms pass beside the hips
TEETER_FLARE = 38.0               # the circle's upper half tilted out to the side (deg): the arms a wide V over the hat
TEETER_KEYS = {
    "root": [(0, (0.0, -0.015, 0.0)), (1, (0.0, -0.014, 0.014)), (2, (0.0, -0.012, 0.055)), (3, (0.0, -0.01, 0.11)),
             (5, (0.0, -0.008, 0.138)), (7, (0.0, -0.006, 0.165)), (10, (0.0, -0.006, 0.148)), (13, (0.0, -0.005, 0.158)),
             (15, (0.0, -0.005, 0.155))],
    "hips": [(0, 0), (1, 0.4), (2, 2), (3, 4.5), (4, 6.5), (6, 8), (8, 10), (11, 8), (14, 10), (15, 9.8)],
    "chest": [(0, 0), (1, 0.6), (2, 2.5), (3, 6), (4, 10), (5, 13), (7, 10.5), (9, 15), (12, 12), (15, 14)],

}


def _teeter_shoulder(f, side):
    """The shoulder's place (approximately: the pelvis carried by the root, the spine turned by the hips' and the chest's pitch)."""
    r = _kv(TEETER_KEYS["root"], f)
    pitch = math.radians(_kv(TEETER_KEYS["hips"], f) + _kv(TEETER_KEYS["chest"], f) * 0.85)
    sx = -0.13 if side == "r" else 0.13
    v = (0.37 * math.cos(pitch) + 0.05 * math.sin(pitch), -0.05 * math.cos(pitch) + 0.37 * math.sin(pitch))
    return (sx, PELV_REST[1] + r[1] + v[0], PELV_REST[2] + r[2] + v[1])


def _trap(f, f0, f1, ramp, settle=None):
    """0 to 1 over frames f0..f1: the speed eased up over `ramp` frames, held, and eased down over `settle` (default `ramp`: a
    spin's start and its settle; the peak speed the whole over (f1 - f0 - (ramp + settle) / 2))."""
    if settle is None:
        settle = ramp

    def v(t):
        if t <= f0 or t >= f1:
            return 0.0
        if t < f0 + ramp:
            return 0.5 - 0.5 * math.cos(math.pi * (t - f0) / ramp)
        if t > f1 - settle:
            return 0.5 - 0.5 * math.cos(math.pi * (f1 - t) / settle)
        return 1.0

    def area(upto):
        n = 600
        h = (upto - f0) / n
        return sum(v(f0 + (i + 0.5) * h) for i in range(n)) * h
    if f <= f0:
        return 0.0
    if f >= f1:
        return 1.0
    return area(f) / area(f1)


def teeter_at(f):
    out = {}
    for s, sg, i in (("r", -1.0, 0), ("l", 1.0, 1)):
        S = _teeter_shoulder(f, s)
        f0, f1 = TEETER_SPAN[i]
        ph = math.radians(-90.0 + TEETER_TURN[i] * _trap(f, f0, f1, *TEETER_RAMPS[i]))
        c = (S[0] + sg * TEETER_OUT[0], S[1] + TEETER_OUT[1], S[2] + TEETER_OUT[2])
        up = math.sin(ph)
        fl = math.radians(TEETER_FLARE) if up > 0.0 else 0.0
        wind = (c[0] + sg * TEETER_R * up * math.sin(fl), c[1] + TEETER_R * up * math.cos(fl), c[2] + TEETER_R * math.cos(ph))
        # (the first two frames ease off the stand's hanging palm onto the circle)
        w = min(1.0, f / 2.0)
        w = w * w * (3.0 - 2.0 * w)
        st = STAND["hand_" + s]
        hand = tuple(st[k] + (wind[k] - st[k]) * w for k in range(3))
        out["hand_" + s] = hand
        if f == 0:
            out["face_" + s] = "stand"
            continue
        fing = Vector(hand) - Vector(S)
        fing.normalize()
        out["face_" + s] = (_r3(tuple(fing)), (-sg * 1.0, 0.0, 0.0))
    return out


## The guard holds (loops while E keeps the guard up; spec 4.4: the tell is the guard's own pose): each the held pose of its
## round-2 guard clip (the frames between its strike and its back_s), alive: earth breathing heavy in its low catch (the
## rock between the palms, the right on top), water rocking its ward-off forward and back with the palms tracing slow
## circles, fire bouncing on the balls of its feet behind a knife hand stood up before the face, air turning a wheel before
## the chest (one palm high, one low, changing over). (Pass 2: earth's horse wide and low with a breath and a squeeze that
## read at 15 m and a slow weight shift; fire's bounce twice as deep, snapped off the balls of the feet (a sharp bottom, a
## soft top) and driven by the knees, the hands settling a beat after it.)
def guard_earth_at(a):
    b = 0.5 - 0.5 * _c(a)                 # the breath (0 in, 1 out: the body sinks)
    bl = 0.5 - 0.5 * _c(a, -0.7)          # the chest's a few frames after the root
    bh = 0.5 - 0.5 * _c(a, -1.3)          # the hands' squeeze after the chest
    return {
        "root": (0.016 * _s(a), -0.24 - 0.035 * b, -0.035 - 0.012 * b),
        "hips": -1.0 + 4.0 * b, "chest": -3.0 + 6.0 * bl, "head": 2.0 - 4.0 * bl, "side": 3.0 * _s(a, -0.5),

        "clav_r": (4.0, -3.0 + 6.0 * bl), "clav_l": (4.0, -3.0 + 6.0 * bl),
        "hand_r": (-0.06 + 0.008 * _s(a, -0.6), 1.175 - 0.05 * bh, 0.32 + 0.015 * bh),
        "hand_l": (0.05 + 0.008 * _s(a, -0.6), 0.845 - 0.018 * bh, 0.32 + 0.012 * bh),
        "grip_r": 0.05 + 0.15 * bh, "grip_l": 0.05 + 0.15 * bh,
    }


def guard_water_at(a):
    fw = _s(a)                            # the weight forward (+) and back (-)
    return {
        "root": (0.006 * _s(a, 0.8), -0.132 - 0.008 * (0.5 - 0.5 * _c(2 * a)), 0.135 + 0.032 * fw),
        "yaw": 2.0 * _s(a, -0.4) - 1.0, "twist": -3.0 + 3.0 * _s(a, -0.9),
        "hips": 8.0 + 1.6 * fw, "chest": 10.5 + 2.2 * _s(a, -0.6), "head": -2.0 - 1.2 * _s(a, -1.1),
        "side": 1.5 * _s(a, -1.4),
        "clav_r": (13.0 + 2.0 * _s(a, -0.5), -5.0), "clav_l": (13.0 + 2.0 * _s(a, -0.9), -5.0),
        # (the palms trace a slow circle each: out and down as the weight goes forward, up and in as it comes back; the
        # left a beat after the right)
        "hand_r": (-0.2, 1.13 + 0.045 * _c(a, -0.7), 0.6 + 0.05 * _s(a, -0.7)),
        "hand_l": (0.2, 1.12 + 0.045 * _c(a, -1.3), 0.6 + 0.05 * _s(a, -1.3)),
        "heel_r": 7.0 + 6.0 * max(0.0, fw), "grip_r": -0.3 + 0.08 * _s(a, -1.0), "grip_l": -0.3 + 0.08 * _s(a, -1.5),
    }


def guard_fire_at(a):
    up = abs(_s(a))                        # two bounces a loop (1 up on the balls, 0 down): sharp at the bottom, soft at the top
    upl = 0.5 - 0.5 * _c(2 * a, -0.9)      # the arms settling a beat after the body (smooth)
    return {
        "root": (0.0, -0.152 + 0.045 * up, 0.12 + 0.006 * _s(a)),
        "yaw": 18.0 + 2.0 * _s(a), "twist": 12.0 + 2.0 * _s(a, -0.6),
        "hips": 7.5 - 2.0 * up, "chest": 8.0 + 3.0 * upl, "side": -2.0, "head": -3.0 + 1.5 * upl,
        "clav_r": (16.0, -4.0 - 3.0 * upl), "clav_l": (-5.0, 2.0),
        # (the knife hand stood up ahead of the face draws a small circle, the edge of the hand leading; the rear fist pumps
        # at the ribs with the bounce)
        "hand_r": (-0.04 + 0.02 * _s(a), 1.3 + 0.025 * _c(a) - 0.03 * upl, 0.66 + 0.01 * _s(a, 0.7)),
        "hand_l": (0.19, 1.045 - 0.03 * upl, 0.03 + 0.012 * upl),
        "heel_r": 10.0 + 20.0 * up, "heel_l": 2.0 + 14.0 * up,
    }


def guard_air_at(a):
    b2 = _s(2 * a)
    return {
        "root": (0.01 * _s(a, 0.4), -0.1 + 0.01 * b2, 0.1),
        "yaw": 3.0 + 3.0 * _s(a, -0.5), "twist": 9.0 * _s(a, -0.3), "side": -3.0 * _c(a, -0.4),
        "hips": 5.0, "chest": 8.0 + 1.0 * _s(2 * a, -0.6), "head": -2.0 + 1.5 * _s(a, -1.0),
        "clav_r": (12.0, -2.0 - 6.0 * max(0.0, _c(a))), "clav_l": (12.0, -2.0 - 6.0 * max(0.0, -_c(a))),
        # (the wheel: the palms orbit each other before the chest, the right high and the left low at the seam, changing over
        # at the half; the palms out ahead, turned to the foe)
        "hand_r": (-0.17 - 0.08 * _s(a), 1.24 + 0.2 * _c(a), 0.55 + 0.06 * _s(a)),
        "hand_l": (0.17 - 0.08 * _s(a), 1.24 - 0.2 * _c(a), 0.55 - 0.06 * _s(a)),

        "heel_r": 12.0 + 4.0 * b2, "heel_l": 6.0 + 3.0 * _s(2 * a, 1.0),
    }


def _const(length, **ch):
    return {k: [(0, v), (length, v)] for k, v in ch.items()}


def _guard(length, fn, **const):
    c = {"length": length, "loop": True, "meta": {"hand": "both", "mask": "full", "root": "place"}}
    c.update(_loop(length, fn))
    c.update(_const(length, **const))
    return c


FACING.update({
    "fist_back": ((0.0, -0.55, -0.83), (1.0, 0.0, 0.0)),     # a fist flung back and down behind the hip, the palm in
})


SET7 = {
    # the Pop's rising hand (one for every element; the effect carries the element): coiled down on the right, the fist
    # chambered behind the hip with the trunk wound hard to the right and the left fist guarding the chin (held); unwound
    # through the hips and the chest into a rising punch driven straight up over the head, the spine and the arm one C
    # (bent away from the fist, the right shoulder shrugged up behind it, up on the right toes), the left fist dropping to
    # the chamber a frame later with a dip; the hand opening over the top and brought down and out ahead to the right,
    # where it closes round the stone earth's Pop keeps (BendR3.pop_stone), the left fist back up in guard; held there to the
    # end so the held-stone pose follows.  hold_s: coiled; strike_s: the fist at the top; back_s: the hand at the stone.
    # Its twin (twin_tail) rises on the left hand and ends on this same held-stone pose, the right hand on the stone where
    # the code holds it (meta stone_hand: the hand on the stone, r for both).
    "jab_rise": {
        "length": 24, "mirror": True, "twin_tail": 12,
        # (pass 3: the twin's rising left fist stays a fist and drops straight back to the guard; its right hand leaves the
        # chamber for the stone from f8, so it reads as one hand rising and the other taking the stone, not a missed grab)
        "twin_keys": {"fyaw_l": [(0, 7), (5, 16), (13, 7), (24, 7)], "fyaw_r": [(0, 7), (13, 12), (24, 12)],
                      "grip_l": [(0, 0.4), (2, 1.0), (24, 1.0)],
                      "hand_l": [(0, HL), (2, (0.28, 0.8, -0.05)), (3, (0.23, 0.99, 0.2)), (4, (0.16, 1.37, 0.31)),
                                 (5, (0.12, 1.75, 0.2)), (7, (0.11, 1.77, 0.17)), (8, (0.13, 1.62, 0.2)), (10, (0.15, 1.4, 0.25)),
                                 (13, (0.13, 1.18, 0.26)), (16, (0.12, 1.24, 0.28)), (24, (0.12, 1.24, 0.28))],
                      "face_l": [(0, "stand"), (2, "fist_low"), (3, "fist_low"), (5, "fist_up"), (8, "fist_up"), (13, "fist_guard"),
                                 (24, "fist_guard")],
                      "hand_r": [(0, HR), (2, (-0.14, 1.25, 0.3)), (4, (-0.16, 1.18, 0.2)), (6, (-0.2, 1.0, 0.02)),
                                 (7, (-0.2, 0.96, 0.02)), (9, (-0.26, 1.07, 0.18)), (11, (-0.4, 1.22, 0.33)), (13, POP_PALM),

                                 (15, (POP_PALM[0], POP_PALM[1] - 0.025, POP_PALM[2])),
                                 (17, (POP_PALM[0], POP_PALM[1] - 0.008, POP_PALM[2])), (24, POP_PALM)],
                      "face_r": [(0, "stand"), (2, "fist_guard"), (5, "chamber"), (8, "chamber"), (11, "stone_hold"),
                                 (13, "stone_hold"), (24, "stone_hold")],
                      "grip_r": [(0, 0.4), (2, 1.0), (8, 1.0), (11, -0.25), (12, -0.3), (14, 0.35), (17, 0.6), (24, 0.62)],
                      "heel_l": [(0, 0), (2, 0), (5, 20), (8, 18), (12, 4), (15, 0), (24, 0)],
                      "heel_r": [(0, 0), (4, 0), (5, 6), (8, 5), (11, 0), (24, 0)]},
        "meta": {"hold_s": 2 / FPS, "strike_s": 5 / FPS, "back_s": 13 / FPS, "hand": "r", "mask": "upper", "root": "place",
                 "stone_hand": "r", "twin_tail_s": 12 / FPS, "stone_s": 13 / FPS},

        "root": [(0, (0, -0.015, 0)), (2, (0.0, -0.07, 0.0)), (5, (0.0, -0.025, 0.045)), (7, (0.0, -0.02, 0.045)),
                 (13, (0.0, -0.045, 0.03)), (16, (0.0, -0.056, 0.03)), (20, (0.0, -0.048, 0.03)), (24, (0.0, -0.052, 0.03))],
        "hips": [(0, 0), (2, 8), (5, -5), (7, -4), (13, 4), (16, 5.5), (20, 4.5), (24, 5)],
        "chest": [(0, 0), (2, 16), (4, 2), (5, -9), (7, -8), (10, -2), (13, 6), (16, 9), (20, 7.5), (24, 8)],
        "side": [(0, 0), (2, 6), (5, -14), (7, -13), (10, -7), (13, -2), (24, -2)],
        "twist": [(0, 0), (2, -28), (4, 4), (5, 16), (7, 19), (13, 16), (17, 14), (24, 14)],
        "head": [(0, 0), (2, 10), (5, -12), (7, -14), (10, -6), (13, 4), (16, 6), (24, 6)],
        "clav_r": [(0, (0, 0)), (2, (-8, 6)), (5, (14, -26)), (7, (14, -28)), (10, (12, -14)), (13, (14, -4)), (24, (14, -4))],
        "clav_l": [(0, (0, 0)), (2, (4, -4)), (6, (-6, 4)), (13, (2, -2)), (24, (4, -4))],
        "hand_r": [(0, HR), (2, (-0.28, 0.8, -0.05)), (3, (-0.23, 0.99, 0.2)), (4, (-0.16, 1.37, 0.31)), (5, (-0.12, 1.75, 0.2)),
                   (7, (-0.11, 1.77, 0.17)), (9, (-0.2, 1.62, 0.28)), (11, (-0.37, 1.36, 0.36)), (13, POP_PALM),
                   (15, (POP_PALM[0], POP_PALM[1] - 0.025, POP_PALM[2])), (17, (POP_PALM[0], POP_PALM[1] - 0.008, POP_PALM[2])),
                   (24, POP_PALM)],
        "hand_l": [(0, HL), (2, (0.14, 1.25, 0.3)), (4, (0.16, 1.18, 0.2)), (6, (0.2, 1.0, 0.02)), (7, (0.2, 0.96, 0.02)),
                   (9, (0.2, 1.0, 0.03)), (13, (0.13, 1.18, 0.26)), (16, (0.12, 1.24, 0.28)), (24, (0.12, 1.24, 0.28))],
        "face_r": [(0, "stand"), (2, "fist_low"), (3, "fist_low"), (5, "fist_up"), (8, "fist_up"), (13, "stone_hold"),
                   (24, "stone_hold")],
        "face_l": [(0, "stand"), (2, "fist_guard"), (5, "chamber"), (9, "chamber"), (13, "fist_guard"), (24, "fist_guard")],
        "pole_r": [(0, (-0.35, -0.1, -1.0)), (2, (-0.5, -0.6, -0.6)), (5, (-1.0, -0.2, 0.0)), (8, (-1.0, -0.2, 0.0)),
                   (13, (-0.9, -0.6, -0.2)), (24, (-0.9, -0.6, -0.2))],
        "pole_l": [(0, (0.35, -0.1, -1.0)), (2, (0.6, -0.6, -0.3)), (6, (0.4, -0.5, -1.0)), (13, (0.7, -0.7, -0.2)),
                   (24, (0.7, -0.7, -0.2))],
        "grip_r": [(0, 0.4), (2, 1.0), (8, 1.0), (10, 0.0), (12, -0.3), (14, 0.35), (17, 0.6), (24, 0.62)],
        "grip_l": [(0, 0.4), (2, 1.0), (24, 1.0)],
        "heel_r": [(0, 0), (2, 0), (5, 20), (8, 18), (12, 4), (15, 0), (24, 0)],
        "heel_l": [(0, 0), (4, 0), (5, 6), (8, 5), (11, 0), (24, 0)],
        "fyaw_r": [(0, 7), (5, 16), (13, 12), (24, 12)],
    },
    # the Hammer (earth's Slam): the fists clasped and cocked up behind the head, the whole body bent back into one C like a
    # drawn bow, the heels drawn up to the seat, the eyes up on the fists (held: the lock's wind-up, the read); hammered over
    # the top and down on one long arc to finish ahead of and below the knees as the body jackknifes deep and sinks, the
    # legs spread into a wide horse in the air framing the fists (Hung Gar's double hammer fist); the fists overshoot and
    # settle, held low a beat, then part and the body opens back into the fall.  hold_s: cocked; strike_s: the fists down;
    # back_s: opening
    "earth_hammer": {
        "length": 22, "base": AIR,
        "meta": {"hold_s": 3 / FPS, "strike_s": 6 / FPS, "back_s": 13 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, AIR["root"]), (2, (0.0, 0.03, -0.02)), (3, (0.0, 0.04, -0.03)), (4, (0.0, 0.03, -0.01)), (5, (0.0, -0.03, 0.02)),
                 (6, (0.0, -0.1, 0.03)), (8, (0.0, -0.12, 0.03)), (10, (0.0, -0.11, 0.03)), (13, (0.0, -0.06, 0.02)),
                 (17, (0.0, -0.02, 0.01)), (22, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, -10), (3, -16), (4, -10), (5, 8), (6, 26), (8, 29), (10, 27), (13, 18), (17, 10),
                 (22, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, -15), (3, -22), (4, -14), (5, 6), (6, 26), (8, 30), (10, 28), (13, 16), (17, 8),
                  (22, AIR["chest"])],
        "head": [(0, AIR["head"]), (2, 2), (3, -4), (4, -4), (5, -2), (6, -6), (8, -6), (10, -5), (13, 2), (17, 6),
                 (22, AIR["head"])],
        "clav_r": [(0, AIR["clav_r"]), (2, (-6, -22)), (3, (-6, -28)), (5, (6, -10)), (6, (16, 4)), (8, (16, 6)), (13, (6, -6)),
                   (22, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (-6, -22)), (3, (-6, -28)), (5, (6, -10)), (6, (16, 4)), (8, (16, 6)), (13, (6, -6)),
                   (22, AIR["clav_l"])],
        "hand_r": [(0, AR), (2, (-0.08, 1.66, -0.3)), (3, (-0.04, 1.72, -0.4)), (4, (-0.04, 1.8, -0.1)),
                   (5, (-0.05, 1.5, 0.45)), (6, (-0.06, 0.68, 0.57)), (8, (-0.06, 0.61, 0.56)), (10, (-0.06, 0.66, 0.57)),
                   (13, (-0.32, 0.88, 0.32)), (17, (-0.52, 1.1, 0.17)), (22, AR)],
        "hand_l": [(0, AL), (2, (0.08, 1.66, -0.3)), (3, (0.04, 1.72, -0.4)), (4, (0.04, 1.8, -0.1)),
                   (5, (0.05, 1.5, 0.45)), (6, (0.06, 0.675, 0.57)), (8, (0.06, 0.605, 0.56)), (10, (0.06, 0.655, 0.57)),
                   (13, (0.22, 0.82, 0.35)), (15, (0.36, 0.96, 0.27)), (18, (0.52, 1.2, 0.14)), (22, AL)],
        "face_r": [(0, "balance"), (2, "hammer_up"), (4, "hammer_up"), (6, "fist_down"), (11, "fist_down"), (16, "balance"),
                   (22, "balance")],
        "face_l": [(0, "balance"), (2, "hammer_up"), (4, "hammer_up"), (6, "fist_down"), (12, "fist_down"), (17, "balance"),
                   (22, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (2, (-1.0, 0.1, 0.4)), (4, (-1.0, 0.1, 0.4)), (6, (-1.0, 0.0, -0.2)), (11, (-1.0, 0.0, -0.2)),
                   (22, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (2, (1.0, 0.1, 0.4)), (4, (1.0, 0.1, 0.4)), (6, (1.0, 0.0, -0.2)), (11, (1.0, 0.0, -0.2)),
                   (22, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (2, 1.0), (12, 1.0), (16, 0.3), (22, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (2, 1.0), (13, 1.0), (17, 0.3), (22, AIR["grip_l"])],
        # (pass 3: at the strike the feet hang lower and the knees point down and out, so the fists hang clear below the
        # knee line instead of closing into a ball)
        "foot_r": [(0, AFR), (3, (-0.15, 0.7, -0.4)), (5, (-0.3, 0.46, 0.06)), (6, (-0.37, 0.37, 0.1)), (8, (-0.38, 0.35, 0.12)),
                   (10, (-0.375, 0.36, 0.12)), (13, (-0.26, 0.32, 0.16)), (22, AFR)],
        "foot_l": [(0, AFL), (3, (0.15, 0.72, -0.36)), (5, (0.3, 0.48, 0.04)), (6, (0.37, 0.38, 0.07)), (8, (0.38, 0.36, 0.09)),
                   (10, (0.375, 0.37, 0.09)), (13, (0.25, 0.34, 0.0)), (22, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (3, 50), (6, 20), (13, 22), (22, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (3, 50), (6, 20), (13, 24), (22, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (3, 4), (6, 30), (13, 18), (22, AIR["fyaw_r"])],
        "fyaw_l": [(0, AIR["fyaw_l"]), (3, 4), (6, 30), (13, 18), (22, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (3, (-0.3, -0.6, 0.8)), (5, (-0.9, 0.1, 0.5)), (6, (-0.8, -0.1, 0.6)), (10, (-0.8, -0.1, 0.6)),
                   (13, (-0.7, 0.1, 0.8)), (22, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (3, (0.3, -0.6, 0.8)), (5, (0.9, 0.1, 0.5)), (6, (0.8, -0.1, 0.6)), (10, (0.8, -0.1, 0.6)),
                   (13, (0.7, 0.1, 0.8)), (22, AIR["knee_l"])],
    },

    # the Downpour (water's Slam): the arms swept up wide into a tall V over the head, the palms turned up gathering the
    # rain, the chest opened back and the eyes up, the knees drawn up soft (held); the arms swept round and down in front on
    # two great arcs (the left a frame behind the right) to press the palms flat down, the arms long, a table of palms clear
    # of the hips, as the body stands up tall into a column, the legs long and together with the toes pointed, and is lifted
    # on the push (tai chi's pressing palms); the lift hangs, then the hands float back out into the fall.  hold_s: gathered;
    # strike_s: the palms pressed down; back_s: floating out
    "water_downpour": {
        "length": 24, "base": AIR,
        "meta": {"hold_s": 3 / FPS, "strike_s": 6 / FPS, "back_s": 14 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, AIR["root"]), (3, (0.0, -0.01, -0.01)), (5, (0.0, 0.04, 0.01)), (6, (0.0, 0.1, 0.02)), (8, (0.0, 0.16, 0.02)),
                 (11, (0.0, 0.155, 0.02)), (14, (0.0, 0.11, 0.01)), (18, (0.0, 0.05, 0.01)), (24, AIR["root"])],
        # (pass 3: the press has a forward-down line of action: the trunk folded over the palms, the eyes on the mark below,
        # the long legs swung ahead into a shallow pike; the chest a frame after the hips, the head a frame after the chest)
        "hips": [(0, AIR["hips"]), (3, -4), (4, -2), (5, 5), (6, 11), (8, 12.5), (11, 12), (14, 8), (19, 4), (24, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (3, -18), (4, -12), (5, -1), (6, 12), (7, 16.5), (9, 16), (12, 15), (15, 9), (20, 5),
                  (24, AIR["chest"])],
        "head": [(0, AIR["head"]), (3, -10), (4, -6), (5, -2), (6, 6), (7, 9), (8, 10.5), (11, 10), (13, 8), (16, 5),
                 (24, AIR["head"])],
        "side": [(0, 0), (3, 2), (6, -2), (9, 1), (14, 0), (24, 0)],
        "clav_r": [(0, AIR["clav_r"]), (3, (-6, -34)), (5, (6, -8)), (6, (12, 6)), (8, (13, 7)), (14, (6, -4)), (24, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (3, (-6, -34)), (5, (4, -10)), (6, (11, 4)), (8, (13, 7)), (14, (6, -4)), (24, AIR["clav_l"])],
        # (pass 3: the hands come inside the shoulders while still high (f5), so the strike frame falls almost straight down
        # and is the biggest step; the press keeps sinking to f9 and floats up from f11, the left a frame behind)
        "hand_r": [(0, AR), (2, (-0.5, 1.55, 0.05)), (3, (-0.44, 1.69, -0.035)), (4, (-0.46, 1.6, 0.16)), (5, (-0.3, 1.38, 0.3)),
                   (6, (-0.163, 1.003, 0.41)), (7, (-0.145, 0.998, 0.413)), (8, (-0.139, 1.005, 0.408)), (10, (-0.139, 1.012, 0.404)),
                   (12, (-0.16, 1.022, 0.395)),
                   (14, (-0.3, 1.06, 0.33)), (19, (-0.55, 1.15, 0.16)), (24, AR)],
        "hand_l": [(0, AL), (2, (0.5, 1.57, 0.04)), (3, (0.445, 1.695, -0.03)), (4, (0.48, 1.63, 0.12)), (5, (0.33, 1.43, 0.28)),
                   (6, (0.178, 1.01, 0.41)), (7, (0.152, 0.998, 0.412)), (8, (0.144, 1.001, 0.411)), (9, (0.14, 1.005, 0.409)),
                   (11, (0.139, 1.012, 0.405)), (13, (0.178, 1.02, 0.39)), (15, (0.31, 1.07, 0.32)), (20, (0.56, 1.25, 0.12)), (24, AL)],
        "face_r": [(0, "balance"), (2, "rain_up"), (4, "rain_up"), (5, "float"), (6, "press_down"), (12, "press_down"),
                   (17, "balance"), (24, "balance")],
        "face_l": [(0, "balance"), (2, "rain_up"), (4, "rain_up"), (5, "float"), (7, "press_down"), (13, "press_down"),
                   (18, "balance"), (24, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-0.9, -0.3, 0.3)), (6, (-0.9, -0.2, -0.4)), (13, (-0.9, -0.2, -0.4)), (24, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (3, (0.9, -0.3, 0.3)), (6, (0.9, -0.2, -0.4)), (13, (0.9, -0.2, -0.4)), (24, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (2, -0.3), (5, -0.3), (6, -0.5), (11, -0.45), (15, 0.0), (24, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (2, -0.3), (5, -0.3), (7, -0.5), (12, -0.45), (16, 0.0), (24, AIR["grip_l"])],
        "foot_r": [(0, AFR), (3, (-0.15, 0.38, 0.06)), (6, _heel_key("r", (-0.09, 0.23, 0.19), 55.0)),
                   (8, _heel_key("r", (-0.09, 0.29, 0.18), 55.0)), (11, _heel_key("r", (-0.09, 0.29, 0.19), 55.0)),
                   (14, (-0.13, 0.28, 0.2)), (24, AFR)],
        "foot_l": [(0, AFL), (3, (0.15, 0.42, -0.04)), (6, _heel_key("l", (0.09, 0.25, 0.13), 55.0)),
                   (8, _heel_key("l", (0.09, 0.31, 0.12), 55.0)),
                   (11, _heel_key("l", (0.09, 0.31, 0.13), 55.0)), (14, (0.13, 0.31, 0.02)), (24, AFL)],

        "heel_r": [(0, AIR["heel_r"]), (3, 30), (6, 55), (11, 55), (14, 40), (24, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (3, 30), (6, 55), (11, 55), (14, 42), (24, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (6, 2), (11, 2), (24, AIR["fyaw_r"])], "fyaw_l": [(0, AIR["fyaw_l"]), (6, 2), (11, 2), (24, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (3, (-0.35, 0.2, 1.0)), (6, (-0.1, 0.1, 1.0)), (11, (-0.1, 0.1, 1.0)), (24, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (3, (0.35, 0.2, 1.0)), (6, (0.1, 0.1, 1.0)), (11, (0.1, 0.1, 1.0)), (24, AIR["knee_l"])],
    },
    # the Axe Kick (fire's Slam; and its twin): the right leg swung up straight outside and over the head, the hips turned
    # away, the foot flexed with the heel up, the body leant back under it and the arms spread wide for the balance (held: the
    # read); chopped in on a crescent (out, over, down) and straight down ahead heel first, the knee locked long, the other
    # leg split back behind, the chest open and the eyes on the mark, both fists thrown back behind the hips against it; the
    # heel overshoots and the leg is carried on under him and folded as the arms settle, then back into the fall (Northern
    # Shaolin's axe kick).  hold_s: the leg up; strike_s: the heel down; back_s: folding back
    "fire_axe_kick": {
        "length": 22, "base": AIR, "mirror": True, "twin_ends": True,
        "meta": {"hold_s": 3 / FPS, "strike_s": 6 / FPS, "back_s": 13 / FPS, "hand": "foot_r", "mask": "full", "root": "place",
                 "legs_always": 1.0, "twin_ends": 1.0},
        "root": [(0, AIR["root"]), (3, (0.0, 0.07, -0.03)), (5, (0.0, 0.0, 0.0)), (6, (0.0, -0.06, 0.03)), (8, (0.0, -0.08, 0.04)),
                 (13, (0.0, -0.04, 0.02)), (22, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, -6), (3, -12), (4, -6), (5, 8), (6, 18), (8, 22), (10, 20), (13, 14), (17, 9), (22, AIR["hips"])],
        # (pass 3: the torso folds over the chopping heel at the strike, the eyes kept up on the mark)
        "chest": [(0, AIR["chest"]), (2, -4), (3, -8), (4, -2), (5, 10), (6, 18), (7, 20.5), (8, 20), (10, 17), (13, 11),
                  (17, 7), (22, AIR["chest"])],
        "head": [(0, AIR["head"]), (3, 10), (5, 4), (6, -5), (8, -6), (10, -2), (13, 4), (17, 6), (22, AIR["head"])],
        "twist": [(0, 0), (3, -10), (6, 8), (9, 6), (14, 0), (22, 0)],
        "yaw": [(0, 0), (3, -14), (5, -4), (6, 4), (13, 0), (22, 0)],
        "clav_r": [(0, AIR["clav_r"]), (3, (-6, -10)), (6, (-8, 0)), (9, (-4, -2)), (13, (4, -6)), (22, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (3, (8, -12)), (6, (-8, 0)), (9, (-4, -2)), (13, (2, -6)), (22, AIR["clav_l"])],
        "hand_r": [(0, AR), (3, (-0.46, 1.177, -0.215)), (5, (-0.458, 1.166, -0.191)), (6, (-0.39, 1.18, -0.2)),
                   (7, (-0.362, 1.166, -0.174)), (8, (-0.366, 1.15, -0.17)), (10, (-0.413, 1.124, -0.17)), (13, (-0.5, 1.05, 0.0)),
                   (17, (-0.55, 1.14, 0.1)), (22, AR)],
        "hand_l": [(0, AL), (3, (0.365, 1.37, 0.3)), (5, (0.42, 1.22, 0.05)), (6, (0.4, 1.18, -0.2)), (8, (0.42, 1.16, -0.205)),
                   (11, (0.42, 1.15, -0.175)), (13, (0.48, 1.1, 0.04)), (17, (0.56, 1.24, 0.1)), (22, AL)],
        "face_r": [(0, "balance"), (3, "fist_guard"), (5, "fist_guard"), (6, "fist_back"), (10, "fist_back"), (17, "balance"),
                   (22, "balance")],
        "face_l": [(0, "balance"), (3, "push"), (5, "push"), (6, "fist_back"), (11, "fist_back"), (17, "balance"), (22, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-0.7, -0.6, -0.3)), (6, (-0.8, -0.3, -0.5)), (13, (-0.8, -0.3, -0.5)), (22, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (3, (0.6, -0.8, 0.0)), (6, (0.8, -0.3, -0.5)), (13, (0.8, -0.3, -0.5)), (22, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (3, 1.0), (12, 1.0), (17, 0.3), (22, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (3, -0.4), (5, -0.2), (6, 1.0), (12, 1.0), (17, 0.3), (22, AIR["grip_l"])],
        # (the kicking ankle's crescent about the hip, keyed where the ankle lands (_heel_key): swung up outside the body at
        # the hold, in over the top, chopped straight down ahead at the strike with the knee locked, overshooting, carried
        # on under and folded)
        # (pass 3: the crescent swung wide outside on the way up, so it reads outside-in from behind)
        "foot_r": [(0, AFR), (2, _heel_key("r", (-0.45, 1.05, 0.25), -60.0)), (3, _heel_key("r", (-0.32, 1.5, 0.22), -90.0)),
                   (4, _heel_key("r", (-0.14, 1.36, 0.49), -85.0)), (5, _heel_key("r", (-0.11, 1.0, 0.62), -75.0)),
                   (6, _heel_key("r", (-0.1, 0.352, 0.61), -70.0)), (8, _heel_key("r", (-0.1, 0.27, 0.53), -30.0)),
                   (10, (-0.11, 0.26, 0.36)), (13, (-0.12, 0.27, 0.3)), (17, (-0.13, 0.27, 0.26)), (22, AFR)],
        "heel_r": [(0, AIR["heel_r"]), (2, -60), (3, -90), (4, -85), (5, -75), (6, -70), (8, -30), (10, 0), (13, 16),
                   (22, AIR["heel_r"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (3, 0), (8, 0), (22, AIR["fyaw_r"])],
        "knee_r": [(0, AIR["knee_r"]), (3, (-0.3, 0.6, 0.8)), (5, (-0.1, 0.3, 1.0)), (6, (-0.1, 0.0, 1.0)), (8, (-0.15, 0.0, 1.0)),
                   (22, AIR["knee_r"])],
        # (pass 3: the rear leg folded up under him at the strike, not split back: one long chopping leg against a compact
        # body)
        "foot_l": [(0, AFL), (3, (0.13, 0.3, -0.12)), (5, (0.13, 0.55, -0.16)), (6, (0.13, 0.7, -0.13)), (7, (0.13, 0.72, -0.12)),
                   (8, (0.13, 0.72, -0.12)), (10, (0.135, 0.62, -0.13)), (13, (0.14, 0.45, -0.16)), (22, AFL)],
        "heel_l": [(0, AIR["heel_l"]), (3, 36), (6, 20), (8, 20), (13, 32), (22, AIR["heel_l"])],
        "fyaw_l": [(0, AIR["fyaw_l"]), (6, 6), (22, AIR["fyaw_l"])],

        "knee_l": [(0, AIR["knee_l"]), (3, (0.2, -0.2, 1.0)), (5, (0.2, 0.3, 1.0)), (6, (0.2, 0.5, 1.0)), (8, (0.2, 0.5, 1.0)),
                   (13, (0.2, 0.1, 1.0)), (22, AIR["knee_l"])],

    },
    # the Down Gust (air's Slam): coiled small, the knees tucked up high, both palms drawn up flat by the ears with the
    # elbows high and wide and the trunk wrung hard to the right (held); unscrewed past the middle and driven straight down:
    # the palms pressed down flat beside the hips with the arms long and the shoulders sunk, the legs shot long and together
    # under him, the toes pointed, the spine a gentle S, the whole body lifted tall on the gust (Baguazhang's pressing
    # palms); the lift hangs, then he loosens back into the fall.  hold_s: coiled; strike_s: the palms down; back_s: loosening
    "air_down_gust": {
        "length": 22, "base": AIR,
        "meta": {"hold_s": 3 / FPS, "strike_s": 6 / FPS, "back_s": 13 / FPS, "hand": "both", "mask": "full", "root": "place"},
        "root": [(0, AIR["root"]), (3, (0.0, 0.0, -0.02)), (5, (0.0, 0.05, 0.0)), (6, (0.0, 0.1, 0.0)), (8, (0.0, 0.18, 0.0)),
                 (10, (0.0, 0.18, 0.0)), (13, (0.0, 0.12, 0.0)), (17, (0.0, 0.05, 0.0)), (22, AIR["root"])],
        "hips": [(0, AIR["hips"]), (3, 12), (4, 8), (5, 1), (6, -4), (8, -6), (10, -5), (13, 1), (17, 6), (22, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (3, 6), (4, 3), (5, -2), (6, -6), (8, -9), (10, -8), (13, -1), (17, 4), (22, AIR["chest"])],
        "head": [(0, AIR["head"]), (3, -8), (5, -2), (6, 6), (8, 8), (10, 7), (13, 6), (22, AIR["head"])],
        # (pass 3: the spiral carries on past the strike, the wheel still turning (overlap), and the head follows the chest
        # two frames behind it)
        "twist": [(0, 0), (3, -35), (4, -20), (5, 2), (6, 15), (8, 22), (11, 16), (15, 4), (22, 0)],
        "look": [(0, 0), (3, 4), (5, 13), (6, 8), (7, 0), (8, -6), (10, -9), (13, -6.5), (17, -1.5), (22, 0)],
        "side": [(0, 0), (3, -3), (6, 5), (8, 4), (11, 2), (15, 0), (22, 0)],
        "yaw": [(0, 0), (3, -8), (6, 6), (10, 4), (16, 0), (22, 0)],
        "clav_r": [(0, AIR["clav_r"]), (3, (-8, -22)), (5, (2, 2)), (6, (10, 16)), (8, (10, 17)), (13, (2, -4)), (22, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (3, (-8, -22)), (5, (2, 2)), (6, (10, 16)), (8, (10, 17)), (13, (2, -4)), (22, AIR["clav_l"])],
        # (pass 3: the palms flared out and down into a wide Λ, the fingers pointing out to the sides, each frame of the drive
        # bigger than the last; the press sinks on a little past the strike and the left settles a frame behind)
        "hand_r": [(0, AR), (3, (-0.3, 1.67, 0.05)), (4, (-0.33, 1.58, 0.07)), (5, (-0.39, 1.38, 0.06)), (6, (-0.515, 1.035, 0.02)),
                   (7, (-0.503, 1.04, 0.015)), (8, (-0.494, 1.048, 0.013)), (10, (-0.487, 1.062, 0.013)), (12, (-0.492, 1.08, 0.028)),
                   (14, (-0.522, 1.106, 0.059)), (17, (-0.55, 1.17, 0.12)), (22, AR)],
        "hand_l": [(0, AL), (3, (0.3, 1.69, 0.03)), (4, (0.33, 1.6, 0.05)), (5, (0.39, 1.41, 0.05)), (6, (0.484, 1.075, 0.019)),
                   (7, (0.462, 1.093, 0.004)), (8, (0.432, 1.102, -0.009)), (10, (0.437, 1.101, -0.008)), (12, (0.466, 1.09, 0.01)),
                   (14, (0.505, 1.087, 0.035)), (15, (0.522, 1.1, 0.05)), (18, (0.56, 1.26, 0.1)), (22, AL)],
        "face_r": [(0, "balance"), (2, "coil_down"), (4, "coil_down"), (6, "press_out"), (12, "press_out"), (17, "balance"),
                   (22, "balance")],
        "face_l": [(0, "balance"), (2, "coil_down"), (4, "coil_down"), (6, "press_out"), (13, "press_out"), (18, "balance"),
                   (22, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-1.0, 0.8, -0.2)), (5, (-1.0, 0.2, -0.3)), (6, (-0.8, -0.2, -0.6)), (22, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (3, (1.0, 0.8, -0.2)), (5, (1.0, 0.2, -0.3)), (6, (0.8, -0.2, -0.6)), (22, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (3, -0.2), (6, -0.55), (12, -0.5), (17, 0.0), (22, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (3, -0.2), (6, -0.55), (13, -0.5), (18, 0.0), (22, AIR["grip_l"])],
        # (pass 3: the knees kept half tucked under him at the strike, the body riding the gust compact, unlike the
        # Downpour's long column)
        "foot_r": [(0, AFR), (3, (-0.12, 0.67, 0.22)), (5, (-0.11, 0.5, 0.1)), (6, _heel_key("r", (-0.1, 0.45, 0.0), 45.0)),
                   (8, _heel_key("r", (-0.1, 0.47, -0.01), 45.0)), (10, _heel_key("r", (-0.1, 0.475, -0.01), 44.0)),
                   (13, (-0.12, 0.42, 0.06)), (22, AFR)],
        "foot_l": [(0, AFL), (3, (0.12, 0.69, 0.16)), (5, (0.11, 0.52, 0.07)), (6, _heel_key("l", (0.1, 0.46, -0.03), 45.0)),
                   (8, _heel_key("l", (0.1, 0.48, -0.04), 45.0)), (10, _heel_key("l", (0.1, 0.485, -0.04), 44.0)),
                   (14, (0.12, 0.42, -0.1)), (22, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (3, 20), (5, 35), (6, 45), (10, 44), (13, 36), (22, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (3, 20), (5, 35), (6, 45), (10, 44), (14, 36), (22, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (6, 4), (12, 4), (22, AIR["fyaw_r"])], "fyaw_l": [(0, AIR["fyaw_l"]), (6, 4), (12, 4), (22, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (3, (-0.1, 0.5, 1.0)), (6, (-0.1, 0.2, 1.0)), (10, (-0.1, 0.2, 1.0)), (22, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (3, (0.1, 0.5, 1.0)), (6, (0.1, 0.2, 1.0)), (10, (0.1, 0.2, 1.0)), (22, AIR["knee_l"])],

    },
    # the held guards (loops while E is held; the guard's own pose is the tell, spec 4.4)
    "guard_hold_earth": _guard(40, guard_earth_at,
                               face_r="palm_down", face_l="chamber", pole_r=(-1.0, 0.3, 0.0), pole_l=(1.0, -0.4, 0.0),
                               foot_r=(-0.3, 0.077, -0.12), fyaw_r=28.0, knee_r=(-0.6, 0.0, 1.0),
                               foot_l=(0.3, 0.077, 0.0), fyaw_l=22.0, knee_l=(0.6, 0.0, 1.0)),
    "guard_hold_water": _guard(48, guard_water_at,
                               face_r="push", face_l="push", pole_r=(-0.8, -0.6, -0.1), pole_l=(0.8, -0.6, -0.1),
                               foot_l=(0.16, 0.077, 0.2), fyaw_l=6.0, knee_l=(0.25, 0.0, 1.0),
                               foot_r=(-0.17, 0.077, -0.11), fyaw_r=30.0, knee_r=(-0.45, 0.0, 1.0)),
    "guard_hold_fire": _guard(24, guard_fire_at,
                              face_r="knife_up", face_l="fist_guard", pole_r=(-0.5, -1.0, 0.0), pole_l=(0.3, -0.5, -1.0),
                              grip_r=-0.5, grip_l=1.0, foot_l=(0.14, 0.077, 0.22), knee_l=(0.2, 0.2, 1.0),
                              foot_r=(-0.15, 0.077, -0.1), fyaw_r=36.0),
    "guard_hold_air": _guard(40, guard_air_at,
                             face_r="push", face_l="push", pole_r=(-0.8, -0.6, -0.1), pole_l=(0.8, -0.6, -0.1),
                             grip_r=-0.4, grip_l=-0.4, foot_l=(0.13, 0.077, 0.15), foot_r=(-0.14, 0.077, -0.08), fyaw_r=20.0),
    # the teeter (held toward the water at the lip; the code holds its last frame while he leans there): tipped out from
    # the ankles over the balls of the feet (eased in), both long arms windmilling backward from the shoulders to win the
    # balance back (the right leading, the left a beat behind, spun up and settled at different frames), the heels rising
    # and settling about the balls, the head down at the water; caught leaning out, the right arm up and back, the left out
    # ahead, the chest lifted, the right heel up.  strike_s: the lurch (f3); hold_s: the end, held
    "teeter": dict({"length": TEETER_LEN,
                    "meta": {"strike_s": 3 / FPS, "hold_s": TEETER_LEN / FPS, "hand": "both", "mask": "full", "root": "place",
                             "legs_always": 1.0},
                    "head": [(0, 0), (1, 1), (2, 4), (3, 9), (5, 16), (6, 21), (8, 18), (10, 22), (13, 19.5), (15, 20)],
                    "side": [(0, 0), (3, 3), (6, -4), (9, 3), (12, -1), (15, -1)],
                    "twist": [(0, 0), (3, 5), (6, -6), (9, 5), (12, -2), (15, -3)],
                    "clav_r": [(0, (0, 0)), (3, (6, -10)), (7, (0, -14)), (12, (2, -14)), (15, (-2, -16))],
                    "clav_l": [(0, (0, 0)), (4, (6, -10)), (8, (0, -14)), (12, (2, -15)), (15, (0, -16))],

                    "pole_r": [(0, (-0.35, -0.1, -1.0)), (2, (-1.0, -0.3, -0.3)), (15, (-1.0, -0.3, -0.3))],
                    "pole_l": [(0, (0.35, -0.1, -1.0)), (2, (1.0, -0.3, -0.3)), (15, (1.0, -0.3, -0.3))],
                    "grip_r": [(0, 0.4), (2, -0.25), (13, -0.2), (15, -0.1)], "grip_l": [(0, 0.4), (3, -0.25), (12, -0.2), (15, -0.15)],
                    "heel_r": [(0, 0), (1, 4), (2, 14), (3, 24), (5, 20), (8, 30), (11, 25), (13, 29), (15, 28)],
                    "heel_l": [(0, 0), (1, 3), (2, 10), (3, 18), (5, 22), (8, 25), (11, 29), (13, 25), (15, 26)],
                    "knee_r": [(0, "auto"), (15, "auto")], "knee_l": [(0, "auto"), (15, "auto")]},
                   **TEETER_KEYS, **_each(TEETER_LEN, teeter_at, ["hand_r", "hand_l", "face_r", "face_l"])),
}
CLIPS.update(SET7)


## ---------------------------------------------------------------- the eighth set (round 3's P3: the spout ride and its step
## off, the air High Kick's back-flip crescent and the four air-only close hits, one an element (the owner's answer of
## 2026-10-05: one air-only close hit per element with its own clip); authored the same way, key poses typed here, nothing
## read). The air clips start and end on AIR, the fall's first pose; the spout ride is a loop standing on the spout's water;
## its step-off starts on the ride's first pose and ends on AIR. Earth Hung Gar (the knee and the elbow driven together),
## water tai chi (the hands parting a ring), fire Northern Shaolin (the double flying kick, the back-flip crescent) and air
## Baguazhang (the open palms turned round the body) are style labels for the typed key poses only.
FACING.update({
    "fist_cock": ((0.15, 0.3, 0.94), (0.95, 0.0, -0.15)),     # a fist cocked back by the ear (the elbow raised behind it), the palm in
    "blade_out": ((-0.85, 0.45, 0.05), (0.0, 0.05, 1.0)),     # a palm high out at the arm's end, the fingers out and up, the palm forward (it leads the spin)
    "blade_wrap": ((0.7, 0.1, 0.7), (0.65, 0.0, -0.75)),      # a palm wrapped across the body for the spin's wind-up, the palm back
    "soles": ((0.1, -0.9, 0.4), (0.95, 0.0, 0.25)),           # a fist thrown back past the hip for the double kick, the palm in
})


## The water hit's ring (Spin Splash)
## Pass 2 (2026-10-07, the critic's pass-1 notes): the ball of water held at the arms' length from the shoulders (the
## elbows long), wound to 150 degrees behind his right side, through ahead at the strike and round to 150 behind his left;
## the waist leading the hands (the hips' yaw and the chest's twist take the disc's angle a little ahead of it), the body
## leaning out against it, the legs spread and swung round against the trunk as a counterweight; the hands a ball apart
## (the right palm over it, the left under), the wrists rolling through the sweep; parted at f9, the right trailing the left
## two frames and floating past the balance before it settles.
FACING.update({
    "press_down": ((-0.5, -0.05, 0.86), (0.05, -1.0, 0.0)),   # a tai chi press: the fingers ahead and out, the palm flat down on the water
    "arc_back": ((-0.32, 0.6, -0.72), (0.95, 0.1, -0.3)),     # an arm thrown back past the head along the spine's line, the palm in
    "bagua_lead": ((-0.25, 0.75, 0.6), (0.5, -0.1, 0.86)),    # Baguazhang's leading palm at the head's height, the fingers up, the palm in and ahead
    "fist_flung": ((-0.42, 0.3, -0.86), (0.9, 0.0, -0.4)),    # a fist flung back and out behind the shoulder, the palm in
})
## RING_ANG: the disc's angle round the ring (deg: 0 ahead, + to his left) from f1 to RING_PART.
RING_ANG = [(1, -100.0), (2, -150.0), (3, -132.0), (4, -72.0), (5, 0.0), (6, 68.0), (7, 112.0), (8, 138.0), (9, 150.0),
            (10, 156.0), (11, 158.0)]
RING_LEAD = 0.4            # the waist leads the hands by this many frames
RING_TURN = (0.6, 0.25)    # the share of the (led) disc's angle the hips' yaw and the chest's twist take
RING_LEAN = 0.18           # the body's lean away from the disc (deg of roll a degree of its angle)
RING_SIDE = 0.05           # and the spine's side bend with it
RING_LEGS = 0.25           # the legs' counter-swing against the hips (a share of the disc's angle, the other way)
## (pass 2: the legs a kneeling tuck that swings, the thighs down and ahead and the shins trailing back, the left foot
## farther back: never a seat in the air)
RING_FOOT = ((-0.12, 0.36, 0.02), (0.15, 0.4, -0.22))     # the tucked feet, the left trailing (the hips' frame)
RING_KNEE = ((-0.3, -0.2, 1.0), (0.32, -0.3, 1.0))        # the knees ahead and a little apart

RING_Y = 1.22              # the ball's middle (m): the palms 0.1 over and under it, at the shoulders' line
RING_HALF = (0.1, 0.1)     # the palms' offsets from the ball's middle (m: up / down, and out to each side)
RING_REACH = 0.505         # the farthest a palm is held from its shoulder (m: the arm nearly long, the elbow soft)
RING_STAGGER = 0.12        # how much farther out along the radius one palm may hold the ball than the other (m)
RING_PART = 9              # the hands part here (the right trailing the left two frames)
RING_ROLL = 18.0           # the wrists' roll through the sweep (deg)
WATER_LEN = 18
## the shoulders' height over the pelvis and their half width (m), for holding the ball at the arms' length from them
RING_SPINE = (0.42, 0.135)
WATER_ROOT = [(0, (0.0, 0.0, 0.0)), (2, (0.0, -0.01, 0.0)), (5, (0.0, 0.04, 0.02)), (8, (0.0, 0.06, 0.0)), (12, (0.0, 0.04, 0.0)),
              (18, (0.0, 0.0, 0.0))]
WATER_HIPS = [(0, AIR["hips"]), (2, 8), (5, 6), (8, 4), (12, 5), (18, AIR["hips"])]
WATER_CHEST = [(0, AIR["chest"]), (2, 10), (4, 9), (5, 8), (8, 4), (11, 2), (14, 4), (18, AIR["chest"])]
## the body's unwinding after the parting (yaw, twist, roll, side) back onto the fall's
RING_UNWIND = {"yaw": [(12, 66.0), (13, 44.0), (14, 24.0), (15, 8.0), (16, -3.0), (17, -1.5), (18, 0.0)],
               "twist": [(12, 16.0), (13, 7.0), (14, 0.0), (15, -4.0), (16, -3.0), (18, 0.0)],
               "roll": [(12, 8.0), (14, 1.0), (16, -2.0), (18, AIR["roll"])],
               "side": [(12, 3.0), (15, -1.0), (18, 0.0)]}


def _ring_th(f):
    return _kv(RING_ANG, min(max(f, 1.0), 11.0))


def _ring_trunk(f):
    """The ring's yaw, twist, roll and side bend at frame f (1..11): the waist taking the disc's angle RING_LEAD frames ahead
    of the hands, the body leaning out away from it."""
    lead = _ring_th(f + RING_LEAD)
    th = _ring_th(f)
    return {"yaw": RING_TURN[0] * lead, "twist": RING_TURN[1] * lead, "roll": RING_LEAN * th, "side": RING_SIDE * th}


def _water_keys(ch):
    """The water hit's trunk channel's keys: the fall's at f0, the ring's at every frame from f1 (to f11 for the turn, f10
    for the lean), then its unwinding."""
    last = 11 if ch in ("yaw", "twist") else 10
    first = AIR["roll"] if ch == "roll" else 0.0
    return [(0, first)] + [(fr, round(_ring_trunk(fr)[ch], 3)) for fr in range(1, last + 1)] + RING_UNWIND[ch]


WATER_TRUNK = {ch: _water_keys(ch) for ch in ("yaw", "twist", "roll", "side")}


def _water_ch(ch, f):
    return _kv(WATER_TRUNK[ch], f)


def _ring_shoulders(f):
    """The shoulders' places at frame f (approximately: the spine bowed by the hips and the chest, leant by the roll, turned
    by the yaw, the shoulder line by the yaw and the twist): (middle, right, left)."""
    pitch = math.radians(_kv(WATER_HIPS, f) + 0.85 * _kv(WATER_CHEST, f))
    roll = math.radians(_water_ch("roll", f))
    yaw = _water_ch("yaw", f)
    c = yaw + _water_ch("twist", f)
    up = (0.0, RING_SPINE[0] * math.cos(pitch), RING_SPINE[0] * math.sin(pitch))
    up = _yawv((-up[1] * math.sin(roll), up[1] * math.cos(roll), up[2]), yaw)
    root = _kv(WATER_ROOT, f)
    mid = (up[0] + root[0], 0.9 + root[1] + up[1], 0.02 + root[2] + up[2])
    lat = _yawv((RING_SPINE[1] * math.cos(roll), RING_SPINE[1] * math.sin(roll), 0.0), c)
    return mid, tuple(mid[i] - lat[i] for i in range(3)), tuple(mid[i] + lat[i] for i in range(3))


def _ring_hands(f):
    """The two palms on the ball at frame f: its middle out along the disc's angle from the shoulders' middle, as far as
    the farther arm reaches (RING_REACH)."""
    th = _ring_th(f)
    r = math.radians(th)
    out_v = (math.sin(r), 0.0, math.cos(r))
    tan_v = (math.cos(r), 0.0, -math.sin(r))
    mid, shr, shl = _ring_shoulders(f)
    sh = {"r": shr, "l": shl}
    # (each palm as far out along the disc's radius as its own arm reaches, the two kept within RING_STAGGER of each other
    # so they still hold one ball)
    p, dd = {}, {}
    for s, up, side in (("r", RING_HALF[0], -RING_HALF[1]), ("l", -RING_HALF[0], RING_HALF[1])):
        d = 0.85
        while d > 0.15:
            # (the right palm over the ball and toward its right, the left under it and toward its left, in the disc's frame)
            q = (mid[0] + d * out_v[0] + side * math.cos(r), RING_Y + up, mid[2] + d * out_v[2] - side * math.sin(r))
            if math.dist(q, sh[s]) <= RING_REACH:
                break
            d -= 0.005
        dd[s] = d
    dd = {"r": min(dd["r"], dd["l"] + RING_STAGGER), "l": min(dd["l"], dd["r"] + RING_STAGGER)}
    for s, up, side in (("r", RING_HALF[0], -RING_HALF[1]), ("l", -RING_HALF[0], RING_HALF[1])):
        p[s] = (mid[0] + dd[s] * out_v[0] + side * math.cos(r), RING_Y + up, mid[2] + dd[s] * out_v[2] - side * math.sin(r))
    return p, out_v, tan_v


def _ring_face(f, s, out_v, tan_v):
    """A palm's facing on the ball: the fingers out along the disc's radius, the right palm down on it and the left up under
    it, both rolled along the sweep (RING_ROLL, most through the strike)."""
    w = math.tan(math.radians(RING_ROLL * math.sin(math.pi * min(1.0, max(0.0, (f - 2.0) / 7.0)))))
    pv = (0.0, -1.0, 0.0) if s == "r" else (0.0, 1.0, 0.0)
    palm = _r3((pv[0] + w * tan_v[0], pv[1], pv[2] + w * tan_v[2]))
    return (_r3((out_v[0], -0.1, out_v[2])), palm)


def water_ring_at(f):
    """The Spin Splash's channels at frame f (1..RING_PART+2): the trunk's turn and lean, the hands on the ball, the legs."""
    th = _ring_th(f)
    tr = _ring_trunk(f)
    p, out_v, tan_v = _ring_hands(f)
    out = {}
    for s in "rl":
        out["hand_" + s] = p[s]
        out["face_" + s] = _ring_face(f, s, out_v, tan_v)
        out["pole_" + s] = _yawv(((-0.55 if s == "r" else 0.55), -0.8, -0.2), tr["yaw"] + tr["twist"])
    # (the legs swung with the trunk's lean as one long line, the feet thrown out toward the disc's side while the head
    # leans away from it, and turned round against the trunk)
    legs = tr["yaw"] - RING_LEGS * th
    for i, s in enumerate("rl"):
        out["foot_" + s] = _yawv(_lean_about_root(RING_FOOT[i], tr["roll"]), legs)
        out["knee_" + s] = _yawv(_lean_about_root(RING_KNEE[i], tr["roll"], 0.0), legs)
    return out


def _lean_about_root(v, roll, pivot_y=0.9):
    """A place (or, with pivot_y 0, a way) turned with the body's roll about the root (+ the left hip up: the feet swing to
    his left)."""
    r = math.radians(roll)
    x, y = v[0], v[1] - pivot_y
    return (x * math.cos(r) - y * math.sin(r), pivot_y + x * math.sin(r) + y * math.cos(r), v[2])


RING_CH = _each(RING_PART + 2, water_ring_at, ["hand_r", "hand_l", "face_r", "face_l", "pole_r", "pole_l", "foot_r", "foot_l",
                                               "knee_r", "knee_l"])
RING_CH = {k: [kv for kv in v if kv[0] >= 1] for k, v in RING_CH.items()}


def _upto(ch, last, first=1):
    return [kv for kv in RING_CH[ch] if first <= kv[0] <= last]


def _chest_rel(f, v):
    """A palm's place at frame f held out from the shoulders' middle in the turning chest's frame (v: out to the side, its
    height, ahead)."""
    mid = _ring_shoulders(f)[0]
    o = _yawv((v[0], 0.0, v[2]), _water_ch("yaw", f) + _water_ch("twist", f))
    return _r3((mid[0] + o[0], v[1], mid[2] + o[2]))


## The water hit's keys after the ring: the left hand parts at RING_PART and floats out into the balance (in the unwinding
## chest's frame), the right trails it two frames on the disc's path and floats on past the balance (behind it) before it
## settles.
WATER_HAND_L = _upto("hand_l", RING_PART) + [(11, _chest_rel(11, (0.46, 1.28, 0.12))), (13, _chest_rel(13, (0.48, 1.32, 0.1))),
                                              (15, _chest_rel(15, (0.47, 1.31, 0.09))), (18, AL)]
WATER_HAND_R = _upto("hand_r", RING_PART + 2) + [(13, _chest_rel(13, (-0.44, 1.37, -0.06))),
                                                  (15, _chest_rel(15, (-0.46, 1.31, 0.06))), (18, AR)]
WATER_FEET = {s: _upto("foot_" + s, RING_PART) + [(12, _r3(_yawv(RING_FOOT[i], 0.7 * _water_ch("yaw", 12)))),
                                                  (15, _r3(_yawv(((-0.14, 0.33, 0.18) if s == "r" else (0.14, 0.35, -0.2)),
                                                                 _water_ch("yaw", 15))))]
              for i, s in enumerate("rl")}


## The spout ride (own-bend-spout-ride, a loop of 48 frames while the spout holds him 3 m over the deck): stood on the
## water's crown in a low horse-riding stance (the feet wide in a surfer's slight stagger, the knees pushed out over the
## toes, the seat back over the middle of the feet), the round tai chi arms out at the sides pressing the water down with the
## palms; the weight wanders from foot to foot once a loop with the trunk and the arms answering it late (the low side's hand
## dropping, the high one lifting); twice a loop the water surges: a quick lift (SPOUT_LIFT of each half loop), then a long
## ease down; the knees take it two frames late, the hands sink with it a frame late, the head counters it three frames after
## the knees. Nothing slides: the feet stay where they stand.
## Pass 2 (the critic's pass-1 notes): the stance wider and staggered with the knees out, the seat back, the arms raised and
## round pressing the water, the surge asymmetric and lagged through the body.
SPOUT_LEN = 48
SPOUT_FOOT_R = (-0.2, 0.077, -0.1)
SPOUT_FOOT_L = (0.2, 0.077, 0.12)
SPOUT_LIFT = 4.0 / 24.0     # the surge's quick lift: 4 frames of each 24


def _surge(a, late=0.0):
    """The water's surge under him (0-1, twice a loop) at phase a, `late` frames after it: a quick lift, a long ease down."""
    p = (a / math.pi - late / 24.0) % 1.0
    if p < SPOUT_LIFT:
        return 0.5 - 0.5 * math.cos(math.pi * p / SPOUT_LIFT)
    return 0.5 + 0.5 * math.cos(math.pi * (p - SPOUT_LIFT) / (1.0 - SPOUT_LIFT))


def spout_at(a):
    sway = _s(a)                         # the weight over the left foot (+) or the right (-)
    lag = 2 * math.pi * 4 / SPOUT_LEN    # the arms four frames behind the hips
    rise = _surge(a)                     # the water's lift
    knees = _surge(a, 2.0)               # taken in the knees two frames late
    hands = _surge(a, 1.0)               # the palms pressed down with it a frame late
    head = _surge(a, 5.0)                # the head countering it three frames after the knees
    return {
        "root": (0.05 * sway + 0.006 * _s(2 * a, 0.7), -0.115 + 0.02 * rise - 0.05 * knees, 0.012 * _s(a, 1.2)),
        "roll": 3.5 * sway, "hips": 8.0 + 3.0 * knees, "chest": -2.0 + 2.0 * _surge(a, 3.0) + 1.0 * _s(2 * a, -0.4),
        "side": -6.5 * _s(a, -0.5), "twist": 4.0 * _s(a, -1.4), "yaw": 2.5 * _s(a, 2.0),
        "head": 2.0 - 4.0 * head, "tilt": -4.5 * _s(a, -0.9), "look": 8.0 * _s(a, -1.8),
        "clav_r": (2.0, -6.0 - 5.0 * _s(a, -lag)), "clav_l": (2.0, -6.0 + 5.0 * _s(a, -lag)),
        # (the round arms out at the sides, the palms pressing the water: the low side's hand dropping, the far one lifting,
        # after the hips; both sinking with the surge)
        "hand_r": (-0.47 - 0.03 * _s(a, -lag), 1.09 + 0.07 * _s(a, -lag) - 0.07 * hands, 0.25 + 0.04 * _c(a, -lag)),
        "hand_l": (0.47 + 0.03 * _s(a, -lag + 0.3), 1.11 - 0.06 * _s(a, -lag + 0.3) - 0.06 * hands, 0.26 - 0.04 * _c(a, -lag + 0.3)),

        "grip_r": -0.3 + 0.1 * _s(a, -2.0), "grip_l": -0.3 + 0.1 * _s(a, -2.6),
    }


SPOUT = dict(STAND)
SPOUT.update({k: _rv(v) for k, v in spout_at(0.0).items()})
SPOUT.update({"face_r": "press_down", "face_l": "press_down", "pole_r": (-0.85, -0.45, -0.3), "pole_l": (0.85, -0.45, -0.3),
              "foot_r": SPOUT_FOOT_R, "foot_l": SPOUT_FOOT_L, "fyaw_r": 16.0, "fyaw_l": 10.0,
              "knee_r": (-0.5, 0.0, 1.0), "knee_l": (0.5, 0.0, 1.0)})
SR, SL = SPOUT["hand_r"], SPOUT["hand_l"]


SET8 = {
    # the spout ride (a loop; the code holds him on the spout until he leaves it): see spout_at
    "spout_ride": dict({"length": SPOUT_LEN, "loop": True, "base": SPOUT,
                        "meta": {"hand": "both", "mask": "full", "root": "place", "legs_always": 1.0}},
                       **_loop(SPOUT_LEN, spout_at),
                       **_const(SPOUT_LEN, face_r="press_down", face_l="press_down", pole_r=(-0.85, -0.45, -0.3),
                                pole_l=(0.85, -0.45, -0.3), foot_r=SPOUT_FOOT_R, foot_l=SPOUT_FOOT_L, fyaw_r=16.0, fyaw_l=10.0,
                                knee_r=(-0.5, 0.0, 1.0), knee_l=(0.5, 0.0, 1.0))),
    # the step off the spout (from the ride's first pose onto the fall's first, AIR): a deep dip on the knees (held f2-f4: the
    # read), then the body tipped out over the stepping foot, the head leading, the right foot stepped out and down past the
    # crown's edge as the left leg drives straight off its ball (the heel up, the ball kept on the crown until it leaves), the
    # arms in opposition (the right back, the left ahead and up); the legs gathered under him into the fall's, the arms opening
    # into its balance, the head last.  hold_s: the dip; strike_s: the push off; back_s: gathering into the fall
    "spout_step_off": {
        "length": 16, "base": SPOUT,
        "meta": {"hold_s": 3 / FPS, "strike_s": 6 / FPS, "back_s": 9 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, SPOUT["root"]), (2, (0.0, -0.26, -0.01)), (4, (0.0, -0.28, 0.0)), (6, (0.0, -0.09, 0.12)),
                 (8, (0.0, 0.0, 0.16)), (11, (0.0, 0.02, 0.08)), (16, AIR["root"])],
        "roll": [(0, SPOUT["roll"]), (3, 0.0), (6, -3.0), (9, 1.0), (16, AIR["roll"])],
        "hips": [(0, SPOUT["hips"]), (2, 13), (4, 14), (6, 14), (8, 10), (12, 8), (16, AIR["hips"])],
        "chest": [(0, SPOUT["chest"]), (2, 9), (4, 10), (6, 12), (8, 8), (12, 6), (16, AIR["chest"])],
        "side": [(0, SPOUT["side"]), (3, 0), (16, 0)], "tilt": [(0, SPOUT["tilt"]), (4, 0), (16, 0)],
        "twist": [(0, SPOUT["twist"]), (3, -4), (6, 8), (10, 2), (16, AIR["twist"])],
        "yaw": [(0, SPOUT["yaw"]), (3, 0), (16, 0)], "look": [(0, SPOUT["look"]), (3, 0), (16, 0)],
        "head": [(0, SPOUT["head"]), (3, 8), (5, 2), (6, -2), (9, 3), (12, 7), (16, AIR["head"])],
        "clav_r": [(0, SPOUT["clav_r"]), (3, (4, -2)), (6, (-8, -4)), (10, (2, -12)), (16, AIR["clav_r"])],
        "clav_l": [(0, SPOUT["clav_l"]), (3, (4, -2)), (6, (10, -14)), (10, (-2, -12)), (16, AIR["clav_l"])],
        # (opposition: the right arm swung back as the right foot steps, the left forward and up, then both open into the
        # fall's balance)
        "hand_r": [(0, SR), (2, (-0.46, 0.98, 0.16)), (4, (-0.46, 0.97, 0.15)), (6, (-0.32, 1.04, -0.14)), (8, (-0.44, 1.15, -0.08)),
                   (11, (-0.58, 1.27, 0.04)), (16, AR)],
        "hand_l": [(0, SL), (2, (0.46, 0.99, 0.17)), (4, (0.46, 0.98, 0.16)), (6, (0.24, 1.3, 0.42)), (8, (0.4, 1.38, 0.3)),
                   (11, (0.57, 1.35, 0.13)), (16, AL)],
        "face_r": [(0, "press_down"), (4, "press_down"), (6, "dive"), (8, "dive"), (12, "balance"), (16, "balance")],
        "face_l": [(0, "press_down"), (4, "press_down"), (6, "point"), (8, "point"), (12, "balance"), (16, "balance")],
        "pole_r": [(0, SPOUT["pole_r"]), (4, SPOUT["pole_r"]), (6, (-0.6, -0.4, 0.7)), (16, AIR["pole_r"])],
        "pole_l": [(0, SPOUT["pole_l"]), (4, SPOUT["pole_l"]), (6, (0.6, -0.8, -0.2)), (16, AIR["pole_l"])],
        "grip_r": [(0, SPOUT["grip_r"]), (6, 0.2), (16, AIR["grip_r"])], "grip_l": [(0, SPOUT["grip_l"]), (6, -0.2), (16, AIR["grip_l"])],
        # (the feet pinned through the dip (f0-f4); the right steps out ahead and down past the crown's edge at f5-f6; the
        # left's ball kept on the crown while its heel rises (f4-f5), driving off straight and leaving at f6)
        "foot_r": [(0, SPOUT_FOOT_R), (4, SPOUT_FOOT_R), (5, (-0.17, 0.15, 0.16)), (6, (-0.15, 0.1, 0.38)), (8, (-0.15, 0.15, 0.36)),
                   (9, (-0.15, 0.2, 0.32)), (12, (-0.145, 0.26, 0.26)), (16, AFR)],
        "heel_r": [(0, 0), (4, 0), (5, 8), (6, 4), (9, 18), (16, AIR["heel_r"])],
        "fyaw_r": [(0, SPOUT["fyaw_r"]), (4, SPOUT["fyaw_r"]), (6, 6), (16, AIR["fyaw_r"])],
        "knee_r": [(0, SPOUT["knee_r"]), (4, SPOUT["knee_r"]), (6, (-0.25, 0.1, 1.0)), (16, AIR["knee_r"])],
        "foot_l": [(0, SPOUT_FOOT_L), (5, SPOUT_FOOT_L), (6, _heel_key("l", (0.16, 0.2, -0.16), 55.0)), (9, (0.15, 0.3, -0.22)),
                   (12, (0.14, 0.33, -0.22)), (16, AFL)],
        "heel_l": [(0, 0), (3, 0), (4, 20), (5, 42), (6, 55), (10, 40), (16, AIR["heel_l"])],
        "fyaw_l": [(0, SPOUT["fyaw_l"]), (5, SPOUT["fyaw_l"]), (16, AIR["fyaw_l"])],
        "knee_l": [(0, SPOUT["knee_l"]), (4, SPOUT["knee_l"]), (6, (0.25, 0.0, 1.0)), (16, AIR["knee_l"])],
    },
    # the air High Kick (fire's 2 tapped twice, in the air; and its twin): a back-flip crescent: gathered small and bowed over,
    # the fists swung down behind the hips (held: the lock's read); the arms thrown back past the head along the spine's line
    # (half-closed fists) as the body turns over backward, the right leg swung up straight on a crescent, out wide of the hip
    # and in over the top, the foot passing high ahead along the aim at the strike (the knee long), the left leg folded tight
    # (the heel to the seat); the kicking leg folded in over three frames, the hands brought round on their arc onto the
    # shins, the body tucked tight round the rest of the somersault (fastest in the tuck); opened out into the fall, the legs
    # first, the chest after, the head last (Northern Shaolin's back-flip kick). The left arm a frame behind the right
    # throughout.  hold_s: gathered; strike_s: the foot high ahead; back_s: opening out of the tuck
    "fire_flip_kick": {
        "length": 24, "base": AIR, "mirror": True, "twin_ends": True,
        "meta": {"hold_s": 3 / FPS, "strike_s": 6 / FPS, "back_s": 14 / FPS, "hand": "foot_r", "mask": "full", "root": "place",
                 "legs_always": 1.0, "twin_ends": 1.0},
        "flip": [(0, 0), (2, 6), (3, 8), (4, -4), (5, -18), (6, -40), (7, -75), (8, -120), (9, -168), (10, -214), (11, -255),
                 (12, -288), (13, -313), (14, -332), (16, -350), (19, -358), (24, -360)],
        "root": [(0, AIR["root"]), (3, (0.0, -0.04, 0.02)), (6, (0.0, 0.05, 0.0)), (10, (0.0, 0.07, 0.0)), (14, (0.0, 0.04, 0.0)),
                 (24, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, 14), (3, 16), (4, 6), (5, -6), (6, -10), (7, 4), (8, 22), (11, 26), (13, 20), (15, 12),
                 (19, 8), (24, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, 16), (3, 18), (4, 6), (5, -8), (6, -12), (7, 2), (8, 20), (11, 26), (13, 18), (15, 10),
                  (18, 6), (24, AIR["chest"])],
        "head": [(0, AIR["head"]), (2, 10), (3, 12), (5, 14), (6, 18), (7, 18), (9, 24), (12, 26), (14, 22), (16, 17), (19, 9),
                 (24, AIR["head"])],
        "twist": [(0, 0), (3, -8), (5, 6), (6, 10), (8, 4), (12, 0), (24, 0)],
        "side": [(0, 0), (5, 4), (6, 6), (8, 2), (12, 0), (24, 0)],
        "clav_r": [(0, AIR["clav_r"]), (3, (8, 10)), (6, (-10, -22)), (8, (6, 0)), (12, (10, 6)), (15, (4, -6)), (24, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (4, (8, 10)), (7, (-10, -20)), (9, (6, 0)), (13, (10, 6)), (16, (4, -6)), (24, AIR["clav_l"])],
        # (the arms: swung down behind the hips at the hold, thrown up and back past the head along the spine's line as he
        # turns over, brought round on one arc over the top onto the shins in the tuck; opened out into the balance; the left
        # a frame behind the right throughout)
        "hand_r": [(0, AR), (2, (-0.34, 1.0, -0.15)), (3, (-0.3, 1.0, -0.2)), (4, (-0.42, 1.26, -0.14)), (5, (-0.38, 1.6, -0.32)),
                   (6, (-0.33, 1.68, -0.43)), (7, (-0.32, 1.75, 0.14)), (8, (-0.28, 1.45, 0.58)), (9, (-0.16, 1.0, 0.52)),
                   (12, (-0.15, 0.86, 0.41)), (14, (-0.3, 1.0, 0.32)), (18, (-0.55, 1.18, 0.16)), (24, AR)],
        "hand_l": [(0, AL), (3, (0.34, 1.0, -0.15)), (4, (0.3, 1.0, -0.2)), (5, (0.42, 1.25, -0.15)), (6, (0.38, 1.59, -0.32)),
                   (7, (0.33, 1.66, -0.41)),
 (8, (0.32, 1.73, 0.12)), (9, (0.28, 1.44, 0.56)), (10, (0.17, 0.99, 0.5)),
                   (13, (0.16, 0.88, 0.4)), (15, (0.32, 1.02, 0.3)), (19, (0.56, 1.25, 0.14)), (24, AL)],
        "face_r": [(0, "balance"), (2, "fist_back"), (3, "fist_back"), (5, "arc_back"), (7, "arc_back"), (9, "hug"), (12, "hug"),
                   (17, "balance"), (24, "balance")],
        "face_l": [(0, "balance"), (3, "fist_back"), (4, "fist_back"), (6, "arc_back"), (8, "arc_back"), (10, "hug"), (13, "hug"),
                   (18, "balance"), (24, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (3, (-0.6, 0.2, 0.8)), (6, (-0.9, -0.1, 0.4)), (9, (-1.0, -0.2, 0.0)), (13, (-1.0, -0.2, 0.0)),
                   (24, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (4, (0.6, 0.2, 0.8)), (7, (0.9, -0.1, 0.4)), (10, (1.0, -0.2, 0.0)), (14, (1.0, -0.2, 0.0)),
                   (24, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (2, 1.0), (4, 0.6), (5, 0.3), (7, 0.3), (9, 0.7), (13, 0.7), (18, 0.2), (24, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (3, 1.0), (5, 0.6), (6, 0.3), (8, 0.3), (10, 0.7), (14, 0.7), (19, 0.2), (24, AIR["grip_l"])],
        # (the kicking leg: tucked at the hold, swung out wide of the hip, in over the top straight (the foot high ahead at
        # the strike, the knee long), across inside, folded in over three frames (the knee's way turned round gradually);
        # tucked with the other round the somersault)
        "foot_r": [(0, AFR), (2, (-0.12, 0.55, 0.16)), (3, (-0.12, 0.58, 0.15)), (4, _heel_key("r", (-0.36, 0.52, 0.36), 50.0)),
                   (5, _heel_key("r", (-0.36, 0.8, 0.62), 55.0)), (6, _heel_key("r", (-0.082, 1.01, 0.745), 55.0)),
                   (7, _heel_key("r", (0.13, 0.94, 0.6), 50.0)), (8, (0.04, 0.74, 0.36)), (9, (-0.08, 0.62, 0.24)),
                   (10, (-0.11, 0.6, 0.22)), (12, (-0.11, 0.6, 0.21)), (14, (-0.13, 0.48, 0.22)), (17, (-0.14, 0.33, 0.23)), (24, AFR)],
        "heel_r": [(0, AIR["heel_r"]), (3, 40), (4, 50), (5, 55), (7, 50), (9, 40), (13, 40), (17, 30), (24, AIR["heel_r"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (4, 18), (6, 0), (8, 0), (24, AIR["fyaw_r"])],
        "knee_r": [(0, AIR["knee_r"]), (3, (-0.1, 0.5, 1.0)), (4, (-0.6, 0.6, 0.6)), (5, (-0.5, 0.8, 0.3)), (6, (-0.1, 1.0, -0.1)),
                   (7, (0.1, 0.95, 0.1)), (8, (0.08, 0.8, 0.6)), (9, (-0.05, 0.5, 1.0)), (10, (-0.1, 0.4, 1.0)),
                   (13, (-0.1, 0.4, 1.0)), (24, AIR["knee_r"])],
        "foot_l": [(0, AFL), (2, (0.12, 0.53, 0.12)), (3, (0.12, 0.56, 0.11)), (5, (0.13, 0.62, 0.12)), (7, (0.13, 0.62, 0.12)),
                   (9, (0.11, 0.62, 0.2)), (12, (0.11, 0.6, 0.19)), (15, (0.13, 0.46, 0.08)), (19, (0.14, 0.36, -0.12)), (24, AFL)],
        "heel_l": [(0, AIR["heel_l"]), (3, 40), (5, 50), (7, 50), (9, 40), (14, 40), (24, AIR["heel_l"])],
        "fyaw_l": [(0, AIR["fyaw_l"]), (5, 6), (24, AIR["fyaw_l"])],
        "knee_l": [(0, AIR["knee_l"]), (3, (0.1, 0.5, 1.0)), (5, (0.15, 0.6, 1.0)), (7, (0.15, 0.6, 1.0)), (9, (0.1, 0.4, 1.0)),
                   (14, (0.1, 0.4, 1.0)), (24, AIR["knee_l"])],
    },
    # the earth air hit (Stone Knee; and its twin): balled up and wound to the right, the right knee chambered, the right
    # fist cocked back by the ear, the left fist reaching out to measure (held); the whole figure whips round to the left: a
    # hit-stop as the right knee is driven up high outside the coat before him and the right elbow down onto it (the fist by
    # the chin), the left fist arriving two frames late stacked on the right, the left heel tucked to the seat, the trunk
    # curled over them all: one compact boulder, both elbows in; then the whip carries it round once (fastest after the
    # hit-stop), the head lagging and snapping round to spot; overshot a little and settled, opened back into the fall, the
    # left leg two frames after the right (Hung Gar's driving elbow).  hold_s: wound; strike_s: the knee and the elbow met
    # before him; back_s: opening
    "air_hit_earth": {
        "length": 18, "base": AIR, "mirror": True, "twin_ends": True,
        "meta": {"hold_s": 2 / FPS, "strike_s": 4 / FPS, "back_s": 10 / FPS, "hand": "r", "mask": "full", "root": "place",
                 "legs_always": 1.0, "twin_ends": 1.0},
        "spin": [(0, 0), (1, -28), (2, -50), (3, -14), (4, 18), (5, 24), (6, 88), (7, 155), (8, 220), (9, 272), (10, 312),
                 (11, 340), (12, 358), (13, 368), (15, 362), (16, 360), (18, 360)],
        "look": [(0, 0), (2, 30), (3, 16), (4, 4), (5, 0), (6, -28), (7, -46), (8, -12), (9, 30), (10, 28), (12, 12), (14, 3),
                 (18, 0)],
        "root": [(0, AIR["root"]), (2, (0.0, 0.03, 0.0)), (4, (0.0, -0.01, 0.02)), (6, (0.0, -0.02, 0.02)), (9, (0.0, 0.0, 0.0)),
                 (18, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, 14), (4, 30), (6, 30), (9, 27), (12, 19), (15, 10), (18, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, 14), (3, 24), (4, 34), (6, 34), (9, 29), (12, 19), (15, 9), (18, AIR["chest"])],
        "twist": [(0, 0), (2, -24), (3, -6), (4, 12), (5, 14), (8, 10), (11, 5), (14, 1), (18, 0)],
        "side": [(0, 0), (2, 6), (4, -5), (7, -4), (11, -2), (18, 0)],
        "head": [(0, AIR["head"]), (2, 4), (4, 6), (5, 8), (8, 8), (11, 6), (14, 6), (18, AIR["head"])],
        "clav_r": [(0, AIR["clav_r"]), (2, (-10, -16)), (4, (14, 8)), (8, (12, 8)), (11, (8, 2)), (14, (2, -6)), (18, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (12, -2)), (6, (12, 6)), (9, (10, 6)), (13, (2, -4)), (18, AIR["clav_l"])],
        # (the right fist: cocked back by the ear, then the elbow driven down onto the knee with the fist by the chin, grinding
        # down a little through the hit-stop and the whip; the left fist measuring, then pulled in two frames late to stack on
        # the right (two fists on one rock), eased out after the right)
        "hand_r": [(0, AR), (1, (-0.42, 1.38, 0.0)), (2, (-0.24, 1.46, -0.08)), (3, (-0.16, 1.38, 0.3)), (4, (-0.19, 1.34, 0.38)),
                   (6, (-0.19, 1.32, 0.38)), (8, (-0.19, 1.31, 0.37)), (10, (-0.24, 1.28, 0.3)), (13, (-0.36, 1.18, 0.2)), (18, AR)],
        "hand_l": [(0, AL), (2, (0.18, 1.26, 0.4)), (3, (0.14, 1.22, 0.42)), (4, (-0.02, 1.26, 0.44)), (5, (-0.08, 1.29, 0.43)),
                   (6, (-0.1, 1.3, 0.43)), (9, (-0.1, 1.29, 0.42)), (11, (0.0, 1.22, 0.34)),
 (14, (0.44, 1.2, 0.14)),
                   (16, (0.55, 1.28, 0.1)), (18, AL)],
        "face_r": [(0, "balance"), (1, "fist_cock"), (2, "fist_cock"), (4, "fist_guard"), (10, "fist_guard"), (15, "balance"),
                   (18, "balance")],
        "face_l": [(0, "balance"), (2, "fist_guard"), (3, "fist_guard"), (6, "fist_guard"), (11, "fist_guard"), (16, "balance"),
                   (18, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (2, (-0.8, 0.7, -0.5)), (3, (-0.6, -0.3, 0.2)), (4, (-0.585, 0.23, -0.79)),
                   (10, (-0.585, 0.23, -0.79)),

 (14, (-0.8, -0.4, 0.0)), (18, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (2, (0.5, -0.6, 0.2)), (5, (0.2, -1.0, 0.3)), (11, (0.2, -1.0, 0.3)), (15, (0.7, -0.5, -0.3)),
                   (18, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (1, 1.0), (13, 1.0), (16, 0.3), (18, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (2, 1.0), (14, 1.0), (17, 0.3), (18, AIR["grip_l"])],
        # (the right knee chambered, then driven up high and out past the coat's front edge; the left heel tucked to the
        # seat; both legs held in the ball through the whip, the right opening first and the left two frames after it)
        "foot_r": [(0, AFR), (2, (-0.13, 0.58, 0.12)), (3, _heel_key("r", (-0.12, 0.74, 0.2), 45.0)),
                   (4, _heel_key("r", (-0.12, 0.86, 0.3), 45.0)), (6, _heel_key("r", (-0.12, 0.87, 0.3), 45.0)),
                   (8, _heel_key("r", (-0.12, 0.85, 0.29), 45.0)), (10, _heel_key("r", (-0.12, 0.78, 0.27), 42.0)),
                   (12, (-0.13, 0.6, 0.24)), (15, (-0.14, 0.4, 0.24)), (18, AFR)],
        "heel_r": [(0, AIR["heel_r"]), (3, 45), (10, 42), (18, AIR["heel_r"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (4, 0), (10, 0), (18, AIR["fyaw_r"])],
        "knee_r": [(0, AIR["knee_r"]), (2, (-0.3, 0.4, 1.0)), (4, (-0.18, 0.7, 0.8)), (9, (-0.18, 0.7, 0.8)), (13, (-0.15, 0.4, 1.0)),
                   (18, AIR["knee_r"])],
        "foot_l": [(0, AFL), (2, (0.14, 0.46, -0.1)), (4, (0.14, 0.5, -0.2)), (9, (0.14, 0.5, -0.2)), (12, (0.14, 0.49, -0.21)),
                   (14, (0.15, 0.43, -0.25)), (16, (0.15, 0.36, -0.24)), (18, AFL)],
        "heel_l": [(0, AIR["heel_l"]), (3, 50), (12, 50), (18, AIR["heel_l"])],
        "knee_l": [(0, AIR["knee_l"]), (3, (0.25, -0.3, 1.0)), (12, (0.25, -0.3, 1.0)), (18, AIR["knee_l"])],
    },
    # the water air hit (Spin Splash; and its twin): the left hand reaching across to join the right behind his right hip on a
    # ball of water (the right palm over it, the left under it), the body wound right with it and leaning away (held); the
    # ball swung round on one flat ring at the arms' length from the shoulders, through ahead at the strike and on round to
    # behind his left shoulder, the waist leading it, the body leaning out against it a hammer thrower's way, the spread legs
    # swinging round against the trunk (water_ring_at); the hands part, the right trailing the left and floating past the
    # balance, as the turn unwinds into the fall (tai chi's cloud hands at full stretch).  hold_s: wound; strike_s: the ball
    # swung through ahead; back_s: parting
    "air_hit_water": {
        "length": WATER_LEN, "base": AIR, "mirror": True, "twin_ends": True,
        "meta": {"hold_s": 2 / FPS, "strike_s": 5 / FPS, "back_s": 10 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0, "twin_ends": 1.0},
        "root": [(fr, _r3(_add(AIR["root"], v))) for fr, v in WATER_ROOT],
        "yaw": WATER_TRUNK["yaw"], "twist": WATER_TRUNK["twist"], "roll": WATER_TRUNK["roll"], "side": WATER_TRUNK["side"],
        "hips": WATER_HIPS, "chest": WATER_CHEST,
        "head": [(0, AIR["head"]), (2, 6), (5, 4), (8, 2), (12, 3), (16, 6), (18, AIR["head"])],
        "look": [(0, 0), (2, 20), (4, 10), (5, 0), (7, -20), (9, -28), (11, -24), (13, -10), (16, -2), (18, 0)],
        "clav_r": [(0, AIR["clav_r"]), (2, (-6, 0)), (5, (16, -4)), (8, (20, -4)), (11, (12, -6)), (18, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (18, 0)), (5, (16, -4)), (8, (-4, -6)), (11, (-6, -8)), (18, AIR["clav_l"])],
        "hand_r": [(0, AR)] + WATER_HAND_R,
        "hand_l": [(0, AL), (1, (0.02, 1.14, 0.46))] + WATER_HAND_L[1:],
        "face_r": [(0, "balance")] + _upto("face_r", RING_PART + 2) + [(14, "float"), (16, "balance"), (18, "balance")],
        "face_l": [(0, "balance"), (1, "palm_up_wide")] + _upto("face_l", RING_PART, 2) + [(12, "balance"), (18, "balance")],
        "pole_r": [(0, AIR["pole_r"])] + _upto("pole_r", RING_PART + 2) + [(15, AIR["pole_r"]), (18, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"])] + _upto("pole_l", RING_PART) + [(13, AIR["pole_l"]), (18, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (2, -0.2), (5, -0.4), (11, -0.4), (14, 0.0), (18, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (2, -0.2), (5, -0.4), (9, -0.4), (12, 0.0), (18, AIR["grip_l"])],
        "foot_r": [(0, AFR)] + WATER_FEET["r"] + [(18, AFR)],
        "foot_l": [(0, AFL)] + WATER_FEET["l"] + [(18, AFL)],
        "knee_r": [(0, AIR["knee_r"])] + _upto("knee_r", RING_PART) + [(14, (-0.25, 0.2, 1.0)), (18, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"])] + _upto("knee_l", RING_PART) + [(14, (0.25, 0.15, 1.0)), (18, AIR["knee_l"])],
        "heel_r": [(0, AIR["heel_r"]), (2, 35), (10, 35), (14, 32), (18, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (2, 35), (10, 35), (14, 34), (18, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (2, 0), (12, 0), (18, AIR["fyaw_r"])],
        "fyaw_l": [(0, AIR["fyaw_l"]), (2, 0), (12, 0), (18, AIR["fyaw_l"])],
    },
    # the fire air hit (Flare Kick): both knees snapped up to the chest, the fists up before the chin, the chin tucked (held);
    # the right leg shot out straight ahead at the hips' height, the left a frame behind it (the soles leading, the toes
    # pulled up), as the trunk lies back against them in one straight diagonal (the head, the hips and the soles), the body
    # rolled a little so the legs clear the trunk from behind, both fists thrown back and up behind the shoulders on long arms
    # (a counter-line to the legs; the left a frame behind); the soles drive on, recoil and are snapped back into the tuck, the
    # head nodding on the impact; opened into the fall, the arms after the legs (Northern Shaolin's double flying kick).
    # hold_s: tucked; strike_s: the right sole out; back_s: opening
    "air_hit_fire": {
        "length": 18, "base": AIR,
        "meta": {"hold_s": 2 / FPS, "strike_s": 4 / FPS, "back_s": 10 / FPS, "hand": "foot_r", "mask": "full", "root": "place",
                 "legs_always": 1.0},
        "root": [(0, AIR["root"]), (2, (0.0, 0.04, 0.0)), (4, (0.0, -0.02, -0.06)), (6, (0.0, -0.03, -0.08)), (9, (0.0, 0.02, -0.02)),
                 (18, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, 12), (3, -4), (4, -28), (5, -36), (6, -38), (7, -36), (8, -18), (10, -2), (13, 4),
                 (18, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, 18), (3, 6), (4, -10), (5, -15), (6, -16), (7, -15), (8, -4), (10, 8), (13, 8),
                  (18, AIR["chest"])],
        "head": [(0, AIR["head"]), (2, 14), (3, 18), (4, 22), (5, 28), (6, 26), (8, 22), (11, 12), (18, AIR["head"])],
        "roll": [(0, AIR["roll"]), (3, 0.0), (4, 5.0), (5, 9.0), (7, 9.0), (9, 4.0), (12, 0.0), (18, AIR["roll"])],
        "clav_r": [(0, AIR["clav_r"]), (2, (14, 4)), (4, (-14, -6)), (7, (-12, -6)), (11, (2, -6)), (18, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (14, 4)), (5, (-14, -6)), (8, (-12, -6)), (12, (2, -6)), (18, AIR["clav_l"])],
        "hand_r": [(0, AR), (2, (-0.13, 1.28, 0.3)), (3, (-0.26, 1.12, 0.04)), (4, (-0.38, 1.24, -0.62)), (5, (-0.43, 1.33, -0.76)),
                   (7, (-0.42, 1.32, -0.74)), (9, (-0.4, 1.12, -0.3)), (11, (-0.42, 1.04, -0.06)), (14, (-0.56, 1.16, 0.08)), (18, AR)],
        "hand_l": [(0, AL), (2, (0.13, 1.27, 0.31)), (3, (0.2, 1.18, 0.16)), (4, (0.28, 1.08, -0.1)), (5, (0.38, 1.24, -0.62)),
                   (6, (0.4, 1.31, -0.72)), (7, (0.4, 1.31, -0.71)), (8, (0.35, 1.26, -0.6)), (10, (0.41, 1.1, -0.28)), (12, (0.43, 1.06, -0.05)),
                   (15, (0.57, 1.24, 0.08)), (18, AL)],
        "face_r": [(0, "balance"), (2, "fist_guard"), (4, "fist_flung"), (8, "fist_flung"), (14, "balance"), (18, "balance")],
        "face_l": [(0, "balance"), (2, "fist_guard"), (3, "fist_guard"), (5, "fist_flung"), (9, "fist_flung"), (15, "balance"),
                   (18, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (2, (-0.5, -1.0, 0.0)), (4, (-0.6, -0.6, 0.4)), (9, (-0.6, -0.6, 0.4)), (18, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (2, (0.5, -1.0, 0.0)), (5, (0.6, -0.6, 0.4)), (10, (0.6, -0.6, 0.4)), (18, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (2, 1.0), (10, 1.0), (14, 0.3), (18, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (2, 1.0), (11, 1.0), (15, 0.3), (18, AIR["grip_l"])],
        # (the right leg shot out at f4 and the left at f5, each driven on, recoiled and snapped back into the tuck, let down)
        "foot_r": [(0, AFR), (2, (-0.1, 0.66, 0.2)), (3, (-0.1, 0.72, 0.38)), (4, _heel_key("r", (-0.1, 0.79, 0.66), -30.0)),
                   (5, _heel_key("r", (-0.1, 0.81, 0.71), -32.0)), (6, _heel_key("r", (-0.1, 0.82, 0.73), -32.0)),

                   (7, _heel_key("r", (-0.1, 0.81, 0.68), -30.0)), (8, (-0.1, 0.68, 0.36)), (10, (-0.11, 0.6, 0.24)),
                   (13, (-0.13, 0.45, 0.24)), (18, AFR)],
        "foot_l": [(0, AFL), (2, (0.1, 0.65, 0.18)), (3, (0.1, 0.68, 0.24)), (4, (0.1, 0.72, 0.42)),
                   (5, _heel_key("l", (0.1, 0.78, 0.67), -30.0)), (6, _heel_key("l", (0.1, 0.8, 0.71), -32.0)),
                   (7, _heel_key("l", (0.1, 0.81, 0.725), -32.0)),
 (8, _heel_key("l", (0.1, 0.8, 0.66), -28.0)),
                   (9, (0.1, 0.68, 0.38)), (11, (0.11, 0.58, 0.2)), (14, (0.13, 0.42, 0.02)), (18, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (2, 40), (3, 0), (4, -30), (6, -32), (7, -30), (8, 10), (10, 35), (18, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (2, 40), (4, 0), (5, -30), (7, -32), (8, -28), (9, 10), (11, 35), (18, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (3, 0), (8, 0), (18, AIR["fyaw_r"])],
        "fyaw_l": [(0, AIR["fyaw_l"]), (3, 0), (9, 0), (18, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (2, (-0.1, 0.6, 1.0)), (4, (-0.1, 1.0, 0.2)), (7, (-0.1, 1.0, 0.2)), (8, (-0.1, 0.6, 1.0)),
                   (18, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (2, (0.1, 0.6, 1.0)), (5, (0.1, 1.0, 0.2)), (8, (0.1, 1.0, 0.2)), (9, (0.1, 0.6, 1.0)),
                   (18, AIR["knee_l"])],
    },
    # the air air hit (Whirl; and its twin): the arms wrapped round the body to the right (the right palm by the left shoulder,
    # the left by the right hip), the waist wrung hard and the knees tucked together (held two frames); unwound into one
    # whole turn to the left on the spot: the right palm leads at the head's height pointing in to the turn's middle with the
    # left palm guarding under the right elbow (the strike: the leading palm through ahead), then both flung out long and open
    # (the right high, the left low: a slanted blade), the hands dragging behind the turn and overshooting as it stops, the
    # feet flaring out behind it and tucking back; the head held on the mark as the body turns away, then snapped round to
    # spot it (Baguazhang's turning eye); the arms float down into the fall's balance as the turn settles (Baguazhang's palm
    # change).  hold_s: wound; strike_s: the leading palm through ahead; back_s: settling
    "air_hit_air": {
        "length": 20, "base": AIR, "mirror": True, "twin_ends": True,
        "meta": {"hold_s": 2 / FPS, "strike_s": 4 / FPS, "back_s": 12 / FPS, "hand": "both", "mask": "full", "root": "place",
                 "legs_always": 1.0, "twin_ends": 1.0},
        "spin": [(0, 0), (1, -16), (2, -32), (3, -36), (4, 30), (5, 92), (6, 150), (7, 205), (8, 252), (9, 290), (10, 320),
                 (11, 342), (12, 356), (13, 364), (15, 362), (17, 360), (20, 360)],
        "look": [(0, 0), (2, 39), (3, 44), (4, -28), (5, -72), (6, -67), (7, -69), (8, -15), (9, 50), (10, 40), (11, 18), (12, 4),
                 (13, -4), (15, -2), (20, 0)],
        "root": [(0, AIR["root"]), (2, (0.0, -0.02, 0.0)), (5, (0.0, 0.07, 0.0)), (9, (0.0, 0.09, 0.0)), (13, (0.0, 0.05, 0.0)),
                 (20, AIR["root"])],
        "hips": [(0, AIR["hips"]), (2, 12), (3, 12), (4, 0), (6, -4), (10, -2), (14, 3), (20, AIR["hips"])],
        "chest": [(0, AIR["chest"]), (2, 14), (3, 14), (4, -2), (6, -6), (10, -4), (14, 2), (20, AIR["chest"])],
        "head": [(0, AIR["head"]), (2, 8), (4, 2), (7, 0), (11, 2), (15, 5), (20, AIR["head"])],
        "twist": [(0, 0), (2, -34), (3, -38), (4, -8), (5, 10), (6, 16), (8, 12), (11, 6), (14, 2), (20, 0)],
        # (leant into the turn like a top: the right side up as the right arm leads round)
        "roll": [(0, AIR["roll"]), (2, 4), (4, -6), (5, -9), (9, -9), (12, -5), (15, -2), (20, AIR["roll"])],
        "side": [(0, 0), (2, 5), (5, -6), (8, -5), (12, -2), (20, 0)],
        "clav_r": [(0, AIR["clav_r"]), (2, (16, 2)), (3, (16, 2)), (4, (4, -10)), (5, (-4, -16)), (11, (-4, -16)), (14, (0, -10)),
                   (20, AIR["clav_r"])],
        "clav_l": [(0, AIR["clav_l"]), (2, (-8, 6)), (3, (-8, 6)), (4, (6, 0)), (6, (-6, -6)), (11, (-6, -6)), (14, (0, -10)),
                   (20, AIR["clav_l"])],
        # (the arms: wrapped and held, the right palm leading at the head's height with the left under its elbow, then flung
        # out long on a slant, dragging behind the turn (AIR_DRAG) and overshooting as it stops, floated down into the balance)
        "hand_r": [(0, AR), (1, (-0.36, 1.24, 0.28)), (2, (0.1, 1.32, 0.2)), (3, (0.08, 1.33, 0.24)), (4, (-0.3, 1.56, 0.36)),
                   (5, (-0.46, 1.58, 0.2)), (6, (-0.52, 1.57, 0.06)), (11, (-0.52, 1.57, 0.06)), (13, (-0.55, 1.5, 0.08)),
                   (15, (-0.6, 1.4, 0.1)), (20, AR)],
        "hand_l": [(0, AL), (1, (0.36, 1.12, 0.24)), (2, (-0.16, 0.96, 0.22)), (3, (-0.12, 1.0, 0.26)), (4, (-0.16, 1.16, 0.3)),
                   (5, (0.3, 1.0, 0.22)), (6, (0.48, 1.02, 0.03)), (11, (0.48, 1.02, 0.02)), (13, (0.52, 1.08, 0.04)),
                   (16, (0.6, 1.24, 0.08)), (20, AL)],
        "face_r": [(0, "balance"), (2, "blade_wrap"), (3, "blade_wrap"), (4, "bagua_lead"), (6, "blade_out"), (11, "blade_out"),
                   (16, "balance"), (20, "balance")],
        "face_l": [(0, "balance"), (2, ((-0.6, -0.4, 0.7), (-0.75, 0.1, -0.65))), (3, ((-0.6, -0.4, 0.7), (-0.75, 0.1, -0.65))),
                   (4, ((-0.5, 0.6, 0.6), (0.0, 1.0, 0.0))), (6, ((0.8, -0.55, -0.05), (0.0, 0.05, -1.0))),
                   (11, ((0.8, -0.55, -0.05), (0.0, 0.05, -1.0))), (17, "balance"), (20, "balance")],
        "pole_r": [(0, AIR["pole_r"]), (2, (-0.6, -0.4, 0.8)), (4, (-0.7, -0.7, -0.1)), (6, (-0.2, -1.0, -0.3)),
                   (12, (-0.2, -1.0, -0.3)), (20, AIR["pole_r"])],
        "pole_l": [(0, AIR["pole_l"]), (2, (0.8, -0.2, -0.6)), (4, (0.5, -1.0, 0.2)), (6, (0.3, -1.0, 0.0)), (12, (0.3, -1.0, 0.0)),
                   (20, AIR["pole_l"])],
        "grip_r": [(0, AIR["grip_r"]), (2, 0.0), (4, -0.6), (12, -0.6), (16, 0.0), (20, AIR["grip_r"])],
        "grip_l": [(0, AIR["grip_l"]), (2, 0.0), (4, -0.4), (6, -0.6), (12, -0.6), (17, 0.0), (20, AIR["grip_l"])],
        # (the legs: tucked together under him, the toes pointed, then flared out behind the turn as it whips and tucked
        # back in as it settles)
        "foot_r": [(0, AFR), (2, (-0.09, 0.5, 0.12)), (4, (-0.07, 0.46, 0.02)), (6, (-0.09, 0.45, 0.07)), (8, (-0.1, 0.44, 0.1)),
                   (9, (-0.1, 0.44, 0.09)), (13, (-0.08, 0.42, 0.06)), (16, (-0.11, 0.36, 0.12)), (20, AFR)],
        "foot_l": [(0, AFL), (2, (0.09, 0.48, 0.06)), (4, (0.07, 0.43, -0.06)), (6, (0.09, 0.42, -0.11)), (8, (0.1, 0.42, -0.15)),
                   (9, (0.1, 0.42, -0.15)), (13, (0.08, 0.42, -0.07)), (16, (0.11, 0.37, -0.14)), (20, AFL)],
        "heel_r": [(0, AIR["heel_r"]), (2, 45), (4, 55), (10, 55), (14, 40), (20, AIR["heel_r"])],
        "heel_l": [(0, AIR["heel_l"]), (2, 45), (4, 55), (10, 55), (15, 40), (20, AIR["heel_l"])],
        "fyaw_r": [(0, AIR["fyaw_r"]), (4, 0), (12, 0), (20, AIR["fyaw_r"])],
        "fyaw_l": [(0, AIR["fyaw_l"]), (4, 0), (12, 0), (20, AIR["fyaw_l"])],
        "knee_r": [(0, AIR["knee_r"]), (2, (-0.05, 0.3, 1.0)), (12, (-0.05, 0.3, 1.0)), (20, AIR["knee_r"])],
        "knee_l": [(0, AIR["knee_l"]), (2, (0.05, 0.2, 1.0)), (12, (0.05, 0.2, 1.0)), (20, AIR["knee_l"])],
    },
}
## The air hit's hands dragging behind the turn and overshooting as it stops (deg about the vertical, - behind the turn, at
## each frame; both hands, the left a frame later), applied to the typed keys above.
AIR_DRAG = [(4, 0.0), (5, -8.0), (6, -14.0), (7, -18.0), (8, -16.0), (9, -12.0), (10, -6.0), (11, 0.0), (12, 7.0), (13, 5.0),
            (15, 0.0)]


def _dragged(keys, late=0):
    out = []
    for fr, v in keys:
        d = _kv(AIR_DRAG, fr - late) if 4 + late <= fr <= 15 + late else 0.0
        out.append((fr, _r3(_yawv(v, d)) if d else v))
    return out


SET8["air_hit_air"]["hand_r"] = _dragged([(fr, v) for fr, v in SET8["air_hit_air"]["hand_r"] if fr not in (11,)]
                                         + [(7, (-0.52, 1.57, 0.06)), (9, (-0.52, 1.57, 0.06)), (11, (-0.52, 1.57, 0.06)),
                                            (12, (-0.54, 1.54, 0.07))])
SET8["air_hit_air"]["hand_r"].sort(key=lambda kv: kv[0])
SET8["air_hit_air"]["hand_l"] = _dragged(sorted([(fr, v) for fr, v in SET8["air_hit_air"]["hand_l"] if fr not in (11,)]
                                                + [(8, (0.48, 1.02, 0.03)), (10, (0.48, 1.02, 0.02)), (12, (0.5, 1.04, 0.03))],

                                                key=lambda kv: kv[0]), late=1)
CLIPS.update(SET8)


## The slack an arm or a leg keeps short of straight at its keys (m): less is flagged by --fit (a limb locked straight by the IK
## reads stiff; the polish pulls such keys in).
SLACK = 0.015
## The striking limb's slack at strike_s that --fit suggests (m): out nearly straight, not locked.
STRIKE_SLACK = 0.03


## The joints whose bend --angles prints (shoulder, elbow, wrist; hip, knee, ankle) and the last bake's rows.
ARM_J = ("shoulder", "elbow", "wrist")
LEG_J = ("upper_leg", "knee", "ankle")
ANGLES = []
## The joints --points prints each frame (the character's frame, m) with the body's lowest surface (SURF), for placing the
## edge clips' hands, elbows, knees and toes on the lip, the deck and the face.
PT_J = ("heada", "neck", "spinec", "r_shoulder", "l_shoulder", "r_elbow", "l_elbow", "r_palm", "l_palm", "pelvis", "r_knee", "l_knee",
        "r_ankle", "l_ankle", "r_ball", "l_ball", "r_upper_leg", "l_upper_leg")
POINTS = []


def bake(clip, fit=None):
    """The clip's frames; `fit` (a list) collects the frames where a limb is within SLACK of straight or past it: (frame, limb,
    slack, the channel's place pulled in to SLACK)."""
    frames, roots, report = [], [], []
    ANGLES.clear()
    POINTS.clear()
    names = keyed()
    legs_only = clip.get("bones") == "legs"
    if legs_only:
        # a legs-only layer (the air-legs under a cast): only the legs' bones keyed, their rotations each in its parent's frame,
        # so the legs keep their tuck under whatever the hips and the upper body are doing; no root place
        names = [nm for nm in names if any(nm == s + "_" + b for s in "lr" for b in LEG)]
    # (a clip with "substeps": n is baked n times a frame (meta fps FPS * n in the json): a planted hand whose arm moves fast
    # holds its place between the keys too, the game interpolating the bones between them)
    sub = int(clip.get("substeps", 1))
    for fi in range(clip["length"] * sub + 1):
        f = fi / sub if sub > 1 else fi
        rigkit.MISS.clear()
        rots, root = pose(clip, f)
        frames.append({nm: [rots[nm].x, rots[nm].y, rots[nm].z, rots[nm].w] for nm in names})
        if not legs_only:
            roots.append([root.x, root.y, root.z])
        P, G = SK.fk(rots, root)
        # (each elbow's and knee's bend in degrees, 0 straight, for --angles)
        low = surface_low(P)
        hp = hat_points(P, G)
        hat_far = (round(max(v.z for v in hp), 3), round(min(min((P[s + "_palm"] - v).length for v in hp) for s in "rl"), 3)) \
            if hp else (9.0, 9.0)
        POINTS.append((f, {j: tuple(round(x, 3) for x in (head_middle(P) if j == "heada" else P[j])) for j in PT_J},
                       (round(low[0], 3), low[1]), round(hat_low(P, G), 3), hat_far))
        ANGLES.append((f, [round(math.degrees((P[s + "_" + b] - P[s + "_" + a]).angle(P[s + "_" + c] - P[s + "_" + b], 0.0)))
                           for s, (a, b, c) in (("r", ARM_J), ("l", ARM_J), ("r", LEG_J), ("l", LEG_J))]))
        report.append((f, [round(x, 3) for x in P["r_palm"]], [round(x, 3) for x in P["l_palm"]], round(P["pelvis"].y, 3),
                       [round(x, 3) for x in P["r_ankle"]], [round(x, 3) for x in P["l_ankle"]],
                       round(max([d for _, d in rigkit.MISS] or [0.0]), 3)))
        if fit is not None:
            for limb, (base, target, reach, place) in DIAG.items():
                d = (target - base).length
                slack = reach - d
                if slack < SLACK:
                    pulled = place - (target - base).normalized() * (SLACK - slack)
                    fit.append((f, limb, round(slack, 3), tuple(round(x, 3) for x in pulled)))
                elif f == round(clip["meta"].get("strike_s", -1.0) * FPS) and limb[0] in str(clip["meta"].get("hand", "")) \
                        .replace("both", "lr").replace("foot_", ""):
                    # the striking limb at the strike: how far short of straight (a punch or a palm reads weak bent), and
                    # its place carried out to STRIKE_SLACK along the same line
                    if (limb.endswith("arm") and "foot" not in str(clip["meta"].get("hand"))) or \
                            (limb.endswith("leg") and "foot" in str(clip["meta"].get("hand"))):
                        out = place + (target - base).normalized() * (slack - STRIKE_SLACK)
                        fit.append((f, limb + " STRIKE", round(slack, 3), tuple(round(x, 3) for x in out)))
    return frames, roots, report


# ---------------------------------------------------------------- the .blend to open and refine
def keep_blend(path, baked):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB, bone_heuristic="FORTUNE")
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    rm = rigmap.RigMap(arm)
    scn = bpy.context.scene
    scn.render.fps = FPS
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    arm.animation_data_create()
    C = Matrix.Rotation(math.pi / 2, 3, "X")
    for name, (frames, roots) in baked.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        for fi, rots in enumerate(frames):
            for bn, q in rots.items():
                pb = arm.pose.bones.get(bn)
                if pb is None or bn not in rm.B:
                    continue
                pb.rotation_quaternion = rm.to_basis(bn, q)
                pb.keyframe_insert("rotation_quaternion", frame=fi)
            rb = arm.pose.bones.get("root")
            if rb is not None:
                h = C @ Vector(roots[fi])
                rb.location = rb.bone.matrix_local.to_3x3().inverted() @ (h - rb.bone.head_local)
                rb.keyframe_insert("location", frame=fi)
    arm.animation_data.action = bpy.data.actions[next(iter(baked))]
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(path))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--clips", default="")
    ap.add_argument("--glb", default=None)
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--fit", action="store_true", help="list the frames where a limb is (nearly) locked straight")
    ap.add_argument("--angles", action="store_true", help="print each frame's elbow and knee bends (deg, 0 straight)")
    ap.add_argument("--points", action="store_true", help="print each frame's key joints and the lowest surface (m)")
    a = ap.parse_args(argv)
    only = [c for c in a.clips.split(",") if c]
    out = {"fps": FPS, "clips": {}, "names": {},
           "about": "tools/anim_author/blender/bend_clips.py: our own ring-sport casts and knocks, key poses IK-solved on Actor_B's "
                    "rig in Blender from the rig's rest pose (no library clip read)"}
    baked = {}
    print("BEND rest r_shoulder %s r_palm %s  hand axes r %s" % ([round(x, 3) for x in P_REST["r_shoulder"]],
                                                                  [round(x, 3) for x in P_REST["r_palm"]],
                                                                  [[round(x, 3) for x in v] for v in HAND_LOCAL["r"]]))
    if a.fit:
        for j in ("r_shoulder", "r_elbow", "r_wrist", "r_palm", "r_upper_leg", "r_knee", "r_ankle", "r_ball", "pelvis", "neck",
                  "heada"):
            print("BEND rest %s %s" % (j, [round(x, 3) for x in P_REST[j]]))
        P0, _ = SK.fk(*pose({"length": 1}, 0))
        for j in ("r_shoulder", "r_palm", "r_upper_leg", "r_ankle", "pelvis", "heada"):
            print("BEND stand %s %s" % (j, [round(x, 3) for x in P0[j]]))
    for name, clip in all_clips().items():
        if only and name not in only and name.removesuffix("_l") not in only:
            continue
        fit = [] if a.fit else None
        frames, roots, report = bake(clip, fit)
        meta = dict(clip["meta"])
        meta["length_frames"] = clip["length"]
        # the worst miss of the two-bone IK over the frames (m: a target out of a limb's reach), kept with the clip so the
        # library can be checked against it (tests/bending/test_bend_clips.gd: at most 5 mm)
        meta["ik_miss_m"] = round(max(r[-1] for r in report), 4)
        if clip.get("loop"):
            meta["loop"] = "linear"
        out["clips"][name] = {"frames": frames, "root": roots, "meta": meta}
        if int(clip.get("substeps", 1)) > 1:
            out["clips"][name]["fps"] = FPS * int(clip["substeps"])
        out["names"][name] = game_name(name)
        baked[name] = (frames, roots)
        worst = max(r[-1] for r in report)
        print("BEND %s -> %s: %d frames, worst IK miss %.3f m" % (name, game_name(name), len(frames), worst))
        for fr in fit or []:
            print("   FIT %s f%02d %s slack %.3f -> %s" % (name, fr[0], fr[1], fr[2], fr[3]))
        if a.angles:
            for fr, ang in ANGLES:
                print("   ANG %s f%02d elbow r %3d l %3d  knee r %3d l %3d" % (name, fr, *ang))
        if a.points:
            for fr, pts, low, hat, far in POINTS:
                print("   PTS %s f%02d low %.3f (%s) " % (name, fr, low[0], low[1]) +
                      " ".join("%s=%s" % (j, list(v)) for j, v in pts.items()) + " hat=%.3f hatz=%.3f palmhat=%.3f" % (hat, *far))
        if not a.quiet:
            for r in report:
                print("   f%02d  r_palm %s  l_palm %s  pelvis %.3f  r_ankle %s  l_ankle %s  miss %.3f" % r)
    json.dump(out, open(a.out, "w"))
    print("BEND baked %d clips -> %s" % (len(out["clips"]), a.out))
    if a.blend:
        keep_blend(a.blend, baked)
        print("BEND blend -> %s" % a.blend)


if __name__ == "__main__":
    main()
