function Test-MtCisaSpoDefaultSharingScope {
    <#
    .SYNOPSIS
    Checks state of default SharePoint Online sharing scope

    .DESCRIPTION
    Default sharing scope SHOULD be set to Specific People (Only the people the user specifies).

    .EXAMPLE
    Test-MtCisaSpoDefaultSharingScope

    Returns true if default sharing scope is restricted to specific people

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoDefaultSharingScope
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

        # DefaultSharingLinkType: None = default (not explicitly set), Direct = Specific People, Internal = Organization, AnonymousAccess = Anyone
        $testResult = $spoTenant.DefaultSharingLinkType -eq "Direct"

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant default sharing scope is set to Specific People."
        } else {
            $testResultMarkdown = "Your tenant default sharing scope is not set to Specific People.`n`n* Current setting: ``$($spoTenant.DefaultSharingLinkType)``"
        }

        Add-MtTestResultDetail -Result $testResultMarkdown

        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
