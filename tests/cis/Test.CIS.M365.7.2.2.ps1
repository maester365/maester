function Test-MtCisSpoB2BIntegration {
    <#
    .SYNOPSIS
        Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled

    .DESCRIPTION
        7.2.2 (L1) Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.2, L1)

    .EXAMPLE
        Test-MtCisSpoB2BIntegration

        Returns true if SharePoint and OneDrive integration with Azure AD B2B is enabled

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoB2BIntegration
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.2',
        Title = 'Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled',
        Product = 'sharepoint',
        RelatedProduct = 'entra',
        Feature = 'external-sharing',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1078.004', 'T1213.002'),
        Service = 'SharePointOnline',
        Author = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Write-Verbose "Testing SharePoint Entra B2B integration..."

    $return = $true
    $spoTenant = Get-MtSpo
    if ($spoTenant.EnableAzureADB2BIntegration) {
        $testResult = "Well done. Your SharePoint tenant is integrated with Microsoft Entra B2B."
    } else {
        $testResult = "Your SharePoint tenant is not integrated with Microsoft Entra B2B."
        $return = $false
    }
    Add-MtTestResultDetail -Result $testResult
    return $return
}
