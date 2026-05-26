function Test-MtAIAgentHardCodedCredentialsCompliance {
    <#
    .SYNOPSIS
    Tests if AI agents have hard-coded credentials in topic definitions.

    .DESCRIPTION
    Scans all Copilot Studio agent topics for patterns that suggest hard-coded
    credentials, API keys, connection strings, or secrets. Hard-coded credentials
    in agent topics can be extracted by prompt injection attacks and often persist
    after key rotation is performed elsewhere.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAIAgentHardCodedCredentialsCompliance
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

    # Patterns that commonly indicate hard-coded credentials
    # Note: Patterns with key-value separators use "? to handle JSON-encoded data
    # where keys are quoted (e.g., "x-api-key":"value" instead of x-api-key: value)
    $credentialPatterns = @(
        @{ Name = 'API Key header';          Pattern = '(?i)(x-api-key|api[_-]?key|apikey)"?\s*[:=]\s*["\x27]?[A-Za-z0-9\-_\.]{16,}' }
        @{ Name = 'Bearer token';            Pattern = '(?i)bearer\s+[A-Za-z0-9\-_\.]{20,}' }
        @{ Name = 'Authorization header';    Pattern = '(?i)authorization"?\s*[:=]\s*["\x27]?(Basic|Bearer)\s+[A-Za-z0-9\+/=\-_\.]{16,}' }
        @{ Name = 'Connection string';       Pattern = '(?i)(Server|Data Source|AccountKey|SharedAccessKey)\s*=' }
        @{ Name = 'Secret/Password literal'; Pattern = '(?i)(password|secret|client_secret|clientsecret)"?\s*[:=]\s*["\x27]?[^\s"]{8,}' }
        @{ Name = 'AWS-style key';           Pattern = '(?i)(AKIA|ASIA)[A-Z0-9]{16}' }
        @{ Name = 'Private key block';       Pattern = '-----BEGIN (RSA |EC )?PRIVATE KEY-----' }
    )

    $failedAgents = @()

    foreach ($agent in $agents) {
        if ([string]::IsNullOrEmpty($agent.AgentTopicsDetails)) {
            continue
        }

        $topicsJson = $null
        try {
            if ($agent.AgentTopicsDetails -is [string]) {
                $topicsJson = $agent.AgentTopicsDetails
            } else {
                $topicsJson = $agent.AgentTopicsDetails | ConvertTo-Json -Depth 10 -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Verbose "Could not process AgentTopicsDetails for agent $($agent.AIAgentName): $_"
            continue
        }

        if ($null -eq $topicsJson) { continue }

        $matchedPatterns = @()
        foreach ($cred in $credentialPatterns) {
            if ($topicsJson -match $cred.Pattern) {
                $matchedPatterns += $cred.Name
            }
        }

        if ($matchedPatterns.Count -gt 0) {
            $failedAgents += [PSCustomObject]@{
                AIAgentName    = $agent.AIAgentName
                EnvironmentId  = $agent.EnvironmentId
                CredentialType = ($matchedPatterns | Select-Object -Unique) -join ', '
            }
        }
    }

    if ($failedAgents.Count -eq 0) {
    } else {
        $result = "| Agent Name | Environment | Credential Types Found |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.CredentialType) |`n"
        }
    }

    return ($failedAgents.Count -eq 0)

}
