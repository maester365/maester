<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoDisabledLinkCount {
    <#
    .SYNOPSIS
    Counts the number of GPOs that have disabled GPO links.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then counts how many returned GPO reports indicate disabled links.

    .EXAMPLE
    Test-MtAdGpoDisabledLinkCount

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes the number of GPOs with disabled links.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoDisabledLinkCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = Get-MtADGpoState
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory GPO report data from Get-MtADGpoState.'
        return $false
    }

    $gpoReportsArray = @($gpoReports | Where-Object { $null -ne $_ })
    $totalCount = $gpoReportsArray.Count
    $disabledCount = @($gpoReportsArray | Where-Object { [int]$_.DisabledLinks -gt 0 }).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs | $totalCount |`n"
    $result += "| GPOs with disabled links | $disabledCount |`n"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for disabled links. $disabledCount out of $totalCount GPO(s) have disabled link(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
