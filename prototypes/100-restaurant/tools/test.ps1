param([Parameter(Mandatory=$true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
foreach ($test in @('modules/restaurant/domain/test_domain.gd','modules/restaurant/storage/smoke_test.gd','tests/test_integration.gd','tests/test_high_fidelity_state.gd','tests/test_knife_physics.gd','tests/test_knife_drag.gd','tests/test_cut_batch_stability.gd','modules/restaurant/ui/poster_store_test.gd','modules/restaurant/ui/collage_test.gd','tests/test_collage_input.gd','modules/restaurant/storage/paper_recipe_test.gd','tests/test_recipe_diy.gd','tests/test_tape_editing.gd','tests/test_tape_tools.gd','tests/test_seasoning.gd','tests/test_spatula.gd','tests/test_heat_control.gd','tests/test_kitchen_interactions.gd','tests/test_customer_reviews.gd','tests/test_free_pan.gd','tests/test_workstations.gd','tests/test_comfort_release.gd','tests/capture_asset_gallery.gd')) {
    & $GodotPath --headless --path $projectPath --script $test
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
}
