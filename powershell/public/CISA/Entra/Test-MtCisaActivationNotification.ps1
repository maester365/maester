<#
.SYNOPSIS
    Checks for notification on role activation

.DESCRIPTION

    User activation of the Global Administrator role SHALL trigger an alert.
    User activation of other highly privileged roles SHOULD trigger an alert.

.EXAMPLE
    Test-MtCisaActivationNotification

    Returns true if notifications are set for activation of the highly privileged roles other than Global Admin

.EXAMPLE
    Test-MtCisaActivationNotification -GlobalAdminOnly

    Returns true if notifications are set for activation of the Global Admin role
#>

Function Test-MtCisaActivationNotification {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [switch]$GlobalAdminOnly
    )

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"
    if(-not $pim){
        return $false
    }

    $roles = Get-MtRole -CisaHighlyPrivilegedRoles
    if($GlobalAdminOnly){
        $roles = $roles | Where-Object {`
            $_.displayName -eq "Global Administrator"
        }
    }else{
        $roles = $roles | Where-Object {`
            $_.displayName -ne "Global Administrator"
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

    $testResult = $misconfigured.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has notifications for role activations:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have notifications on role activations."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}