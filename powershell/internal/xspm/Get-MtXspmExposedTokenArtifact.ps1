<#
.SYNOPSIS
    Check data from Exposure Management for exposed token artifacts.
.DESCRIPTION
    Executes KQL function over Exposure Management data to retrieve information about exposed token artifacts such as Primary Refresh Tokens, Session Cookies, and Azure CLI tokens. It enriches the data with device insights and alert evidence.
.EXAMPLE
    Get-MtXspmExposedAuthenticationArtifact
    Returns a detailed list of exposed token artifacts, including their types, associated devices, and any relevant alert evidence.
.LINK
    https://maester.dev/docs/commands/Get-MtXspmExposedAuthenticationArtifact
#>

function Get-MtXspmExposedAuthenticationArtifact {

    $Query = "
        let PrimaryRefresh = ExposureGraphEdges
            | where EdgeLabel == @'has credentials of'
            | join kind = inner (
                ExposureGraphNodes
                | project NodeId, RawData = parse_json(NodeProperties)['rawData'], EntityIds
            ) on `$left.SourceNodeId == `$right.NodeId
            | join kind = inner (
                ExposureGraphNodes
                | extend AccountObjectId = tostring(parse_json(NodeProperties)['rawData']['accountObjectId'])
                | project AccountObjectId, NodeId
            ) on `$left.TargetNodeId == `$right.NodeId
            | where parse_json(EdgeProperties)['rawData']['primaryRefreshToken']['primaryRefreshToken'] == 'true'
            | extend TokenType = tostring(parse_json(EdgeProperties)['rawData']['primaryRefreshToken']['type'])
            | project EdgeId, SourceNodeId, SourceNodeName, SourceNodeLabel, EdgeLabel, TargetNodeId, TargetNodeName, TokenType, DeviceRawData = RawData, EntityIds, AccountObjectId;
        let SessionCookie = ExposureGraphEdges
            | where EdgeLabel == @'contains' and TargetNodeLabel == 'entra-userCookie'
            | join kind = inner (
                ExposureGraphNodes
                | project NodeId, RawData = parse_json(NodeProperties)['rawData'], EntityIds
            ) on `$left.SourceNodeId == `$right.NodeId
            | join kind = inner (
                ExposureGraphNodes
                | project NodeId, RawData = parse_json(NodeProperties)['rawData'], EntityIds
            ) on `$left.TargetNodeId == `$right.NodeId
            | join kind = inner (
                ExposureGraphEdges
                | where EdgeLabel == @'can authenticate as' and SourceNodeLabel == @'entra-userCookie'
            ) on `$left.TargetNodeId == `$right.SourceNodeId
            | join kind = inner (
                ExposureGraphNodes
                | extend AccountObjectId = tostring(parse_json(NodeProperties)['rawData']['accountObjectId'])
                | project NodeId, AccountObjectId
            ) on `$left.TargetNodeId1 == `$right.NodeId
            | extend TargetNodeId
            | extend TokenType = 'UserCookie'
            | project EdgeId, SourceNodeId, SourceNodeName, SourceNodeLabel, EdgeLabel, TargetNodeId = TargetNodeId1, TargetNodeName = TargetNodeName1, TokenType, DeviceRawData = RawData, EntityIds, AccountObjectId;
        let AzureCliToken = ExposureGraphNodes
            // RT and AT in Azure CLI e.g., privileged account not primary user but will be used on this device
            | where NodeLabel == 'user-azure-cli-secret'
            | extend AccountSid = tostring(parse_json(NodeProperties)['rawData']['userAzureCliSecretData']['userSid'])
            | join kind=inner ( ExposureGraphNodes
                | extend AccountObjectId = tostring(parse_json(NodeProperties)['rawData']['accountObjectId'])
                | extend AccountSid = tostring(parse_json(NodeProperties)['rawData']['aadSid'])
                | project UserNodeId = NodeId, UserNodeName = NodeName, AccountSid, AccountObjectId
            ) on AccountSid
            | join kind=inner (
                ExposureGraphEdges
                ) on `$left.NodeId == `$right.TargetNodeId
            | extend TokenType = tostring(parse_json(NodeProperties)['rawData']['userAzureCliSecretData']['type'])
            | project EdgeId, SourceNodeId, SourceNodeName, SourceNodeLabel, EdgeLabel, TargetNodeId = UserNodeId, TargetNodeName = UserNodeName, TokenType, TokenNodeId = TargetNodeId, TokenNodeName = TargetNodeName, UserRawData = parse_json(NodeProperties)['rawData'], AccountObjectId;
        union PrimaryRefresh, SessionCookie, AzureCliToken
        // Enrichment to MDE insights
        | summarize DeviceRawData = make_set(DeviceRawData), EntityIds = make_set(EntityIds), TokenArtifacts = make_list(TokenType) by SourceNodeId, SourceNodeName, TargetNodeId, TargetNodeName, AccountObjectId
        | mv-apply EntityIds = parse_json(EntityIds) on (
            where EntityIds.type =~ 'DeviceInventoryId'
            | extend DeviceId = tostring(EntityIds.id)
        )
        | extend HighRiskVulnerability = iff(parse_json(DeviceRawData)['highRiskVulnerabilityInsights']['hasHighOrCritical'] == 'true', true, false)
        | extend CredentialGuard = iff(parse_json(DeviceRawData)['hasGuardMisconfigurations'] has 'Credential Guard', false, true)
        | mv-expand parse_json(DeviceRawData)
        | project
                User = TargetNodeName,
                TokenArtifacts,
                Device = SourceNodeName,
                DeviceId,
                PublicIP = tostring(parse_json(DeviceRawData)['publicIP']),
                ExposureScore = tostring(parse_json(DeviceRawData)['exposureScore']),
                RiskScore = tostring(parse_json(DeviceRawData)['riskScore']),
                HighRiskOrCriticalVulnerability = tostring(HighRiskVulnerability),
                MaxCvssScore = tostring(parse_json(DeviceRawData)['highRiskVulnerabilityInsights']['maxCvssScore']),
                AllowedRDP = tostring(parse_json(DeviceRawData)['rdpStatus']['allowConnections']),
                CredentialGuard = tostring(CredentialGuard),
                TpmActivated = tostring(parse_json(DeviceRawData)['tpmData']['activated']),
                SourceNodeId,
                TargetNodeId,
                AccountObjectId
        | join kind = leftouter ( AlertEvidence
            | where isnotempty(DeviceId)
            | summarize Alerts = make_set(Title), AlertCategories = make_set(Categories) by DeviceId
        ) on DeviceId
        | project-away DeviceId1
        | sort by User, Device
    "

    $XspmExposedTokenArtifacts = Invoke-MtGraphSecurityQuery -Query $Query -Timespan "P1D"
    return $XspmExposedTokenArtifacts
}