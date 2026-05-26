function Test-MtCisaActivationNotificationCompliance {
    <#
    .SYNOPSIS
    Checks for notification on role activation

    .DESCRIPTION
    User activation of the Global Administrator role SHALL trigger an alert.
    User activation of other highly privileged roles SHOULD trigger an alert.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaActivationNotificationCompliance
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

    $roles = Get-MgDirectoryRole -All -CisaHighlyPrivilegedRoles
    if($GlobalAdminOnly){
        $roles = $roles | Where-Object {`
            $_.id -eq "62e90394-69f5-4237-9190-012177145e10"
        }
    }else{
        $roles = $roles | Where-Object {`
            $_.id -ne "62e90394-69f5-4237-9190-012177145e10"
        }
    }

    $rolePolicies = @()

    foreach($role in $roles){
        $rolePolicy = [PSCustomObject]@{
            role             = $role.displayName
            activationNotify = $false
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

        $activationNotify = $policy.policy.rules | Where-Object {`
            $_.id -eq "Notification_Admin_EndUser_Assignment" -and `
            $_.notificationRecipients
        }
        $rolePolicy.activationNotify = -not $null -eq $activationNotify

        $rolePolicies += $rolePolicy
    }

    $misconfigured = $rolePolicies | Where-Object {`
        -not $_.activationNotify
    }

    $testResult = ($misconfigured|Measure-Object).Count -eq 0

    $link = "https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/ResourceMenuBlade/~/roles/resourceId//resourceType/tenant/provider/aadroles"
    $resultFail = "❌ Fail"
    $resultPass = "✅ Pass"
    $result = "| Role Name | Result |`n"
    $result += "| --- | --- |`n"
    return $testResult

}
