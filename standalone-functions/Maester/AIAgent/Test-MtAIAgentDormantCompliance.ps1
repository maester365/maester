function Test-MtAIAgentDormantCompliance {
    <#
    .SYNOPSIS
    Tests if AI agents are dormant.

    .DESCRIPTION
    Checks all published Copilot Studio agents for those that have not been
    modified or republished within 180 days.
    Dormant agents may have outdated configurations, unpatched vulnerabilities,
    or stale permissions that present unnecessary risk.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAIAgentDormantCompliance
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

    Write-Verbose "Checking $($agents.Count) agent(s) for dormant status"

    $thresholdDays = 180
    $threshold = (Get-Date).AddDays(-$thresholdDays)

    $failedAgents = $agents | Where-Object {
        $_.AgentStatus -eq "Published" -and
        $null -ne $_.LastModifiedTime -and
        [datetime]$_.LastModifiedTime -lt $threshold
    }

    if ($failedAgents.Count -eq 0) {
    } else {
        $result = "| Agent Name | Environment | Last Modified | Last Published |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $lastModified = if ($agent.LastModifiedTime) { ([datetime]$agent.LastModifiedTime).ToString("yyyy-MM-dd") } else { "Unknown" }
            $lastPublished = if ($agent.LastPublishedTime) { ([datetime]$agent.LastPublishedTime).ToString("yyyy-MM-dd") } else { "Unknown" }
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $lastModified | $lastPublished |`n"
        }
    }

    return $failedAgents.Count -eq 0

}
