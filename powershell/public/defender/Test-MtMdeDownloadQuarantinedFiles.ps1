<#
.SYNOPSIS
    Checks if Download Quarantined Files is configured in Microsoft Defender for Endpoint

.DESCRIPTION
    Download Quarantined Files capability is enabled for forensic analysis. This setting is not available via Microsoft Graph API
    and requires manual verification in the Microsoft 365 Defender Portal.

.EXAMPLE
    Test-MtMdeDownloadQuarantinedFiles

    This test always returns $null as it requires manual verification.

.LINK
    https://maester.dev/docs/commands/Test-MtMdeDownloadQuarantinedFiles
#>

function Test-MtMdeDownloadQuarantinedFiles {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This setting requires manual verification. Navigate to Settings > Endpoints > Advanced Features > General in the Microsoft 365 Defender Portal (https://security.microsoft.com)."
    return $null
}
