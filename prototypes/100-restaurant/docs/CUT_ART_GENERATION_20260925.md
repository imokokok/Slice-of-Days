# Generated derivative artwork — 2026-09-25

User explicitly requested image-generation derivatives for sliced/diced food. Original team PNG/JPG files are unchanged. These generated faces are not registered as original hand-drawn work. PNGs were copied unchanged from image_gen output; region selection happens only in the game renderer. The counter image contributes only a small patch replacing the baked-in immovable towel.

## roots

Inputs:

[
  "docs/supplied_assets/20260925-tomato/tomato-original.jpg",
  "docs/supplied_assets/20260925-batch2/onion.jpg",
  "docs/supplied_assets/20260925-batch2/carrot.jpg",
  "docs/supplied_assets/20260925-batch2/potato.jpg"
]

Prompt:

Create ONE production 2D cooking-game sprite sheet with a genuinely transparent alpha background. Use the four attached images only as TEAM ART style/color references, not as background: orange-red tomato, purple onion, orange carrot, ochre-skinned potato. Match their simple handmade angular gouache shapes and restrained brush texture. Do NOT redraw whole ingredients. Output precisely 4 rows by 6 columns in equal evenly spaced cells, no labels, no borders, no text, no shadows outside sprites. Each cell contains ONE separate cut food piece centered with generous transparent padding; never a pile. Row 1 TOMATO: col1 broad circular cut slice with distinct seed chambers orange red flesh, col2 smaller off-center slice, col3 end slice, col4 large chunky cube, col5 smaller cube with visible juicy interior, col6 irregular wedge. Row2 PURPLE ONION: col1 cross-section disk with concentric pink-white rings and purple skin, col2 off-center ring slice, col3 smaller end slice, col4 layered cube, col5 smaller layered cube, col6 wedge with curved layers. Row3 CARROT: col1 cross-section disk with orange center ring, col2 smaller slice, col3 small tip slice, col4 cube, col5 smaller cube, col6 diagonal chunk. Row4 POTATO: col1 broad pale yellow slice with fine ochre skin rim, col2 smaller slice, col3 small end slice, col4 pale yellow cube with thin skin on ONE face, col5 small cube, col6 irregular wedge. All visible cut faces tilted very slightly into view but near top-down 2D, consistent orthographic lighting, enough interior surface to serve as clipped textures in a game. EXACTLY 24 sprites in a regular 6x4 grid, no duplicate whole vegetables, no kitchen, no props. Wide canvas preferred 1536x1024. Preserve handmade non-vector look of reference ingredients. These are authorized derivative cut-state illustrations, not copies claimed to be untouched originals.

## vegetables

Inputs:

[
  "modules/restaurant/assets/handdrawn/mushroom.png",
  "docs/supplied_assets/20260925-batch2/eggplant.jpg",
  "docs/supplied_assets/20260925-batch2/bell_pepper_yellow.jpg",
  "docs/supplied_assets/20260925-batch2/zucchini.jpg"
]

Prompt:

One transparent-alpha production cooking-game sprite atlas, 1536x1024 preferred, EXACT 6 columns x 4 rows with equally sized cells and generous transparent gutters, no labels or text or props. Four supplied files are TEAM ART references only: mixed mushrooms, purple eggplant, yellow hollow bell pepper, pale green squash. Match simple warm handmade angular gouache 2D illustration. Each cell is exactly ONE separate food cut piece, not a pile. Row1 mushroom: columns1-3 three slightly different longitudinal cut slices with recognizable brown cap, pale stem and gills; cols4-6 three irregular mushroom diced chunks showing white interior and partial brown cap. Row2 eggplant: cols1-3 three cross-section disks with thin purple peel and pale cream seeded centers (large middle, off-center, small end); cols4-6 three diced chunks with cream interior and purple peel on just one edge. Row3 yellow bell pepper: cols1-3 three thin HOLLOW cross-section rings with yellow walls and small white ribs, transparent empty central cavity, no solid yellow disk; cols4-6 single curved wall chunks of different sizes, never solid cubes because pepper is hollow. Row4 light-green squash: cols1-3 three cross-section disks with lightgreen skin and pale seeded middle (large, off-center, small tip); cols4-6 three pale-green diced chunks with skin on one face. Slightly tilted near top-down orthographic cut surface so interiors readable, no perspective scenery, no baked ground shadows, no glow. 24 isolated transparent sprites, regular grid, consistent scale. Authorized derived CUT appearance assets, preserve references' palette and non-vector handmade brushwork. Background MUST be genuinely transparent, no opaque matte.

## counter_patch

Inputs:

[
  "modules/restaurant/assets/kitchen_reference_playable.png"
]

Prompt:

Edit this existing 1536x1024 kitchen background. ONLY REMOVE the cream dish towel with red stripes at the very bottom left-center, approximately x338-552 y790-923. Inpaint the wooden counter top and vertical front edge behind it, following the nearby original orange-brown wood perspective and lighting. Preserve the sink rim, stove, all other composition, all signs, all other pixels, exact camera and dimensions. Do not add objects. This edited area will be used as a small environment patch under a movable cleaning cloth in the game. No other changes.



## Output integrity

Files below live in modules/restaurant/assets/cut_states/. Original image-generation outputs were copied byte-for-byte. Runtime extraction uses explicit alpha bounds because generated spacing is not uniform. 42 faces are active (7 ingredients x 6); the bell-pepper row is reserved, with no active item ID. Partial amounts use the real cut polygons and conserved source fractions, not a canned ten-frame animation.

| File | SHA-256 |
| --- | --- |
| counter_patch.png | ff0adc5a80d744cf90dae94eb8470e55e4a1292e88072f37b9c2d1ade731af27 |
| roots.png | ab6adc8bf2b7bb3a4067d94bb6f34ab26ee7dc59c2f894a1245d120eac56bd0e |
| vegetables.png | 84ae92d4a4aa5cc1486138a7e752a0944adc223bef48e2f4d2978ec8e74ef347 |
