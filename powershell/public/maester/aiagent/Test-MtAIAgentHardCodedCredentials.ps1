<#
.SYNOPSIS
    Tests if AI agents have hard-coded credentials in topic definitions.

.DESCRIPTION
    Scans all Copilot Studio agent topics for patterns that suggest hard-coded
    credentials, API keys, connection strings, or secrets. Hard-coded credentials
    in agent topics can be extracted by prompt injection attacks and often persist
    after key rotation is performed elsewhere.

.OUTPUTS
    [bool] - Returns $true if no hard-coded credentials are found, $false if any
    agent topics contain credential patterns, $null if data is unavailable.

.EXAMPLE
    Test-MtAIAgentHardCodedCredentials

.LINK
    https://maester.dev/docs/commands/Test-MtAIAgentHardCodedCredentials
#>

function Test-MtAIAgentHardCodedCredentials {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $agents = Get-MtAIAgentInfo
    if ($null -eq $agents) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No Copilot Studio agent data available. Ensure DataverseEnvironmentUrl is configured in maester-config.json and Connect-Maester -Service Dataverse has been run. See https://maester.dev/docs/tests/MT.1119 for prerequisites.'
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
        $testResultMarkdown = "Well done. No AI agents have hard-coded credentials in topic definitions."
    } else {
        $testResultMarkdown = "Found $($failedAgents.Count) AI agent(s) with potential hard-coded credentials in topics.`n`n%TestResult%"
        $result = "| Agent Name | Environment | Credential Types Found |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($agent in $failedAgents) {
            $result += "| $($agent.AIAgentName) | $($agent.EnvironmentId) | $($agent.CredentialType) |`n"
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity "High"
    return ($failedAgents.Count -eq 0)
}
