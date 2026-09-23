# Chess table presentation — 2026-09-24

The user asked for the chess UI and other minigames to belong to the same hand-drawn coastal world. The accepted pocket badges are the style reference. Original game rules, local opponents, teaching, saved lessons and result handoff are retained.

- `art/ui/pocket_doodles/chess_table.png`: generated tabletop, source `exec-b1f8716f-4983-4534-bc8e-3682c54806c4.png`.
- `art/ui/pocket_doodles/chess_pieces.png`: generated twelve-piece transparent atlas, source `exec-d6d44856-32e1-452e-8790-db67cef4e806.png`.
- Generation used the built-in ImageGen tool with the approved `badges.png` as a visual reference. No copied game artwork is included.
- Board grids, intersections, legal moves, stones, typography and controls are native Godot elements. The generated table and pieces have no functional text baked in. `table_art.gd` crops the piece atlas at draw time; original outputs remain archived locally.
- Warm paper and brown ink also cover the rule sheet, lesson editor and post-match dialogue. The host bar reserves space above the game rather than covering it.
- Chinese remains the source language. The engine fallback is explicitly Chinese so adding an English catalog cannot silently turn Chinese native Controls into English.

## Table prompt

```text
Create a finished 2D hand-drawn game background asset, landscape 1536x1024. Match the supplied reference's quiet thin brown ink contours, flat very pale cream and muted sage blocks, modest charming imperfection, NOT rough scratchy texture or realistic materials. A tabletop for a cozy coastal-town board game. Orthographic TOP DOWN, no perspective. One continuous pale oatmeal table with simple dark warm-brown uneven outline near outer perimeter, a few tiny restrained marks, absolutely NO lemons, flowers, foliage, words, icons, game grid, chess pieces, UI buttons, numbers or characters. Left 58 percent of canvas: a large completely BLANK square of pale honey wood for a board, approximately x=110..800,y=165..820 in a 1536x1024 canvas; just its single softly drawn irregular outer wooden edge, blank flat center for the game's own grid. Right x=955..1450,y=115..915: one large blank pale ivory sheet, lightly curled right bottom corner and a slim muted sage paperclip at top right, completely unmarked blank interior where native readable game text and controls will go. Upper left y=40..130 and bottom left y=865..975 stay empty for title and guidance text. A tiny pair of softly drawn empty bowls at very far left margin, no intrusive decorative objects. Clean readable large color fields, negligible texture, the reference's restrained sketchbook object quality. The desk is the entire background; do not show the reference icons. Asset with solid background, no checkerboard. Maintain broad empty usable areas.
```

## Piece atlas prompt

```text
Generate one transparent PNG sprite atlas, exactly 1536x1024, strict 6 columns by 2 rows of equally sized 256x512 cells, generous blank transparent margin separating every cell. 12 independent hand-drawn 2D chess pieces, FRONT silhouette view as little cut-paper illustrations. In each row the exact order is PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING. Top row pale ivory fill with warm deep brown fine hand-ink outlines; bottom row muted deep blue-green fill with dark brown fine hand-ink outlines. SAME shapes in both rows. Each piece centered at cell x=128 and y=256, occupies about 150px width and 230px height maximum, fully contained within its cell. Conventional immediately distinguishable silhouettes: pawn simple round head; knight simple horse head; bishop mitre with one diagonal slit; rook square tower battlements; queen small five point crown with round tips; king single small cross on crown. All pieces same broad flat oval pedestal, few flat color shapes, NO 3D render, NO gradients, NO photoreal material, NO glow, NO shadows outside shape, NO engraved details, NO texture noise, NO dots around pieces, NO labels or board. Match the supplied reference's refined simple warm ink hand-drawn object style, slightly imperfect contour and very quiet cream colors, simple enough to be legible at 60px. Transparency is essential; no chessboard pattern or solid background.
```
