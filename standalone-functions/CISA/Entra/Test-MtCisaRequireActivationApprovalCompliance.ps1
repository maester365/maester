function Test-MtCisaRequireActivationApprovalCompliance {
    <#
    .SYNOPSIS
    Checks for approval requirement on activation of Gloabl Admin role

    .DESCRIPTION
    Activation of the Global Administrator role SHALL require approval.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaRequireActivationApprovalCompliance
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

    $globalAdministratorsRole = Get-MgDirectoryRole -All | Where-Object {`
        $_.id -eq "62e90394-69f5-4237-9190-012177145e10" }

    $policySplat = @{
        ApiVersion      = "v1.0"
        RelativeUri     = "policies/roleManagementPolicyAssignments"
        Filter          = "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$($globalAdministratorsRole.id)'"
        QueryParameters = @{
            expand = "policy(expand=rules)"
        }
    }
    $policy = Invoke-MtGraphRequest @policySplat

    $testResult = ($policy.policy.rules | Where-Object {`
        $_.'@odata.type' -eq "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
    }).setting.isApprovalRequired -eq $true
    return $testResult

}
