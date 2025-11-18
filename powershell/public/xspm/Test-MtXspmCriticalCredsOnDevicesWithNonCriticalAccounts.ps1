<#
.SYNOPSIS
    Test to find devices with critical and non-critical user credentials on the same device

.DESCRIPTION
    Test to find devices with critical and non-critical user credentials on the same device

.OUTPUTS
    [bool] - Returns $true if no devices with critical and non-critical devices are found, $false if any are found, $null if skipped or prerequisites not met.

.EXAMPLE
    Test-MtXspmCriticalCredsOnDevicesWithNonCriticalAccounts

.LINK
    https://maester.dev/docs/commands/Test-MtXspmCriticalCredsOnDevicesWithNonCriticalAccounts
#>

function Test-MtXspmCriticalCredsOnDevicesWithNonCriticalAccounts {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks for devices with critical and non-critical user credentials on the same device.')]
    [OutputType([bool])]
    param()

    Write-Verbose "Get raw data from Exposure Management..."
    $Query = "
        // Search for all users and save their criticality level
        let xspm_users = materialize(
            ExposureGraphNodes
            | where NodeLabel == 'user'
            | extend CriticalityLevel = todynamic(NodeProperties).rawData.criticalityLevel.criticalityLevel
            | extend RuleNames = todynamic(NodeProperties).rawData.criticalityLevel.ruleNames
            | distinct NodeName, NodeId, tostring(CriticalityLevel), tostring(RuleNames)
        );
        // Make a list of all critical users
        let critical_users = toscalar(
            xspm_users
            | where CriticalityLevel == 0
            | summarize make_set(NodeName)
        );
        // Make a list of all non critical users
        let non_critical_users = toscalar(
            xspm_users
            | where CriticalityLevel != 0
            | summarize make_set(NodeName)
        );
        ExposureGraphEdges
        // Focus on credential related paths
        | where EdgeLabel in ('contains', 'can impersonate as', 'has credentials of', 'can authenticate as', 'has permissions to', 'frequently logged in by')
        // Make graph for max of 3 edges, where we start from a device and end with an user
        | make-graph SourceNodeId --> TargetNodeId with ExposureGraphNodes on NodeId
        | graph-match (SourceNode)-[anyEdge*1..3]->(TargetNode)
            where SourceNode.NodeLabel in ('device', 'microsoft.compute/virtualmachines') and TargetNode.NodeLabel == 'user'
            project DeviceName = SourceNode.NodeName,
            Edges = anyEdge.EdgeLabel,
            TargetNodeName = TargetNode.NodeName,
            TargetNodeLabel = TargetNode.NodeLabel
        // Make a list of all users a device has credentials for
        | summarize UserList = make_set(TargetNodeName) by DeviceName
        // Only return devices with more than one credential
        | where array_length(UserList) > 1
        // Make new lists saving the critical users and non critical users per device
        | extend CriticalUserList = set_intersect(UserList, critical_users),
            NonCriticalUserList = set_intersect(UserList, non_critical_users)
        // Flag when a device has both critical and non critical users
        | where array_length(CriticalUserList) > 0 and array_length(NonCriticalUserList) > 0
        // Sort and Remove the total user list
        | sort by array_length(UserList) desc
        | project-away UserList
    "
    $Devices = Invoke-MtGraphSecurityQuery -Query $Query -Timespan "P1D"

    $Severity = "Low"

    if ([string]::IsNullOrEmpty($Devices)) {
        $testResultMarkdown = "Well done. No devices with shared critical and non-critical user credentials are found."
    } else {
        $testResultMarkdown = "At least one device with shared critical and non-critical user credentials were found.`n`n%TestResult%"

        Write-Verbose "Found $($Devices.Count) devices sharing critical and non-critical credentials on the same device."

        $result = "| DeviceName | CriticalUserList | NonCriticalUserList | `n"
        $result += "| --- | --- | --- |`n"
        foreach ($Device in $Devices) {
            $CriticalUsers = $($Device.CriticalUserList) -join ', '   # "user1, user2, user3"
            $NonCriticalUsers = $($Device.NonCriticalUserList) -join ', '   # "user1, user2, user3"
            $result += "| $($Device.DeviceName) | $($CriticalUsers) | $($NonCriticalUsers) |`n"
        }
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity $Severity
    $result = [string]::IsNullOrEmpty($Devices)
    return $result
}