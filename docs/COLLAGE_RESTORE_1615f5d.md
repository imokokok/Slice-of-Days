# Original letter gameplay with replacement materials

The user selected the original `1615f5d` version, then requested that its functionality and overall layout remain while its collage materials are replaced using the supplied source-link packs.

- Restore the original 1440×900 desk, dialogue, craft-knife rectangle/free cropping, transforms, tape, handwriting, folding, envelope, wax, stamp and drift-letter service.
- Replace only the material renderer and catalog with 67 materials: 25 icons, 8 papers, 12 print sheets, 10 tickets, 6 decorative scores and 6 public-domain paintings. The existing tabs, two source sheets, private ticket and album retain their positions and controls.
- Adapt photo labels and artwork feedback to the new material content. The story and crafting sequence remain intact.
- Remove the rejected later workshop, desktop/tool artwork, typewriter and glue systems from active source. Keep other games and Git history. This is a forward commit, never a force push.
- Integrated source is the same as the standalone prototype with relocated resource paths. A small adapter isolates host drafts by journey/character; the host fits the original canvas without covering it.
- Original saved files are not deleted. Their material indexes now refer to the replacement catalog; start a fresh letter to see the new set as intended.

Asset origins and exact file hashes: `prototypes/collage-letter/assets/open_pack/sources.json`.

Validation: rendered full crafting smoke flow, server service tests, host viewport and mouse-input test, full replacement-catalog rendering/cropping audit, rendered captures. Native interaction with the final packaged window was not completed.

The subsequent user request also authorizes suitable commercial-safe open-source components and prior sound assets. Waitress 3.0.2 now serves desktop/LAN/container builds; the Godot client retries transient safe operations with a fixed idempotency key. Recorded CC0 effects replace synthesized effects using a fixed sound pool. See prototypes/collage-letter/OPEN_SOURCE_REVIEW.md.
