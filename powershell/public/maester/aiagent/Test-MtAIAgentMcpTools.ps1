<#
.SYNOPSIS
    Tests if AI agents are configured with MCP server tools.

.DESCRIPTION
    Checks all Copilot Studio agents for Model Context Protocol (MCP) server tool
    integrations. MCP tools extend agents with arbitrary external capabilities and
    may introduce supply chain risks if the MCP server is compromised or untrusted.

.OUTPUTS
    [bool] - Returns $true if no MCP tools are found, $false if any agent uses
    MCP tools, $null if data is unavailable.

.EXAMPLE
    Test-MtAIAgentMcpTools

.LINK
    https://maester.dev/docs/commands/Test-MtAIAgentMcpTools
#>

function Test-MtAIAgentMcpTools {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No Copilot Studio agent data available. Ensure DataverseEnvironmentUrl is configured in maester-config.json and Connect-Maester -Service Dataverse has been run. See https://maester.dev/docs/tests/MT.1120 for prerequisites.'
        return $null
    }

    $mcpPatterns = @('MCP', 'ModelContextProtocol', 'Model Context Protocol', 'mcp_server', 'mcpServer', 'mcp-server')

    $failedAgents = @()

    foreach ($agent in $agents) {
        if ([string]::IsNullOrEmpty($agent.AgentToolsDetails)) {
            continue
        }

        $toolsJson = $null
        try {
            if ($agent.AgentToolsDetails -is [string]) {
                $toolsJson = $agent.AgentToolsDetails
            } else {
                $toolsJson = $agent.AgentToolsDetails | ConvertTo-Json -Depth 10 -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Verbose "Could not process AgentToolsDetails for agent $($agent.AIAgentName): $_"
            continue
        }

        if ($null -eq $toolsJson) { continue }

        $matchedPatterns = @()
        foreach ($pattern in $mcpPatterns) {
            if ($toolsJson -match [regex]::Escape($pattern)) {
                $matchedPatterns += $pattern
            }
        }

        if ($matchedPatterns.Count -gt 0) {
            $failedAgents += [PSCustomObject]@{
                AIAgentName   = $agent.AIAgentName
                EnvironmentId = $agent.EnvironmentId
                McpIndicators = ($matchedPatterns | Select-Object -Unique) -join ', '
            }
        }
    }

    if ($failedAgents.Count -eq 0) {
        $testResultMarkdown = "Well done. No AI agents are configured with MCP server tools."
    } else {
        $testResultMarkdown = "Found $($failedAgents.Count) AI agent(s) with MCP server tool integrations.`n`n%TestResult%"
        $result = "| Agent Name | Environment | MCP Indicators |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.McpIndicators) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity "Medium"
    return ($failedAgents.Count -eq 0)
}
