function Test-MtAdGroupPrivilegedWithMembersDetails {
    <#
    .SYNOPSIS
    Details of privileged groups with their member counts in Active Directory.

    .DESCRIPTION
    This test lists all privileged groups (with adminCount = 1 or well-known RIDs)
    along with their member counts. This information is crucial for security auditing
    and identifying over-provisioned privileged access.

    Well-known privileged groups include:
    - Domain Admins (RID 512)
    - Enterprise Admins (RID 519)
    - Schema Admins (RID 518)
    - Account Operators (RID 548)
    - Server Operators (RID 549)
    - Print Operators (RID 550)
    - Backup Operators (RID 551)

    .EXAMPLE
    Test-MtAdGroupPrivilegedWithMembersDetails

    Returns $true if data is retrievable.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupPrivilegedWithMembersDetails
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

    # Collect privileged groups with members
    $privilegedGroups = @()

    foreach ($group in $groups) {
        # Check if group is privileged (adminCount = 1 or well-known RID)
        $isPrivileged = $group.adminCount -eq 1
        $rid = ($group.SID.Value -split '-')[-1]
        $isWellKnown = $privilegedRIDs.ContainsKey($rid)

        if ($isPrivileged -or $isWellKnown) {
            try {
                $members = Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction SilentlyContinue
                $memberCount = ($members | Measure-Object).Count

                $privilegedGroups += [PSCustomObject]@{
                    Name = $group.Name
                    RID = $rid
                    IsWellKnown = $isWellKnown
                    WellKnownName = if ($isWellKnown) { $privilegedRIDs[$rid] } else { 'N/A' }
                    MemberCount = $memberCount
                    GroupScope = $group.GroupScope
                    GroupCategory = $group.GroupCategory
                    AdminCount = $group.adminCount
                }
            }
            catch {
                Write-Verbose "Could not check members for group $($group.Name): $($_.Exception.Message)"
            }
        }
    }

    $testResult = $true

    if ($testResult) {
        $result = "### Privileged Groups with Members`n`n"

        if ($privilegedGroups.Count -eq 0) {
            $result += "> No privileged groups found.`n`n"
        } else {
            # Sort by member count descending
            $sortedGroups = $privilegedGroups | Sort-Object MemberCount -Descending

            $result += "**Total Privileged Groups:** $($privilegedGroups.Count)`n"
            $totalMembers = ($privilegedGroups | Measure-Object -Property MemberCount -Sum).Sum
            $result += "**Total Members in Privileged Groups:** $totalMembers`n`n"

            # Well-known groups section
            $result += "#### Well-Known Privileged Groups`n`n"
            $result += "| Group Name | RID | Well-Known Name | Members |`n"
            $result += "| --- | --- | --- | --- |`n"

            $wellKnownGroups = $sortedGroups | Where-Object { $_.IsWellKnown }

            foreach ($group in $wellKnownGroups) {
                $result += "| **$($group.Name)** | $($group.RID) | $($group.WellKnownName) | $($group.MemberCount) |`n"
            }

            # AdminSDHolder protected groups section
            $result += "`n#### AdminSDHolder Protected Groups (adminCount = 1)`n`n"
            $result += "| Group Name | Members | Scope |`n"
            $result += "| --- | --- | --- |`n"

            $adminSdHolderGroups = $sortedGroups | Where-Object { $_.AdminCount -eq 1 -and -not $_.IsWellKnown }

            if ($adminSdHolderGroups.Count -eq 0) {
                $result += "| No additional AdminSDHolder groups found | - | - |`n"
            } else {
                foreach ($group in ($adminSdHolderGroups | Select-Object -First 20)) {
                    $result += "| $($group.Name) | $($group.MemberCount) | $($group.GroupScope) |`n"
                }

                if ($adminSdHolderGroups.Count -gt 20) {
                    $result += "| ... and $($adminSdHolderGroups.Count - 20) more | - | - |`n"
                }
            }
        }

        $testResultMarkdown = $result
    } else {
        $testResultMarkdown = "Unable to retrieve group data."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
