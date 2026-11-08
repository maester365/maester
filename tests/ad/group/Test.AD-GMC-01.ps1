function Test-MtAdGroupMemberDistinctGroupCount {
    <#
    .SYNOPSIS
    Counts the distinct groups that have members in Active Directory.

    .DESCRIPTION
    This test retrieves the count of unique groups that contain at least one member
    in Active Directory. This provides visibility into group utilization and helps
    identify groups that are actively being used versus empty or unused groups.

    .EXAMPLE
    Test-MtAdGroupMemberDistinctGroupCount

    Returns $true if group member data is accessible, $false otherwise.
    The test result includes counts of groups with members and total groups.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupMemberDistinctGroupCount
    #>
    [MaesterTest(
        Id = 'AD-GMC-01',
        Title = 'Distinct groups with members count should be retrievable',
        Product = 'ad',
        Feature = 'groups',
        Area = 'identity-lifecycle',
        ResourceType = 'Group',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        LongRunning = $true,
        Permission = ('ActiveDirectory:Ldap:group:ReadProperty', 'ActiveDirectory:Ldap:group.member:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Groups')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Error -Result 'Active Directory inventory is unavailable; the declared service gate is handled by the engine.'
        return $null
    }

    $groups = $adState.Groups
    if ($null -eq $groups) { throw 'Group collection is unavailable.' }
    $totalGroupCount = ($groups | Measure-Object).Count

    $protocolConnection = New-MtAdProtocolConnection -ProtocolEvidence $adState.ProtocolEvidence

    # Query members for each group to find groups with members
    $groupsToCheck = @($groups)
    $groupsWithMembers = @()

    try {
        foreach ($group in $groupsToCheck) {
            $members = @(Get-MtLdapGroupMember -Connection $protocolConnection -GroupDistinguishedName $group.DistinguishedName)
            if ($members -and ($members | Measure-Object).Count -gt 0) {
                $groupsWithMembers += $group
            }
        }
    } finally {
        $protocolConnection.Dispose()
    }

    $groupsWithMembersCount = $groupsWithMembers.Count
    $emptyGroupsCount = $totalGroupCount - $groupsWithMembersCount

    # Test passes if we successfully retrieved group data
    $testResult = $null -ne $adState.Groups

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalGroupCount -gt 0) {
            [Math]::Round(($groupsWithMembersCount / $totalGroupCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Groups | $totalGroupCount |" + "`n"
        $result += "| Groups with Members | $groupsWithMembersCount |" + "`n"
        $result += "| Empty Groups | $emptyGroupsCount |" + "`n"
        $result += "| Groups with Members % | $percentage% |" + "`n"

        $result += "| Groups Analyzed | $($groupsToCheck.Count) |" + "`n"

        $testResultMarkdown = "Active Directory groups have been analyzed. $groupsWithMembersCount out of $totalGroupCount groups ($percentage%) have at least one member.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
