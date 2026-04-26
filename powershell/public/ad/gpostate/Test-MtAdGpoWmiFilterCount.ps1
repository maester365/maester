<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoWmiFilterCount {
    <#
    .SYNOPSIS
    Counts the number of GPOs that have a non-empty WMI filter.

    .DESCRIPTION
    This test retrieves Active Directory GPO state data using Get-MtADGpoState and counts how many
    returned GPOs have a configured WmiFilter value.

    .EXAMPLE
    Test-MtAdGpoWmiFilterCount

    Returns $true if GPO state data is accessible, $false otherwise.
    The test result includes counts of WMI-filtered vs total GPOs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoWmiFilterCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoWmiFilterCount"
    $gpoState = Get-MtADGpoState
    Write-Verbose "Retrieved AD state"

    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo wmi filter count"

    $gpos = $gpoState.GPOs
    if ($null -eq $gpos) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory Group Policy Objects (GPOs) from Get-MtADGpoState.'
        return $false
    }

    $gposArray = @($gpos | Where-Object { $null -ne $_ })
    $totalCount = $gposArray.Count

    $wmiFiltered = $gposArray | Where-Object {
        $wf = $_.WmiFilter
        -not [string]::IsNullOrWhiteSpace([string]$wf)
    }

    $wmiFilterCount = @($wmiFiltered).Count
    $testResult = $true

    $wmiPercentage = if ($totalCount -gt 0) { [Math]::Round(($wmiFilterCount / $totalCount) * 100, 2) } else { 0 }

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs (state) | $totalCount |`n"
    $result += "| GPOs with WMI Filter | $wmiFilterCount |`n"
    $result += "| WMI Filter ratio | $wmiPercentage% |`n"
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for WMI filters. $wmiFilterCount out of $totalCount GPO(s) have a WMI filter configured.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdGpoWmiFilterCount"
    return $testResult
}


