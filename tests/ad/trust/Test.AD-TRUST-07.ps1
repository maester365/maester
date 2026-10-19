function Test-MtAdTrustStaleDetails {
    <#
    .SYNOPSIS
    Lists detailed information about stale trusts in Active Directory.

    .DESCRIPTION
    This test retrieves detailed information about trusts that have not been validated
    beyond the configured threshold (default 60 days). Stale trusts may indicate connectivity issues, decommissioned
    domains, or trusts that are no longer needed. This test helps identify specific
    trusts that should be reviewed and potentially removed to reduce the attack surface.

    .EXAMPLE
    Test-MtAdTrustStaleDetails

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes details of stale trusts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustStaleDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-TRUST-07',
        Title = 'Trust stale details should be investigated',
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

    Write-Verbose "Starting Test-MtAdTrustStaleDetails"

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

    # Get stale trusts (those not validated within the configured threshold)
    $staleTrusts = $trusts | Where-Object {
        $null -ne $_.LastValidated -and $_.LastValidated -lt $staleThreshold
    } | Sort-Object LastValidated

    $staleCount = ($staleTrusts | Measure-Object).Count
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
    $result += "| Stale Trusts (>$StaleThresholdDays days) | $staleCount |" + "`n" + "`n"

    if ($staleCount -gt 0) {
        $result += "### Stale Trust Details" + "`n" + "`n"
        $result += "| Target | Direction | Last Validated | Days Since Validation | Type |" + "`n"
        $result += "| --- | --- | --- | --- | --- |" + "`n"

        foreach ($trust in $staleTrusts) {
            $target = $trust.Target
            $direction = $trust.Direction
            $lastValidated = $trust.LastValidated
            $daysSince = [Math]::Floor(((Get-Date) - $lastValidated).TotalDays)
            $trustType = switch ($trust.TrustType) {
                "External" { "External" }
                "Forest" { "Forest" }
                "Kerberos" { "Kerberos" }
                default { $trust.TrustType }
            }
            $result += "| $target | $direction | $($lastValidated.ToString('yyyy-MM-dd')) | $daysSince | $trustType |" + "`n"
        }
    }

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain. The analysis would change if one or more trusts were created.`n`n%TestResult%"
    } elseif ($staleCount -eq 0) {
        $knownValidationCount = ($trusts | Where-Object { $null -ne $_.LastValidated } | Measure-Object).Count
        if ($knownValidationCount -lt $totalCount) {
            $unknownCount = $totalCount - $knownValidationCount
            $testResultMarkdown = "No stale trusts detected. $unknownCount trust(s) have an unknown validation status. The remaining $knownValidationCount configured trust(s) have been validated within the last $StaleThresholdDays days. The most recent validation was on $mostRecentValidation.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "All $totalCount configured trusts have been validated within the last $StaleThresholdDays days. The most recent validation was on $mostRecentValidation.`n`n%TestResult%"
        }
    } else {
        $testResultMarkdown = "Found $staleCount stale trust(s) that have not been validated for more than $StaleThresholdDays days. These trusts should be reviewed and removed if the target domain is no longer accessible or needed.`n`n%TestResult%"
    }

    if ($totalCount -gt 0) {
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", ""
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
