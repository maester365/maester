<#
.SYNOPSIS
    Checks if Allow or Block File capability is enabled for IOC handling in Microsoft Defender for Endpoint

.DESCRIPTION
    Allow or Block File capability is enabled for IOC handling. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeAllowBlockFile

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeAllowBlockFile
#>

function Test-MtMdeAllowBlockFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > Allow or Block File in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
