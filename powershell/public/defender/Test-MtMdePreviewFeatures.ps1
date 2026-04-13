<#
.SYNOPSIS
    Checks if Preview Features are enabled organization-wide in Microsoft Defender XDR

.DESCRIPTION
    Preview Features are enabled organization-wide in Microsoft Defender XDR. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdePreviewFeatures

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdePreviewFeatures
#>

function Test-MtMdePreviewFeatures {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Microsoft Defender XDR > Preview Features in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
