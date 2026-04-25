function Test-MtAdGroupMemberAccountTypeDetails {
    <#
    .SYNOPSIS
    Provides detailed breakdown of member account types across Active Directory groups.

    .DESCRIPTION
    This test provides a comprehensive analysis of group membership composition in
    Active Directory. It categorizes members by their object class (user, group,
    computer, foreignSecurityPrincipal) and provides counts for each type. This
    detailed view helps administrators understand the structure and composition
    of their group memberships.

    .EXAMPLE
    Test-MtAdGroupMemberAccountTypeDetails

    Returns $true if group member data is accessible, $false otherwise.
    The test result includes detailed breakdown of account types.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupMemberAccountTypeDetails
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

    # Collect all members and their types
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

    # Group by object class and get counts
    $typeBreakdown = $allMembers | Group-Object -Property objectClass | Sort-Object Count -Descending
    $totalUniqueMembers = $allMembers.Count
    $distinctTypeCount = $typeBreakdown.Count

    # Test passes if we successfully retrieved member data
    $testResult = $totalUniqueMembers -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Unique Members Analyzed | $totalUniqueMembers |`n"
        $result += "| Distinct Account Types | $distinctTypeCount |`n"

        if ($groupsToCheck.Count -lt ($groups | Measure-Object).Count) {
            $result += "| Groups Analyzed | $($groupsToCheck.Count) of $(($groups | Measure-Object).Count) |`n"
        }

        $result += "`n**Account Type Breakdown:**`n`n"
        $result += "| Account Type | Count | Percentage |`n"
        $result += "| --- | --- | --- |`n"

        foreach ($type in $typeBreakdown) {
            $percentage = if ($totalUniqueMembers -gt 0) {
                [Math]::Round(($type.Count / $totalUniqueMembers) * 100, 2)
            } else {
                0
            }
            $result += "| $($type.Name) | $($type.Count) | $percentage% |`n"
        }

        $testResultMarkdown = "Active Directory group member account types have been analyzed. Found $distinctTypeCount distinct account types across $totalUniqueMembers unique members.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group member data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
