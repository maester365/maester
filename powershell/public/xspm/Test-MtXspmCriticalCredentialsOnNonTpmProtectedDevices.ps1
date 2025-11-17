<#
.SYNOPSIS
    Test to find devices that have critical credentials stored on devices that are not protected by TPM.

.DESCRIPTION
    Test to find devices that have critical credentials stored on devices that are not protected by TPM.

.OUTPUTS
    [bool] - Returns $true if no devices are found, $false if any are found, $null if skipped or prerequisites not met.

.EXAMPLE
    Test-MtXspmCriticalCredentialsOnNonTpmProtectedDevices

.LINK
    https://maester.dev/docs/commands/Test-MtXspmCriticalCredentialsOnNonTpmProtectedDevices
#>

function Test-MtXspmCriticalCredentialsOnNonTpmProtectedDevices {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks for devices that have critical credentials stored on devices that are not protected by TPM.')]
    [OutputType([bool])]
    param()

    Write-Verbose "Get raw data from Exposure Management..."
    $Query = @"
        let no_tpm_devices = (
        ExposureGraphNodes
        // Get device nodes with their inventory ID
        | mv-expand EntityIds
        | where EntityIds.type == "DeviceInventoryId"
        // Get interesting properties
        | extend OnboardingStatus = tostring(parse_json(NodeProperties)["rawData"]["onboardingStatus"]),
            TpmSupported = tostring(parse_json(NodeProperties)["rawData"]["tpmData"]["supported"]),
            TpmEnabled = tostring(parse_json(NodeProperties)["rawData"]["tpmData"]["enabled"]),
            TpmActivated = tostring(parse_json(NodeProperties)["rawData"]["tpmData"]["activated"]),
            DeviceName = tostring(parse_json(NodeProperties)["rawData"]["deviceName"]),
            DeviceId = tostring(EntityIds.id)
        | extend DeviceName = iff(isempty(DeviceName), NodeName, DeviceName)
        // Search for distinct devices
        | distinct NodeId, DeviceName, OnboardingStatus, TpmSupported, TpmEnabled, TpmActivated
        // Get device with no TPM enabled
        | where TpmSupported != "true" and TpmActivated != "true" and TpmEnabled != "true"
        | extend TpmSupported = iff(TpmSupported == "", "unknown", TpmSupported),
            TpmActivated = iff(TpmActivated == "", "unknown", TpmActivated),
            TpmEnabled = iff(TpmEnabled == "", "unknown", TpmEnabled)
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
    // Only return devices that do not have a TPM fully enabled
    | join kind=inner no_tpm_devices on `$left.SourceNodeId == `$right.NodeId
    // Make JSON of tpm data
    | extend TpmState = tostring(bag_pack(
        'TpmSupported', TpmSupported,
        'TpmEnabled', TpmEnabled,
        'TpmActivated', TpmActivated
    ))
    // Make list of users per device
    | summarize UserList = make_list(TargetNodeName) by DeviceName
    // Count amount of exposed users per device
    | extend UserCount = array_length(UserList)
    | sort by UserCount desc
"@

    $Devices = Invoke-MtGraphSecurityQuery -Query $Query -Timespan "P1D"

    $Severity = "Medium"

    if ($return -or [string]::IsNullOrEmpty($Devices)) {
        $testResultMarkdown = "Well done. All devices with critical credentials stored are protected by TPM."
    } else {
        $testResultMarkdown = "At least one device was found with critical credentials not protected by a TPM.`n`n%TestResult%"

        Write-Verbose "Found $($Devices.Count) devices with critical credentials not protected by a TPM."

        $result = "| DeviceName | UserList | UserCount |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($Device in $Devices) {
            $UserList = $($Device.UserList) -join ', '   # "user1, user2, user3"
            $result += "| $($Device.DeviceName) | $($UserList) | $($Device.UserCount) |`n"
        }
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity
    $result = [string]::IsNullOrEmpty($Devices)
    return $result
}