<#
.SYNOPSIS
    Tests if AI agents are shared too broadly.

.DESCRIPTION
    Checks all Copilot Studio agents for those with access control set to "Any" or
    "Any multitenant", which allows any user (or users across tenants) to interact
    with the agent.

.OUTPUTS
    [bool] - Returns $true if no agents are broadly shared, $false if any agent has
    open access control, $null if data is unavailable.

.EXAMPLE
    Test-MtAIAgentBroadSharing

.LINK
    https://maester.dev/docs/commands/Test-MtAIAgentBroadSharing
#>

function Test-MtAIAgentBroadSharing {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No Copilot Studio agent data available. Ensure DataverseEnvironmentUrl is configured in maester-config.json and Connect-Maester -Service Dataverse has been run. See https://maester.dev/docs/tests/MT.1113 for prerequisites.'
        return $null
    }

    Write-Verbose "Checking $($agents.Count) agent(s) for broad sharing configuration"

    $failedAgents = $agents | Where-Object { $_.AccessControlPolicy -eq "Any" -or $_.AccessControlPolicy -eq "Any multitenant" }

    if ([string]::IsNullOrEmpty($failedAgents)) {
        $testResultMarkdown = "Well done. No AI agents are shared broadly."
    } else {
        $testResultMarkdown = "Found $($failedAgents.Count) AI agent(s) with broad sharing configured.`n`n%TestResult%"
        $result = "| Agent Name | Environment | Access Control | Authentication |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.AccessControlPolicy) | $($agent.UserAuthenticationType) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity "High"
    return [string]::IsNullOrEmpty($failedAgents)
}
