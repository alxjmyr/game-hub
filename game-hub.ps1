# Run from PowerShell: .\game-hub.ps1
$ErrorActionPreference = 'Stop'
if ($env:GODOT_BIN) {
    & $env:GODOT_BIN --path $PSScriptRoot @args
} elseif (Test-Path "$PSScriptRoot/build/windows/game-hub.exe") {
    & "$PSScriptRoot/build/windows/game-hub.exe" @args
} elseif (Get-Command godot -ErrorAction SilentlyContinue) {
    & godot --path $PSScriptRoot @args
} elseif (Get-Command godot4 -ErrorAction SilentlyContinue) {
    & godot4 --path $PSScriptRoot @args
} else {
    throw 'No game build or Godot found. Install Godot 4.5.2, or set GODOT_BIN to its executable.'
}
exit $LASTEXITCODE
