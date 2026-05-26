function Test-MtCisaAssignmentNotificationCompliance {
    <#
    .SYNOPSIS
    Checks for notification on role assignments

    .DESCRIPTION
    Eligible and Active highly privileged role assignments SHALL trigger an alert.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaAssignmentNotificationCompliance
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
    $rolePolicies = @()

    foreach($role in $roles){
        $rolePolicy = [PSCustomObject]@{
            role           = $role.displayName
            eligibleNotify = $false
            activeNotify   = $false
        }
        $policySplat = @{
            ApiVersion      = "v1.0"
            RelativeUri     = "policies/roleManagementPolicyAssignments"
            Filter          = "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$($role.id)'"
            QueryParameters = @{
                expand = "policy(expand=rules)"
            }
        }
        $policy = Invoke-MtGraphRequest @policySplat

        $eligibleNotify = $policy.policy.rules | Where-Object {`
            $_.id -eq "Notification_Admin_Admin_Eligibility" -and `
            $_.notificationRecipients
        }
        $activeNotify = $policy.policy.rules | Where-Object {`
            $_.id -eq "Notification_Admin_Admin_Assignment" -and `
            $_.notificationRecipients
        }
        $rolePolicy.eligibleNotify = -not $null -eq $eligibleNotify
        $rolePolicy.activeNotify   = -not $null -eq $activeNotify

        $rolePolicies += $rolePolicy
    }

    $misconfigured = $rolePolicies | Where-Object {`
        -not $_.eligibleNotify -or -not $_.activeNotify
    }

    $testResult = ($misconfigured|Measure-Object).Count -eq 0

    $resultFail = "❌ Fail"
    $resultPass = "✅ Pass"

    if ($testResult) {
    } else {
        $misconfigured | ForEach-Object {
        }
    }

    return $testResult

}
