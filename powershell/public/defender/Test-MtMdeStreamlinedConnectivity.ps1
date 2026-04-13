<#
.SYNOPSIS
    Checks if Streamlined Connectivity is configured in Microsoft Defender for Endpoint

.DESCRIPTION
    Streamlined Connectivity is enabled as default configuration. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeStreamlinedConnectivity

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeStreamlinedConnectivity
#>

function Test-MtMdeStreamlinedConnectivity {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > General in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
