# Solmere UI implementation and verification

Updated 2026-09-22. This change implements the visual hierarchy and usable native controls described in the supplied Solmere UI references and Production Overhaul document. The existing town art and gameplay backends remain in use. This is not a claim that every proposed new gameplay system in the document exists.

## Visual and architectural coverage

| Surface | Native UI and actual behavior |
| --- | --- |
| Exploration | Small day/time and one tracked lead, contextual Input Map prompt, hidden while tools or other modes are active. |
| Dialogue / thoughts | White NPC bubble, separate blue choices and yellow selection; existing dialogue branches; independent animated thoughts suppressed outside exploration. |
| Notebook | Open book, six left sections, live objective checkboxes, heard facts, people/places, private notes, collected materials and actual photographs. |
| Archive | Six section cards, official requirements/final questions, blank personal/life/recognition pages, seven independent portfolio pages only in Portfolio. |
| Portfolio | Real selected-item controls and dragging; identity, source, transform and layer persistence continue through the existing residency save data. |
| Camera / Gallery | Full-screen world capture, shutter, actual film inventory and developing; real photo thumbnails, filters, enlarged view and navigation. New letter-workshop projects also import developed photos with source IDs. |
| Recorder | Real game audio capture, stop/save, dynamic entries, real waveform/playhead, playback, seeking, rename and deletion confirmation. In-use recordings cannot be deleted. |
| Map | Independent location markers, actual visit/route/knowledge state, four filters, pan/zoom and actual route selection. No pins are baked into the illustration. |
| Travel | Destination/method choice, actual time/fare/availability, confirmation, fade, transaction-derived travel card, arrival. Friend rides require an established relationship; fares, time, tickets and knowledge share the existing rollback-safe transaction. |
| Shops / bag / restaurant | Real inventory, selected shelves, price/time confirmations, receipt, insufficient-funds feedback; existing orders/cooking connections retained. |
| Minigames | Shared native buttons and scene-appropriate panels across cooking, chess, tarot, observatory, letter/collage and other existing modules. Chess previews legal hover targets; observatory hints fade and return when needed. |
| Music studio | Existing real four-track timeline and waveform, transport and mixing controls; actual undo/redo and save. |
| Pause / settings / saves | Tree pause, resume, actual audio buses, display/reduced motion settings, real save/scene transition. Three dynamic save cards use real world thumbnails, with confirmation before deletion. |
| 3D memory | Sparse interaction hint, Input Map movement/examine, no global exploration thoughts leaking over the scene. |

Reusable scripts live in `scripts/ui/components`: `solmere_button`, `book_surface`, `ink_icon`, `confirm_sheet`, `shutter_button`, `location_marker`, `media_browser`, `runtime_menu`, `travel_card`, `save_slots`. The common theme is `art/ui/solmere_ui.tres`. Text, buttons, selection, data and input handling are separate nodes; none of the supplied complete reference images is displayed as an interactive screen.

## Generated assets

Made with the built-in ImageGen tool for this project. These are decorative assets only; their source references were supplied by the user. No reference-game screenshots or third-party icon packs are shipped as UI.

- `art/ui/blank-notebook-spread.png`: blank open warm-white notebook, blue cloth cover, subtle paper grain, transparent exterior. No text, photos, tabs or UI. Native labels, checkboxes, pictures and controls sit above the blank material.
- `art/ui/solmere-tourist-map-painting.png`: original coastal-town gouache tourism illustration, sea blue, warm white, lemon and light green. No labels, markers or interface; every location marker is a separate data-bound Button.
- `art/ui/enamel-cooking-pan.png`: original top-down empty warm-white enamel pan with sea-blue exterior, wooden handle/spoon and small cloth; transparent background, restrained gouache texture. No food, text or controls. Ingredient choices remain native interactive cards.
- `art/ui/check-on.svg`, `check-off.svg`: project-authored line checkbox shapes used by the actual themed CheckBox state.

## Verification

Godot 4.7.2, Windows, compatibility renderer. Tests use isolated AppData and `--isolated-save`; actual player saves are not used as fixtures. Renderer-dependent capture/workshop tests must run with `--rendering-method gl_compatibility`, not headless.

- `test_production_ui.gd`: PASS, 28 captured game screens/states; long real notebook entries, dialogue and follow-up topic choices, actual purchases, insufficient funds, film capture/develop, recorder capture, studio undo/redo, travel confirmation/charge/time/arrival, real save thumbnail and five minigame screens.
- `test_native_guidance_ui.gd`: PASS; native notebook/archive/map/dialogue/media/settings, seven-page transforms, live objectives; a separate `--load-only` process also PASS for save/quit/load persistence.
- `test_v3_film.gd`: PASS, 78 checks, including capture to developed photo to collage source metadata.
- `test_v3_economy.gd`: PASS, 51 checks.
- `test_patch_travel.gd`: PASS, 30 checks; `test_travel_choices.gd`: PASS, 12 checks.
- `test_save_failure_recovery.gd`, `test_daily_spending.gd`, `test_world_ui.gd`, `test_native_modules.gd`: PASS.
- `test_workshop_tools.gd -- --workshop-test`: PASS with renderer for actual cutting and tool dragging.

Screenshots and logs are local QA artifacts in `.runtime`, excluded from source control. Engine-level verification is paired with a separately launched visible game window.

## Explicit remaining gameplay extensions

The existing cooking/restaurant flow works, but the proposed **player-drawn, named custom recipe becoming an item in a persistent restaurant menu and customer order pool** needs a new gameplay data model and order-generation rules. Full **restaurant advertising/customer management** is also not established by changing this UI. No placeholder button pretends to implement either system.

The music studio has actual tracks, mixing and undo/redo; **editable automation curves** are not implemented. The optional English localization catalog is absent in this checkout, so its unavailable language option is disabled rather than showing untranslated UI. These are explicit follow-up items, not passed acceptance claims.

The town remains the existing 2D scene, not the illustrated scene depicted in the supplied UI mockups. UI layout and hierarchy are rebuilt for this playable scene; pixel-identical backgrounds are not part of this change.
