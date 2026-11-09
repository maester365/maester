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
        Title = 'Trust validation age and unknown dates should be investigated',
        Product = 'ad',
        Feature = 'trusts',
        Area = 'external-access',
        ResourceType = 'Trust',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:trustedDomain:ReadProperty'),
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
        throw 'Active Directory trust inventory was not returned.'
    }

    $trusts = $adState.Trusts
    if ($null -eq $trusts) { throw 'Active Directory trusts were not returned.' }
    $totalCount = ($trusts | Measure-Object).Count

    # Define stale threshold
    $staleThreshold = (Get-Date).AddDays(-$StaleThresholdDays)

    # Count stale trusts (those not validated within the configured threshold)
    $staleTrusts = @($trusts | Where-Object {
        $null -ne $_.LastValidated -and [datetime]$_.LastValidated -lt $staleThreshold
    })
    $staleCount = ($staleTrusts | Measure-Object).Count

    # Count trusts with unknown validation status (null LastValidated)
    $unknownTrusts = @($trusts | Where-Object { $null -eq $_.LastValidated })
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

    # The safe LDAP inventory has no LastValidated field. Never infer validation from whenChanged.
    $testResult = $null -ne $adState.Trusts

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Trusts | $totalCount |" + "`n"
    $result += "| Stale Trusts (>$StaleThresholdDays days) | $staleCount |" + "`n"
    $result += "| Unknown Validation Status | $unknownCount |" + "`n"
    $result += "| Known dates within threshold | $($totalCount - $staleCount - $unknownCount) |" + "`n" + "`n"
    if ($totalCount -gt 0) {
        $result += "| Target | Direction | Type | Last validated | Days since validation | Assessment |`n"
        $result += "| --- | --- | --- | --- | --- | --- |`n"
        foreach ($trust in ($trusts | Sort-Object TrustPartner)) {
            if ($null -eq $trust.LastValidated) {
                $date = 'Unknown'
                $days = 'Unknown'
                $assessment = 'Cannot assess from LDAP inventory'
            } else {
                $validated = [datetime]$trust.LastValidated
                $date = $validated.ToString('yyyy-MM-dd')
                $days = [Math]::Floor(((Get-Date) - $validated).TotalDays)
                $assessment = if ($validated -lt $staleThreshold) { 'Older than threshold' } else { 'Within threshold' }
            }
            $result += "| $($trust.TrustPartner) | $($trust.Direction) | $($trust.TrustTypeName) | $date | $days | $assessment |`n"
        }
    }

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain. The analysis would change if one or more trusts were created.`n`n%TestResult%"
    } elseif ($staleCount -eq 0 -and $unknownCount -eq $totalCount) {
        $testResultMarkdown = "Validation age is unknown for all $totalCount configured trusts. The safe LDAP inventory has no persisted last-validation timestamp; no stale-trust assertion can be made. Do not substitute trust object modification time.`n`n%TestResult%"
    } elseif ($staleCount -eq 0 -and $unknownCount -gt 0) {
        $testResultMarkdown = "No dated trust exceeds $StaleThresholdDays days, but $unknownCount trust(s) have no recorded validation date and cannot be assessed. The most recent known validation date was $mostRecentValidation.`n`n%TestResult%"
    } elseif ($staleCount -eq 0) {
        $testResultMarkdown = "All $totalCount trusts with known validation dates fall within $StaleThresholdDays days. The most recent recorded date was $mostRecentValidation.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Found $staleCount trust(s) with a recorded validation date older than $StaleThresholdDays days; $unknownCount trust(s) remain unassessable. Review the dated records and verify trusts independently.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
