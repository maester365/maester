<#
.SYNOPSIS
    Checks if Tamper Protection is enabled tenant-wide in Microsoft Defender for Endpoint

.DESCRIPTION
    Tamper Protection is enabled tenant-wide to prevent local administrators from disabling security features. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeTamperProtection

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeTamperProtection
#>

function Test-MtMdeTamperProtection {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > Tamper Protection in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
