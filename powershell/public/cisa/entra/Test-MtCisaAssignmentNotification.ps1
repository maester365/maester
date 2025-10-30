<#
.SYNOPSIS
    Checks for notification on role assignments

.DESCRIPTION
    Eligible and Active highly privileged role assignments SHALL trigger an alert.

.EXAMPLE
    Test-MtCisaAssignmentNotification

    Returns true if notifications are set for all roles

.LINK
    https://maester.dev/docs/commands/Test-MtCisaAssignmentNotification
#>
function Test-MtCisaAssignmentNotification {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"
    if(-not $pim){
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
        return $null
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

    $resultFail = "❌ Fail"
    $resultPass = "✅ Pass"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has notifications for any highly privileged role assignments:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant has highly privileged roles without notifications.`n`n"
        $testResultMarkdown += "| Role | Eligible Notification | Active Notification |`n"
        $testResultMarkdown += "| --- | --- | --- |`n"
        $misconfigured | ForEach-Object {
            $testResultMarkdown += "| $($_.role) | $(if ($_.eligibleNotify) {$resultPass} else {$resultFail}) | $(if ($_.activeNotify) {$resultPass} else {$resultFail}) |`n"
        }
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}