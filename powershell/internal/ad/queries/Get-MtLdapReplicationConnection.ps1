function Get-MtLdapReplicationConnection {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $ConfigurationNamingContext
    )

    try {
        $attributes = @('distinguishedName', 'name', 'fromServer', 'transportType', 'options', 'enabledConnection')
        $entries = @(Invoke-MtLdapSearch -Connection $Connection -SearchBase "CN=Sites,$ConfigurationNamingContext" -Scope Subtree -Filter '(objectClass=nTDSConnection)' -Attributes $attributes)
        return @($entries | ForEach-Object { [PSCustomObject]@{ Name = [string]$_.name; DistinguishedName = [string]$_.DistinguishedName; FromServer = [string]$_.fromServer; TransportType = [string]$_.transportType; Options = $_.options; EnabledConnection = [bool]$_.enabledConnection } })
    }
    catch {
        Write-Verbose "Could not query LDAP replication connections: $($_.Exception.Message)"
        return @()
    }
}
