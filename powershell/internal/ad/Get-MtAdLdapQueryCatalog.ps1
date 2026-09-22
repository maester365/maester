function Get-MtAdLdapQueryCatalog {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    return [ordered]@{
        RootDse = [ordered]@{
            SearchBase = ''
            Scope      = 'Base'
            Filter     = '(objectClass=*)'
            Attributes = @(
                'defaultNamingContext',
                'configurationNamingContext',
                'schemaNamingContext',
                'dnsHostName',
                'forestFunctionality',
                'domainFunctionality',
                'namingContexts',
                'supportedLDAPVersion',
                'supportedSASLMechanisms'
            )
            Description = 'Reads RootDSE capabilities and naming contexts from the target LDAP endpoint.'
        }
        DomainNamingContext = [ordered]@{
            SearchBase = '{DefaultNamingContext}'
            Scope      = 'Base'
            Filter     = '(objectClass=domainDNS)'
            Attributes = @(
                'distinguishedName',
                'name',
                'objectSid',
                'lockoutDuration',
                'lockoutThreshold',
                'maxPwdAge',
                'minPwdLength',
                'ms-DS-MachineAccountQuota'
            )
            Description = 'Reads baseline domain policy attributes from the default naming context.'
        }
        ConfigurationNamingContext = [ordered]@{
            SearchBase = '{ConfigurationNamingContext}'
            Scope      = 'Subtree'
            Filter     = '(objectClass=crossRef)'
            Attributes = @(
                'distinguishedName',
                'dnsRoot',
                'nCName',
                'nETBIOSName',
                'systemFlags',
                'trustParent'
            )
            Description = 'Enumerates partition metadata and forest naming information from the configuration naming context.'
        }
    }
}
