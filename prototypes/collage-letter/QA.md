# Letter Office validation · 2026-09-25

- Standalone, Godot 4.5.1, NVIDIA OpenGL rendered run: LETTER_WORKSHOP_TEST PASS; WORKSHOP_TOOLS_TEST PASS; TYPEWRITER_TEST PASS; WORKSHOP_GLUE_TEST PASS.
- Main-game host after rebasing onto cbfa7e9, Godot 4.7.2: COLLAGE_VIEWPORT_TEST PASS. The fixture follows the real travel API and starts in an open 11:30 schedule slot. Main-game session drafts, photo IDs and localized controls are retained.
- Python drift service: all 8 tests passed, including two players over real HTTP, restart persistence, idempotency and atomic send/reply debt.
- Glue tests exercise mouse strokes, front/back isolation, insufficient adhesive, press attachment, drag resistance, peeling, undo/redo, serialization and releasing over a GUI control. Deep copies prevent later edits from mutating undo records.
- Visual renders inspected: desk, coated paper back, seven-line Chinese/English typewriter output and envelope. Material rack sizing and ephemeral texture lifetime were corrected during inspection.
- Desktop window: launched, but Windows was locked when the native screenshot was requested. No claim of completed manual live-window interaction; unlock is pending.
- Old workshop raster images, old material data and obsolete renderer files are removed from both source layouts; the additional retired handmade workshop set from current upstream is removed as well. Walking animation and other game art remain intact. Existing player-created local drafts are preserved.
- 67 material entries and 81 source/license records. All manifest SHA-256 values match the distributed files. Clean Windows folder is built from tracked standalone files, plus the existing Godot/Python runtimes. No old assets, engine caches, databases, identities or API credentials are included.

The rebuild kit contains wider proposals (orders/economy, consumable source pages, typewriter overprinting, fluid simulation). These are not represented as completed features in this change; see GUIDE.md for current implementation boundaries.
