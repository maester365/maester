<#
.SYNOPSIS
    Checks for active role assingments with no start time

.DESCRIPTION

    Provisioning users to highly privileged roles SHALL NOT occur outside of a PAM system.

.EXAMPLE
    Test-MtCisaUnmanagedRoleAssignments

    Returns true if all role assignments have a start time
#>

Function Test-MtCisaUnmanagedRoleAssignments {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"
    if(-not $pim){
        return $false
    }

    $roles = Get-MtRole -CisaHighlyPrivilegedRoles
    $roleAssignments = @()

    foreach($role in $roles){
        $principal  = $null
        $roleAssignment = [PSCustomObject]@{
            role           = $role.displayName
            principal      = $principal
        }
        $assignmentsSplat = @{
            ApiVersion      = "v1.0"
            RelativeUri     = "roleManagement/directory/roleAssignmentSchedules"
            Filter          = "roleDefinitionId eq '$($role.id)' and assignmentType eq 'Assigned'"
            QueryParameters = @{
                expand="principal"
            }
        }
        $assignments = Invoke-MtGraphRequest @assignmentsSplat | Where-Object {`
            $null -eq $_.createdUsing -or `
            $null -eq $_.scheduleInfo.startDateTime}

        $roleAssignment.principal = $assignments.principal

        $roleAssignments += $roleAssignment
    }

    $testResult = $roleAssignments.principal.Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no unmanaged active role assignments:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant has active assignments without a start date."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}