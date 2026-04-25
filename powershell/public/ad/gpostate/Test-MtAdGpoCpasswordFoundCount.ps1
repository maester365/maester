<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoCpasswordFoundCount {
    <#
    .SYNOPSIS
    Counts the number of GPOs that contain a cpassword.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then counts how many returned GPO reports indicate a cpassword was found.

    .EXAMPLE
    Test-MtAdGpoCpasswordFoundCount

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes the number of GPOs with cpassword present.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoCpasswordFoundCount
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
    $cpasswordCount = @($gpoReportsArray | Where-Object { [bool]$_.CpasswordFound }).Count

    $testResult = $true
    $cpasswordPercentage = if ($totalCount -gt 0) { [Math]::Round(($cpasswordCount / $totalCount) * 100, 2) } else { 0 }

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs | $totalCount |`n"
    $result += "| GPOs with cpassword | $cpasswordCount |`n"
    $result += "| cpassword ratio | $cpasswordPercentage% |`n"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for cpassword usage. $cpasswordCount out of $totalCount GPO(s) contain a cpassword.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
