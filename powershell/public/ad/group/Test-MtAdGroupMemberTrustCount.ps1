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

    # Collect trust members
    # Limit to first 50 groups for performance
    $groupsToCheck = $groups | Select-Object -First 50
    $trustMembers = @()
    $processedSids = @{}

    foreach ($group in $groupsToCheck) {
        try {
            $members = Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction SilentlyContinue
            foreach ($member in $members) {
                # Check if this is a trust member (foreignSecurityPrincipal or SID doesn't match domain)
                $isTrustMember = $false

                # Check by objectClass
                if ($member.objectClass -eq 'foreignSecurityPrincipal') {
                    $isTrustMember = $true
                }
                # Check by SID prefix (doesn't match current domain SID)
                elseif ($member.SID.Value -and -not $member.SID.Value.StartsWith($domainSid)) {
                    $isTrustMember = $true
                }

                if ($isTrustMember -and -not $processedSids.ContainsKey($member.SID.Value)) {
                    $processedSids[$member.SID.Value] = $true
                    $trustMembers += [PSCustomObject]@{
                        SID = $member.SID.Value
                        Name = $member.Name
                        ObjectClass = $member.objectClass
                        GroupName = $group.Name
                    }
                }
            }
        }
        catch {
            Write-Verbose "Could not retrieve members for group $($group.Name): $($_.Exception.Message)"
        }
    }

    $trustMemberCount = $trustMembers.Count

    # Test passes if we successfully retrieved member data
    $testResult = $true

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Trust Members Found | $trustMemberCount |`n"
        $result += "| Groups Analyzed | $($groupsToCheck.Count) |`n"

        if ($groupsToCheck.Count -lt ($groups | Measure-Object).Count) {
            $result += "| Note | Analyzed first $($groupsToCheck.Count) of $(($groups | Measure-Object).Count) groups |`n"
        }

        if ($trustMemberCount -gt 0) {
            $result += "`n**Trust members indicate cross-domain access configurations.** These may represent:`n"
            $result += "- Users or groups from trusted external domains`n"
            $result += "- Foreign security principals from forest trusts`n"
            $result += "- SID history from domain migrations`n"
        } else {
            $result += "`nNo trust members found in analyzed groups.`n"
        }

        $testResultMarkdown = "Active Directory group trust membership has been analyzed. Found $trustMemberCount trust members from external domains.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group member data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
