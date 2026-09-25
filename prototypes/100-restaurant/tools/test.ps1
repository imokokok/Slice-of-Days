param([Parameter(Mandatory=$true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
function Invoke-GodotTest([string]$Script) {
    $result = & $GodotPath --headless --path $projectPath --script $Script --quit-after 18000 2>&1
    $code = $LASTEXITCODE
    $result | Write-Output
    if ($code -ne 0 -or ($result -match 'SCRIPT ERROR:|^ERROR:|^FAIL:') -or -not ($result -match 'PASS|Asset alpha audit: .*0 errors')) {
        throw "Engine test failed or did not reach its success marker: $Script (exit $code)"
    }
}
Invoke-GodotTest tests/test_thermal_reactions.gd
if ($LASTEXITCODE -ne 0) { throw 'Thermal reaction tests failed' }
Invoke-GodotTest tests/test_reaction_kitchen.gd
if ($LASTEXITCODE -ne 0) { throw 'Thermal kitchen integration tests failed' }
Invoke-GodotTest tests/test_visual_spatial_consistency.gd
if ($LASTEXITCODE -ne 0) { throw 'Visual spatial consistency tests failed' }
Invoke-GodotTest tests/test_craft_workbench.gd
if ($LASTEXITCODE -ne 0) { throw 'Paper craft workbench tests failed' }
Invoke-GodotTest tests/test_material_physics.gd
if ($LASTEXITCODE -ne 0) { throw 'Material physics tests failed' }
Invoke-GodotTest tests/test_cut_clean_share.gd
if ($LASTEXITCODE -ne 0) { throw 'Cut, cleaning and sharing tests failed' }
Invoke-GodotTest tests/test_handdrawn_assets.gd
if ($LASTEXITCODE -ne 0) { throw 'Hand-drawn asset tests failed' }
Invoke-GodotTest tests/test_shelf_pages.gd
if ($LASTEXITCODE -ne 0) { throw 'Shelf page tests failed' }
Invoke-GodotTest tests/test_recipe_guide.gd
if ($LASTEXITCODE -ne 0) { throw 'Recipe guide tests failed' }
Invoke-GodotTest tests/test_recorded_audio.gd
if ($LASTEXITCODE -ne 0) { throw 'Recorded audio tests failed' }
foreach ($test in @('modules/restaurant/domain/test_domain.gd','modules/restaurant/storage/smoke_test.gd','tests/test_integration.gd','tests/test_high_fidelity_state.gd','tests/test_knife_physics.gd','tests/test_knife_drag.gd','tests/test_cut_batch_stability.gd','tests/test_slice_cooking_continuity.gd','tests/test_reference_layout.gd','tests/test_stock_volume_recipe.gd','modules/restaurant/ui/poster_store_test.gd','modules/restaurant/ui/collage_test.gd','tests/test_collage_input.gd','modules/restaurant/storage/paper_recipe_test.gd','tests/test_recipe_diy.gd','tests/test_tape_editing.gd','tests/test_tape_tools.gd','tests/test_seasoning.gd','tests/test_spatula.gd','tests/test_heat_control.gd','tests/test_kitchen_interactions.gd','tests/test_customer_reviews.gd','tests/test_free_pan.gd','tests/test_workstations.gd','tests/test_comfort_release.gd','tests/capture_asset_gallery.gd')) {
    Invoke-GodotTest $test
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
}
