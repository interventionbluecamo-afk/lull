# Runtime captures — October 6, 2026

These are actual iPhone 17e simulator captures, not generated art or completed playtest evidence.

- `sorter-iphone-portrait.png`: the redesigned sorter at rest, before the subsequently confirmed correct circle drag.
- `window-live-blur-blank.png`: the failed Window rendering with the original live Core Image beam filter enabled.
- `window-blur-diagnostic.png`: the same activity rendered correctly with that filter disabled for a controlled DEBUG comparison. A dial tap subsequently advanced day to sunset visibly.

The production replacement uses a cached feathered beam texture; its final simulator build passed. The Mac locked before that replacement could be checked through the computer-control window. See the handoff for the exact distinction between rendering, a confirmed gesture, and remaining tests.
