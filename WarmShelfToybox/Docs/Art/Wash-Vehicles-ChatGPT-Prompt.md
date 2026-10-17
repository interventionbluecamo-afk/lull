You are making art for Lull, a calm, premium felt-and-wood toy app for children aged 2 to 6. I need SEVEN images for the "Little Wash" toy, where a child washes muddy vehicles. Please make all seven, one after another, without waiting for me between them. If you stop, I'll type "next".

=== STYLE (applies to every image) ===
Handmade needle-felt toy for a calm, premium children's app (ages 2–6), matching an existing felt-and-wood toybox: soft wool fibres you can almost feel, gently rounded chunky shapes, stitched seams, warm diffuse light from the upper left, soft sun-faded hand-dyed colours (terracotta, sage, butter, lavender, water-blue, petal, cream), never neon, never glossy plastic. One object, centred, fully visible, camera straight from the side, TRANSPARENT background (PNG with alpha), no drop shadow, no text, no letters, no numbers, no logos.

=== HARD RULES (break any of these and that image must be redone) ===
1. Transparent background. No floor, no shadow, no scenery.
2. Side view, facing RIGHT, the whole vehicle visible with a little empty space around it.
3. NO WHEELS on the trucks. Leave dark felt wheel arches where wheels would go (the app adds spinning wheels).
4. NO FACE. Windows and windshields are plain pale-blue felt panels: no eyes, no mouth, no driver, no pilot (the app draws the face).
5. Clean and new-looking, never muddy (the app adds the mud).
6. Nothing that looks like writing: no letters, numbers, signs, license plates, crosses or symbols.
7. Toy-like and friendly, never realistic or aggressive.

=== THE SEVEN IMAGES (wide landscape canvas for each) ===
1. wash-garbage-truck — A chunky felt garbage truck: sage-green body, a rounded cream back bin with stitched ridges, a small felt step at the back. Dark felt wheel arches, no wheels.
2. wash-mail-truck — A rounded little felt mail truck: butter-yellow and cream body, a sliding side door, a small felt envelope shape on the side with no writing. Dark felt wheel arches, no wheels.
3. wash-camper — A cosy felt camper van: water-blue and cream two-tone body, round windows with tiny felt curtains, a little rooftop luggage rack. Dark felt wheel arches, no wheels.
4. wash-tow-truck — A friendly felt tow truck: petal-pink body, a short wooden boom with a felt hook at the back. Dark felt wheel arches, no wheels.
5. wash-ambulance — A rounded felt ambulance: cream body with a soft petal stripe, a small two-part light on the roof, unlit. No cross symbol, no text. Dark felt wheel arches, no wheels.
6. wash-helicopter — A round, chubby felt helicopter: lavender and cream body, a big rounded bubble window that is a plain pale-blue felt panel (no face, no pilot), a short tail with a small round tail rotor, two cream felt landing skids at the bottom, and a short felt mast on top with NO main rotor blades (they are a separate image).
7. wash-helicopter-rotor — The main rotor of that felt toy helicopter seen straight from the side: one long, thin, soft, rounded cream felt blade bar with stitched edges and a small charcoal felt hub in the middle. Nothing else.

=== AFTER ALL SEVEN ARE MADE: prepare the files with Python ===
Use your Python tool to turn the seven images into app-ready PNGs. For each image:
a) Make sure it has a real transparent background (RGBA, corners fully transparent). If any image has a solid background, regenerate that image with a transparent background first.
b) Trim away the empty transparent border (use the alpha channel, threshold 40).
c) Vehicles 1–5 (the trucks): scale the trimmed vehicle so its width is exactly 1268 px (keep proportions), then paste it onto a new fully transparent 1600 × 1000 canvas, centred left-to-right, with the bottom of the vehicle at y = 770 (so the empty space below is for the app's wheels).
d) Image 6 (helicopter): scale so its width is 1268 px, paste onto a transparent 1600 × 1000 canvas, centred left-to-right, with the bottom of the skids at y = 880.
e) Image 7 (rotor): scale so its width is 1150 px, paste onto a transparent 1200 × 240 canvas, centred both ways.
f) If any vehicle becomes taller than the canvas allows (its top above y = 20), scale it down until its top is at y = 20, keeping the bottom where it should be.
g) Save each as PNG with exactly these names: wash-garbage-truck.png, wash-mail-truck.png, wash-camper.png, wash-tow-truck.png, wash-ambulance.png, wash-helicopter.png, wash-helicopter-rotor.png
h) Print a check table: name, final size, colour mode, and whether all four corners are transparent.
i) Put all seven PNGs in one zip called lull-wash-vehicles.zip and give me the download link.

Finally, show me all seven finished images side by side so I can check them.
