# Resident placement and direct New Game — 2026-09-24

## Scope and reference decisions

The user reported an NPC outside a building appearing again inside when the player entered, and asked to remove the opening animation. This change fixes those requests in the production scenes.

The text of `SOLMERE_功能打磨与强制实现规格.docx` was read directly from the supplied functional-polish ZIP. The user explicitly rejected every reference image in that package. Neither the three PNGs nor the document's embedded illustrations were extracted, viewed, imported, or used as generation references. The updated visual direction is Venba; existing approved Solmere artwork and pocket badges remain in place. Official visual source for subsequent art work: https://venbagame.com/press/ . This patch does not claim a new Venba-style art pass.

The existing authored schedules remain. “Fixed position” is implemented as a stable, resident-specific standing place within each scheduled scene, with one physical scene per resident at a time. The day's main collaborator stays at the work location throughout its opening hours, independent of whether a conversation has just completed. This does not turn all twelve residents into permanently stationary characters.

## Production changes

| Files | Behavior / mount point |
| --- | --- |
| `data/npcs/resident_staging.json`, `scripts/core/schedule_system.gd` | Every authored activity resolves to a named room or the street and a coordinate keyed by resident ID. Missing staging cannot produce an arbitrary fallback person. Loaded by the existing ScheduleSystem autoload. |
| `scripts/core/dialogue_system.gd` | Resolves one effective activity and placement before querying a location. Daily-host placement overrides the ordinary schedule globally instead of adding a second person at the task destination. Dialogue schedule answers and invitations use the same effective activity. |
| `scripts/ui/town_day.gd` | Draws only street residents, including visible neighboring blocks. Rejects conversations with people inside another scene. Keeps end signs and places the middle sign away from shop-door reach zones. |
| `scripts/ui/interactive_space.gd` | Draws only residents assigned to this exact room. Stable coordinates replace the previous `920 + roster index * 180` arrangement. Homes cannot inherit street NPCs. |
| `scripts/ui/street_composition.gd` | Removes the unused, competing NPC-coordinate table. |
| `scripts/photography/film_paper.gd`, `scripts/town_sound/RecorderScreen.gd` | “Nearby residents” for sharing a photo or recording context respects the same room/street boundary. |
| `scripts/ui/main_menu.gd` | New Game immediately starts the existing journey transition. Removes the opening movie player, white-screen sequence and playback timer from the menu. Existing save allocation and failure handling remain. |
| `scripts/core/guidance_system.gd` | Idle help cannot replace a closed shop's opening hours with a conflicting suggestion to visit it now. |

No new autoload, second clock, alternate town scene or replacement save system was added. Placement is derived from the existing saved day/time and authored configuration; no save-schema migration is required. Existing on-camera departure retention remains in `resident_presence.gd`.

## Player-entry regression

`tests/integration/test_resident_spaces.gd` runs through the real New Game button, walks to real door targets and sends E/W/Escape input. It checks:

1. New Game reaches the actual town without the opening movie.
2. Mossner stands outside the grocery in his morning slot, does not follow the player inside, and remains at the same outside coordinate on return.
3. Xanni is absent from the street while assigned to the record shop. Entering produces one indoor Xanni; W opens the real conversation beside him.
4. Leaving, re-entering and saving/loading preserve that fixed coordinate.
5. Every authored activity has a valid standing place; all five days and sampled schedule boundaries have at most one physical appearance per resident.
6. New readers do not move Maya's slot. Xanni's authored late visit remains outside the closed shop.

The test advances the production clock to 09:00 before the morning-entry checks. Later day/time sweeps are explicitly data fixtures, separate from the player-input section; they do not grant narrative completion. All saves use `--isolated-save`.

## Validation

- Resident-space regression: **128 checks, 0 failures**. Screenshots: `.runtime/resident-spaces/` (local, ignored).
- Full five-day regression: **218 checks, 0 failures**. Its conversation helper now enters the correct building and uses W beside the actual person, rather than calling an outdoor conversation method remotely.
- Fresh-process five-day reload: **13 checks, 0 failures**.
- Opening hours, night and physical interactions: **160 checks, 0 failures**, including all four idle-help levels before the shop opens.
- Both home interiors: **42 checks, 0 failures**.
- Optional dialogue and cancellation: **0 failures**, using a currently present resident rather than a retired encounter fixture.
- Fresh native-window check: clicked New Game in the production menu and observed the playable Day 1 street without a movie, then maximized the game. The review window uses an isolated save.
- Opening-related expectations were updated in `test_patch_travel.gd` and `test_v2_runtime.gd`; these historical full suites are not represented as passing without a fresh run.

## Functional-package boundary

Reading the functional package is not evidence that all of it has been delivered. This commit implements the newly reported NPC/entry issues and removes the intro. The package's four-fragment-per-NPC album and explicit signatures, further cooking/tool/music mechanics, saved unfinished chess games, and two-floor mailbox flow still require separate implementation and acceptance. No formal story text or recognition conditions were invented for those systems in this change.
