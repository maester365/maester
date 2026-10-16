function Get-MtLdapReplicationSubnet {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $ConfigurationNamingContext
    )

    try {
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase "CN=Sites,$ConfigurationNamingContext" -Scope Subtree -Filter '(objectClass=subnet)' -Attributes @('distinguishedName', 'name', 'siteObject', 'location'))
        return @($entries | ForEach-Object { [PSCustomObject]@{ Name = [string]$_.name; DistinguishedName = [string]$_.DistinguishedName; SiteObject = [string]$_.siteObject; Location = [string]$_.location } })
    }
    catch {
        Write-Verbose "Could not query LDAP replication subnets: $($_.Exception.Message)"
        return @()
    }
}
