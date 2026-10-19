param([int]$RobloxPid = 0)
$ErrorActionPreference = 'Stop'
$builtPath = & (Join-Path $PSScriptRoot 'build.ps1')
Start-Process -FilePath $builtPath -ArgumentList @($RobloxPid.ToString()) -WindowStyle Hidden
Write-Output 'Companion started. Load MM2 Universal, then open streamer/build/connect.lua in Solara and execute it.'
Write-Output 'In OBS choose Window Capture for Roblox, with Capture Cursor off. Verify a saved clip before relying on it.'
Write-Output 'Use F4 or Visuals > HUD & Alerts > Streamer mode to restore the native UI before closing the companion.'
Write-Output 'After stopping your recording and turning Streamer mode Off, run Stop-Streamer.ps1 to close this companion.'
