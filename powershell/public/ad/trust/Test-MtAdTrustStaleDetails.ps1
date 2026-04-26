function Test-MtAdTrustStaleDetails {
    <#
    .SYNOPSIS
    Lists detailed information about stale trusts in Active Directory.

    .DESCRIPTION
    This test retrieves detailed information about trusts that have not been validated
    for more than 60 days. Stale trusts may indicate connectivity issues, decommissioned
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

    # Get stale trusts (those not validated in 60+ days)
    $staleTrusts = $trusts | Where-Object {
        $null -ne $_.LastValidated -and $_.LastValidated -lt $staleThreshold
    } | Sort-Object LastValidated

    $staleCount = ($staleTrusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Trusts | $totalCount |`n"
    $result += "| Stale Trusts (>60 days) | $staleCount |`n`n"

    if ($staleCount -gt 0) {
        $result += "### Stale Trust Details`n`n"
        $result += "| Target | Direction | Last Validated | Days Since Validation | Type |`n"
        $result += "| --- | --- | --- | --- | --- |`n"

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
            $result += "| $target | $direction | $($lastValidated.ToString('yyyy-MM-dd')) | $daysSince | $trustType |`n"
        }
    }

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain.`n`n%TestResult%"
    } elseif ($staleCount -eq 0) {
        $testResultMarkdown = "No stale trusts detected. All configured trusts have been validated within the last 60 days.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Found $staleCount stale trust(s). These trusts should be reviewed and removed if the target domain is no longer accessible or needed.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



