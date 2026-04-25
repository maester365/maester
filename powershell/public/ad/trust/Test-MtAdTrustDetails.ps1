function Test-MtAdTrustDetails {
    <#
    .SYNOPSIS
    Lists detailed information about all Active Directory trusts.

    .DESCRIPTION
    This test retrieves comprehensive details about all domain trusts configured
    in Active Directory. Trust details include target domain, trust direction,
    trust type, SID filtering status, and whether the trust is within the same
    forest. This information is essential for security audits and trust management.

    .EXAMPLE
    Test-MtAdTrustDetails

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes detailed trust configuration information.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustDetails
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

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Trusts | $totalCount |`n`n"

    if ($totalCount -gt 0) {
        $result += "### Trust Configuration Details`n`n"
        $result += "| Target | Direction | Type | Intra-Forest | Quarantined | Selective Auth |`n"
        $result += "| --- | --- | --- | --- | --- | --- |`n"

        foreach ($trust in $trusts) {
            $target = $trust.Target
            $direction = $trust.Direction
            $trustType = switch ($trust.TrustType) {
                "External" { "External" }
                "Forest" { "Forest" }
                "Kerberos" { "Kerberos" }
                default { $trust.TrustType }
            }
            $intraForest = if ($trust.IntraForest) { "Yes" } else { "No" }
            $quarantined = if ($trust.Quarantined) { "Yes" } else { "No" }
            $selectiveAuth = if ($trust.SelectiveAuthentication) { "Yes" } else { "No" }
            $result += "| $target | $direction | $trustType | $intraForest | $quarantined | $selectiveAuth |`n"
        }
    }

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No Active Directory trusts are configured in this domain.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Active Directory trust configuration details are listed below.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
