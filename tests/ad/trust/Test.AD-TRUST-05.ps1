function Test-MtAdTrustDetails {
    <#
    .SYNOPSIS
    Lists detailed information about all Active Directory trusts.

    .DESCRIPTION
    This test retrieves comprehensive details about all domain trusts configured
    in Active Directory. Trust details include target domain, trust direction,
    trust type, SID filtering status, and whether the trust is within the same
    forest. Properties are derived from the LDAP trustAttributes bitmask and
    trustType numeric values.

    .EXAMPLE
    Test-MtAdTrustDetails

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes detailed trust configuration information with SID filtering classification.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [MaesterTest(
        Id = 'AD-TRUST-05',
        Title = 'Trust configuration details should be investigated',
        Severity = 'Info',
        Category = 'Active Directory - Trusts',
        Tag = 'AD.Trust',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdTrustDetails"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Trusts')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $trusts = $adState.Trusts
    $totalCount = ($trusts | Measure-Object).Count

    # Derive properties from trustAttributes bitmask and trustType
    # trustAttributes bits:
    #   0x4  = QUARANTINED_DOMAIN (SID filtering enabled on external trusts)
    #   0x8  = FOREST_TRANSITIVE (forest trust)
    #   0x10 = CROSS_ORGANIZATION (selective authentication)
    #   0x20 = WITHIN_FOREST (parent-child intra-forest trust)
    #   0x40 = TREAT_AS_EXTERNAL (SID history enabled on forest trusts)
    # trustType values:
    #   1 = DOWNLEVEL (Windows NT 4 external)
    #   2 = UPLEVEL (Windows 2000+ AD domain)
    #   3 = MIT (Kerberos realm)
    #   4 = DCE
    foreach ($trust in $trusts) {
        $trustAttributes = [int]$trust.TrustAttributes
        $trustType = [int]$trust.TrustType

        $isForest   = ($trustAttributes -band 0x8) -ne 0
        $isExternal = -not $isForest -and -not ($trustAttributes -band 0x20) -and ($trustType -in 1,2)
        $isMit      = ($trustType -eq 3)
        $sidFilteringWeak = ($isExternal -and -not ($trustAttributes -band 0x4)) -or
                            ($isForest -and ($trustAttributes -band 0x40))

        $trust | Add-Member -NotePropertyName Quarantined -NotePropertyValue (($trustAttributes -band 0x4) -ne 0) -Force
        $trust | Add-Member -NotePropertyName IntraForest -NotePropertyValue (($trustAttributes -band 0x20) -ne 0) -Force
        $trust | Add-Member -NotePropertyName SelectiveAuthentication -NotePropertyValue (($trustAttributes -band 0x10) -ne 0) -Force
        $trust | Add-Member -NotePropertyName IsForest -NotePropertyValue $isForest -Force
        $trust | Add-Member -NotePropertyName IsExternal -NotePropertyValue $isExternal -Force
        $trust | Add-Member -NotePropertyName IsMit -NotePropertyValue $isMit -Force
        $trust | Add-Member -NotePropertyName SidFilteringWeak -NotePropertyValue $sidFilteringWeak -Force
    }

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Trusts | $totalCount |" + "`n" + "`n"

    if ($totalCount -gt 0) {
        $result += "### Trust Configuration Details" + "`n" + "`n"
        $result += "| Target | Direction | Type | Intra-Forest | Quarantined | Selective Auth |" + "`n"
        $result += "| --- | --- | --- | --- | --- | --- |" + "`n"

        foreach ($trust in $trusts) {
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
            $intraForest = if ($trust.IntraForest) { "Yes" } else { "No" }
            $quarantined = if ($trust.Quarantined) { "Yes" } else { "No" }
            $selectiveAuth = if ($trust.SelectiveAuthentication) { "Yes" } else { "No" }
            $result += "| $target | $direction | $trustType | $intraForest | $quarantined | $selectiveAuth |" + "`n"
        }
    }

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No Active Directory trusts are configured in this domain.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Active Directory trust configuration details are listed below.`n`n%TestResult%"
    }

    # Only include the table content when findings exist. If there are zero findings,
    # omit the table entirely by replacing the placeholder with an empty string.
    if ($totalCount -gt 0) {
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", ""
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
