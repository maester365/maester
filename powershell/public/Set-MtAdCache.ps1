<#
.SYNOPSIS
    Sets the local cache of AD lookups.

.DESCRIPTION
    By default all AD queries are cached and re-used for the duration of the session.

    Use this function to set the cache.

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.PARAMETER Objects
    Specific type of AD objects to query.

.EXAMPLE
    Set-MtAdCache

    This example sets the cache of AD queries.

.LINK
    https://maester.dev/docs/commands/Set-MtAdCache
#>
function Set-MtAdCache {
    [CmdletBinding()]
    param(
        [string]$Server = $__MtSession.AdServer,
        [pscredential]$Credential = $__MtSession.AdCredential,
        [ValidateSet('All', 'Computers', 'Configuration', 'Domains', 'Forest')]
        [string[]]$Objects = 'All'
    )

    # Backwards compatible wrapper that fills the on-demand cache if callers expect the old behaviour
    foreach ($o in $Objects) {
        switch ($o) {
            'Computers' { Get-MtAdCacheItem -Type Computers -Properties @('DistinguishedName','Name','DNSHostName','LastLogonDate') -Server $Server -Credential $Credential -TtlMinutes 60 | Out-Null }
            'Domains'    { Get-MtAdCacheItem -Type Domains -Properties @('DistinguishedName','Name') -Server $Server -Credential $Credential -TtlMinutes 60 | Out-Null }
            'Forest'     { Get-MtAdCacheItem -Type Forest -Properties @('Name','Domains') -Server $Server -Credential $Credential -TtlMinutes 60 | Out-Null }
            'Configuration' { Get-MtAdCacheItem -Type Configuration -Properties @('DistinguishedName') -Server $Server -Credential $Credential -TtlMinutes 60 | Out-Null }
            'All'        {
                Get-MtAdCacheItem -Type Computers -Properties @('DistinguishedName','Name','DNSHostName','LastLogonDate') -Server $Server -Credential $Credential -TtlMinutes 60 | Out-Null
                Get-MtAdCacheItem -Type Domains -Properties @('DistinguishedName','Name') -Server $Server -Credential $Credential -TtlMinutes 60 | Out-Null
                Get-MtAdCacheItem -Type Forest -Properties @('Name','Domains') -Server $Server -Credential $Credential -TtlMinutes 60 | Out-Null
                Get-MtAdCacheItem -Type Configuration -Properties @('DistinguishedName') -Server $Server -Credential $Credential -TtlMinutes 60 | Out-Null
            }
        }
    }
}
