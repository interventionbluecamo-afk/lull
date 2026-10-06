# Expression Principles (a Lull law)

> Everything a child touches in Lull is **alive**. It notices them, and it feels things.

This is not decoration. It is the core reason a 2–4 year-old returns: the world responds to
them like a creature would, not like a button does. Treat this as a hard rule for every toy.

## The law

**Any object a child can act on must express emotion across its whole lifecycle**, not just at
the moment of success. The minimum vocabulary:

| Beat | What the object does |
| --- | --- |
| **Idle / resting** | Breathes; occasionally blinks, yawns, or shifts — it's alive even when ignored. |
| **Noticed (touch-down)** | Reacts within one frame — wakes, looks up, perks. "The world noticed me." |
| **Carried / moved** | Looks the way it's going; leans into motion. |
| **In peril (falling/fast)** | Widens, gasps — a delighted *whee*, never fear. |
| **Resolved (lands/settles)** | Squashes, beams, blinks happy; cheeks. |
| **Mishap (topple/decline)** | Dizzy, surprised, sheepish — **never a failure**, always endearing. |
| **Triumph (signature beat)** | Glows, smiles wide, a warm sound. Rare and earned. |

## Rules of taste

- **Emotion reads at a glance** — eyes + mouth + squash. No text, no numbers.
- **A mishap is comedy, not punishment.** Toppling stones go dizzy and giggle. Wrong food gets a
  gentle "no thanks." Nothing is ever lost, broken, or scored.
- **One clear beat at a time.** Don't stack five reactions; pick the dominant feeling.
- **Calm amplitude.** Expressions are soft and quick (0.1–0.3s), never frantic. This is a lullaby,
  not a cartoon.
- **Idle life is mandatory.** If the child sets the phone down, the toys keep quietly living.

## Reference implementation

`StackPieceNode` is the canonical example. It sleeps in the pile (closed lids, breathing,
occasional yawns), gasps awake when lifted (`beginHold` → surprised → happy), tracks the finger
(`lookToward`), widens as it falls (`reactFalling`), beams and squashes on landing
(`reactLanded`), goes dizzy when it tumbles (`dizzy`), and the top stone of a tall tower truly
*wakes* (`wake`). `StackScene` drives these on the matching physics beats.

`CharacterNode` (Feed) is the other reference: mood-driven mouths, blinks, personality ticks.

## Applying the law to a new toy

Before a toy ships, check every row of the table above has an answer. If an object can be touched
but only reacts on success, it is not finished.
