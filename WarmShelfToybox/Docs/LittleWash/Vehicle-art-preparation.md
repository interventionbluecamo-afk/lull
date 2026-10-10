# Little Wash vehicle art preparation

The delivered originals are preserved unchanged in `Docs/Art/LittleWash/Source/`.
`Vehicle-art-source.json` maps each original generation filename to its Git-preserved
source and records the rectangular source crop, windshield measurements and wheel arches.
`Vehicle-rigs.json` records the transformed fractions, body placement and original SHA-256.

Run from `WarmShelfToybox` with Python 3 and Pillow:

```sh
python3 Tools/prepare_wash_vehicles.py --contact-sheet /tmp/little-wash-vehicles-contact.png
python3 Tools/verify_wash.py
```

Preparation uses only a rectangular crop, proportional Lanczos resampling and transparent
padding. It does not remove backgrounds, recolour, repaint or erase alpha. The native felt
fibres and alpha remain; very faint edge fibres are therefore also retained. The diagnostic
contact sheet composites onto cream and draws placeholder wheels and a face footprint. That
background and those overlays never enter a shipped PNG.

All consumer vehicle images are RGBA, 1600 × 1000. The padded body region is 1280 pixels wide.
The separate wheel rigs share a bottom at y=880, leaving 12% of the canvas below them. The body
may end above that line because the separate wheels extend below the open arches. Do not
trim the images at runtime: the canvas padding is part of the measured coordinate system.

Face and wheel centres use fractional canvas coordinates, x from the left and y from the top.
Radii are fractions of canvas **height**, so horizontal radii must be divided by the canvas
aspect ratio when expressed as x fractions. The face footprint has clearance within the
plain window; the window stays faceless in the source PNG.

Wheel arch measurements fit a circle to the inner transparent opening (alpha threshold 64),
using paired boundary points through the curved upper arch. The hand-recorded fit is retained
in the manifest; the full vehicle art is visually checked with the contact sheet. Separate
wheel sprites slightly overlap the opening (1.08× the inner-arch fit) and should render behind
the vehicle body. Wheel y coordinates are adjusted to the common ground line; tractor wheel
sizes remain different. This is an intentional rendering adjustment, not a claim that the
handmade source curves form mathematically exact circles.

The preparation script updates the compiled `WashVehicleRig` table only with all six
vehicles available. `--allow-missing` is an intermediate registration aid and leaves the
Swift table untouched. The verifier checks production rigs against committed measurement
records and the shared wheel baseline, besides the cleaning and shuffle behavior.

Visual rig review and interaction on the device remain the founder's testing. The contact
sheet is asset QA and does not establish game performance or a device pass.
