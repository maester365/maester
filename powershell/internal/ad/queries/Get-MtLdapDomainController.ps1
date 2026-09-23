function Get-MtLdapDomainController {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $ConfigurationNamingContext
    )

    try {
        $searchBase = "CN=Sites,$ConfigurationNamingContext"
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $searchBase -Scope Subtree -Filter '(objectClass=nTDSDSA)' -Attributes @('distinguishedName', 'name', 'options', 'invocationId'))
        return @($entries | ForEach-Object {
            $serverDn = $_.DistinguishedName -replace '^[^,]+,', ''
            $server = Invoke-MtLdapSearch -Connection $Connection -SearchBase $serverDn -Scope Base -Filter '(objectClass=server)' -Attributes @('dNSHostName', 'serverReference') -PageSize 0 | Select-Object -First 1
            [PSCustomObject]@{
                Name = [string]$_.name; DistinguishedName = [string]$_.DistinguishedName; DnsHostName = [string]$server.dNSHostName
                ServerReference = [string]$server.serverReference; Options = $_.options; InvocationId = $_.invocationId
            }
        })
    }
    catch {
        Write-Verbose "Could not query LDAP domain controllers: $($_.Exception.Message)"
        return @()
    }
}
