BeforeDiscovery { Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force }
Describe 'AD DNS zone authorization behavior' {
    InModuleScope Maester {
        BeforeAll {
            $script:Connection=[Runtime.Serialization.FormatterServices]::GetUninitializedObject([System.DirectoryServices.Protocols.LdapConnection])
            $script:ZoneGuid=[guid]'e0fa1e8b-9b45-11d0-afdd-00c04fd930c9'
            $script:NodeGuid=[guid]'e0fa1e8c-9b45-11d0-afdd-00c04fd930c9'
            $script:RecordGuid=[guid]'11111111-2222-3333-4444-555555555555'
            $script:RootDse=[pscustomobject]@{DefaultNamingContext='DC=contoso,DC=com';RootDomainNamingContext='DC=contoso,DC=com';SchemaNamingContext='CN=Schema,CN=Configuration,DC=contoso,DC=com';NamingContexts=@('DC=DomainDnsZones,DC=contoso,DC=com')}
        }
        BeforeEach {
            $script:SchemaShape=[byte[]]$script:NodeGuid.ToByteArray()
            $script:Aces=@()
            Mock Invoke-MtLdapSearch {
                if($Filter -eq '(objectClass=domainDNS)'){return [pscustomobject]@{objectSid=[pscustomobject]@{Value='S-1-5-21-1-2-3'}}}
                if($Filter -like '*lDAPDisplayName=dnsNode*'){return [pscustomobject]@{schemaIDGUID=$script:SchemaShape}}
                if($Filter -like '*lDAPDisplayName=dnsRecord*'){return [pscustomobject]@{schemaIDGUID=[byte[]]$script:RecordGuid.ToByteArray()}}
                if($Filter -eq '(objectClass=dnsZone)'){return [pscustomobject]@{name='contoso.com';DistinguishedName='DC=contoso.com,CN=MicrosoftDNS,DC=DomainDnsZones,DC=contoso,DC=com';ntSecurityDescriptor=[pscustomobject]@{Access=$script:Aces}}}
            }
        }
        It 'normalizes <Name> schema GUID shape' -TestCases @(
            @{Name='byte array';Shape={ [byte[]]$script:NodeGuid.ToByteArray() }}
            @{Name='decoded GUID string';Shape={ $script:NodeGuid.ToString() }}
            @{Name='object integer array';Shape={ [object[]]@($script:NodeGuid.ToByteArray()|ForEach-Object{[int]$_}) }}
            @{Name='Value wrapper';Shape={ [pscustomobject]@{Value=[byte[]]$script:NodeGuid.ToByteArray()} }}
            @{Name='single-item wrapper array';Shape={ ,([pscustomobject]@{Value=[byte[]]$script:NodeGuid.ToByteArray()}) }}
        ) {
            param($Name,$Shape)
            $script:SchemaShape=&$Shape
            (Get-MtLdapDnsZoneAuthorization -Connection $script:Connection -RootDse $script:RootDse).DnsNodeSchemaGuid | Should -Be $script:NodeGuid.ToString()
        }
        It 'classifies a zone-effective CreateChild ACE with dnsZone inheritance metadata as broad' {
            $script:Aces=@([pscustomobject]@{ActiveDirectoryRights='CreateChild';Sid='S-1-5-32-554';IdentityReference='BUILTIN\Pre-Windows 2000 Compatible Access';ObjectType=$script:NodeGuid;InheritedObjectType=$script:ZoneGuid;AceFlags='ContainerInherit, Inherited';AccessControlType='Allow';IsInherited=$true})
            $result=Get-MtLdapDnsZoneAuthorization -Connection $script:Connection -RootDse $script:RootDse
            $result.BroadPrincipalAces.Count | Should -Be 1
            $result.BroadPrincipalAces[0].MatchedWriteRights | Should -Contain 'CreateChild'
        }
        It 'rejects non-inheritable dnsRecord WriteProperty and accepts an inheritable dnsNode child ACE' {
            $script:Aces=@(
                [pscustomobject]@{ActiveDirectoryRights='WriteProperty';Sid='S-1-5-11';IdentityReference='NT AUTHORITY\Authenticated Users';ObjectType=$script:RecordGuid;InheritedObjectType=[guid]::Empty;AceFlags='None';AccessControlType='Allow';IsInherited=$false},
                [pscustomobject]@{ActiveDirectoryRights='WriteProperty';Sid='S-1-5-11';IdentityReference='NT AUTHORITY\Authenticated Users';ObjectType=$script:RecordGuid;InheritedObjectType=$script:NodeGuid;AceFlags='ContainerInherit';AccessControlType='Allow';IsInherited=$false}
            )
            $entries=(Get-MtLdapDnsZoneAuthorization -Connection $script:Connection -RootDse $script:RootDse).ZoneAclEntries
            $entries[0].IsCandidate | Should -BeFalse
            $entries[1].IsCandidate | Should -BeTrue
        }
        It 'retains an InheritOnly WriteProperty ACE applicable to dnsNode children' {
            $script:Aces=@([pscustomobject]@{ActiveDirectoryRights='WriteProperty';Sid='S-1-5-11';IdentityReference='NT AUTHORITY\Authenticated Users';ObjectType=$script:RecordGuid;InheritedObjectType=$script:NodeGuid;AceFlags='ContainerInherit, InheritOnly';AccessControlType='Allow';IsInherited=$false})
            $entry=(Get-MtLdapDnsZoneAuthorization -Connection $script:Connection -RootDse $script:RootDse).ZoneAclEntries[0]
            $entry.AppliesToDnsNode | Should -BeTrue
            $entry.IsCandidate | Should -BeTrue
        }
        It 'rejects an unrelated dnsRecord property GUID even when the ACE is inheritable' {
            $unrelated=[guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
            $script:Aces=@([pscustomobject]@{ActiveDirectoryRights='WriteProperty';Sid='S-1-5-11';IdentityReference='NT AUTHORITY\Authenticated Users';ObjectType=$unrelated;InheritedObjectType=$script:NodeGuid;AceFlags='ContainerInherit';AccessControlType='Allow';IsInherited=$false})
            $entry=(Get-MtLdapDnsZoneAuthorization -Connection $script:Connection -RootDse $script:RootDse).ZoneAclEntries[0]
            $entry.IsCandidate | Should -BeFalse
        }
        It 'rejects InheritOnly ACEs even when their object metadata otherwise matches' {
            $script:Aces=@([pscustomobject]@{ActiveDirectoryRights='CreateChild';Sid='S-1-5-11';IdentityReference='NT AUTHORITY\Authenticated Users';ObjectType=$script:NodeGuid;InheritedObjectType=$script:ZoneGuid;AceFlags='ContainerInherit, InheritOnly';AccessControlType='Allow';IsInherited=$true})
            $entry=(Get-MtLdapDnsZoneAuthorization -Connection $script:Connection -RootDse $script:RootDse).ZoneAclEntries[0]
            $entry.IsCandidate | Should -BeFalse
        }
    }
}
