function Test-MtAdTrustNonQuarantinedDetails {
    <#
    .SYNOPSIS
    Lists details of trusts with weak SID filtering in Active Directory.

    .DESCRIPTION
    This test retrieves detailed information about external and forest trusts that have weak
    SID filtering. For external trusts, weakness means the QUARANTINED_DOMAIN bit (0x4) is not set.
    For forest trusts, weakness means the TREAT_AS_EXTERNAL bit (0x40) is set (SID history enabled).
    Intra-forest (parent-child) trusts are excluded because they do not support quarantine.
    MIT Kerberos realm trusts are also excluded as SID filtering does not apply to them.

    Trust classification is derived from the trustAttributes LDAP attribute and trustType.

    .EXAMPLE
    Test-MtAdTrustNonQuarantinedDetails

    Returns $true if all evaluated trusts have strong SID filtering, $false if any are weak.
    The test result includes details of trusts with weak SID filtering.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustNonQuarantinedDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-TRUST-04',
        Title = 'No trusts should lack SID filtering (quarantine)',
        Severity = 'High',
        Category = 'Active Directory - Trusts',
        Tag = 'AD.Trust',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
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

    # Derive trust classification and SID filtering status from trustAttributes bitmask
    # trustAttributes bits:
    #   0x4  = QUARANTINED_DOMAIN (SID filtering enabled on external trusts)
    #   0x8  = FOREST_TRANSITIVE (forest trust)
    #   0x20 = WITHIN_FOREST (parent-child intra-forest trust)
    #   0x40 = TREAT_AS_EXTERNAL (SID history enabled on forest trusts)
    # trustType values:
    #   1 = DOWNLEVEL (Windows NT 4 external)
    #   2 = UPLEVEL (Windows 2000+ AD domain)
    #   3 = MIT (Kerberos realm) — SID filtering does not apply
    #   4 = DCE
    foreach ($trust in $trusts) {
        $trustAttributes = [int]$trust.TrustAttributes
        $trustType = [int]$trust.TrustType

        $isForest   = ($trustAttributes -band 0x8) -ne 0
        $isExternal = -not $isForest -and -not ($trustAttributes -band 0x20) -and ($trustType -in 1,2)
        $isMit      = ($trustType -eq 3)

        # SID filtering weakness:
        # - External trusts: weak if QUARANTINED_DOMAIN (0x4) is NOT set
        # - Forest trusts: weak if TREAT_AS_EXTERNAL (0x40) IS set (SID history enabled)
        # - MIT trusts: excluded from evaluation
        $sidFilteringWeak = ($isExternal -and -not ($trustAttributes -band 0x4)) -or
                            ($isForest -and ($trustAttributes -band 0x40))

        $trust | Add-Member -NotePropertyName IsForest -NotePropertyValue $isForest -Force
        $trust | Add-Member -NotePropertyName IsExternal -NotePropertyValue $isExternal -Force
        $trust | Add-Member -NotePropertyName IsMit -NotePropertyValue $isMit -Force
        $trust | Add-Member -NotePropertyName SidFilteringWeak -NotePropertyValue $sidFilteringWeak -Force
    }

    # Only evaluate external/forest trusts for SID filtering weakness
    # Intra-forest trusts do not support quarantine; MIT trusts are excluded
    $evaluatedTrusts = $trusts | Where-Object { $_.IsExternal -or $_.IsForest }
    $weakTrusts = $evaluatedTrusts | Where-Object { $_.SidFilteringWeak }
    $weakCount = ($weakTrusts | Measure-Object).Count
    $evaluatedCount = ($evaluatedTrusts | Measure-Object).Count
    $totalCount = ($trusts | Measure-Object).Count

    # Test fails if any evaluated trusts have weak SID filtering
    $testResult = ($weakCount -eq 0)

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Trusts | $totalCount |" + "`n"
    $result += "| Evaluated Trusts (External/Forest) | $evaluatedCount |" + "`n"
    $result += "| Trusts with Weak SID Filtering | $weakCount |" + "`n" + "`n"

    if ($weakCount -gt 0) {
        $result += "### Trusts with Weak SID Filtering" + "`n" + "`n"
        $result += "| Target | Direction | Type | Forest | External | Weak Reason |" + "`n"
        $result += "| --- | --- | --- | --- | --- | --- |" + "`n"

        foreach ($trust in $weakTrusts) {
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
            $isForestStr = if ($trust.IsForest) { "Yes" } else { "No" }
            $isExternalStr = if ($trust.IsExternal) { "Yes" } else { "No" }
            $weakReason = if ($trust.IsForest) { "TREAT_AS_EXTERNAL (SID history enabled)" } else { "QUARANTINED_DOMAIN not set" }
            $result += "| $target | $direction | $trustType | $isForestStr | $isExternalStr | $weakReason |" + "`n"
        }
    }

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain.`n`n%TestResult%"
    } elseif ($evaluatedCount -eq 0) {
        $testResultMarkdown = "No external or forest trusts are configured. Only intra-forest or MIT trusts exist, which are not evaluated for SID filtering.`n`n%TestResult%"
    } elseif ($weakCount -eq 0) {
        $testResultMarkdown = "All external/forest trusts have strong SID filtering. Good security posture!`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Found $weakCount trust(s) with weak SID filtering. External trusts lacking quarantine or forest trusts with SID history enabled may be vulnerable to privilege escalation.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
