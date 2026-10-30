function Show-MtPackInstalled {
    <#
    .SYNOPSIS
    Writes what Install-MtPack installed, where it was recorded and the commands to run it.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'The message is written for a person at the console.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Entry,
        [Parameter()] [AllowEmptyString()] [AllowNull()] [string] $LockPath,
        [Parameter()] [AllowEmptyString()] [AllowNull()] [string] $ConfigPath
    )

    $console = Get-MtConsoleMode
    $style = { param($text, $s) Format-MtConsoleText $text -Style $s -Console $console }
    $code = ConvertTo-MtPackSafeText -Text ([string]$Entry.Code) -MaxLength 30
    $id = ConvertTo-MtPackSafeText -Text ([string]$Entry.Id) -MaxLength 60
    $tick = if ($console.Unicode) { '✓' } else { '+' }
    $tests = @($Entry.Tests).Count
    $here = (Get-Location).Path
    $shown = { param($path) if (-not $path) { return $null }; $relative = [System.IO.Path]::GetRelativePath($here, $path); if ($relative.StartsWith('..')) { $path } else { "./$relative" } }

    Write-Host ''
    Write-Host "  $(& $style $tick 'Passed') $(& $style 'Installed' 'Passed') $(& $style $code 'Accent')  $id $(& $style "v$($Entry.Version)" 'Dim')$(if ($tests) { & $style "  $tests tests (MP.$code.*)" 'Dim' })"
    $recorded = @(& $shown $ConfigPath; & $shown $LockPath) | Where-Object { $_ }
    if ($recorded) { Write-Host (& $style "    Recorded in $($recorded -join ' and ')" 'Dim') }
    Write-Host ''
    $next = [System.Collections.Generic.List[object]]::new()
    foreach ($service in @($Entry.Services | Where-Object { $_ })) { $next.Add(@("Connect its service", "Connect-Maester -Service $(ConvertTo-MtPackSafeText -Text $service -MaxLength 60)")) }
    $next.Add(@('Run only this pack', "Invoke-Maester -Pack $code -SkipBuiltIn"))
    $next.Add(@('Run it with the rest', "Invoke-Maester -Pack $code"))
    $next.Add(@('Run every pack', 'Invoke-Maester -AllPacks'))
    $next.Add(@('See installed packs', 'Get-MtPack'))
    foreach ($n in $next) {
        $label = "$($n[0]):".PadRight(22)
        Write-Host "    $(& $style $label 'Dim') $(& $style $n[1] 'Accent')"
    }
    Write-Host ''
}
