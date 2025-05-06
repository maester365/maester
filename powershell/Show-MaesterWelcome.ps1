[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
param ()

try {
    . "$PSScriptRoot/internal/Show-MtLogo.ps1" -ErrorAction Stop
    Show-MtLogo
} catch {
    Write-Host "Importing Maester v$((Import-PowerShellDataFile -Path "$PSScriptRoot/../Maester.psd1" -ErrorAction SilentlyContinue).ModuleVersion)." -ForegroundColor Green
}

Write-Host "    To get started, install Maester tests and connect before running Maester:`n" -ForegroundColor Yellow
Write-Host "`tmd 'maester-tests'           " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tcd 'maester-tests'           " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tInstall-MaesterTests         " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tConnect-Maester -Service All " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tInvoke-Maester               " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`n    See https://maester.dev for more info.🔥`n" -ForegroundColor Yellow
