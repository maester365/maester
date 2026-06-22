function Test-MtGsaForwardingProfileAssignmentNotNested {
    <#
    .SYNOPSIS
        Checks if groups assigned to Global Secure Access traffic forwarding profiles use direct membership (no nested groups).

    .DESCRIPTION
        Global Secure Access traffic forwarding profiles (Microsoft 365, Internet, and Private Access)
        can be scoped to specific users and groups. Microsoft does not support nested group membership
        for this assignment - a user must be a DIRECT member of the assigned group to receive the
        profile (and therefore the Global Secure Access client routing). A nested assignment group
        silently leaves part of the intended population without the profile.

        Traffic forwarding profiles are represented by service principals whose display name ends with
        'trafficforwardingprofile'; their user and group assignments are exposed as app role assignments.

    .EXAMPLE
        Test-MtGsaForwardingProfileAssignmentNotNested

        Returns $true if no group assigned to a traffic forwarding profile contains a nested group.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaForwardingProfileAssignmentNotNested
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    if ((Get-MtLicenseInformation -Product EntraID) -eq 'Free') {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $servicePrincipals = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -ApiVersion beta
        $forwardingProfiles = $servicePrincipals | Where-Object { $_.displayName -match 'trafficforwardingprofile' }

        if (-not $forwardingProfiles) {
            Add-MtTestResultDetail -Result 'No Global Secure Access traffic forwarding profiles were found in this tenant.'
            return $null
        }

        $nestedAssignments = @()
        foreach ($forwardingProfile in $forwardingProfiles) {
            $assignedGroups = Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$($forwardingProfile.id)/appRoleAssignedTo" |
                Where-Object { $_.principalType -eq 'Group' }

            foreach ($group in $assignedGroups) {
                $nestedGroups = Get-MtGroupMember -GroupId $group.principalId | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }
                if ($nestedGroups) {
                    $nestedAssignments += [pscustomobject]@{
                        Profile = $forwardingProfile.displayName
                        Group   = $group.principalDisplayName
                    }
                }
            }
        }

        $result = ($nestedAssignments.Count -eq 0)
        if ($result) {
            $testResult = "Well done. All groups assigned to Global Secure Access traffic forwarding profiles use direct membership (no nested groups).`n`n"
        } else {
            $testResult = "These traffic forwarding profile assignment groups contain **nested groups**. Microsoft does not honor nested membership for profile assignment, so the nested members will not receive the profile:`n`n"
            $testResult += "| Traffic forwarding profile | Assignment group |`n| --- | --- |`n"
            foreach ($entry in $nestedAssignments) {
                $testResult += "| $($entry.Profile) | $($entry.Group) |`n"
            }
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
