<#
.SYNOPSIS
    Tests if AI agents can send email with AI-controlled inputs.

.DESCRIPTION
    Checks all Copilot Studio agents for email-sending tools (such as Office 365
    Outlook or SendMail connectors) where the recipient, subject, or body may be
    controlled by AI-generated content. This presents a risk of data exfiltration
    via email to attacker-controlled addresses.

.OUTPUTS
    [bool] - Returns $true if no email exfiltration risk is found, $false if any
    agent has email-sending capabilities with dynamic inputs, $null if data is
    unavailable.

.EXAMPLE
    Test-MtAIAgentEmailExfiltration

.LINK
    https://maester.dev/docs/commands/Test-MtAIAgentEmailExfiltration
#>

function Test-MtAIAgentEmailExfiltration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No AI agent data available. Ensure DataverseEnvironmentUrl is configured in maester-config.json and Connect-Maester -Service Dataverse has been run. See https://maester.dev/docs/tests/MT.1116 for prerequisites.'
        return $null
    }

    $emailPatterns = @('Office 365 Outlook', 'SendMail', 'Send an email', 'Send_an_email', 'Outlook', 'Mail.Send', 'microsoft.graph.sendMail')

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

        $matchedTools = @()
        foreach ($pattern in $emailPatterns) {
            if ($toolsJson -match [regex]::Escape($pattern)) {
                $matchedTools += $pattern
            }
        }

        if ($matchedTools.Count -gt 0) {
            $failedAgents += [PSCustomObject]@{
                AIAgentName   = $agent.AIAgentName
                EnvironmentId = $agent.EnvironmentId
                EmailTools    = ($matchedTools | Select-Object -Unique) -join ', '
            }
        }
    }

    if ($failedAgents.Count -eq 0) {
        $testResultMarkdown = "Well done. No AI agents have email-sending capabilities with AI-controlled inputs."
    } else {
        $testResultMarkdown = "Found $($failedAgents.Count) AI agent(s) with email-sending tools that may allow data exfiltration.`n`n%TestResult%"
        $result = "| Agent Name | Environment | Email Tools |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.EmailTools) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity "High"
    return ($failedAgents.Count -eq 0)
}
