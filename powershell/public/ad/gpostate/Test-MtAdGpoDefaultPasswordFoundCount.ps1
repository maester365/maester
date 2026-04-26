<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoDefaultPasswordFoundCount {
    <#
    .SYNOPSIS
    Counts the number of GPOs that contain a default password (decoded from cpassword).

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then counts how many returned GPO reports indicate DefaultPasswordFound was true.

    .EXAMPLE
    Test-MtAdGpoDefaultPasswordFoundCount

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes the number of GPOs with DefaultPasswordFound.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoDefaultPasswordFoundCount
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
    $defaultPasswordCount = @($gpoReportsArray | Where-Object { [bool]$_.DefaultPasswordFound }).Count

    $testResult = $true
    $defaultPasswordPercentage = if ($totalCount -gt 0) { [Math]::Round(($defaultPasswordCount / $totalCount) * 100, 2) } else { 0 }

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs | $totalCount |`n"
    $result += "| GPOs with default password | $defaultPasswordCount |`n"
    $result += "| Default password ratio | $defaultPasswordPercentage% |`n"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for default password usage. $defaultPasswordCount out of $totalCount GPO(s) contain a default password.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}


