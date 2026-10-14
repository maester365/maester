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
        Product = 'sharepoint',
        Feature = 'sharing-links',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1080', 'T1565.001'),
        Control = ('cis-m365:7.2.11', 'nist-800-53-r5:AC-6'),
        Service = 'SharePointOnline',
        Author = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing default sharing link permission in SharePoint Online..."

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
