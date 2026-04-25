function Test-MtAdGroupMemberForeignSidDetails {
    <#
    .SYNOPSIS
    Details of foreign security principals by their domain of origin.

    .DESCRIPTION
    This test analyzes group memberships containing foreign security principals (FSPs)
    and breaks them down by their domain of origin. Foreign SIDs indicate trusts
    with external domains or forests and may pose security risks if not properly managed.

    .EXAMPLE
    Test-MtAdGroupMemberForeignSidDetails

    Returns $true if foreign SID data is retrievable.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupMemberForeignSidDetails
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
    $domain = $adState.Domain
    $domainSid = $domain.DomainSID.Value

    # Collect all foreign SIDs from group members
    $foreignSidsByDomain = @{}
    $totalForeignSids = 0

    foreach ($group in $groups) {
        try {
            # Get group members
            $members = Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction SilentlyContinue

            foreach ($member in $members) {
                if ($member.SID -and $member.SID.Value) {
                    $sidString = $member.SID.Value

                    # Check if this is a foreign SID (does not start with domain SID)
                    if (-not $sidString.StartsWith($domainSid)) {
                        $totalForeignSids++

                        # Extract domain SID from the foreign SID
                        $foreignDomainSid = $sidString -replace '-\d+$', ''

                        if (-not $foreignSidsByDomain.ContainsKey($foreignDomainSid)) {
                            $foreignSidsByDomain[$foreignDomainSid] = @{
                                DomainSid = $foreignDomainSid
                                Count = 0
                                Groups = @()
                            }
                        }

                        $foreignSidsByDomain[$foreignDomainSid].Count++

                        if ($group.Name -notin $foreignSidsByDomain[$foreignDomainSid].Groups) {
                            $foreignSidsByDomain[$foreignDomainSid].Groups += $group.Name
                        }
                    }
                }
            }
        }
        catch {
            Write-Verbose "Could not retrieve members for group $($group.Name): $($_.Exception.Message)"
        }
    }

    $testResult = $true

    if ($testResult) {
        $result = "### Foreign Security Principals by Domain`n`n"

        if ($foreignSidsByDomain.Count -eq 0) {
            $result += "> No foreign security principals found in group memberships.`n`n"
            $result += "This indicates all group members belong to the local domain.`n`n"
        } else {
            $result += "| Domain SID | FSP Count | Groups Affected |`n"
            $result += "| --- | --- | --- |`n"

            $sortedDomains = $foreignSidsByDomain.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending

            foreach ($domainEntry in $sortedDomains) {
                $sid = $domainEntry.Value.DomainSid
                $count = $domainEntry.Value.Count
                $affectedGroups = ($domainEntry.Value.Groups | Select-Object -First 5) -join ', '
                if ($domainEntry.Value.Groups.Count -gt 5) {
                    $affectedGroups += " (+$($domainEntry.Value.Groups.Count - 5) more)"
                }

                $result += "| $sid | $count | $affectedGroups |`n"
            }

            $result += "`n**Total Foreign Security Principals:** $totalForeignSids`n"
            $result += "**External Domains:** $($foreignSidsByDomain.Count)`n"
        }

        $testResultMarkdown = $result
    } else {
        $testResultMarkdown = "Unable to retrieve foreign security principal data."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
