function Test-MtAdPrinterTotalCount {
    <#
    .SYNOPSIS
    Published printer inventory.
    .DESCRIPTION
    Uses cached Active Directory state to assess or inventory published printer inventory.
    .EXAMPLE
    Invoke-MtTest -Id AD-PRINT-01
    Review published printers manually.
    .LINK
    https://maester.dev/docs/tests/AD-PRINT-01
    #>
    [MaesterTest(
        Id = 'AD-PRINT-01',
        Title = 'Published printer inventory',
        Product = 'ad',
        Feature = 'printers',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:printQueue:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Printers')
    $printers = Get-MtAdStateCollection -State $state -Name Printers
    $rows = @('| Printer | Server | Location | Description |', '| --- | --- | --- | --- |')
    foreach ($printer in $printers) {
        $rows += '| {0} | {1} | {2} | {3} |' -f (Format-MtAdSiteInventoryValue $printer.Name), (Format-MtAdSiteInventoryValue $printer.ServerName), (Format-MtAdSiteInventoryValue $printer.Location), (Format-MtAdSiteInventoryValue $printer.Description)
    }
    Add-MtTestResultDetail -Result "Review $($printers.Count) published printer(s).`n`n$($rows -join "`n")" -Investigate
    return $true
}
