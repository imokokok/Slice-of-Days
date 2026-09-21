# Scene-aware dialogue presentation

The old speech bubble was centered above whichever character was speaking. Its detached menu used a second set of fixed coordinates, so changing speakers, longer Chinese text, and five counter options could cover a face, a shopfront, or each other.

The new presentation uses native Godot Controls: warm white, dark body text, small sea-blue speaker names, restrained lemon accents, and lightweight response rows. It keeps the scene alive and preserves its artwork.

## Reference interpretation

- [Kentucky Route Zero, Cardboard Computer](https://kentuckyroutezero.com/) and the [developer's screenshots](https://cardboardcomputer.itch.io/kentucky-route-zero): staged composition, text hierarchy, a stable reading block, sparse emphasis. Its black treatment and artwork are not copied. Additional dialogue still consulted: [developer interview with in-game screenshots](https://www.gamesradar.com/the-making-of-kentucky-route-zero/).
- [OXENFREE, Night School Studio](https://nightschoolstudio.com/oxenfree/): conversation belongs to the live scene, with actual responses and relationship consequences.
- The user's Night in the Woods reference informs the compact separation of speaker and words. These references are design direction, not UI textures or prescribed animation timings.

## Implementation

- `scripts/ui/components/dialogue_card.gd`: shared native labels, measured wrapping, adaptive single/two-column layout, typography and restrained entry/exit.
- `scripts/ui/components/dialogue_choice.gd`: real Buttons with normal/hover/pressed/focus/disabled/selected treatments; mouse, keyboard and controller navigation.
- `scripts/ui/components/dialogue_layout.gd`: scores candidate positions around actual scene geometry and screen edges. Any actor-free candidate outranks one covering a character; scenery follows, then proximity and layout stability.
- `walk_stage.gd::dialogue_obstacles()`: derives padded actor silhouettes from the actual stage/camera, captures building rectangles from the same drawing routines, and preserves interior work-counter/object areas.
- NPC conversation, vendor responses, direct questions, indoor remarks, town event dialogue and the street argument use the shared presentation. The argument's memory-drag mechanics remain intact.

During a conversation the card retains its location unless the scene or content genuinely requires relocation. Five counter replies can switch to two columns rather than grow down over the shop. Relocation fades in at its destination rather than travelling across characters. There is no long speech tail crossing the scene.

Entry is a 160 ms fade with 4 px of internal movement; exit is a 120 ms input-transparent visual tail. Esc releases gameplay immediately. Main conversational text reveals at 32 characters/second with brief punctuation pauses. The first advance reveals the current line, the next advances the story. Reduced Motion removes both entry animation and the initial typewriter effect.

Godot 4.7 labels explicitly receive `custom_maximum_size.x` and shape the whole line before revealing characters. This prevents stale one-character-wide wrapping from producing a towering blank panel during rendered font loading. Layout measurements are cached until scene/content/viewport state changes.

The layout avoids authored rectangles, not image semantics. Indoor backdrops cover much of the screen, so the protected areas are actors, work counters and interactive objects; a card can still sit over a noninteractive wall/roof. New room artwork can extend the stage's protected regions. Future unusually large dialogue catalogs should add a scrolling/paged overflow mode; current story events have at most two choices and the counter has five.

## Preserved behavior

DialogueSystem and existing conversation owners still control branches, story progression, invitations, transactions and saves. No parallel story state, automatic conversation entry, or fake shop buttons were introduced. Cancelling an unfinished story does not mark it complete. Closing the real shop resumes the same counter conversation.

## Validation

- `test_dialogue_presentation.gd`: geometry at 960/1280/1600 widths and both screen edges; stable positioning; fully visible wrapped Chinese; native counter controls; actual keyboard shop entry/resume; mouse topic selection; Cici's real dog branch; disabled replies; interior silhouettes; immediate Esc; Reduced Motion.
- Run the above both headless and with the compatibility renderer. Rendered checks are required because headless fallback fonts do not expose all sizing issues.
- `test_optional_dialogue.gd`: approaching does not force dialogue, Esc cancels without marking complete or opening Pause.
- `test_linear_dialogue.gd`: actual line advancement, subsequent story episode, save/load persistence, cancellation.
- `test_core_loop_rebuild.gd`: 76 existing gameplay checks.
- Real visible game verification: exterior line and counter layout, keyboard highlight and real shelf opening, and interior dialogue.

Local preview, using isolated APPDATA/LOCALAPPDATA and `--isolated-save`:

```
godot --path . --script res://tools/preview_dialogue.gd -- --isolated-save
godot --path . --script res://tools/preview_dialogue.gd -- --isolated-save --dialogue-preview=room
```

The preview also accepts `cici` and `argument`. It opens the actual game scenes and dialogue systems; it is not a mockup and must not use the normal player's save directories.
