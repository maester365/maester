<#
.SYNOPSIS
    Checks if Hide Duplicate Device Records is enabled in Microsoft Defender for Endpoint

.DESCRIPTION
    Hide Duplicate Device Records is enabled to reduce clutter. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeHideDuplicateDevices

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeHideDuplicateDevices
#>

function Test-MtMdeHideDuplicateDevices {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > Device Management in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
