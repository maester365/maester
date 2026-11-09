function Test-MtAdGroupMemberAccountTypeCount {
    <#
    .SYNOPSIS
    Counts the distinct account types of members across Active Directory groups.

    .DESCRIPTION
    This test analyzes group membership across Active Directory and identifies
    the distinct types of objects that are members of groups. Common account types
    include user, group, computer, and foreignSecurityPrincipal. This helps
    understand the composition of group memberships in the directory.

    .EXAMPLE
    Invoke-MtTest -Id AD-GMC-02

    Returns $true if group member data is accessible, $false otherwise.
    The test result includes the count of distinct account types found.

    .LINK
    https://maester.dev/docs/tests/AD-GMC-02
    #>
    [MaesterTest(
        Id = 'AD-GMC-02',
        Title = 'Distinct account types of members count should be retrievable',
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
        Add-MtTestResultDetail -SkippedBecause Error -Result 'Active Directory group inventory is unavailable; member account types cannot be assessed.'
        return $null
    }

    $groups = $adState.Groups
    if ($null -eq $groups) { throw 'Group collection is unavailable.' }

    $protocolConnection = New-MtAdProtocolConnection -ProtocolEvidence $adState.ProtocolEvidence

    # Collect all unique member object classes
    $groupsToCheck = @($groups)
    $allMembers = @()
    $processedSids = @{}

    try {
        foreach ($group in $groupsToCheck) {
            $members = @(Get-MtLdapGroupMember -Connection $protocolConnection -GroupDistinguishedName $group.DistinguishedName)
            foreach ($member in $members) {
                # Avoid duplicates by SID
                $memberKey = if ($member.SID.Value) { [string]$member.SID.Value } else { [string]$member.DistinguishedName }
                if (-not $processedSids.ContainsKey($memberKey)) {
                    $processedSids[$memberKey] = $true
                    $allMembers += $member
                }
            }
        }
    } finally {
        $protocolConnection.Dispose()
    }

    # Get distinct object classes
    $distinctTypes = $allMembers | ForEach-Object { $_.objectClass } | Select-Object -Unique
    $distinctTypeCount = ($distinctTypes | Measure-Object).Count
    $totalUniqueMembers = $allMembers.Count

    # Test passes if we successfully retrieved member data
    $testResult = $null -ne $adState.Groups

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Unique Members Analyzed | $totalUniqueMembers |" + "`n"
        $result += "| Distinct Account Types | $distinctTypeCount |" + "`n"
        $result += "| Account Types Found | $($distinctTypes -join ', ') |" + "`n"
        $result += "`n| Account Type | Unique Members |" + "`n"
        $result += "| --- | --- |" + "`n"
        foreach ($type in @($allMembers | Group-Object objectClass | Sort-Object Count -Descending)) {
            $result += "| $($type.Name) | $($type.Count) |" + "`n"
        }

        $result += "| Groups Analyzed | $($groupsToCheck.Count) |" + "`n"

        $testResultMarkdown = "Active Directory group member account types have been analyzed. Found $distinctTypeCount distinct account types across $totalUniqueMembers unique members.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group member data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
