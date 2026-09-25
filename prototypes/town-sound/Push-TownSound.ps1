param([string]$Message = "Update Town Sound")
$ErrorActionPreference = 'Stop'

function Invoke-ProjectGit {
    param([string[]]$GitArguments)
    & git @GitArguments
    if ($LASTEXITCODE -ne 0) { throw "git failed: $($GitArguments -join ' '). Resolve the reported issue before retrying." }
}

Push-Location $PSScriptRoot
try {
    $repositoryRoot = (& git rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'This folder must be inside the Slice-of-Days Git checkout.' }
    Set-Location -LiteralPath $repositoryRoot
    $currentBranch = (& git branch --show-current).Trim()
    if ($currentBranch -ne 'main') { throw "Expected main, found $currentBranch. Switch intentionally before pushing." }
    $remoteUrl = (& git remote get-url --push origin).Trim()
    if ($remoteUrl -notmatch 'github\.com[:/]imokokok/(?:Slice-of-Days|Solmere)(?:\.git)?$') { throw 'origin is not the expected Slice-of-Days repository.' }
    $scopes = @('prototypes/town-sound/', 'scripts/town_sound/', 'scenes/town_sound/', 'tests/town_sound/', 'art/town_sound_cc0/', 'art/recording_icons/', 'third_party/licenses/lucide/', 'third_party/licenses/godot_sound_manager/')
    $sharedFiles = @('README.md', 'project.godot', 'scripts/ui/town_day.gd', 'scripts/ui/interactive_space.gd', 'scripts/core/scene_router.gd', 'scripts/residency/recorder_lite.gd', 'scripts/residency/paper_overlay.gd', 'scripts/ui/components/live_sound_window.gd', 'scripts/ui/components/media_browser.gd', 'export_presets.cfg', 'THIRD_PARTY_LICENSES.md', 'docs/DAILY_LIFE_SYSTEM.md', 'scripts/core/character_system.gd', 'scripts/core/save_manager.gd', 'scripts/core/ui_state_system.gd', 'scripts/residency/gameplay_shell.gd', 'scripts/ui/extension_host.gd', 'scripts/ui/native_module_game.gd', 'scripts/ui/components/cooking_board.gd', 'extensions/collage_letter/scripts/audio_manager.gd', 'extensions/observatory/scripts/audio_manager.gd', 'extensions/observatory/assets/nebulae/casa_observed.tscn', 'extensions/observatory/assets/nebulae/crab_observed.tscn', 'extensions/observatory/assets/nebulae/cygnus_observed.tscn', 'extensions/myriorama_tarot/scripts/sound.gd', 'tests/integration/test_global_recording.gd', 'tests/integration/test_global_recording.gd.uid', 'tests/integration/test_pocket_roles.gd', 'tests/integration/test_five_day_flow.gd', 'tests/integration/test_recorder_movement.gd', 'tests/integration/test_recording_retry.gd', 'tests/integration/test_ui_reference_review.gd')
    $changedPaths = @(& git diff --name-only) + @(& git diff --cached --name-only) + @(& git ls-files --others --exclude-standard)
    $otherPaths = @($changedPaths | Where-Object {
        $candidatePath = $_
        $isAllowed = $sharedFiles -contains $candidatePath
        foreach ($scope in $scopes) { if ($candidatePath.StartsWith($scope)) { $isAllowed = $true } }
        $candidatePath -and -not $isAllowed
    })
    if ($otherPaths.Count -gt 0) {
        throw "Changes outside Town Sound exist. Commit or handle them separately first: $($otherPaths -join ', ')"
    }
    Invoke-ProjectGit -GitArguments (@('add', '--') + $scopes + $sharedFiles)
    Invoke-ProjectGit -GitArguments @('diff', '--cached', '--check')
    & git diff --cached --quiet
    if ($LASTEXITCODE -eq 1) {
        Invoke-ProjectGit -GitArguments @('commit', '-m', $Message)
    } elseif ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the staged changes.' }
    Invoke-ProjectGit -GitArguments @('fetch', 'origin', 'main')
    Invoke-ProjectGit -GitArguments @('rebase', 'origin/main')
    Invoke-ProjectGit -GitArguments @('push', 'origin', 'main')
    $localHead = (& git rev-parse HEAD).Trim()
    $remoteHead = ((& git ls-remote origin refs/heads/main) -split '\s+')[0]
    if ($localHead -ne $remoteHead) { throw 'Remote main differs from local HEAD; inspect before retrying.' }
    Write-Host "Verified main: $localHead"
    Write-Host 'Town Sound is synchronized with GitHub.'
} finally {
    Pop-Location
}
