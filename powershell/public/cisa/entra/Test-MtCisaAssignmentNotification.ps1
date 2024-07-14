﻿<#
.SYNOPSIS
    Checks for notification on role assignments

.DESCRIPTION

    Eligible and Active highly privileged role assignments SHALL trigger an alert.

.EXAMPLE
    Test-MtCisaAssignmentNotification

    Returns true if notifications are set for all roles
#>

Function Test-MtCisaAssignmentNotification {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"
    if(-not $pim){
        return $false
    }

    $roles = Get-MtRole -CisaHighlyPrivilegedRoles
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

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has notifications for any highly privileged role assisngments:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant has highly privileged roles without notifications."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}