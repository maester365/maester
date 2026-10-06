function Test-MtCisSpoDefaultSharingLinkPermission {
    <#
    .SYNOPSIS
        Ensure the SharePoint default sharing link permission is set

    .DESCRIPTION
        7.2.11 (L1) Ensure the SharePoint default sharing link permission is set
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.11, L1)

    .EXAMPLE
        Test-MtCisSpoDefaultSharingLinkPermission

        Returns true if the SharePoint default sharing link permission is set to View

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoDefaultSharingLinkPermission
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.11',
        Title = 'Ensure the SharePoint default sharing link permission is set',
        Severity = 'Medium',
        Category = 'CIS',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS E5', 'CIS E5 Level 1', 'CIS M365 v7.0.0', 'L1', 'OneDrive', 'SharePoint Online'),
        Service = 'SharePointOnline',
        Author = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing default sharing link permission in SharePoint Online..."

    if (!(Test-MtConnection SharePointOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSharePoint
        return $null
    }

    $return = $true
    $spoTenant = Get-MtSpo
    if ($spoTenant.DefaultLinkPermission -eq "View") {
        $testResult = "Well done. Default sharing link permission is set to View."
    } else {
        $testResult = "Default sharing link permission is not set to View."
        $return = $false
    }
    Add-MtTestResultDetail -Result $testResult
    return $return
}
