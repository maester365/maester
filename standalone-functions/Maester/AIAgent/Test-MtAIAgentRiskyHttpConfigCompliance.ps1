function Test-MtAIAgentRiskyHttpConfigCompliance {
    <#
    .SYNOPSIS
    Tests if AI agents have risky HTTP configurations.

    .DESCRIPTION
    Checks all Copilot Studio agents for HTTP actions that connect to non-standard
    ports or non-connector endpoints. HTTP actions to unexpected destinations may
    indicate data exfiltration, command-and-control communication, or misconfigured
    integrations.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAIAgentRiskyHttpConfigCompliance
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
                if ($port -ne '443') {
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
    } else {
        $result = "| Agent Name | Environment | Risky Actions |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.RiskyActions) |`n"
        }
    }

    return ($failedAgents.Count -eq 0)

}
