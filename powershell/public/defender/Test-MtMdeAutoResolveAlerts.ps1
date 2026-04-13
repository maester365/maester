<#
.SYNOPSIS
    Checks if Automatically Resolve Alerts is properly configured in Microsoft Defender for Endpoint

.DESCRIPTION
    Automatically Resolve Alerts is properly configured. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeAutoResolveAlerts

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeAutoResolveAlerts
#>

function Test-MtMdeAutoResolveAlerts {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > Auto-resolution in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
