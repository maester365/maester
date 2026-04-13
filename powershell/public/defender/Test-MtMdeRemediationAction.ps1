<#
.SYNOPSIS
    Checks if remediation action for all threat levels is set to Quarantine in Microsoft Defender for Endpoint

.DESCRIPTION
    Remediation action for all threat levels is set to Quarantine for consistent threat handling. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft Endpoint Manager.

.EXAMPLE
    Test-MtMdeRemediationAction

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeRemediationAction
#>

function Test-MtMdeRemediationAction {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Endpoint Security > Antivirus > Threat Severity Default Action in the Microsoft Endpoint Manager (https://endpoint.microsoft.com)."
    return $null
}
