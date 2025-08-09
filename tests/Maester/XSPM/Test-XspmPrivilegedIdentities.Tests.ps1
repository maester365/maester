BeforeDiscovery {

    $AdvancedIdentityAvailable = ((Invoke-MtGraphRequest -ApiVersion "beta" -RelativeUri "security/runHuntingQuery" -Method POST `
        -Body (@{"Query" = "IdentityInfo | getschema | where ColumnName == 'PrivilegedEntraPimRoles'"} | ConvertTo-Json) `
        -OutputType PSObject -Verbose).results.ColumnName -eq "PrivilegedEntraPimRoles")
    $OAuthAppInfoAvailable = ((Invoke-MtGraphRequest -ApiVersion "beta" -RelativeUri "security/runHuntingQuery" -Method POST `
        -Body (@{"Query" = "OAuthAppInfo | getschema"} | ConvertTo-Json) `
        -OutputType PSObject -Verbose).results.ColumnName -contains "OAuthAppId")
    $UnifiedIdentityInfoExecutable = $AdvancedIdentityAvailable -and $OAuthAppInfoAvailable
    $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"

    Write-Verbose "IdentityInfo: $AdvancedIdentityAvailable"
    Write-Verbose "OAuthAppInfo: $OAuthAppInfoAvailable"
    Write-Verbose "UnifiedIdentityInfoExecutable is $UnifiedIdentityInfoExecutable (IdentityInfo is $AdvancedIdentityAvailable, $OAuthAppInfoAvailable)"


    function Get-XspmPrivilegedClassificationIcon {
        param (
            [Parameter(Mandatory = $true)]
            [object]$AdminTierLevelName
        )
        #region Classification icon
        if ($AdminTierLevelName -contains 'ControlPlane') {
            $AdminTierLevelIcon = "🔐"
        } elseif ($AdminTierLevelName -contains 'ManagementPlane') {
            $AdminTierLevelIcon = "☁️"
        } elseif ($AdminTierLevelName -contains 'WorkloadPlane') {
            $AdminTierLevelIcon = "⚙️"
        } elseif ($AdminTierLevelName -contains 'High') {
            $AdminTierLevelIcon = "⚠️"
        } else {
            $AdminTierLevelIcon = "ℹ️"
        }
        return $AdminTierLevelIcon
        #endregion
    }

}

Describe "Exposure Management - Privileged Assets" -Tag "Maester", "Privileged", "XSPM", "EntraOps" -Skip:( $EntraIDPlan -ne "P2" ) {
    It "MT.1071: Workload identities with high-privileged API permissions should have no owners. See https://maester.dev/docs/tests/MT.1071" -Tag "MT.1071" {

    $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
    Write-Verbose "Found $($UnifiedIdentityInfo.Count) application or workload identities"

    $HighPrivilegedAppsByApiPermissions = $UnifiedIdentityInfo | where-object {$_.ApiPermissions.EAMTierLevelName -eq "ControlPlane" -or $_.ApiPermissions.EAMTierLevelName -eq "ManagementPlane" -or $_.ApiPermissions.PrivilegeLevel -eq "High" }
    $SensitiveApiRolesOnAppsWithOwners = $HighPrivilegedAppsByApiPermissions | Where-Object { $null -ne $_.OwnedBy -and $_.Type -eq "Workload" }

    if ($return) {
        $testResultMarkdown = "Well done. No application and workload identity has a privileged API permission with an owner."
    } else {
        $testResultMarkdown = "At least one application has owner with a risk of sensitive API permissions.`n`n%TestResult%"

        $result = "| ApplicationName | Ownership | Sensitive App Role | API Provider |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach ($SensitiveApp in $SensitiveApiRolesOnAppsWithOwners) {
            $filteredApiPermissions = $SensitiveApp.ApiPermissions | Where-Object { $_.EAMTierLevelName -eq "ControlPlane" -or $_.EAMTierLevelName -eq "ManagementPlane" -or $_.PrivilegeLevel -eq "High" } | Select-Object AppDisplayName, AppRoleDisplayName, EAMTierLevelName
            $AdminTierLevelIcon = Get-XspmPrivilegedClassificationIcon -AdminTierLevelName $filteredApiPermissions.EAMTierLevelName
            $SensitiveApp.OwnedBy | ForEach-Object {
                $ServicePrincipalLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($SensitiveApp.AccountObjectId)/appId/$($SensitiveApp.AppId))"

                $result += "| $($AdminTierLevelIcon) $($ServicePrincipalLink) | $($_.NodeName) - $($_.NodeLabel) | $($filteredApiPermissions.AppRoleDisplayName) | $($filteredApiPermissions.AppDisplayName) |`n"
            }
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    $SensitiveApiRolesOnAppsWithOwners.Count -eq "0" | Should -Be $True -Because $benefits
    }

    It "MT.1072: Workload identities with high-privileged directory roles should have no owners. See https://maester.dev/docs/tests/MT.1072" -Tag "MT.1072" {

        try {
            $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
            Write-Verbose "Found $($UnifiedIdentityInfo.Count) application or workload identities"
        } catch {
            Write-Verbose "Authentication needed. Please call Connect-MgGraph."
        }

        $HighPrivilegedAppsByEntraRoles = $UnifiedIdentityInfo | where-object {$_.AssignedEntraRoles.EAMTierLevelName -eq "ControlPlane" -or $_.AssignedEntraRoles.EAMTierLevelName -eq "ManagementPlane" -or $_.AssignedEntraRoles.RoleIsPrivileged -eq $True }
        $SensitiveDirectoryRolesOnAppsWithOwners = $HighPrivilegedAppsByEntraRoles | Where-Object { $null -ne $_.OwnedBy -and $_.Type -eq "Workload" }

        if ($return) {
            $testResultMarkdown = "Well done. No application and workload identity has a privileged directory role with an owner."
        } else {
            $testResultMarkdown = "At least one application has ownership with a risk of sensitive directory role.`n`n%TestResult%"

            $result = "| ApplicationName | ApplicationId | Ownership | Sensitive Directory Role | API Provider |`n"
            $result += "| --- | --- | --- | --- | --- |`n"
            foreach ($SensitiveApp in $SensitiveDirectoryRolesOnAppsWithOwners) {
                $filteredApiPermissions = $SensitiveApp.AssignedEntraRoles | where-object {$_.Classification.EAMTierLevelName -eq "ControlPlane" -or $_.Classification.EAMTierLevelName -eq "ManagementPlane" -or $_.RoleIsPrivileged -eq $True } | Select-Object RoleDefinitionName, Classification
                # XSPM supports only Directory scope for now
                $filteredApiPermissions | Add-Member -MemberType NoteProperty -Name RoleScope -Value "Directory" -Force
                $AdminTierLevelIcon = Get-XspmPrivilegedClassificationIcon -AdminTierLevelName $filteredApiPermissions.Classification.EAMTierLevelName
                $SensitiveApp.OwnedBy | ForEach-Object {
                    $result += "| $($AdminTierLevelIcon) $($SensitiveApp.AccountDisplayName) | $($SensitiveApp.AccountObjectId) | $($_.NodeName) - $($_.NodeLabel) | $($filteredApiPermissions.RoleDefinitionName) | $($filteredApiPermissions.RoleScope) |`n"
                }
            }
            $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        }
        Add-MtTestResultDetail -Result $testResultMarkdown
        #endregion
        # Actual test
        $SensitiveApiRolesOnAppsWithOwners.Count -eq "0" | Should -Be $True -Because $benefits
    }

    It "MT.1073: Privileged API permissions on workload identities should not be unused. See https://maester.dev/docs/tests/MT.1073" -Tag "MT.1073" {

        try {
            $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
            Write-Verbose "Found $($UnifiedIdentityInfo.Count) application or workload identities"
        } catch {
            Write-Verbose "Authentication needed. Please call Connect-MgGraph."
        }

        $HighPrivilegedAppsByApiPermissions = $UnifiedIdentityInfo | where-object {$_.ApiPermissions.EAMTierLevelName -eq "ControlPlane" -or $_.ApiPermissions.EAMTierLevelName -eq "ManagementPlane" -or $_.ApiPermissions.PrivilegeLevel -eq "High" }
        $SensitiveAppsWithUnusedPermissions = $HighPrivilegedAppsByApiPermissions | Where-Object { $_.ApiPermissions.InUse -eq $false }

        if ($return) {
            $testResultMarkdown = "Well done. No application and workload identity has a privileged API permission which are unused"
        } else {
            $testResultMarkdown = "At least one application has unused sensitive API permissions.`n`n%TestResult%"

            $result = "| ApplicationName | ApplicationId | Enterprise Access Level | Sensitive App Role | API Provider |`n"
            $result += "| --- | --- | --- | --- | --- |`n"
            foreach ($SensitiveApp in $SensitiveAppsWithUnusedPermissions) {
                $filteredApiPermissions = $SensitiveApp.ApiPermissions | Where-Object { ($_.EAMTierLevelName -eq "ControlPlane" -or $_.EAMTierLevelName -eq "ManagementPlane" -or $_.PrivilegeLevel -eq "High") -and $_.InUse -eq $false } | Select-Object AppDisplayName, AppRoleDisplayName, EAMTierLevelName | sort-object EAMTierLevelName, AppDisplayName
                if($filteredApiPermissions) {
                    $SensitiveApp.OwnedBy | ForEach-Object {
                        $AdminTierLevelIcon = Get-XspmPrivilegedClassificationIcon -AdminTierLevelName $filteredApiPermissions.EAMTierLevelName
                        $result += "| $($AdminTierLevelIcon) $($SensitiveApp.AccountDisplayName) | $($SensitiveApp.AccountObjectId) | $($SensitiveApp.EAMTierLevelName) | $($filteredApiPermissions.AppRoleDisplayName) | $($filteredApiPermissions.AppDisplayName) |`n"
                    }
                }
            }
            $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        }
        Add-MtTestResultDetail -Result $testResultMarkdown
        #endregion
        # Actual test
        $SensitiveApiRolesOnAppsWithOwners.Count -eq "0" | Should -Be $True -Because $benefits
    }


    It "MT.1078: Hybrid users should not be assigned to Entra ID role assignments. See https://maester.dev/docs/tests/MT.1078" -Tag "MT.1078" {

        $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
        $HighPrivilegedUsersByEntraRoles = $UnifiedIdentityInfo | Where-Object { $_.Type -eq "User" -and ($_.AssignedEntraRoles.Classification -eq "ControlPlane" -or $_.AssignedEntraRoles.Classification -eq "ManagementPlane" -or $_.AssignedEntraRoles.RoleIsPrivileged -eq $True) | Sort-Object Classification, AccountDisplayName}
        $HighPrivilegedHybridUsers = $HighPrivilegedUsersByEntraRoles | Where-Object { $_.SourceProviders -ne "AzureActiveDirectory"}

        if ($return) {
            $testResultMarkdown = "Well done. No hybrid users with sensitive directory roles."
        } else {
            $testResultMarkdown = "At least one hybrid user with a risk of sensitive directory role membership.`n`n%TestResult%"

            $result = "| AccountName | Classification | Sensitive Directory Role | ChangeSource |`n"
            $result += "| --- | --- | --- | --- |`n"
            foreach ($HighPrivilegedHybridUser in $HighPrivilegedHybridUsers) {
                $filteredDirectoryRole = $HighPrivilegedHybridUser.AssignedEntraRoles | Where-Object { $_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane" -or $_.RoleIsPrivileged -eq $True} | Select-Object RoleDefinitionName, Classification
                $AdminTierLevelIcon = Get-XspmPrivilegedClassificationIcon -AdminTierLevelName $HighPrivilegedHybridUser.Classification
                $HybridUserLink = "[$($HighPrivilegedHybridUser.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($HighPrivilegedHybridUser.AccountObjectId))"
                $result += "| $($AdminTierLevelIcon) $($HybridUserLink) | $($HighPrivilegedHybridUser.Classification) | $($filteredDirectoryRole.RoleDefinitionName) - $($filteredDirectoryRole.Classification)) | $($HighPrivilegedHybridUser.SourceProvider) |`n"
            }
            $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        }
        Add-MtTestResultDetail -Result $testResultMarkdown

        $PrivilegedHybridUsers.Count -eq "0" | Should -Be $True -Because $benefits
    }
}

<#

Describe "Exposure Management - No secrets on privileged workloads" -Tag "Maester", "Privileged", "XSPM", "EntraOps" {
}


Describe "Exposure Management - No exposed Entra ID user credentials on workloads" -Tag "Maester", "Privileged", "XSPM", "EntraOps" {
}


Describe "Exposure Management - No exposed credentials, token or cookies of privileged users on vulnerable endpoints" -Tag "Maester", "Privileged", "XSPM", "EntraOps" {
    #Get-MtXspmExposedTokenArtifcats
}


    $HighPrivilegedAppsByEntraRoles = $UnifiedIdentityInfo | where-object {$_.AssignedEntraRoles.EAMTierLevelName -eq "ControlPlane" -or $_.AssignedEntraRoles.EAMTierLevelName -eq "ManagementPlane" -or $_.AssignedEntraRoles.RoleIsPrivileged -eq $True }
    $HighPrivilegedApps = @($HighPrivilegedAppsByApiPermissions; $HighPrivilegedAppsByEntraRoles) | Sort-Object AccountObjectId -Unique

#>


