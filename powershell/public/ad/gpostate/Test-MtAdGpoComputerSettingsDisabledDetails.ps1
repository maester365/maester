<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoComputerSettingsDisabledDetails {
    <#
    .SYNOPSIS
    Returns details of GPOs where computer settings are disabled.

    .DESCRIPTION
    This test retrieves Active Directory GPO state data using Get-MtADGpoState and returns a markdown
    table listing GPOs with GpoStatus indicating computer settings are disabled.

    GpoStatus mapping:
    - 0 = AllDisabled
    - 1 = UserDisabled
    - 2 = ComputerDisabled
    - 3 = AllEnabled

    .EXAMPLE
    Test-MtAdGpoComputerSettingsDisabledDetails

    Returns $true if GPO state data is accessible, $false otherwise.
    The test result includes a markdown table with the computer-disabled GPOs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoComputerSettingsDisabledDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
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

    $computerDisabled = foreach ($gpo in $gposArray) {
        $statusInt = Convert-GpoStatusToInt -Status $gpo.GpoStatus
        if ($null -ne $statusInt -and $statusInt -eq 2) { $gpo }
    }

    $computerDisabledCount = @($computerDisabled).Count
    $testResult = $true

    $table = "| GPO DisplayName | Id | GpoStatus | WmiFilter | Owner |`n"
    $table += '| --- | --- | --- | --- | --- |' + "`n"

    foreach ($gpo in @($computerDisabled | Sort-Object -Property DisplayName)) {
        $displayName = [string]$gpo.DisplayName
        $displayName = $displayName -replace '\|', '\\&#124;'
        $id = [string]$gpo.Id
        $status = if ($null -ne $gpo.GpoStatus) { $gpo.GpoStatus } else { '' }
        $wmiFilter = [string]$gpo.WmiFilter
        $wmiFilter = $wmiFilter -replace '\|', '\\&#124;'
        $owner = if ($null -ne $gpo.Owner) { [string]$gpo.Owner } else { '' }
        $owner = $owner -replace '\|', '\\&#124;'

        $table += "| $displayName | $id | $status | $wmiFilter | $owner |`n"
    }

    $recommendation = if ($computerDisabledCount -gt 0) {
        "GPOs with computer settings disabled were returned ($computerDisabledCount).`
Review these GPOs to ensure computer-side policy delivery is intentionally disabled."
    } else {
        '✅ No GPOs with computer settings disabled were found.'
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}



