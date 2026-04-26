<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoEnforcementCount {
    <#
    .SYNOPSIS
    Counts the number of GPOs that have enforced GPO links.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then counts how many returned GPO reports indicate enforced links.

    .EXAMPLE
    Test-MtAdGpoEnforcementCount

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes the number of GPOs with enforced links.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoEnforcementCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoEnforcementCount"
    $gpoState = Get-MtADGpoState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo enforcement count"

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory GPO report data from Get-MtADGpoState.'
        return $false
    }

    $gpoReportsArray = @($gpoReports | Where-Object { $null -ne $_ })
    $totalCount = $gpoReportsArray.Count
    $enforcedCount = @($gpoReportsArray | Where-Object { [int]$_.Enforcement -gt 0 }).Count

    $testResult = $true
    $enforcedPercentage = if ($totalCount -gt 0) { [Math]::Round(($enforcedCount / $totalCount) * 100, 2) } else { 0 }

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs | $totalCount |`n"
    $result += "| GPOs with enforced links | $enforcedCount |`n"
    $result += "| Enforced ratio | $enforcedPercentage% |`n"
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory GPOs have been analyzed for enforced links. $enforcedCount out of $totalCount GPO(s) have enforced link(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdGpoEnforcementCount"
    return $testResult
}


