﻿<#
.SYNOPSIS
    Checks for approval requirement on activation of Gloabl Admin role

.DESCRIPTION
    Activation of the Global Administrator role SHALL require approval.

.EXAMPLE
    Test-MtCisaRequireActivationApproval

    Returns true if the Global Admin role requires approval on activation

.LINK
    https://maester.dev/docs/commands/Test-MtCisaRequireActivationApproval
#>
function Test-MtCisaRequireActivationApproval {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"
    if(-not $pim){
        return $false
    }

    $globalAdministratorsRole = Get-MtRole | Where-Object {`
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

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no unmanaged active role assignments:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant has active assignments without a start date."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}