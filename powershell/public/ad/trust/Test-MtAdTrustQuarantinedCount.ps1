function Test-MtAdTrustQuarantinedCount {
    <#
    .SYNOPSIS
    Counts the number of quarantined trusts in Active Directory.

    .DESCRIPTION
    This test retrieves the count of quarantined (SID filtering enabled) trusts in Active Directory.
    Quarantined trusts have SID filtering enabled, which prevents malicious SID history from being
    used to elevate privileges across the trust boundary. This is a critical security control for
    inter-forest trusts.

    .EXAMPLE
    Test-MtAdTrustQuarantinedCount

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes the count of quarantined trusts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustQuarantinedCount
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

    # Count quarantined trusts (SID filtering enabled)
    $quarantinedTrusts = $trusts | Where-Object { $_.Quarantined -eq $true }
    $quarantinedCount = ($quarantinedTrusts | Measure-Object).Count
    $totalCount = ($trusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Trusts | $totalCount |`n"
    $result += "| Quarantined Trusts | $quarantinedCount |`n"
    $result += "| Non-Quarantined Trusts | $($totalCount - $quarantinedCount) |`n`n"

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain.`n`n%TestResult%"
    } elseif ($quarantinedCount -eq 0) {
        $testResultMarkdown = "No trusts are quarantined (SID filtering disabled). Consider enabling SID filtering on inter-forest trusts to prevent privilege escalation attacks.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$quarantinedCount trust(s) are quarantined with SID filtering enabled. This helps prevent privilege escalation attacks across trust boundaries.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
