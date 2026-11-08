function Test-MtAdGroupMemberForeignSidCount {
    <#
    .SYNOPSIS
    Counts the foreign SID principals in Active Directory groups.

    .DESCRIPTION
    This test identifies and counts security principals that have SIDs from external
    domains or forests. This check matches domain-account objectSids outside the
    connected domain SID prefix; it does not inspect sIDHistory or prove effective
    cross-domain access. It includes foreign-security-principal representations and
    other visible domain-account principals, but excludes well-known SID namespaces.

    .EXAMPLE
    Test-MtAdGroupMemberForeignSidCount

    Returns $true if group member data is accessible, $false otherwise.
    The test result includes the count of foreign SID principals found.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupMemberForeignSidCount
    #>
    [MaesterTest(
        Id = 'AD-GMC-06',
        Title = 'Foreign SID principals count should be investigated',
        Product = 'ad',
        Feature = 'groups',
        Area = 'external-access',
        ResourceType = 'Group',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        LongRunning = $true,
        Permission = ('ActiveDirectory:Ldap:domainDNS:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty', 'ActiveDirectory:Ldap:group.member:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Domain', 'Groups')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Error -Result 'Active Directory inventory is unavailable; the declared service gate is handled by the engine.'
        return $null
    }

    $groups = $adState.Groups
    $domainSid = if ($adState.Domain.DomainSID -is [string]) { $adState.Domain.DomainSID } else { [string]$adState.Domain.DomainSID.Value }
    if ($null -eq $groups -or [string]::IsNullOrWhiteSpace($domainSid)) { throw 'Group or domain SID collection is unavailable.' }

    $protocolConnection = New-MtAdProtocolConnection -ProtocolEvidence $adState.ProtocolEvidence

    # Collect foreign SID principals
    # Assess all visible groups; LongRunning makes this complete scan opt-in.
    $groupsToCheck = @($groups)
    $foreignSidPrincipals = @()
    $processedSids = @{}

    try {
        foreach ($group in $groupsToCheck) {
            $members = @(Get-MtLdapGroupMember -Connection $protocolConnection -GroupDistinguishedName $group.DistinguishedName)
            foreach ($member in $members) {
                $memberSid = if ($member.SID -is [string]) { $member.SID } else { [string]$member.SID.Value }
                # Check if SID is foreign (doesn't start with domain SID)
                if ($memberSid -match '^S-1-5-21-\d+-\d+-\d+-\d+$' -and -not $memberSid.StartsWith("$domainSid-")) {
                    if (-not $processedSids.ContainsKey($memberSid)) {
                        $processedSids[$memberSid] = $true

                        # Extract domain SID prefix
                        $sidString = $memberSid
                        $domainSidPrefix = $sidString -replace '-\d+$', ''

                        $foreignSidPrincipals += [PSCustomObject]@{
                            SID = $memberSid
                            DomainSID = $domainSidPrefix
                            Name = $member.Name
                            ObjectClass = $member.objectClass
                            GroupName = $group.Name
                        }
                    }
                }
            }
        }
    } finally {
        $protocolConnection.Dispose()
    }

    $foreignSidCount = $foreignSidPrincipals.Count
    $distinctDomainSids = ($foreignSidPrincipals | Select-Object -ExpandProperty DomainSID -Unique | Measure-Object).Count

    # Test passes if we successfully retrieved member data
    $testResult = $null -ne $adState.Groups

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Foreign SID Principals | $foreignSidCount |" + "`n"
        $result += "| Distinct External Domains | $distinctDomainSids |" + "`n"
        $result += "| Groups Analyzed | $($groupsToCheck.Count) |" + "`n"
        $result += "| Current Domain SID | $domainSid |" + "`n"
        if ($foreignSidCount -gt 0) {
            $result += "`n| Group | Principal | Foreign SID |" + "`n| --- | --- | --- |" + "`n"
            foreach ($principal in $foreignSidPrincipals) {
                $result += "| $($principal.GroupName) | $($principal.Name) | $($principal.SID) |" + "`n"
            }
        }

        if ($groupsToCheck.Count -lt ($groups | Measure-Object).Count) {
            $result += "| Note | Analyzed first $($groupsToCheck.Count) of $(($groups | Measure-Object).Count) groups |" + "`n"
        }

        if ($foreignSidCount -gt 0) {
            $result += "`n**Foreign SID Principals by External Domain:**" + "`n" + "`n"
            $result += "| Domain SID | Count |" + "`n"
            $result += "| --- | --- |" + "`n"

            $domainSidGroups = $foreignSidPrincipals | Group-Object -Property DomainSID | Sort-Object Count -Descending
            foreach ($domainGroup in $domainSidGroups | Select-Object -First 10) {
                $result += "| $($domainGroup.Name) | $($domainGroup.Count) |" + "`n"
            }

            if ($domainSidGroups.Count -gt 10) {
                $result += "| ... | ($($domainSidGroups.Count - 10) more domains) |" + "`n"
            }

            $result += "`n**Note:** Foreign SIDs may represent:" + "`n"
            $result += "- Users/groups from trusted external domains or forests" + "`n"
            $result += "- Visible domain-account principals outside the connected domain (objectSid, not sIDHistory)" + "`n"
            $result += "- Accounts from former domains still referenced in groups" + "`n"
        } else {
            $result += "`nNo foreign SID principals found in analyzed groups." + "`n"
        }

        $testResultMarkdown = "Active Directory foreign SID principals have been analyzed. Found $foreignSidCount foreign SID principals from $distinctDomainSids external domain(s).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group member data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
