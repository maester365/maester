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
        Title = 'Applicable trusts should have strong SID filtering with no weak findings',
        Product = 'ad',
        Feature = 'trusts',
        Area = 'external-access',
        ResourceType = 'Trust',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1134.005',
        Control = ('nist-800-53-r5:AC-4', 'nist-800-53-r5:SC-7'),
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:trustedDomain:ReadProperty'),
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
        throw 'Active Directory trust inventory was not returned.'
    }

    $trusts = $adState.Trusts
    if ($null -eq $trusts) { throw 'Active Directory trusts were not returned.' }

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
    # Only external Windows trusts and forest trusts have applicable flags.
    $evaluatedTrusts = @($trusts | Where-Object {
        $bits = [int]$_.TrustAttributes
        $null -ne $_.TrustAttributes -and $null -ne $_.TrustType -and ($bits -band 0x400) -eq 0 -and
        ((($bits -band 0x8) -ne 0) -or (($bits -band 0x20) -eq 0 -and [int]$_.TrustType -in 1, 2))
    })
    $strongTrusts = @($evaluatedTrusts | Where-Object {
        $bits = [int]$_.TrustAttributes
        if (($bits -band 0x8) -ne 0) { ($bits -band 0x40) -eq 0 }
        else { ($bits -band 0x4) -ne 0 }
    })
    $strongCount = ($strongTrusts | Measure-Object).Count
    $evaluatedCount = ($evaluatedTrusts | Measure-Object).Count
    $totalCount = ($trusts | Measure-Object).Count

    # A missing bitmask is not evidence of a protected trust.
    $unknownCount = @($trusts | Where-Object { $null -eq $_.TrustAttributes -or $null -eq $_.TrustType }).Count
    $pimCount = @($trusts | Where-Object { $null -ne $_.TrustAttributes -and ([int]$_.TrustAttributes -band 0x400) -ne 0 }).Count
    $testResult = $strongCount -eq $evaluatedCount -and $unknownCount -eq 0

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Trusts | $totalCount |" + "`n"
    $result += "| Evaluated Trusts (External/Forest) | $evaluatedCount |" + "`n"
    $result += "| Strong SID Filtering | $strongCount |" + "`n"
    $result += "| Weak SID Filtering | $($evaluatedCount - $strongCount) |" + "`n" + "`n"
    $result += "| Unknown Trust Attributes or Type | $unknownCount |" + "`n"
    $result += "| PIM Trusts Excluded (manual review) | $pimCount |" + "`n"
    $weakTrusts = @($evaluatedTrusts | Where-Object {
        $bits = [int]$_.TrustAttributes
        if (($bits -band 0x8) -ne 0) { ($bits -band 0x40) -ne 0 }
        else { ($bits -band 0x4) -eq 0 }
    })
    if ($weakTrusts.Count -gt 0) {
        $result += "`n**Trusts with weak SID filtering:**`n`n"
        $result += "| Target | Direction | Type | Reason |`n| --- | --- | --- | --- |`n"
        foreach ($trust in $weakTrusts) {
            $reason = if (([int]$trust.TrustAttributes -band 0x8) -ne 0) { 'Forest trust: TREAT_AS_EXTERNAL set (SID history permitted)' } else { 'External trust: QUARANTINED_DOMAIN not set' }
            $result += "| $($trust.TrustPartner) | $($trust.Direction) | $($trust.TrustTypeName) | $reason |`n"
        }
    }
    if ($unknownCount -gt 0) {
        $result += "`n**Trusts with unknown configuration:**`n`n| Target | Direction |`n| --- | --- |`n"
        foreach ($trust in ($trusts | Where-Object { $null -eq $_.TrustAttributes -or $null -eq $_.TrustType })) {
            $result += "| $($trust.TrustPartner) | $($trust.Direction) |`n"
        }
    }

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No trusts are configured in this domain.`n`n%TestResult%"
    } elseif ($unknownCount -gt 0) {
        $testResultMarkdown = "Trust SID filtering cannot be confirmed: $unknownCount trust(s) lack trust attributes or type. Review the missing data and any weak trusts listed in the count.`n`n%TestResult%"
    } elseif ($evaluatedCount -eq 0) {
        $testResultMarkdown = "No non-PIM external or forest trusts are eligible for this SID-filtering check. Within-forest and MIT trusts are excluded; review $pimCount PIM trust(s) under their separate filtering rules.`n`n%TestResult%"
    } elseif ($strongCount -eq 0 -and $evaluatedCount -gt 0) {
        $testResultMarkdown = "No external/forest trusts have strong SID filtering. Consider enabling SID filtering on external trusts and disabling SID history on forest trusts to prevent privilege escalation attacks.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$(if ($testResult) { 'Well done.' } else { 'Review weak filtering.' }) $strongCount of $evaluatedCount external/forest trust(s) have strong SID filtering.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
