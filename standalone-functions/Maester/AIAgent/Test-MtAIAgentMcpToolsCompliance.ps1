function Test-MtAIAgentMcpToolsCompliance {
    <#
    .SYNOPSIS
    Tests if AI agents are configured with MCP server tools.

    .DESCRIPTION
    Checks all Copilot Studio agents for Model Context Protocol (MCP) server tool
    integrations. MCP tools extend agents with arbitrary external capabilities and
    may introduce supply chain risks if the MCP server is compromised or untrusted.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAIAgentMcpToolsCompliance
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
    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
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
    } else {
        $result = "| Agent Name | Environment | MCP Indicators |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.McpIndicators) |`n"
        }
    }

    return ($failedAgents.Count -eq 0)

}
