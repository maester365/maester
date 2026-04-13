<#
.SYNOPSIS
    Checks if Streamlined Connectivity for Intune/DFC is configured in Microsoft Defender for Endpoint

.DESCRIPTION
    Streamlined Connectivity is applied to Intune/DFC for synchronization. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeStreamlinedConnectivityIntune

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeStreamlinedConnectivityIntune
#>

function Test-MtMdeStreamlinedConnectivityIntune {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > General in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
