function Get-MtLdapGpoLink {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [string] $SearchBase
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SearchBase)) { $SearchBase = (Get-MtLdapRootDse -Connection $Connection).DefaultNamingContext }
        $filter = '(|(objectClass=domainDNS)(objectClass=organizationalUnit))'
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $SearchBase -Scope Subtree -Filter $filter -Attributes @('distinguishedName', 'objectClass', 'gPLink', 'gPOptions'))
        return @($entries | ForEach-Object { [PSCustomObject]@{ DistinguishedName = [string]$_.DistinguishedName; ObjectClass = @($_.objectClass | Where-Object { $null -ne $_ }); GpLink = [string]$_.gPLink; GpOptions = $_.gPOptions } })
    }
    catch {
        Write-Verbose "Could not query LDAP GPO links: $($_.Exception.Message)"
        return @()
    }
}
