function Test-MtPurviewAiRetentionPolicy {
    <#
    .SYNOPSIS
    Ensure a Microsoft Purview retention policy is configured for Microsoft 365 Copilot interactions.

    .DESCRIPTION
    Microsoft Purview retention exposes a **Microsoft Copilot** location that retains or disposes of user prompts
    and AI-generated responses (Copilot interactions) according to a defined schedule. Without a retention policy
    on the Copilot location, organisations cannot satisfy regulatory obligations for AI interaction retention,
    cannot defensibly dispose of stale Copilot transcripts, and may have gaps in eDiscovery or legal hold workflows.

    The test passes if at least one enabled Microsoft Purview retention policy targets the Microsoft Copilot location.

    .EXAMPLE
    Test-MtPurviewAiRetentionPolicy

    Returns true if a retention policy is configured for the Microsoft Copilot location.

    .LINK
    https://maester.dev/docs/commands/Test-MtPurviewAiRetentionPolicy
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }

    try {
        $policies = Get-RetentionCompliancePolicy -ErrorAction Stop
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    # Match policies that target the Microsoft Copilot location.
    # Schema fields vary by tenant version: MicrosoftCopilotLocation (multivalued) and / or Workload contains 'MicrosoftCopilot'.
    $copilotPolicies = @($policies | Where-Object {
            ($_.MicrosoftCopilotLocation -and ($_.MicrosoftCopilotLocation.DisplayName -or $_.MicrosoftCopilotLocation.Count -gt 0)) -or
            ($_.Workload -match 'Copilot')
        })

    $enabledCopilotPolicies = @($copilotPolicies | Where-Object { $_.Enabled -eq $true })

    $testResult = $enabledCopilotPolicies.Count -ge 1

    $portalLink = "https://purview.microsoft.com/datalifecyclemanagement/policies"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has at least one enabled [Microsoft Purview retention policy]($portalLink) "
        $testResultMarkdown += "targeting the Microsoft Copilot location.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have an enabled [Microsoft Purview retention policy]($portalLink) "
        $testResultMarkdown += "targeting the Microsoft Copilot location.`n`n"
        $testResultMarkdown += "> **Risk:** Copilot prompts and responses are not governed by a retention schedule, so the organisation "
        $testResultMarkdown += "cannot satisfy regulatory obligations for AI interaction retention, cannot defensibly dispose of stale "
        $testResultMarkdown += "Copilot transcripts, and may have gaps in eDiscovery or legal hold workflows for AI activity.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Name | Status | Enabled | Mode |`n"
    $result += "| --- | --- | --- | --- |`n"
    if ($copilotPolicies.Count -eq 0) {
        $result += "| _No retention policies target the Microsoft Copilot location_ | $failResult | - | - |`n"
    } else {
        foreach ($item in ($copilotPolicies | Sort-Object -Property Name)) {
            $itemResult = if ($item.Enabled) { $passResult } else { $failResult }
            $result += "| $($item.Name) | $itemResult | $($item.Enabled) | $($item.Mode) |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
