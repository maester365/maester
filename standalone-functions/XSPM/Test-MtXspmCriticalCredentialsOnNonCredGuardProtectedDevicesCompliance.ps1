function Test-MtXspmCriticalCredentialsOnNonCredGuardProtectedDevicesCompliance {
    <#
    .SYNOPSIS
    Find devices with critical credentials stored on devices not protected by Credential Guard.

    .DESCRIPTION
    Find devices with critical credentials stored on devices not protected by Credential Guard.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtXspmCriticalCredentialsOnNonCredGuardProtectedDevicesCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose "Get raw data from Exposure Management..."
    $Query = @"

let no_credguard_devices = (
        ExposureGraphNodes
        // Get devices with credential guard misconfiguration
        | where array_length(NodeProperties.rawData.hasGuardMisconfigurations) > 0
        // Get interesting data
        | extend DeviceName = tostring(parse_json(NodeProperties)["rawData"]["deviceName"]),
            DeviceId = tostring(EntityIds.id)
        | extend DeviceName = iff(isempty(DeviceName), NodeName, DeviceName)
        // Search for distinct devices
        | distinct NodeId, DeviceName
    );
    let critical_users = toscalar(
        // Search for critical users
        ExposureGraphNodes
        | where NodeLabel == "user"
        | extend CriticalityLevel = todynamic(NodeProperties).rawData.criticalityLevel.criticalityLevel
        | extend RuleNames = todynamic(NodeProperties).rawData.criticalityLevel.ruleNames
        | where CriticalityLevel == 0
        | distinct NodeName, NodeId, tostring(CriticalityLevel), tostring(RuleNames)
        | summarize make_set(NodeName)
    );
    // Make graph for max of 3 edges, where we start from a device and end with an user
    ExposureGraphEdges
    | make-graph SourceNodeId --> TargetNodeId with ExposureGraphNodes on NodeId
    | graph-match (SourceNode)-[anyEdge*1..3]->(TargetNode)
        where SourceNode.NodeLabel in ("device", "microsoft.compute/virtualmachines") and TargetNode.NodeLabel == "user" and TargetNode.NodeName in ( critical_users )
        project SourceNodeName = SourceNode.NodeName,
        SourceNodeId = SourceNode.NodeId,
        Edges = anyEdge.EdgeLabel,
        TargetNodeId = TargetNode.NodeId,
        TargetNodeName = TargetNode.NodeName,
        TargetNodeLabel = TargetNode.NodeLabel,
        TargetCriticalityLevel = TargetNode.NodeProperties.rawData.criticalityLevel.criticalityLevel,
        TargetRuleNames = TargetNode.NodeProperties.rawData.criticalityLevel.ruleNames
    | distinct SourceNodeId, SourceNodeName, TargetNodeId, TargetNodeName, tostring(TargetCriticalityLevel), tostring(TargetRuleNames)
    // Only return devices that do not have Credential Guard fully enabled
    | join kind=inner no_credguard_devices on `$left.SourceNodeId == `$right.NodeId
    // Make list of users per device
    | summarize UserList = make_list(TargetNodeName) by DeviceName
    // Count amount of exposed users per device
    | extend UserCount = array_length(UserList)
    | sort by UserCount desc
"@

    $Devices = Invoke-MtGraphSecurityQuery -Query $Query -Timespan "P1D"

    $Severity = "Medium"

    if ($return -or [string]::IsNullOrEmpty($Devices)) {
    } else {

        Write-Verbose "Found $($Devices.Count) devices with critical credentials not protected by a Credential Guard."

        $result = "| DeviceName | UserList | UserCount |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($Device in $Devices) {
            $UserList = $($Device.UserList) -join ', '   # "user1, user2, user3"
            $result += "| $($Device.DeviceName) | $($UserList) | $($Device.UserCount) |`n"
        }
    }
    $result = [string]::IsNullOrEmpty($Devices)
    return $result

}
