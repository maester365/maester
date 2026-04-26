<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoUserSettingsDisabledDetails {
    <#
    .SYNOPSIS
    Returns details of GPOs where user settings are disabled.

    .DESCRIPTION
    This test retrieves Active Directory GPO state data using Get-MtADGpoState and returns a markdown
    table listing GPOs with GpoStatus indicating user settings are disabled.

    GpoStatus mapping:
    - 0 = AllDisabled
    - 1 = UserDisabled
    - 2 = ComputerDisabled
    - 3 = AllEnabled

    .EXAMPLE
    Test-MtAdGpoUserSettingsDisabledDetails

    Returns $true if GPO state data is accessible, $false otherwise.
    The test result includes a markdown table with the user-disabled GPOs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoUserSettingsDisabledDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoUserSettingsDisabledDetails"
    $gpoState = Get-MtADGpoState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo user settings disabled details"

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

    $userDisabled = foreach ($gpo in $gposArray) {
        $statusInt = Convert-GpoStatusToInt -Status $gpo.GpoStatus
        if ($null -ne $statusInt -and $statusInt -eq 1) { $gpo }
    }

    $userDisabledCount = @($userDisabled).Count
    $testResult = $true

    $table = "| GPO DisplayName | Id | GpoStatus | WmiFilter | Owner |`n"
    $table += '| --- | --- | --- | --- | --- |' + "`n"

    foreach ($gpo in @($userDisabled | Sort-Object -Property DisplayName)) {
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

    $recommendation = if ($userDisabledCount -gt 0) {
        "GPOs with user settings disabled were returned ($userDisabledCount).`nReview these GPOs to ensure user-side policy delivery is intentionally disabled."
    }
    else {
        '✅ No GPOs with user settings disabled were found.'
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdGpoUserSettingsDisabledDetails"
    return $testResult
}



