function Test-MtAdTrustNonQuarantinedDetails {
    <#
    .SYNOPSIS
    Lists details of non-quarantined trusts in Active Directory.

    .DESCRIPTION
    This test retrieves detailed information about trusts that are not quarantined
    (SID filtering disabled). Non-quarantined trusts may be vulnerable to SID history
    attacks where malicious SIDs can be used to elevate privileges across trust boundaries.
    This test helps identify trusts that may need additional security controls.

    .EXAMPLE
    Test-MtAdTrustNonQuarantinedDetails

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes details of non-quarantined trusts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustNonQuarantinedDetails
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

    # Get non-quarantined trusts
    $nonQuarantinedTrusts = $trusts | Where-Object { $_.Quarantined -eq $false }
    $nonQuarantinedCount = ($nonQuarantinedTrusts | Measure-Object).Count
    $totalCount = ($trusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Trusts | $totalCount |`n"
    $result += "| Non-Quarantined Trusts | $nonQuarantinedCount |`n`n"

    if ($nonQuarantinedCount -gt 0) {
        $result += "### Non-Quarantined Trust Details`n`n"
        $result += "| Target | Direction | Intra-Forest | Trust Type |`n"
        $result += "| --- | --- | --- | --- |`n"

        foreach ($trust in $nonQuarantinedTrusts) {
            $target = $trust.Target
            $direction = $trust.Direction
            $intraForest = if ($trust.IntraForest) { "Yes" } else { "No" }
            $trustType = switch ($trust.TrustType) {
                "External" { "External" }
                "Forest" { "Forest" }
                "Kerberos" { "Kerberos" }
                default { $trust.TrustType }
            }
            $result += "| $target | $direction | $intraForest | $trustType |`n"
        }
    }

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain.`n`n%TestResult%"
    } elseif ($nonQuarantinedCount -eq 0) {
        $testResultMarkdown = "All trusts are quarantined with SID filtering enabled. Good security posture!`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Found $nonQuarantinedCount non-quarantined trust(s). These trusts may be vulnerable to SID history attacks. Consider enabling SID filtering for inter-forest trusts.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}

