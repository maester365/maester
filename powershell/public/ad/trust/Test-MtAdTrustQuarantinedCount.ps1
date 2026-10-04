function Test-MtAdTrustQuarantinedCount {
    <#
    .SYNOPSIS
    Counts the number of quarantined external/forest trusts in Active Directory.

    .DESCRIPTION
    This test retrieves the count of quarantined (SID filtering enabled) external and forest trusts.
    Quarantined trusts have SID filtering enabled, which prevents malicious SID history from being
    used to elevate privileges across the trust boundary. This is a critical security control for
    inter-forest trusts. Intra-forest (parent-child) trusts are excluded because they do not support
    quarantine.

    Quarantine status is derived from the trustAttributes LDAP attribute (bit 0x4 = QUARANTINED_DOMAIN).

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

    Write-Verbose "Starting Test-MtAdTrustQuarantinedCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Trusts')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $trusts = $adState.Trusts

    # Derive Quarantined and IntraForest from trustAttributes bitmask
    # 0x4 = QUARANTINED_DOMAIN (SID filtering enabled)
    # 0x20 = WITHIN_FOREST (parent-child intra-forest trust)
    foreach ($trust in $trusts) {
        $trustAttributes = [int]$trust.TrustAttributes
        $trust | Add-Member -NotePropertyName Quarantined -NotePropertyValue (($trustAttributes -band 0x4) -ne 0) -Force
        $trust | Add-Member -NotePropertyName IntraForest -NotePropertyValue (($trustAttributes -band 0x20) -ne 0) -Force
    }

    # Only evaluate external/forest trusts for quarantine — intra-forest trusts do not support it
    $externalTrusts = $trusts | Where-Object { -not $_.IntraForest }
    $quarantinedTrusts = $externalTrusts | Where-Object { $_.Quarantined }
    $quarantinedCount = ($quarantinedTrusts | Measure-Object).Count
    $externalCount = ($externalTrusts | Measure-Object).Count
    $totalCount = ($trusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Trusts | $totalCount |" + "`n"
    $result += "| External/Forest Trusts | $externalCount |" + "`n"
    $result += "| Quarantined Trusts | $quarantinedCount |" + "`n"
    $result += "| Non-Quarantined Trusts | $($externalCount - $quarantinedCount) |" + "`n" + "`n"

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain.`n`n%TestResult%"
    } elseif ($externalCount -eq 0) {
        $testResultMarkdown = "No external or forest trusts are configured. Only intra-forest trusts exist, which do not support quarantine.`n`n%TestResult%"
    } elseif ($quarantinedCount -eq 0) {
        $testResultMarkdown = "No external/forest trusts are quarantined (SID filtering disabled). Consider enabling SID filtering on inter-forest trusts to prevent privilege escalation attacks.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$quarantinedCount external/forest trust(s) are quarantined with SID filtering enabled. This helps prevent privilege escalation attacks across trust boundaries.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
