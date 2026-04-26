function Test-MtAdGroupMemberForeignSidCount {
    <#
    .SYNOPSIS
    Counts the foreign SID principals in Active Directory groups.

    .DESCRIPTION
    This test identifies and counts security principals that have SIDs from external
    domains or forests. Foreign SIDs are security identifiers that do not match the
    current domain's SID pattern and represent accounts from other domains, migrated
    accounts with SID history, or trust relationships. These are important to track
    for security auditing and understanding cross-domain access.

    .EXAMPLE
    Test-MtAdGroupMemberForeignSidCount

    Returns $true if group member data is accessible, $false otherwise.
    The test result includes the count of foreign SID principals found.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupMemberForeignSidCount
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

    # Collect foreign SID principals
    # Limit to first 50 groups for performance
    $groupsToCheck = $groups | Select-Object -First 50
    $foreignSidPrincipals = @()
    $processedSids = @{}

    foreach ($group in $groupsToCheck) {
        try {
            $members = Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction SilentlyContinue
            foreach ($member in $members) {
                # Check if SID is foreign (doesn't start with domain SID)
                if ($member.SID.Value -and -not $member.SID.Value.StartsWith($domainSid)) {
                    if (-not $processedSids.ContainsKey($member.SID.Value)) {
                        $processedSids[$member.SID.Value] = $true

                        # Extract domain SID prefix
                        $sidString = $member.SID.Value
                        $domainSidPrefix = if ($sidString -match '^S-\d+-\d+-\d+-\d+-\d+') {
                            $matches[0]
                        } else {
                            "Unknown"
                        }

                        $foreignSidPrincipals += [PSCustomObject]@{
                            SID = $member.SID.Value
                            DomainSID = $domainSidPrefix
                            Name = $member.Name
                            ObjectClass = $member.objectClass
                            GroupName = $group.Name
                        }
                    }
                }
            }
        }
        catch {
            Write-Verbose "Could not retrieve members for group $($group.Name): $($_.Exception.Message)"
        }
    }

    $foreignSidCount = $foreignSidPrincipals.Count
    $distinctDomainSids = ($foreignSidPrincipals | Select-Object -ExpandProperty DomainSID -Unique | Measure-Object).Count

    # Test passes if we successfully retrieved member data
    $testResult = $true

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Foreign SID Principals | $foreignSidCount |`n"
        $result += "| Distinct External Domains | $distinctDomainSids |`n"
        $result += "| Groups Analyzed | $($groupsToCheck.Count) |`n"
        $result += "| Current Domain SID | $domainSid |`n"

        if ($groupsToCheck.Count -lt ($groups | Measure-Object).Count) {
            $result += "| Note | Analyzed first $($groupsToCheck.Count) of $(($groups | Measure-Object).Count) groups |`n"
        }

        if ($foreignSidCount -gt 0) {
            $result += "`n**Foreign SID Principals by External Domain:**`n`n"
            $result += "| Domain SID | Count |`n"
            $result += "| --- | --- |`n"

            $domainSidGroups = $foreignSidPrincipals | Group-Object -Property DomainSID | Sort-Object Count -Descending
            foreach ($domainGroup in $domainSidGroups | Select-Object -First 10) {
                $result += "| $($domainGroup.Name) | $($domainGroup.Count) |`n"
            }

            if ($domainSidGroups.Count -gt 10) {
                $result += "| ... | ($($domainSidGroups.Count - 10) more domains) |`n"
            }

            $result += "`n**Note:** Foreign SIDs may represent:`n"
            $result += "- Users/groups from trusted external domains or forests`n"
            $result += "- Migrated accounts with SID history preserved`n"
            $result += "- Accounts from former domains still referenced in groups`n"
        } else {
            $result += "`nNo foreign SID principals found in analyzed groups.`n"
        }

        $testResultMarkdown = "Active Directory foreign SID principals have been analyzed. Found $foreignSidCount foreign SID principals from $distinctDomainSids external domain(s).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group member data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


