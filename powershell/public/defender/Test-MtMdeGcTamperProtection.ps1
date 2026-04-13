<#
.SYNOPSIS
    Checks if Tamper Protection is enabled tenant-wide in Advanced Features

.DESCRIPTION
    Tamper Protection is enabled tenant-wide in Advanced Features. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeGcTamperProtection

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeGcTamperProtection
#>

function Test-MtMdeGcTamperProtection {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > Tamper Protection in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
