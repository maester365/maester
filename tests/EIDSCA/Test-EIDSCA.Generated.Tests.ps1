Describe "Default Authorization Settings" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Default Authorization Settings - Enabled Self service password reset. See https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToUseSSPR" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowedToUseSSPR | Should -Be 'true' -Because "policies/authorizationPolicy/allowedToUseSSPR should be 'true' but was $($result.allowedToUseSSPR)"
    }
    It "EIDSCA: Default Authorization Settings - Blocked MSOnline PowerShell access. See https://maester.dev/test/EIDSCA.authorizationPolicy.blockMsolPowerShell" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.blockMsolPowerShell | Should -Be '' -Because "policies/authorizationPolicy/blockMsolPowerShell should be '' but was $($result.blockMsolPowerShell)"
    }
    It "EIDSCA: Default Authorization Settings - Enabled . See https://maester.dev/test/EIDSCA.authorizationPolicy.enabledPreviewFeatures" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.enabledPreviewFeatures | Should -Be '' -Because "policies/authorizationPolicy/enabledPreviewFeatures should be '' but was $($result.enabledPreviewFeatures)"
    }
    It "EIDSCA: Default Authorization Settings - Guest invite restrictions. See https://maester.dev/test/EIDSCA.authorizationPolicy.allowInvitesFrom" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowInvitesFrom | Should -Be 'adminsAndGuestInviters' -Because "policies/authorizationPolicy/allowInvitesFrom should be 'adminsAndGuestInviters' but was $($result.allowInvitesFrom)"
    }
    It "EIDSCA: Default Authorization Settings - Sign-up for email based subscription. See https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToSignUpEmailBasedSubscriptions" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowedToSignUpEmailBasedSubscriptions | Should -Be 'false' -Because "policies/authorizationPolicy/allowedToSignUpEmailBasedSubscriptions should be 'false' but was $($result.allowedToSignUpEmailBasedSubscriptions)"
    }
    It "EIDSCA: Default Authorization Settings - User can joint the tenant by email validation. See https://maester.dev/test/EIDSCA.authorizationPolicy.allowEmailVerifiedUsersToJoinOrganization" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowEmailVerifiedUsersToJoinOrganization | Should -Be 'false' -Because "policies/authorizationPolicy/allowEmailVerifiedUsersToJoinOrganization should be 'false' but was $($result.allowEmailVerifiedUsersToJoinOrganization)"
    }
    It "EIDSCA: Default Authorization Settings - Guest user access. See https://maester.dev/test/EIDSCA.authorizationPolicy.guestUserRoleId" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.guestUserRoleId | Should -Be '2af84b1e-32c8-42b7-82bc-daa82404023b' -Because "policies/authorizationPolicy/guestUserRoleId should be '2af84b1e-32c8-42b7-82bc-daa82404023b' but was $($result.guestUserRoleId)"
    }
    It "EIDSCA: Default Authorization Settings - User consent policy assigned for applications. See https://maester.dev/test/EIDSCA.authorizationPolicy.permissionGrantPolicyIdsAssignedToDefaultUserRole" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.permissionGrantPolicyIdsAssignedToDefaultUserRole | Should -Be 'ManagePermissionGrantsForSelf.microsoft-user-default-low' -Because "policies/authorizationPolicy/permissionGrantPolicyIdsAssignedToDefaultUserRole should be 'ManagePermissionGrantsForSelf.microsoft-user-default-low' but was $($result.permissionGrantPolicyIdsAssignedToDefaultUserRole)"
    }
    It "EIDSCA: Default Authorization Settings - Risk-based step-up consent. See https://maester.dev/test/EIDSCA.authorizationPolicy.allowUserConsentForRiskyApps" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowUserConsentForRiskyApps | Should -Be 'false' -Because "policies/authorizationPolicy/allowUserConsentForRiskyApps should be 'false' but was $($result.allowUserConsentForRiskyApps)"
    }
    It "EIDSCA: Default Authorization Settings - Default User Role Permissions - Allowed to create Apps. See https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToCreateApps" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.defaultUserRolePermissions.allowedToCreateApps | Should -Be 'false' -Because "policies/authorizationPolicy/defaultUserRolePermissions.allowedToCreateApps should be 'false' but was $($result.defaultUserRolePermissions.allowedToCreateApps)"
    }
    It "EIDSCA: Default Authorization Settings - Default User Role Permissions - Allowed to create Security Groups. See https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToCreateSecurityGroups" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowedToCreateSecurityGroups | Should -Be '' -Because "policies/authorizationPolicy/allowedToCreateSecurityGroups should be '' but was $($result.allowedToCreateSecurityGroups)"
    }
    It "EIDSCA: Default Authorization Settings - Default User Role Permissions - Allowed to create Tenants. See https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToCreateTenants" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowedToCreateTenants | Should -Be '' -Because "policies/authorizationPolicy/allowedToCreateTenants should be '' but was $($result.allowedToCreateTenants)"
    }
    It "EIDSCA: Default Authorization Settings - Default User Role Permissions - Allowed to read BitLocker Keys for Owned Devices. See https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToReadBitlockerKeysForOwnedDevice" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowedToReadBitlockerKeysForOwnedDevice | Should -Be '' -Because "policies/authorizationPolicy/allowedToReadBitlockerKeysForOwnedDevice should be '' but was $($result.allowedToReadBitlockerKeysForOwnedDevice)"
    }
    It "EIDSCA: Default Authorization Settings - Default User Role Permissions - Allowed to read other users. See https://maester.dev/test/EIDSCA.authorizationPolicy.allowedToReadOtherUsers" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta
        $result.allowedToReadOtherUsers | Should -Be 'true' -Because "policies/authorizationPolicy/allowedToReadOtherUsers should be 'true' but was $($result.allowedToReadOtherUsers)"
    }

}
Describe "Default Settings - Consent Policy Settings" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data. See https://maester.dev/test/EIDSCA.settings.EnableGroupSpecificConsent" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values.EnableGroupSpecificConsent | Should -Be 'False' -Because "settings/values.EnableGroupSpecificConsent should be 'False' but was $($result.values.EnableGroupSpecificConsent)"
    }
    It "EIDSCA: Default Settings - Consent Policy Settings - Group owner consent for apps accessing data - Restricted to selected group owners. See https://maester.dev/test/EIDSCA.settings.ConstrainGroupSpecificConsentToMembersOfGroupId" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values.ConstrainGroupSpecificConsentToMembersOfGroupId | Should -Be '' -Because "settings/values.ConstrainGroupSpecificConsentToMembersOfGroupId should be '' but was $($result.values.ConstrainGroupSpecificConsentToMembersOfGroupId)"
    }
    It "EIDSCA: Default Settings - Consent Policy Settings - Block user consent for risky apps. See https://maester.dev/test/EIDSCA.settings.BlockUserConsentForRiskyApps" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values.BlockUserConsentForRiskyApps | Should -Be 'true' -Because "settings/values.BlockUserConsentForRiskyApps should be 'true' but was $($result.values.BlockUserConsentForRiskyApps)"
    }
    It "EIDSCA: Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to???. See https://maester.dev/test/EIDSCA.settings.EnableAdminConsentRequests" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.values.EnableAdminConsentRequests | Should -Be 'true' -Because "settings/values.EnableAdminConsentRequests should be 'true' but was $($result.values.EnableAdminConsentRequests)"
    }

}
Describe "Default Settings - Password Rule Settings" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Default Settings - Password Rule Settings - Password Protection - Mode. See https://maester.dev/test/EIDSCA.settings.BannedPasswordCheckOnPremisesMode" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.BannedPasswordCheckOnPremisesMode | Should -Be 'Enforce' -Because "settings/BannedPasswordCheckOnPremisesMode should be 'Enforce' but was $($result.BannedPasswordCheckOnPremisesMode)"
    }
    It "EIDSCA: Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory. See https://maester.dev/test/EIDSCA.settings.EnableBannedPasswordCheckOnPremises" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.EnableBannedPasswordCheckOnPremises | Should -Be 'True' -Because "settings/EnableBannedPasswordCheckOnPremises should be 'True' but was $($result.EnableBannedPasswordCheckOnPremises)"
    }
    It "EIDSCA: Default Settings - Password Rule Settings - Enforce custom list. See https://maester.dev/test/EIDSCA.settings.EnableBannedPasswordCheck" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.EnableBannedPasswordCheck | Should -Be 'True' -Because "settings/EnableBannedPasswordCheck should be 'True' but was $($result.EnableBannedPasswordCheck)"
    }
    It "EIDSCA: Default Settings - Password Rule Settings - Password Protection - Custom banned password list. See https://maester.dev/test/EIDSCA.settings.BannedPasswordList" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.BannedPasswordList | Should -Be '' -Because "settings/BannedPasswordList should be '' but was $($result.BannedPasswordList)"
    }
    It "EIDSCA: Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds. See https://maester.dev/test/EIDSCA.settings.LockoutDurationInSeconds" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.LockoutDurationInSeconds | Should -Be '60' -Because "settings/LockoutDurationInSeconds should be '60' but was $($result.LockoutDurationInSeconds)"
    }
    It "EIDSCA: Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold. See https://maester.dev/test/EIDSCA.settings.LockoutThreshold" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.LockoutThreshold | Should -Be '10' -Because "settings/LockoutThreshold should be '10' but was $($result.LockoutThreshold)"
    }

}
Describe "Default Settings - Classification and M365 Groups" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Default Settings - Classification and M365 Groups - Default writeback setting for newly created Microsoft 365 groups. See https://maester.dev/test/EIDSCA.settings.NewUnifiedGroupWritebackDefault" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.NewUnifiedGroupWritebackDefault | Should -Be '' -Because "settings/NewUnifiedGroupWritebackDefault should be '' but was $($result.NewUnifiedGroupWritebackDefault)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - Microsoft Information Protection (MIP) Sensitivity labels to Microsoft 365 groups. See https://maester.dev/test/EIDSCA.settings.EnableMIPLabels" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.EnableMIPLabels | Should -Be '' -Because "settings/EnableMIPLabels should be '' but was $($result.EnableMIPLabels)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups naming convention - Custom blocked words list. See https://maester.dev/test/EIDSCA.settings.CustomBlockedWordsList" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.CustomBlockedWordsList | Should -Be '' -Because "settings/CustomBlockedWordsList should be '' but was $($result.CustomBlockedWordsList)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups naming convention - Microsoft Standard List of blocked words (deprecated). See https://maester.dev/test/EIDSCA.settings.EnableMSStandardBlockedWords" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.EnableMSStandardBlockedWords | Should -Be '' -Because "settings/EnableMSStandardBlockedWords should be '' but was $($result.EnableMSStandardBlockedWords)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups naming convention - Classification descriptions. See https://maester.dev/test/EIDSCA.settings.ClassificationDescriptions" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.ClassificationDescriptions | Should -Be '' -Because "settings/ClassificationDescriptions should be '' but was $($result.ClassificationDescriptions)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups naming convention - Default classification. See https://maester.dev/test/EIDSCA.settings.DefaultClassification" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.DefaultClassification | Should -Be '' -Because "settings/DefaultClassification should be '' but was $($result.DefaultClassification)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups naming convention - prefix/suffix naming requirement. See https://maester.dev/test/EIDSCA.settings.PrefixSuffixNamingRequirement" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.PrefixSuffixNamingRequirement | Should -Be '' -Because "settings/PrefixSuffixNamingRequirement should be '' but was $($result.PrefixSuffixNamingRequirement)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner. See https://maester.dev/test/EIDSCA.settings.AllowGuestsToBeGroupOwner" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.AllowGuestsToBeGroupOwner | Should -Be 'false' -Because "settings/AllowGuestsToBeGroupOwner should be 'false' but was $($result.AllowGuestsToBeGroupOwner)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content. See https://maester.dev/test/EIDSCA.settings.AllowGuestsToAccessGroups" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.AllowGuestsToAccessGroups | Should -Be 'True' -Because "settings/AllowGuestsToAccessGroups should be 'True' but was $($result.AllowGuestsToAccessGroups)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Guest usage guidelines URL. See https://maester.dev/test/EIDSCA.settings.GuestUsageGuidelinesUrl" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.GuestUsageGuidelinesUrl | Should -Be '' -Because "settings/GuestUsageGuidelinesUrl should be '' but was $($result.GuestUsageGuidelinesUrl)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Enable Group creation for any members. See https://maester.dev/test/EIDSCA.settings.EnableGroupCreation" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.EnableGroupCreation | Should -Be '' -Because "settings/EnableGroupCreation should be '' but was $($result.EnableGroupCreation)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Allow group created for a specific security group. See https://maester.dev/test/EIDSCA.settings.GroupCreationAllowedGroupId" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.GroupCreationAllowedGroupId | Should -Be '' -Because "settings/GroupCreationAllowedGroupId should be '' but was $($result.GroupCreationAllowedGroupId)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Allow to add Guests. See https://maester.dev/test/EIDSCA.settings.AllowToAddGuests" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.AllowToAddGuests | Should -Be '' -Because "settings/AllowToAddGuests should be '' but was $($result.AllowToAddGuests)"
    }
    It "EIDSCA: Default Settings - Classification and M365 Groups - M365 groups - Classification list. See https://maester.dev/test/EIDSCA.settings.ClassificationList" {
        $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta
        $result.ClassificationList | Should -Be '' -Because "settings/ClassificationList should be '' but was $($result.ClassificationList)"
    }

}
Describe "Default Activity Timeout" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Default Activity Timeout - Enable directory level idle timeout. See https://maester.dev/test/EIDSCA.activityBasedTimeoutPolicies.WebSessionIdleTimeout" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/activityBasedTimeoutPolicies" -ApiVersion beta
        $result.definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout | Should -Be '' -Because "policies/activityBasedTimeoutPolicies/definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout should be '' but was $($result.definition.ActivityBasedTimeoutPolicy.ApplicationPolicies.WebSessionIdleTimeout)"
    }

}
Describe "External Identities" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: External Identities - External user leave settings. See https://maester.dev/test/EIDSCA.externalIdentitiesPolicy.allowExternalIdentitiesToLeave" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/externalIdentitiesPolicy" -ApiVersion beta
        $result.allowExternalIdentitiesToLeave | Should -Be '' -Because "policies/externalIdentitiesPolicy/allowExternalIdentitiesToLeave should be '' but was $($result.allowExternalIdentitiesToLeave)"
    }
    It "EIDSCA: External Identities - Deleted Identities Data Removal. See https://maester.dev/test/EIDSCA.externalIdentitiesPolicy.allowDeletedIdentitiesDataRemoval" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/externalIdentitiesPolicy" -ApiVersion beta
        $result.allowDeletedIdentitiesDataRemoval | Should -Be '' -Because "policies/externalIdentitiesPolicy/allowDeletedIdentitiesDataRemoval should be '' but was $($result.allowDeletedIdentitiesDataRemoval)"
    }

}
Describe "Feature Rollout (Enabled Previews)" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Feature Rollout (Enabled Previews) - . See https://maester.dev/test/EIDSCA.featureRolloutPolicies.featureRolloutPolicy" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/featureRolloutPolicies" -ApiVersion beta
        $result.value | Should -Be '' -Because "policies/featureRolloutPolicies/value should be '' but was $($result.value)"
    }

}
Describe "Authentication Method - General Settings" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Authentication Method - General Settings - Manage migration. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.policyMigrationState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.policyMigrationState | Should -Be 'migrationComplete' -Because "policies/authenticationMethodsPolicy/policyMigrationState should be 'migrationComplete' but was $($result.policyMigrationState)"
    }
    It "EIDSCA: Authentication Method - General Settings - Report suspicious activity - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.reportSuspiciousActivitySettings.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.state should be 'enabled' but was $($result.reportSuspiciousActivitySettings.state)"
    }
    It "EIDSCA: Authentication Method - General Settings - Report suspicious activity - Included users/groups. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsIncluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.reportSuspiciousActivitySettings.includeTargets.id | Should -Be 'all_users' -Because "policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.includeTargets.id should be 'all_users' but was $($result.reportSuspiciousActivitySettings.includeTargets.id)"
    }
    It "EIDSCA: Authentication Method - General Settings - Report suspicious activity - Reporting code. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.reportSuspiciousActivitySettingsReporting code" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.reportSuspiciousActivitySettings.voiceReportingCode | Should -Be '' -Because "policies/authenticationMethodsPolicy/reportSuspiciousActivitySettings.voiceReportingCode should be '' but was $($result.reportSuspiciousActivitySettings.voiceReportingCode)"
    }
    It "EIDSCA: Authentication Method - General Settings - System Credential Preferences - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.systemCredentialPreferencesState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.systemCredentialPreferences.state | Should -Be '' -Because "policies/authenticationMethodsPolicy/systemCredentialPreferences.state should be '' but was $($result.systemCredentialPreferences.state)"
    }
    It "EIDSCA: Authentication Method - General Settings - System Credential Preferences - Included users/groups. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.systemCredentialPreferencesStateIncluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.systemCredentialPreferences.includeTargets.id | Should -Be '' -Because "policies/authenticationMethodsPolicy/systemCredentialPreferences.includeTargets.id should be '' but was $($result.systemCredentialPreferences.includeTargets.id)"
    }
    It "EIDSCA: Authentication Method - General Settings - System Credential Preferences - Excluded users/groups. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.systemCredentialPreferencesStateExcluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.systemCredentialPreferences.excludeTargets.id | Should -Be '' -Because "policies/authenticationMethodsPolicy/systemCredentialPreferences.excludeTargets.id should be '' but was $($result.systemCredentialPreferences.excludeTargets.id)"
    }
    It "EIDSCA: Authentication Method - General Settings - Registration campaign - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.state | Should -Be '' -Because "policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.state should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.state)"
    }
    It "EIDSCA: Authentication Method - General Settings - Registration campaign - Included users/groups. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignIncluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id | Should -Be '' -Because "policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.id)"
    }
    It "EIDSCA: Authentication Method - General Settings - Registration campaign - Authentication Method. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignTargetedAuthenticationMethod" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod | Should -Be '' -Because "policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.includeTargets.targetedAuthenticationMethod)"
    }
    It "EIDSCA: Authentication Method - General Settings - Registration campaign - Excluded users/groups. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignExcluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.excludeTargets.id | Should -Be '' -Because "policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.excludeTargets.id should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.excludeTargets.id)"
    }
    It "EIDSCA: Authentication Method - General Settings - Registration campaign - Days allowed to snooze. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationMethodsRegistrationCampaignSnoozeDurationInDays" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta
        $result.registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays | Should -Be '' -Because "policies/authenticationMethodsPolicy/registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays should be '' but was $($result.registrationEnforcement.authenticationMethodsRegistrationCampaign.snoozeDurationInDays)"
    }

}
Describe "Authentication Method - Microsoft Authenticator" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Authentication Method - Microsoft Authenticator - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/state should be 'enabled' but was $($result.state)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Allow use of Microsoft Authenticator OTP. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.isSoftwareOathEnabled" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/state should be 'enabled' but was $($result.state)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Require number matching for push notifications. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.numberMatchingRequiredState.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.state should be 'enabled' but was $($result.featureSettings.numberMatchingRequiredState.state)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredStateIncluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.numberMatchingRequiredState.includeTarget.id | Should -Be 'all_users' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.includeTarget.id should be 'all_users' but was $($result.featureSettings.numberMatchingRequiredState.includeTarget.id)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Excluded users/groups of number matching for push notifications. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.numberMatchingRequiredStateExcluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.numberMatchingRequiredState.excludeTarget.id | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.numberMatchingRequiredState.excludeTarget.id should be '' but was $($result.featureSettings.numberMatchingRequiredState.excludeTarget.id)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.displayAppInformationRequiredState.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.state should be 'enabled' but was $($result.featureSettings.displayAppInformationRequiredState.state)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredStateIncluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.displayAppInformationRequiredState.includeTarget.id | Should -Be 'all_users' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.includeTarget.id should be 'all_users' but was $($result.featureSettings.displayAppInformationRequiredState.includeTarget.id)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Excluded users/groups to show application name in push and passwordless notifications. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayAppInformationRequiredStateExcluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.displayAppInformationRequiredState.excludeTarget.id | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayAppInformationRequiredState.excludeTarget.id should be '' but was $($result.featureSettings.displayAppInformationRequiredState.excludeTarget.id)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredState" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.displayLocationInformationRequiredState.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.state should be 'enabled' but was $($result.featureSettings.displayLocationInformationRequiredState.state)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredStateIncluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.displayLocationInformationRequiredState.includeTarget.id | Should -Be 'all_users' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.includeTarget.id should be 'all_users' but was $($result.featureSettings.displayLocationInformationRequiredState.includeTarget.id)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Excluded users/groups to show geographic location in push and passwordless notifications. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.displayLocationInformationRequiredExcluded" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.featureSettings.displayLocationInformationRequiredState.excludeTarget.id | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/featureSettings.displayLocationInformationRequiredState.excludeTarget.id should be '' but was $($result.featureSettings.displayLocationInformationRequiredState.excludeTarget.id)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Included users/groups from using Authenticator App. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.includeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/includeTargets should be '' but was $($result.includeTargets)"
    }
    It "EIDSCA: Authentication Method - Microsoft Authenticator - Excluded users/groups from using Authenticator App. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta
        $result.excludeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')/excludeTargets should be '' but was $($result.excludeTargets)"
    }

}
Describe "Authentication Method - FIDO2 security key" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Authentication Method - FIDO2 security key - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/state should be 'enabled' but was $($result.state)"
    }
    It "EIDSCA: Authentication Method - FIDO2 security key - Allow self-service set up. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.isSelfServiceRegistrationAllowed" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.isSelfServiceRegistrationAllowed | Should -Be 'true' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/isSelfServiceRegistrationAllowed should be 'true' but was $($result.isSelfServiceRegistrationAllowed)"
    }
    It "EIDSCA: Authentication Method - FIDO2 security key - Enforce attestation. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.isAttestationEnforced" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.isAttestationEnforced | Should -Be 'true' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/isAttestationEnforced should be 'true' but was $($result.isAttestationEnforced)"
    }
    It "EIDSCA: Authentication Method - FIDO2 security key - Enforce key restrictions. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.keyRestrictions.isEnforced" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.keyRestrictions.isEnforced | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.isEnforced should be '' but was $($result.keyRestrictions.isEnforced)"
    }
    It "EIDSCA: Authentication Method - FIDO2 security key - Restricted. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.keyRestrictions.aaGuids" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.keyRestrictions.aaGuids | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.aaGuids should be '' but was $($result.keyRestrictions.aaGuids)"
    }
    It "EIDSCA: Authentication Method - FIDO2 security key - Restrict specific keys. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.keyRestrictions.enforcementType" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.keyRestrictions.enforcementType | Should -Be 'block' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/keyRestrictions.enforcementType should be 'block' but was $($result.keyRestrictions.enforcementType)"
    }
    It "EIDSCA: Authentication Method - FIDO2 security key - Included users/groups from using security keys. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.includeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/includeTargets should be '' but was $($result.includeTargets)"
    }
    It "EIDSCA: Authentication Method - FIDO2 security key - Excluded users/groups from using security keys. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta
        $result.excludeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/excludeTargets should be '' but was $($result.excludeTargets)"
    }

}
Describe "Authentication Method - Temporary Access Pass" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Authentication Method - Temporary Access Pass - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta
        $result.state | Should -Be 'enabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/state should be 'enabled' but was $($result.state)"
    }
    It "EIDSCA: Authentication Method - Temporary Access Pass - One-time. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.isUsableOnce" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta
        $result.isUsableOnce | Should -Be 'false' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/isUsableOnce should be 'false' but was $($result.isUsableOnce)"
    }
    It "EIDSCA: Authentication Method - Temporary Access Pass - Default lifetime. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.defaultLifetimeInMinutes" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta
        $result.defaultLifetimeInMinutes | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/defaultLifetimeInMinutes should be '' but was $($result.defaultLifetimeInMinutes)"
    }
    It "EIDSCA: Authentication Method - Temporary Access Pass - Length. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.defaultLength" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta
        $result.defaultLength | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/defaultLength should be '' but was $($result.defaultLength)"
    }
    It "EIDSCA: Authentication Method - Temporary Access Pass - Minimum lifetime. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.minimumLifetimeInMinutes" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta
        $result.minimumLifetimeInMinutes | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/minimumLifetimeInMinutes should be '' but was $($result.minimumLifetimeInMinutes)"
    }
    It "EIDSCA: Authentication Method - Temporary Access Pass - Maximum lifetime. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.maximumLifetimeInMinutes" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta
        $result.maximumLifetimeInMinutes | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/maximumLifetimeInMinutes should be '' but was $($result.maximumLifetimeInMinutes)"
    }
    It "EIDSCA: Authentication Method - Temporary Access Pass - Included users/groups from Temporary Access Pass. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta
        $result.includeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/includeTargets should be '' but was $($result.includeTargets)"
    }
    It "EIDSCA: Authentication Method - Temporary Access Pass - Excluded users/group from Temporary Access Pass. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta
        $result.excludeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')/excludeTargets should be '' but was $($result.excludeTargets)"
    }

}
Describe "Authentication Method - Third-party software OATH tokens" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Authentication Method - Third-party software OATH tokens - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')" -ApiVersion beta
        $result.state | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/state should be '' but was $($result.state)"
    }
    It "EIDSCA: Authentication Method - Third-party software OATH tokens - Included users/groups from OATH token. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')" -ApiVersion beta
        $result.includeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/includeTargets should be '' but was $($result.includeTargets)"
    }
    It "EIDSCA: Authentication Method - Third-party software OATH tokens - Excluded users/group from OATH token. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')" -ApiVersion beta
        $result.excludeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('SoftwareOath')/excludeTargets should be '' but was $($result.excludeTargets)"
    }

}
Describe "Authentication Method - Email OTP" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Authentication Method - Email OTP - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')" -ApiVersion beta
        $result.state | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/state should be '' but was $($result.state)"
    }
    It "EIDSCA: Authentication Method - Email OTP - Allow external users to use email OTP. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.allowExternalIdToUseEmailOtp" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')" -ApiVersion beta
        $result.allowExternalIdToUseEmailOtp | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/allowExternalIdToUseEmailOtp should be '' but was $($result.allowExternalIdToUseEmailOtp)"
    }
    It "EIDSCA: Authentication Method - Email OTP - Included users/groups from Email OTP. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')" -ApiVersion beta
        $result.includeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/includeTargets should be '' but was $($result.includeTargets)"
    }
    It "EIDSCA: Authentication Method - Email OTP - Excluded users/group from Email OTP. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')" -ApiVersion beta
        $result.excludeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Email')/excludeTargets should be '' but was $($result.excludeTargets)"
    }

}
Describe "Authentication Method - Voice call" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Authentication Method - Voice call - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')" -ApiVersion beta
        $result.state | Should -Be 'disabled' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/state should be 'disabled' but was $($result.state)"
    }
    It "EIDSCA: Authentication Method - Voice call - Phone Options - Office. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.isOfficePhoneAllowed" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')" -ApiVersion beta
        $result.isOfficePhoneAllowed | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/isOfficePhoneAllowed should be '' but was $($result.isOfficePhoneAllowed)"
    }
    It "EIDSCA: Authentication Method - Voice call - Included users/groups from Voice call. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')" -ApiVersion beta
        $result.includeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/includeTargets should be '' but was $($result.includeTargets)"
    }
    It "EIDSCA: Authentication Method - Voice call - Excluded users/group from Voice call. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')" -ApiVersion beta
        $result.excludeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')/excludeTargets should be '' but was $($result.excludeTargets)"
    }

}
Describe "Authentication Method - SMS" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Authentication Method - SMS - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')" -ApiVersion beta
        $result.state | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/state should be '' but was $($result.state)"
    }
    It "EIDSCA: Authentication Method - SMS - Included users/groups from Voice call. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')" -ApiVersion beta
        $result.includeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/includeTargets should be '' but was $($result.includeTargets)"
    }
    It "EIDSCA: Authentication Method - SMS - Excluded users/group from Voice call. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')" -ApiVersion beta
        $result.excludeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Sms')/excludeTargets should be '' but was $($result.excludeTargets)"
    }

}
Describe "Authentication Method - Certificate-based authentication" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Authentication Method - Certificate-based authentication - State. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.state" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')" -ApiVersion beta
        $result.state | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/state should be '' but was $($result.state)"
    }
    It "EIDSCA: Authentication Method - Certificate-based authentication - Included users/groups from CBA. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.includeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')" -ApiVersion beta
        $result.includeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/includeTargets should be '' but was $($result.includeTargets)"
    }
    It "EIDSCA: Authentication Method - Certificate-based authentication - Excluded users/group from CBA. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.excludeTargets" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')" -ApiVersion beta
        $result.excludeTargets | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/excludeTargets should be '' but was $($result.excludeTargets)"
    }
    It "EIDSCA: Authentication Method - Certificate-based authentication - Authentication binding - Protected Level. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')" -ApiVersion beta
        $result.authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode should be '' but was $($result.authenticationModeConfiguration.x509CertificateAuthenticationDefaultMode)"
    }
    It "EIDSCA: Authentication Method - Certificate-based authentication - Authentication binding - Rules. See https://maester.dev/test/EIDSCA.authenticationMethodsPolicy.authenticationModeConfiguration.rules" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')" -ApiVersion beta
        $result.authenticationModeConfiguration.rules | Should -Be '' -Because "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('X509Certificate')/authenticationModeConfiguration.rules should be '' but was $($result.authenticationModeConfiguration.rules)"
    }

}
Describe "Consent Framework - Admin Consent Request (Coming soon)" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Users can request admin consent to apps they are unable to consent to. See https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.isEnabled" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta
        $result.isEnabled | Should -Be 'true' -Because "policies/adminConsentRequestPolicy/isEnabled should be 'true' but was $($result.isEnabled)"
    }
    It "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Reviewers will receive email notifications for requests???. See https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.notifyReviewers" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta
        $result.notifyReviewers | Should -Be 'true' -Because "policies/adminConsentRequestPolicy/notifyReviewers should be 'true' but was $($result.notifyReviewers)"
    }
    It "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Reviewers will receive email notifications when admin consent requests are about to expire???. See https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.notifyReviewers" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta
        $result.notifyReviewers | Should -Be 'true' -Because "policies/adminConsentRequestPolicy/notifyReviewers should be 'true' but was $($result.notifyReviewers)"
    }
    It "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Consent request expires after (days)???. See https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.requestDurationInDays" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta
        $result.requestDurationInDays | Should -Be '30' -Because "policies/adminConsentRequestPolicy/requestDurationInDays should be '30' but was $($result.requestDurationInDays)"
    }
    It "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Consent request expires after (days)???. See https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.reviewers" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta
        $result.reviewers | Should -Be '30' -Because "policies/adminConsentRequestPolicy/reviewers should be '30' but was $($result.reviewers)"
    }
    It "EIDSCA: Consent Framework - Admin Consent Request (Coming soon) - Consent request expires after (days)???. See https://maester.dev/test/EIDSCA.servicePrincipalCreationPolicies.version" {
        $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta
        $result.version | Should -Be '' -Because "policies/adminConsentRequestPolicy/version should be '' but was $($result.version)"
    }

}
Describe "Azure AD Recommendations" -Tag "EIDSCA", "Security", "All" {
    It "EIDSCA: Azure AD Recommendations - Protect all users with a user risk policy. See https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.UserRiskPolicy" {
        $result = Invoke-MtGraphRequest -RelativeUri "directory/recommendations" -ApiVersion beta
        $result.status | Should -Be 'completedBySystem' -Because "directory/recommendations/status should be 'completedBySystem' but was $($result.status)"
    }
    It "EIDSCA: Azure AD Recommendations - Protect all users with a sign-in risk policy. See https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.SigninRiskPolicy" {
        $result = Invoke-MtGraphRequest -RelativeUri "directory/recommendations" -ApiVersion beta
        $result.status | Should -Be 'completedBySystem' -Because "directory/recommendations/status should be 'completedBySystem' but was $($result.status)"
    }
    It "EIDSCA: Azure AD Recommendations - Require multifactor authentication for administrative roles. See https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.AdminMFAV2" {
        $result = Invoke-MtGraphRequest -RelativeUri "directory/recommendations" -ApiVersion beta
        $result.status | Should -Be 'completedBySystem' -Because "directory/recommendations/status should be 'completedBySystem' but was $($result.status)"
    }
    It "EIDSCA: Azure AD Recommendations - Use limited administrative roles. See https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.RoleOverlap" {
        $result = Invoke-MtGraphRequest -RelativeUri "directory/recommendations" -ApiVersion beta
        $result.status | Should -Be 'completedBySystem' -Because "directory/recommendations/status should be 'completedBySystem' but was $($result.status)"
    }
    It "EIDSCA: Azure AD Recommendations - Remove unused applications. See https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.StaleApps" {
        $result = Invoke-MtGraphRequest -RelativeUri "directory/recommendations" -ApiVersion beta
        $result.status | Should -Be 'completedBySystem' -Because "directory/recommendations/status should be 'completedBySystem' but was $($result.status)"
    }
    It "EIDSCA: Azure AD Recommendations - Renew expiring application credentials. See https://maester.dev/test/EIDSCA.recommendations.Microsoft.Identity.IAM.Insights.ApplicationCredentialExpiry" {
        $result = Invoke-MtGraphRequest -RelativeUri "directory/recommendations" -ApiVersion beta
        $result.status | Should -Be 'completedBySystem' -Because "directory/recommendations/status should be 'completedBySystem' but was $($result.status)"
    }

}

