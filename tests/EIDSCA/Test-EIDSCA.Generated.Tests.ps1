BeforeDiscovery {
$EnabledAuthMethods = (Get-MtAuthenticationMethodPolicyConfig -State Enabled).Id
$EnabledAdminConsentWorkflow = (Invoke-MtGraphRequest -RelativeUri 'policies/adminConsentRequestPolicy' -ApiVersion beta).isenabled
}
Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AP01" {
    It "EIDSCA.AP01: Default Authorization Settings - Enabled Self service password reset for administrators. See https://maester.dev/docs/tests/EIDSCA.AP01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .allowedToUseSSPR = 'false'
        #>
        Test-MtEidscaAP01 | Should -Be 'false'
    }
}
Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AP04" {
    It "EIDSCA.AP04: Default Authorization Settings - Guest invite restrictions. See https://maester.dev/docs/tests/EIDSCA.AP04" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .allowInvitesFrom = 'adminsAndGuestInviters'
        #>
        Test-MtEidscaAP04 | Should -Be 'adminsAndGuestInviters'
    }
}
Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AP05" {
    It "EIDSCA.AP05: Default Authorization Settings - Sign-up for email based subscription. See https://maester.dev/docs/tests/EIDSCA.AP05" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .allowedToSignUpEmailBasedSubscriptions = 'false'
        #>
        Test-MtEidscaAP05 | Should -Be 'false'
    }
}
Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AP06" {
    It "EIDSCA.AP06: Default Authorization Settings - User can join the tenant by email validation. See https://maester.dev/docs/tests/EIDSCA.AP06" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .allowEmailVerifiedUsersToJoinOrganization = 'false'
        #>
        Test-MtEidscaAP06 | Should -Be 'false'
    }
}
Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AP07" {
    It "EIDSCA.AP07: Default Authorization Settings - Guest user access. See https://maester.dev/docs/tests/EIDSCA.AP07" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .guestUserRoleId = '2af84b1e-32c8-42b7-82bc-daa82404023b'
        #>
        Test-MtEidscaAP07 | Should -Be '2af84b1e-32c8-42b7-82bc-daa82404023b'
    }
}
Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AP08" {
    It "EIDSCA.AP08: Default Authorization Settings - User consent policy assigned for applications. See https://maester.dev/docs/tests/EIDSCA.AP08" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .permissionGrantPolicyIdsAssignedToDefaultUserRole | Sort-Object -Descending | select-object -first 1 = 'ManagePermissionGrantsForSelf.microsoft-user-default-low'
        #>
        Test-MtEidscaAP08 | Should -Be 'ManagePermissionGrantsForSelf.microsoft-user-default-low'
    }
}
Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AP09" {
    It "EIDSCA.AP09: Default Authorization Settings - Risk-based step-up consent. See https://maester.dev/docs/tests/EIDSCA.AP09" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .allowUserConsentForRiskyApps = 'false'
        #>
        Test-MtEidscaAP09 | Should -Be 'false'
    }
}
Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AP10" {
    It "EIDSCA.AP10: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps. See https://maester.dev/docs/tests/EIDSCA.AP10" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .defaultUserRolePermissions.allowedToCreateApps = 'false'
        #>
        Test-MtEidscaAP10 | Should -Be 'false'
    }
}
Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AP14" {
    It "EIDSCA.AP14: Default Authorization Settings - Default User Role Permissions - Allowed to read other users. See https://maester.dev/docs/tests/EIDSCA.AP14" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authorizationPolicy"
            .defaultUserRolePermissions.allowedToReadOtherUsers = 'true'
        #>
        Test-MtEidscaAP14 | Should -Be 'true'
    }
}

Describe "Default Settings - Consent Policy Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.CP01" {
    It "EIDSCA.CP01: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data. See https://maester.dev/docs/tests/EIDSCA.CP01" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value = 'False'
        #>
        Test-MtEidscaCP01 | Should -Be 'False'
    }
}
Describe "Default Settings - Consent Policy Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.CP03" {
    It "EIDSCA.CP03: Default Settings - Consent Policy Settings - Block user consent for risky apps. See https://maester.dev/docs/tests/EIDSCA.CP03" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value = 'true'
        #>
        Test-MtEidscaCP03 | Should -Be 'true'
    }
}
Describe "Default Settings - Consent Policy Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.CP04" {
    It "EIDSCA.CP04: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to. See https://maester.dev/docs/tests/EIDSCA.CP04" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value = 'true'
        #>
        Test-MtEidscaCP04 | Should -Be 'true'
    }
}

Describe "Default Settings - Password Rule Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.PR01" {
    It "EIDSCA.PR01: Default Settings - Password Rule Settings - Password Protection - Mode. See https://maester.dev/docs/tests/EIDSCA.PR01" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value = 'Enforce'
        #>
        Test-MtEidscaPR01 | Should -Be 'Enforce'
    }
}
Describe "Default Settings - Password Rule Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.PR02" {
    It "EIDSCA.PR02: Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory. See https://maester.dev/docs/tests/EIDSCA.PR02" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value = 'True'
        #>
        Test-MtEidscaPR02 | Should -Be 'True'
    }
}
Describe "Default Settings - Password Rule Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.PR03" {
    It "EIDSCA.PR03: Default Settings - Password Rule Settings - Enforce custom list. See https://maester.dev/docs/tests/EIDSCA.PR03" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value = 'True'
        #>
        Test-MtEidscaPR03 | Should -Be 'True'
    }
}
Describe "Default Settings - Password Rule Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.PR05" {
    It "EIDSCA.PR05: Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds. See https://maester.dev/docs/tests/EIDSCA.PR05" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value >= '60'
        #>
        Test-MtEidscaPR05 | Should -BeGreaterOrEqual '60'
    }
}
Describe "Default Settings - Password Rule Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.PR06" {
    It "EIDSCA.PR06: Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold. See https://maester.dev/docs/tests/EIDSCA.PR06" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'LockoutThreshold' | select-object -expand value = '10'
        #>
        Test-MtEidscaPR06 | Should -Be '10'
    }
}

Describe "Default Settings - Classification and M365 Groups" -Tag "EIDSCA", "Security", "All", "EIDSCA.ST08" {
    It "EIDSCA.ST08: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner. See https://maester.dev/docs/tests/EIDSCA.ST08" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value = 'false'
        #>
        Test-MtEidscaST08 | Should -Be 'false'
    }
}
Describe "Default Settings - Classification and M365 Groups" -Tag "EIDSCA", "Security", "All", "EIDSCA.ST09" {
    It "EIDSCA.ST09: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content. See https://maester.dev/docs/tests/EIDSCA.ST09" {
        <#
            Check if "https://graph.microsoft.com/beta/settings"
            .values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value = 'True'
        #>
        Test-MtEidscaST09 | Should -Be 'True'
    }
}

Describe "Authentication Method - General Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AG01" {
    It "EIDSCA.AG01: Authentication Method - General Settings - Manage migration. See https://maester.dev/docs/tests/EIDSCA.AG01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy"
            .policyMigrationState = 'migrationComplete'
        #>
        Test-MtEidscaAG01 | Should -Be 'migrationComplete'
    }
}
Describe "Authentication Method - General Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AG02" {
    It "EIDSCA.AG02: Authentication Method - General Settings - Report suspicious activity - State. See https://maester.dev/docs/tests/EIDSCA.AG02" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy"
            .reportSuspiciousActivitySettings.state = 'enabled'
        #>
        Test-MtEidscaAG02 | Should -Be 'enabled'
    }
}
Describe "Authentication Method - General Settings" -Tag "EIDSCA", "Security", "All", "EIDSCA.AG03" {
    It "EIDSCA.AG03: Authentication Method - General Settings - Report suspicious activity - Included users/groups. See https://maester.dev/docs/tests/EIDSCA.AG03" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy"
            .reportSuspiciousActivitySettings.includeTarget.id = 'all_users'
        #>
        Test-MtEidscaAG03 | Should -Be 'all_users'
    }
}

Describe "Authentication Method - Microsoft Authenticator" -Tag "EIDSCA", "Security", "All", "EIDSCA.AM01" {
    It "EIDSCA.AM01: Authentication Method - Microsoft Authenticator - State. See https://maester.dev/docs/tests/EIDSCA.AM01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .state = 'enabled'
        #>
        Test-MtEidscaAM01 | Should -Be 'enabled'
    }
}
Describe "Authentication Method - Microsoft Authenticator" -Tag "EIDSCA", "Security", "All", "EIDSCA.AM02" -Skip:( $EnabledAuthMethods -notcontains 'MicrosoftAuthenticator' ) {
    It "EIDSCA.AM02: Authentication Method - Microsoft Authenticator - Allow use of Microsoft Authenticator OTP. See https://maester.dev/docs/tests/EIDSCA.AM02" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .state = 'enabled'
        #>
        Test-MtEidscaAM02 | Should -Be 'enabled'
    }
}
Describe "Authentication Method - Microsoft Authenticator" -Tag "EIDSCA", "Security", "All", "EIDSCA.AM03" -Skip:( $EnabledAuthMethods -notcontains 'MicrosoftAuthenticator' ) {
    It "EIDSCA.AM03: Authentication Method - Microsoft Authenticator - Require number matching for push notifications. See https://maester.dev/docs/tests/EIDSCA.AM03" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.numberMatchingRequiredState.state = 'enabled'
        #>
        Test-MtEidscaAM03 | Should -Be 'enabled'
    }
}
Describe "Authentication Method - Microsoft Authenticator" -Tag "EIDSCA", "Security", "All", "EIDSCA.AM04" -Skip:( $EnabledAuthMethods -notcontains 'MicrosoftAuthenticator' ) {
    It "EIDSCA.AM04: Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications. See https://maester.dev/docs/tests/EIDSCA.AM04" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.numberMatchingRequiredState.includeTarget.id = 'all_users'
        #>
        Test-MtEidscaAM04 | Should -Be 'all_users'
    }
}
Describe "Authentication Method - Microsoft Authenticator" -Tag "EIDSCA", "Security", "All", "EIDSCA.AM06" -Skip:( $EnabledAuthMethods -notcontains 'MicrosoftAuthenticator' ) {
    It "EIDSCA.AM06: Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM06" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.displayAppInformationRequiredState.state = 'enabled'
        #>
        Test-MtEidscaAM06 | Should -Be 'enabled'
    }
}
Describe "Authentication Method - Microsoft Authenticator" -Tag "EIDSCA", "Security", "All", "EIDSCA.AM07" -Skip:( $EnabledAuthMethods -notcontains 'MicrosoftAuthenticator' ) {
    It "EIDSCA.AM07: Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM07" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.displayAppInformationRequiredState.includeTarget.id = 'all_users'
        #>
        Test-MtEidscaAM07 | Should -Be 'all_users'
    }
}
Describe "Authentication Method - Microsoft Authenticator" -Tag "EIDSCA", "Security", "All", "EIDSCA.AM09" -Skip:( $EnabledAuthMethods -notcontains 'MicrosoftAuthenticator' ) {
    It "EIDSCA.AM09: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM09" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.displayLocationInformationRequiredState.state = 'enabled'
        #>
        Test-MtEidscaAM09 | Should -Be 'enabled'
    }
}
Describe "Authentication Method - Microsoft Authenticator" -Tag "EIDSCA", "Security", "All", "EIDSCA.AM10" -Skip:( $EnabledAuthMethods -notcontains 'MicrosoftAuthenticator' ) {
    It "EIDSCA.AM10: Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.AM10" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')"
            .featureSettings.displayLocationInformationRequiredState.includeTarget.id = 'all_users'
        #>
        Test-MtEidscaAM10 | Should -Be 'all_users'
    }
}

Describe "Authentication Method - FIDO2 security key" -Tag "EIDSCA", "Security", "All", "EIDSCA.AF01" {
    It "EIDSCA.AF01: Authentication Method - FIDO2 security key - State. See https://maester.dev/docs/tests/EIDSCA.AF01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .state = 'enabled'
        #>
        Test-MtEidscaAF01 | Should -Be 'enabled'
    }
}
Describe "Authentication Method - FIDO2 security key" -Tag "EIDSCA", "Security", "All", "EIDSCA.AF02" -Skip:( $EnabledAuthMethods -notcontains 'Fido2' ) {
    It "EIDSCA.AF02: Authentication Method - FIDO2 security key - Allow self-service set up. See https://maester.dev/docs/tests/EIDSCA.AF02" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .isSelfServiceRegistrationAllowed = 'true'
        #>
        Test-MtEidscaAF02 | Should -Be 'true'
    }
}
Describe "Authentication Method - FIDO2 security key" -Tag "EIDSCA", "Security", "All", "EIDSCA.AF03" -Skip:( $EnabledAuthMethods -notcontains 'Fido2' ) {
    It "EIDSCA.AF03: Authentication Method - FIDO2 security key - Enforce attestation. See https://maester.dev/docs/tests/EIDSCA.AF03" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .isAttestationEnforced = 'true'
        #>
        Test-MtEidscaAF03 | Should -Be 'true'
    }
}
Describe "Authentication Method - FIDO2 security key" -Tag "EIDSCA", "Security", "All", "EIDSCA.AF04" -Skip:( $EnabledAuthMethods -notcontains 'Fido2' ) {
    It "EIDSCA.AF04: Authentication Method - FIDO2 security key - Enforce key restrictions. See https://maester.dev/docs/tests/EIDSCA.AF04" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .keyRestrictions.isEnforced = 'true'
        #>
        Test-MtEidscaAF04 | Should -Be 'true'
    }
}
Describe "Authentication Method - FIDO2 security key" -Tag "EIDSCA", "Security", "All", "EIDSCA.AF05" -Skip:( $EnabledAuthMethods -notcontains 'Fido2' -or (Test-MtEidscaAF04) -eq $false ) {
    It "EIDSCA.AF05: Authentication Method - FIDO2 security key - Restricted. See https://maester.dev/docs/tests/EIDSCA.AF05" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .keyRestrictions.aaGuids -notcontains $null = 'true'
        #>
        Test-MtEidscaAF05 | Should -Be 'true'
    }
}
Describe "Authentication Method - FIDO2 security key" -Tag "EIDSCA", "Security", "All", "EIDSCA.AF06" -Skip:( $EnabledAuthMethods -notcontains 'Fido2' -or (Test-MtEidscaAF04) -eq $false ) {
    It "EIDSCA.AF06: Authentication Method - FIDO2 security key - Restrict specific keys. See https://maester.dev/docs/tests/EIDSCA.AF06" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')"
            .keyRestrictions.aaGuids -notcontains $null -and ($result.keyRestrictions.enforcementType -eq 'allow' -or $result.keyRestrictions.enforcementType -eq 'block') = 'true'
        #>
        Test-MtEidscaAF06 | Should -Be 'true'
    }
}

Describe "Authentication Method - Temporary Access Pass" -Tag "EIDSCA", "Security", "All", "EIDSCA.AT01" {
    It "EIDSCA.AT01: Authentication Method - Temporary Access Pass - State. See https://maester.dev/docs/tests/EIDSCA.AT01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')"
            .state = 'enabled'
        #>
        Test-MtEidscaAT01 | Should -Be 'enabled'
    }
}
Describe "Authentication Method - Temporary Access Pass" -Tag "EIDSCA", "Security", "All", "EIDSCA.AT02" -Skip:( $EnabledAuthMethods -notcontains 'TemporaryAccessPass' ) {
    It "EIDSCA.AT02: Authentication Method - Temporary Access Pass - One-time. See https://maester.dev/docs/tests/EIDSCA.AT02" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')"
            .isUsableOnce = 'true'
        #>
        Test-MtEidscaAT02 | Should -Be 'true'
    }
}

Describe "Authentication Method - Voice call" -Tag "EIDSCA", "Security", "All", "EIDSCA.AV01" {
    It "EIDSCA.AV01: Authentication Method - Voice call - State. See https://maester.dev/docs/tests/EIDSCA.AV01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')"
            .state = 'disabled'
        #>
        Test-MtEidscaAV01 | Should -Be 'disabled'
    }
}

Describe "Consent Framework - Admin Consent Request" -Tag "EIDSCA", "Security", "All", "EIDSCA.CR01" {
    It "EIDSCA.CR01: Consent Framework - Admin Consent Request - Policy to enable or disable admin consent request feature. See https://maester.dev/docs/tests/EIDSCA.CR01" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy"
            .isEnabled = 'true'
        #>
        Test-MtEidscaCR01 | Should -Be 'true'
    }
}
Describe "Consent Framework - Admin Consent Request" -Tag "EIDSCA", "Security", "All", "EIDSCA.CR02" -Skip:( ($EnabledAdminConsentWorkflow) -eq $false ) {
    It "EIDSCA.CR02: Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests. See https://maester.dev/docs/tests/EIDSCA.CR02" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy"
            .notifyReviewers = 'true'
        #>
        Test-MtEidscaCR02 | Should -Be 'true'
    }
}
Describe "Consent Framework - Admin Consent Request" -Tag "EIDSCA", "Security", "All", "EIDSCA.CR03" -Skip:( ($EnabledAdminConsentWorkflow) -eq $false ) {
    It "EIDSCA.CR03: Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire. See https://maester.dev/docs/tests/EIDSCA.CR03" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy"
            .notifyReviewers = 'true'
        #>
        Test-MtEidscaCR03 | Should -Be 'true'
    }
}
Describe "Consent Framework - Admin Consent Request" -Tag "EIDSCA", "Security", "All", "EIDSCA.CR04" -Skip:( ($EnabledAdminConsentWorkflow) -eq $false ) {
    It "EIDSCA.CR04: Consent Framework - Admin Consent Request - Consent request duration (days). See https://maester.dev/docs/tests/EIDSCA.CR04" {
        <#
            Check if "https://graph.microsoft.com/beta/policies/adminConsentRequestPolicy"
            .requestDurationInDays = '30'
        #>
        Test-MtEidscaCR04 | Should -Be '30'
    }
}


