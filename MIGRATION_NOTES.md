# Solmere migration audit

Baseline: 09129be; backup/pre-network-09129be. New specification explicitly confirmed by the user. No source/assets deleted. 102 GDScript files and 22 scenes inventoried; see docs/SCRIPT_INDEX.md. Inventory is not a claim of a full manual playthrough of every minigame.

## KEEP
- project.godot: Godot 4.7 compatibility renderer, 1600×900 canvas.
- Main entry scenes/main_menu.tscn + scripts/ui/main_menu.gd: direct New Game and latest Continue.
- scripts/core/save_manager.gd: automatic slots, archive rotation and isolated tests. Add migration before altering chapter/world data.
- scripts/core/relationship_system.gd: recognition and encounter memory, independently of mood.
- scripts/core/event_system.gd: conditions, choices, results; keep old content pending new chronology verification.
- scripts/core/gameplay_module_system.gd and scripts/ui/extension_host.gd: entry/results/return adapters.
- scripts/town_sound: recorder, photo album/camera, multitrack arrangement, visual composition, pressing table, local record library, audio settings.
- extensions/collage_letter, elder_board, hear_you, observatory: existing interactive assets/scenes. Stargazing uses authored 3D positions and Camera3D.
- Nine interiors and fifteen canonical locations remain authoritative. Only internal public-space partitions may be introduced.

## REFACTOR
- scripts/ui/town_day.gd and walk_stage.gd: one 13,500-unit street → small shared stage instances selected by world graph; branch exits, saved local coordinates, composition anchors.
- scripts/core/travel_system.gd: existing Dijkstra useful; remove universal buses and role-only friend rides, add configured stops/timetables/quotes, appointment conflicts and atomic arrival.
- scripts/core/chapter_system.gd: fourteen alternating chapters → seven authored days A/B/B/A/B/A/choice. Sleep remains day-end action.
- scripts/core/game_state.gd: save v3 → v4 migration, structured facts and offscreen traces in persisted shared state. 5:1 natural clock retained, configurable.
- scripts/core/schedule_system.gd: retain location schedules, add deterministic mood/energy from authored slots and scheduled arrivals/departures indoors.
- scripts/ui/journal.gd: A object Pocket, B factual Notebook, source/confidence and player pins. Do not reveal hidden event windows through day_leads.
- Dialogue currently town event overlay + one-line interior chat. Introduce shared contextual conversation panel and data topics; pause natural clock, preserve actor visibility and history.
- SceneRouter currently stores transient room return positions; extend map/travel return context, retain single transition owner.
- Input uses physical keys A/D/arrows/Shift/E/J and default ui_accept/navigation; add M and shared dialogue selection, retain keyboard and pointer paths.

## LEGACY (retained in place until replacements pass)
- town_backdrop.gd / stage_backdrop.gd: old background renderers.
- data/story/transitions.json and day_openings.json: old fourteen-chapter presentation, no longer authoritative.
- Old global street coordinates, old generated roster and event routes: migrate positions and keep IDs, do not silently delete player memories.
- optical_illusion and archives native prototypes remain asset/reference scenes; do not restore deleted separate locations.
- Old seven-day simulation assumes every role gets seven full playable days; new vertical slice requires its own integration suite before full-route rebalance.

## Existing minigame entry scenes
- cooking: res://scenes/native_module_game.tscn
- ghostwriting: res://scenes/extension_host.tscn → res://extensions/collage_letter/Main.tscn
- tarot: res://scenes/tarot_table.tscn
- translation: res://scenes/extension_host.tscn → res://extensions/hear_you/main.tscn
- optical_illusion: res://scenes/native_module_game.tscn
- sound_sampling: res://scenes/native_module_game.tscn
- chess: res://scenes/extension_host.tscn → res://extensions/elder_board/scenes/main.tscn
- contemplation: res://scenes/extension_host.tscn → res://extensions/observatory/scenes/StarGazing3D.tscn
- photography: res://scenes/native_module_game.tscn
- archives: res://scenes/native_module_game.tscn

Cooking currently uses native_module_game, a simplified ingredient/heat prototype: it is NOT the requested full first-person cooking simulation. Chess extension may require external recognition for optional camera features; default offline play must be verified. Existing postcard/painted art is reusable inside minigames but not a unified exterior art solution.

## Autoload audit
CharacterSystem, GameState, ScheduleSystem, ResidentProfileSystem, TravelSystem, RelationshipSystem, EventSystem, ChapterSystem, GameplayModuleSystem, SaveManager, SettingsSystem, SceneRouter, WorldSound, SoundSettings, ObservatoryState, ObservatoryAudio. Retain existing names and separate responsibilities instead of adding aliases for every suggested Manager.

## Risks and acceptance
- Do not erase old saves. Migrate old chapter cursor onto the matching calendar day/role, preserving all personal artifacts and recognized residents.
- Travel must validate before charging, display full wait/fare/arrival and preserve correct return location.
- Lookout opens at 21:00; time display HH:MM; 60 real seconds = 5 game minutes.
- Tests at baseline pass behavior assertions but print 2 ObjectDB / 1 resource cleanup warnings on exit.
- First delivery is the Day 1 A + Day 2 B vertical slice, not a claim that all expanded minigames or seven-day authored content are finished.

## Vertical-slice implementation outcome
WorldGraph, KnowledgeSystem, DialogueSystem and EchoSystem added as separate autoloads. Existing TravelSystem/ChapterSystem/SceneRouter retained and refactored. Eight internal stage partitions serve exactly fifteen locations. Seven generated background names retired into data/npcs/demo_npcs.json:retired_generated_names to retain a 100-person active roster after adding the seven new core identities; their old saves remain preserved. Legacy core profiles retained in docs/legacy_core_residents.json. Current stage and content tests pass; broader seven-day rebalance remains explicitly pending.
