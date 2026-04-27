function Test-MtPurviewAiDlpPolicy {
    <#
    .SYNOPSIS
    Ensure a Microsoft Purview DLP policy is configured for the Microsoft 365 Copilot location.

    .DESCRIPTION
    Microsoft Purview Data Loss Prevention exposes a **Microsoft 365 Copilot** location that lets administrators
    block Copilot from summarising or surfacing files containing sensitive information types (SITs) or labelled content.

    Without a DLP policy targeting the Copilot location, Microsoft 365 Copilot can summarise, paraphrase or expose
    sensitive content (PII, secrets, financial data, regulated data) from any file the requesting user can already
    access — accelerating oversharing risk for AI-assisted workflows.

    The test passes if at least one enabled, non-simulation DLP policy targets the Microsoft 365 Copilot location.

    .EXAMPLE
    Test-MtPurviewAiDlpPolicy

    Returns true if a DLP policy is configured for the Microsoft 365 Copilot location.

    .LINK
    https://maester.dev/docs/commands/Test-MtPurviewAiDlpPolicy
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    } elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    } elseif ($null -eq (Get-MtLicenseInformation -Product ExoDlp)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedExoDlp
        return $null
    }

    try {
        $policies = Get-MtExo -Request DlpCompliancePolicy
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    # Match policies that target the Microsoft 365 Copilot location.
    # Schema fields: MicrosoftCopilotLocation (multivalued; 'All' or specific scopes), Workload (may include 'MicrosoftCopilot').
    $copilotPolicies = @($policies | Where-Object {
            ($_.MicrosoftCopilotLocation -and ($_.MicrosoftCopilotLocation.DisplayName -or $_.MicrosoftCopilotLocation.Count -gt 0)) -or
            ($_.Workload -match 'Copilot')
        })

    $enabledCopilotPolicies = @($copilotPolicies | Where-Object {
            $_.Enabled -and -not $_.IsSimulationPolicy
        })

    $testResult = $enabledCopilotPolicies.Count -ge 1

    $portalLink = "https://purview.microsoft.com/datalossprevention/policies"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has at least one enabled [Microsoft Purview DLP policy]($portalLink) "
        $testResultMarkdown += "targeting the Microsoft 365 Copilot location.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have an enabled [Microsoft Purview DLP policy]($portalLink) "
        $testResultMarkdown += "targeting the Microsoft 365 Copilot location.`n`n"
        $testResultMarkdown += "> **Risk:** Microsoft 365 Copilot can summarise, paraphrase or expose files containing sensitive "
        $testResultMarkdown += "information types or labelled content from any source the requesting user can access, dramatically "
        $testResultMarkdown += "amplifying oversharing risk through AI-assisted workflows.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Name | Status | Mode | Enabled |`n"
    $result += "| --- | --- | --- | --- |`n"
    if ($copilotPolicies.Count -eq 0) {
        $result += "| _No DLP policies target the Microsoft 365 Copilot location_ | $failResult | - | - |`n"
    } else {
        foreach ($item in ($copilotPolicies | Sort-Object -Property Name)) {
            $itemResult = if ($item.Enabled -and -not $item.IsSimulationPolicy) { $passResult } else { $failResult }
            $mode = if ($item.IsSimulationPolicy) { "Simulation" } else { $item.Mode }
            $result += "| $($item.Name) | $itemResult | $mode | $($item.Enabled) |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
