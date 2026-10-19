$ErrorActionPreference = 'Stop'
$expectedPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'build\MM2Streamer.exe'))
$stopped = 0
foreach ($companionProcess in @(Get-Process -Name MM2Streamer -ErrorAction SilentlyContinue)) {
    if ($companionProcess.Path -and [IO.Path]::GetFullPath($companionProcess.Path) -eq $expectedPath) {
        Stop-Process -Id $companionProcess.Id
        $stopped++
    }
}
$connectionPath = Join-Path $PSScriptRoot 'build\connect.lua'
if (Test-Path -LiteralPath $connectionPath) { Remove-Item -LiteralPath $connectionPath }
Write-Output "Stopped $stopped companion process(es) from this folder."
Write-Output 'If the native HUD is still hidden, turn Streamer mode Off in MM2 (F4 by default).'
