function Test-MtAdGroupPrivilegedWithMembersCount {
    <#
    .SYNOPSIS
    Counts privileged groups that have members in Active Directory.

    .DESCRIPTION
    This test counts privileged groups (with adminCount = 1) that have members.
    This is important for security auditing as privileged groups provide
    administrative access to the domain and should be carefully monitored.

    Well-known privileged group RIDs:
    - 512: Domain Admins
    - 519: Enterprise Admins
    - 518: Schema Admins
    - 548: Account Operators
    - 549: Server Operators
    - 550: Print Operators
    - 551: Backup Operators

    .EXAMPLE
    Test-MtAdGroupPrivilegedWithMembersCount

    Returns $true if data is retrievable.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupPrivilegedWithMembersCount
    #>
    [MaesterTest(
        Id = 'AD-GMC-10',
        Title = 'Privileged groups with members count should be investigated',
        Product = 'ad',
        Feature = 'groups',
        Area = 'privileged-access',
        ResourceType = 'Group',
        Severity = 'Info',
        Mitre = ('T1098.007', 'T1078.002'),
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:group:ReadProperty', 'ActiveDirectory:Ldap:group.member:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState -Categories @('Groups')
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Error -Result 'Active Directory inventory is unavailable; the declared service gate is handled by the engine.'
        return $null
    }

    $groups = $adState.Groups
    if ($null -eq $groups) { throw 'Group collection is unavailable.' }

    $protocolConnection = New-MtAdProtocolConnection -ProtocolEvidence $adState.ProtocolEvidence

    # Well-known privileged group RIDs
    $privilegedRIDs = @{
        '512' = 'Domain Admins'
        '519' = 'Enterprise Admins'
        '518' = 'Schema Admins'
        '548' = 'Account Operators'
        '549' = 'Server Operators'
        '550' = 'Print Operators'
        '551' = 'Backup Operators'
    }

    # Count privileged groups with members
    $privilegedWithMembers = 0
    $privilegedWithoutMembers = 0
    $totalPrivileged = 0
    $wellKnownPrivilegedWithMembers = 0

    $privilegedGroupsWithMembers = @()

    try {
        foreach ($group in $groups) {
            # Check if group is privileged (adminCount = 1 or well-known RID).
            $isPrivileged = $group.adminCount -eq 1
            $sid = if ($group.SID -is [string]) { $group.SID } else { [string]$group.SID.Value }
            $rid = ($sid -split '-')[-1]
            $isWellKnown = $privilegedRIDs.ContainsKey($rid) -and (
                ($sid -match '^S-1-5-21-\d+-\d+-\d+-(512|518|519)$') -or
                ($sid -match '^S-1-5-32-(548|549|550|551)$')
            )

            if ($isPrivileged -or $isWellKnown) {
                $totalPrivileged++

                $members = @(Get-MtLdapGroupMember -Connection $protocolConnection -GroupDistinguishedName $group.DistinguishedName)
                $memberCount = ($members | Measure-Object).Count

                if ($memberCount -gt 0) {
                    $privilegedWithMembers++
                    if ($isWellKnown) {
                        $wellKnownPrivilegedWithMembers++
                    }

                    $privilegedGroupsWithMembers += [PSCustomObject]@{
                        Name = $group.Name
                        RID = $rid
                        IsWellKnown = $isWellKnown
                        MemberCount = $memberCount
                    }
                } else {
                    $privilegedWithoutMembers++
                }
            }
        }
    } finally {
        $protocolConnection.Dispose()
    }

    $testResult = $null -ne $adState.Groups

    if ($testResult) {
        $result = "| Category | Count |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Privileged Groups | $totalPrivileged |" + "`n"
        $result += "| Privileged Groups with Members | $privilegedWithMembers |" + "`n"
        $result += "| Privileged Groups without Members | $privilegedWithoutMembers |" + "`n"
        $result += "| Well-Known Privileged with Members | $wellKnownPrivilegedWithMembers |" + "`n"

        $result += "`n### Well-Known Privileged Groups with Members" + "`n" + "`n"
        $result += "| Group Name | RID | Member Count |" + "`n"
        $result += "| --- | --- | --- |" + "`n"

        $sortedWellKnown = $privilegedGroupsWithMembers | Where-Object { $_.IsWellKnown } | Sort-Object MemberCount -Descending

        foreach ($group in $sortedWellKnown) {
            $result += "| $($group.Name) | $($group.RID) | $($group.MemberCount) |" + "`n"
        }
        $result += "`n### Other AdminCount-Protected Groups with Members`n`n"
        $result += "| Group | Member Count |" + "`n| --- | --- |" + "`n"
        foreach ($group in @($privilegedGroupsWithMembers | Where-Object { -not $_.IsWellKnown } | Sort-Object MemberCount -Descending)) {
            $result += "| $($group.Name) | $($group.MemberCount) |" + "`n"
        }

        $testResultMarkdown = "Security audit found **$privilegedWithMembers** privileged groups with members out of **$totalPrivileged** total privileged groups." + "`n" + "`n"
        $testResultMarkdown += "These groups should be regularly audited for unauthorized membership changes.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve group data."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    return $testResult
}
