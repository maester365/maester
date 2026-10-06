function Test-MtCisaSpoAnyoneLinkExpiration {
    <#
    .SYNOPSIS
    Checks state of Anyone link expiration for SharePoint Online

    .DESCRIPTION
    An expiration date SHALL be set for Anyone links.

    .EXAMPLE
    Test-MtCisaSpoAnyoneLinkExpiration

    Returns true if Anyone links have an expiration set

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoAnyoneLinkExpiration
    #>
    [MaesterTest(
        Id = 'CISA.MS.SHAREPOINT.3.1',
        Title = 'Expiration days for Anyone links SHALL be set to 30 days or less.',
        Severity = 'Medium',
        Category = 'CISA',
        Tag = ('MS.SHAREPOINT', 'MS.SHAREPOINT.3.1'),
        Service = 'SharePointOnline',
        Author = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $spoTenant = Get-MtSpo

    if ($spoTenant.SharingCapability -ne "ExternalUserAndGuestSharing") {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Anyone links are not enabled. This test only applies when sharing is set to Anyone."
        return $null
    }

    # RequireAnonymousLinksExpireInDays: 0 = no expiration, >0 = days until expiry
    # CISA requires >= 1 AND <= 30 days
    $days = $spoTenant.RequireAnonymousLinksExpireInDays
    $testResult = $days -ge 1 -and $days -le 30

    if ($testResult) {
        $testResultMarkdown = "Well done. Anyone links expire after $days day(s)."
    } elseif ($days -eq 0) {
        $testResultMarkdown = "Anyone links do not have an expiration date set."
    } else {
        $testResultMarkdown = "Anyone links expiration is set to $days day(s), which exceeds the 30-day maximum."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'High'

    return $testResult
}
