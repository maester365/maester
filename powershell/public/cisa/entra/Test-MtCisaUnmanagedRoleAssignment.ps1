function Test-MtCisaUnmanagedRoleAssignment {
    <#
    .SYNOPSIS
    Checks for active role assingments with no start time

    .DESCRIPTION
    Provisioning users to highly privileged roles SHALL NOT occur outside of a PAM system.

    .EXAMPLE
    Test-MtCisaUnmanagedRoleAssignment

    Returns true if all role assignments have a start time

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaUnmanagedRoleAssignment
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"
    if (-not $pim) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        return $null
    }

    $roles = Get-MtRole -CisaHighlyPrivilegedRoles
    $roleAssignments = @()

    foreach ($role in $roles) {
        $principal = $null
        $roleAssignment = [PSCustomObject]@{
            role      = $role.displayName
            principal = $principal
        }
        $assignmentsSplat = @{
            ApiVersion      = "v1.0"
            RelativeUri     = "roleManagement/directory/roleAssignmentSchedules"
            Filter          = "roleDefinitionId eq '$($role.id)' and assignmentType eq 'Assigned'"
            QueryParameters = @{
                expand = "principal"
            }
        }
        $assignments = Invoke-MtGraphRequest @assignmentsSplat | Where-Object {`
                $null -eq $_.createdUsing -or `
                $null -eq $_.scheduleInfo.startDateTime }

        $roleAssignment.principal = $assignments.principal

        $roleAssignments += $roleAssignment
    }

    $testResult = ($roleAssignments.principal | Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no unmanaged active role assignments."
    } else {
        $testResultMarkdown = "Your tenant has active assignments without a start date:`n`n%TestResult%"
    }

    if (-not $testResult) {
        $result = "| Role | Principal Type | Display Name | Status |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach ($roleAssignment in ($roleAssignments | Where-Object { $_.principal })) {
            foreach ($principal in $roleAssignment.principal) {
                $principalType = $principal.'@odata.type'.Split('.')[-1]
                $entraPortalUrl = $__MtSession.AdminPortalUrl.Entra
                $portalDeepLink = switch ($principal.'@odata.type') {
                    '#microsoft.graph.user' { "$($entraPortalUrl)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($principal.id)" }
                    '#microsoft.graph.servicePrincipal' { "$($entraPortalUrl)#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($principal.id)" }
                    '#microsoft.graph.group' { "$($entraPortalUrl)#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/$($principal.id)" }
                    default { $null }
                }
                $displayName = if ($portalDeepLink) {
                    "[$(Get-MtSafeMarkdown $principal.displayName)]($portalDeepLink)"
                } else {
                    Get-MtSafeMarkdown $principal.displayName
                }
                $result += "| $($roleAssignment.role) | $principalType | $displayName | ❌ No Start Date |`n"
            }
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
