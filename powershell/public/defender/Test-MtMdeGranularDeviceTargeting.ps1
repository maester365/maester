<#
.SYNOPSIS
    Checks if granular device targeting is configured in Microsoft Defender for Endpoint

.DESCRIPTION
    Device profiles are granular and follow least privilege principle. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft Endpoint Manager.

.EXAMPLE
    Test-MtMdeGranularDeviceTargeting

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeGranularDeviceTargeting
#>

function Test-MtMdeGranularDeviceTargeting {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Groups > Device Groups in the Microsoft Endpoint Manager (https://endpoint.microsoft.com)."
    return $null
}
