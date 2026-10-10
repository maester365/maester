function Resolve-MtSelection {
    <#
    .SYNOPSIS
    Combines the run config's Selection section with the Invoke-Maester parameters (design section 7.3).

    .DESCRIPTION
    -Tag and -TestId replace the config lists; -ExcludeTag and -ExcludeTestId add to them; the include
    switches are true when either source sets them.

    .EXAMPLE
    Resolve-MtSelection -RunConfig $config -BoundParameters $PSBoundParameters
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $RunConfig,

        [Parameter()] [string[]] $Tag,
        [Parameter()] [string[]] $ExcludeTag,
        [Parameter()] [string[]] $TestId,
        [Parameter()] [string[]] $ExcludeTestId,
        [Parameter()] [switch] $IncludePreview,
        [Parameter()] [switch] $IncludeLongRunning
    )

    $s = $RunConfig.Selection
    [pscustomobject]@{
        Tag                = @(if ($Tag) { $Tag } else { $s.Tag })
        ExcludeTag         = @(@($s.ExcludeTag) + @($ExcludeTag) | Where-Object { $_ } | Select-Object -Unique)
        TestId             = @(if ($TestId) { $TestId } else { $s.TestId })
        ExcludeTestId      = @(@($s.ExcludeTestId) + @($ExcludeTestId) | Where-Object { $_ } | Select-Object -Unique)
        IncludePreview     = $IncludePreview.IsPresent -or [bool]$s.IncludePreview
        IncludeLongRunning = $IncludeLongRunning.IsPresent -or [bool]$s.IncludeLongRunning
        DefaultAction      = $s.DefaultAction
        OnUnknownId        = $s.OnUnknownId
        BuiltIn            = $s.BuiltIn
    }
}

function Test-MtIdMatch {
    <#
    .SYNOPSIS
    Returns the patterns that match an ID: exact or '*' wildcards, case-insensitive.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Id,
        [Parameter()] [string[]] $Pattern = @()
    )

    foreach ($p in $Pattern) {
        if ($p.Contains('*')) {
            if ($Id -like $p) { $p }
        } elseif ($Id -eq $p) {
            $p
        }
    }
}

function Get-MtPesterSelectionPlan {
    <#
    .SYNOPSIS
    Decides which Pester It blocks to exclude by line for ID-based selection and config admission.

    .DESCRIPTION
    Pester selects by tag only. ID-based rules (-TestId, -ExcludeTestId, TestSettings[].Enabled and
    Selection.DefaultAction) are applied by excluding the It lines of the tests they deselect
    (Filter.ExcludeLine). Excluded tests stay in the result as NotRun rows with a reason code. A test
    whose name is built at run time is matched as a family through its literal ID prefix.

    Returns: ExcludeLines (file:line strings), Reasons (file:line -> reason object), LiftPreview and
    LiftLongRunning (an exact -TestId names a Preview or long-running test, so the default tag
    exclusion is dropped and other such tests are excluded by line instead), UnknownIds, and the
    inventory it used.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Rows from Get-MtPesterFileInventory.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Inventory,

        # Output of Resolve-MtSelection.
        [Parameter(Mandatory)]
        [pscustomobject] $Selection,

        # The resolved run config (for TestSettings).
        [Parameter(Mandatory)]
        [pscustomobject] $RunConfig
    )

    $reasons = [ordered]@{}
    $liftPreview = $false
    $liftLongRunning = $false
    $knownIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $familyParents = [System.Collections.Generic.List[string]]::new()

    $rows = foreach ($row in $Inventory) {
        if ($row.ParseError -or -not $row.Line) { continue }
        $parentId = $null
        if (-not $row.IsStatic) {
            $parentId = Get-MtFamilyParentId -LiteralPrefix $row.LiteralPrefix
            if ($parentId) { $familyParents.Add($parentId) }
        } elseif ($row.Id) {
            $null = $knownIds.Add($row.Id)
        }
        [pscustomobject]@{
            Key      = "$($row.File):$($row.Line)"
            Id       = $row.Id
            ParentId = $parentId
            Tags     = $row.Tags
            Row      = $row
        }
    }

    $enabledRows = @{}
    foreach ($ts in @($RunConfig.TestSettings)) {
        if ($null -ne $ts -and $ts.Id -and $ts.PSObject.Properties['Enabled']) { $enabledRows[[string]$ts.Id] = $ts }
    }

    foreach ($r in $rows) {
        if ($reasons.Contains($r.Key)) { continue }
        # The IDs this row answers to: its own, or for a family its parent and any instance under it.
        $matchId = if ($r.Id) { $r.Id } else { $r.ParentId }
        if (-not $matchId) { continue }

        # Config admission and disabling.
        $setting = $null
        if ($r.Id -and $enabledRows.ContainsKey($r.Id)) { $setting = $enabledRows[$r.Id] }
        elseif ($r.ParentId) {
            # A row that enables the parent or any instance admits the family. Only a row on the parent disables
            # it: a row that disables one instance is applied to that instance after the run (DisabledInstances).
            $setting = $enabledRows.Keys | Where-Object { $_ -eq $r.ParentId -or $_ -like "$($r.ParentId).*" } |
                ForEach-Object { $enabledRows[$_] } | Where-Object { $_.Enabled -eq $true } | Select-Object -First 1
            if (-not $setting -and $enabledRows.ContainsKey($r.ParentId)) { $setting = $enabledRows[$r.ParentId] }
        }
        if ($setting -and $setting.Enabled -eq $false) {
            $reasons[$r.Key] = New-MtSelectionReason -ReasonCode 'DisabledByConfig' -Detail $(if ($setting.Reason) { [string]$setting.Reason } else { 'Disabled in the Maester config.' })
            continue
        }
        if ($Selection.DefaultAction -eq 'Skip' -and -not ($setting -and $setting.Enabled -eq $true)) {
            $reasons[$r.Key] = New-MtSelectionReason -ReasonCode 'NotListed' -Detail 'Selection.DefaultAction is Skip and no TestSettings row enables this test.'
            continue
        }

        # -ExcludeTestId wins over -TestId. A family is excluded here only by a pattern that covers every
        # instance ('MT.1024', 'MT.1024.*'); a pattern for some instances is applied after the run.
        $excludedBy = @(Test-MtIdMatch -Id $matchId -Pattern $Selection.ExcludeTestId)
        if (-not $excludedBy -and $r.ParentId) {
            $excludedBy = @($Selection.ExcludeTestId | Where-Object { $_.Contains('*') -and "$($r.ParentId).*" -like $_ })
        }
        if ($excludedBy) {
            $reasons[$r.Key] = New-MtSelectionReason -ReasonCode 'ExcludedById' -Detail "Excluded by ID ($($excludedBy -join ', '))."
            continue
        }

        if ($Selection.TestId.Count -gt 0) {
            $includedBy = @(Test-MtIdMatch -Id $matchId -Pattern $Selection.TestId)
            if (-not $includedBy -and $r.ParentId) {
                # A pattern for the whole family, or for some of its instances, selects the family; the
                # instances it does not name are reported DeselectedAtRuntime after the run.
                $includedBy = @($Selection.TestId | Where-Object { ($_.Contains('*') -and "$($r.ParentId).*" -like $_) -or $_ -like "$($r.ParentId).*" })
            }
            if (-not $includedBy) {
                $reasons[$r.Key] = New-MtSelectionReason -ReasonCode 'NotSelected' -Detail 'Not in the list of test IDs to run.'
                continue
            }
            $exact = @($includedBy | Where-Object { -not $_.Contains('*') })
            if ($exact) {
                if ($r.Tags -contains 'Preview') { $liftPreview = $true }
                if ($r.Tags -contains 'LongRunning') { $liftLongRunning = $true }
            } else {
                # A wildcard match does not lift the Preview or long-running exclusion.
                if ($r.Tags -contains 'Preview' -and -not $Selection.IncludePreview -and $Selection.Tag.Count -eq 0) {
                    $reasons[$r.Key] = New-MtSelectionReason -ReasonCode 'Preview' -Detail 'Preview test. Use -IncludePreview or name its ID to run it.'
                    continue
                }
                if ($r.Tags -contains 'LongRunning' -and -not $Selection.IncludeLongRunning -and
                    -not (@($Selection.Tag) | Where-Object { $_ -in 'LongRunning', 'CAWhatIf' })) {
                    $reasons[$r.Key] = New-MtSelectionReason -ReasonCode 'LongRunning' -Detail 'Long-running test. Use -IncludeLongRunning or name its ID to run it.'
                    continue
                }
            }
        }
    }

    # IDs named by the user that match no test. Wildcards and family instances are never unknown.
    $named = @($Selection.TestId) + @($Selection.ExcludeTestId) + @($enabledRows.Keys)
    $unknown = foreach ($id in ($named | Where-Object { $_ -and -not $_.Contains('*') } | Select-Object -Unique)) {
        if ($knownIds.Contains($id)) { continue }
        if ($familyParents | Where-Object { $id -eq $_ -or $id -like "$_.*" }) { continue }
        $id
    }

    # Instances of a family that a TestSettings row disables: the family still runs, and these rows become NotRun.
    $disabledInstances = @{}
    foreach ($id in @($enabledRows.Keys)) {
        if ($enabledRows[$id].Enabled -ne $false) { continue }
        if ($familyParents | Where-Object { $id -like "$_.*" }) { $disabledInstances[$id] = $enabledRows[$id] }
    }

    [pscustomobject]@{
        ExcludeLines      = @($reasons.Keys)
        Reasons           = $reasons
        LiftPreview       = $liftPreview
        LiftLongRunning   = $liftLongRunning
        UnknownIds        = @($unknown)
        FamilyParents     = @($familyParents | Select-Object -Unique)
        DisabledInstances = $disabledInstances
    }
}

function New-MtSelectionReason {
    <#
    .SYNOPSIS
    Creates the reason object recorded for a test the engine did not run.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $ReasonCode,
        [Parameter()] [string] $Detail
    )
    [pscustomobject]@{ ReasonCode = $ReasonCode; ReasonDetail = $Detail }
}

function Get-MtFamilyParentId {
    <#
    .SYNOPSIS
    Returns the parent ID of a family from the literal start of its It name: 'MT.1024.' gives 'MT.1024'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()] [AllowNull()] [AllowEmptyString()] [string] $LiteralPrefix
    )

    if ([string]::IsNullOrWhiteSpace($LiteralPrefix)) { return $null }
    $prefix = ($LiteralPrefix -split ':', 2)[0]
    $prefix = $prefix.Trim().TrimEnd('.', '-', '_', ' ')
    if ($prefix -match '^[A-Za-z][A-Za-z0-9]*([.\-][A-Za-z0-9_]+)*$') { return $prefix }
    $null
}
