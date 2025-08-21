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

}

Describe "Exposure Management - Protection of classified assets identified by EntraOps and Critical Asset Management" -Tag "Full", "Maester", "Privileged", "XSPM", "EntraOps" -Skip:( $EntraIDPlan -ne "P2" ) {
    It "MT.1071: App registrations with privileged API permissions should have no owners. See https://maester.dev/docs/tests/MT.1071" -Tag "MT.1071" {

    try {
        $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
    } catch {
        Write-Verbose "Authentication needed. Please call Connect-MgGraph."
    }

    $HighPrivilegedAppsByApiPermissions = $UnifiedIdentityInfo | where-object {$_.ApiPermissions.Classification -eq "ControlPlane" -or $_.ApiPermissions.Classification -eq "ManagementPlane" -or $_.ApiPermissions.PrivilegeLevel -eq "High" }
    $SensitiveApiRolesOnAppsWithOwners = $HighPrivilegedAppsByApiPermissions | Where-Object { $null -ne $_.OwnedBy -and $_.Type -eq "Workload" }

    if ($return) {
        $testResultMarkdown = "Well done. No app registrations with privileged API permission has assigned to owner."
    } else {
        $testResultMarkdown = "At least one app registration has assigned owner with privileged API permissions.`n`n%TestResult%"
        $result = "| ApplicationName | Ownership | Tier Breach | Sensitive App Role | API Provider |`n"
        $result += "| --- | --- | --- | --- |  --- |`n"
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

                # Use <br/> for GitHub Flavored Markdown in-table line breaks
                $AppRoleDisplayName = $filteredApiPermissions.AppRoleDisplayName -join "<br/>"
                $AppDisplayName = $filteredApiPermissions.AppDisplayName -join "<br/>"

                $ServicePrincipalLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$($SensitiveApp.AppId)/isMSAApp~/false)"
                $result += "| $($AdminTierLevelIcon) $($ServicePrincipalLink) | $($Owner) | $($TierBreach) | $($AppRoleDisplayName) | $($AppDisplayName) |`n"
            }
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Description "High privileged app registration will be identified by using data from OAuthAppInfo and the high privilege level by MDA App Governance but also Control Plane and Management Plane classification by the community project EntraOps. Ownership on app registrations will be identified by Microsoft Security Exposure Management" -Severity "High"
    $SensitiveApiRolesOnAppsWithOwners.Count -eq "0" | Should -Be $True -Because "avoid permanent ownership on high-privileged apps"
    }

    It "MT.1072: Workload identities with high-privileged directory roles should have no owners. See https://maester.dev/docs/tests/MT.1072" -Tag "MT.1072" {

        if ( $UnifiedIdentityInfoExecutable -eq $false) {
                Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test requires availability of MDA App Governance and MDI to get data for Defender XDR Advanced Hunting tables.'
                return $null
        }

        try {
            $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
        } catch {
            Write-Verbose "Authentication needed. Please call Connect-MgGraph."
        }

        $Severity = "Medium"
        $ShouldBeReason = "ownership should not be used for high-privileged apps"
        $HighPrivilegedAppsByEntraRoles = $UnifiedIdentityInfo | where-object {$_.AssignedEntraRoles.Classification -eq "ControlPlane" -or $_.AssignedEntraRoles.Classification -eq "ManagementPlane" -or $_.AssignedEntraRoles.RoleIsPrivileged -eq $True }
        $SensitiveDirectoryRolesOnAppsWithOwners = $HighPrivilegedAppsByEntraRoles | Where-Object { $null -ne $_.OwnedBy -and $_.Type -eq "Workload" }

        if ($return) {
            $testResultMarkdown = "Well done. No application and workload identity has a privileged directory role with an owner."
        } else {
            $testResultMarkdown = "At least one application has ownership with a risk of sensitive directory role.`n`n%TestResult%"

            $result = "| ApplicationName | Ownership | Tier Breach | Sensitive Directory Role | API Provider |`n"
            $result += "| --- | --- | --- | --- | --- |`n"
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
                        $ShouldBeReason = "ownership should not be used for high-privileged apps and also not delegated to lower privileged users"
                    }
                    $filteredApiPermissions.RoleDefinitionName = "$($filteredApiPermissions.RoleDefinitionName)"
                    # Use <br/> for GitHub Flavored Markdown in-table line breaks
                    $RoleDefinitionName = $filteredApiPermissions.RoleDefinitionName -join "<br/>"
                    $RoleScope = $filteredApiPermissions.RoleScope -join "<br/>"

                    $ServicePrincipalLink = "[$($SensitiveApp.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($SensitiveApp.AccountObjectId)/appId/$($SensitiveApp.AppId))"
                    $result += "| $($AdminTierLevelIcon) $($ServicePrincipalLink) | $($Owner) | $($TierBreach) | $($RoleDefinitionName) | $($RoleScope) |`n"
                }
            }
            $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        }

        Add-MtTestResultDetail -Result $testResultMarkdown -Description "Description Field" -Severity $Severity
        $SensitiveDirectoryRolesOnAppsWithOwners.Count -eq "0" | Should -Be $True -Because $ShouldBeReason
    }

    It "MT.1073: Privileged API permissions on workload identities should not be unused. See https://maester.dev/docs/tests/MT.1073" -Tag "MT.1073" {

        if ( $UnifiedIdentityInfoExecutable -eq $false) {
                Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test requires availability of MDA App Governance and MDI to get data for Defender XDR Advanced Hunting tables.'
                return $null
        }

        try {
            $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
        } catch {
            Write-Verbose "Authentication needed. Please call Connect-MgGraph."
        }

        $Severity = "Medium"
        $ShouldBeReason = "unused sensitive API permissions should not be present"
        $HighPrivilegedAppsByApiPermissions = $UnifiedIdentityInfo | where-object {$_.ApiPermissions.Classification -eq "ControlPlane" -or $_.ApiPermissions.Classification -eq "ManagementPlane" -or $_.ApiPermissions.PrivilegeLevel -eq "High" }
        $SensitiveAppsWithUnusedPermissions = $HighPrivilegedAppsByApiPermissions | Where-Object { $_.ApiPermissions.InUse -eq $false }

        if ($return) {
            $testResultMarkdown = "Well done. No application and workload identity has a privileged API permission which are unused"
        } else {
            $testResultMarkdown = "At least one application has unused sensitive API permissions.`n`n%TestResult%"

            $result = "| ApplicationName | Enterprise Access Level | Sensitive App Role | API Provider |`n"
            $result += "| --- | --- | --- | --- | `n"
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
            $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        }
        Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity -Description "High privileged app registration will be identified by using data from OAuthAppInfo and the high privilege level by MDA App Governance but also Control Plane and Management Plane classification by the community project EntraOps. Unused API permissions will be identified by Exposure Management."
        $SensitiveAppsWithUnusedPermissions.Count -eq "0" | Should -Be $True -Because $ShouldBeReason
    }

    It "MT.1074: Credentials, token or cookies from high-privileged users should not be exposed on vulnerable endpoints. See https://maester.dev/docs/tests/MT.1074" -Tag "MT.1074" {

        if ( $UnifiedIdentityInfoExecutable -eq $false) {
                Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'This test requires availability of MDA App Governance and MDI to get data for Defender XDR Advanced Hunting tables.'
                return $null
        }

        try {
            $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo
            $ExposedTokenArtifacts = Get-MtXspmExposedTokenArtifacts
        } catch {
            Write-Verbose "Authentication needed. Please call Connect-MgGraph."
        }

        $Severity = "Medium"
        $ShouldBeReason = "no exposed authentication artifacts should be present on vulnerable endpoints"

        if ($return) {
            $testResultMarkdown = "Well done. No authentication artifacts seems to be exposed on vulnerable endpoints."
        } else {
            $testResultMarkdown = "At least one authentication artifact seems to be exposed on a vulnerable endpoint.`n`n%TestResult%"

            $result = "| AccountName | Device | Classification | Criticality Level | Artifacts | ExposureScore | RiskScore |`n"
            $result += "| --- | --- | --- | --- | --- | --- | --- |`n"
            $ExposedTokenArtifacts = $ExposedTokenArtifacts | Where-Object {$_.RiskScore -eq "High" -or $_.ExposureScore -eq "High"}
            foreach ($ExposedTokenArtifact in $ExposedTokenArtifacts) {
                $EnrichedUserDetails = $UnifiedIdentityInfo | Where-Object { $_.AccountObjectId -eq $ExposedTokenArtifact.AccountObjectId } | Select-Object Classification, AccountObjectId, CriticalityLevel, AccountDisplayName, TenantId
                if ($EnrichedUserDetails.Classification -eq "ControlPlane" -or $EnrichedUserDetails.Classification -eq "ManagementPlane" -or $EnrichedUserDetails.CriticalityLevel -lt "1") {
                    $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $EnrichedUserDetails.Classification

                    if($EnrichedUserDetails.Classification -eq "ControlPlane") {
                        $Severity = "High"
                        $ShouldBeReason = "no exposed authentication artifacts should be present on vulnerable endpoints, especially Control Plane users."
                    }

                    $UserLink = "[$($EnrichedUserDetails.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($EnrichedUserDetails.AccountObjectId))"
                    $DeviceLink = "[$($ExposedTokenArtifact.Device)](https://security.microsoft.com/machines/v2/$($ExposedTokenArtifact.DeviceId)?tid=$($EnrichedUserDetails.TenantId))"
                    $UserArtifacts = $ExposedTokenArtifact.TokenArtifacts | ForEach-Object { (Get-MtXspmAuthenticationArtifactIcon -ArtifactType $_) + " " + $_ } | Where-Object { $_ -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }

                    # Use <br/> for GitHub Flavored Markdown in-table line breaks
                    $UserArtifacts = $UserArtifacts -join "<br/>"

                    $result += "| $($AdminTierLevelIcon) $($UserLink)  | $($DeviceLink) | $($EnrichedUserDetails.Classification) | $($EnrichedUserDetails.CriticalityLevel) | $($UserArtifacts) | $($ExposedTokenArtifact.ExposureScore) | $($ExposedTokenArtifact.RiskScore) |`n"
                }
            }
            $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        }
        Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity -Description "High privileged users will be identified by using data from IdentityInfo and OAuthAppInfo. Exposed authentication artifacts will be identified by Exposure Management."

        $ExposedTokenArtifacts.Count -eq "0" | Should -Be $True -Because $ShouldBeReason
    }

    It "MT.1075: Hybrid users should not be assigned to Entra ID role assignments. See https://maester.dev/docs/tests/MT.1075" -Tag "MT.1075" {

        $UnifiedIdentityInfo = Get-MtXspmUnifiedIdentityInfo

        $HighPrivilegedUsersByEntraRoles = $UnifiedIdentityInfo | Where-Object { $_.Type -eq "User" -and ($_.AssignedEntraRoles.Classification -eq "ControlPlane" -or $_.AssignedEntraRoles.Classification -eq "ManagementPlane" -or $_.AssignedEntraRoles.RoleIsPrivileged -eq $True) | Sort-Object Classification, AccountDisplayName}
        $HighPrivilegedHybridUsers = $HighPrivilegedUsersByEntraRoles | Where-Object { $_.SourceProviders -eq "AzureActiveDirectory"}

        $Severity = "Medium"
        $ShouldBeReason = "no hybrid users with sensitive directory roles should be present"

        if ($return) {
            $testResultMarkdown = "Well done. No hybrid users with sensitive directory roles."
        } else {
            $testResultMarkdown = "At least one hybrid user with a risk of sensitive directory role membership.`n`n%TestResult%"

            $result = "| AccountName | Classification | Sensitive Directory Role | ChangeSource |`n"
            $result += "| --- | --- | --- | --- |`n"
            foreach ($HighPrivilegedHybridUser in $HighPrivilegedHybridUsers) {
                $filteredDirectoryRoles = $HighPrivilegedHybridUser.AssignedEntraRoles | Where-Object { $_.Classification -eq "ControlPlane" -or $_.Classification -eq "ManagementPlane" -or $_.RoleIsPrivileged -eq $True} | Select-Object RoleDefinitionName, Classification
                $UserSensitiveDirectoryRoles = $filteredDirectoryRoles | foreach-object { (Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $_.Classification) + " " + $_.RoleDefinitionName }
                $UserSensitiveDirectoryRolesResult = @()
                $UserSensitiveDirectoryRoles | ForEach-Object {
                    $UserSensitiveDirectoryRolesResult += "$_, "
                }
                $AdminTierLevelIcon = Get-MtXspmPrivilegedClassificationIcon -AdminTierLevelName $HighPrivilegedHybridUser.Classification
                if ($HighPrivilegedHybridUser.Classification -eq "ControlPlane") {
                    $Severity = "High"
                    $ShouldBeReason = "no hybrid users with sensitive directory roles should be present, especially Control Plane users."
                }

                # Use <br/> for GitHub Flavored Markdown in-table line breaks
                $UserSensitiveDirectoryRolesResult = $UserSensitiveDirectoryRolesResult -join "<br/>"

                $HybridUserLink = "[$($HighPrivilegedHybridUser.AccountDisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($HighPrivilegedHybridUser.AccountObjectId))"
                $result += "| $($AdminTierLevelIcon) $($HybridUserLink) | $($HighPrivilegedHybridUser.Classification) | $($UserSensitiveDirectoryRolesResult) | $($HighPrivilegedHybridUser.SourceProvider) |`n"
            }
            $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        }
        Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity -Description "High privileged users will be identified by using data from IdentityInfo. Sensitive directory roles will be identified by using classification from community project EntraOps."

        $HighPrivilegedHybridUsers.Count -eq "0" | Should -Be $True -Because $ShouldBeReason
    }
}