<#
.SYNOPSIS
    Check data from various XDR tables to identify applications role assignments, API permissions and ownership.

.DESCRIPTION
    Details about the OAuth application and workload identity posture in your environment.

.EXAMPLE
    Test-MtOAuthAppPosture

    Returns true if no application has Tier-0 graph permissions

.LINK
    https://maester.dev/docs/commands/Get-MtOAuthAppDetailsFromXdr
#>

function Get-MtOAuthAppDetailsFromXdr {

    $Query = "
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
            | where Timestamp >ago(14d)
            | summarize arg_max(Timestamp, *) by AccountObjectId
            | project ServicePrincipalName = AccountDisplayName, ServicePrincipalId = AccountObjectId
        // Lookup for OAuth application details
        | lookup (
            OAuthAppInfo
                | where Timestamp >ago(30d)
                | summarize arg_max(Timestamp, *) by ServicePrincipalId
        ) on ServicePrincipalId
        // Lookup for Graph API Classification
        | lookup (
            OAuthAppInfo
                | where Timestamp >ago(30d)
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
                | extend ApiPermission = bag_pack_columns(AppId, AppDisplayName, AppRoleId, AppRoleDisplayName, InUse, PrivilegeLevel, Category, EAMTierLevelName)
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
                | extend RoleDefinitionId = RoleId
                | project RoleAssignments = bag_pack_columns(RoleDefinitionName, RoleDefinitionId, Classification, RoleIsPrivileged), ServicePrincipalId = AccountObjectId
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
        | project-away XspmGraphNodeId, XspmGraphNodeId1, ServicePrincipalId1, ServicePrincipalId2, XspmGraphNodeId1, XspmGraphNodeId2, TargetNodeId, XspmGraphOAuthAppNodeId, XspmGraphOAuthAppNodeId1
        | sort by ServicePrincipalName asc
        | project ServicePrincipalName, ServicePrincipalId, OAuthAppId, AddedOnTime, LastModifiedTime, AppStatus, VerifiedPublisher, IsAdminConsented, AppOrigin, AppOwnerTenantId, ApiPermissions, AssignedAzureRoles, AssignedEntraRoles, AuthenticatedBy, OwnedBy
        | sort by OAuthAppId
    "

    $Body = @{
        "Query" = $Query;
    } | ConvertTo-Json

        $XdrAdvHuntingQuery = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/security/runHuntingQuery" -Method POST -Body $Body -OutputType PSObject
        if ( $XdrAdvHuntingQuery ) {
            return $XdrAdvHuntingQuery
        } else {
            Write-Error "Failed to run advanced hunting query to get application and workload identity details."
        }
}