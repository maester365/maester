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

.LINK
    https://maester.dev/docs/commands/Test-MtCisaActivationNotification
#>
function Test-MtCisaActivationNotification {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Check Global Administrator role only
        [switch]$GlobalAdminOnly
    )

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }else{
        $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
        if($EntraIDPlan -notin @("P2","Governance")){
            if($EntraIDPlan -ne "P2"){
                Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2
                return $null
            }elseif($EntraIDPlan -ne "Governance"){
                #This will not currently be hit
                Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDGovernance
                return $null
            }
        }
    }

    $roles = Get-MtRole -CisaHighlyPrivilegedRoles
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

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has notifications for [role activations]($link).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have notifications on [role activations]($link).`n`n%TestResult%"
    }

    $result = "| Role Name | Result |`n"
    $result += "| --- | --- |`n"

    foreach ($item in $rolePolicies) {
        $itemResult = $resultFail
        if($item.activationNotify){
            $itemResult = $resultPass
        }
        $result += "| $($item.role) | $($itemResult) |`n"
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}