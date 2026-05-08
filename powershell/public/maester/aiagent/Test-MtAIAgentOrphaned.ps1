<#
.SYNOPSIS
    Tests if AI agents are orphaned.

.DESCRIPTION
    Checks all Copilot Studio agents for those whose owner accounts no longer
    exist or are disabled in Entra ID. Orphaned agents lack active governance
    and may drift from security policies without anyone responsible for
    maintaining them.

.OUTPUTS
    [bool] - Returns $true if all agents have active owners, $false if any
    agent has disabled or missing owners, $null if data is unavailable.

.EXAMPLE
    Test-MtAIAgentOrphaned

.LINK
    https://maester.dev/docs/commands/Test-MtAIAgentOrphaned
#>

function Test-MtAIAgentOrphaned {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No Copilot Studio agent data available. Ensure DataverseEnvironmentUrl is configured in maester-config.json and Connect-Maester -Service Dataverse has been run. See https://maester.dev/docs/tests/MT.1122 for prerequisites.'
        return $null
    }

    $failedAgents = @()

    foreach ($agent in $agents) {
        if ([string]::IsNullOrEmpty($agent.OwnerAccountUpns)) {
            $failedAgents += $agent | Select-Object *, @{N='OrphanReason';E={'No owner assigned'}}
            continue
        }

        # Check each owner UPN against Entra ID
        $ownerUpns = @($agent.OwnerAccountUpns -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        $allOwnersInvalid = $true

        foreach ($upn in $ownerUpns) {
            try {
                $user = Invoke-MtGraphRequest -RelativeUri "users/$upn" -Select 'id,accountEnabled' -ApiVersion 'v1.0'
                if ($user -and $user.accountEnabled -eq $true) {
                    $allOwnersInvalid = $false
                    break
                }
            } catch {
                # User not found or access denied - treat as invalid
                Write-Verbose "Could not resolve owner $upn for agent $($agent.AIAgentName): $_"
            }
        }

        if ($allOwnersInvalid) {
            $reason = if ([string]::IsNullOrEmpty($ownerUpns)) { "No owner assigned" } else { "All owners disabled or not found" }
            $failedAgents += $agent | Select-Object *, @{N='OrphanReason';E={$reason}}
        }
    }

    if ($failedAgents.Count -eq 0) {
        $testResultMarkdown = "Well done. All AI agents have active owners."
    } else {
        $testResultMarkdown = "Found $($failedAgents.Count) AI agent(s) with no active owner.`n`n%TestResult%"
        $result = "| Agent Name | Environment | Owner UPNs | Reason |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $owners = if ($agent.OwnerAccountUpns) { $agent.OwnerAccountUpns } else { "None" }
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $owners | $($agent.OrphanReason) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity "Medium"
    return ($failedAgents.Count -eq 0)
}
