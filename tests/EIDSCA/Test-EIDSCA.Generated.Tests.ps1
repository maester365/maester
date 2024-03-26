Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA.AP01: Default Authorization Settings - Enabled Self service password reset. See https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowedToUseSSPR" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowedToUseSSPR | Should -Be 'true' -Because "policies/authorizationPolicy/allowedToUseSSPR should be 'true'"
    }
    It "EIDSCA.AP04: Default Authorization Settings - Guest invite restrictions. See https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowInvitesFrom" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowInvitesFrom | Should -Be 'adminsAndGuestInviters' -Because "policies/authorizationPolicy/allowInvitesFrom should be 'adminsAndGuestInviters'"
    }
    It "EIDSCA.AP05: Default Authorization Settings - Sign-up for email based subscription. See https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowedToSignUpEmailBasedSubscriptions" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowedToSignUpEmailBasedSubscriptions | Should -Be 'false' -Because "policies/authorizationPolicy/allowedToSignUpEmailBasedSubscriptions should be 'false'"
    }
    It "EIDSCA.AP06: Default Authorization Settings - User can joint the tenant by email validation. See https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowEmailVerifiedUsersToJoinOrganization" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowEmailVerifiedUsersToJoinOrganization | Should -Be 'false' -Because "policies/authorizationPolicy/allowEmailVerifiedUsersToJoinOrganization should be 'false'"
    }
    It "EIDSCA.AP07: Default Authorization Settings - Guest user access. See https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.guestUserRoleId" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.guestUserRoleId | Should -Be '2af84b1e-32c8-42b7-82bc-daa82404023b' -Because "policies/authorizationPolicy/guestUserRoleId should be '2af84b1e-32c8-42b7-82bc-daa82404023b'"
    }
    It "EIDSCA.AP08: Default Authorization Settings - User consent policy assigned for applications. See https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.permissionGrantPolicyIdsAssignedToDefaultUserRole" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.permissionGrantPolicyIdsAssignedToDefaultUserRole[2] | Should -Be 'ManagePermissionGrantsForSelf.microsoft-user-default-low' -Because "policies/authorizationPolicy/permissionGrantPolicyIdsAssignedToDefaultUserRole[2] should be 'ManagePermissionGrantsForSelf.microsoft-user-default-low'"
    }
    It "EIDSCA.AP09: Default Authorization Settings - Risk-based step-up consent. See https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowUserConsentForRiskyApps" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowUserConsentForRiskyApps | Should -Be 'false' -Because "policies/authorizationPolicy/allowUserConsentForRiskyApps should be 'false'"
    }
    It "EIDSCA.AP10: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps. See https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowedToCreateApps" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.defaultUserRolePermissions.allowedToCreateApps | Should -Be 'false' -Because "policies/authorizationPolicy/defaultUserRolePermissions.allowedToCreateApps should be 'false'"
    }
    It "EIDSCA.AP14: Default Authorization Settings - Default User Role Permissions - Allowed to read other users. See https://maester.dev/docs/tests/EIDSCA.authorizationPolicy.allowedToReadOtherUsers" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.defaultUserRolePermissions.allowedToReadOtherUsers | Should -Be 'true' -Because "policies/authorizationPolicy/defaultUserRolePermissions.allowedToReadOtherUsers should be 'true'"
    }

}
Describe "Default Settings - Consent Policy Settings" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA.CP01: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data. See https://maester.dev/docs/tests/EIDSCA.settings.EnableGroupSpecificConsent" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value | Should -Be 'False' -Because "settings/values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value should be 'False'"
    }
    It "EIDSCA.CP03: Default Settings - Consent Policy Settings - Block user consent for risky apps. See https://maester.dev/docs/tests/EIDSCA.settings.BlockUserConsentForRiskyApps" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value | Should -Be 'true' -Because "settings/values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value should be 'true'"
    }
    It "EIDSCA.CP04: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to???. See https://maester.dev/docs/tests/EIDSCA.settings.EnableAdminConsentRequests" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value | Should -Be 'true' -Because "settings/values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value should be 'true'"
    }

}
Describe "Default Settings - Password Rule Settings" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA.PR01: Default Settings - Password Rule Settings - Password Protection - Mode. See https://maester.dev/docs/tests/EIDSCA.settings.BannedPasswordCheckOnPremisesMode" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value | Should -Be 'Enforce' -Because "settings/values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value should be 'Enforce'"
    }
    It "EIDSCA.PR02: Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory. See https://maester.dev/docs/tests/EIDSCA.settings.EnableBannedPasswordCheckOnPremises" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value | Should -Be 'True' -Because "settings/values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value should be 'True'"
    }
    It "EIDSCA.PR03: Default Settings - Password Rule Settings - Enforce custom list. See https://maester.dev/docs/tests/EIDSCA.settings.EnableBannedPasswordCheck" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value | Should -Be 'True' -Because "settings/values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value should be 'True'"
    }
    It "EIDSCA.PR05: Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds. See https://maester.dev/docs/tests/EIDSCA.settings.LockoutDurationInSeconds" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value | Should -Be '60' -Because "settings/values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value should be '60'"
    }
    It "EIDSCA.PR06: Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold. See https://maester.dev/docs/tests/EIDSCA.settings.LockoutThreshold" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values | where-object name -eq 'LockoutThreshold' | select-object -expand value | Should -Be '10' -Because "settings/values | where-object name -eq 'LockoutThreshold' | select-object -expand value should be '10'"
    }

}
Describe "Default Settings - Classification and M365 Groups" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA.ST08: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner. See https://maester.dev/docs/tests/EIDSCA.settings.AllowGuestsToBeGroupOwner" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value | Should -Be 'false' -Because "settings/values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value should be 'false'"
    }
    It "EIDSCA.ST09: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content. See https://maester.dev/docs/tests/EIDSCA.settings.AllowGuestsToAccessGroups" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value | Should -Be 'True' -Because "settings/values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value should be 'True'"
    }

}
Describe "Authentication Method - General Settings" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA.AG01: Authentication Method - General Settings - Manage migration. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.policyMigrationState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.policyMigrationState | Should -Be 'migrationComplete' -Because "policies/authenticationMethodsPolicy/policyMigrationState should be 'migrationComplete'"
    }
    It "EIDSCA.AG02: Authentication Method - General Settings - Report suspicious activity - State. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.reportSuspiciousActivitySettings.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.state should be 'enabled'"
    }
    It "EIDSCA.AG03: Authentication Method - General Settings - Report suspicious activity - Included users/groups. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsIncluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.reportSuspiciousActivitySettings.includeTarget.id | Should -Be 'all_users' -Because "policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.includeTarget.id should be 'all_users'"
    }

}
Describe "Authentication Method - Microsoft Authenticator" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA.AM01: Authentication Method - Microsoft Authenticator - State. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/state should be 'enabled'"
    }
    It "EIDSCA.AM02: Authentication Method - Microsoft Authenticator - Allow use of Microsoft Authenticator OTP. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.isSoftwareOathEnabled" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/state should be 'enabled'"
    }
    It "EIDSCA.AM03: Authentication Method - Microsoft Authenticator - Require number matching for push notifications. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.numberMatchingRequiredState.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.state should be 'enabled'"
    }
    It "EIDSCA.AM04: Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredStateIncluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.numberMatchingRequiredState.includeTarget.id | Should -Be 'all_users' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.includeTarget.id should be 'all_users'"
    }
    It "EIDSCA.AM06: Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.displayAppInformationRequiredState.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.state should be 'enabled'"
    }
    It "EIDSCA.AM07: Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredStateIncluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.displayAppInformationRequiredState.includeTarget.id | Should -Be 'all_users' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.includeTarget.id should be 'all_users'"
    }
    It "EIDSCA.AM09: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.displayLocationInformationRequiredState.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.state should be 'enabled'"
    }
    It "EIDSCA.AM10: Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredStateIncluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.displayLocationInformationRequiredState.includeTarget.id | Should -Be 'all_users' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.includeTarget.id should be 'all_users'"
    }

}
Describe "Authentication Method - FIDO2 security key" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA.AF01: Authentication Method - FIDO2 security key - State. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/state should be 'enabled'"
    }
    It "EIDSCA.AF02: Authentication Method - FIDO2 security key - Allow self-service set up. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.isSelfServiceRegistrationAllowed" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.isSelfServiceRegistrationAllowed | Should -Be 'true' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/isSelfServiceRegistrationAllowed should be 'true'"
    }
    It "EIDSCA.AF03: Authentication Method - FIDO2 security key - Enforce attestation. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.isAttestationEnforced" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.isAttestationEnforced | Should -Be 'true' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/isAttestationEnforced should be 'true'"
    }
    It "EIDSCA.AF06: Authentication Method - FIDO2 security key - Restrict specific keys. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.keyRestrictions.enforcementType" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.keyRestrictions.enforcementType | Should -Be 'block' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.enforcementType should be 'block'"
    }

}
Describe "Authentication Method - Temporary Access Pass" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA.AT01: Authentication Method - Temporary Access Pass - State. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta
        $result.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/state should be 'enabled'"
    }
    It "EIDSCA.AT02: Authentication Method - Temporary Access Pass - One-time. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.isUsableOnce" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta
        $result.isUsableOnce | Should -Be 'false' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/isUsableOnce should be 'false'"
    }

}
Describe "Authentication Method - Voice call" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA.AV01: Authentication Method - Voice call - State. See https://maester.dev/docs/tests/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')" -ApiVersion beta
        $result.state | Should -Be 'disabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/state should be 'disabled'"
    }

}
Describe "Consent Framework - Admin Consent Request" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA.CR01: Consent Framework - Admin Consent Request - Users can request admin consent to apps they are unable to consent to. See https://maester.dev/docs/tests/EIDSCA.servicePrincipalCreationPolicies.isEnabled" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta
        $result.isEnabled | Should -Be 'true' -Because "policies/adminConsentRequestPolicy/isEnabled should be 'true'"
    }
    It "EIDSCA.CR02: Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests???. See https://maester.dev/docs/tests/EIDSCA.servicePrincipalCreationPolicies.notifyReviewers" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta
        $result.notifyReviewers | Should -Be 'true' -Because "policies/adminConsentRequestPolicy/notifyReviewers should be 'true'"
    }
    It "EIDSCA.CR03: Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire???. See https://maester.dev/docs/tests/EIDSCA.servicePrincipalCreationPolicies.notifyReviewers" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta
        $result.notifyReviewers | Should -Be 'true' -Because "policies/adminConsentRequestPolicy/notifyReviewers should be 'true'"
    }
    It "EIDSCA.CR04: Consent Framework - Admin Consent Request - Consent request duration (days)???. See https://maester.dev/docs/tests/EIDSCA.servicePrincipalCreationPolicies.requestDurationInDays" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta
        $result.requestDurationInDays | Should -Be '30' -Because "policies/adminConsentRequestPolicy/requestDurationInDays should be '30'"
    }

}

