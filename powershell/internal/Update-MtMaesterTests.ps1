function Update-MtMaesterTests {
    <#
    .SYNOPSIS
    Removes the stale copies of built-in tests from a folder (used by Update-MaesterTests).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple tests')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        # The folder to clean up.
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Write-Error "The folder '$Path' does not exist."
        return
    }
    $Path = (Resolve-Path -LiteralPath $Path).Path

    $builtInRoot = Get-MtMaesterTestFolderPath
    $builtInFiles = @(Get-MtBuiltInPesterFile -BuiltInRoot $builtInRoot)
    $builtInInventory = @(if ($builtInFiles.Count -gt 0) { Get-MtPesterFileInventory -Path $builtInFiles })
    $resolvedBuiltInRoot = if (Test-Path -LiteralPath $builtInRoot) { (Resolve-Path -LiteralPath $builtInRoot).Path } else { $builtInRoot }

    $candidates = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Filter '*.Tests.ps1' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/][Cc]ustom[\\/]' -and -not $_.FullName.StartsWith($resolvedBuiltInRoot, [System.StringComparison]::OrdinalIgnoreCase) } |
            ForEach-Object { $_.FullName })
    $removed = [System.Collections.Generic.List[string]]::new()
    if ($candidates.Count -gt 0) {
        $inventory = @(Get-MtPesterFileInventory -Path $candidates)
        $superseded = Get-MtSupersededTest -CustomInventory $inventory -BuiltInInventory $builtInInventory -BuiltInId @(Get-MtTestCatalog | ForEach-Object { $_.Id })
        foreach ($file in $superseded.ExcludeFiles) {
            if ($PSCmdlet.ShouldProcess($file, 'Remove copy of a built-in Maester test')) {
                Remove-Item -LiteralPath $file -Force
                $removed.Add($file)
            }
        }
        $partial = @($superseded.Items | Where-Object { $_.File -notin $superseded.ExcludeFiles } | ForEach-Object { $_.File } | Select-Object -Unique)
        foreach ($file in $partial) {
            Write-Warning "Kept '$file': it has tests of your own as well as copies of built-in tests. The copies are not run."
        }
    }

    # Folders the removal left empty.
    if ($removed.Count -gt 0) {
        $folders = @($removed | ForEach-Object { Split-Path $_ -Parent } | Select-Object -Unique | Sort-Object { $_.Length } -Descending)
        foreach ($folder in $folders) {
            $current = $folder
            while ($current -and $current.Length -gt $Path.Length -and (Test-Path -LiteralPath $current) -and -not (Get-ChildItem -LiteralPath $current -Force)) {
                if ($PSCmdlet.ShouldProcess($current, 'Remove empty folder')) { Remove-Item -LiteralPath $current -Force }
                $current = Split-Path $current -Parent
            }
        }
    }

    # A copy of the config file Maester 2.x shipped: keep only what differs from the defaults.
    $configFile = Join-Path $Path 'maester-config.json'
    $reducedRows = $null
    if (Test-Path -LiteralPath $configFile) {
        $config = ConvertTo-MtConfigLayer -InputObject $configFile
        $rows = @($config.TestSettings)
        if ($rows.Count -ge 300 -and -not ($rows | Where-Object { $_ -and -not $_.PSObject.Properties['Title'] })) {
            # The defaults are the severities of the built-in tests (their [MaesterTest] attribute), plus any
            # row the shipped config still has. A row for a test that no longer exists, with nothing but a
            # severity, is dropped too.
            $defaults = @{}
            foreach ($t in @(Get-MtTestCatalog)) { if ($t.Id) { $defaults[[string]$t.Id] = [pscustomobject]@{ Severity = $t.Severity } } }
            foreach ($d in @((Get-MtShippedMaesterConfig).TestSettings)) { if ($d.Id) { $defaults[[string]$d.Id] = $d } }
            $kept = @($rows | Where-Object {
                    $default = $defaults[[string]$_.Id]
                    ($_.PSObject.Properties.Name | Where-Object { $_ -notin 'Id', 'Title', 'Severity' }) -or ($default -and $_.Severity -ne $default.Severity)
                } | ForEach-Object {
                    $row = [ordered]@{ Id = $_.Id }
                    foreach ($p in $_.PSObject.Properties) { if ($p.Name -notin 'Id', 'Title') { $row[$p.Name] = $p.Value } }
                    [pscustomobject]$row
                })
            if ($PSCmdlet.ShouldProcess($configFile, "Reduce to the $($kept.Count) of $($rows.Count) test settings that differ from the defaults")) {
                $newConfig = [ordered]@{}
                foreach ($p in $config.PSObject.Properties) {
                    if ($p.Name -in 'ModuleVersion', 'ConfigVersion') { continue }
                    $newConfig[$p.Name] = if ($p.Name -eq 'TestSettings') { $kept } else { $p.Value }
                }
                $newConfig | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configFile -Encoding UTF8
                $reducedRows = $kept.Count
            }
        }
    }

    Write-Host "Removed $($removed.Count) copies of built-in tests from $Path." -ForegroundColor Green
    if ($null -ne $reducedRows) { Write-Host "Reduced maester-config.json to the $reducedRows test settings that differ from the defaults." -ForegroundColor Green }
    [pscustomobject]@{ RemovedFiles = $removed.ToArray(); ConfigRowsKept = $reducedRows }
}
