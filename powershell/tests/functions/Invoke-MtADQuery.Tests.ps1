BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -ErrorAction Stop
}

Describe 'Modular AD query definitions and filter values' {
    It 'creates independent named definitions and canonical attribute selections' {
        $first = New-MtADQuery -Name User
        $first.Attributes[0] = 'changed'
        $second = New-MtADQuery -Name User
        $second.Attributes | Should -Contain 'primarygroupid'
        $second.Attributes | Should -Not -Contain 'changed'
        $second.Filter | Should -Be '(&(objectClass=user)(!(objectClass=computer)))'
        (New-MtADQuery -Attributes NAME,name,objectGUID).Attributes | Should -Be @('name', 'objectguid')
    }

    It 'allows explicit overrides of a named definition' {
        $query = New-MtADQuery -Name Group -SearchBase 'OU=Groups,DC=example,DC=com' -Filter '(name=A)' -Attributes name,member
        $query.Filter | Should -Be '(name=A)'
        $query.NamingContext | Should -BeNullOrEmpty
        $query.Attributes | Should -Be @('member', 'name')
    }

    It 'requires attributes and disallows ambiguous naming contexts or unscoped RootDSE' {
        { New-MtADQuery } | Should -Throw '*explicit Attributes*'
        { New-MtADQuery -Name User -NamingContext Default -SearchBase 'DC=example,DC=com' } | Should -Throw '*not both*'
        { New-MtADQuery -SearchBase '' -Attributes name } | Should -Throw '*Scope Base*'
        (New-MtADQuery -SearchBase '' -Scope Base -Attributes defaultNamingContext).SearchBase | Should -Be ''
    }

    It 'rejects wildcard, OID, option and known secret selections: <Attribute>' -ForEach @(
        @{ Attribute = '*' }, @{ Attribute = '+' }, @{ Attribute = '1.1' }, @{ Attribute = '1.2.840.113556.1.4.90' },
        @{ Attribute = 'member;range=0-*' }, @{ Attribute = 'msLAPS-Password' }, @{ Attribute = 'MS-MCS-ADMPWD' },
        @{ Attribute = 'msLAPS-EncryptedPasswordHistory' }, @{ Attribute = 'msDS-ManagedPassword' },
        @{ Attribute = 'msLAPS-EncryptedDSRMPassword' }, @{ Attribute = 'msLAPS-EncryptedDSRMPasswordHistory' },
        @{ Attribute = 'supplementalCredentials' }, @{ Attribute = 'msFVE-RecoveryPassword' }, @{ Attribute = 'msPKIDPAPIMasterKeys' }
    ) {
        { New-MtADQuery -Attributes $Attribute } | Should -Throw
    }

    It 'permits password policy and expiration metadata' {
        (New-MtADQuery -Attributes msLAPS-PasswordExpirationTime,ms-Mcs-AdmPwdExpirationTime,pwdLastSet).Attributes | Should -HaveCount 3
    }

    It 'escapes metacharacters, nulls, Unicode and binary filter values' {
        ConvertTo-MtLdapFilterValue 'a*(b)\' | Should -Be 'a\2a\28b\29\5c'
        ConvertTo-MtLdapFilterValue "a$([char]0)b" | Should -Be 'a\00b'
        ConvertTo-MtLdapFilterValue ([string][char]0xE9) | Should -Be '\c3\a9'
        ConvertTo-MtLdapFilterValue ([byte[]]@(0, 65, 255)) | Should -Be '\00\41\ff'
        ConvertTo-MtLdapFilterValue $null | Should -Be ''
        ConvertTo-MtLdapFilterValue ([guid]'00112233-4455-6677-8899-aabbccddeeff') | Should -Be '\33\22\11\00\55\44\77\66\88\99\aa\bb\cc\dd\ee\ff'
        { ConvertTo-MtLdapFilterValue 10 } | Should -Throw '*string, byte array or GUID*'
    }

    It 'does not include assertion values or query filters in verbose messages' {
        $records = @(ConvertTo-MtLdapFilterValue 'sensitive-assertion' -Verbose 4>&1)
        $records += @(New-MtADQuery -Attributes name -Filter '(name=sensitive-assertion)' -Verbose 4>&1)
        $messages = @($records | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })
        $messages | Should -HaveCount 2
        foreach ($message in $messages) { $message.Message | Should -Not -Match 'sensitive-assertion' }
    }
}

Describe 'Invoke-MtADQuery additive cached collection' {
    BeforeEach {
        $script:ADQueryTestConnection = InModuleScope Maester {
            $__MtSession.ADCache = @{}
            $__MtSession.ADCredential = $null
            $__MtSession.ADConnection = [ordered]@{
                Connected = $true
                ProtocolValidated = $true
                ResolvedServer = 'dc1.example.com'
                ResolvedDomain = 'example.com'
                DefaultNamingContext = 'DC=example,DC=com'
                ConfigurationNamingContext = 'CN=Configuration,DC=example,DC=com'
                SchemaNamingContext = 'CN=Schema,CN=Configuration,DC=example,DC=com'
                AuthenticationMode = 'Negotiate'
                TlsMode = 'Ldaps'
                SkipCertificateCheck = $false
            }
            $script:ADQueryTestState = @{
                Reads = 0
                Disposed = 0
                Fail = $false
                Requests = [System.Collections.Generic.List[object]]::new()
                Timeouts = [System.Collections.Generic.List[object]]::new()
                Entries = @([pscustomobject]@{
                    DistinguishedName = 'CN=Alice,DC=example,DC=com'
                    Attributes = [ordered]@{ name = @('Alice'); objectGUID = [guid]'00112233-4455-6677-8899-aabbccddeeff' }
                })
            }
            $script:ADQueryTestConnection = [System.DirectoryServices.Protocols.LdapConnection]::new('dc1.example.com')
            $script:ADQueryTestConnection | Add-Member NoteProperty MtState $script:ADQueryTestState
            $script:ADQueryTestConnection | Add-Member ScriptMethod Dispose {
                $this.MtState.Disposed++
                $this.psbase.Dispose()
            } -Force
            $script:ADQueryTestConnection | Add-Member NoteProperty MtSendRequestOverride {
                param($request, $timeout)
                $script:ADQueryTestState.Reads++
                $script:ADQueryTestState.Requests.Add($request)
                $script:ADQueryTestState.Timeouts.Add($timeout)
                if ($script:ADQueryTestState.Fail) { throw 'query test failure' }
                [pscustomobject]@{
                    ResultCode = [System.DirectoryServices.Protocols.ResultCode]::Success
                    Entries = $script:ADQueryTestState.Entries
                    Controls = @([pscustomobject]@{ Cookie = [byte[]]@() })
                    References = @()
                }
            }
            $script:ADQueryTestConnection
        }
        Mock -ModuleName Maester Test-MtConnection { $true }
        Mock -ModuleName Maester New-MtAdProtocolConnection { $script:ADQueryTestConnection }
    }

    AfterEach {
        InModuleScope Maester { $script:ADQueryTestConnection.psbase.Dispose() }
    }

    It 'returns rows or envelopes with a consistent independent object contract' {
        $first = Invoke-MtADQuery -Attributes name,objectGUID -AsResult
        ($first.Entries[0].Attributes['name'] -is [object[]]) | Should -BeTrue
        $first.Entries[0].Attributes['name'][0] | Should -Be 'Alice'
        $first.Entries[0].Attributes['objectguid'][0] | Should -BeOfType ([guid])
        $first.Request.SearchBase | Should -Be 'DC=example,DC=com'
        $first.Request.Target.Server | Should -Be 'dc1.example.com'
        $first.CollectedAt | Should -BeOfType ([datetime])
        $first.Entries[0].Attributes['name'][0] = 'mutated'
        $first.Request.Attributes[0] = 'mutated'
        $rows = @(Invoke-MtADQuery -Attributes OBJECTGUID,NAME -PageSize 1)
        $rows | Should -HaveCount 1
        $rows[0].Attributes['name'][0] | Should -Be 'Alice'
        $rows[0].Attributes['objectguid'][0] | Should -BeOfType ([guid])
        Should -Invoke New-MtAdProtocolConnection -ModuleName Maester -Times 1 -Exactly
        InModuleScope Maester {
            $script:ADQueryTestState.Reads | Should -Be 1
            $script:ADQueryTestState.Disposed | Should -Be 1
            $script:ADQueryTestState.Timeouts[0] | Should -Be ([timespan]::FromSeconds(30))
        }
    }

    It 'caches successful empty collections without mistaking them for a miss' {
        InModuleScope Maester { $script:ADQueryTestState.Entries = @() }
        $first = Invoke-MtADQuery -Attributes name -AsResult
        $first.Entries | Should -HaveCount 0
        @(Invoke-MtADQuery -Attributes name) | Should -HaveCount 0
        InModuleScope Maester { $script:ADQueryTestState.Reads | Should -Be 1 }
        Should -Invoke New-MtAdProtocolConnection -ModuleName Maester -Times 1 -Exactly
    }

    It 'accepts query objects, dictionaries, and direct parameters with the same cache identity' {
        $query = New-MtADQuery -Name User -Attributes name
        $null = $query | Invoke-MtADQuery
        $null = Invoke-MtADQuery -Query @{ Name = 'User'; Attributes = @('name') }
        $null = Invoke-MtADQuery -Name User -Attributes name
        InModuleScope Maester { $script:ADQueryTestState.Reads | Should -Be 1 }
    }

    It 'rejects unexpected fields and revalidates modified query objects' {
        { Invoke-MtADQuery -Query @{ Attributes = @('name'); Unexpected = 'x' } } | Should -Throw '*unsupported field*'
        $query = New-MtADQuery -Name User
        $query.Attributes = @('msLAPS-Password')
        { Invoke-MtADQuery -Query $query } | Should -Throw '*secret attributes*'
        { Invoke-MtADQuery -Query 'not a definition' } | Should -Throw '*dictionary or PSCustomObject*'
        Should -Invoke New-MtAdProtocolConnection -ModuleName Maester -Times 0 -Exactly
    }

    It 'separates filters by exact values, bases, scopes, selections and descriptor controls' {
        InModuleScope Maester {
            $operation = @{ Connection = $null }
            $queries = @(
                (New-MtADQuery -Attributes name -Filter '(name=Alice)'),
                (New-MtADQuery -Attributes name -Filter '(name=alice)'),
                (New-MtADQuery -Attributes name -SearchBase 'OU=A,DC=example,DC=com'),
                (New-MtADQuery -Attributes name -Scope OneLevel),
                (New-MtADQuery -Attributes name,objectGUID),
                (New-MtADQuery -Attributes name -SecurityDescriptorFlags Dacl),
                (New-MtADQuery -Attributes name -SecurityDescriptorFlags Owner)
            )
            foreach ($query in $queries) {
                $null = Invoke-MtADQueryCached -Query $query -Operation $operation -PageSize 1000 -Timeout ([timespan]::FromSeconds(30))
            }
            $script:ADQueryTestState.Reads | Should -Be 7
            $__MtSession.ADCache.ADQueryState.Results.Count | Should -Be 7
            $operation.Connection.Dispose()
        }
    }

    It 'resolves each naming context and explicit RootDSE without rediscovering the target' {
        $queries = @(
            (New-MtADQuery -Attributes name),
            (New-MtADQuery -Attributes name -NamingContext Configuration),
            (New-MtADQuery -Attributes name -NamingContext Schema),
            (New-MtADQuery -Attributes defaultNamingContext -SearchBase '' -Scope Base)
        )
        $results = @($queries | Invoke-MtADQuery -AsResult)
        $results.Request.SearchBase | Should -Be @('DC=example,DC=com', 'CN=Configuration,DC=example,DC=com', 'CN=Schema,CN=Configuration,DC=example,DC=com', '')
        Should -Invoke New-MtAdProtocolConnection -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $ProtocolEvidence.ResolvedServer -eq 'dc1.example.com' }
        InModuleScope Maester { $script:ADQueryTestState.Disposed | Should -Be 1 }
    }

    It 'throws before cache access if the session is no longer connected or validated' {
        $null = Invoke-MtADQuery -Attributes name
        Mock -ModuleName Maester Test-MtConnection { $false }
        { Invoke-MtADQuery -Attributes name } | Should -Throw '*must validate a target*'
        Mock -ModuleName Maester Test-MtConnection { $true }
        InModuleScope Maester { $__MtSession.ADConnection.ProtocolValidated = $false }
        { Invoke-MtADQuery -Attributes name } | Should -Throw '*must validate a target*'
    }

    It 'throws when a naming context is missing instead of querying an empty base' {
        InModuleScope Maester { $__MtSession.ADConnection.SchemaNamingContext = $null }
        { Invoke-MtADQuery -NamingContext Schema -Attributes name } | Should -Throw '*naming context is unavailable*'
        Should -Invoke New-MtAdProtocolConnection -ModuleName Maester -Times 0 -Exactly
    }

    It 'does not cache failed collections and disposes the connection' {
        InModuleScope Maester { $script:ADQueryTestState.Fail = $true }
        { Invoke-MtADQuery -Attributes name } | Should -Throw '*query test failure*'
        InModuleScope Maester {
            $__MtSession.ADCache.ADQueryState.Results.Count | Should -Be 0
            $script:ADQueryTestState.Disposed | Should -Be 1
            $script:ADQueryTestState.Fail = $false
        }
        @(Invoke-MtADQuery -Attributes name) | Should -HaveCount 1
        InModuleScope Maester { $script:ADQueryTestState.Reads | Should -Be 2 }
    }

    It 'does not return or cache partial entries when a later page fails' {
        InModuleScope Maester {
            $script:ADQueryTestConnection.MtSendRequestOverride = {
                param($request, $timeout)
                $script:ADQueryTestState.Reads++
                $script:ADQueryTestState.Requests.Add($request)
                $script:ADQueryTestState.Timeouts.Add($timeout)
                if ($script:ADQueryTestState.Reads -gt 1) { throw 'second page failed' }
                [pscustomobject]@{
                    ResultCode = [System.DirectoryServices.Protocols.ResultCode]::Success
                    Entries = $script:ADQueryTestState.Entries
                    Controls = @([pscustomobject]@{ Cookie = [byte[]]@(1) })
                    References = @()
                }
            }
            $received = [System.Collections.Generic.List[object]]::new()
            { Invoke-MtADQuery -Attributes name | ForEach-Object { $received.Add($_) } } | Should -Throw '*second page failed*'
            $received.Count | Should -Be 0
            $__MtSession.ADCache.ADQueryState.Results.Count | Should -Be 0
        }
    }

    It 'disposes the pipeline connection even when the consumer stops early' {
        @((New-MtADQuery -Name User), (New-MtADQuery -Name Group)) | Invoke-MtADQuery | Select-Object -First 1 | Out-Null
        InModuleScope Maester { $script:ADQueryTestState.Reads | Should -Be 1; $script:ADQueryTestState.Disposed | Should -Be 1 }
    }

    It 'never caches or emits an entry with a missing range continuation' {
        InModuleScope Maester {
            $script:ADQueryTestConnection.MtSendRequestOverride = {
                param($request, $timeout)
                $script:ADQueryTestState.Reads++
                $script:ADQueryTestState.Timeouts.Add($timeout)
                $entries = if ($request.Scope -eq [System.DirectoryServices.Protocols.SearchScope]::Base) { @() }
                else { @([pscustomobject]@{
                    DistinguishedName = 'CN=Group,DC=example,DC=com'
                    Attributes = [ordered]@{ 'member;range=0-0' = @('CN=Alice,DC=example,DC=com') }
                }) }
                [pscustomobject]@{
                    ResultCode = [System.DirectoryServices.Protocols.ResultCode]::Success
                    Entries = $entries
                    Controls = @([pscustomobject]@{ Cookie = [byte[]]@() })
                    References = @()
                }
            }
            $received = [System.Collections.Generic.List[object]]::new()
            { Invoke-MtADQuery -Name Group -Attributes member | ForEach-Object { $received.Add($_) } } | Should -Throw '*original entry*'
            $received.Count | Should -Be 0
            $__MtSession.ADCache.ADQueryState.Results.Count | Should -Be 0
            $script:ADQueryTestState.Disposed | Should -Be 1
        }
    }

    It 'completes and caches ranged membership when AD returns an empty base placeholder' {
        InModuleScope Maester {
            $script:ADQueryTestConnection.MtSendRequestOverride = {
                param($request, $timeout)
                $script:ADQueryTestState.Reads++
                $script:ADQueryTestState.Requests.Add($request)
                $script:ADQueryTestState.Timeouts.Add($timeout)
                $attributes = if ($request.Scope -eq [System.DirectoryServices.Protocols.SearchScope]::Base) {
                    [ordered]@{ 'member;range=1-*' = @('CN=Bob') }
                } else {
                    [ordered]@{ member = @(); 'member;range=0-0' = @('CN=Alice') }
                }
                [pscustomobject]@{
                    ResultCode = [System.DirectoryServices.Protocols.ResultCode]::Success
                    Entries = @([pscustomobject]@{ DistinguishedName = 'CN=Group,DC=example,DC=com'; Attributes = $attributes })
                    Controls = @([pscustomobject]@{ Cookie = [byte[]]@() })
                    References = @()
                }
            }
        }
        $first = Invoke-MtADQuery -Name Group -Attributes member -AsResult
        $first.Entries[0].Attributes['member'] | Should -Be @('CN=Alice', 'CN=Bob')
        @($first.Entries[0].Attributes.Keys | Where-Object { $_ -match ';range=' }) | Should -HaveCount 0
        $cached = Invoke-MtADQuery -Name Group -Attributes member -AsResult
        $cached.CollectedAt | Should -Be $first.CollectedAt
        $cached.Entries[0].Attributes['member'] | Should -Be @('CN=Alice', 'CN=Bob')
        InModuleScope Maester {
            $script:ADQueryTestState.Reads | Should -Be 2
            $script:ADQueryTestState.Disposed | Should -Be 1
        }
    }

    It 'preserves and isolates binary values on the first return and cache hits' {
        InModuleScope Maester {
            $script:ADQueryTestState.Entries[0].Attributes = [ordered]@{ customBlob = [byte[]]@(0, 255, 65) }
        }
        $first = Invoke-MtADQuery -Attributes customBlob -AsResult
        $first.Entries[0].Attributes['customblob'][0][0] = 42
        $second = Invoke-MtADQuery -Attributes customBlob -AsResult
        ($second.Entries[0].Attributes['customblob'][0] -is [byte[]]) | Should -BeTrue
        $second.Entries[0].Attributes['customblob'][0][0] | Should -Be 0
        InModuleScope Maester { $script:ADQueryTestState.Reads | Should -Be 1 }
    }

    It 'does not cache known text values with invalid UTF-8' {
        InModuleScope Maester { $script:ADQueryTestState.Entries[0].Attributes = [ordered]@{ name = [byte[]]@(255) } }
        { Invoke-MtADQuery -Attributes name } | Should -Throw
        InModuleScope Maester {
            $__MtSession.ADCache.ADQueryState.Results.Count | Should -Be 0
            $script:ADQueryTestState.Disposed | Should -Be 1
        }
    }

    It 'terminates conversion failures under Continue without an enclosing error handler' {
        # A fresh runspace isolates the call from Pester's own exception handlers and preferences.
        $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $powershell = [powershell]::Create()
        try {
            $runspace.Open()
            $powershell.Runspace = $runspace
            $script = @'
param($Manifest)
Import-Module $Manifest -Force -ErrorAction Stop
$ErrorActionPreference = 'Continue'
$script:ReachedAfterQuery = $false
& (Get-Module Maester) {
    $__MtSession.ADCache = @{}
    $__MtSession.ADCredential = $null
    $__MtSession.ADConnection = [ordered]@{
        ProtocolValidated = $true; ResolvedServer = 'ldap.mock'; DefaultNamingContext = 'DC=example,DC=com'
        AuthenticationMode = 'Negotiate'; TlsMode = 'Ldaps'; SkipCertificateCheck = $false
    }
    $script:ContinueFixture = @{ Disposed = 0 }
    $script:ContinueConnection = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
    $script:ContinueConnection | Add-Member NoteProperty Fixture $script:ContinueFixture
    $script:ContinueConnection | Add-Member ScriptMethod Dispose {
        $this.Fixture.Disposed++
        $this.psbase.Dispose()
    } -Force
    $script:ContinueConnection | Add-Member NoteProperty MtSendRequestOverride {
        [pscustomobject]@{
            ResultCode = [System.DirectoryServices.Protocols.ResultCode]::Success
            Entries = @(
                [pscustomobject]@{ DistinguishedName = 'CN=Valid'; Attributes = [ordered]@{ name = @('Valid') } }
                [pscustomobject]@{ DistinguishedName = 'CN=Invalid'; Attributes = [ordered]@{ name = [byte[]]@(255) } }
            )
            Controls = @([pscustomobject]@{ Cookie = [byte[]]@() })
            References = @()
        }
    }
    function script:Test-MtConnection { param([string]$Service) $Service -eq 'ActiveDirectory' }
    function script:New-MtAdProtocolConnection {
        param([object]$ProtocolEvidence)
        if ($ProtocolEvidence.ResolvedServer -ne 'ldap.mock') { throw 'Unexpected fixture target.' }
        $script:ContinueConnection
    }
}
Invoke-MtADQuery -Attributes name -AsResult
$script:ReachedAfterQuery = $true
'@
            $null = $powershell.AddScript($script).AddArgument((Join-Path $PSScriptRoot '../../Maester.psd1'))
            $output = @()
            $failure = $null
            # Catch only the host-side Invoke exception. The isolated script has no error handler.
            try { $output = @($powershell.Invoke()) } catch { $failure = $_ }
            $failure | Should -Not -BeNullOrEmpty
            $output | Should -HaveCount 0
            $powershell.InvocationStateInfo.State | Should -Be ([System.Management.Automation.PSInvocationState]::Failed)
            $powershell.Commands.Clear()
            $powershell.Streams.Error.Clear()
            $null = $powershell.AddScript(@'
$module = Get-Module Maester
[pscustomobject]@{
    CacheEntries = $module.Invoke({ $__MtSession.ADCache.ADQueryState.Results.Count })[0]
    Disposed = $module.Invoke({ $script:ContinueFixture.Disposed })[0]
    ReachedAfterQuery = $script:ReachedAfterQuery
    ErrorPreference = $ErrorActionPreference
}
'@)
            $state = @($powershell.Invoke())[0]
            $state.CacheEntries | Should -Be 0
            $state.Disposed | Should -Be 1
            $state.ReachedAfterQuery | Should -BeFalse
            $state.ErrorPreference | Should -Be 'Continue'
        } finally {
            $powershell.Dispose()
            $runspace.Dispose()
        }
    }

    It 'invalidates only new results when connection evidence or credentials change' {
        InModuleScope Maester {
            $__MtSession.ADCache['DomainState:Users'] = @{ Users = @('legacy') }
            $operation = @{ Connection = $null }
            $query = New-MtADQuery -Attributes name
            $null = Invoke-MtADQueryCached -Query $query -Operation $operation -PageSize 1 -Timeout ([timespan]::FromSeconds(30))
            $__MtSession.ADConnection = [ordered]@{} + $__MtSession.ADConnection
            $null = Invoke-MtADQueryCached -Query $query -Operation $operation -PageSize 1 -Timeout ([timespan]::FromSeconds(30))
            $__MtSession.ADCredential = [pscredential]::new('reader', [securestring]::new())
            $null = Invoke-MtADQueryCached -Query $query -Operation $operation -PageSize 1 -Timeout ([timespan]::FromSeconds(30))
            $script:ADQueryTestState.Reads | Should -Be 3
            $__MtSession.ADCache['DomainState:Users'].Users | Should -Be @('legacy')
            $operation.Connection.Dispose()
        }
    }

    It 'invalidates on changed resolved target or TLS identity' {
        InModuleScope Maester {
            $operation = @{ Connection = $null }
            $query = New-MtADQuery -Attributes name
            $null = Invoke-MtADQueryCached -Query $query -Operation $operation -PageSize 1 -Timeout ([timespan]::FromSeconds(30))
            $__MtSession.ADConnection.ResolvedServer = 'dc2.example.com'
            $result = Invoke-MtADQueryCached -Query $query -Operation $operation -PageSize 1 -Timeout ([timespan]::FromSeconds(30))
            $result.Request.Target.Server | Should -Be 'dc2.example.com'
            $__MtSession.ADConnection.TlsMode = 'StartTls'
            $result = Invoke-MtADQueryCached -Query $query -Operation $operation -PageSize 1 -Timeout ([timespan]::FromSeconds(30))
            $result.Request.Target.Port | Should -Be 389
            $script:ADQueryTestState.Reads | Should -Be 3
            $operation.Connection.Dispose()
        }
    }

    It 'resets with a full AD cache clear but remains separate from scoped legacy clears' {
        InModuleScope Maester {
            $operation = @{ Connection = $null }
            $query = New-MtADQuery -Attributes name
            $null = Invoke-MtADQueryCached -Query $query -Operation $operation -PageSize 1 -Timeout ([timespan]::FromSeconds(30))
            Clear-MtADCache -Categories Users
            $null = Invoke-MtADQueryCached -Query $query -Operation $operation -PageSize 1 -Timeout ([timespan]::FromSeconds(30))
            $script:ADQueryTestState.Reads | Should -Be 1
            Clear-MtADCache
            $null = Invoke-MtADQueryCached -Query $query -Operation $operation -PageSize 1 -Timeout ([timespan]::FromSeconds(30))
            $script:ADQueryTestState.Reads | Should -Be 2
            $operation.Connection.Dispose()
        }
    }
}
