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
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $groups = $adState.Groups
    $domainSid = $adState.Domain.DomainSID.Value

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

    foreach ($group in $groups) {
        # Check if group is privileged (adminCount = 1 or well-known RID)
        $isPrivileged = $group.adminCount -eq 1
        $rid = ($group.SID.Value -split '-')[-1]
        $isWellKnown = $privilegedRIDs.ContainsKey($rid)

        if ($isPrivileged -or $isWellKnown) {
            $totalPrivileged++

            try {
                $members = Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction SilentlyContinue
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
            catch {
                Write-Verbose "Could not check members for group $($group.Name): $($_.Exception.Message)"
            }
        }
    }

    $testResult = $true

    if ($testResult) {
        $result = "| Category | Count |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Privileged Groups | $totalPrivileged |`n"
        $result += "| Privileged Groups with Members | $privilegedWithMembers |`n"
        $result += "| Privileged Groups without Members | $privilegedWithoutMembers |`n"
        $result += "| Well-Known Privileged with Members | $wellKnownPrivilegedWithMembers |`n"

        $result += "`n### Well-Known Privileged Groups with Members`n`n"
        $result += "| Group Name | RID | Member Count |`n"
        $result += "| --- | --- | --- |`n"

        $sortedWellKnown = $privilegedGroupsWithMembers | Where-Object { $_.IsWellKnown } | Sort-Object MemberCount -Descending

        foreach ($group in $sortedWellKnown) {
            $result += "| $($group.Name) | $($group.RID) | $($group.MemberCount) |`n"
        }

        $testResultMarkdown = "Security audit found **$privilegedWithMembers** privileged groups with members out of **$totalPrivileged** total privileged groups.`n`n"
        $testResultMarkdown += "These groups should be regularly audited for unauthorized membership changes.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve group data."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
