<#
.SYNOPSIS
    Checks if users installing Outlook add-ins is not allowed

.DESCRIPTION
    This command checks if users are able to install add-ins for Outlook in Exchange Online.
    By default, users can install add-ins in their Microsoft Outlook Desktop client, allowing data
    access within the client application. Attackers exploit vulnerable or custom add-ins to access user data.

.EXAMPLE
    Test-MtExoOutlookAddin

    Returns true if users are restricted from installing Outlook add-ins.

.LINK
    https://maester.dev/docs/commands/Test-MtExoOutlookAddin
#>
function Test-MtExoOutlookAddin {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        Write-Verbose "Getting Role Assignment Policies..."
        $roleAssignmentPolicy = Get-MtExo -Request RoleAssignmentPolicy
        Write-Verbose "Found $($roleAssignmentPolicy.Count) Exchange Role Assignment Policy"

        $portalLink_SecureScore = "$($__MtSession.AdminPortalUrl.Security)securescore"

        $roleAssignmentPolicyDefault = $roleAssignmentPolicy | Where-Object { $_.Identity -eq "Default Role Assignment Policy" }
        Write-Verbose "Filtered $($roleAssignmentPolicyDefault.Count) Default Web mailbox policy"

        # Get Management Role Assignments
        $managementRoleAssignments = Get-MtExo -Request ManagementRoleAssignment

        $myCustomApps = $managementRoleAssignments | Where-Object {
            $_.Role -eq "My Custom Apps" -and $_.RoleAssigneeName -eq $roleAssignmentPolicyDefault.Name
        }
        $myMarketplaceApps = $managementRoleAssignments | Where-Object {
            $_.Role -eq "My Marketplace Apps" -and $_.RoleAssigneeName -eq $roleAssignmentPolicyDefault.Name
        }
        $myReadWriteMailboxApps = $managementRoleAssignments | Where-Object {
            $_.Role -eq "My ReadWriteMailbox Apps" -and $_.RoleAssigneeName -eq $roleAssignmentPolicyDefault.Name
        }

        $result = [bool]$myCustomApps -or [bool]$myMarketplaceApps -or [bool]$myReadWriteMailboxApps

        if ($result -eq $false) {
            $testResultMarkdown = "Well done. Apps in 'Default Role Assignment Policy' is ``$($result)```n`n"
        } else {
            $testResultMarkdown = "Apps in 'Default Role Assignment Policy' should be ``False`` and is ``$($result)`` in [SecureScore]($portalLink_SecureScore)`n`n"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    return !$result
}