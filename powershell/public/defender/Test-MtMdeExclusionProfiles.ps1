<#
.SYNOPSIS
    Checks if exclusion profiles are configured in Microsoft Defender for Endpoint

.DESCRIPTION
    Exclusions are configured in dedicated profiles to reduce baseline complexity. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft Endpoint Manager.

.EXAMPLE
    Test-MtMdeExclusionProfiles

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeExclusionProfiles
#>

function Test-MtMdeExclusionProfiles {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Endpoint Security > Antivirus in the Microsoft Endpoint Manager (https://endpoint.microsoft.com)."
    return $null
}
