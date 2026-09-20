# Workshop artwork provenance

The original desk image was provided by the user on 2026-09-20 and is preserved verbatim as `reference-desk.png`.

Tool: built-in `image_gen.imagegen`, edit mode, original reference and derived wax tray as inputs. Derived assets were copied into this project; alpha channels are retained. Godot uses alpha-aware textures and soft natural contact shadows. No runtime dependency on the generation service.

## Prompts

### desk-clean.png

Use case: precise-object-edit. Edit the supplied 16:9 Solmere desk image into a clean background plate for this exact game. Keep camera, window, town, sun, walls, plants, desk wood grain, left stationery rack, books and vase in exactly the same positions. Seamlessly remove ONLY the central blank letter, typewriter, scissors, craft knife, green cutting mat, both tape rolls, pen cup and pens, envelope at lower right, entire wax tray with all contents, matchbox and loose matches. Reconstruct the occluded desk naturally in matching painted wood texture and sunlight, absolutely no ghost silhouettes or cutout seams. Remove the top-left Solmere logo/date and left menu labels and top-right icons and bottom-right SEND text, replace underlying wall/paper naturally. Do not remove the stationery rack/photos. Full frame same composition. Warm hand-painted illustration as original, no new objects.

### typewriter.png

Use case: background-extraction. Extract ONLY the olive green vintage typewriter WITH its cream paper from the supplied Solmere desk reference. Reconstruct the entire hidden edges and base, retain exact painted style, warm lighting and three-quarter desktop angle. Isolated single complete typewriter, large centered with tight margin, genuine transparent alpha background, no table, no other props, no rectangle/white halo/checkerboard. Paper must be blank for game-rendered text. Clean natural antialiased silhouette and soft small contact shadow.

### scissors.png

Use case: background-extraction. Extract ONLY the dark black-handled metal scissors at lower left from the supplied reference; reconstruct all cropped or obscured blade tips so the entire scissors is complete. Keep same warm painterly style and slightly open blades, diagonal orientation. One single scissors only, centered large with tight margin, genuine transparent alpha background. No mat, no paper, no desk. No white/colored halo or cutout artifacts.

### knife.png

Extract ONLY the silver and warm ivory craft knife on the green mat in supplied reference. Complete the entire blade, body and end. One isolated knife in the same diagonal orientation, matching hand-painted warm light. Genuine transparent alpha background, tight margin, no mat/paper/desk, no white halo, no crop marks.

### tape.png

Extract ONLY the blue checked washi tape roll from the desk reference, complete its back/hidden circumference. One isolated roll, painterly style and warm sun retained, large centered, genuine transparent alpha background, no other props, no table, no halos, no checkerboard background.

### mat.png

Extract ONLY the green gridded cutting mat from lower left reference. Remove scissors, knife, paper and reconstruct the obscured grid flawlessly. Complete rectangular mat shown top-down, game asset, hand-painted aged green, small grid markings. Genuine transparent alpha around the rectangular mat, no table, no props, no seams.

### pen.png

Extract and reconstruct one complete wooden fountain pen from the reference pen cup. Show full wood barrel, metal nib pointing downward, upright diagonal. Same warm hand-painted style, single isolated pen, genuine transparent background, centered large tight margins, no cup, no other objects, no halo.

### envelope.png

Extract only the cream botanical envelope at lower right of supplied reference. Reconstruct all its obscured edges and clean silhouette. Show complete envelope with its triangular flap OPEN upward for inserting a letter, blank interior, tiny green leaf sprig lower front. Same hand-painted texture, no table or other objects, genuine transparent alpha background, centered tight margins, no white outline.

### wax-tray.png

Extract ONLY the wooden wax sealing tray at right from supplied reference, including candle in brass holder, wooden stamp, red wax pellets box and metal spoon. Reconstruct any obscured parts, keep warm hand-painted style. Single complete tray kit on genuine transparent alpha background, large and centered. Remove flame from candle (unlit wick). No table, typewriter or envelope or extra props. No cutout halos.

### candle.png

Extract only the unlit cream candle INCLUDING brass candle holder from this tray. Reconstruct complete circular holder, keep same hand-painted summer palette, upright wick unlit. Large centered single object on genuine transparent alpha background. No tray, other props, surroundings, halo or cast shadow.

### spoon.png

Extract only the brass wax melting spoon with wooden handle from this tray. Make the bowl EMPTY (gold brass interior), reconstruct entire handle and bowl edges. Horizontal bowl on left, wooden handle on right, same hand-painted summer palette. Single complete isolated tool with genuine transparent alpha, no tray, no other props, no shadow or halo.

### stamp.png

Extract only the tall wooden handled brass wax seal stamp from the right of this tray. Complete the round brass base including hidden edges. Same warm hand-painted style, upright whole stamp, tight margin, genuine transparent alpha background. No wax, tray, other props, glow, outline or shadows.

### matchbox.png

Create a single complete matchbox and one wooden match lying just below it, as a warm hand-painted game sprite matching this reference. Cream paper matchbox, tiny red floral print, clearly visible rough brown striking strip along front side. No text. Genuine transparent alpha background, isolated large centered sprite, no other objects, no table, no halo or shadow.
