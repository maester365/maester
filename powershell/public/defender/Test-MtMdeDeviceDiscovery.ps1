<#
.SYNOPSIS
    Checks if Device Discovery is configured in Microsoft Defender for Endpoint

.DESCRIPTION
    Device Discovery is enabled for Shadow IT visibility. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeDeviceDiscovery

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeDeviceDiscovery
#>

function Test-MtMdeDeviceDiscovery {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > Device Discovery in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
