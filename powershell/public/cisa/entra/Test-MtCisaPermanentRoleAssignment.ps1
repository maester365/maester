<#
.SYNOPSIS
    Checks for permanent active role assingments

.DESCRIPTION

    Permanent active role assignments SHALL NOT be allowed for highly privileged roles.

.EXAMPLE
    Test-MtCisaPermanentRoleAssignment

    Returns true if no roles have permanent active assignments
#>

Function Test-MtCisaPermanentRoleAssignment {
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
            $_.scheduleInfo.expiration.type -eq "noExpiration"}

        $roleAssignment.principal = $assignments.principal

        $roleAssignments += $roleAssignment
    }

    $testResult = ($roleAssignments.principal|Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no active assignments without expiration to privileged roles:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant has active assignments without expiration to privileged roles."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}