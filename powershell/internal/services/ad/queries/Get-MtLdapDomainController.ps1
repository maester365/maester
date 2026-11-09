function Get-MtLdapDomainController {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $ConfigurationNamingContext
    )

    $searchBase = "CN=Sites,$ConfigurationNamingContext"
    $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase $searchBase -Scope Subtree -Filter '(objectClass=nTDSDSA)' -Attributes @('distinguishedName', 'name', 'objectClass', 'options', 'invocationId', 'msDS-Behavior-Version', 'msDS-isRODC'))
    $siteNames = @{}
    return @($entries | ForEach-Object {
        $serverDn = $_.DistinguishedName -replace '^(?:\\.|[^,])+,', ''

        # Extract site name from DN: CN=<Server>,CN=Servers,CN=<Site>,CN=Sites,...
        $site = $null
        $siteDn = $null
        $collectionError = $null
        if ($serverDn -match '(?i),CN=Servers,(?<siteDn>.+)$') {
            $siteDn = $matches['siteDn']
            if (-not $siteNames.ContainsKey($siteDn)) {
                try {
                    $siteEntry = Invoke-MtLdapSearch -Connection $Connection -SearchBase $siteDn -Scope Base -Filter '(objectClass=site)' -Attributes @('name') -PageSize 0 | Select-Object -First 1
                    $siteNames[$siteDn] = if ($null -ne $siteEntry) { [string]$siteEntry.name } else { $null }
                }
                catch { $siteNames[$siteDn] = $null }
            }
            $site = $siteNames[$siteDn]
        }

        $server = $null
        try {
            $server = Invoke-MtLdapSearch -Connection $Connection -SearchBase $serverDn -Scope Base -Filter '(objectClass=server)' -Attributes @('name', 'dNSHostName', 'serverReference') -PageSize 0 | Select-Object -First 1
        }
        catch { $collectionError = 'DC server metadata could not be read from the selected directory target.' }
        if ($null -eq $server) { $collectionError = 'DC server metadata was not returned by the selected directory target.' }

        # Query computer object for operatingSystem and RODC status
        $operatingSystem = $null
        $operatingSystemVersion = $null
        $isReadOnly = if ($null -ne $_.'msDS-isRODC') { [bool]$_.'msDS-isRODC' } elseif (@($_.objectClass) -contains 'nTDSDSARO') { $true } elseif (@($_.objectClass) -contains 'nTDSDSA') { $false } else { $null }
        if (-not [string]::IsNullOrWhiteSpace($server.serverReference)) {
            try {
                $computer = Invoke-MtLdapSearch -Connection $Connection -SearchBase $server.serverReference -Scope Base -Filter '(objectClass=computer)' -Attributes @('operatingSystem', 'operatingSystemVersion', 'msDS-IsRODC') -PageSize 0 | Select-Object -First 1
                if ($null -eq $computer) { $collectionError = 'DC computer metadata was not returned; cross-domain visibility may be incomplete.' }
                else {
                    $operatingSystem = $computer.operatingSystem
                    $operatingSystemVersion = $computer.operatingSystemVersion
                    if ($null -eq $isReadOnly -and $null -ne $computer.'msDS-IsRODC') { $isReadOnly = [bool]$computer.'msDS-IsRODC' }
                }
            }
            catch { $collectionError = 'DC computer metadata could not be read; cross-domain visibility may be incomplete.' }
        }
        elseif ($null -eq $collectionError) { $collectionError = 'DC serverReference is unavailable; computer metadata cannot be resolved.' }

        $optionsValue = if ($null -ne $_.options) { [int]$_.options } else { 0 }

        [PSCustomObject]@{
            Name = [string]$server.name
            DistinguishedName = [string]$_.DistinguishedName
            DnsHostName = [string]$server.dNSHostName
            ServerReference = [string]$server.serverReference
            Options = $_.options
            InvocationId = $_.invocationId
            Site = $site
            SiteDistinguishedName = $siteDn
            OperatingSystem = [string]$operatingSystem
            OperatingSystemVersion = [string]$operatingSystemVersion
            SupportedLevelValue = if ($null -ne $_.'msDS-Behavior-Version') { [int]$_.'msDS-Behavior-Version' } else { $null }
            IsGlobalCatalog = [bool]($optionsValue -band 0x1)
            IsReadOnly = $isReadOnly
            LdapPort = $null
            SslPort = $null
            PortEvidence = 'Not measured'
            CollectionError = $collectionError
        }
    })
}
