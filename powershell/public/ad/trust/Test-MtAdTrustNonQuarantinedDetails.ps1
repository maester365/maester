function Test-MtAdTrustNonQuarantinedDetails {
    <#
    .SYNOPSIS
    Lists details of non-quarantined external trusts in Active Directory.

    .DESCRIPTION
    This test retrieves detailed information about external and forest trusts that are not quarantined
    (SID filtering disabled). Non-quarantined inter-forest trusts may be vulnerable to SID history
    attacks where malicious SIDs can be used to elevate privileges across trust boundaries.
    Intra-forest (parent-child) trusts are excluded because they do not support quarantine.

    Quarantine status is derived from the trustAttributes LDAP attribute (bit 0x4 = QUARANTINED_DOMAIN).

    .EXAMPLE
    Test-MtAdTrustNonQuarantinedDetails

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes details of non-quarantined external/forest trusts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustNonQuarantinedDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdTrustNonQuarantinedDetails"

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
    $nonQuarantinedTrusts = $externalTrusts | Where-Object { -not $_.Quarantined }
    $nonQuarantinedCount = ($nonQuarantinedTrusts | Measure-Object).Count
    $externalCount = ($externalTrusts | Measure-Object).Count
    $totalCount = ($trusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Trusts | $totalCount |" + "`n"
    $result += "| External/Forest Trusts | $externalCount |" + "`n"
    $result += "| Non-Quarantined External/Forest Trusts | $nonQuarantinedCount |" + "`n" + "`n"

    if ($nonQuarantinedCount -gt 0) {
        $result += "### Non-Quarantined Trust Details" + "`n" + "`n"
        $result += "| Target | Direction | Type | Quarantined |" + "`n"
        $result += "| --- | --- | --- | --- |" + "`n"

        foreach ($trust in $nonQuarantinedTrusts) {
            $target = $trust.TrustPartner
            $direction = switch ([int]$trust.TrustDirection) {
                1 { "Inbound" }
                2 { "Outbound" }
                3 { "Bidirectional" }
                default { $trust.TrustDirection }
            }
            $trustType = switch ([int]$trust.TrustType) {
                1 { "External (Downlevel)" }
                2 { "Domain (Uplevel)" }
                3 { "MIT (Kerberos)" }
                4 { "DCE" }
                default { "Type $($trust.TrustType)" }
            }
            $quarantined = if ($trust.Quarantined) { "Yes" } else { "No" }
            $result += "| $target | $direction | $trustType | $quarantined |" + "`n"
        }
    }

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain.`n`n%TestResult%"
    } elseif ($externalCount -eq 0) {
        $testResultMarkdown = "No external or forest trusts are configured. Only intra-forest trusts exist, which do not support quarantine.`n`n%TestResult%"
    } elseif ($nonQuarantinedCount -eq 0) {
        $testResultMarkdown = "All external/forest trusts are quarantined with SID filtering enabled. Good security posture!`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Found $nonQuarantinedCount non-quarantined external/forest trust(s). These trusts may be vulnerable to SID history attacks. Consider enabling SID filtering.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
