[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
param ()

Show-MtLogo
Write-Host "    To get started, install Maester tests and connect before running Maester:`n" -ForegroundColor Yellow
Write-Host "`tmd 'Maester-Tests'           " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tcd 'Maester-Tests'           " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tInstall-MtTests              " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tConnect-Maester -Service All " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`tInvoke-Maester               " -ForegroundColor Black -BackgroundColor Gray -NoNewline
Write-Host ''
Write-Host "`n    See https://maester.dev for more info.🔥`n" -ForegroundColor Yellow
