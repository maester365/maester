function Test-MtPurviewAiAuditLogIngestion {
    <#
    .SYNOPSIS
    Ensure the Microsoft 365 unified audit log is enabled so Microsoft 365 Copilot and other AI app interactions are captured.

    .DESCRIPTION
    Checks the Microsoft 365 unified audit log ingestion state via Get-AdminAuditLogConfig.

    Microsoft 365 Copilot, Security Copilot, Copilot in Fabric, Copilot Studio and Entra-registered AI apps all
    flow user prompts and responses into the Microsoft Purview unified audit log. The DSPM for AI activity explorer,
    Insider Risk Management Risky AI policies, eDiscovery searches for Copilot activity, and Communication Compliance
    policies for Copilot interactions all depend on the unified audit log being enabled.

    Without unified audit log ingestion, Copilot prompts and responses are NOT captured, leaving organisations with no
    forensic record of how generative AI is being used and breaking every downstream Purview AI control.

    The test passes if the tenant returns UnifiedAuditLogIngestionEnabled = True.

    .EXAMPLE
    Test-MtPurviewAiAuditLogIngestion

    Returns true if the unified audit log is enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtPurviewAiAuditLogIngestion
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        $config = Get-AdminAuditLogConfig -ErrorAction Stop
        $enabled = [bool]$config.UnifiedAuditLogIngestionEnabled

        $portalLink = "https://purview.microsoft.com/audit/auditsearch"

        if ($enabled) {
            $testResultMarkdown = "Well done. Your tenant has [unified audit log ingestion enabled]($portalLink), "
            $testResultMarkdown += "so Microsoft 365 Copilot and other AI app prompts/responses are captured for "
            $testResultMarkdown += "DSPM for AI, Insider Risk Management, eDiscovery and Communication Compliance."
        } else {
            $testResultMarkdown = "Your tenant does **not** have [unified audit log ingestion enabled]($portalLink).`n`n"
            $testResultMarkdown += "> **Risk:** Without the unified audit log, Microsoft 365 Copilot prompts and responses are not captured. "
            $testResultMarkdown += "DSPM for AI activity explorer, the Risky AI usage Insider Risk template, Copilot eDiscovery searches, "
            $testResultMarkdown += "and Communication Compliance for Copilot will all be empty or non-functional."
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $enabled
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }
        return $null
    }
}
