function Test-MtCisaSpoOneDriveSharing {
    <#
    .SYNOPSIS
    Checks state of OneDrive sharing

    .DESCRIPTION
    External sharing for OneDrive SHALL be limited to Existing guests or Only People in your organization.

    .EXAMPLE
    Test-MtCisaSpoOneDriveSharing

    Returns true if OneDrive sharing is restricted

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoOneDriveSharing
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection SharePoint)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSharePoint
        return $null
    }

    try {
        $spoTenant = Get-MtSpo

        # OneDriveSharingCapability: Disabled, ExistingExternalUserSharingOnly, ExternalUserSharingOnly, ExternalUserAndGuestSharing
        $testResult = $spoTenant.OneDriveSharingCapability -in @("Disabled", "ExistingExternalUserSharingOnly")

        if ($testResult) {
            $testResultMarkdown = "Well done. OneDrive sharing is restricted."
        } else {
            $testResultMarkdown = "OneDrive sharing is not restricted.`n`n* Current setting: ``$($spoTenant.OneDriveSharingCapability)``"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
