# User-supplied postal, produce and grocery frontages

The user identified three new images as 邮局, 菜摊 and 杂货店 (correcting 便利店). They replace only the corresponding exterior artwork. Existing interiors, names, backgrounds and other approved art remain unchanged.

## Sources

Files in `art/user_scenes/` are byte-identical copies of the supplied files:

| Imported file | Supplied filename | SHA-256 |
| --- | --- | --- |
| post_office_supplied.png | dd6f3af70de95b9ad5aabf1bb65625ea.png | 7841DB9374D97D3D68B842FE912950B20CFEF2D67E58C150701EEE90EB0AE888 |
| produce_stall_supplied.jpg | df1d9cceb7b02617943c78ce7468a22c.jpg | 11154A7F2DFDCA16BF13AECAAA5AC8CD0DFE7F673346B3C4E12FADD7B088B49D |
| grocery_supplied.png | 6fbb12a609f1a4bbe5f3a38699662c98.png | D9318A1B9454320DB4F45C510AD096FB3FCF72F60B84B3C4A250057ACFF20CE8 |

The existing runtime paper-cutout helper removes only the produce JPG's exterior paper and three bounded openings. White canopy stripes and the welcome sign remain opaque. PNG transparency is retained. No raster repainting or recoloring was performed.

## Staging and behavior

- Shared curb grounding, preserved aspect ratio and existing scene daylight modulation.
- Postal roof fits inside the view; the entrance follows the painted left door and opens the existing letter office.
- Produce retains its vendor and direct checkout.
- Grocery uses existing internal ID `cafe`. Its fruit table and crates overlap the paving behind people. The painted doorway opens the existing owner conversation and purchase flow, without a new interior.

## Verification

`tools/preview_supplied_frontages.gd -- --isolated-save` checks transparency, grounding, real entrances and visible checkout controls: 15 checks, zero failures. Actual GPU screenshots were inspected for all three frontages. Run with `--keep-open` to leave a disposable playable preview open at the post office.

Focused integration suites `test_shop_work_routes` and `test_street_motion` pass. The runner verifies that existing tracked artwork stays unchanged. Final checks are repeated after incorporating remote main commit `40127f4`; evidence is stored alongside this report in `supplied_frontages_20260926/`.

Godot's sandbox root-certificate-store warning is unrelated to these local rendering and interaction checks; no script/runtime errors were observed. No claim is made that the previous Windows release package contains these newly imported assets.
