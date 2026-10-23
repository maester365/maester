function Get-MtPackTestInventory {
    <#
    .SYNOPSIS
    Returns the native tests of the packs in a pack set, as the engine plans them (Maester Packs design, sections 4.4 and 5.5).

    .DESCRIPTION
    A Ready pack's suites are read statically, like custom tests (Get-MtNativeTestInventory). Every row then
    gets what keeps a pack from passing as a built-in check: Source is Custom whatever its suite.json says,
    PackId names the pack, and Package carries Id, Version, Commit, Publisher, BuiltIn and Runtime (Script),
    the reserved row field of the 3.0 result schema. PackSelected is true for a pack named with -Pack, whose
    preview and long-running tests the plan runs as if their IDs were named.

    A pack that is not Ready gives one row per test ID it is known to provide (the lock file's Tests, or a
    static read of a built-in pack), with PackStatus set so the plan reports it without running anything:
    NotRun with PackUnavailable, PackBlocked or PackNotAllowed, or Error with PackLoadFailed or
    RequiresNewerMaester. A Disabled pack gives no rows.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $PackSet
    )

    foreach ($pack in $PackSet) {
        if ($pack.Status -eq 'Disabled') { continue }
        $package = [pscustomobject][ordered]@{
            Id        = $pack.Id
            Version   = $pack.Version
            Commit    = if ($pack.Entry) { $pack.Entry.Commit } else { $null }
            Publisher = if ($pack.Manifest) { [string]$pack.Manifest.Publisher } elseif ($pack.Entry) { $pack.Entry.Publisher } else { $null }
            BuiltIn   = [bool]$pack.BuiltIn
            Runtime   = 'Script'
        }

        $tests = @()
        if ($pack.Root -and $pack.Manifest -and $pack.Status -in 'Ready', 'Failed', 'Blocked', 'NotAllowed') {
            # Reading the AST runs nothing, so a pack that may not run still names its tests.
            $tests = @(foreach ($folder in $pack.Manifest.Suites) {
                    $suiteRoot = Join-Path $pack.Root $folder
                    if (Test-Path -LiteralPath $suiteRoot -PathType Container) { Get-MtNativeTestInventory -Path $suiteRoot -Root $suiteRoot }
                })
        }
        if ($pack.Status -ne 'Ready') {
            $disposition = if ($pack.ReasonCode -in 'PackLoadFailed', 'RequiresNewerMaester') { 'Error' } else { 'NotRun' }
            $ids = if ($tests.Count -gt 0) { @($tests | Where-Object Id | ForEach-Object { $_.Id }) } else { @($pack.TestIds) }
            foreach ($id in ($ids | Where-Object { $_ } | Select-Object -Unique)) {
                $test = $tests | Where-Object { $_.Id -eq $id } | Select-Object -First 1
                if (-not $test) { $test = ConvertTo-MtPackPlaceholderTest -Id $id }
                $test | Add-Member -NotePropertyMembers ([ordered]@{
                        Source     = 'Custom'
                        PackId     = $pack.Id
                        Package    = $package
                        PackStatus = [pscustomobject]@{ Disposition = $disposition; ReasonCode = $pack.ReasonCode; Reason = $pack.Reason }
                    }) -Force
                $test
            }
            continue
        }
        foreach ($test in $tests) {
            $test | Add-Member -NotePropertyMembers ([ordered]@{ Source = 'Custom'; PackId = $pack.Id; Package = $package; PackStatus = $null; PackSelected = [bool]$pack.Selected }) -Force
            # Defence in depth for a pack that never went through Install-MtPack (one that ships with Maester).
            if ($test.Id -and $pack.Manifest.Code -and -not (Test-MtPackTestId -Id $test.Id -Code $pack.Manifest.Code -BuiltIn:([bool]$pack.BuiltIn))) {
                $test.Errors.Add([pscustomobject]@{ Code = 'InvalidMetadata'; Message = "A test in the pack $($pack.Id) must have an ID that starts with $(Get-MtPackTestIdPrefix -Code $pack.Manifest.Code -BuiltIn:([bool]$pack.BuiltIn))."; Line = $test.Line })
            }
            $test
        }
    }
}

function ConvertTo-MtPackPlaceholderTest {
    <#
    .SYNOPSIS
    Returns a test row for a pack test that could not be read, with the fields the plan and the result row use.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [string] $Id)

    [pscustomobject]@{
        File = $null; FunctionName = $null; Line = 1; Id = $Id; Title = $Id; Product = $null; RelatedProduct = @(); Feature = $null
        Area = $null; ResourceType = $null; Severity = $null; UserImpact = $null; ImplementationCost = $null; Mitre = @(); Control = @()
        Service = @(); License = @(); Permission = @(); TenantType = @(); Cloud = @(); Platform = @(); Lifecycle = 'Stable'; ReplacedBy = $null
        LongRunning = $false; Exclusive = $false; InstanceSource = $null; Tag = @(); Author = @(); Contributor = @(); HelpUrl = $null
        Parameters = @(); UnregisteredServices = @(); MarkdownPath = $null; RequiresMaester = $null; BuiltIn = $false
        Errors = [System.Collections.Generic.List[pscustomobject]]::new(); Suite = 'Custom'; Block = 'Custom'; SuiteTag = @(); Format = 'Native'; Benchmark = $null
    }
}
