<#
.SYNOPSIS
    Checks if Authenticated Telemetry is configured in Microsoft Defender for Endpoint

.DESCRIPTION
    Authenticated Telemetry settings comply with privacy requirements. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeAuthenticatedTelemetry

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeAuthenticatedTelemetry
#>

function Test-MtMdeAuthenticatedTelemetry {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > General in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
