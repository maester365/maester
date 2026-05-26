function Test-MtXspmAppRegWithPrivilegedUnusedPermissionsCompliance {
    <#
    .SYNOPSIS
    Tests if app registration have assigned privileged API permissions which are unused.

    .DESCRIPTION
    This function checks all Entra ID app registrations with privileged API permissions and checks if any of them are unused.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtXspmAppRegWithPrivilegedUnusedPermissionsCompliance
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

    $Severity = "Medium"
    $HighPrivilegedAppsByApiPermissions = $UnifiedIdentityInfo | where-object {$_.ApiPermissions.Classification -eq "ControlPlane" -or $_.ApiPermissions.Classification -eq "ManagementPlane" -or $_.ApiPermissions.PrivilegeLevel -eq "High" }
    $SensitiveAppsWithUnusedPermissions = $HighPrivilegedAppsByApiPermissions | Where-Object { $_.ApiPermissions.InUse -eq $false }

    if ($return -or [string]::IsNullOrEmpty($SensitiveAppsWithUnusedPermissions)) {
    } else {

        $result = "| ApplicationName | Enterprise Access Level | Sensitive App Role | API Provider |`n"
        $result += "| --- | --- | --- | --- | `n"

        Write-Verbose "Found $($SensitiveAppsWithUnusedPermissions.Count) app registrations with unused sensitive API permissions."

        foreach ($SensitiveApp in $SensitiveAppsWithUnusedPermissions) {
            $filteredApiPermissions = $SensitiveApp.ApiPermissions | Where-Object { ($_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane" -or $_.PrivilegeLevel -eq "High") -and $_.InUse -eq $false } | Select-Object AppDisplayName, AppRoleDisplayName, Classification | sort-object Classification, AppDisplayName
            if($filteredApiPermissions) {
                foreach ($filteredApiPermission in $filteredApiPermissions) {
                    if ($filteredApiPermission.Classification -eq "") { $filteredApiPermission.Classification = "Unknown" }
                    $ServicePrincipalLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($SensitiveApp.AccountObjectId)/appId/$($SensitiveApp.AppId))"
                    $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $SensitiveApp.Classification
                    $result += "| $($AdminTierLevelIcon) $($ServicePrincipalLink) | $($filteredApiPermission.Classification) | $($filteredApiPermission.AppRoleDisplayName) | $($filteredApiPermission.AppDisplayName) |`n"
                }
            }
        }
    }
    $result = [string]::IsNullOrEmpty($SensitiveAppsWithUnusedPermissions)
    return $result

}
