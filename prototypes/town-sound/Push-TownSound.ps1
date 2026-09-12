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
    if ($remoteUrl -notmatch 'github\.com[:/]imokokok/Slice-of-Days(?:\.git)?$') { throw 'origin is not the expected Slice-of-Days repository.' }
    $scope = 'prototypes/town-sound/'
    $changedPaths = @(& git diff --name-only) + @(& git diff --cached --name-only) + @(& git ls-files --others --exclude-standard)
    $otherPaths = @($changedPaths | Where-Object { $_ -and -not $_.StartsWith($scope) })
    if ($otherPaths.Count -gt 0) {
        throw "Changes outside Town Sound exist. Commit or handle them separately first: $($otherPaths -join ', ')"
    }
    Invoke-ProjectGit -GitArguments @('add', '--', 'prototypes/town-sound')
    & git diff --cached --quiet
    if ($LASTEXITCODE -eq 1) {
        Invoke-ProjectGit -GitArguments @('commit', '-m', $Message)
    } elseif ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the staged changes.' }
    Invoke-ProjectGit -GitArguments @('fetch', 'origin', 'main')
    Invoke-ProjectGit -GitArguments @('rebase', 'origin/main')
    Invoke-ProjectGit -GitArguments @('push', 'origin', 'main')
    Write-Host 'Town Sound is synchronized with GitHub.'
} finally {
    Pop-Location
}
