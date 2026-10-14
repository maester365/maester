function Get-MtLdapSiteContainer {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $ConfigurationNamingContext
    )

    try {
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase "CN=Sites,$ConfigurationNamingContext" -Scope Subtree -Filter '(objectClass=site)' -Attributes @('distinguishedName', 'name', 'gPLink', 'objectClass'))
        return @($entries | ForEach-Object { [PSCustomObject]@{ DistinguishedName = [string]$_.DistinguishedName; Name = [string]$_.name; GpLink = [string]$_.gPLink; ObjectClass = @($_.objectClass | Where-Object { $null -ne $_ }) } })
    }
    catch {
        Write-Verbose "Could not query LDAP site GPO containers: $($_.Exception.Message)"
        return @()
    }
}
