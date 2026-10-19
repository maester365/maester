function Test-MtAdTrustStaleCount {
    <#
    .SYNOPSIS
    Counts the number of stale trusts in Active Directory (trusts not validated within the configured threshold).

    .DESCRIPTION
    This test retrieves the count of stale trusts in Active Directory. Stale trusts
    are those that have not been validated beyond the configured threshold (default 60 days), which may indicate
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
    [MaesterTest(
        Id = 'AD-TRUST-06',
        Title = 'Trust stale count should be investigated',
        Product = 'ad',
        Feature = 'trusts',
        Area = 'external-access',
        ResourceType = 'Trust',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Age, in days, after which a trust is considered stale.
        [ValidateRange(1, 3650)] [int] $StaleThresholdDays = 60
    )

    Write-Verbose "Starting Test-MtAdTrustStaleCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Trusts')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $trusts = $adState.Trusts
    $totalCount = ($trusts | Measure-Object).Count

    # Define stale threshold
    $staleThreshold = (Get-Date).AddDays(-$StaleThresholdDays)

    # Count stale trusts (those not validated within the configured threshold)
    $staleTrusts = $trusts | Where-Object {
        $null -ne $_.LastValidated -and $_.LastValidated -lt $staleThreshold
    }
    $staleCount = ($staleTrusts | Measure-Object).Count

    # Count trusts with unknown validation status (null LastValidated)
    $unknownTrusts = $trusts | Where-Object { $null -eq $_.LastValidated }
    $unknownCount = ($unknownTrusts | Measure-Object).Count
    $mostRecentValidation = $trusts |
        Where-Object { $null -ne $_.LastValidated } |
        Sort-Object LastValidated -Descending |
        Select-Object -First 1 -ExpandProperty LastValidated
    if ($null -eq $mostRecentValidation) {
        $mostRecentValidation = 'unknown'
    } else {
        $mostRecentValidation = $mostRecentValidation.ToString('yyyy-MM-dd')
    }

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Trusts | $totalCount |" + "`n"
    $result += "| Stale Trusts (>$StaleThresholdDays days) | $staleCount |" + "`n"
    $result += "| Unknown Validation Status | $unknownCount |" + "`n"
    $result += "| Valid Trusts | $($totalCount - $staleCount - $unknownCount) |" + "`n" + "`n"

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain. The analysis would change if one or more trusts were created.`n`n%TestResult%"
    } elseif ($staleCount -eq 0) {
        $testResultMarkdown = "All $totalCount configured trusts have been validated within the last $StaleThresholdDays days. The most recent validation was on $mostRecentValidation.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Found $staleCount stale trust(s) that have not been validated for more than $StaleThresholdDays days. These trusts should be reviewed and removed if no longer needed.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
