# Solmere dialogue readability pass

## Visual references and interpretation

- User-supplied Solmere UI board: a small opaque NPC line beside the scene, with independently operable player replies.
- [OXENFREE official press kit](https://nightschoolstudio.com/press-kit/oxenfree-press-kit/), specifically its `OXENFREE-NETFLIX-Nona-EN.jpg` screenshot: small separate reading surfaces, clear speaker association and native response choices. The screenshot was inspected locally as research only.
- The user's Night in the Woods campfire reference: short, compact speech with a solid backing and strong text contrast. The [publisher page](https://finji.co/games/nightinthewoods/) identifies the reference game.
- [Kentucky Route Zero](https://kentuckyroutezero.com/) remains a reference for restrained presentation and reading rhythm. This patch follows the user's explicit warm-white solid backing requirement rather than copying any game's colors or assets.

All visible controls remain Godot Controls. No reference screenshot is a runtime asset. No new bitmap art is needed for this typography and layout correction; the existing scene and handmade shop art stay intact.

## Presentation contract

- Speech: `#FFFDF6`, alpha 1. Body: `#26343D`; hint: `#4F6470`. Body contrast is checked at 7:1 or better; hints and all response states at 4.5:1 or better.
- At the authored 1600 x 900 viewport, the speech surface is 394 px wide (about one quarter of the view). Height follows actual shaped text; the old forced 96 px body and menu-sized enclosing panel are removed.
- Body is 22 px, replies 19 px, speaker 17 px and secondary control hints 14 px. Body text uses the shared readable font. Only the name uses the existing handwriting font.
- Response chips are 326 px wide, at least 44 px high, with 8 px gaps. Normal, hover, pressed, focus, disabled and selected remain native states. Focus uses a clear blue rim and pale lemon fill.
- Layout first excludes character silhouettes and draggable memories, then avoids authored building silhouettes. It prefers the lower side of the conversation; a clear side column reads speech first and replies below. Crowded scenes place the two groups independently.
- Reading location is retained across lines and camera settling. Entering a new line uses only 2 px of inset motion over 140 ms; the backing and text never fade into the scenery. Reduced motion shows the line immediately. Esc closes immediately and restores movement.
- CICI's speech anchor now resolves to the right-hand character within the shared market hotspot. Her draggable memory and the speaker indicator use the same side as her actual portrait.
- Street arguments now count as dialogue for notification policy. Unrelated guidance waits until conversation ends. Inner thoughts reserve every actual speech/reply rectangle rather than just the old enclosing panel.
- Ordinary legacy panel/input surfaces and scene choice buttons use opaque backgrounds. Direction, context prompts and feedback also keep solid backing during their entrance.

## Verification

`tests/integration/test_dialogue_presentation.gd` covers scene bounds at 960/1280/1600 widths, stable placement, text wrapping, contrast, opacity, separate response bounds, mouse/keyboard branch results, disabled choices, counter reopening, Esc, market memories, indoor long lines, reduced motion and night lighting. A rendered run writes seven screenshots to `.runtime/dialogue-captures` for visual inspection.

Additional regressions cover optional dialogue, guidance/relationship feedback, inner voices and the existing world UI. The feedback regression now uses the actual basket checkout introduced by the previous shop update instead of waiting for its retired confirmation modal.

Verified results: dialogue presentation 275 checks / 0 failures (rendered); optional dialogue 0 failures; life feedback 38 checks / 0 failures; inner voices 40 checks / 0 failures; world UI 0 failures. Fresh desktop verification also exercised line advance and immediate Esc cancellation.

`tools/preview_dialogue.gd -- --isolated-save` opens a real town conversation using an isolated save; it does not modify the player's normal save. The normal game scenes use these same shared components.
