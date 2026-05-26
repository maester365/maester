function Test-MtCisaGlobalAdminRatioCompliance {
    <#
    .SYNOPSIS
    Checks the ratio of global admins to privileged roles

    .DESCRIPTION
    Privileged users SHALL be provisioned with finer-grained roles instead of Global Administrator.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaGlobalAdminRatioCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $roles = Get-MgDirectoryRole -All -CisaHighlyPrivilegedRoles
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
    $result = "Current Ratio: $([System.Math]::Round($ratio,2)) = $($globalAdministrators.Count) / $($otherAssignments.Count)`n`n"
    $result += "Ratio >= 1 - $($ratio -ge 1)"


    return $testResult

}
