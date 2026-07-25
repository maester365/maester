function Test-MtGsaPrivateAccessAppAssignmentNotNested {
    <#
    .SYNOPSIS
        Checks if groups assigned to Entra Private Access (and Quick Access) applications use direct membership (no nested groups).

    .DESCRIPTION
        Microsoft Entra enterprise application assignment grants access to the direct (and dynamic)
        members of an assigned group only - the assignment does not cascade to nested groups, and
        nested group membership is not supported for app assignment. Groups assigned to Global Secure
        Access Private Access applications (and the Quick Access app) must therefore use direct
        membership, otherwise members of a nested group are silently left without access.

        Note: this only applies to app assignment (appRoleAssignedTo). Conditional Access scoping does
        honor nested groups, so the MFA and managed-device coverage checks are not affected.

    .EXAMPLE
        Test-MtGsaPrivateAccessAppAssignmentNotNested

        Returns $true if no group assigned to a Private Access or Quick Access application contains a nested group.

    .LINK
        https://maester.dev/docs/commands/Test-MtGsaPrivateAccessAppAssignmentNotNested
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
        $apps = Get-MtPrivateAccessApplication
        if (-not $apps) {
            Add-MtTestResultDetail -Result 'No Entra Private Access applications were found in this tenant.'
            return $null
        }

        $nestedAssignments = @()
        foreach ($app in $apps) {
            $assignedGroups = Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$($app.id)/appRoleAssignedTo" |
                Where-Object { $_.principalType -eq 'Group' }

            foreach ($group in $assignedGroups) {
                $nestedGroups = Get-MtGroupMember -GroupId $group.principalId | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }
                if ($nestedGroups) {
                    $nestedAssignments += [pscustomobject]@{
                        Application = $app.displayName
                        Group       = $group.principalDisplayName
                    }
                }
            }
        }

        $result = ($nestedAssignments.Count -eq 0)
        if ($result) {
            $testResult = "Well done. All groups assigned to Entra Private Access applications (and Quick Access) use direct membership (no nested groups).`n`n"
        } else {
            $testResult = "These Private Access / Quick Access application assignment groups contain **nested groups** (members of the nested group are not granted access):`n`n"
            $testResult += "| Application | Assignment group |`n| --- | --- |`n"
            foreach ($entry in $nestedAssignments) {
                $testResult += "| $($entry.Application) | $($entry.Group) |`n"
            }
        }

        Add-MtTestResultDetail -Result $testResult
        return $result
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
