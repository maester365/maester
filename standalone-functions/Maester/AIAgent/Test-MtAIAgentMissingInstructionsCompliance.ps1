function Test-MtAIAgentMissingInstructionsCompliance {
    <#
    .SYNOPSIS
    Tests if AI agents with generative orchestration have custom instructions.

    .DESCRIPTION
    Checks all Copilot Studio agents that use generative orchestration (generative
    actions enabled) for the presence of custom instructions. Agents without
    instructions rely entirely on the LLM's default behavior, which increases the
    risk of prompt injection, off-topic responses, and uncontrolled tool usage.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAIAgentMissingInstructionsCompliance
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
        # Check if generative orchestration is enabled using the dedicated column
        $generativeEnabled = $false
        if ($agent.PSObject.Properties['IsGenerativeOrchestrationEnabled']) {
            $generativeEnabled = $agent.IsGenerativeOrchestrationEnabled -eq $true -or $agent.IsGenerativeOrchestrationEnabled -eq 'true'
        }

        if (-not $generativeEnabled) {
            continue
        }

        # Check for custom instructions in RawAgentInfo
        $hasInstructions = $false
        if (-not [string]::IsNullOrEmpty($agent.RawAgentInfo)) {
            $rawInfo = $null
            try {
                if ($agent.RawAgentInfo -is [string]) {
                    $rawInfo = $agent.RawAgentInfo | ConvertFrom-Json -ErrorAction Stop
                } else {
                    $rawInfo = $agent.RawAgentInfo
                }
            } catch {
                Write-Verbose "Could not parse RawAgentInfo for agent $($agent.AIAgentName): $_"
            }

            if ($null -ne $rawInfo) {
                foreach ($prop in @('Instructions', 'CustomInstructions', 'SystemPrompt', 'SystemMessage')) {
                    if ($rawInfo.PSObject.Properties[$prop] -and -not [string]::IsNullOrWhiteSpace($rawInfo.$prop)) {
                        $hasInstructions = $true
                        break
                    }
                }
            }
        }

        if (-not $hasInstructions) {
            $failedAgents += [PSCustomObject]@{
                AIAgentName   = $agent.AIAgentName
                EnvironmentId = $agent.EnvironmentId
                AgentStatus   = $agent.AgentStatus
            }
        }
    }

    if ($failedAgents.Count -eq 0) {
    } else {
        $result = "| Agent Name | Environment | Status |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.AgentStatus) |`n"
        }
    }

    return ($failedAgents.Count -eq 0)

}
