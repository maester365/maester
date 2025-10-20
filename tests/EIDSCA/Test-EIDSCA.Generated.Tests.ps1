BeforeDiscovery {
    try {
        $AuthorizationPolicyAvailable = (Invoke-MtGraphRequest -RelativeUri 'policies/authorizationpolicy' -ApiVersion beta)
        $SettingsApiAvailable = (Invoke-MtGraphRequest -RelativeUri 'settings' -ApiVersion beta).values.name
        $EntraIDPlan = Get-MtLicenseInformation -Product 'EntraID'
        $EnabledAuthMethods = (Get-MtAuthenticationMethodPolicyConfig -State Enabled).Id
        $EnabledAdminConsentWorkflow = (Invoke-MtGraphRequest -RelativeUri 'policies/adminConsentRequestPolicy' -ApiVersion beta).isenabled
    } catch {
        $EntraIDPlan = "NotConnected"
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AP01" {
    It "EIDSCA.AP01: Default Authorization Settings - Enabled Self service password reset for administrators. See https://maester.dev/docs/tests/EIDSCA.AP01" -TestCases @{ AuthorizationPolicyAvailable = $AuthorizationPolicyAvailable } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .allowedToUseSSPR -eq 'false'
        #>
        Test-MtEidscaControl -CheckId AP01 | Should -Be 'false'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AP04" {
    It "EIDSCA.AP04: Default Authorization Settings - Guest invite restrictions. See https://maester.dev/docs/tests/EIDSCA.AP04" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .allowInvitesFrom -in @('adminsAndGuestInviters','none')
        #>
        Test-MtEidscaControl -CheckId AP04 | Should -BeIn @('adminsAndGuestInviters','none')
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AP05" {
    It "EIDSCA.AP05: Default Authorization Settings - Sign-up for email based subscription. See https://maester.dev/docs/tests/EIDSCA.AP05" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .allowedToSignUpEmailBasedSubscriptions -eq 'false'
        #>
        Test-MtEidscaControl -CheckId AP05 | Should -Be 'false'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AP06" {
    It "EIDSCA.AP06: Default Authorization Settings - User can join the tenant by email validation. See https://maester.dev/docs/tests/EIDSCA.AP06" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .allowEmailVerifiedUsersToJoinOrganization -eq 'false'
        #>
        Test-MtEidscaControl -CheckId AP06 | Should -Be 'false'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AP07" {
    It "EIDSCA.AP07: Default Authorization Settings - Guest user access. See https://maester.dev/docs/tests/EIDSCA.AP07" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .guestUserRoleId -eq '2af84b1e-32c8-42b7-82bc-daa82404023b'
        #>
        Test-MtEidscaControl -CheckId AP07 | Should -Be '2af84b1e-32c8-42b7-82bc-daa82404023b'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AP08" {
    It "EIDSCA.AP08: Default Authorization Settings - User consent policy assigned for applications. See https://maester.dev/docs/tests/EIDSCA.AP08" -TestCases @{ AuthorizationPolicyAvailable = $AuthorizationPolicyAvailable } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .permissionGrantPolicyIdsAssignedToDefaultUserRole -clike 'ManagePermissionGrantsForSelf*' -eq 'ManagePermissionGrantsForSelf.microsoft-user-default-low'
        #>
        Test-MtEidscaControl -CheckId AP08 | Should -Be 'ManagePermissionGrantsForSelf.microsoft-user-default-low'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AP09" {
    It "EIDSCA.AP09: Default Authorization Settings - Allow user consent on risk-based apps. See https://maester.dev/docs/tests/EIDSCA.AP09" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .allowUserConsentForRiskyApps -eq 'false'
        #>
        Test-MtEidscaControl -CheckId AP09 | Should -Be 'false'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AP10" {
    It "EIDSCA.AP10: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps. See https://maester.dev/docs/tests/EIDSCA.AP10" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .defaultUserRolePermissions.allowedToCreateApps -eq 'false'
        #>
        Test-MtEidscaControl -CheckId AP10 | Should -Be 'false'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AP14" {
    It "EIDSCA.AP14: Default Authorization Settings - Default User Role Permissions - Allowed to read other users. See https://maester.dev/docs/tests/EIDSCA.AP14" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .defaultUserRolePermissions.allowedToReadOtherUsers -eq 'true'
        #>
        Test-MtEidscaControl -CheckId AP14 | Should -Be 'true'
    }
}

Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.CP01" {
    It "EIDSCA.CP01: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data. See https://maester.dev/docs/tests/EIDSCA.CP01" -TestCases @{ SettingsApiAvailable = $SettingsApiAvailable } {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value -eq 'False'
        #>
        Test-MtEidscaControl -CheckId CP01 | Should -Be 'False'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.CP03" {
    It "EIDSCA.CP03: Default Settings - Consent Policy Settings - Block user consent for risky apps. See https://maester.dev/docs/tests/EIDSCA.CP03" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value -eq 'true'
        #>
        Test-MtEidscaControl -CheckId CP03 | Should -Be 'true'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.CP04" {
    It "EIDSCA.CP04: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to. See https://maester.dev/docs/tests/EIDSCA.CP04" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value -eq 'true'
        #>
        Test-MtEidscaControl -CheckId CP04 | Should -Be 'true'
    }
}

Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.PR01" {
    It "EIDSCA.PR01: Default Settings - Password Rule Settings - Password Protection - Mode. See https://maester.dev/docs/tests/EIDSCA.PR01" -TestCases @{ EntraIDPlan = $EntraIDPlan } {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value -eq 'Enforce'
        #>
        Test-MtEidscaControl -CheckId PR01 | Should -Be 'Enforce'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.PR02" {
    It "EIDSCA.PR02: Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory. See https://maester.dev/docs/tests/EIDSCA.PR02" -TestCases @{ EntraIDPlan = $EntraIDPlan } {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value -eq 'True'
        #>
        Test-MtEidscaControl -CheckId PR02 | Should -Be 'True'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.PR03" {
    It "EIDSCA.PR03: Default Settings - Password Rule Settings - Enforce custom list. See https://maester.dev/docs/tests/EIDSCA.PR03" -TestCases @{ EntraIDPlan = $EntraIDPlan } {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value -eq 'True'
        #>
        Test-MtEidscaControl -CheckId PR03 | Should -Be 'True'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.PR05" {
    It "EIDSCA.PR05: Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds. See https://maester.dev/docs/tests/EIDSCA.PR05" -TestCases @{ EntraIDPlan = $EntraIDPlan } {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value -ge '60'
        #>
        Test-MtEidscaControl -CheckId PR05 | Should -BeGreaterOrEqual '60'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.PR06" {
    It "EIDSCA.PR06: Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold. See https://maester.dev/docs/tests/EIDSCA.PR06" -TestCases @{ EntraIDPlan = $EntraIDPlan } {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'LockoutThreshold' | select-object -expand value -le '10'
        #>
        Test-MtEidscaControl -CheckId PR06 | Should -BeLessOrEqual '10'
    }
}

Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.ST08" {
    It "EIDSCA.ST08: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner. See https://maester.dev/docs/tests/EIDSCA.ST08" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value -eq 'false'
        #>
        Test-MtEidscaControl -CheckId ST08 | Should -Be 'false'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.ST09" {
    It "EIDSCA.ST09: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content. See https://maester.dev/docs/tests/EIDSCA.ST09" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value -eq 'True'
        #>
        Test-MtEidscaControl -CheckId ST09 | Should -Be 'True'
    }
}

Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AG01" {
    It "EIDSCA.AG01: Authentication Method - General Settings - Manage migration. See https://maester.dev/docs/tests/EIDSCA.AG01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy"
            .policyMigrationState -in @('migrationComplete', '')
        #>
        Test-MtEidscaControl -CheckId AG01 | Should -BeIn @('migrationComplete', '')
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AG02" {
    It "EIDSCA.AG02: Authentication Method - General Settings - Report suspicious activity - State. See https://maester.dev/docs/tests/EIDSCA.AG02" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy"
            .reportSuspiciousActivitySettings.state -eq 'enabled'
        #>
        Test-MtEidscaControl -CheckId AG02 | Should -Be 'enabled'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AG03" {
    It "EIDSCA.AG03: Authentication Method - General Settings - Report suspicious activity - Included users/groups. See https://maester.dev/docs/tests/EIDSCA.AG03" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy"
            .reportSuspiciousActivitySettings.includeTarget.id -eq 'all_users'
        #>
        Test-MtEidscaControl -CheckId AG03 | Should -Be 'all_users'
    }
}

Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AM01" {
    It "EIDSCA.AM01: Authentication Method - Microsoft Authenticator - State. See https://maester.dev/docs/tests/EIDSCA.AM01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .state -eq 'enabled'
        #>
        Test-MtEidscaControl -CheckId AM01 | Should -Be 'enabled'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AM02" {
    It "EIDSCA.AM02: Authentication Method - Microsoft Authenticator - Allow use of Microsoft Authenticator OTP. See https://maester.dev/docs/tests/EIDSCA.AM02" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .isSoftwareOathEnabled -eq 'false'
        #>
        Test-MtEidscaControl -CheckId AM02 | Should -Be 'false'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AM03" {
    It "EIDSCA.AM03: Authentication Method - Microsoft Authenticator - Require number matching for push notifications. See https://maester.dev/docs/tests/EIDSCA.AM03" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.numberMatchingRequiredState.state -eq 'enabled'
        #>
        Test-MtEidscaControl -CheckId AM03 | Should -Be 'enabled'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AM04" {
    It "EIDSCA.AM04: Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications. See https://maester.dev/docs/tests/EIDSCA.AM04" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.numberMatchingRequiredState.includeTarget.id -eq 'all_users'
        #>
        Test-MtEidscaControl -CheckId AM04 | Should -Be 'all_users'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AM06" {
    It "EIDSCA.AM06: Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM06" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.displayAppInformationRequiredState.state -eq 'enabled'
        #>
        Test-MtEidscaControl -CheckId AM06 | Should -Be 'enabled'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AM07" {
    It "EIDSCA.AM07: Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM07" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.displayAppInformationRequiredState.includeTarget.id -eq 'all_users'
        #>
        Test-MtEidscaControl -CheckId AM07 | Should -Be 'all_users'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AM09" {
    It "EIDSCA.AM09: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM09" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.displayLocationInformationRequiredState.state -eq 'enabled'
        #>
        Test-MtEidscaControl -CheckId AM09 | Should -Be 'enabled'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AM10" {
    It "EIDSCA.AM10: Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM10" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.displayLocationInformationRequiredState.includeTarget.id -eq 'all_users'
        #>
        Test-MtEidscaControl -CheckId AM10 | Should -Be 'all_users'
    }
}

Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AF01" {
    It "EIDSCA.AF01: Authentication Method - FIDO2 security key - State. See https://maester.dev/docs/tests/EIDSCA.AF01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .state -eq 'enabled'
        #>
        Test-MtEidscaControl -CheckId AF01 | Should -Be 'enabled'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AF02" {
    It "EIDSCA.AF02: Authentication Method - FIDO2 security key - Allow self-service set up. See https://maester.dev/docs/tests/EIDSCA.AF02" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .isSelfServiceRegistrationAllowed -eq 'true'
        #>
        Test-MtEidscaControl -CheckId AF02 | Should -Be 'true'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AF03" {
    It "EIDSCA.AF03: Authentication Method - FIDO2 security key - Enforce attestation. See https://maester.dev/docs/tests/EIDSCA.AF03" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .isAttestationEnforced -eq 'true'
        #>
        Test-MtEidscaControl -CheckId AF03 | Should -Be 'true'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AF04" {
    It "EIDSCA.AF04: Authentication Method - FIDO2 security key - Enforce key restrictions. See https://maester.dev/docs/tests/EIDSCA.AF04" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .keyRestrictions.isEnforced -eq 'true'
        #>
        Test-MtEidscaControl -CheckId AF04 | Should -Be 'true'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AF05" {
    It "EIDSCA.AF05: Authentication Method - FIDO2 security key - Restricted. See https://maester.dev/docs/tests/EIDSCA.AF05" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .keyRestrictions.aaGuids -notcontains $null -eq 'true'
        #>
        Test-MtEidscaControl -CheckId AF05 | Should -Be 'true'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AF06" {
    It "EIDSCA.AF06: Authentication Method - FIDO2 security key - Restrict specific keys. See https://maester.dev/docs/tests/EIDSCA.AF06" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .keyRestrictions.aaGuids -notcontains $null -and ($result.keyRestrictions.enforcementType -eq 'allow' -or $result.keyRestrictions.enforcementType -eq 'block') -eq 'true'
        #>
        Test-MtEidscaControl -CheckId AF06 | Should -Be 'true'
    }
}

Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AT01" {
    It "EIDSCA.AT01: Authentication Method - Temporary Access Pass - State. See https://maester.dev/docs/tests/EIDSCA.AT01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')"
            .state -eq 'enabled'
        #>
        Test-MtEidscaControl -CheckId AT01 | Should -Be 'enabled'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AT02" {
    It "EIDSCA.AT02: Authentication Method - Temporary Access Pass - One-time. See https://maester.dev/docs/tests/EIDSCA.AT02" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')"
            .isUsableOnce -eq 'true'
        #>
        Test-MtEidscaControl -CheckId AT02 | Should -Be 'true'
    }
}

Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AV01" {
    It "EIDSCA.AV01: Authentication Method - Voice call - State. See https://maester.dev/docs/tests/EIDSCA.AV01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')"
            .state -eq 'disabled'
        #>
        Test-MtEidscaControl -CheckId AV01 | Should -Be 'disabled'
    }
}

Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.AS04" {
    It "EIDSCA.AS04: Authentication Method - SMS - Use for sign-in. See https://maester.dev/docs/tests/EIDSCA.AS04" -TestCases @{ EnabledAuthMethods = $EnabledAuthMethods } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')"
            .includeTargets.isUsableForSignIn -eq 'false'
        #>
        Test-MtEidscaControl -CheckId AS04 | Should -Be 'false'
    }
}

Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.CR01" {
    It "EIDSCA.CR01: Consent Framework - Admin Consent Request - Policy to enable or disable admin consent request feature. See https://maester.dev/docs/tests/EIDSCA.CR01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy"
            .isEnabled -eq 'true'
        #>
        Test-MtEidscaControl -CheckId CR01 | Should -Be 'true'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.CR02" {
    It "EIDSCA.CR02: Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests. See https://maester.dev/docs/tests/EIDSCA.CR02" -TestCases @{ EnabledAdminConsentWorkflow = $EnabledAdminConsentWorkflow } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy"
            .notifyReviewers -eq 'true'
        #>
        Test-MtEidscaControl -CheckId CR02 | Should -Be 'true'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.CR03" {
    It "EIDSCA.CR03: Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire. See https://maester.dev/docs/tests/EIDSCA.CR03" -TestCases @{ EnabledAdminConsentWorkflow = $EnabledAdminConsentWorkflow } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy"
            .remindersEnabled -eq 'true'
        #>
        Test-MtEidscaControl -CheckId CR03 | Should -Be 'true'
    }
}
Describe "EIDSCA" -Tag "EIDSCA", "Security", "EIDSCA.CR04" {
    It "EIDSCA.CR04: Consent Framework - Admin Consent Request - Consent request duration (days). See https://maester.dev/docs/tests/EIDSCA.CR04" -TestCases @{ EnabledAdminConsentWorkflow = $EnabledAdminConsentWorkflow } {
        <#
            Check if "https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy"
            .requestDurationInDays -le '30'
        #>
        Test-MtEidscaControl -CheckId CR04 | Should -BeLessOrEqual '30'
    }
}


