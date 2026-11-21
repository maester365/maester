function Test-MtAdDomainControllerAccount {
    <#
    .SYNOPSIS
    Identifies a DC account from the collected directory server inventory.

    .DESCRIPTION
    Uses serverReference distinguished names, with DNS fallback only for inventory
    entries lacking serverReference. A claimed DC primary group is not DC evidence.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object] $Account,

        [Parameter(Mandatory)]
        [object[]] $DomainControllers
    )

    if ([string]::IsNullOrWhiteSpace([string]$Account.DistinguishedName)) {
        throw 'Account distinguished name is unavailable; DC identity cannot be verified.'
    }
    if (@($Account.ObjectClass | Where-Object { $_ -in 'msDS-ManagedServiceAccount', 'msDS-GroupManagedServiceAccount', 'msDS-DelegatedManagedServiceAccount' }).Count -gt 0) {
        return $false
    }
    foreach ($dc in $DomainControllers) {
        if (-not $dc.ServerReference -and -not $dc.DnsHostName) {
            throw 'DC inventory lacks serverReference and DNS identity; DC exclusions cannot be verified.'
        }
        if ($dc.ServerReference) {
            if ([string]$dc.ServerReference -eq [string]$Account.DistinguishedName) { return $true }
        }
        elseif ($Account.DnsHostName -and ([string]$dc.DnsHostName).TrimEnd('.') -eq ([string]$Account.DnsHostName).TrimEnd('.')) {
            return $true
        }
    }
    return $false
}
