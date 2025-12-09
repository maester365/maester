<#
.SYNOPSIS
    Checks for permanent active role assingments

.DESCRIPTION
    Permanent active role assignments SHALL NOT be allowed for highly privileged roles.

.EXAMPLE
    Test-MtCisaPermanentRoleAssignment

    Returns true if no roles have permanent active assignments

.LINK
    https://maester.dev/docs/commands/Test-MtCisaPermanentRoleAssignment
#>
function Test-MtCisaPermanentRoleAssignment {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"
    if(-not $pim){
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        return $null
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
        $testResultMarkdown = "Well done. Your tenant has no active assignments without expiration to privileged roles."
    } else {
        $testResultMarkdown = "Your tenant has active assignments without expiration to privileged roles.`n`n%TestResult%"
    }

    if (-not $testResult) {
        $result = "| Role | Principal Type | Display Name | Status |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach($roleAssignment in ($roleAssignments | Where-Object {$_.principal})){
            foreach($principal in $roleAssignment.principal){
                $result += "| $($roleAssignment.role) | $($principal.'@odata.type'.Split('.')[-1]) | $($principal.displayName ) | ❌ No Expiration |`n"
            }
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}