function Test-MtCisSpoGuestCannotShareUnownedItem {
    <#
    .SYNOPSIS
        Ensure that SharePoint guest users cannot share items they don't own

    .DESCRIPTION
        7.2.5 (L2) Ensure that SharePoint guest users cannot share items they don't own
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.5, L2)

    .EXAMPLE
        Test-MtCisSpoGuestCannotShareUnownedItem

        Returns true if SharePoint guest users cannot share items they don't own

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoGuestCannotShareUnownedItem
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.5',
        Title = 'Ensure that SharePoint guest users cannot share items they don''t own',
        Product = 'sharepoint',
        Feature = 'external-sharing',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1213.002', 'T1530'),
        Control = ('cis-m365:7.2.5', 'nist-800-53-r5:AC-3', 'nist-800-53-r5:AC-21'),
        Service = 'SharePointOnline',
        Author = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing that SharePoint guest users cannot share items they don't own..."

    $return = $true
    $spoTenant = Get-MtSpo
    if ($spoTenant.PreventExternalUsersFromResharing) {
        $testResult = "Well done. External users cannot share items they don't own."
    } else {
        $testResult = "External users can share items they don't own."
        $return = $false
    }
    Add-MtTestResultDetail -Result $testResult
    return $return
}
