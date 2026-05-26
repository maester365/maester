function Test-MtAIAgentNoAuthenticationCompliance {
    <#
    .SYNOPSIS
    Tests if AI agents require user authentication.

    .DESCRIPTION
    Checks all Copilot Studio agents for weak or missing authentication.
    Flags agents with no authentication configured, as well as agents where
    authentication is configured but 'Require users to sign in' is not enabled
    (trigger set to 'As Needed' instead of 'Always').
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAIAgentNoAuthenticationCompliance
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

    Write-Verbose "Checking $($agents.Count) agent(s) for missing or weak authentication"

    # Agents with no authentication at all
    $noAuthAgents = $agents | Where-Object { $_.UserAuthenticationType -eq "None" }
    # Agents with auth configured but sign-in not required (trigger = As Needed)
    $optionalAuthAgents = $agents | Where-Object {
        $_.UserAuthenticationType -ne "None" -and $_.AuthenticationTrigger -eq "As Needed"
    }
    $failedAgents = @()
    if ($noAuthAgents) { $failedAgents += $noAuthAgents }
    if ($optionalAuthAgents) { $failedAgents += $optionalAuthAgents }

    if ($failedAgents.Count -eq 0) {
    } else {
        $result = "| Agent Name | Issue | Auth Type | Auth Trigger | Status |`n"
        $result += "| --- | --- | --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $issue = if ($agent.UserAuthenticationType -eq "None") { "No authentication" } else { "Sign-in not required" }
            $result += "| $($agent.AIAgentName) | $issue | $($agent.UserAuthenticationType) | $($agent.AuthenticationTrigger) | $($agent.AgentStatus) |`n"
        }
    }

    return ($failedAgents.Count -eq 0)

}
