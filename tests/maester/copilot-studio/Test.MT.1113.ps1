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

function    Test-MtAIAgentBroadSharing {
    [MaesterTest(
        Id = 'MT.1113',
        Title = 'AI agents should not be shared with broad access control policies.',
        Severity = 'High',
        Category = 'Copilot Studio Agent Security',
        Tag = ('AI', 'AIAgent', 'CopilotStudio', 'Maester'),
        Service = 'Graph',
        Author = 'lnfernux'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason (Get-MtAIAgentSkippedReason -TestId 'MT.1113')
        return $null
    }

    Write-Verbose "Checking $($agents.Count) agent(s) for broad sharing configuration"

    $failedAgents = $agents | Where-Object { $_.AccessControlPolicy -eq "Any" -or $_.AccessControlPolicy -eq "Any multitenant" }

    if ($failedAgents.Count -eq 0) {
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
    return $failedAgents.Count -eq 0
}
