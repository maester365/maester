function Test-MtPurviewAiRetentionPolicy {
    <#
    .SYNOPSIS
    Ensure a Microsoft Purview retention policy is configured for Microsoft 365 Copilot interactions.

    .DESCRIPTION
    Microsoft Purview retention exposes Copilot interaction retention through two surfaces:
    the legacy retention surface (`Get-RetentionCompliancePolicy`, historically used for the
    "Teams chats and Copilot interactions" location) and the newer app-retention surface
    (`Get-AppRetentionCompliancePolicy`) used for Microsoft Copilot experiences such as
    Microsoft 365 Copilot, Security Copilot, Copilot Studio, and Copilot in Fabric, with
    application identifiers such as `User:M365Copilot`.

    Without a retention policy on either surface, organisations cannot satisfy regulatory
    obligations for AI interaction retention, cannot defensibly dispose of stale Copilot
    transcripts, and may have gaps in eDiscovery or legal hold workflows.

    The test passes if at least one enabled Microsoft Purview retention policy targets
    Microsoft Copilot interactions on EITHER the legacy retention surface or the
    app-retention surface.

    .EXAMPLE
    Test-MtPurviewAiRetentionPolicy

    Returns true if a retention policy is configured for the Microsoft Copilot location.

    .LINK
    https://maester.dev/docs/commands/Test-MtPurviewAiRetentionPolicy
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-MtPurviewAiRetentionPolicy: Checking for Microsoft Purview retention policies targeting Microsoft Copilot interactions."

    if (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }

    # Microsoft Purview now exposes Copilot retention through two surfaces:
    #   - Get-RetentionCompliancePolicy        : legacy/general retention surface (Exchange/SharePoint/Teams + Copilot via the
    #                                            older 'Teams chats and Copilot interactions' location)
    #   - Get-AppRetentionCompliancePolicy     : newer app-retention surface used by Microsoft Copilot experiences
    #                                            (M365 Copilot, Security Copilot, Copilot Studio, etc.) with application
    #                                            identifiers such as 'User:M365Copilot'.
    # Tenants may have configured Copilot retention through either surface. The pass condition succeeds when EITHER
    # surface contains an enabled policy targeting Microsoft Copilot interactions.
    try {
        $legacyPolicies = @(Get-MtExo -Request RetentionCompliancePolicy)
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }

    # The app-retention cmdlet may be unavailable on older tenants / unlicensed environments.
    # Treat a missing cmdlet as "no app-retention surface" rather than a hard error.
    $appPolicies = @()
    try {
        $appPolicies = @(Get-MtExo -Request AppRetentionCompliancePolicy)
    } catch {
        $exception = $_.Exception
        $errorId = $_.FullyQualifiedErrorId
        $message = $exception.Message
        if ($exception -is [System.Management.Automation.CommandNotFoundException] -or
            $errorId -match 'CommandNotFoundException' -or
            $message -match "The term 'Get-AppRetentionCompliancePolicy' is not recognized" -or
            $message -match 'Get-AppRetentionCompliancePolicy.*(is unavailable|not available|was not found)') {
            Write-Verbose "Get-AppRetentionCompliancePolicy is not available in this session/tenant; falling back to Get-RetentionCompliancePolicy only."
        } elseif ($exception.Response -and $exception.Response.StatusCode -in @(401, 403)) {
            # Authorization failure on the app-retention surface alone shouldn't fail the whole test —
            # we still have legacy results to evaluate.
            Write-Verbose "Not authorized to query Get-AppRetentionCompliancePolicy; continuing with legacy retention policies only."
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
            return $null
        }
    }

    # Match legacy retention policies that target the Microsoft Copilot location.
    # Schema fields vary by tenant version: MicrosoftCopilotLocation (multivalued) and / or Workload contains 'MicrosoftCopilot'.
    $copilotLegacyPolicies = @($legacyPolicies | Where-Object {
            ($_.MicrosoftCopilotLocation -and ($_.MicrosoftCopilotLocation.DisplayName -or $_.MicrosoftCopilotLocation.Count -gt 0)) -or
            ($_.Workload -match 'Copilot')
        })

    # Match app-retention policies that target Microsoft Copilot experiences.
    # The app-retention surface uses Applications (e.g. 'User:M365Copilot') and Locations,
    # and Workload may also surface a Copilot value.
    $copilotAppPolicies = @($appPolicies | Where-Object {
            ($_.Workload -match 'Copilot') -or
            ($_.Applications -and (@($_.Applications) | Where-Object { "$_" -match 'M365Copilot|Copilot' })) -or
            ($_.Locations -and (@($_.Locations) | Where-Object {
                ($_ -is [string] -and $_ -match 'Copilot') -or
                ($_.Workload -match 'Copilot') -or
                ($_.Name -match 'Copilot') -or
                ($_.DisplayName -match 'Copilot')
            }))
        })

    # Tag each policy with its source surface so the markdown table can show provenance.
    $taggedLegacy = @($copilotLegacyPolicies | ForEach-Object {
            [pscustomobject]@{
                Name    = $_.Name
                Enabled = $_.Enabled
                Mode    = $_.Mode
                Surface = 'Legacy'
            }
        })
    $taggedApp = @($copilotAppPolicies | ForEach-Object {
            [pscustomobject]@{
                Name    = $_.Name
                Enabled = $_.Enabled
                Mode    = $_.Mode
                Surface = 'App'
            }
        })
    $copilotPolicies = @($taggedLegacy + $taggedApp)

    $enabledCopilotPolicies = @($copilotPolicies | Where-Object { $_.Enabled -eq $true })

    $testResult = $enabledCopilotPolicies.Count -ge 1

    $portalLink = "https://purview.microsoft.com/datalifecyclemanagement/policies"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has at least one enabled [Microsoft Purview retention policy]($portalLink) "
        $testResultMarkdown += "targeting Microsoft Copilot interactions (legacy retention or app-retention surface).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have an enabled [Microsoft Purview retention policy]($portalLink) "
        $testResultMarkdown += "targeting Microsoft Copilot interactions on either the legacy retention or app-retention surface.`n`n"
        $testResultMarkdown += "> **Risk:** Copilot prompts and responses are not governed by a retention schedule, so the organisation "
        $testResultMarkdown += "cannot satisfy regulatory obligations for AI interaction retention, cannot defensibly dispose of stale "
        $testResultMarkdown += "Copilot transcripts, and may have gaps in eDiscovery or legal hold workflows for AI activity.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Name | Surface | Status | Enabled | Mode |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    if ($copilotPolicies.Count -eq 0) {
        $result += "| _No retention policies target Microsoft Copilot interactions_ | - | $failResult | - | - |`n"
    } else {
        foreach ($item in ($copilotPolicies | Sort-Object -Property Surface, Name)) {
            $itemResult = if ($item.Enabled) { $passResult } else { $failResult }
            $result += "| $($item.Name) | $($item.Surface) | $itemResult | $($item.Enabled) | $($item.Mode) |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
