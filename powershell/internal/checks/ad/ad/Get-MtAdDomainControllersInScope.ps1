function Get-MtAdDomainControllersInScope {
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory)] $State)

    $dn = [string]$State.Domain.DistinguishedName
    if (-not $dn -or $null -eq $State.DomainControllers) { throw 'Connected domain DN or DC inventory is unavailable.' }
    $scopedControllers = @($State.DomainControllers | Where-Object {
        $reference = [string]$_.ServerReference
        if ($reference) {
            $referenceDomain = ([regex]::Matches($reference, '(?i)(?:^|,)DC=[^,]+') | ForEach-Object { $_.Value.TrimStart(',') }) -join ','
            $referenceDomain -ieq $dn
        } else {
            $dns = [string]$_.DnsHostName
            $root = [string]$State.Domain.DnsRoot
            if (-not $dns -or -not $root) { throw "Cannot scope DC $($_.Name) to the connected domain." }
            $dot = $dns.IndexOf('.')
            $dot -gt 0 -and $dns.Substring($dot + 1) -ieq $root
        }
    })
    return $scopedControllers
}
