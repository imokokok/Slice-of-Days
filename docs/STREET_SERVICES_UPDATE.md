# Street services revision — 2026-09-22

The location barrage has been removed from both exploration hosts, its catalog and debug controls. Authored inner thoughts and NPC dialogue remain independent systems.

SOMEWHERE signposts sit at the right edge of each outdoor location. The lookout sign is at the right end of the public approach, before the 21:00 telescope gate, so daytime visitors can leave. The route board is native Godot Control UI: a destination list, four existing transport methods, actual price/time/wait/availability, and one departure action. It calls SceneRouter.travel_to with its existing save-failure rollback. Reference research: [80 Days official press kit](https://www.inklestudios.com/press/80days/) and [official overview](https://www.inklestudios.com/80days/); route/destination/method hierarchy only, no copied art or screens.

Fishing now begins at the harbour or lookout approach, never at the bus shelter or shop. The dedicated opaque seaside view uses a generated scenery painting. Float, line, rod motion, catch timing, controls and saved catches remain live separate game elements. It does not replace the town's supplied panorama or building art.

Camera, film and processing purchases present the existing financial receipt immediately; the counter can reopen saved receipts. The B camera exchange has a separately identified non-cash handover slip, not a invented cash payment. Receipts remain usable in Life Log; processing also keeps the real pickup ticket. RGB developed photos are converted before printing onto RGBA collage paper, preventing blank paper copies.

Visible NPC presentations persist across location and schedule refreshes. The previous pose retires only once its entire conservative silhouette is outside the camera. Adjacent blocks populate before crossing a boundary. Interaction distance and dialogue avoidance use the rendered pose; schedule/gameplay state remains authoritative. Both argument participants and the sprite-based resident use the same presentation policy.

Feedback holds for 14–26 seconds according to length; hovering or a blocking modal pauses reading time. The primary next-step card remains persistent.

## Generated assets

Built-in image_gen, original outputs copied into this repository; native transparency preserved for the sign. The sign crop discards near-transparent outer padding (alpha <= 8 only for measuring crop bounds, retained alpha otherwise). Sea painting stored as an opaque high-quality JPEG. No full UI mockups or invisible hotspots.

- `art/ui/handmade/fishing_sea.jpg`
- `art/ui/handmade/wayfinding_sign.png`

Exact sea prompt:

Create an original wide 16:9 2D game environment painting for Solmere, a tranquil coastal town. Reference image is STYLE REFERENCE ONLY (flat cut paper, light grain, airy cyan and periwinkle ocean, warm ivory, small lemon yellow accents); do not reproduce its long road or buildings. New asset: a quiet first-person fishing spot at the very edge of the sea. View looking outward over open water with the horizon at 25% height. A simple small sunwashed ivory stone quay enters the bottom-left corner and ends by x=25%, y=76%, leaving most of the lower and central scene as visible blue water. A tiny distant lighthouse silhouette at far right on the horizon, sparse high clouds, gentle broken flat hand-painted wave strokes. The middle water at x=45%-80% y=45%-75% must be open for a moving float. Lower right edge can be slightly deeper blue for legible overlay controls. No people, no fishing rod, no float, no boats, no plants in foreground, NO buildings nearby, NO bus stop, no text, no lettering, no UI, no border. The painting must be matte, flat, simple hand-drawn shapes, limited palette, light crayon grain matching the supplied reference, not realistic, not glossy, not a 3D render. Full opaque image. Large expansive sea, pleasant late summer daylight. This is background scenery for a real interactive fishing mode, not a UI mockup.

Exact sign prompt:

A single isolated 2D hand-drawn seaside village wayfinding signpost game sprite on a truly transparent background, portrait composition. One slender muted sea-blue wooden post, capped with ONE horizontal arrow-shaped wooden board pointing RIGHT. Board near the top, warm ivory matte painted surface with a thin blue edge and very subtle worn pale-blue strokes, completely BLANK generous central area so game can typeset a short word there. Post reaches flat ground at the bottom, a tiny low flat stone at its foot. Simple original crayon and flat gouache cut-paper illustration with a light paper grain, very small lemon yellow paint accent at the post base. Clean silhouette, flat frontal view, no perspective foreshortening, not realistic, no rendered light, no shadows cast outside the object, no plants, no ocean, no background, no typography or symbols or letters, NO extra boards. Overall asset proportions width to height approximately 0.85, board at y=8%-28%, post from y=0 to95%. Match a restrained coastal indie game's hand-painted props. Native transparent alpha, no checkerboard.

## Validation

- `test_street_services.gd`: 62 checks, including camera/film/development receipts, save/load, sign in all 14 locations, keyboard Input Map opening, route transaction rollback, real bus departure, absence of barrage and camera-aware resident retirement.
- `test_handmade_life.gd`: 55 checks, shopping/cooking/catch persistence and rollback.
- `test_dialogue_presentation.gd`: 275 checks.
- `test_travel_choices.gd`: 12 checks; walking journey regression passes.
- `test_v3_film.gd`: 80 checks passed WITH `--rendering-method gl_compatibility`, because the real collage workbench waits for a rendered frame. This also verifies that photo pixels, rather than blank paper, reach the collage, and that the camera exchange produces a non-cash handover slip.
- `test_street_motion.gd`: 34 checks; optional-dialogue exit regression passes.
- Visible captures in `.runtime/services-captures/` and live mouse/keyboard route inspection. Development outputs are not shipped as assets.

Playable review: `--script res://tools/preview_street_services.gd -- --isolated-save`; optional `--fishing` or `--camera` selects the matching actual street. Keep a separate review APPDATA/LOCALAPPDATA so normal saves remain intact.
