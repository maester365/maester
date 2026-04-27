function Test-MtPurviewAiInsiderRiskPolicy {
    <#
    .SYNOPSIS
    Ensure a Microsoft Purview Insider Risk Management policy from the Risky AI usage template is configured and enabled.

    .DESCRIPTION
    Microsoft Purview Insider Risk Management ships a dedicated **Risky AI usage** policy template that detects
    risky prompts and responses inside Microsoft 365 Copilot and other AI apps captured by DSPM for AI — for example
    prompts attempting jailbreaks, harmful content generation, or extraction of sensitive information.

    Without a Risky AI usage policy enabled, alerts on risky Copilot/AI app interactions are not generated and
    Insider Risk reviewers have no triage queue for AI misuse.

    The test passes if at least one Insider Risk Management policy based on the Risky AI usage template is enabled.

    Requires Microsoft 365 E5 or the Insider Risk Management add-on.

    .EXAMPLE
    Test-MtPurviewAiInsiderRiskPolicy

    Returns true if a Risky AI usage Insider Risk policy is enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtPurviewAiInsiderRiskPolicy
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }

    try {
        $policies = Get-InsiderRiskPolicy -ErrorAction Stop
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            # IRM cmdlets are unavailable when the tenant is not licensed for Insider Risk Management.
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Get-InsiderRiskPolicy is unavailable. Microsoft 365 E5 or the Insider Risk Management add-on is required."
        }
        return $null
    }

    # The Risky AI usage template surfaces as an InsiderRiskScenario value such as 'RiskyAIUsage'.
    # Match permissively on policy name or scenario to handle SKU/template renames over time.
    $aiPolicies = @($policies | Where-Object {
            $_.InsiderRiskScenario -match 'AI' -or
            $_.Name -match 'Risky\s*AI' -or
            $_.Name -match 'AI\s*Usage' -or
            $_.PolicyTemplate -match 'AI'
        })

    $enabledAiPolicies = @($aiPolicies | Where-Object { $_.Enabled -eq $true })
    $testResult = $enabledAiPolicies.Count -ge 1

    $portalLink = "https://purview.microsoft.com/insiderriskmgmt/policies"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has at least one [Insider Risk Management policy]($portalLink) "
        $testResultMarkdown += "based on the Risky AI usage template enabled.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have an enabled [Insider Risk Management policy]($portalLink) "
        $testResultMarkdown += "based on the Risky AI usage template.`n`n"
        $testResultMarkdown += "> **Risk:** Risky prompts and responses inside Microsoft 365 Copilot and other AI apps will not "
        $testResultMarkdown += "generate Insider Risk alerts, and reviewers will have no triage queue for AI misuse.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Name | Status | Scenario | Enabled |`n"
    $result += "| --- | --- | --- | --- |`n"
    if ($aiPolicies.Count -eq 0) {
        $result += "| _No Risky AI usage policies found_ | $failResult | - | - |`n"
    } else {
        foreach ($item in ($aiPolicies | Sort-Object -Property Name)) {
            $itemResult = if ($item.Enabled) { $passResult } else { $failResult }
            $result += "| $($item.Name) | $itemResult | $($item.InsiderRiskScenario) | $($item.Enabled) |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
