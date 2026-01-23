<#
.SYNOPSIS
    Checks the ratio of global admins to privileged roles

.DESCRIPTION
    Privileged users SHALL be provisioned with finer-grained roles instead of Global Administrator.

.EXAMPLE
    Test-MtCisaGlobalAdminRatio

    Returns true if global admin to privileged roles ration is 1 or less

.LINK
    https://maester.dev/docs/commands/Test-MtCisaGlobalAdminRatio
#>
function Test-MtCisaGlobalAdminRatio {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $roles = Get-MtRole -CisaHighlyPrivilegedRoles
    $roleAssignments = @()

    foreach($role in $roles){
        $assignments = $null
        $roleAssignment = [PSCustomObject]@{
            role        = $role.id
            assignments = $assignments
        }
        $assignments = Get-MtRoleMember -roleId $role.id
        $roleAssignment.assignments = $assignments
        $roleAssignments += $roleAssignment
    }

    $globalAdministrators = $roleAssignments | Where-Object {`
        $_.role -eq "62e90394-69f5-4237-9190-012177145e10"} | ` # Global Administrator
        Select-Object -ExpandProperty assignments | Where-Object {`
        $_.'@odata.type' -eq "#microsoft.graph.user"}

    $otherAssignments = $roleAssignments | Where-Object {`
        $_.role -ne "62e90394-69f5-4237-9190-012177145e10"} | ` # Global Administrator
        Select-Object -ExpandProperty assignments | Where-Object {`
        $_.'@odata.type' -eq "#microsoft.graph.user"}

    If ($otherAssignments.Count) {
        $ratio = 0
        $ratio = $globalAdministrators.Count / $otherAssignments.Count
        $testResult = $ratio -le 1
    } Else {
        $testResult = $false
    }

    $link = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has more granular [role assignments]($link) than global admin assignments.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have enough granular [role assignments]($link).`n`n%TestResult%"
    }
    $result = "Current Ratio: $([System.Math]::Round($ratio,2)) = $($globalAdministrators.Count) / $($otherAssignments.Count)`n`n"
    $result += "Ratio >= 1 - $($ratio -ge 1)"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
