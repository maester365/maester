function Test-MtXspmAppRegWithPrivilegedApiAndOwners {
    <#
    .SYNOPSIS
    Tests if app registration owners with privileged API permissions have delegated ownership.

    .DESCRIPTION
    This function checks all Entra ID app registrations with sensitive API permissions and checks if ownership has been delegated.

    .OUTPUTS
    [bool] - Returns $true if no owners on app registrations with privileged API permissions, $false if any owners have been assigned, $null if skipped or prerequisites not met.

    .EXAMPLE
    Test-MtXspmAppRegWithPrivilegedApiAndOwners

    .LINK
    https://maester.dev/docs/commands/Test-MtXspmAppRegWithPrivilegedApiAndOwners
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks for multiple owners for each application object.')]
    [OutputType([bool])]
    param()

    $UnifiedIdentityInfoExecutable = Get-MtXspmUnifiedIdentityInfo -ValidateRequiredTablesOnly
    if ( $UnifiedIdentityInfoExecutable -eq $false) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test requires availability of MDA App Governance and MDI to get data for Defender XDR Advanced Hunting tables. Check https://maester.dev/docs/tests/MT.1077/#Prerequisites for more information.'
        return $null
    }

    try {
        Write-Verbose "Get details from UnifiedIdentityInfo.."
        $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    $HighPrivilegedAppsByApiPermissions = $UnifiedIdentityInfo | where-object { $_.ApiPermissions.Classification -eq "ControlPlane" -or $_.ApiPermissions.Classification -eq "ManagementPlane" -or $_.ApiPermissions.PrivilegeLevel -eq "High" } | sort-object AccountDisplayName
    $SensitiveApiRolesOnAppsWithOwners = $HighPrivilegedAppsByApiPermissions | Where-Object { $null -ne $_.OwnedBy -and $_.Type -eq "Workload" }

    $result = ''
    if ($return -or [string]::IsNullOrEmpty($SensitiveApiRolesOnAppsWithOwners) ) {
        $testResultMarkdown = "Well done. No app registrations with privileged API permission has assigned to owner."
    } else {

        Write-Verbose "Found $($SensitiveApiRolesOnAppsWithOwners.Count) app registrations with privileged API permission assigned to owner."

        $testResultMarkdown = "At least one app registration has assigned owner with privileged API permissions.`n`n%TestResult%"
        $result = "| ApplicationName | Ownership | Tier Breach | Sensitive App Role |`n"
        $result += "| --- | --- | --- | ---  |`n"
        foreach ($SensitiveApp in $SensitiveApiRolesOnAppsWithOwners) {
            $filteredApiPermissions = $SensitiveApp.ApiPermissions | Where-Object { $_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane" -or $_.PrivilegeLevel -eq "High" } | Select-Object TargetAppDisplayName, PermissionValue, PermissionType, Classification
            $permissionClassifications = @($filteredApiPermissions.Classification | Where-Object { -not [string]::IsNullOrEmpty($_) } | Sort-Object -Unique)
            $effectiveClassification = if ($permissionClassifications -contains "ControlPlane") {
                "ControlPlane"
            } elseif ($permissionClassifications -contains "ManagementPlane") {
                "ManagementPlane"
            } else {
                "Unknown"
            }
            $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $effectiveClassification
            $SensitiveApp.OwnedBy | ForEach-Object {
                $Owner = $_
                $XspmIdentifiers = ($Owner.EntityIds | Where-Object { $_.type -eq "AadObjectId" }).id
                if ($XspmIdentifiers -match 'objectid=([0-9a-fA-F\-]{36})') {
                    $MatchedObjectId = $matches[1]
                    $MatchedOwner = $UnifiedIdentityInfo | Where-Object { $_.AccountObjectId -eq $MatchedObjectId }
                    if ($null -eq $MatchedOwner) {
                        # In case owner is missing in Defender XDR tables
                        $MatchedOwner = [PSCustomObject]@{ Classification = "Unknown"; Type = "Unknown"; AccountObjectId = $MatchedObjectId; AppId = $null; AccountDisplayName = "Unknown" }
                    }
                    $OwnerAdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $MatchedOwner.Classification
                    if ($MatchedOwner.Type -eq "Workload") {
                        $OwnerLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($MatchedOwner.AccountObjectId)/appId/$($MatchedOwner.AppId))"
                    } else {
                        $OwnerLink = "[$($MatchedOwner.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($MatchedOwner.AccountObjectId))"
                    }
                    $Owner = "$($OwnerAdminTierLevelIcon) $OwnerLink"
                    $TierBreach = $MatchedOwner.Classification -ne "ControlPlane" -and ($permissionClassifications -notcontains $MatchedOwner.Classification)
                } else {
                    $Owner = $($_.NodeName) - $($_.NodeLabel)
                    $TierBreach = "Unknown"
                }

                # Summary of App roles in one column (as workaround for missing support of simple linebreak in one call)
                $ApiPermissionSummary = $filteredApiPermissions | Select-Object -Unique TargetAppDisplayName, PermissionType | ForEach-Object {
                    $TargetAppDisplayName = $_.TargetAppDisplayName
                    $PermissionType = $_.PermissionType
                    $ApiPermissions = $filteredApiPermissions | Where-Object { $_.TargetAppDisplayName -eq $TargetAppDisplayName -and $_.PermissionType -eq $PermissionType } | Select-Object PermissionValue
                    "$TargetAppDisplayName ($PermissionType)" + ": " + "$($ApiPermissions| ForEach-Object { '`' + $_.PermissionValue + '`' })"
                }

                $ServicePrincipalLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($SensitiveApp.AppId)/isMSAApp~/false)"
                $result += "| $($AdminTierLevelIcon) $($ServicePrincipalLink) | $($Owner) | $($TierBreach) | $($ApiPermissionSummary) |`n"
            }
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity "High"
    $result = [string]::IsNullOrEmpty($SensitiveApiRolesOnAppsWithOwners)
    return $result
}
