<#
.SYNOPSIS
    Checks if Isolation Exclusion Rules are configured in Microsoft Defender for Endpoint

.DESCRIPTION
    Isolation Exclusion Rules are disabled unless specifically required. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeIsolationExclusions

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeIsolationExclusions
#>

function Test-MtMdeIsolationExclusions {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > General in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
