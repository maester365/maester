<#
.SYNOPSIS
    Checks if EDR in Block Mode is enabled for Microsoft Defender Antivirus devices

.DESCRIPTION
    EDR in Block Mode is enabled for Microsoft Defender Antivirus devices. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeEdrBlockMode

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeEdrBlockMode
#>

function Test-MtMdeEdrBlockMode {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > EDR in Block Mode in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
