<#
.SYNOPSIS
    Tests if AI agents have risky HTTP configurations.

.DESCRIPTION
    Checks all Copilot Studio agents for HTTP actions that connect to non-standard
    ports or non-connector endpoints. HTTP actions to unexpected destinations may
    indicate data exfiltration, command-and-control communication, or misconfigured
    integrations.

.OUTPUTS
    [bool] - Returns $true if no risky HTTP configurations are found, $false if any
    agent has suspicious HTTP actions, $null if data is unavailable.

.EXAMPLE
    Test-MtAIAgentRiskyHttpConfig

.LINK
    https://maester.dev/docs/commands/Test-MtAIAgentRiskyHttpConfig
#>

function Test-MtAIAgentRiskyHttpConfig {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No AI agent data available. Ensure DataverseEnvironmentUrl is configured in maester-config.json and Connect-Maester -Service Dataverse has been run. See https://maester.dev/docs/tests/MT.1115 for prerequisites.'
        return $null
    }

    $failedAgents = @()

    foreach ($agent in $agents) {
        if ([string]::IsNullOrEmpty($agent.AgentTopicsDetails)) {
            continue
        }

        $topicsDetails = $null
        try {
            if ($agent.AgentTopicsDetails -is [string]) {
                $topicsDetails = $agent.AgentTopicsDetails | ConvertFrom-Json -ErrorAction Stop
            } else {
                $topicsDetails = $agent.AgentTopicsDetails
            }
        } catch {
            Write-Verbose "Could not parse AgentTopicsDetails for agent $($agent.AIAgentName): $_"
            continue
        }

        # Look for HTTP actions with non-standard ports or non-HTTPS URLs
        # Search the raw Data field (YAML) of each topic directly, not JSON-serialized
        $riskyActions = @()
        $items = if ($topicsDetails -is [array]) { $topicsDetails } else { @($topicsDetails) }
        foreach ($topic in $items) {
            $data = $topic.Data
            if ([string]::IsNullOrEmpty($data)) { continue }

            # Match HTTP URLs with explicit non-443 ports
            $portMatches = [regex]::Matches($data, 'https?://[^\s]+:(\d+)')
            foreach ($match in $portMatches) {
                $port = $match.Groups[1].Value
                if ($port -ne '443' -and $port -ne '80') {
                    $riskyActions += "Non-standard port :$port in topic '$($topic.Name)'"
                }
            }
            # Match plain HTTP (non-HTTPS) URLs
            $httpMatches = [regex]::Matches($data, '(http://[^\s]+)')
            foreach ($match in $httpMatches) {
                $riskyActions += "Plain HTTP: $($match.Groups[1].Value) in topic '$($topic.Name)'"
            }
            # Match HttpRequestAction kind (direct HTTP calls from topics)
            if ($data -match 'kind:\s*HttpRequestAction') {
                $riskyActions += "HttpRequestAction in topic '$($topic.Name)'"
            }
        }

        if ($riskyActions.Count -gt 0) {
            $failedAgents += [PSCustomObject]@{
                AIAgentName   = $agent.AIAgentName
                EnvironmentId = $agent.EnvironmentId
                RiskyActions  = ($riskyActions | Select-Object -Unique) -join '; '
            }
        }
    }

    if ($failedAgents.Count -eq 0) {
        $testResultMarkdown = "Well done. No AI agents have risky HTTP configurations."
    } else {
        $testResultMarkdown = "Found $($failedAgents.Count) AI agent(s) with risky HTTP configurations.`n`n%TestResult%"
        $result = "| Agent Name | Environment | Risky Actions |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.RiskyActions) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity "Medium"
    return ($failedAgents.Count -eq 0)
}
