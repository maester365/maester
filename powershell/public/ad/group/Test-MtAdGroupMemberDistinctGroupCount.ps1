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
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $groups = $adState.Groups
    $totalGroupCount = ($groups | Measure-Object).Count

    # Query members for each group to find groups with members
    # Limit to first 100 groups for performance if there are many
    $groupsToCheck = $groups | Select-Object -First 100
    $groupsWithMembers = @()

    foreach ($group in $groupsToCheck) {
        try {
            $members = Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction SilentlyContinue
            if ($members -and ($members | Measure-Object).Count -gt 0) {
                $groupsWithMembers += $group
            }
        }
        catch {
            Write-Verbose "Could not retrieve members for group $($group.Name): $($_.Exception.Message)"
        }
    }

    $groupsWithMembersCount = $groupsWithMembers.Count
    $emptyGroupsCount = $totalGroupCount - $groupsWithMembersCount

    # Test passes if we successfully retrieved group data
    $testResult = $totalGroupCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalGroupCount -gt 0) {
            [Math]::Round(($groupsWithMembersCount / $totalGroupCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalGroupCount |`n"
        $result += "| Groups with Members | $groupsWithMembersCount |`n"
        $result += "| Empty Groups | $emptyGroupsCount |`n"
        $result += "| Groups with Members % | $percentage% |`n"

        if ($groupsToCheck.Count -lt $totalGroupCount) {
            $result += "| Note | Analyzed first $($groupsToCheck.Count) groups for performance |`n"
        }

        $testResultMarkdown = "Active Directory groups have been analyzed. $groupsWithMembersCount out of $totalGroupCount groups ($percentage%) have at least one member.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


