function Get-MtLdapRootDse {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.Protocols.LdapConnection] $Connection
    )

    $rootDseAttributes = @(
        'defaultNamingContext',
        'rootDomainNamingContext',
        'configurationNamingContext',
        'schemaNamingContext',
        'dnsHostName',
        'forestFunctionality',
        'domainFunctionality',
        'namingContexts',
        'supportedLDAPVersion',
        'supportedSASLMechanisms'
    )

    try {
        $result = Invoke-MtLdapSearch -Connection $Connection -SearchBase '' -Scope Base -Filter '(objectClass=*)' -Attributes $rootDseAttributes -PageSize 0
        if ($null -eq $result -or @($result).Count -eq 0) {
            throw 'The LDAP server returned no RootDSE entry.'
        }

        $entry = @($result)[0]
        return [PSCustomObject]@{
            DistinguishedName          = [string]$entry.DistinguishedName
            DefaultNamingContext       = [string]$entry.defaultNamingContext
            RootDomainNamingContext    = [string]$entry.rootDomainNamingContext
            ConfigurationNamingContext = [string]$entry.configurationNamingContext
            SchemaNamingContext        = [string]$entry.schemaNamingContext
            DnsHostName                = [string]$entry.dnsHostName
            ForestFunctionality        = $entry.forestFunctionality
            DomainFunctionality        = $entry.domainFunctionality
            NamingContexts             = [string[]]@($entry.namingContexts)
            SupportedLdapVersion       = @($entry.supportedLDAPVersion)
            SupportedSaslMechanisms    = [string[]]@($entry.supportedSASLMechanisms)
        }
    }
    catch {
        throw "Failed to read LDAP RootDSE. $($_.Exception.Message)"
    }
}
