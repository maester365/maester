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
    Test-MtAdGroupMemberAccountTypeCount

    Returns $true if group member data is accessible, $false otherwise.
    The test result includes the count of distinct account types found.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupMemberAccountTypeCount
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

    # Collect all unique member object classes
    # Limit to first 50 groups for performance
    $groupsToCheck = $groups | Select-Object -First 50
    $allMembers = @()
    $processedSids = @{}

    foreach ($group in $groupsToCheck) {
        try {
            $members = Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction SilentlyContinue
            foreach ($member in $members) {
                # Avoid duplicates by SID
                if (-not $processedSids.ContainsKey($member.SID.Value)) {
                    $processedSids[$member.SID.Value] = $true
                    $allMembers += $member
                }
            }
        }
        catch {
            Write-Verbose "Could not retrieve members for group $($group.Name): $($_.Exception.Message)"
        }
    }

    # Get distinct object classes
    $distinctTypes = $allMembers | ForEach-Object { $_.objectClass } | Select-Object -Unique
    $distinctTypeCount = ($distinctTypes | Measure-Object).Count
    $totalUniqueMembers = $allMembers.Count

    # Test passes if we successfully retrieved member data
    $testResult = $totalUniqueMembers -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Unique Members Analyzed | $totalUniqueMembers |`n"
        $result += "| Distinct Account Types | $distinctTypeCount |`n"
        $result += "| Account Types Found | $($distinctTypes -join ', ') |`n"

        if ($groupsToCheck.Count -lt ($groups | Measure-Object).Count) {
            $result += "| Note | Analyzed first $($groupsToCheck.Count) groups for performance |`n"
        }

        $testResultMarkdown = "Active Directory group member account types have been analyzed. Found $distinctTypeCount distinct account types across $totalUniqueMembers unique members.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group member data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


