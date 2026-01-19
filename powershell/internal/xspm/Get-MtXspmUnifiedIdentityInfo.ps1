<#
.SYNOPSIS
    Check data from various XDR tables to identify users and workload identities with sensitive privileges and apply classification from community project EntraOps.

.DESCRIPTION
    Executes KQL function over Advanced Hunting API to retrieves unified identity information from XDR, including user and workload identities with sensitive privileges.
    It applies classification from the EntraOps community project to identify critical assets and their roles.

.EXAMPLE
    Get-MtXspmUnifiedIdentityInfo

    Returns a detailed list of user and workload identities with sensitive privileges, including their roles, classifications, and criticality levels.

.LINK
    https://maester.dev/docs/commands/Get-MtXspmUnifiedIdentityInfo
#>

function Get-MtXspmUnifiedIdentityInfo {
    param (
        [Parameter()]
        [switch]$ValidateRequiredTablesOnly = $false
    )

    if (!$ValidateRequiredTablesOnly) {
        $Query = "
        // Define the UnifiedIdentityInfo function
        let Int_PrivilegedIdentityInfo = (UserPrincipalName:string='', ObjectId:string='', EntraRoleDefinitionName:string='', EntraRolePermission:string='', LookbackTimestamp:datetime=datetime(now)) {
            let SensitiveEntraDirectoryRoles = externaldata(RoleName: string, RoleId: string, isPrivileged: bool, Categories:string, Classification: dynamic, RolePermissions: dynamic)['https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_EntraIdDirectoryRoles.json'] with(format='multijson')
            | project RoleDefinitionName = RoleName, RoleIsPrivileged = isPrivileged, Classification, RoleCategories = Categories, RolePermissions;
            let IdentityInfoUpdateInterval = -14;
            let IdentityInfoLookbackWindow = datetime_add('day', IdentityInfoUpdateInterval, LookbackTimestamp);
            let AllEntraPimRoles = IdentityInfo
                | where tolower(AccountUpn) contains tolower(UserPrincipalName) and AccountObjectId contains (ObjectId)
                | where TimeGenerated >(IdentityInfoLookbackWindow) and TimeGenerated <(LookbackTimestamp)
                | summarize arg_max(TimeGenerated, *) by AccountObjectId
                | mv-expand parse_json(PrivilegedEntraPimRoles)
                | extend RoleDefinitionName = tostring(bag_keys(PrivilegedEntraPimRoles)[0])
                | where RoleDefinitionName contains (EntraRoleDefinitionName)
                | extend PimAssignmentExpiration = tostring(PrivilegedEntraPimRoles[RoleDefinitionName][1])
                | extend PimAssignmentType = tostring(PrivilegedEntraPimRoles[RoleDefinitionName][0])
                | extend RoleAssignmentType = tostring(PrivilegedEntraPimRoles[RoleDefinitionName][2])
                | project AccountObjectId, AccountUpn, RoleDefinitionName, RoleAssignmentType, PimAssignmentType, PimAssignmentExpiration
                | sort by AccountUpn, RoleDefinitionName;
            let EntraEligibleRoles = AllEntraPimRoles
                | where PimAssignmentType == 'Eligible'
                | sort by AccountUpn, RoleDefinitionName;
            let EntraActiveRoles = IdentityInfo
                | where tolower(AccountUpn) contains tolower(UserPrincipalName) or AccountObjectId contains (ObjectId)
                | where TimeGenerated >(IdentityInfoLookbackWindow) and TimeGenerated <(LookbackTimestamp)
                | summarize arg_max(TimeGenerated, *) by AccountObjectId
                | where isnotempty(AssignedRoles)
                | mv-expand parse_json(AssignedRoles)
                | extend RoleDefinitionName = tostring(AssignedRoles)
                | where RoleDefinitionName contains (EntraRoleDefinitionName)
                | join kind = leftouter (
                    AllEntraPimRoles
                    | where PimAssignmentType == 'Assigned'
                ) on AccountObjectId, RoleDefinitionName
                | extend PimAssignmentExpiration = coalesce(PimAssignmentExpiration, 'Unknown')
                | extend PimAssignmentType = 'Active'
                | extend RoleAssignmentType = coalesce(RoleAssignmentType, 'Unknown')
                | project AccountObjectId, AccountUpn, RoleDefinitionName, RoleAssignmentType, PimAssignmentType, PimAssignmentExpiration
                | sort by AccountObjectId, RoleDefinitionName;
            let AllEntraRoles = union EntraEligibleRoles, EntraActiveRoles
                | where tolower(AccountUpn) contains tolower(UserPrincipalName) and AccountObjectId contains (ObjectId)
                | join kind=inner ( SensitiveEntraDirectoryRoles
                    | where RolePermissions contains (EntraRolePermission)
                ) on RoleDefinitionName
                | extend AadDirectoryRoleTierLevels = parse_json(Classification.EAMTierLevelName)
                | extend Classification = case(
                    AadDirectoryRoleTierLevels contains 'ControlPlane', 'ControlPlane',
                    AadDirectoryRoleTierLevels contains 'ManagementPlane', 'ManagementPlane',
                    AadDirectoryRoleTierLevels contains 'WorkloadPlane', 'WorkloadPlane',
                    AadDirectoryRoleTierLevels contains 'UserAccess', 'UserAccess',
                    'Unclassified'
                )
                | extend PimAssignmentType = iff(PimAssignmentType == 'Assigned', 'Active', PimAssignmentType)
                | project RoleAssignments = bag_pack_columns(RoleDefinitionName, RoleAssignmentType, PimAssignmentType, PimAssignmentExpiration, Classification, RoleIsPrivileged, RoleCategories, RolePermissions), AccountObjectId
                | summarize AssignedEntraRoles = make_set(RoleAssignments) by AccountObjectId;
            IdentityInfo
            | where tolower(AccountUpn) contains tolower(UserPrincipalName) and AccountObjectId contains (ObjectId)
            | where TimeGenerated >(IdentityInfoLookbackWindow) and TimeGenerated <(LookbackTimestamp)
            | summarize arg_max(TimeGenerated, *) by AccountObjectId
            | join kind=inner ( AllEntraRoles ) on AccountObjectId
            | project-away ReportId, AssignedRoles, PrivilegedEntraPimRoles, AccountObjectId1
            | sort by AccountName asc
            | extend Classification = case(
                AssignedEntraRoles has 'ControlPlane', 'ControlPlane',
                AssignedEntraRoles has 'ManagementPlane', 'ManagementPlane',
                AssignedEntraRoles has 'WorkloadPlane', 'WorkloadPlane',
                AssignedEntraRoles has 'UserAccess', 'UserAccess',
                'Unclassified'
            )
        };
        let Int_WorkloadIdentityInfoXdr = (ServicePrincipalName:string='', ServicePrincipalObjectId:guid=guid(null)) {
            let FirstPartyApps = externaldata(AppId: string, AppDisplayName: string, AppOwnerOrganizationId: string, Source:string)
                ['https://raw.githubusercontent.com/merill/microsoft-info/main/_info/MicrosoftApps.json'] with(format='multijson')
                | project OAuthAppId = AppId, AppOwnerTenantId = AppOwnerOrganizationId;
            let SensitiveEntraDirectoryRoles = externaldata(RoleName: string, RoleId: string, isPrivileged: bool, Categories:string, Classification: dynamic, RolePermissions: dynamic)
                ['https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_EntraIdDirectoryRoles.json'] with(format='multijson')
                | project RoleDefinitionName = RoleName, RoleId, RoleIsPrivileged = isPrivileged, Classification, RoleCategories = Categories, RolePermissions;
            let SensitiveMsGraphPermissions = externaldata(AppRoleDisplayName: string, AppRoleId: string, AppId: string, EAMTierLevelName: string, Category: string)
                ['https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/main/Classification/Classification_AppRoles.json'] with(format='multijson');
            let PrivilegedAzureRoles = dynamic(['Owner','Contributor','Access Review Operator Service Role','Azure File Sync Administrator','Role Based Access Control Administrator','User Access Administrator']);
            let PrivilegedArmOperations = (externaldata(RoleAction:string)
                [@'https://raw.githubusercontent.com/Cloud-Architekt/AzurePrivilegedIAM/refs/heads/main/PrivilegedOperations/ArmApiRequest.csv'] with (format='csv', ignoreFirstRecord=true)
            );
            let PrivilegedArmOperationsPattern = @'Microsoft\.Authorization/.*/action';
            let PrivilegedGroupMinCriticalLevel = 2;
            IdentityInfo
                | where Type == 'ServiceAccount' and SourceProvider == 'AzureActiveDirectory'
                | where tolower(AccountDisplayName) contains tolower(ServicePrincipalName) and AccountObjectId contains tostring(ServicePrincipalObjectId)
                | where Timestamp >ago(14d)
                | summarize arg_max(Timestamp, *) by AccountObjectId
                | extend AccountStatus = iff(IsAccountEnabled == true, 'Enabled', 'Disabled')
                | project ServicePrincipalName = AccountDisplayName, ServicePrincipalId = AccountObjectId, CriticalityLevel, AccountStatus
            // Lookup for OAuth application details
            | lookup (
                OAuthAppInfo
                    | where Timestamp >ago(30d)
                    | where tolower(AppName) contains tolower(ServicePrincipalName) and ServicePrincipalId contains tostring(ServicePrincipalObjectId)
                    | summarize arg_max(Timestamp, *) by ServicePrincipalId
            ) on ServicePrincipalId
            // Lookup for Graph API Classification
            | lookup (
                OAuthAppInfo
                    | where Timestamp >ago(30d)
                    | where tolower(AppName) contains tolower(ServicePrincipalName) and ServicePrincipalId contains tostring(ServicePrincipalObjectId)
                    | summarize arg_max(Timestamp, *) by ServicePrincipalId
                    | mv-expand parse_json(Permissions)
                    | extend AppId = tostring(parse_json(Permissions)['TargetAppId'])
                    | extend AppDisplayName = tostring(parse_json(Permissions)['TargetAppDisplayName'])
                    | extend AppRoleDisplayName = tostring(parse_json(Permissions)['PermissionValue'])
                    | extend PermissionType = tostring(parse_json(Permissions)['PermissionType'])
                    | extend InUse = tostring(parse_json(Permissions)['InUse'])
                    | extend PrivilegeLevel = tostring(parse_json(Permissions)['PrivilegeLevel'])
                    | join kind = leftouter (
                        SensitiveMsGraphPermissions
                    ) on AppId, AppRoleDisplayName
                    | project-rename Classification = EAMTierLevelName
                    | extend ApiPermission = bag_pack_columns(AppId, AppDisplayName, AppRoleId, AppRoleDisplayName, InUse, PrivilegeLevel, Category, Classification)
                    | summarize ApiPermissions = make_set(ApiPermission) by ServicePrincipalId
            ) on ServicePrincipalId
            | project-away Permissions
            // Lookup for First Party App Status
            | join kind=leftouter ( FirstPartyApps ) on OAuthAppId, AppOwnerTenantId
            // Lookup for Permanent or Active Entra ID Roles with Classification to EntraOps
            | join kind=leftouter (
                IdentityInfo
                    | where Type == 'ServiceAccount' and SourceProvider == 'AzureActiveDirectory'
                    | where Timestamp >ago(14d)
                    | summarize arg_max(Timestamp, *) by AccountObjectId
                    | where isnotempty(AssignedRoles)
                    | mv-expand parse_json(AssignedRoles)
                    | extend RoleDefinitionName = tostring(AssignedRoles)
                    | join kind=inner ( SensitiveEntraDirectoryRoles
                    ) on RoleDefinitionName
                    | extend AadDirectoryRoleTierLevels = parse_json(Classification.EAMTierLevelName)
                    | extend Classification = case(
                        AadDirectoryRoleTierLevels contains 'ControlPlane', 'ControlPlane',
                        AadDirectoryRoleTierLevels contains 'ManagementPlane', 'ManagementPlane',
                        AadDirectoryRoleTierLevels contains 'WorkloadPlane', 'WorkloadPlane',
                        AadDirectoryRoleTierLevels contains 'UserAccess', 'UserAccess',
                        'Unclassified'
                    )
                    | extend PimAssignmentType = 'Active'
                    // Details not available in IdentityInfo for Active/Permanent Assignments on SPs
                    | extend PimAssignmentExpiration = 'Unknown'
                    | extend RoleAssignmentType = 'Unknown'
                    | project RoleAssignments = bag_pack_columns(RoleDefinitionName, RoleAssignmentType, PimAssignmentType, PimAssignmentExpiration, Classification, RoleIsPrivileged, RoleCategories, RolePermissions), ServicePrincipalId = AccountObjectId
                    | summarize AssignedEntraRoles = make_set(RoleAssignments) by ServicePrincipalId
            ) on ServicePrincipalId
            // Lookup for Critical asset and Graph node details
            | join kind=leftouter (
                ExposureGraphNodes
                | where NodeLabel == @'serviceprincipal' or NodeLabel == @'managedidentity'
                // AppId on some GraphNodes not available
                | extend AppId = parse_json(NodeProperties)['rawData']['appId']
                // Fallback to ObjectId
                | mv-expand parse_json(EntityIds)
                | where parse_json(EntityIds).type == 'AadObjectId'
                | extend EntityId = tostring(parse_json(EntityIds).id)
                | extend ServicePrincipalId = tostring(extract('objectid=([\\w-]+)', 1, EntityId))
                | extend ServicePrincipalType = tostring(parse_json(NodeProperties)['rawData']['servicePrincipalType'])
                | extend XspmCriticalAssetDetails = parse_json(NodeProperties)['rawData']['criticalityLevel']
                | extend XspmGraphNodeDetails = bag_pack_columns(NodeId, NodeName, NodeLabel)
                | project ServicePrincipalId, ServicePrincipalType, XspmGraphNodeId = NodeId, XspmGraphNodeDetails, XspmCriticalAssetDetails
            ) on ServicePrincipalId
            // Lookup for Graph node details of OAuth App
            | join kind=leftouter (
                ExposureGraphNodes
                | where NodeLabel == @'Microsoft Entra OAuth App'
                | mv-expand parse_json(EntityIds)
                | where parse_json(EntityIds).type == 'AadApplicationId'
                | extend OAuthAppId = tostring(parse_json(EntityIds).id)
                | extend XspmGraphOAuthAppNodeDetails = bag_pack_columns(NodeId, NodeName, NodeLabel)
                | project XspmGraphOAuthAppNodeDetails, OAuthAppId
                ) on OAuthAppId
            // Lookup for Azure roles from Graph edges
            | join kind=leftouter (
                ExposureGraphEdges
                | where SourceNodeLabel == 'managedidentity' or SourceNodeLabel == 'serviceprincipal'
                | where EdgeLabel == @'has role on'
                | where parse_json(TargetNodeCategories) contains 'environmentAzure'
                | mv-expand parse_json(EdgeProperties)['rawData']['permissions']['roles']
                | extend RoleDefinitionName = parse_json(EdgeProperties_rawData_permissions_roles)['name']
                | extend RoleDefinitionId = parse_json(EdgeProperties_rawData_permissions_roles)['id']
                | extend RoleAssignmentId = parse_json(EdgeProperties_rawData_permissions_roles)['roleAssignmentId']
                | extend RoleActions = parse_json(EdgeProperties_rawData_permissions_roles)['actions']
                | extend RoleIsPrivileged = iff((
                    RoleActions matches regex (PrivilegedArmOperationsPattern)
                    or RoleActions has_any (PrivilegedArmOperations)) == true
                    or RoleDefinitionName in~ (PrivilegedAzureRoles)
                    or RoleActions[0] == '*',
                    'true', 'false')
                | extend IsOverProvisioned = parse_json(EdgeProperties)['rawData']['isOverProvisioned']
                | extend IsIdentityInactive = parse_json(EdgeProperties)['rawData']['isIdentityInactive']
                | project RoleAssignments = bag_pack_columns(RoleDefinitionName, RoleDefinitionId, RoleIsPrivileged, IsOverProvisioned, IsIdentityInactive), XspmGraphNodeId = SourceNodeId
                | summarize AssignedAzureRoles = make_set(RoleAssignments) by XspmGraphNodeId
            ) on XspmGraphNodeId
            // Lookup for Security Group assignments from Graph edges
            | join kind=leftouter (
                ExposureGraphEdges
                | where SourceNodeLabel == 'managedidentity' or SourceNodeLabel == 'serviceprincipal'
                | where EdgeLabel == @'member of'
                | where TargetNodeLabel == @'group'
                | join kind=inner ( ExposureGraphNodes
                    | mv-expand parse_json(EntityIds)
                    | where parse_json(EntityIds).type == 'AadObjectId'
                    | extend EntityId = tostring(parse_json(EntityIds).id)
                    | extend GroupDisplayName = NodeName
                    | extend GroupObjectId = tostring(extract('objectid=([\\w-]+)', 1, EntityId))
                    | extend XspmCriticalAssetDetails = parse_json(NodeProperties)['rawData']['criticalityLevel']
                ) on `$left.TargetNodeId == `$right.NodeId
                | extend GroupIsPrivileged = iff(
                    parse_json(XspmCriticalAssetDetails)['criticalityLevel'] <= PrivilegedGroupMinCriticalLevel or parse_json(XspmCriticalAssetDetails)['ruleBasedCriticalityLevel'] <= PrivilegedGroupMinCriticalLevel,
                    'true',
                    'false'
                    )
                | project RoleAssignments = bag_pack_columns(GroupDisplayName, GroupObjectId, GroupIsPrivileged), XspmGraphNodeId = SourceNodeId
                | summarize AssignedGroupMembership = make_set(RoleAssignments) by XspmGraphNodeId
            ) on XspmGraphNodeId
            // Lookup for Nodes with 'can authenticate as' relation from Graph edges (App Registration or Azure Resources with Managed Identities)
            | join kind=leftouter (
                ExposureGraphEdges
                | where EdgeLabel == @'can authenticate as'
                | where TargetNodeLabel == @'managedidentity' or TargetNodeLabel == @'serviceprincipal'
                | join kind=leftouter ( ExposureGraphNodes | project SourceNodeId = NodeId, EntityIds ) on SourceNodeId
                | extend NodeId = SourceNodeId, NodeName = SourceNodeName, NodeLabel = SourceNodeLabel
                | extend AuthenticatedBy = bag_pack_columns(NodeId, NodeName, NodeLabel, EntityIds)
                | summarize AuthenticatedBy = make_set(AuthenticatedBy) by TargetNodeId
            ) on `$left.XspmGraphNodeId == `$right.TargetNodeId
            // Lookup for Ownership (currently limited to Application Objects)
            | extend XspmGraphOAuthAppNodeId = tostring(XspmGraphOAuthAppNodeDetails.NodeId)
            | join kind=leftouter (
                ExposureGraphEdges
                | where EdgeLabel == @'has role on'
                // Currently limited to OAuth App edges
                | where TargetNodeLabel == 'Microsoft Entra OAuth App'
                | extend RolePermissions = parse_json(EdgeProperties)['rawData']['roles']['rolePermissions']
                | mv-expand parse_json(RolePermissions)
                | where RolePermissions.['roleValue'] startswith 'Owner'
                | join kind=leftouter (
                    ExposureGraphNodes | project SourceNodeId = NodeId, EntityIds
                ) on SourceNodeId
                | extend NodeId = SourceNodeId, NodeName = SourceNodeName, NodeLabel = SourceNodeLabel
                | extend OwnedBy = bag_pack_columns(NodeId, NodeName, NodeLabel, EntityIds)
                | project-rename XspmGraphOAuthAppNodeId = TargetNodeId
                | summarize OwnedBy = make_set(OwnedBy) by XspmGraphOAuthAppNodeId
            ) on XspmGraphOAuthAppNodeId
            | extend CriticalityLevel = toint(parse_json(XspmCriticalAssetDetails)['criticalityLevel'])
            | project-away XspmGraphNodeId, XspmGraphNodeId1, ServicePrincipalId1, ServicePrincipalId2, XspmGraphNodeId1, XspmGraphNodeId2, TargetNodeId, XspmGraphOAuthAppNodeId, XspmGraphOAuthAppNodeId1
            | sort by ServicePrincipalName asc
            | project Timestamp, TimeGenerated, ServicePrincipalName, ServicePrincipalId, OAuthAppId, CriticalityLevel, AddedOnTime, LastModifiedTime, AppStatus, VerifiedPublisher, IsAdminConsented, AppOrigin, AppOwnerTenantId, ApiPermissions, AssignedAzureRoles, AssignedEntraRoles, AuthenticatedBy, OwnedBy, AccountStatus
            | extend Classification = case(
                AssignedEntraRoles has 'ControlPlane' or ApiPermissions has 'ControlPlane', 'ControlPlane',
                AssignedEntraRoles has 'ManagementPlane' or ApiPermissions has 'ManagementPlane', 'ManagementPlane',
                AssignedEntraRoles has 'WorkloadPlane' or ApiPermissions has 'WorkloadPlane', 'WorkloadPlane',
                AssignedEntraRoles has 'UserAccess' or ApiPermissions has 'UserAccess', 'UserAccess',
                'Unclassified'
            )
            | sort by OAuthAppId
        };
        let UnifiedIdentityInfoXdr = (ObjectName:string, ObjectId:guid, LookbackTimestamp:datetime=datetime(now)) {
            let PrivilegedUsers = Int_PrivilegedIdentityInfo(UserPrincipalName=tolower(ObjectName),ObjectId=tostring(ObjectId))
            | where TimeGenerated > ago(14d)
            | where Type == 'User'
            | where tolower(AccountDisplayName) contains tolower(ObjectName) and AccountObjectId contains tostring(ObjectId)
            | extend OnPremSynchronized = iff(isnotempty(OnPremObjectId), 'true', 'false')
            | extend IsDeleted = iff(isnotempty(DeletedDateTime), 'true', 'false')
            | extend AccountStatus = iff(IsAccountEnabled == true, 'Enabled', 'Disabled')
            // Enrichment to primary work account
            | join kind=leftouter (
                IdentityAccountInfo
                | where SourceProvider == @'AzureActiveDirectory'
                | where tolower(DisplayName) contains tolower(ObjectName) and SourceProviderAccountId contains tostring(ObjectId)
                | summarize arg_max(TimeGenerated, *) by AccountId
                | where IsPrimary == false
                | project TimeGenerated, DisplayName, SourceProviderAccountId, IdentityId, IdentityLinkBy, IdentityLinkType, IsPrimary, AccountId
                | join kind = leftouter (
                    IdentityAccountInfo
                        | where SourceProvider == @'AzureActiveDirectory'
                        | summarize arg_max(TimeGenerated, *) by AccountId
                        | where IsPrimary == true
                        | project IdentityId, AccountObjectId = SourceProviderAccountId, AccountUpn, AccountStatus
                ) on IdentityId
                | extend AssociatedPrimaryAccount = bag_pack_columns(AccountObjectId, AccountUpn, AccountStatus, IdentityLinkType, IdentityId)
                | project AccountObjectId = SourceProviderAccountId, AssociatedPrimaryAccount, PrimaryAccountObjectId = AccountObjectId
            ) on AccountObjectId
            | project-away AccountObjectId1;
            let AllWorkloads = Int_WorkloadIdentityInfoXdr(ServicePrincipalName=tolower(ObjectName),ServicePrincipalObjectId=tostring(ObjectId))
            | extend Type = 'Workload'
            | project-rename AccountObjectId = ServicePrincipalId, AccountDisplayName = ServicePrincipalName;
            let IdentityInfoUpdateInterval = -14;
            let IdentityInfoLookbackWindow = datetime_add('day', IdentityInfoUpdateInterval, LookbackTimestamp);
            let AllUsers = IdentityInfo
            | where TimeGenerated >(IdentityInfoLookbackWindow) and TimeGenerated <(LookbackTimestamp)
            | summarize arg_max(TimeGenerated, *) by AccountObjectId
            | where Type == 'User'
            | where tolower(AccountDisplayName) contains tolower(ObjectName) and AccountObjectId contains tostring(ObjectId)
            | extend AccountStatus = iff(IsAccountEnabled == true, 'Enabled', 'Disabled')
            | summarize arg_max(TimeGenerated, *) by AccountObjectId
            | join kind=anti (PrivilegedUsers | where TimeGenerated > ago(14d)) on AccountObjectId
            // Enrichment to primary work account
            | join kind=leftouter (
                IdentityAccountInfo
                | where SourceProvider == @'AzureActiveDirectory'
                | where tolower(DisplayName) contains tolower(ObjectName) and SourceProviderAccountId contains tostring(ObjectId)
                | summarize arg_max(TimeGenerated, *) by AccountId
                | where IsPrimary == false
                | project TimeGenerated, DisplayName, SourceProviderAccountId, IdentityId, IdentityLinkBy, IdentityLinkType, IsPrimary, AccountId
                | join kind = leftouter (
                    IdentityAccountInfo
                        | where SourceProvider == @'AzureActiveDirectory'
                        | summarize arg_max(TimeGenerated, *) by AccountId
                        | where IsPrimary == true
                        | project IdentityId, AccountObjectId = SourceProviderAccountId, AccountUpn, AccountStatus
                ) on IdentityId
                | extend AssociatedPrimaryAccount = bag_pack_columns(AccountObjectId, AccountUpn, IdentityLinkType, IdentityId, AccountStatus)
                | project AccountObjectId = SourceProviderAccountId, AssociatedPrimaryAccount, PrimaryAccountObjectId = AccountObjectId
            ) on AccountObjectId
            | project-away AccountObjectId1
            | extend OnPremSynchronized = iff(isnotempty(OnPremObjectId), 'true', 'false')
            | extend IsDeleted = iff(isnotempty(DeletedDateTime), 'true', 'false')
            | project-away ReportId, AssignedRoles, PrivilegedEntraPimRoles;
            union AllUsers, PrivilegedUsers, AllWorkloads
            | extend AppId = OAuthAppId
            | extend Classification = case(
                isnotempty(Classification), Classification,
                TenantMembershipType == 'Member', 'UserAccess',
                TenantMembershipType == 'Guest' or AccountUpn contains '#EXT#@', 'ExternalAccess',
                'Unclassified'
            )
            | join kind = leftouter ( ExposureGraphNodes
            | mv-expand EntityIds
            | extend EntityType = parse_json(EntityIds)
            | where EntityType['type'] == 'AadObjectId' or EntityType['type'] == 'AzureResourceId'
            | mv-expand CriticalityData = parse_json(NodeProperties)['rawData']['criticalityLevel']['ruleNames']
            | extend CriticalityLevel = tostring(parse_json(NodeProperties)['rawData']['criticalityLevel']['criticalityLevel'])
            | extend RuleName = tostring(CriticalityData)
            | extend ObjectId = iff(EntityType['type'] == 'AadObjectId', tolower(tostring(extract('objectid=([\\w-]+)', 1, tostring(parse_json(EntityIds)['id'])))), tolower(tostring(EntityType['id'])))
            | extend CriticalAssetDetail = bag_pack_columns(CriticalityLevel, RuleName)
            | summarize CriticalAssetDetails = make_set_if(CriticalAssetDetail, isnotempty(CriticalAssetDetail)) by AccountObjectId = ObjectId
            ) on AccountObjectId
            | project-reorder AccountObjectId, AccountDisplayName, AccountStatus, Type, CriticalityLevel, CriticalAssetDetails, Classification, AssignedAzureRoles, AssignedEntraRoles, ApiPermissions, AssociatedPrimaryAccount;
        };
        // Lookback feature is limited to user identities only
        UnifiedIdentityInfoXdr(ObjectName='',ObjectId='',LookbackTimestamp=datetime(now))
        "
        $XspmUnifiedIdentityInfoResult = Invoke-MtGraphSecurityQuery -Query $Query -Timespan "P14D"

        if ( $XspmUnifiedIdentityInfoResult ) {
            return $XspmUnifiedIdentityInfoResult
        }
    } else {
        Write-Verbose "Checking prerequisites for Exposure Management"
        try {
            $AdvancedIdentityAvailable = ((Invoke-MtGraphRequest -ApiVersion "beta" -RelativeUri "security/runHuntingQuery" -Method POST `
                        -ErrorAction Stop `
                        -Body (@{"Query" = "IdentityInfo | getschema | where ColumnName == 'PrivilegedEntraPimRoles'" } | ConvertTo-Json) `
                        -OutputType PSObject).results.ColumnName -eq "PrivilegedEntraPimRoles")
            $OAuthAppInfoAvailable = ((Invoke-MtGraphRequest -ApiVersion "beta" -RelativeUri "security/runHuntingQuery" -Method POST `
                        -ErrorAction Stop `
                        -Body (@{"Query" = "OAuthAppInfo | getschema" } | ConvertTo-Json) `
                        -OutputType PSObject).results.ColumnName -contains "OAuthAppId")
            $UnifiedIdentityInfoExecutable = $AdvancedIdentityAvailable -and $OAuthAppInfoAvailable
            Write-Verbose "UnifiedIdentityInfoExecutable is $UnifiedIdentityInfoExecutable (IdentityInfo is $AdvancedIdentityAvailable, $OAuthAppInfoAvailable)"
            return $UnifiedIdentityInfoExecutable
        } catch {
            return $false
        }
    }
}