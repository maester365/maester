function Test-MtAdGroupMemberTrustCount {
    <#
    .SYNOPSIS
    Counts the trust members in Active Directory groups.

    .DESCRIPTION
    This test identifies and counts members from trusted domains that are included
    in Active Directory groups. Trust members are represented as foreign security
    principals and typically appear as domain-qualified SIDs. This helps identify
    cross-domain access configurations and external trust relationships being
    utilized for access control.

    .EXAMPLE
    Test-MtAdGroupMemberTrustCount

    Returns $true if group member data is accessible, $false otherwise.
    The test result includes the count of trust members found.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupMemberTrustCount
    #>
    [MaesterTest(
        Id = 'AD-GMC-04',
        Title = 'Trust members count should be investigated',
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
    $domain = $adState.Domain
    $domainSid = if ($domain.DomainSID.PSObject.Properties['Value']) { [string]$domain.DomainSID.Value } else { [string]$domain.DomainSID }
    if ($null -eq $groups -or -not $domainSid) { throw 'Group or domain SID collection is unavailable.' }

    $protocolConnection = New-MtAdProtocolConnection -ProtocolEvidence $adState.ProtocolEvidence

    # Collect trust members
    # Assess every group; counts describe distinct SIDs and details retain all group memberships.
    $groupsToCheck = @($groups)
    $trustMembers = @()
    $processedSids = @{}

    try {
        foreach ($group in $groupsToCheck) {
            $members = @(Get-MtLdapGroupMember -Connection $protocolConnection -GroupDistinguishedName $group.DistinguishedName)
            foreach ($member in $members) {
                $memberSid = if ($member.SID.PSObject.Properties['Value']) { [string]$member.SID.Value } else { [string]$member.SID }
                # Check if this is a trust member (foreignSecurityPrincipal or SID doesn't match domain)
                $isTrustMember = $false

                # Check by objectClass
                if (($member.IsForeignSecurityPrincipal -or $member.objectClass -eq 'foreignSecurityPrincipal') -and $memberSid -match '^S-1-5-21-') {
                    $isTrustMember = $true
                }
                # Check by SID prefix (doesn't match current domain SID)
                elseif ($memberSid -match '^S-1-5-21-' -and -not $memberSid.StartsWith("$domainSid-")) {
                    $isTrustMember = $true
                }

                if (($member.IsForeignSecurityPrincipal -or $member.objectClass -eq 'foreignSecurityPrincipal') -and -not $memberSid) {
                    throw 'A foreign security principal has no SID; its domain cannot be assessed.'
                }
                if ($isTrustMember) {
                    $processedSids[$memberSid] = $true
                    $trustMembers += [PSCustomObject]@{
                        SID = $memberSid
                        Name = $member.Name
                        ObjectClass = $member.objectClass
                        GroupName = $group.Name
                    }
                }
            }
        }
    }
    finally { $protocolConnection.Dispose() }

    $trustMemberCount = $processedSids.Count

    # Test passes if we successfully retrieved member data
    $testResult = $null -ne $groups

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Trust Members Found | $trustMemberCount |" + "`n"
        $result += "| Foreign domain group memberships | $($trustMembers.Count) |" + "`n"
        $result += "| Groups Analyzed | $($groupsToCheck.Count) |" + "`n"
        if ($trustMemberCount -gt 0) {
            $result += "`n| Group | Member | SID |" + "`n| --- | --- | --- |" + "`n"
            foreach ($member in $trustMembers) {
                $result += "| $($member.GroupName) | $($member.Name) | $($member.SID) |" + "`n"
            }
        }

        if ($groupsToCheck.Count -lt ($groups | Measure-Object).Count) {
            $result += "| Note | Analyzed first $($groupsToCheck.Count) of $(($groups | Measure-Object).Count) groups |" + "`n"
        }

        if ($trustMemberCount -gt 0) {
            $result += "`n**Trust members indicate cross-domain access configurations.** These may represent:" + "`n"
            $result += "- Users or groups from trusted external domains" + "`n"
            $result += "- Foreign security principals from forest trusts" + "`n"
            $result += "- Visible objectSid references to principals outside the connected domain; sIDHistory is not inspected" + "`n"
        } else {
            $result += "`nNo trust members found in analyzed groups." + "`n"
        }

        $testResultMarkdown = "Active Directory group trust membership has been analyzed. Found $trustMemberCount trust members from external domains.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group member data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
