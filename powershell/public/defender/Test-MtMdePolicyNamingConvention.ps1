<#
.SYNOPSIS
    Checks if consistent policy naming convention is configured in Microsoft Defender for Endpoint

.DESCRIPTION
    Consistent policy naming convention across all MDE policies. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft Endpoint Manager.

.EXAMPLE
    Test-MtMdePolicyNamingConvention

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdePolicyNamingConvention
#>

function Test-MtMdePolicyNamingConvention {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Endpoint Security > Antivirus in the Microsoft Endpoint Manager (https://endpoint.microsoft.com)."
    return $null
}
