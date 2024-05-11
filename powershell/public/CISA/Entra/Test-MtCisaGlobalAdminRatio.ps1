<#
.SYNOPSIS
    Checks the ratio of global admins to privileged roles

.DESCRIPTION

    Privileged users SHALL be provisioned with finer-grained roles instead of Global Administrator.

.EXAMPLE
    Test-MtCisaGlobalAdminRatio

    Returns true if global admin to privileged roles ration is 1 or less
#>

Function Test-MtCisaGlobalAdminRatio {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $roles = Get-MtRole -CisaHighlyPrivilegedRoles
    $roleAssignments = @()

    foreach($role in $roles){
        $assignments = $null
        $roleAssignment = [PSCustomObject]@{
            role        = $role.displayName
            assignments = $assignments
        }
        $assignments = Get-MtRoleMember -roleId $role.id -All
        $roleAssignment.assignments = $assignments
        $roleAssignments += $roleAssignment
    }

    $globalAdministrators = $roleAssignments | Where-Object {`
        $_.role -eq "Global Administrator"} | `
        Select-Object -ExpandProperty assignments | Where-Object {`
        $_.'@odata.type' -eq "#microsoft.graph.user"}

    $otherAssignments = $roleAssignments | Where-Object {`
        $_.role -ne "Global Administrator"} | `
        Select-Object -ExpandProperty assignments | Where-Object {`
        $_.'@odata.type' -eq "#microsoft.graph.user"}

    $ratio = $globalAdministrators.Count / $otherAssignments.Count

    $testResult = $ratio -le 1

    $users = $roleAssignments.assignments | Sort-Object id -Unique

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has more granular role assignments than global admin assignments:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have enough granular role assignments."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType Users -GraphObjects $users

    return $testResult
}