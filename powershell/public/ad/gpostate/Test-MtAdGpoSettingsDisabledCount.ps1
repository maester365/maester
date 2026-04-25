<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoSettingsDisabledCount {
    <#
    .SYNOPSIS
    Counts GPOs where settings are disabled (AllDisabled, UserDisabled, or ComputerDisabled).

    .DESCRIPTION
    This test retrieves Active Directory GPO state data using Get-MtADGpoState and counts how many
    returned GPOs have GpoStatus values indicating disabled settings.

    GpoStatus mapping:
    - 0 = AllDisabled
    - 1 = UserDisabled
    - 2 = ComputerDisabled
    - 3 = AllEnabled

    .EXAMPLE
    Test-MtAdGpoSettingsDisabledCount

    Returns $true if GPO state data is accessible, $false otherwise.
    The test result includes disabled vs total GPO counts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoSettingsDisabledCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = Get-MtADGpoState
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpos = $gpoState.GPOs
    if ($null -eq $gpos) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory Group Policy Objects (GPOs) from Get-MtADGpoState.'
        return $false
    }

    function Convert-GpoStatusToInt {
        param([object]$Status)

        if ($null -eq $Status) { return $null }

        $s = [string]$Status
        if ($s -match '^\s*(\d+)\s*$') { return [int]$Matches[1] }
        switch -Regex ($s) {
            'AllDisabled' { return 0 }
            'UserDisabled' { return 1 }
            'ComputerDisabled' { return 2 }
            'AllEnabled' { return 3 }
        }

        return $null
    }

    $gposArray = @($gpos | Where-Object { $null -ne $_ })
    $totalCount = $gposArray.Count

    $disabledGpos = foreach ($gpo in $gposArray) {
        $statusInt = Convert-GpoStatusToInt -Status $gpo.GpoStatus
        if ($null -ne $statusInt -and $statusInt -in 0,1,2) { $gpo }
    }

    $disabledCount = @($disabledGpos).Count
    $testResult = $true

    $disabledPercentage = if ($totalCount -gt 0) { [Math]::Round(($disabledCount / $totalCount) * 100, 2) } else { 0 }

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs (state) | $totalCount |`n"
    $result += "| GPOs with disabled settings | $disabledCount |`n"
    $result += "| Disabled ratio | $disabledPercentage% |`n"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for disabled settings. $disabledCount out of $totalCount GPO(s) have disabled settings (GpoStatus 0, 1, or 2).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
