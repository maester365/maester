function Test-MtAIAgentEmailExfiltrationCompliance {
    <#
    .SYNOPSIS
    Tests if AI agents can send email with AI-controlled inputs.

    .DESCRIPTION
    Checks all Copilot Studio agents for email-sending tools (such as Office 365
    Outlook or SendMail connectors) where the recipient, subject, or body may be
    controlled by AI-generated content. This presents a risk of data exfiltration
    via email to attacker-controlled addresses.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAIAgentEmailExfiltrationCompliance
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
    } else {
        $result = "| Agent Name | Environment | Email Tools |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.EmailTools) |`n"
        }
    }

    return ($failedAgents.Count -eq 0)

}
