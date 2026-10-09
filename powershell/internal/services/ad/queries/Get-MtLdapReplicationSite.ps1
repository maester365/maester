function Get-MtLdapReplicationSite {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $ConfigurationNamingContext
    )

    try {
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase "CN=Sites,$ConfigurationNamingContext" -Scope Subtree -Filter '(objectClass=site)' -Attributes @('distinguishedName', 'name'))
        return @($entries | ForEach-Object { [PSCustomObject]@{ Name = [string]$_.name; DistinguishedName = [string]$_.DistinguishedName } })
    }
    catch {
        Write-Verbose "Could not query LDAP replication sites: $($_.Exception.Message)"
        return @()
    }
}
