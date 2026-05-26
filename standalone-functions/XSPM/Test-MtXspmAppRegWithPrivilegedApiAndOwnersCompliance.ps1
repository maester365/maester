function Test-MtXspmAppRegWithPrivilegedApiAndOwnersCompliance {
    <#
    .SYNOPSIS
    Tests if app registration owners with privileged API permissions have delegated ownership.

    .DESCRIPTION
    This function checks all Entra ID app registrations with sensitive API permissions and checks if ownership has been delegated.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtXspmAppRegWithPrivilegedApiAndOwnersCompliance
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
        Write-Verbose "Get details from UnifiedIdentityInfo.."
        $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
    } catch {
        return $null
    }

    $HighPrivilegedAppsByApiPermissions = $UnifiedIdentityInfo | where-object {$_.ApiPermissions.Classification -eq "ControlPlane" -or $_.ApiPermissions.Classification -eq "ManagementPlane" -or $_.ApiPermissions.PrivilegeLevel -eq "High" }
    $SensitiveApiRolesOnAppsWithOwners = $HighPrivilegedAppsByApiPermissions | Where-Object { $null -ne $_.OwnedBy -and $_.Type -eq "Workload" }

    if ($return -or [string]::IsNullOrEmpty($SensitiveApiRolesOnAppsWithOwners) ) {
    } else {

        Write-Verbose "Found $($SensitiveApiRolesOnAppsWithOwners.Count) app registrations with privileged API permission assigned to owner."

        $result = "| ApplicationName | Ownership | Tier Breach | Sensitive App Role |`n"
        $result += "| --- | --- | --- | ---  |`n"
        foreach ($SensitiveApp in $SensitiveApiRolesOnAppsWithOwners) {
            $filteredApiPermissions = $SensitiveApp.ApiPermissions | Where-Object { $_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane" -or $_.PrivilegeLevel -eq "High" } | Select-Object AppDisplayName, AppRoleDisplayName, Classification
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

                # Summary of App roles in one column (as workaround for missing support of simple linebreak in one call)
                $AppRolesSummary = $filteredApiPermissions | Select-Object -Unique AppDisplayName | ForEach-Object {
                    $AppDisplayName = $_.AppDisplayName
                    $AppRoles = $filteredApiPermissions | Where-Object {$_.AppDisplayName -eq $AppDisplayName} | Select-Object AppRoleDisplayName
                    "$AppDisplayName" + ": " + "$($AppRoles| ForEach-Object { '`' + $_.AppRoleDisplayName + '`' })"
                }

                $ServicePrincipalLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($SensitiveApp.AppId)/isMSAApp~/false)"
                $result += "| $($AdminTierLevelIcon) $($ServicePrincipalLink) | $($Owner) | $($TierBreach) | $($AppRolesSummary) |`n"
            }
        }
    }
    $result = [string]::IsNullOrEmpty($SensitiveApiRolesOnAppsWithOwners)
    return $result

}
