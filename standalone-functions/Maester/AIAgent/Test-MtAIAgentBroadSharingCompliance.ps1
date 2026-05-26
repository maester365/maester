function Test-MtAIAgentBroadSharingCompliance {
    <#
    .SYNOPSIS
    Tests if AI agents are shared too broadly.

    .DESCRIPTION
    Checks all Copilot Studio agents for those with access control set to "Any" or
    "Any multitenant", which allows any user (or users across tenants) to interact
    with the agent.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAIAgentBroadSharingCompliance
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

    Write-Verbose "Checking $($agents.Count) agent(s) for broad sharing configuration"

    $failedAgents = $agents | Where-Object { $_.AccessControlPolicy -eq "Any" -or $_.AccessControlPolicy -eq "Any multitenant" }

    if ($failedAgents.Count -eq 0) {
    } else {
        $result = "| Agent Name | Environment | Access Control | Authentication |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.AccessControlPolicy) | $($agent.UserAuthenticationType) |`n"
        }
    }

    return $failedAgents.Count -eq 0

}
