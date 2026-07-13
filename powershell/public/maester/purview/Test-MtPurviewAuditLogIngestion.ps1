function Test-MtPurviewAuditLogIngestion {
    <#
    .SYNOPSIS
    Ensure the Microsoft 365 unified audit log is enabled so tenant activity is captured for Microsoft Purview and downstream compliance controls.

    .DESCRIPTION
    Checks the Microsoft 365 unified audit log ingestion state via Get-AdminAuditLogConfig.

    The Microsoft Purview unified audit log is the tenant-wide record of user, admin and service activity across Exchange,
    SharePoint, OneDrive, Teams, Entra ID, Microsoft 365 Copilot and many other workloads. It is the foundation for
    Microsoft Purview Audit, eDiscovery, Insider Risk Management, Communication Compliance, DSPM for AI activity
    explorer, and effectively every Purview investigation or reporting surface.

    Without unified audit log ingestion, tenant activity is NOT captured, leaving organisations with no forensic record
    for audit, incident response, eDiscovery, or compliance investigations — including but not limited to Microsoft 365
    Copilot prompt/response activity.

    The test passes if the tenant returns UnifiedAuditLogIngestionEnabled = True.

    .EXAMPLE
    Test-MtPurviewAuditLogIngestion

    Returns true if the unified audit log is enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtPurviewAuditLogIngestion
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Test-MtPurviewAuditLogIngestion: Checking if the Microsoft 365 unified audit log is enabled."

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
            $testResultMarkdown += "so tenant activity across Exchange, SharePoint, OneDrive, Teams, Entra ID, Microsoft 365 Copilot "
            $testResultMarkdown += "and other workloads is captured for Microsoft Purview Audit, eDiscovery, Insider Risk Management, "
            $testResultMarkdown += "Communication Compliance and DSPM for AI."
        } else {
            $testResultMarkdown = "Your tenant does **not** have [unified audit log ingestion enabled]($portalLink).`n`n"
            $testResultMarkdown += "> **Risk:** Without the unified audit log, tenant activity is not captured. Microsoft Purview Audit, "
            $testResultMarkdown += "eDiscovery searches, Insider Risk Management alerts, Communication Compliance policies, and DSPM for AI "
            $testResultMarkdown += "activity explorer will all be empty or non-functional."
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
