function Test-MtAdDisabledReplicationConnectionCount {
    <#
    .SYNOPSIS
    Checks for disabled Active Directory replication connections.

    .DESCRIPTION
    Replication connections are used to synchronize data between domain controllers.
    Disabled replication connections can cause replication failures and inconsistent
    directory data across domain controllers, potentially leading to security issues
    such as stale password data or inconsistent access controls.

    Security Best Practice:
    - All replication connections should be enabled in a healthy environment
    - Disabled connections should be investigated and either re-enabled or removed
    - Unnecessary disabled connections may indicate incomplete decommissioning

    .EXAMPLE
    Test-MtAdDisabledReplicationConnectionCount

    Returns $true if replication connection data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDisabledReplicationConnectionCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $replicationConnections = $adState.ReplicationConnections
    $totalConnections = ($replicationConnections | Measure-Object).Count
    $disabledConnections = $replicationConnections | Where-Object { $_.Enabled -eq $false }
    $disabledCount = ($disabledConnections | Measure-Object).Count

    $testResult = $true

    $result = "| Property | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Replication Connections | $totalConnections |`n"
    $result += "| Disabled Connections | $disabledCount |`n"
    $result += "| Enabled Connections | $($totalConnections - $disabledCount) |`n"

    if ($totalConnections -gt 0) {
        $percentage = [Math]::Round(($disabledCount / $totalConnections) * 100, 2)
        $result += "| Disabled Percentage | $percentage% |`n"
    }

    $testResultMarkdown = "Active Directory replication connections have been analyzed. Disabled connections may indicate replication issues.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
