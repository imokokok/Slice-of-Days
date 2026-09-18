# Development status

## Current delivery: Day 1 A + Day 2 B vertical slice

Phase 0 complete: audited original entry/controller/schedules/dialogue/router/clock/save/minigames/autoload/input/assets, recorded KEEP/REFACTOR/LEGACY, created backup branch. No minigame assets deleted.

Phase 1 functional: fifteen-node graph, eight small stage partitions, roads/map, priced transport and bus timetable, separate stage return positions, configurable 15:1 clock. All fifteen locations reachable. Public-space interior doors remain direct proximity interactions.

Phase 2 foundation: configurable composition anchor per stage; angular shared silhouettes, inertia/turn/knee gait, synchronized footfalls; reference palette applied. Existing complex minigames retain their art. Individual NPC gesture animations, object-mask transitions and final lighting are pending.

Phase 3 foundation: twelve updated core NPCs with daily schedules and authored mood/energy slots; shared stage dialogue, practical questions, sourced structured knowledge, uncertain rumours, refusal, repeated encounters and history. Topics cover the requested categories through shared handlers and NPC-specific greetings/personal lines. Full bespoke 8–15-exchange major conversations and event-specific branching are pending editorial work.

Phase 4 functional framework: A/B/B/A/B/A/final choice; A object cards and B factual Notebook with map Pin; safe offscreen receipts/notes, stored day cursor, final-day explicit choice, v3 save migration. Full bespoke Day 3–7 arcs and recognition route balancing are not yet validated under the new chronology.

Phase 5 sample loop: cooking leaves a persistent restaurant-board echo visible to the other role. Letter/sound results have echo adapters, closed shops leave a quiet scene instead of a failure popup. This is a representative loop, not the requested complete set of 20–30 authored echoes.

Phase 6 reuse: cooking/native modules, collage letter, chess, tarot, recorder/arranger and real 3D stargazing retained; integration round-trips verified. Cooking is still the existing ingredient/heat prototype; full first-person cooking, cut thickness/force, advanced recipe flow, full physical packaging and pet-photo exchange remain future work. No claim those systems are complete.

Phase 7 existing local persistence retained: records, notes, artifacts. A unified CommunityContentProvider across every minigame and offline chess camera fallback remain to be completed; no new paid API dependency added.

Phase 8 partial: palette, footstep timing and composition changes. Final atmosphere, role-specific audio mix and a redesigned Seven Days archive remain pending.

## Acceptance verified
- Day 1 A begins left, no role/slot gate; world is not one continuous street.
- Bus/taxi prices and time differ, wrong-stop and last-bus restrictions, affordability checked before moving.
- Kitchen plays existing cooking prototype, cost settles, returns to same interior; shared board persists into B's Day 2.
- Sleep at own home advances A day1 → B day2, low-risk absence traces appear.
- Dialogue pauses natural clock, supplies schedule information and uncertainty/source; Notebook and pins persist.
- NPC location and mood change with schedule; missed shop is quietly closed.
- 20:00 lookout gate, authored 3D stars, actual camera rotation and puzzle solvability retained.
- v5 save reload and v4/v3 money/memory migration verified; day7 explicit choice verified.

Exit-only engine resource cleanup warnings remain. Legacy fourteen-chapter smoke/simulation/walking tests need reinterpretation for the new narrative model; see README for the authoritative current suite. No old save or old minigame asset was cleared.

Latest playtest fixes: full-body facing flip and stopped turn before reversing; persistent reachable bench hotspots, seated posture, E to wait 30 minutes / Esc stand / wait until lookout opens; generated looped sea-wash layer on the TownWorld audio bus, quieter indoors. TURN SIT SEA test covers motion, proximity, time advancement and non-silent loop audio.

## September playtest feedback pass

Talking now uses W, physical-world interaction uses E, and dialogue advances with Space (Enter remains a compatibility shortcut) or full-sentence clickable replies; R/C/P and J/Tab provide dedicated recorder, camera, album and notebook controls. The HUD exposes wallet balance plus fragmented/full time guidance. B has authored return deadlines and computer-started work commitments that consume time, pay income, or become missed work when B remains away.

The produce stall and grocery counter now sell priced goods into persistent inventory with a visible money ledger. Purchased cooking ingredients are marked on the kitchen workbench and consumed when selected. Pocket photos and saved recordings write local media metadata and journey artifacts. `test_feedback_systems.gd` covers purchases, inventory consumption, work timing/payment, semantic input actions, HUD presence and shop construction.

Follow-up playtest feedback now gives both roles a 07:00 wake and 22:00 rest boundary. A's 07:00—08:00 morning run and 19:00—20:00 night run cost two authored hours; B starts free exploration at 07:00 while retaining three paid work interruptions. The lookout and its late story windows moved to 20:00—22:00 so the existing two-hour choices remain reachable.

The pocket camera is now an in-world viewfinder rather than a slider form: rule-of-thirds composition, drag/keyboard pan, wheel zoom, focus lock, shutter flash and an instant field-note card. Thirty authored scenery subjects across all fifteen locations persist into a redesigned field-notes album with names, categories and observation captions. `test_camera_rhythm.gd` covers the schedule asymmetry, routine cost, focus discovery, saved metadata and the no-slider camera UI.

## Dialogue and invitation update
Twelve core residents now have authored multi-line everyday stories and repeat variants. Xanni describes her own hours in first person. Recollections retain the actual spoken text and uncertain source in B's notebook. Seven notebook leads point to the relevant resident and place; accepted invitations update the note. Cooking, letters, records and tarot require the host invitation before workbench entry; chess offers a conversation first. The misunderstanding module starts from BEETMAN's produce-stall conversation and returns there. Existing minigame content is retained.
Validation: test_minigame_invitations.gd, test_network_vertical_slice.gd and content_validation_test.tscn pass. Existing Godot shutdown resource warnings remain.

## Myriorama integration and proactive invitations
Imported the user's uploaded prototype from add/myriorama-tarot at a5c1d3d (PR #1) into extensions/myriorama_tarot. The active tarot module now routes through the extension host to the 18-card Myriorama table. Original three-card tarot remains legacy. Assets, CC0 audio license, offline question bank and puzzle rules are retained; only resource namespaces, viewport fitting, main-save role persistence and completion bridge were adapted. Completion requires the prototype's final truth stage; starting a new story resets it.
Eligible hosts now volunteer their invitation after greeting, once per role/day, with individual invitations and polite decline replies. Reopening dialogue does not repeat the invitation; players can bring it up again through the topic and notebook.
Validation: Myriorama entry/return/resume, original smoke test (200 deals and 919 question-bank assertions), invitation flow and content validation pass. Existing shutdown resource warnings remain.
