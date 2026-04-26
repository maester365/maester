function Test-MtAdTrustStaleCount {
    <#
    .SYNOPSIS
    Counts the number of stale trusts in Active Directory (trusts not validated for >60 days).

    .DESCRIPTION
    This test retrieves the count of stale trusts in Active Directory. Stale trusts
    are those that have not been validated for more than 60 days, which may indicate
    connectivity issues, decommissioned domains, or trusts that are no longer needed.
    Stale trusts should be reviewed and removed if no longer required to reduce
    the attack surface.

    .EXAMPLE
    Test-MtAdTrustStaleCount

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes the count of stale trusts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustStaleCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $trusts = $adState.Trusts
    $totalCount = ($trusts | Measure-Object).Count

    # Define stale threshold (60 days)
    $staleThreshold = (Get-Date).AddDays(-60)

    # Count stale trusts (those not validated in 60+ days)
    $staleTrusts = $trusts | Where-Object {
        $null -ne $_.LastValidated -and $_.LastValidated -lt $staleThreshold
    }
    $staleCount = ($staleTrusts | Measure-Object).Count

    # Count trusts with unknown validation status (null LastValidated)
    $unknownTrusts = $trusts | Where-Object { $null -eq $_.LastValidated }
    $unknownCount = ($unknownTrusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Trusts | $totalCount |`n"
    $result += "| Stale Trusts (>60 days) | $staleCount |`n"
    $result += "| Unknown Validation Status | $unknownCount |`n"
    $result += "| Valid Trusts | $($totalCount - $staleCount - $unknownCount) |`n`n"

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain.`n`n%TestResult%"
    } elseif ($staleCount -eq 0) {
        $testResultMarkdown = "No stale trusts detected. All configured trusts have been validated within the last 60 days.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Found $staleCount stale trust(s) that have not been validated for more than 60 days. These trusts should be reviewed and removed if no longer needed.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


