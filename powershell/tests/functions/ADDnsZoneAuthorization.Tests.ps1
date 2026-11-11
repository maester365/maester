BeforeAll { Import-Module "$PSScriptRoot/../../Maester.psd1" -Force }
Describe 'AD DNS zone authorization behavior' {
    InModuleScope Maester {
        BeforeAll {
            $script:Connection=[Runtime.Serialization.FormatterServices]::GetUninitializedObject([System.DirectoryServices.Protocols.LdapConnection])
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
        It 'classifies the fixed Pre-Windows 2000 Compatible Access SID as broad' {
            $script:Aces=@([pscustomobject]@{ActiveDirectoryRights='CreateChild';Sid='S-1-5-32-554';IdentityReference='BUILTIN\Pre-Windows 2000 Compatible Access';ObjectType=$script:NodeGuid;InheritedObjectType=[guid]::Empty;AceFlags='None';AccessControlType='Allow';IsInherited=$false})
            $result=Get-MtLdapDnsZoneAuthorization -Connection $script:Connection -RootDse $script:RootDse
            $result.BroadPrincipalAces.Count | Should -Be 1
        }
        It 'accepts dnsRecord WriteProperty but rejects an unrelated property GUID' {
            $unrelated=[guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
            $script:Aces=@(
                [pscustomobject]@{ActiveDirectoryRights='WriteProperty';Sid='S-1-5-11';IdentityReference='NT AUTHORITY\Authenticated Users';ObjectType=$script:RecordGuid;InheritedObjectType=[guid]::Empty;AceFlags='None';AccessControlType='Allow';IsInherited=$false},
                [pscustomobject]@{ActiveDirectoryRights='WriteProperty';Sid='S-1-5-11';IdentityReference='NT AUTHORITY\Authenticated Users';ObjectType=$unrelated;InheritedObjectType=[guid]::Empty;AceFlags='None';AccessControlType='Allow';IsInherited=$false}
            )
            $entries=(Get-MtLdapDnsZoneAuthorization -Connection $script:Connection -RootDse $script:RootDse).ZoneAclEntries
            $entries[0].IsCandidate | Should -BeTrue
            $entries[1].IsCandidate | Should -BeFalse
        }
        It 'rejects inherited-object mismatch and InheritOnly ACEs' {
            $script:Aces=@(
                [pscustomobject]@{ActiveDirectoryRights='CreateChild';Sid='S-1-5-11';IdentityReference='NT AUTHORITY\Authenticated Users';ObjectType=$script:NodeGuid;InheritedObjectType=[guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';AceFlags='None';AccessControlType='Allow';IsInherited=$true},
                [pscustomobject]@{ActiveDirectoryRights='CreateChild';Sid='S-1-5-11';IdentityReference='NT AUTHORITY\Authenticated Users';ObjectType=$script:NodeGuid;InheritedObjectType=[guid]::Empty;AceFlags='InheritOnly';AccessControlType='Allow';IsInherited=$true}
            )
            $entries=(Get-MtLdapDnsZoneAuthorization -Connection $script:Connection -RootDse $script:RootDse).ZoneAclEntries
            @($entries|Where-Object IsCandidate).Count | Should -Be 0
        }
    }
}