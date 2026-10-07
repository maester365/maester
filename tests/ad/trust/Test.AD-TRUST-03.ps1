function Test-MtAdTrustQuarantinedCount {
    <#
    .SYNOPSIS
    Counts the number of trusts with strong SID filtering in Active Directory.

    .DESCRIPTION
    This test retrieves the count of external and forest trusts that have strong
    SID filtering. For external trusts, strength means the QUARANTINED_DOMAIN bit (0x4) is set.
    For forest trusts, strength means the TREAT_AS_EXTERNAL bit (0x40) is not set (SID history disabled).
    Intra-forest (parent-child) trusts are excluded because they do not support quarantine.
    MIT Kerberos realm trusts are also excluded as SID filtering does not apply to them.

    Trust classification is derived from the trustAttributes LDAP attribute and trustType.

    .EXAMPLE
    Test-MtAdTrustQuarantinedCount

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes the count of trusts with strong SID filtering.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustQuarantinedCount
    #>
    [MaesterTest(
        Id = 'AD-TRUST-03',
        Title = 'Trust quarantined count should be investigated',
        Severity = 'Info',
        Category = 'Active Directory - Trusts',
        Tag = 'AD.Trust',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
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
    $strongTrusts = $evaluatedTrusts | Where-Object { -not $_.SidFilteringWeak }
    $strongCount = ($strongTrusts | Measure-Object).Count
    $evaluatedCount = ($evaluatedTrusts | Measure-Object).Count
    $totalCount = ($trusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Trusts | $totalCount |" + "`n"
    $result += "| Evaluated Trusts (External/Forest) | $evaluatedCount |" + "`n"
    $result += "| Strong SID Filtering | $strongCount |" + "`n"
    $result += "| Weak SID Filtering | $($evaluatedCount - $strongCount) |" + "`n" + "`n"

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain.`n`n%TestResult%"
    } elseif ($evaluatedCount -eq 0) {
        $testResultMarkdown = "No external or forest trusts are configured. Only intra-forest or MIT trusts exist, which are not evaluated for SID filtering.`n`n%TestResult%"
    } elseif ($strongCount -eq 0) {
        $testResultMarkdown = "No external/forest trusts have strong SID filtering. Consider enabling SID filtering on external trusts and disabling SID history on forest trusts to prevent privilege escalation attacks.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$strongCount external/forest trust(s) have strong SID filtering. This helps prevent privilege escalation attacks across trust boundaries.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
