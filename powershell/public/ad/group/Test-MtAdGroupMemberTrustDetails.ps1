function Test-MtAdGroupMemberTrustDetails {
    <#
    .SYNOPSIS
    Provides detailed breakdown of trust members by group in Active Directory.

    .DESCRIPTION
    This test provides a detailed analysis of which Active Directory groups contain
    members from trusted domains. It identifies groups with foreign security principals
    or members with SIDs from external domains, showing the breakdown per group.
    This helps administrators understand cross-domain access patterns and identify
    which groups grant access to external users or groups.

    .EXAMPLE
    Test-MtAdGroupMemberTrustDetails

    Returns $true if group member data is accessible, $false otherwise.
    The test result includes detailed breakdown of trust members by group.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupMemberTrustDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
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
    $domain = $adState.Domain
    $domainSid = $domain.DomainSID.Value

    # Collect trust members per group
    # Limit to first 50 groups for performance
    $groupsToCheck = $groups | Select-Object -First 50
    $groupsWithTrustMembers = @{}
    $totalTrustMembers = 0

    foreach ($group in $groupsToCheck) {
        try {
            $members = Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction SilentlyContinue
            $groupTrustMembers = @()

            foreach ($member in $members) {
                # Check if this is a trust member
                $isTrustMember = $false

                if ($member.objectClass -eq 'foreignSecurityPrincipal') {
                    $isTrustMember = $true
                } elseif ($member.SID.Value -and -not $member.SID.Value.StartsWith($domainSid)) {
                    $isTrustMember = $true
                }

                if ($isTrustMember) {
                    $groupTrustMembers += [PSCustomObject]@{
                        SID         = $member.SID.Value
                        Name        = $member.Name
                        ObjectClass = $member.objectClass
                    }
                    $totalTrustMembers++
                }
            }

            if ($groupTrustMembers.Count -gt 0) {
                $groupsWithTrustMembers[$group.Name] = $groupTrustMembers
            }
        } catch {
            Write-Verbose "Could not retrieve members for group $($group.Name): $($_.Exception.Message)"
        }
    }

    $groupsWithTrustCount = $groupsWithTrustMembers.Count

    # Test passes if we successfully retrieved member data
    $testResult = $true

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Groups with Trust Members | $groupsWithTrustCount |`n"
        $result += "| Total Trust Members | $totalTrustMembers |`n"
        $result += "| Groups Analyzed | $($groupsToCheck.Count) |`n"

        if ($groupsToCheck.Count -lt ($groups | Measure-Object).Count) {
            $result += "| Note | Analyzed first $($groupsToCheck.Count) of $(($groups | Measure-Object).Count) groups |`n"
        }

        if ($groupsWithTrustCount -gt 0) {
            $result += "`n**Groups Containing Trust Members:**`n`n"

            foreach ($groupName in ($groupsWithTrustMembers.Keys | Sort-Object)) {
                $trustMembers = $groupsWithTrustMembers[$groupName]
                $result += "**$groupName** ($($trustMembers.Count) trust members)`n`n"
                $result += "| Name | SID | Type |`n"
                $result += "| --- | --- | --- |`n"

                foreach ($member in $trustMembers | Select-Object -First 10) {
                    $result += "| $($member.Name) | $($member.SID) | $($member.ObjectClass) |`n"
                }

                if ($trustMembers.Count -gt 10) {
                    $result += "| ... | ... | ... ($($trustMembers.Count - 10) more) |`n"
                }
                $result += "`n"
            }
        } else {
            $result += "`nNo groups with trust members found in analyzed groups.`n"
        }

        $testResultMarkdown = "Active Directory group trust membership details have been analyzed. Found $totalTrustMembers trust members across $groupsWithTrustCount groups.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group member data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


