param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$tarotProject = $PSScriptRoot
$tarotEngine = $GodotPath
if (-not $tarotEngine) {
    $tarotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($tarotCommand) { $tarotEngine = $tarotCommand.Source }
}
if (-not $tarotEngine -or -not (Test-Path -LiteralPath $tarotEngine)) {
    throw '请通过 -GodotPath 指定已安装的 Godot 4 可执行文件，或在 Godot 中导入同目录 project.godot。'
}
Start-Process -FilePath $tarotEngine -ArgumentList '--path', ('"' + $tarotProject + '"')
