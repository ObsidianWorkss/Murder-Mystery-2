param([string]$OutputDirectory = (Join-Path $PSScriptRoot 'build'))
$ErrorActionPreference = 'Stop'
$frameworkRoot = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$compilerPath = Join-Path $frameworkRoot 'csc.exe'
if (-not (Test-Path -LiteralPath $compilerPath)) { throw '.NET Framework 4.x C# compiler is required on 64-bit Windows.' }
$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$outputFile = Join-Path (Resolve-Path -LiteralPath $OutputDirectory).Path 'MM2Streamer.exe'
$references = @('System.dll','System.Core.dll','System.Web.Extensions.dll','WPF\WindowsBase.dll','WPF\PresentationCore.dll','WPF\PresentationFramework.dll','System.Xaml.dll')
$compilerArgs = @('/nologo','/target:winexe','/platform:x64','/optimize+',('/out:' + $outputFile))
foreach ($reference in $references) { $compilerArgs += '/reference:' + (Join-Path $frameworkRoot $reference) }
$compilerArgs += Join-Path $PSScriptRoot 'Overlay.cs'
& $compilerPath @compilerArgs
if ($LASTEXITCODE -ne 0) { throw 'Overlay compilation failed.' }
Write-Output $outputFile
