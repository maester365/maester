function Test-MtAIAgentOrphanedCompliance {
    <#
    .SYNOPSIS
    Tests if AI agents are orphaned.

    .DESCRIPTION
    Checks all Copilot Studio agents for those whose owner accounts no longer
    exist or are disabled in Entra ID. Orphaned agents lack active governance
    and may drift from security policies without anyone responsible for
    maintaining them.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAIAgentOrphanedCompliance
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
        if ([string]::IsNullOrEmpty($agent.OwnerAccountUpns)) {
            $failedAgents += $agent | Select-Object *, @{N='OrphanReason';E={'No owner assigned'}}
            continue
        }

        # Check each owner UPN against Entra ID
        $ownerUpns = @($agent.OwnerAccountUpns -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        $allOwnersInvalid = $true

        foreach ($upn in $ownerUpns) {
            try {
                $user = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users/$upn' -Select 'id,accountEnabled' -ApiVersion 'v1.0'
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
    } else {
        $result = "| Agent Name | Environment | Owner UPNs | Reason |`n"
        $result += "| --- | --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $owners = if ($agent.OwnerAccountUpns) { $agent.OwnerAccountUpns } else { "None" }
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $owners | $($agent.OrphanReason) |`n"
        }
    }

    return ($failedAgents.Count -eq 0)

}
