<#
.SYNOPSIS
    Tests if AI agents with generative orchestration have custom instructions.

.DESCRIPTION
    Checks all Copilot Studio agents that use generative orchestration (generative
    actions enabled) for the presence of custom instructions. Agents without
    instructions rely entirely on the LLM's default behavior, which increases the
    risk of prompt injection, off-topic responses, and uncontrolled tool usage.

.OUTPUTS
    [bool] - Returns $true if all generative agents have instructions, $false if
    any generative agent is missing instructions, $null if data is unavailable.

.EXAMPLE
    Test-MtAIAgentMissingInstructions

.LINK
    https://maester.dev/docs/commands/Test-MtAIAgentMissingInstructions
#>

function Test-MtAIAgentMissingInstructions {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No AI agent data available. Ensure DataverseEnvironmentUrl is configured in maester-config.json and Connect-Maester -Service Dataverse has been run. See https://maester.dev/docs/tests/MT.1121 for prerequisites.'
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
        $testResultMarkdown = "Well done. All AI agents with generative orchestration have custom instructions."
    } else {
        $testResultMarkdown = "Found $($failedAgents.Count) AI agent(s) using generative orchestration without custom instructions.`n`n%TestResult%"
        $result = "| Agent Name | Environment | Status |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.AgentStatus) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity "Medium"
    return ($failedAgents.Count -eq 0)
}
