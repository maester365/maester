<#
.SYNOPSIS
    Returns the Guid given the role name.

#>
function Get-MtRoleInfo {
    param(
        # The name of the role to get the Guid for.
        [string] $RoleName
    )

    #TODO: Auto generate on each build. Manual process for now is to run the following command and copy the output to the switch statement.
    #Invoke-MtGraphRequest -RelativeUri "directoryRoleTemplates" | select id, displayName | Sort-Object displayName | %{ "`"$($($_.displayName) -replace ' ')`" { '$($_.id)'; break;}"}

    # Also use the below to generate the ValidateSet for this parameter in Get-MtRoleMember whenever this is updated
    #(Invoke-MtGraphRequest -RelativeUri "directoryRoleTemplates" | select id, displayName | Sort-Object displayName | %{ "'$($($_.displayName) -replace ' ')'"}) -join ", "

    switch ($RoleName) {
        "AIAdministrator" { 'd2562ede-74db-457e-a7b6-544e236ebb61'; break; }
        "ApplicationAdministrator" { '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3'; break; }
        "ApplicationDeveloper" { 'cf1c38e5-3621-4004-a7cb-879624dced7c'; break; }
        "AttackPayloadAuthor" { '9c6df0f2-1e7c-4dc3-b195-66dfbd24aa8f'; break; }
        "AttackSimulationAdministrator" { 'c430b396-e693-46cc-96f3-db01bf8bb62a'; break; }
        "AttributeAssignmentAdministrator" { '58a13ea3-c632-46ae-9ee0-9c0d43cd7f3d'; break; }
        "AttributeAssignmentReader" { 'ffd52fa5-98dc-465c-991d-fc073eb59f8f'; break; }
        "AttributeDefinitionAdministrator" { '8424c6f0-a189-499e-bbd0-26c1753c96d4'; break; }
        "AttributeDefinitionReader" { '1d336d2c-4ae8-42ef-9711-b3604ce3fc2c'; break; }
        "AttributeLogAdministrator" { '5b784334-f94b-471a-a387-e7219fc49ca2'; break; }
        "AttributeLogReader" { '9c99539d-8186-4804-835f-fd51ef9e2dcd'; break; }
        "AuthenticationAdministrator" { 'c4e39bd9-1100-46d3-8c65-fb160da0071f'; break; }
        "AuthenticationExtensibilityAdministrator" { '25a516ed-2fa0-40ea-a2d0-12923a21473a'; break; }
        "AuthenticationPolicyAdministrator" { '0526716b-113d-4c15-b2c8-68e3c22b9f80'; break; }
        "AzureADJoinedDeviceLocalAdministrator" { '9f06204d-73c1-4d4c-880a-6edb90606fd8'; break; }
        "AzureDevOpsAdministrator" { 'e3973bdf-4987-49ae-837a-ba8e231c7286'; break; }
        "AzureInformationProtectionAdministrator" { '7495fdc4-34c4-4d15-a289-98788ce399fd'; break; }
        "B2CIEFKeysetAdministrator" { 'aaf43236-0c0d-4d5f-883a-6955382ac081'; break; }
        "B2CIEFPolicyAdministrator" { '3edaf663-341e-4475-9f94-5c398ef6c070'; break; }
        "BillingAdministrator" { 'b0f54661-2d74-4c50-afa3-1ec803f12efe'; break; }
        "CloudAppSecurityAdministrator" { '892c5842-a9a6-463a-8041-72aa08ca3cf6'; break; }
        "CloudApplicationAdministrator" { '158c047a-c907-4556-b7ef-446551a6b5f7'; break; }
        "CloudDeviceAdministrator" { '7698a772-787b-4ac8-901f-60d6b08affd2'; break; }
        "ComplianceAdministrator" { '17315797-102d-40b4-93e0-432062caca18'; break; }
        "ComplianceDataAdministrator" { 'e6d1a23a-da11-4be4-9570-befc86d067a7'; break; }
        "ConditionalAccessAdministrator" { 'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9'; break; }
        "CustomerLockBoxAccessApprover" { '5c4f9dcd-47dc-4cf7-8c9a-9e4207cbfc91'; break; }
        "DesktopAnalyticsAdministrator" { '38a96431-2bdf-4b4c-8b6e-5d3d8abac1a4'; break; }
        "DeviceJoin" { '9c094953-4995-41c8-84c8-3ebb9b32c93f'; break; }
        "DeviceManagers" { '2b499bcd-da44-4968-8aec-78e1674fa64d'; break; }
        "DeviceUsers" { 'd405c6df-0af8-4e3b-95e4-4d06e542189e'; break; }
        "DirectoryReaders" { '88d8e3e3-8f55-4a1e-953a-9b9898b8876b'; break; }
        "DirectorySynchronizationAccounts" { 'd29b2b05-8046-44ba-8758-1e26182fcf32'; break; }
        "DirectoryWriters" { '9360feb5-f418-4baa-8175-e2a00bac4301'; break; }
        "DomainNameAdministrator" { '8329153b-31d0-4727-b945-745eb3bc5f31'; break; }
        "Dynamics365Administrator" { '44367163-eba1-44c3-98af-f5787879f96a'; break; }
        "Dynamics365BusinessCentralAdministrator" { '963797fb-eb3b-4cde-8ce3-5878b3f32a3f'; break; }
        "EdgeAdministrator" { '3f1acade-1e04-4fbc-9b69-f0302cd84aef'; break; }
        "ExchangeAdministrator" { '29232cdf-9323-42fd-ade2-1d097af3e4de'; break; }
        "ExchangeRecipientAdministrator" { '31392ffb-586c-42d1-9346-e59415a2cc4e'; break; }
        "ExtendedDirectoryUserAdministrator" { 'dd13091a-6207-4fc0-82ba-3641e056ab95'; break; }
        "ExternalIDUserFlowAdministrator" { '6e591065-9bad-43ed-90f3-e9424366d2f0'; break; }
        "ExternalIDUserFlowAttributeAdministrator" { '0f971eea-41eb-4569-a71e-57bb8a3eff1e'; break; }
        "ExternalIdentityProviderAdministrator" { 'be2f45a1-457d-42af-a067-6ec1fa63bc45'; break; }
        "FabricAdministrator" { 'a9ea8996-122f-4c74-9520-8edcd192826c'; break; }
        "GlobalAdministrator" { '62e90394-69f5-4237-9190-012177145e10'; break; }
        "GlobalReader" { 'f2ef992c-3afb-46b9-b7cf-a126ee74c451'; break; }
        "GlobalSecureAccessAdministrator" { 'ac434307-12b9-4fa1-a708-88bf58caabc1'; break; }
        "GroupsAdministrator" { 'fdd7a751-b60b-444a-984c-02652fe8fa1c'; break; }
        "GuestInviter" { '95e79109-95c0-4d8e-aee3-d01accf2d47b'; break; }
        "GuestUser" { '10dae51f-b6af-4016-8d66-8c2a99b929b3'; break; }
        "HelpdeskAdministrator" { '729827e3-9c14-49f7-bb1b-9608f156bbb8'; break; }
        "HybridIdentityAdministrator" { '8ac3fc64-6eca-42ea-9e69-59f4c7b60eb2'; break; }
        "IdentityGovernanceAdministrator" { '45d8d3c5-c802-45c6-b32a-1d70b5e1e86e'; break; }
        "InsightsAdministrator" { 'eb1f4a8d-243a-41f0-9fbd-c7cdf6c5ef7c'; break; }
        "InsightsAnalyst" { '25df335f-86eb-4119-b717-0ff02de207e9'; break; }
        "InsightsBusinessLeader" { '31e939ad-9672-4796-9c2e-873181342d2d'; break; }
        "IntuneAdministrator" { '3a2c62db-5318-420d-8d74-23affee5d9d5'; break; }
        "KaizalaAdministrator" { '74ef975b-6605-40af-a5d2-b9539d836353'; break; }
        "KnowledgeAdministrator" { 'b5a8dcf3-09d5-43a9-a639-8e29ef291470'; break; }
        "KnowledgeManager" { '744ec460-397e-42ad-a462-8b3f9747a02c'; break; }
        "LicenseAdministrator" { '4d6ac14f-3453-41d0-bef9-a3e0c569773a'; break; }
        "LifecycleWorkflowsAdministrator" { '59d46f88-662b-457b-bceb-5c3809e5908f'; break; }
        "MessageCenterPrivacyReader" { 'ac16e43d-7b2d-40e0-ac05-243ff356ab5b'; break; }
        "MessageCenterReader" { '790c1fb9-7f7d-4f88-86a1-ef1f95c05c1b'; break; }
        "Microsoft365MigrationAdministrator" { '8c8b803f-96e1-4129-9349-20738d9f9652'; break; }
        "MicrosoftHardwareWarrantyAdministrator" { '1501b917-7653-4ff9-a4b5-203eaf33784f'; break; }
        "MicrosoftHardwareWarrantySpecialist" { '281fe777-fb20-4fbb-b7a3-ccebce5b0d96'; break; }
        "ModernCommerceAdministrator" { 'd24aef57-1500-4070-84db-2666f29cf966'; break; }
        "NetworkAdministrator" { 'd37c8bed-0711-4417-ba38-b4abe66ce4c2'; break; }
        "OfficeAppsAdministrator" { '2b745bdf-0803-4d80-aa65-822c4493daac'; break; }
        "OnPremisesDirectorySyncAccount" { 'a92aed5d-d78a-4d16-b381-09adb37eb3b0'; break; }
        "OrganizationalBrandingAdministrator" { '92ed04bf-c94a-4b82-9729-b799a7a4c178'; break; }
        "OrganizationalMessagesApprover" { 'e48398e2-f4bb-4074-8f31-4586725e205b'; break; }
        "OrganizationalMessagesWriter" { '507f53e4-4e52-4077-abd3-d2e1558b6ea2'; break; }
        "PartnerTier1Support" { '4ba39ca4-527c-499a-b93d-d9b492c50246'; break; }
        "PartnerTier2Support" { 'e00e864a-17c5-4a4b-9c06-f5b95a8d5bd8'; break; }
        "PasswordAdministrator" { '966707d0-3269-4727-9be2-8c3a10f19b9d'; break; }
        "PermissionsManagementAdministrator" { 'af78dc32-cf4d-46f9-ba4e-4428526346b5'; break; }
        "PowerPlatformAdministrator" { '11648597-926c-4cf3-9c36-bcebb0ba8dcc'; break; }
        "PrinterAdministrator" { '644ef478-e28f-4e28-b9dc-3fdde9aa0b1f'; break; }
        "PrinterTechnician" { 'e8cef6f1-e4bd-4ea8-bc07-4b8d950f4477'; break; }
        "PrivilegedAuthenticationAdministrator" { '7be44c8a-adaf-4e2a-84d6-ab2649e08a13'; break; }
        "PrivilegedRoleAdministrator" { 'e8611ab8-c189-46e8-94e1-60213ab1f814'; break; }
        "ReportsReader" { '4a5d8f65-41da-4de4-8968-e035b65339cf'; break; }
        "RestrictedGuestUser" { '2af84b1e-32c8-42b7-82bc-daa82404023b'; break; }
        "SearchAdministrator" { '0964bb5e-9bdb-4d7b-ac29-58e794862a40'; break; }
        "SearchEditor" { '8835291a-918c-4fd7-a9ce-faa49f0cf7d9'; break; }
        "SecurityAdministrator" { '194ae4cb-b126-40b2-bd5b-6091b380977d'; break; }
        "SecurityOperator" { '5f2222b1-57c3-48ba-8ad5-d4759f1fde6f'; break; }
        "SecurityReader" { '5d6b6bb7-de71-4623-b4af-96380a352509'; break; }
        "ServiceSupportAdministrator" { 'f023fd81-a637-4b56-95fd-791ac0226033'; break; }
        "SharePointAdministrator" { 'f28a1f50-f6e7-4571-818b-6a12f2af6b6c'; break; }
        "SharePointEmbeddedAdministrator" { '1a7d78b6-429f-476b-b8eb-35fb715fffd4'; break; }
        "SkypeforBusinessAdministrator" { '75941009-915a-4869-abe7-691bff18279e'; break; }
        "TeamsAdministrator" { '69091246-20e8-4a56-aa4d-066075b2a7a8'; break; }
        "TeamsCommunicationsAdministrator" { 'baf37b3a-610e-45da-9e62-d9d1e5e8914b'; break; }
        "TeamsCommunicationsSupportEngineer" { 'f70938a0-fc10-4177-9e90-2178f8765737'; break; }
        "TeamsCommunicationsSupportSpecialist" { 'fcf91098-03e3-41a9-b5ba-6f0ec8188a12'; break; }
        "TeamsDevicesAdministrator" { '3d762c5a-1b6c-493f-843e-55a3b42923d4'; break; }
        "TeamsTelephonyAdministrator" { 'aa38014f-0993-46e9-9b45-30501a20909d'; break; }
        "TenantCreator" { '112ca1a2-15ad-4102-995e-45b0bc479a6a'; break; }
        "UsageSummaryReportsReader" { '75934031-6c7e-415a-99d7-48dbd49e875e'; break; }
        "User" { 'a0b1b346-4d3e-4e8b-98f8-753987be4970'; break; }
        "UserAdministrator" { 'fe930be7-5e62-47db-91af-98c3a49a38b1'; break; }
        "UserExperienceSuccessManager" { '27460883-1df1-4691-b032-3b79643e5e63'; break; }
        "VirtualVisitsAdministrator" { 'e300d9e7-4a2b-4295-9eff-f1c78b36cc98'; break; }
        "VivaGoalsAdministrator" { '92b086b3-e367-4ef2-b869-1de128fb986e'; break; }
        "VivaPulseAdministrator" { '87761b17-1ed2-4af3-9acd-92a150038160'; break; }
        "Windows365Administrator" { '11451d60-acb2-45eb-a7d6-43d0f0125c13'; break; }
        "WindowsUpdateDeploymentAdministrator" { '32696413-001a-46ae-978c-ce0f6b3620d2'; break; }
        "WorkplaceDeviceJoin" { 'c34f683f-4d5a-4403-affd-6615e00e3a7f'; break; }
        "YammerAdministrator" { '810a2642-a034-447f-a5e8-41beaa378541'; break; }
        default { $null; break }
    }
}