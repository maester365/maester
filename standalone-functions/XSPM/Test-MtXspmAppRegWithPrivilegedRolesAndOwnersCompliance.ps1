function Test-MtXspmAppRegWithPrivilegedRolesAndOwnersCompliance {
    <#
    .SYNOPSIS
    Tests if app registration owners with highly privileged Entra ID roles have delegated ownership.

    .DESCRIPTION
    This function checks all Entra ID app registrations with highly privileged Entra ID roles and checks if ownership has been delegated.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtXspmAppRegWithPrivilegedRolesAndOwnersCompliance
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
    # Phase 2: Data Collection & Phase 3: Compliance Validation
    $UnifiedIdentityInfoExecutable = Get-MtXspmUnifiedIdentityInfo -ValidateRequiredTablesOnly
    if ( $UnifiedIdentityInfoExecutable -eq $false) {
            return $null
    }

    try {
        Write-Verbose "Get details from UnifiedIdentityInfo ..."
        $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
    } catch {
        return $null
    }

    $HighPrivilegedAppsByEntraRoles = $UnifiedIdentityInfo | where-object {$_.AssignedEntraRoles.Classification -eq "ControlPlane" -or $_.AssignedEntraRoles.Classification -eq "ManagementPlane" -or $_.AssignedEntraRoles.RoleIsPrivileged -eq $True }
    $SensitiveDirectoryRolesOnAppsWithOwners = $HighPrivilegedAppsByEntraRoles | Where-Object { $null -ne $_.OwnedBy -and $_.Type -eq "Workload" }

    if ($return -or [string]::IsNullOrEmpty($SensitiveDirectoryRolesOnAppsWithOwners)) {
    } else {

        $result = "| ApplicationName | Ownership | Tier Breach | Sensitive Directory Role |`n"
        $result += "| --- | --- | --- | --- |`n"

        Write-Verbose "Found $($SensitiveDirectoryRolesOnAppsWithOwners.Count) app registrations with directory role assigned to owner."

        foreach ($SensitiveApp in $SensitiveDirectoryRolesOnAppsWithOwners) {
            $filteredApiPermissions = $SensitiveApp.AssignedEntraRoles | where-object {$_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane" -or $_.RoleIsPrivileged -eq $True } | Select-Object RoleDefinitionName, Classification
            # XSPM supports only Directory scope for now
            $filteredApiPermissions | Add-Member -MemberType NoteProperty -Name RoleScope -Value "Directory" -Force
            $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $filteredApiPermissions.Classification
            $SensitiveApp.OwnedBy | ForEach-Object {
                $Owner = $_
                $XspmIdentifiers = ($Owner.EntityIds | Where-Object {$_.type -eq "AadObjectId"}).id
                if ($XspmIdentifiers -match 'objectid=([0-9a-fA-F\-]{36})') {
                    $MatchedObjectId = $matches[1]
                    $MatchedOwner = $UnifiedIdentityInfo | Where-Object {$_.AccountObjectId -eq $MatchedObjectId}
                    $OwnerAdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $MatchedOwner.Classification
                    if ($MatchedOwner.Type -eq "Workload") {
                        $OwnerLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($MatchedOwner.AccountObjectId)/appId/$($MatchedOwner.AppId))"
                    } else {
                        $OwnerLink = "[$($MatchedOwner.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($MatchedOwner.AccountObjectId))"
                    }
                    $Owner = "$($OwnerAdminTierLevelIcon) $OwnerLink"
                    $TierBreach = $MatchedOwner.Classification -ne "ControlPlane" -and $MatchedOwner.Classification -ne "$filteredApiPermissions.Classification"
                } else {
                    $Owner = $($_.NodeName) - $($_.NodeLabel)
                    $TierBreach = "Unknown"
                }

                # Increase severity to high if tier breach detected
                if ($TierBreach -eq $true) {
                    $Severity = "High"
                } else {
                    $Severity = "Medium"
                }

                # Summary of App roles in one column (as workaround for missing support of simple linebreak in one call)
                $DirectoryRolesSummary = $filteredApiPermissions | Select-Object -Unique RoleScope | ForEach-Object {
                    $RoleScope = $_.RoleScope
                    $DirectoryRoles = $filteredApiPermissions | Where-Object {$_.RoleScope -eq $RoleScope} | Select-Object RoleDefinitionName
                    "Scope $($RoleScope)" + ": " + "$($DirectoryRoles| ForEach-Object { '`' + $_.RoleDefinitionName + '`' })"
                }


                $ServicePrincipalLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($SensitiveApp.AccountObjectId)/appId/$($SensitiveApp.AppId))"
                $result += "| $($AdminTierLevelIcon) $($ServicePrincipalLink) | $($Owner) | $($TierBreach) | $($DirectoryRolesSummary) |`n"
            }
        }
    }

    $result = [string]::IsNullOrEmpty($SensitiveDirectoryRolesOnAppsWithOwners)
    return $result

}
