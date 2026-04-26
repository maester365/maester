function Test-MtAdUserSpnSetCount {
    <#
    .SYNOPSIS
    Counts users with SPNs configured in Active Directory.

    .DESCRIPTION
    This test identifies user objects with one or more Service Principal Names (SPNs)
    configured. User-based SPNs often represent service accounts and can be high-value
    targets for Kerberoasting. Tracking the volume of user accounts with SPNs helps
    identify service account exposure and operational patterns that require review.

    .EXAMPLE
    Test-MtAdUserSpnSetCount

    Returns $true if user data is accessible, $false otherwise.
    The test result includes the count of users with SPNs configured.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserSpnSetCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserSpnSetCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user spn set count"

    $users = $adState.Users
    $usersWithSpn = $users | Where-Object {
        $_.ServicePrincipalName -and
        ($_.ServicePrincipalName | Measure-Object).Count -gt 0
    }

    $spnCount = ($usersWithSpn | Measure-Object).Count
    $totalCount = ($users | Measure-Object).Count
    $testResult = $totalCount -gt 0

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($spnCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Users with SPNs Configured | $spnCount |`n"
        $result += "| SPN Percentage | $percentage% |`n`n"
    Write-Verbose "Counts computed"

        $testResultMarkdown = "Active Directory users have been analyzed. $spnCount out of $totalCount users ($percentage%) have one or more SPNs configured.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory users. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserSpnSetCount"

    return $testResult
}


