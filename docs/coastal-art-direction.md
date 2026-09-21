# Coastal composition and light

The existing sky, panorama, building silhouettes and supplied character artwork remain the source art. This pass changes rendering, scale and staging; it does not bake a new background or overwrite a texture. The joined routes and their saved coordinate system remain unchanged.

## Visual treatment

- A single world material brings monochrome cutouts, colored sprites and native geometry into mineral blue/green shadows and warm ivory highlights. Saturation is restrained; the original printed relief and alpha edges remain visible.
- Fine, static pigment grain is anchored to world coordinates, including during camera movement. No animated noise or full-screen overlay is placed over the UI.
- The opaque black road overlay becomes a gently shaded limestone-colored surface. Its original curb and walkable extent remain. Curb joints move with the world, and shallow contact shadows anchor objects.
- Character clothing and the shelter's bench share the same lighting treatment as buildings. Native sign labels bypass the pigment shader so font distance fields remain sharp.
- Dawn, daytime, late afternoon and night share one light function. All exterior residents, procedural buildings and cutouts now respond to it. Existing authored interiors retain their own lighting.

The color direction interprets the natural-light and production-design approach discussed by cinematographer Sayombhu Mukdeeprom and colorist Chaitawat Thrisansri for *Call Me by Your Name*. It is an original palette for Solmere, not a film LUT or copied image:

- [Kodak — Call Me by Your Name](https://www.kodak.com/en/motion/blog-post/call-me-by-your-name/)
- [Lift-Off — interview with colorist Chaitawat Thrisansri](https://liftoff.network/chaitawat-thrisansri-interview/)

## Staging and gameplay

`street_composition.gd` defines the cutout bounds, contact points, doorway offsets and resident pockets used by both the stage and the actual interaction system. Produce and chess stalls are reduced; the tarot shop, houses, shelter and community-center facade are proportioned around the existing street actors. Native planting occupies gaps between facades rather than the conversation pockets.

The market pair has 140 pixels of separation. Its interaction reach, memory-drop targets and dialogue obstacles use those visible positions. Other residents occupy separate spaces instead of the former tightly packed sequence. A fresh arrival avoids standing directly inside an NPC; normal walking and stored player positions are not forcibly displaced.

Story events are small notices at their location, rather than additional anonymous human silhouettes. Their existing event branches and conditions remain connected. World labels are native Labels; global controls and dialogue do not inherit the world material.

## Verification

`test_coastal_composition.gd` renders all 15 actual outdoor locations and checks standing room, arrivals, reachable hotspots, the real shopkeeper dialogue and cancellation, day/night pixels, UI color isolation, walking and restored positions. Captures are written to `.runtime/coastal-composition/`.

Existing scene-atlas/save migration, optional dialogue, adaptive dialogue presentation and the 28-screen production flow are also exercised. `tools/preview_coastal_town.gd -- --isolated-save` opens a normal playable new game in the caller's isolated save directory; it grants no fabricated inventory, progress or recognition.
