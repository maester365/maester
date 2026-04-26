<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoVersionMismatchCount {
    <#
    .SYNOPSIS
    Counts the number of GPOs with a version mismatch.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then counts how many returned GPO reports indicate a version mismatch.

    .EXAMPLE
    Test-MtAdGpoVersionMismatchCount

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes the number of GPOs with version mismatch.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoVersionMismatchCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoVersionMismatchCount"
    $gpoState = Get-MtADGpoState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo version mismatch count"

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory GPO report data from Get-MtADGpoState.'
        return $false
    }

    $gpoReportsArray = @($gpoReports | Where-Object { $null -ne $_ })
    $totalCount = $gpoReportsArray.Count
    $mismatchCount = @($gpoReportsArray | Where-Object { [bool]$_.HasVersionMismatch }).Count

    $testResult = $true
    $mismatchPercentage = if ($totalCount -gt 0) { [Math]::Round(($mismatchCount / $totalCount) * 100, 2) } else { 0 }

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs | $totalCount |`n"
    $result += "| GPOs with version mismatch | $mismatchCount |`n"
    $result += "| Mismatch ratio | $mismatchPercentage% |`n"
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for version mismatches. $mismatchCount out of $totalCount GPO(s) indicate a version mismatch.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdGpoVersionMismatchCount"
    return $testResult
}


