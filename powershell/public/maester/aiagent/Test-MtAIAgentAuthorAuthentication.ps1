<#
.SYNOPSIS
    Tests if AI agents use author (maker) authentication for their connector tools.

.DESCRIPTION
    Checks all Copilot Studio agents for connector tools that use author (maker)
    authentication instead of end-user authentication. When a connection uses
    author authentication, the agent accesses external services (SharePoint, SQL,
    etc.) using the bot maker's stored credentials rather than requiring the end
    user to authenticate. This creates a privilege escalation risk — the agent
    operates with the maker's permissions regardless of who is chatting with it.

    Reference: https://www.microsoft.com/en-us/security/blog/2026/02/12/copilot-studio-agent-security-top-10-risks-detect-prevent/

.OUTPUTS
    [bool] - Returns $true if no agents use author/maker authentication,
    $false if any agent has connections using the maker's credentials,
    $null if data is unavailable.

.EXAMPLE
    Test-MtAIAgentAuthorAuthentication

.LINK
    https://maester.dev/docs/commands/Test-MtAIAgentAuthorAuthentication
#>

function Test-MtAIAgentAuthorAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No AI agent data available. Ensure DataverseEnvironmentUrl is configured in maester-config.json and Connect-Maester -Service Dataverse has been run. See https://maester.dev/docs/tests/MT.1118 for prerequisites.'
        return $null
    }

    # Detect author (maker) authentication on connector tools.
    # In Copilot Studio, tools using user authentication have 'connectionProperties: mode: Invoker'
    # in their YAML data. Tools with a connectionReference but WITHOUT mode: Invoker
    # use the maker's embedded connection (author authentication).
    $failedAgents = @()

    foreach ($agent in $agents) {
        if ([string]::IsNullOrEmpty($agent.AgentToolsDetails)) {
            continue
        }

        # Parse the tools JSON to inspect each tool's YAML data
        $tools = $null
        try {
            if ($agent.AgentToolsDetails -is [string]) {
                $tools = $agent.AgentToolsDetails | ConvertFrom-Json -ErrorAction Stop
            } else {
                $tools = @($agent.AgentToolsDetails)
            }
        } catch {
            Write-Verbose "Could not parse AgentToolsDetails for agent $($agent.AIAgentName): $_"
            continue
        }

        # Ensure $tools is always an array
        if ($tools -isnot [System.Array]) { $tools = @($tools) }

        $makerAuthTools = @()
        foreach ($tool in $tools) {
            $data = $tool.Data
            if ([string]::IsNullOrEmpty($data)) { continue }

            # Check if the tool has a connection reference (uses a connector)
            if ($data -match 'connectionReference:') {
                # If it does NOT have mode: Invoker, it uses maker auth
                if ($data -notmatch 'mode:\s*Invoker') {
                    $makerAuthTools += $tool.Name
                }
            }
        }

        if ($makerAuthTools.Count -gt 0) {
            $failedAgents += [PSCustomObject]@{
                AIAgentName        = $agent.AIAgentName
                EnvironmentId      = $agent.EnvironmentId
                MakerAuthTools     = ($makerAuthTools -join ', ')
            }
        }
    }

    if ($failedAgents.Count -eq 0) {
        $testResultMarkdown = "Well done. No AI agents are using author (maker) authentication for their connections."
    } else {
        $testResultMarkdown = "Found $($failedAgents.Count) AI agent(s) using author (maker) authentication for connections.`n`n%TestResult%"
        $result = "| Agent Name | Environment | Maker Auth Tools |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.MakerAuthTools) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity "High"
    return ($failedAgents.Count -eq 0)
}
