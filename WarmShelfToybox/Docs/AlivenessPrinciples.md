# Aliveness Principles

Lull's signature is not a mechanic — it's a feeling: **sleeping things wake because the
child touched them, and settle back to calm afterward.** `StackScene` was the first proof;
this law spreads that grammar to everything. `LullHostNode` (the capstone clay friend) is the
canonical implementation.

## Production interpretation — November 3, 2026

The signature is **quick to notice, slow to settle**. It is a timing and cause-and-effect rule, not a requirement to animate or put a face on every object. Quiet scenery can remain still. A part that visibly invites touch should answer that touch consistently.

- Follow the finger immediately during direct manipulation. Give release a material-specific settle: felt bends, cloth lags from an anchored seam, wood carries weight with very little flex, water spreads outward.
- Prefer one readable response with a complete ending. One reaction per object at a time; repeated touches update it instead of queuing performances.
- Give a small discovery a cause the child can understand: a brush bends where rubbed, a friend notices food approaching, a bubble’s visible passenger flies free when popped.
- Keep discoveries optional. No timer-driven spectacle, attention bait, reward ladder or obligation to tap every decoration. Use sound sparingly; the motion must read when muted.
- Preserve geometry during movement: collars and waists stay joined, shadows stay on the surface, curtain tops stay attached, hands keep holding their tools.
- Reduced Motion uses an immediate state change or a restrained fade. Pause, rotation and backgrounding clear transient gestures and cannot leave an object deformed.
- Judge each addition in the running scene, at normal play size. Check both relevant lighting modes and orientations; source code having an animation does not prove it reads well.

## The Four States
An object chosen to feel alive uses four states:

1. **Rest.** A comfortable resting pose. A creature may occasionally breathe or blink;
   scenery and unused objects can remain still.
2. **Notice.** A quick perk toward the child's touch or approach. ~0.16–0.20s, ease-out.
   Eyes peek open — this is the *waking* beat, the thing a 2-year-old falls in love with.
3. **Respond.** Warm, readable cause-and-effect to the child's action: a smile widening, a
   bob, a bloom. Slow enough for a toddler to read. No confetti, no noise.
4. **Settle.** Return to rest — **slower than the wake** (~0.8–1.2s, ease-in-ease-out).

## The Law of Asymmetry (the most important line)
**Quick to wake, slow to settle.** Notice in ~0.18s; settle over ~1s. Symmetric timing reads
as twitchy and mechanical; the slow exhale back to calm is what makes Lull *breathe*. Most
kids' apps nail the wake and forget the settle. **The settle is the brand.**

## Child experience constraints
No timed challenges, competitive scores or punitive failure. Big forgiving targets.
The grown-up play timer is a separate family setting. The child's action must
create real, visible cause-and-effect. The deepest loop is autonomy: *I touched it, and the
world answered.*

## Host discipline (the capstone friend)
The host is the soul, not a mascot. It appears only at the **edges** and never interrupts:
- sleeps on the shelf when idle
- breathes gently during onboarding
- a small clay stamp/mark in parent-only areas
- peeks **after** a child-made beautiful moment — never before, never on a timer, never as a
  reward pop-up

The moment it narrates, blocks a toy, or performs for attention, it becomes a coach and the
spell breaks. Keep it quiet.

## Material law (so it always looks authored)
Handmade clay, felt, linen, soft wood, warm paper. Dimples, compressed edges, a cream
highlight, imperfect hand-shaped silhouettes. Never flat-vector kid-app energy, plastic
gloss, neon, or stock educational graphics. See `Brand.md` and `WarmShelfPalette`.

## Per-object checklist (use when building or reviewing any alive thing)
- [ ] Does it live *before* the child touches it? (rest)
- [ ] Does it wake *toward* the child — fast, eyes opening? (notice)
- [ ] Is the response real cause-and-effect, slow enough to read? (respond)
- [ ] Does it exhale back to calm *more slowly than it woke*? (settle)
- [ ] Big target, no fail, no timer, no score? (Montessori)
