function Test-MtCisaPermanentRoleAssignmentCompliance {
    <#
    .SYNOPSIS
    Checks for permanent active role assingments

    .DESCRIPTION
    Permanent active role assignments SHALL NOT be allowed for highly privileged roles.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaPermanentRoleAssignmentCompliance
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

    try {
        $sku = Get-MgSubscribedSku | Where-Object { $_.ServicePlans.ServicePlanName -match 'AAD_PREMIUM_P2' }
        if ($null -eq $sku) {
            Write-Verbose "Entra ID P2 license not found"
            return $null
        }
    } catch {
        Write-Verbose "License check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"
    if(-not $pim){
        return $null
    }

    $roles = Get-MgDirectoryRole -All -CisaHighlyPrivilegedRoles
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
    if (-not $testResult) {
        $result = "| Role | Principal Type | Display Name | Status |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach($roleAssignment in ($roleAssignments | Where-Object {$_.principal})){
            foreach($principal in $roleAssignment.principal){
                $result += "| $($roleAssignment.role) | $($principal.'@odata.type'.Split('.')[-1]) | $($principal.displayName ) | ❌ No Expiration |`n"
            }
        }
    }


    return $testResult

}
