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

            # Extract site name from DN: CN=<Server>,CN=Servers,CN=<Site>,CN=Sites,...
            $site = $null
            $parts = $serverDn -split ',CN=Sites,', 2
            if ($parts.Count -eq 2) {
                $siteParts = $parts[0] -split ',CN=Servers,', 2
                if ($siteParts.Count -eq 2) {
                    $site = $siteParts[1] -replace '^CN=', ''
                }
            }

            $server = Invoke-MtLdapSearch -Connection $Connection -SearchBase $serverDn -Scope Base -Filter '(objectClass=server)' -Attributes @('dNSHostName', 'serverReference') -PageSize 0 | Select-Object -First 1

            # Query computer object for operatingSystem
            $operatingSystem = $null
            if (-not [string]::IsNullOrWhiteSpace($server.serverReference)) {
                $computer = Invoke-MtLdapSearch -Connection $Connection -SearchBase $server.serverReference -Scope Base -Filter '(objectClass=computer)' -Attributes @('operatingSystem') -PageSize 0 | Select-Object -First 1
                $operatingSystem = $computer.operatingSystem
            }

            [PSCustomObject]@{
                Name = [string]$_.name
                DistinguishedName = [string]$_.DistinguishedName
                DnsHostName = [string]$server.dNSHostName
                ServerReference = [string]$server.serverReference
                Options = $_.options
                InvocationId = $_.invocationId
                Site = $site
                OperatingSystem = [string]$operatingSystem
            }
        })
    }
    catch {
        Write-Verbose "Could not query LDAP domain controllers: $($_.Exception.Message)"
        return @()
    }
}
