# Scene atlas

## Current presentation — 2026-09-24

The reference-atlas exterior renderer and street preloading are retired. Exteriors use simple native facades and the approved hand-drawn cutouts in `art/user_scenes/`, grounded on the shared curb. The supplied coast panorama is retained. Old exterior atlas files are archived, not active street backgrounds.

Home and other existing room interiors are retained. Their day/dusk/night plates now follow the continuous `WorldAtmosphere` presentation clock. The original protagonist artwork, resident sheets, fallback people and original walk rendering are retained. Names, schedules, narrative and interactions are unchanged.

The following describes the historical import, not the current exterior renderer:

Source: the user-provided `SOLMERE_全场景参考图册.pdf`, 99 pages. Each numbered JPEG is the corresponding embedded illustration, extracted without the PDF's caption and footer and encoded at quality 93. No new scenery was generated. The source PDF is retained outside the repository.

`data/world/scene_atlas.json` records page captions, the fifteen exterior locations, nine existing interiors, and door/workbench/bench coordinates. The renderer uses day plates from 06:00, dusk from 17:00 and night from 19:00. At 21:00 the lookout switches from its entrance to the sea terrace; its telescope still opens the existing 3D puzzle.

Street locations are spaced 1600 units apart. The camera follows walking continuously; neighboring illustrations overlap with a 160-unit feathered edge, without black fades or page jumps. Player and NPC height is 80% of the scene's reference door opening, recorded as `door_height` in 900-unit canvas coordinates. Door measurements are approximate visual calibrations; scenes without a visible door use the neighboring architectural scale. Feet remain grounded, including sitting; interaction hints sit above the enlarged silhouettes. Version-4 street save positions are scaled to the new width while keeping their location. New games still start on the left.

Cooking, sample arrangement, photography/archive prototypes, collage letters and the market conversation also use corresponding atlas backgrounds. Remaining detail plates are catalogued for future interaction work; they do not add new locations or replace the playable Myriorama cards or 3D stars.

Validation: scene atlas mapping/save migration, native viewport screenshots (day street, dusk interior, night record shop, open lookout), Day 1/2 journey, turn/sit/sea and observatory entry/return tests. Existing Godot shutdown resource warnings remain.
