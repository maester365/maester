<#
.SYNOPSIS
    Tests if AI agents require user authentication.

.DESCRIPTION
    Checks all Copilot Studio agents for weak or missing authentication.
    Flags agents with no authentication configured, as well as agents where
    authentication is configured but 'Require users to sign in' is not enabled
    (trigger set to 'As Needed' instead of 'Always').

.OUTPUTS
    [bool] - Returns $true if all agents require authentication with sign-in enforced,
    $false if any agent has weak or missing authentication, $null if data is unavailable.

.EXAMPLE
    Test-MtAIAgentNoAuthentication

.LINK
    https://maester.dev/docs/commands/Test-MtAIAgentNoAuthentication
#>

function Test-MtAIAgentNoAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No AI agent data available. Ensure DataverseEnvironmentUrl is configured in maester-config.json and Connect-Maester -Service Dataverse has been run. See https://maester.dev/docs/tests/MT.1114 for prerequisites.'
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
        $testResultMarkdown = "Well done. All AI agents require user authentication with sign-in enforced."
    } else {
        $testResultMarkdown = "Found $($failedAgents.Count) AI agent(s) with missing or weak authentication.`n`n%TestResult%"
        $result = "| Agent Name | Issue | Auth Type | Auth Trigger | Status |`n"
        $result += "| --- | --- | --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $issue = if ($agent.UserAuthenticationType -eq "None") { "No authentication" } else { "Sign-in not required" }
            $result += "| $($agent.AIAgentName) | $issue | $($agent.UserAuthenticationType) | $($agent.AuthenticationTrigger) | $($agent.AgentStatus) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity "High"
    return ($failedAgents.Count -eq 0)
}
