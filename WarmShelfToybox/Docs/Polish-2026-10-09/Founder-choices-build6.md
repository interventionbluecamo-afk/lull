# Founder choices after the build 5 review

October 9, 2026. Two decisions are yours: which new toy replaces Stack, and what to add to the
Meadow. Everything else from your build 5 review is already done for build 1.0 (6). The test guide is
at the end.

## 1. A completely new toy to replace Stack (pick one)

Stack is one of the three free toys, so its replacement is the first impression for every family
that hasn't paid yet. It has to delight a 2-year-old in five seconds and still hold a 6-year-old.
It also has to feel like nothing else on the shelf. The current toys cover popping (Bubbles),
feeding (Feed), shape sorting (Sleepy Box), a room through the day (Window), colours in a row
(Drop Dots), dress-up (Mix-Up), music (Hum) and wandering (Meadow).

### Option A: Little Pond (my recommendation)

**What the child does.** A felt pond with lily pads and slow, round felt fish. The child holds a
finger in the water and a little wooden rod's magnet bobber follows it. A fish swims up and
nibbles: the bobber dips and the fish wiggles. The child lifts, and the fish comes up smiling,
stuck to the magnet the way a real magnetic fishing toy works. No hooks, and nothing gets hurt.
The child drops it into a felt bucket on the bank. Five fish fill the bucket. Tip it over and they
all splash back into the pond with a happy jump, ready to play again.

**Why it fits.** Magnetic fishing is one of the most loved real toddler toys. It's hand–eye
practice with a built-in pause: you wait for the nibble. Colours and counting happen without
asking ("the blue one", one, two, three in the bucket). Letting the fish go is care for living
things. Water is calm by nature: ripples, drifting pads, a frog who blinks.

**Depth so it doesn't get boring.**
- Five fish colours, plus a rare golden fish.
- Now and then a surprise comes up instead of a fish: a duckling, a turtle, a boot with a snail
  in it.
- Rain rings on the water some visits.
- Tap the frog and he catches a fly.
- At dusk the fish glow faintly.

**Layout.** In landscape the pond is wide with the bucket on the bank. In portrait the pond fills
the lower two-thirds with the bucket at the side. It works on iPhone and iPad.

**Sound.** The kit's bubble sounds are made for water. A soft splash on release, the bobber's
"plip". Nothing else.

**Art to generate (about 10 images).** Pond backdrop, five fish plus a golden one, one surprise
(duckling), the rod and bobber, the bucket, lily pads, the frog.

**Effort.** About 2–3 days to polish. Lowest risk of the three.

### Option B: Little Town (your son's pick, I suspect)

**What the child does.** A felt town mat with soft roads. There are three helpers to drive, each
with one small story:
- The **fire truck** raises its ladder to bring a cat down from a tree. There is no fire, ever.
- The **police car** stops traffic so a mother duck and ducklings can cross.
- The **bus** picks up animal friends at the stop and drops them at the park.

Vehicles follow the road under the child's finger, so steering never fails. They park in a garage
that closes with a little wave.

**Why it fits.** Vehicles and community helpers are a top toddler interest, and your son loved the
robot, police officer and firefighter in Mix-Up. Each story is a small act of helping, which is a
Montessori value. Cause and effect is clear.

**Calm.** Soft engine hums. The "wee-woo" is the gentle hummed one from Mix-Up's firefighter,
never a siren.

**Art to generate (about 14 images).** Town mat, three vehicles, tree with cat, duck family, bus
stop, park, garage, four animal passengers.

**Effort.** About 4 days. Road snapping and three mini-stories make it the most work.

### Option C: Little Garden

**What the child does.** The child pats soil to make a hole, drops in a seed, waters it with a
tipping can, and watches it sprout and grow in a few seconds. Then the child pulls the carrot out
of the ground with a satisfying soft "pop" and puts it in a basket. Five seeds to try: carrot,
radish, strawberry, sunflower, and a rare pumpkin that grows huge. A worm sometimes peeks out.

**Why it fits.** It's practical life, caring for plants, with a real sequence (seed → water → sun →
grow → pick). It teaches gentle patience at toddler speed. Harvested vegetables could even appear
on Feed's counter, a lovely link between toys.

**Overlap.** It shares flowers and nature with the Meadow.

**Art to generate (about 22 images).** Each plant needs growth stages, so this has the most art.

**Effort.** About 3–4 days.

**My recommendation: A, Little Pond.** It is the calmest, the most immediate for a 2-year-old, the
most unlike the other eight toys, and the quickest to make excellent. It's the right free toy.
Little Town is a strong later toy, maybe a tenth one or an update, built around your son's
favourites.

When you choose, the App Store description line for Stack, the screenshot spec
(`Docs/AppStore/screenshots.json`) and the shelf card art need updating too.

## 2. The Meadow

### What was the "random tone"?

You were right about the wings. When nobody touched the ladybug for about 5 seconds, she gave a
little spin and wing flutter to say "lead me". That played a note, and it repeated every 7.5
seconds on its own. Three other things added to it:
- While she walked, a random glockenspiel note played every 0.4 seconds as she painted spring.
- Every flower that opened played a note.
- Random synthesized birds chirped in the background.

**All four are gone in build 6.** The Meadow now sounds only when something meaningful happens:
- a sleeping friend wakes
- a patch of spring blooms
- full spring
- the first frost

Those use the new soft notes.

### Ideas to make the Meadow more of a game (my picks first)

1. **Find the little ones (recommended).** Five baby ladybugs hide around the meadow: under a
   leaf, behind a mushroom, inside a flower. When she walks near one, it peeks out and joins her,
   following in a little line behind her. Lead them all home to a leaf house, where they tuck in
   and the house glows. Next visit, they hide in new places.
   - It gives the Meadow a gentle goal with no way to fail.
   - Toddlers adore the parade.
   - Counting to five happens on its own.
   - The visit has an ending.
2. **Evening and fireflies (pairs with 1).** When the meadow is in full spring, dusk falls,
   fireflies come out, her trail glows, and the little ones fall asleep in the leaf house. It's a
   natural, calm end to the visit, in keeping with Lull's wind-down.
3. **A caterpillar to look after.** A caterpillar on a leaf eats the leaves she leads it to.
   Across visits it becomes a cocoon, then a butterfly that flies with her. A small story that
   pays off over days.
4. **Seasons.** As the meadow fills, spring could turn to summer (sunflowers, bees), then autumn
   (leaves to kick through), then winter (snow she leaves tracks in).

The little planet (globe) idea stays parked. ChatGPT's notes in `Meadow-globe-decision.md` explain
why it risks the painted garden. Ideas 1 and 2 give more for less risk.

**Art for ideas 1 and 2 (about 4 images).** A baby ladybug (one image, tinted), a leaf house in two
states (dark and glowing), and a firefly glow (can be drawn in code).

## 3. Build 1.0 (6): what changed and what to check

Everything below is pushed to `claude/modest-bell-cjarqm`. It was verified on Linux (sound kit,
engine, Drop Dots, Feed, Hum, Mix-Up and the other verifiers pass), but **not yet built for iOS**.
ChatGPT builds it on the Mac. Upload still needs your approval.

### Sound: calm, pleasant, far fewer sounds

**Rules now:**
- Sound answers something meaningful a toy does, never a bare touch.
- Nothing plays on its own.
- Sounds are warm and round, never bright metal or hiss.
- Everything is about 3 dB quieter.
- Tapping the same thing quickly gets softer each time instead of piling up.

**Check:**
- Tapping a toy card, the home button and empty felt: **no sound**, just a felt tap (haptic).
  Going from toy to toy should be silent.
- **Sleepy Box:** picking up, hovering and dragging the drawer are silent. Each shape lands with
  a soft low "thup" and its own gentle note. The four shapes hum back. Treasures roll out on a
  soft falling run.
- **Window:** tapping the sky is silent. The dial, lamp and curtain are softer.
- **Bubbles:** pops sound like **pops** now, smaller ones higher.
- **Meadow:** no random notes.

### Haptics

Every pulse is now strong enough to feel (they were mostly at 6–46% of the faintest style).

**If you still feel nothing,** check iOS Settings → Sounds & Haptics → System Haptics is on, and
the Haptics switch in Lull's grown-up area.

### Drop Dots

Dots come in the four ring colours again. Each visit deals one dot per ring plus three of one
colour.

**Check:**
- Hold a dot over its own colour's hole: the rim warms in that colour.
- Drop it there: the ring glows.
- Stack three of a colour: they glow together with a little tune.

### Feed

**Check:**
- Food stays still on its plates; the wished-for food only swells gently in place.
- After a bite, only that plate refills, in place.
- The counter sits a little lower, so the sprout and the knit-hat kid show their sweaters.

### Wren on the shelf

**Check:** tap him. He wiggles, scoots off the edge, and a moment later peeks in from somewhere
else (bottom middle, bottom right, or hanging upside down from a top corner), looks back at where
you tapped, and dozes. It's silent.

### Window visitors

The balloon now takes turns with a kite on a long string, a bunny-shaped cloud, a paper airplane
that loops, and a faraway V of birds. At night a warm paper lantern rises from the trees.

**Check:** the first visitor comes after about 30 seconds of daytime, then roughly every one to
one and a half minutes.

### Bubbles bird

**Check:** it flies like a small songbird now (flap, glide, flap), instead of squashing.

**Optional:** two extra wing frames would make the flapping real. The prompt is in
`Art-prompts.md`, and the code adopts them automatically.
