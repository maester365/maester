function Get-MtAdFsmoPlacement {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $State)

    $forest = $State.Forest
    $domain = $State.Domain
    if (-not $forest.RootDomain -or -not $forest.RootDomainDistinguishedName -or
        -not $domain.DistinguishedName -or @($State.DomainControllers).Count -eq 0 -or
        @($forest.Domains).Count -eq 0) { throw 'Incomplete forest, domain or DC inventory for FSMO placement.' }

    $rootDomain = $domain
    if ($domain.DistinguishedName -ine $forest.RootDomainDistinguishedName) {
        $rootState = Get-MtADDomainState -ComputerName $forest.RootDomain -Categories @('Domain')
        $rootDomain = $rootState.Domain
        if (-not $rootDomain -or $rootDomain.DistinguishedName -ine $forest.RootDomainDistinguishedName) {
            throw 'Cannot obtain the forest root domain PDC owner from the cached root-domain snapshot.'
        }
    }

    $owners = [ordered]@{
        Schema = $forest.SchemaOwnerDistinguishedName
        DomainNaming = $forest.DomainNamingOwnerDistinguishedName
        RootPdc = $rootDomain.PdcOwnerDistinguishedName
        Pdc = $domain.PdcOwnerDistinguishedName
        Rid = $domain.RidOwnerDistinguishedName
        Infrastructure = $domain.InfrastructureOwnerDistinguishedName
    }
    $issues = [System.Collections.Generic.List[string]]::new()
    foreach ($role in $owners.Keys) {
        if ([string]::IsNullOrWhiteSpace([string]$owners[$role]) -or $owners[$role] -notmatch '(?i)^CN=NTDS Settings,CN=') {
            throw "Missing or invalid NTDS Settings DN for $role; hostname fallback is not safe."
        }
        $matching = @($State.DomainControllers | Where-Object { $_.DistinguishedName -ieq $owners[$role] })
        if ($matching.Count -ne 1) { throw "Cannot map $role owner to exactly one inventoried DC: $($owners[$role])." }
        if ($null -eq $matching[0].IsReadOnly) { throw "Incomplete read-only status for $role owner." }
        if ($matching[0].IsReadOnly) { $issues.Add("Read-only DC is recorded as $role owner.") }
    }
    if ($owners.Schema -ine $owners.RootPdc) { $issues.Add('Schema Master is not on the forest-root PDC.') }
    if ($owners.DomainNaming -ine $owners.RootPdc) { $issues.Add('Domain Naming Master is not on the forest-root PDC.') }
    if ($owners.Rid -ine $owners.Pdc) { $issues.Add('RID Master is not on the connected domain PDC.') }

    $multiDomain = @($forest.Domains).Count -gt 1
    $domainDcs = @(Get-MtAdDomainControllersInScope -State $State)
    if ($domainDcs.Count -eq 0) { throw 'Connected-domain DC scope is unavailable for Infrastructure Master placement.' }
    $allGc = @($domainDcs | Where-Object { $null -eq $_.IsGlobalCatalog }).Count -eq 0 -and
        @($domainDcs | Where-Object { $_.IsGlobalCatalog -eq $false }).Count -eq 0
    $recycle = @($State.OptionalFeatures | Where-Object { $_.Name -eq 'Recycle Bin Feature' })
    if ($multiDomain -and -not $allGc) {
        if ($recycle.Count -ne 1 -or $null -eq $recycle[0].IsEnabled) { throw 'Recycle Bin state unavailable for the Infrastructure Master GC exception.' }
        if ($recycle[0].IsEnabled -eq $false) {
            if (@($domainDcs | Where-Object { $null -eq $_.IsGlobalCatalog }).Count -gt 0) {
                throw 'Unknown connected-domain DC GC status prevents determining whether the all-GC Infrastructure Master exception applies.'
            }
            $infra = @($State.DomainControllers | Where-Object { $_.DistinguishedName -ieq $owners.Infrastructure })[0]
            if ($null -eq $infra.IsGlobalCatalog) { throw 'Infrastructure Master GC state unavailable.' }
            if ($infra.IsGlobalCatalog) { $issues.Add('Infrastructure Master is a GC in a multi-domain forest with non-GCs and Recycle Bin disabled.') }
        }
    }
    return [pscustomobject]@{ Owners = $owners; Issues = @($issues); AllGlobalCatalogs = $allGc }
}
