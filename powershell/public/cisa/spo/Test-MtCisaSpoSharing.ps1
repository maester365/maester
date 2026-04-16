function Test-MtCisaSpoSharing {
    <#
    .SYNOPSIS
    Checks state of SharePoint Online sharing

    .DESCRIPTION
    External sharing for SharePoint SHALL be limited to Existing guests or Only People in your organization.

    .EXAMPLE
    Test-MtCisaSpoSharing

    Returns true if sharing is restricted

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoSharing
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

        $testResult = $spoTenant.SharingCapability -in @("Disabled", "ExistingExternalUserSharingOnly")

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant restricts SharePoint Online sharing."
        } else {
            $testResultMarkdown = "Your tenant does not restrict SharePoint Online sharing.`n`n* Current setting: ``$($spoTenant.SharingCapability)``"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
