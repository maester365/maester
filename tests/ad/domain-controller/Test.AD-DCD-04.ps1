function Test-MtAdDcNonGlobalCatalogCount {
    <#
    .SYNOPSIS
    Inventories Global Catalog status or evaluates all-GC and minimum-forest-GC policies.
    .DESCRIPTION
    Inventory mode reports unknown statuses for review. Policy modes require known
    statuses; missing required DC inventory remains an error in every mode.
    .EXAMPLE
    Invoke-MtTest -Id AD-DCD-04
    Inventory each controller's Global Catalog status for investigation.
    .EXAMPLE
    Invoke-MtTest -Id AD-DCD-04 -Parameter @{ AssessmentMode = 'AllGlobalCatalogs' }
    Evaluate the configured policy that every inventoried DC is a Global Catalog.
    .LINK
    https://maester.dev/docs/tests/AD-DCD-04
    #>
    [MaesterTest(
        Id = 'AD-DCD-04',
        Title = 'Global Catalog status should be reviewed or meet the configured policy',
        Product = 'ad',
        Feature = 'domain-controllers',
        Area = 'infrastructure',
        ResourceType = 'DomainController',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:nTDSDSA:ReadProperty', 'ActiveDirectory:Ldap:crossRef:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Inventory by default; optionally require all DCs to be GCs or at least one forest GC.
        [ValidateSet('Inventory', 'AllGlobalCatalogs', 'MinimumForestCatalog')]
        [string] $AssessmentMode = 'Inventory'
    )

    $state = Get-MtADDomainState -Categories @('DomainControllers', 'Forest')
    if (-not $state.Forest -or @($state.Forest.Domains).Count -eq 0 -or $null -eq $state.DomainControllers) { throw 'Forest domains or DC inventory unavailable.' }
    $controllers = @($state.DomainControllers)
    if ($controllers.Count -eq 0) { throw 'Empty DC inventory cannot establish Global Catalog status.' }
    $unknown = @($controllers | Where-Object { $null -eq $_.IsGlobalCatalog })
    if ($AssessmentMode -ne 'Inventory' -and $unknown.Count -gt 0) { throw 'Incomplete GC status cannot establish the configured policy.' }
    $catalogs = @($controllers | Where-Object { $_.IsGlobalCatalog -eq $true })
    $nonCatalogs = @($controllers | Where-Object { $_.IsGlobalCatalog -eq $false })
    $ok = if ($AssessmentMode -eq 'AllGlobalCatalogs') { $nonCatalogs.Count -eq 0 } elseif ($AssessmentMode -eq 'MinimumForestCatalog') { $catalogs.Count -gt 0 } else { $true }
    $metrics = Format-MtAdSummaryTable -Values ([ordered]@{
        'Assessment mode' = $AssessmentMode
        'Inventoried forest DCs' = $controllers.Count
        'Global Catalog DCs' = $catalogs.Count
        'Non-Global Catalog DCs' = $nonCatalogs.Count
        'DCs with unknown GC status' = $unknown.Count
    })
    $rows = @('| Domain controller | Site | Global Catalog status |', '| --- | --- | --- |')
    foreach ($controller in $controllers) {
        $status = if ($null -eq $controller.IsGlobalCatalog) { '❔ Unknown' } elseif ($controller.IsGlobalCatalog) { '✅ GC' } else { '⚠️ Non-GC' }
        $rows += '| {0} | {1} | {2} |' -f (Format-MtAdSiteInventoryValue $controller.DnsHostName), (Format-MtAdSiteInventoryValue $controller.Site), $status
    }
    $message = if ($AssessmentMode -eq 'Inventory') { 'ℹ️ Review each controller GC status. Inventory mode does not impose a GC placement baseline.' }
    elseif ($ok) { 'Well done. ✅ Global Catalog status meets the configured policy.' }
    else { '⚠️ Global Catalog status does not meet the configured policy. Review placement and dependencies before changing it.' }
    if ($AssessmentMode -eq 'Inventory' -and $catalogs.Count -eq 0) { $message += ' ⚠️ No known Global Catalog was returned. Confirm inventory visibility and forest GC availability.' }
    Add-MtTestResultDetail -Result "$message`n`n$metrics`n`n$($rows -join "`n")`n`nRequiring every DC to be a GC is an organizational policy, not a universal AD requirement. Infrastructure Master placement exceptions depend on forest topology and Recycle Bin state. Inventory does not prove reachability." -Investigate:($AssessmentMode -eq 'Inventory')
    return $ok
}
