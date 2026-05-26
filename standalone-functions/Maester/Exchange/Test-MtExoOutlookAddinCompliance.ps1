function Test-MtExoOutlookAddinCompliance {
    <#
    .SYNOPSIS
    Checks if users installing Outlook add-ins is not allowed

    .DESCRIPTION
    This command checks if users are able to install add-ins for Outlook in Exchange Online.
    By default, users can install add-ins in their Microsoft Outlook Desktop client, allowing data
    access within the client application. Attackers exploit vulnerable or custom add-ins to access user data.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtExoOutlookAddinCompliance
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
        $exoSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened' }
        if ($null -eq $exoSession) {
            Write-Verbose "Not connected to Exchange Online"
            return $null
        }
    } catch {
        Write-Verbose "Exchange Online connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {
        Write-Verbose "Getting Role Assignment Policies..."
        $roleAssignmentPolicy = Get-RoleAssignmentPolicy
        Write-Verbose "Found $($roleAssignmentPolicy.Count) Exchange Role Assignment Policy"


        $roleAssignmentPolicyDefault = $roleAssignmentPolicy | Where-Object { $_.Identity -eq "Default Role Assignment Policy" }
        Write-Verbose "Filtered $($roleAssignmentPolicyDefault.Count) Default Web mailbox policy"

        # Get Management Role Assignments
        $managementRoleAssignments = Get-ManagementRoleAssignment

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
        } else {
        }

    } catch {
        return $null
    }

    return !$result

}
