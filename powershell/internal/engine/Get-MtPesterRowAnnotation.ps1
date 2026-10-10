function Get-MtPesterRowAnnotation {
    <#
    .SYNOPSIS
    Computes the 3.0 fields of a result row produced by the Pester provider (design section 9).

    .DESCRIPTION
    Returns Format, ReasonCode, ReasonDetail, ParentId, InstanceId and, when the row must change, an
    overriding Result or Id. Reason codes come from the closed list in appendix A.1:

    - NotRun rows: the reason recorded by the selection plan (ExcludedById, NotSelected, DisabledByConfig,
      NotListed, Preview, LongRunning), DryRun for a test that would have run, or the tag rule that
      filtered it out (Preview, LongRunning, OptInServiceNotConnected, ExcludedByTag, NotSelected).
    - Skipped rows: TestSkipped, or NotApplicable when that is the skip code.
    - Error rows: TestError.
    - A family instance that ran although the run named other instances: NotRun, DeselectedAtRuntime.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # A test object from the Pester result.
        [Parameter(Mandatory)]
        [object] $Test,

        # The ID and Result the 2.x conversion computed for the row.
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Id,
        [Parameter(Mandatory)] [string] $Result,

        # The row's ResultDetail.
        [Parameter()] [AllowNull()] [object] $ResultDetail,

        # Run context built by Invoke-Maester; may be null when the converter is called on its own.
        [Parameter()] [AllowNull()] [object] $RunContext
    )

    $annotation = [ordered]@{
        Format         = 'Pester'
        ReasonCode     = $null
        ReasonDetail   = $null
        ParentId       = $null
        InstanceId     = $null
        ResultOverride = $null
        IdOverride     = $null
    }

    # Families: an It whose name is built at run time.
    $template = [string]$Test.Name
    $firstDynamic = @($template.IndexOf('<'), $template.IndexOf('$')) | Where-Object { $_ -ge 0 } | Sort-Object | Select-Object -First 1
    if ($null -ne $firstDynamic) {
        $parentId = Get-MtFamilyParentId -LiteralPrefix $template.Substring(0, $firstDynamic)
        if ($parentId) {
            $annotation.ParentId = $parentId
            if ($Test.ExpandedName -eq $Test.Name) {
                # Not expanded (discovery only, for example -DryRun): the row stands for the family.
                $annotation.IdOverride = $parentId
            } else {
                $annotation.InstanceId = $Id
            }
        }
    }

    $selection = if ($RunContext) { $RunContext.Selection } else { $null }
    $plan = if ($RunContext) { $RunContext.Plan } else { $null }
    $file = $Test.ScriptBlock.File
    $key = if ($file) { "$($file):$($Test.StartLine)" } else { $null }

    # A family instance that ran although the run named only some instances, or excluded this one.
    if ($annotation.InstanceId -and $selection -and $Result -ne 'NotRun') {
        $named = @(Test-MtIdMatch -Id $Id -Pattern $selection.TestId) + @(Test-MtIdMatch -Id $annotation.ParentId -Pattern $selection.TestId)
        $wholeFamily = @($selection.TestId | Where-Object { $_.Contains('*') -and "$($annotation.ParentId).*" -like $_ })
        $deselected = ($selection.TestId.Count -gt 0 -and -not $named -and -not $wholeFamily) -or
            @(Test-MtIdMatch -Id $Id -Pattern $selection.ExcludeTestId).Count -gt 0
        if ($deselected) {
            $annotation.ResultOverride = 'NotRun'
            $annotation.ReasonCode = 'DeselectedAtRuntime'
            $annotation.ReasonDetail = 'This instance of the family ran although the run did not select it. Its result is not reported.'
            return [pscustomobject]$annotation
        }
    }

    # A family instance that a TestSettings row disables. The family ran for its other instances.
    if ($annotation.InstanceId -and $plan -and $Result -ne 'NotRun' -and $plan.PSObject.Properties['DisabledInstances'] -and
        $plan.DisabledInstances -and $plan.DisabledInstances.ContainsKey($Id)) {
        $row = $plan.DisabledInstances[$Id]
        $annotation.ResultOverride = 'NotRun'
        $annotation.ReasonCode = 'DisabledByConfig'
        $annotation.ReasonDetail = if ($row.PSObject.Properties['Reason'] -and $row.Reason) { [string]$row.Reason } else { 'Disabled in the Maester config.' }
        return [pscustomobject]$annotation
    }

    switch ($Result) {
        'NotRun' {
            if ($plan -and $key -and $plan.Reasons.Contains($key)) {
                $annotation.ReasonCode = $plan.Reasons[$key].ReasonCode
                $annotation.ReasonDetail = $plan.Reasons[$key].ReasonDetail
            } elseif ($RunContext -and $RunContext.DryRun -and $Test.ShouldRun) {
                $annotation.ReasonCode = 'DryRun'
                $annotation.ReasonDetail = 'Dry run: this test would have run.'
            } elseif ($RunContext -and -not $Test.ShouldRun) {
                $tags = @($Test.Tag) + @($Test.Block.Tag) | Where-Object { $_ }
                $parent = $Test.Block.Parent
                while ($parent) { $tags += @($parent.Tag); $parent = $parent.Parent }
                $excludeTag = @($RunContext.ExcludeTag)
                $includeTag = @($RunContext.IncludeTag)
                $hit = @($tags | Where-Object { $_ -in $excludeTag })
                if ($hit -contains 'AD' -and $RunContext.AutoExcludedTag -contains 'AD') {
                    $annotation.ReasonCode = 'OptInServiceNotConnected'
                    $annotation.ReasonDetail = 'Active Directory tests run only after Connect-Maester -Service ActiveDirectory.'
                } elseif ($hit -contains 'Preview' -and $RunContext.AutoExcludedTag -contains 'Preview') {
                    $annotation.ReasonCode = 'Preview'
                    $annotation.ReasonDetail = 'Preview test. Use -IncludePreview to run it.'
                } elseif ($hit -contains 'LongRunning' -and $RunContext.AutoExcludedTag -contains 'LongRunning') {
                    $annotation.ReasonCode = 'LongRunning'
                    $annotation.ReasonDetail = 'Long-running test. Use -IncludeLongRunning to run it.'
                } elseif ($hit) {
                    $annotation.ReasonCode = 'ExcludedByTag'
                    $annotation.ReasonDetail = "Excluded by tag ($(@($hit | Select-Object -Unique) -join ', '))."
                } elseif ($includeTag.Count -gt 0) {
                    $annotation.ReasonCode = 'NotSelected'
                    $annotation.ReasonDetail = "Matched none of the tags $($includeTag -join ', ')."
                } else {
                    $annotation.ReasonCode = 'NotSelected'
                    $annotation.ReasonDetail = 'Not selected by the Pester filter.'
                }
            }
        }
        'Skipped' {
            $code = if ($ResultDetail) { [string]$ResultDetail.TestSkipped } else { $null }
            $annotation.ReasonCode = if ($code -eq 'NotApplicable') { 'NotApplicable' } else { 'TestSkipped' }
            $annotation.ReasonDetail = if ($ResultDetail -and $ResultDetail.SkippedReason) { [string]$ResultDetail.SkippedReason } else { $null }
        }
        'Error' {
            $annotation.ReasonCode = 'TestError'
            $message = $null
            if ($ResultDetail -and $ResultDetail.TestSkipped -eq 'Error' -and $ResultDetail.SkippedReason) { $message = [string]$ResultDetail.SkippedReason }
            elseif ($Test.ErrorRecord -and $Test.ErrorRecord.Count -gt 0) { $message = [string]$Test.ErrorRecord[0].Exception.Message }
            $annotation.ReasonDetail = $message
        }
    }

    [pscustomobject]$annotation
}
