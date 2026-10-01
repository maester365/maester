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
        Domain = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Base'; Filter = '(objectClass=domainDNS)'
            Attributes = @('distinguishedName', 'name', 'objectSid', 'lockoutDuration', 'lockoutThreshold', 'maxPwdAge', 'minPwdAge', 'minPwdLength', 'ms-DS-MachineAccountQuota', 'pwdProperties', 'pwdHistoryLength', 'objectVersion', 'whenCreated', 'whenChanged', 'msDS-Behavior-Version', 'fSMORoleOwner')
            AdditionalSearches = @(
                [ordered]@{ SearchBase = 'CN=Infrastructure,{DefaultNamingContext}'; Scope = 'Base'; Filter = '(objectClass=infrastructureUpdate)'; Attributes = @('fSMORoleOwner') },
                [ordered]@{ SearchBase = 'CN=RID Manager$,CN=System,{DefaultNamingContext}'; Scope = 'Base'; Filter = '(objectClass=rIDManager)'; Attributes = @('fSMORoleOwner') },
                [ordered]@{ SearchBase = '{FsmoServerDistinguishedName}'; Scope = 'Base'; Filter = '(objectClass=server)'; Attributes = @('dNSHostName') }
            )
            Description = 'Reads the domain object and its password, behavior, identity, and FSMO metadata.'
        }
        Forest = [ordered]@{
            SearchBase = '{ConfigurationNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=crossRef)'
            Attributes = @('distinguishedName', 'dnsRoot', 'nCName', 'nETBIOSName', 'systemFlags', 'trustParent')
            Description = 'Builds forest domain information from configuration partition cross-reference objects.'
        }
        Computer = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=computer)'
            Attributes = @('distinguishedName', 'name', 'sAMAccountName', 'userAccountControl', 'operatingSystem', 'operatingSystemVersion', 'dNSHostName', 'whenCreated', 'whenChanged', 'lastLogonTimestamp', 'pwdLastSet', 'servicePrincipalName', 'primaryGroupID', 'objectSid', 'isCriticalSystemObject', 'managedBy', 'sIDHistory')
            Description = 'Enumerates computer accounts and account-control metadata in the domain.'
        }
        User = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(&(objectClass=user)(!(objectClass=computer)))'
            Attributes = @('distinguishedName', 'name', 'sAMAccountName', 'userAccountControl', 'adminCount', 'homeDirectory', 'badPasswordTime', 'lastLogonTimestamp', 'lockoutTime', 'logonHours', 'userWorkstations', 'managedBy', 'manager', 'pwdLastSet', 'profilePath', 'scriptPath', 'objectSid', 'sIDHistory', 'servicePrincipalName', 'whenCreated', 'whenChanged', 'isCriticalSystemObject')
            Description = 'Enumerates user accounts while excluding computer objects.'
        }
        Group = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=group)'
            Attributes = @('distinguishedName', 'name', 'sAMAccountName', 'groupType', 'adminCount', 'whenCreated', 'whenChanged', 'managedBy', 'objectSid', 'sIDHistory', 'isCriticalSystemObject')
            Description = 'Enumerates groups and the attributes needed to derive category and scope.'
        }
        ServiceAccount = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=msDS-GroupManagedServiceAccount)'
            Attributes = @('distinguishedName', 'name', 'sAMAccountName', 'dNSHostName', 'whenCreated', 'whenChanged', 'objectSid')
            Description = 'Enumerates group managed service accounts.'
        }
        DomainController = [ordered]@{
            SearchBase = 'CN=Sites,{ConfigurationNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=nTDSDSA)'
            Attributes = @('distinguishedName', 'name', 'options', 'invocationId')
            AdditionalSearches = @([ordered]@{ SearchBase = '{ServerDistinguishedName}'; Scope = 'Base'; Filter = '(objectClass=server)'; Attributes = @('dNSHostName', 'serverReference') })
            Description = 'Enumerates NTDS settings objects and resolves their parent server metadata.'
        }
        ReplicationSite = [ordered]@{
            SearchBase = 'CN=Sites,{ConfigurationNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=site)'
            Attributes = @('distinguishedName', 'name')
            Description = 'Enumerates Active Directory replication sites.'
        }
        ReplicationSubnet = [ordered]@{
            SearchBase = 'CN=Sites,{ConfigurationNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=subnet)'
            Attributes = @('distinguishedName', 'name', 'siteObject', 'location')
            Description = 'Enumerates replication subnets and their assigned sites.'
        }
        ReplicationConnection = [ordered]@{
            SearchBase = 'CN=Sites,{ConfigurationNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=nTDSConnection)'
            Attributes = @('distinguishedName', 'name', 'fromServer', 'transportType', 'options', 'enabledConnection')
            Description = 'Enumerates NTDS replication connection objects.'
        }
        Trust = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=trustedDomain)'
            Attributes = @('distinguishedName', 'name', 'trustPartner', 'trustType', 'trustDirection', 'trustAttributes', 'securityIdentifier', 'whenCreated', 'whenChanged')
            Description = 'Enumerates trusted-domain objects and trust metadata.'
        }
        OrganizationalUnit = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=organizationalUnit)'
            Attributes = @('distinguishedName', 'name', 'whenCreated', 'whenChanged', 'managedBy', 'description', 'gPLink', 'gPOptions')
            Description = 'Enumerates organizational units and Group Policy link settings.'
        }
        OptionalFeature = [ordered]@{
            SearchBase = 'CN=Optional Features,CN=Directory Service,CN=Windows NT,CN=Services,{ConfigurationNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=msDS-OptionalFeature)'
            Attributes = @('distinguishedName', 'name', 'msDS-OptionalFeatureGUID', 'msDS-EnabledFeatureBL', 'msDS-RequiredForestBehaviorVersion')
            Description = 'Enumerates optional directory features and enablement backlinks.'
        }
        ConfigurationContainer = [ordered]@{
            SearchBase = '{ConfigurationNamingContext}'; Scope = 'Subtree'; Filter = '(|(objectClass=siteLink)(objectClass=certificationAuthority)(objectClass=pKIEnrollmentService)(objectClass=pKICertificateTemplate)(objectClass=queryPolicy)(objectClass=msKds-ProvRootKey)(objectClass=serviceConnectionPoint))'
            Attributes = @('distinguishedName', 'name', 'objectClass', 'whenCreated', 'whenChanged')
            AdditionalSearches = @(
                'CN=WellKnown Security Principals', 'CN=Inter-Site Transports,CN=Sites', 'CN=NetServices,CN=Services',
                'CN=AuthN Policy Configuration,CN=Services', 'CN=Public Key Services,CN=Services',
                'CN=Query Policies,CN=Directory Service,CN=Windows NT,CN=Services',
                'CN=Directory Service,CN=Windows NT,CN=Services', 'CN=Master Root Keys,CN=Group Key Distribution,CN=Services',
                'CN=Activation Objects,CN=Services'
            )
            Description = 'Defines the bounded searches used to collect configuration, PKI, query policy, KDS, and activation data.'
        }
        SchemaObject = [ordered]@{
            SearchBase = '{SchemaNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=*)'
            Attributes = @('distinguishedName', 'name', 'objectClass', 'whenCreated', 'objectVersion')
            Description = 'Enumerates schema objects and schema version metadata.'
        }
        Printer = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=printQueue)'
            Attributes = @('distinguishedName', 'name', 'serverName', 'location')
            Description = 'Enumerates published print queues.'
        }
        FineGrainedPasswordPolicy = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=msDS-PasswordSettings)'
            Attributes = @('distinguishedName', 'name', 'msDS-PasswordSettingsPrecedence', 'msDS-LockoutDuration', 'msDS-LockoutThreshold', 'msDS-MaximumPasswordAge', 'msDS-MinimumPasswordAge', 'msDS-MinimumPasswordLength', 'msDS-PasswordComplexityEnabled', 'msDS-PasswordHistoryLength', 'msDS-PSOAppliesTo')
            Description = 'Enumerates fine-grained password settings objects.'
        }
        Gpo = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(objectClass=groupPolicyContainer)'
            Attributes = @('distinguishedName', 'name', 'displayName', 'whenCreated', 'whenChanged', 'flags', 'ntSecurityDescriptor', 'gPCWQLFilter', 'gPCFileSysPath', 'versionNumber')
            Description = 'Enumerates GPO metadata, ownership, filtering, and version information.'
        }
        GpoLink = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(&(gPLink=*)(|(objectClass=domainDNS)(objectClass=organizationalUnit)(objectClass=site)))'
            Attributes = @('distinguishedName', 'objectClass', 'gPLink', 'gPOptions')
            Description = 'Enumerates domain, OU, and site objects with Group Policy links.'
        }
        SiteContainer = [ordered]@{
            SearchBase = 'CN=Sites,{ConfigurationNamingContext}'; Scope = 'Subtree'; Filter = '(&(objectClass=site)(gPLink=*))'
            Attributes = @('distinguishedName', 'name', 'gPLink', 'objectClass')
            Description = 'Enumerates site containers that have Group Policy links.'
        }
        GroupMember = [ordered]@{
            SearchBase = '{GroupDistinguishedName}'; Scope = 'Base'; Filter = '(objectClass=*)'
            Attributes = @('member;range=0-*')
            AdditionalSearches = @(
                [ordered]@{ SearchBase = '{MemberDistinguishedName}'; Scope = 'Base'; Filter = '(objectClass=*)'; Attributes = @('objectSid') },
                [ordered]@{ SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(objectSid={EscapedSid})'; Attributes = @('distinguishedName', 'objectSid') }
            )
            Description = 'Retrieves ranged group membership and resolves foreign security principals with per-target memoization.'
        }
        Dacl = [ordered]@{
            SearchBase = '{DefaultNamingContext}'; Scope = 'Subtree'; Filter = '(|(objectClass=organizationalUnit)(objectClass=container)(objectClass=groupPolicyContainer)(objectClass=domainDNS)(objectClass=computer)(objectClass=user)(objectClass=group))'
            Attributes = @('distinguishedName', 'objectClass', 'name', 'objectSid', 'ntSecurityDescriptor')
            Description = 'Retrieves and flattens DACL access entries for security-relevant directory objects.'
        }
    }
}
