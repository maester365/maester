#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

Describe 'AD query LDAP transport and range completion' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -ErrorAction Stop
        $script:MaesterModule = Get-Module Maester
        $script:ADBase = 'DC=contoso,DC=com'
        $script:ADDn = 'CN=User,DC=contoso,DC=com'

        function New-ADEntry {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory LDAP entry fixture; no directory or system state is changed.')]
            param([System.Collections.IDictionary] $Attributes = ([ordered]@{}), [string] $Dn = $script:ADDn)
            [pscustomobject]@{ DistinguishedName = $Dn; Attributes = $Attributes }
        }

        function New-ADResponse {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory LDAP response fixture; no directory or system state is changed.')]
            param([object[]] $Entries = @(), [object[]] $Controls = @(),
                [object[]] $References = @(),
                [object] $ResultCode = [System.DirectoryServices.Protocols.ResultCode]::Success)
            [pscustomobject]@{
                Entries = $Entries
                Controls = $Controls
                References = $References
                ResultCode = $ResultCode
            }
        }

        function New-ADFixture {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an unbound in-memory LDAP client with a fixture response hook; no connection is established.')]
            param([object[]] $Responses)
            $state = @{ Responses = $Responses; Index = 0; Requests = [System.Collections.Generic.List[object]]::new(); Timeouts = [System.Collections.Generic.List[object]]::new() }
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
            $script:FixtureConnections.Add($connection)
            $hook = {
                param($request, $timeout)
                $state.Requests.Add($request)
                $state.Timeouts.Add($timeout)
                $index = $state.Index
                $state.Index++
                if ($index -ge $state.Responses.Count) { throw 'Unexpected LDAP request.' }
                return $state.Responses[$index]
            }.GetNewClosure()
            $connection | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value $hook
            [pscustomobject]@{ Connection = $connection; State = $state }
        }
        $script:FixtureConnections = [System.Collections.Generic.List[object]]::new()
    }

    AfterEach {
        foreach ($connection in $script:FixtureConnections) { $connection.Dispose() }
        $script:FixtureConnections.Clear()
    }

    Context 'legacy and attribute-bag conversion' {
        It 'keeps the legacy scalar and null-for-missing contract for the same raw entry' {
            $entry = New-ADEntry ([ordered]@{ displayName = @('Ada'); member = @('One', 'Two') })
            $fixture = New-ADFixture @((New-ADResponse -Entries @($entry)))
            $rows = @($script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -Attributes @('displayName', 'member', 'missing') -PageSize 0 }, $fixture.Connection, $script:ADBase))
            $rows | Should -HaveCount 1
            $rows[0].displayName | Should -BeOfType [string]
            $rows[0].displayName | Should -Be 'Ada'
            $rows[0].missing | Should -BeNullOrEmpty
            $rows[0].PSObject.Properties.Name | Should -Contain 'missing'
            $rows[0].member | Should -HaveCount 2
            $rows[0].PSObject.Properties.Name | Should -Not -Contain 'Attributes'
        }

        It 'returns object arrays for single and empty values, omits absent names, and filters unrequested names' {
            $entry = New-ADEntry ([ordered]@{ displayName = @('Ada'); member = @(); ignored = @('secret') })
            $fixture = New-ADFixture @((New-ADResponse -Entries @($entry)))
            $rows = @($script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -Attributes @('displayName', 'member', 'missing') -PageSize 0 -AsAttributeBag }, $fixture.Connection, $script:ADBase))
            $rows | Should -HaveCount 1
            $rows[0].PSObject.TypeNames | Should -Contain 'Maester.AD.Entry'
            ($rows[0].Attributes['displayname'] -is [object[]]) | Should -BeTrue
            $rows[0].Attributes['displayname'].Count | Should -Be 1
            ($rows[0].Attributes['member'] -is [object[]]) | Should -BeTrue
            $rows[0].Attributes['member'].Count | Should -Be 0
            $rows[0].Attributes.Contains('missing') | Should -BeFalse
            $rows[0].Attributes.Contains('ignored') | Should -BeFalse
        }

        It 'normalizes known GUID, SID, integer and date values without guessing arbitrary dates or binary data' {
            $guid = [guid]::NewGuid()
            $sid = [byte[]]@(1, 1, 0, 0, 0, 0, 0, 5, 21, 0, 0, 0)
            $binary = [byte[]]@(0, 255, 128, 42)
            $descriptor = [byte[]]@(1, 2, 0, 255)
            $entry = New-ADEntry ([ordered]@{
                objectGUID = $guid.ToByteArray()
                objectSid = $sid
                'mS-DS-CreatorSID' = $sid
                nTSecurityDescriptor = $descriptor
                customBlob = $binary
                userAccountControl = @('512')
                whenCreated = @('20260102030405.0Z')
                customDate = @('20260102030405.0Z')
            })
            $fixture = New-ADFixture @((New-ADResponse -Entries @($entry)))
            $names = @('objectGUID', 'objectSid', 'mS-DS-CreatorSID', 'nTSecurityDescriptor', 'customBlob', 'userAccountControl', 'whenCreated', 'customDate')
            $rows = @($script:MaesterModule.Invoke({ param($c, $b, $a) Invoke-MtLdapSearch -Connection $c -SearchBase $b -Attributes $a -PageSize 0 -AsAttributeBag }, $fixture.Connection, $script:ADBase, $names))
            $bag = $rows[0].Attributes
            $bag['objectguid'][0] | Should -BeOfType [guid]
            $bag['objectguid'][0] | Should -Be $guid
            $bag['objectsid'][0] | Should -BeOfType [string]
            $bag['objectsid'][0] | Should -Be 'S-1-5-21'
            $bag['ms-ds-creatorsid'][0] | Should -Be 'S-1-5-21'
            $bag['useraccountcontrol'][0] | Should -BeOfType [int]
            $bag['useraccountcontrol'][0] | Should -Be 512
            $bag['whencreated'][0] | Should -BeOfType [datetime]
            $bag['customdate'][0] | Should -BeOfType [string]
            $bag['customdate'][0] | Should -Be '20260102030405.0Z'
            foreach ($name in @('ntsecuritydescriptor', 'customblob')) {
                ($bag[$name][0] -is [byte[]]) | Should -BeTrue
            }
            [Convert]::ToHexString($bag['ntsecuritydescriptor'][0]) | Should -Be ([Convert]::ToHexString($descriptor))
            [Convert]::ToHexString($bag['customblob'][0]) | Should -Be ([Convert]::ToHexString($binary))
            [object]::ReferenceEquals($bag['customblob'][0], $binary) | Should -BeFalse
        }

        It 'deep-copies nested attribute arrays and bytes when copying a query result' {
            $entry = [pscustomobject]@{ DistinguishedName = $script:ADDn; Attributes = [ordered]@{ photo = ,([byte[]]@(0, 255)) } }
            $copy = $script:MaesterModule.Invoke({ param($value) Copy-MtADQueryResult -Value $value }, $entry)
            ($copy.Attributes['photo'] -is [object[]]) | Should -BeTrue
            ($copy.Attributes['photo'][0] -is [byte[]]) | Should -BeTrue
            $copy.Attributes['photo'][0][0] = 9
            $entry.Attributes['photo'][0][0] | Should -Be 0
        }

        It 'normalizes standard attributes from DirectoryAttribute byte collections without guessing unknown binary' {
            $attributes = [ordered]@{}
            foreach ($pair in @{
                name = 'Alice'
                sAMAccountName = 'alice'
                userAccountControl = '512'
                whenCreated = '20260102030405.0Z'
                customBlob = 'looks like text'
                objectGUID = 'abcdefghijklmnop'
            }.GetEnumerator()) {
                $attribute = [System.DirectoryServices.Protocols.DirectoryAttribute]::new()
                $attribute.Name = $pair.Key
                [void]$attribute.Add([System.Text.Encoding]::UTF8.GetBytes($pair.Value))
                $attributes[$pair.Key] = $attribute
            }
            $fixture = New-ADFixture @((New-ADResponse -Entries @((New-ADEntry $attributes))))
            $rows = @($script:MaesterModule.Invoke({ param($c, $b)
                Invoke-MtLdapSearch -Connection $c -SearchBase $b -Attributes name,sAMAccountName,userAccountControl,whenCreated,customBlob,objectGUID -PageSize 0 -AsAttributeBag
            }, $fixture.Connection, $script:ADBase))
            $bag = $rows[0].Attributes
            $bag['name'][0] | Should -Be 'Alice'
            $bag['samaccountname'][0] | Should -Be 'alice'
            $bag['useraccountcontrol'][0] | Should -BeOfType [int]
            $bag['whencreated'][0] | Should -BeOfType [datetime]
            ($bag['customblob'][0] -is [byte[]]) | Should -BeTrue
            $bag['objectguid'][0] | Should -Be ([guid]::new([System.Text.Encoding]::UTF8.GetBytes('abcdefghijklmnop')))
        }

        It 'retains unset and never FILETIME sentinels as integers rather than absent values' {
            $entry = New-ADEntry ([ordered]@{
                lastLogon = [System.Text.Encoding]::UTF8.GetBytes('0')
                accountExpires = [System.Text.Encoding]::UTF8.GetBytes([long]::MaxValue.ToString())
            })
            $fixture = New-ADFixture @((New-ADResponse -Entries @($entry)))
            $rows = @($script:MaesterModule.Invoke({ param($c, $b)
                Invoke-MtLdapSearch -Connection $c -SearchBase $b -Attributes lastLogon,accountExpires -PageSize 0 -AsAttributeBag
            }, $fixture.Connection, $script:ADBase))
            $rows[0].Attributes['lastlogon'][0] | Should -BeOfType [long]
            $rows[0].Attributes['lastlogon'][0] | Should -Be 0
            $rows[0].Attributes['accountexpires'][0] | Should -Be ([long]::MaxValue)
        }

        It 'throws on invalid UTF-8 under a known text attribute' {
            $fixture = New-ADFixture @((New-ADResponse -Entries @((New-ADEntry ([ordered]@{ name = [byte[]]@(255) })))))
            { $script:MaesterModule.Invoke({ param($c, $b)
                Invoke-MtLdapSearch -Connection $c -SearchBase $b -Attributes name -PageSize 0 -AsAttributeBag
            }, $fixture.Connection, $script:ADBase) } | Should -Throw
        }
    }

    Context 'complete-response safeguards' {
        It 'rejects failed result codes only in strict mode' {
            $response = New-ADResponse -Entries @((New-ADEntry)) -ResultCode ([System.DirectoryServices.Protocols.ResultCode]::SizeLimitExceeded)
            $legacy = New-ADFixture @($response)
            @($script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -PageSize 0 }, $legacy.Connection, $script:ADBase)) | Should -HaveCount 1
            $strict = New-ADFixture @($response)
            { $script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -PageSize 0 -RequireComplete }, $strict.Connection, $script:ADBase) } | Should -Throw '*complete query response*'
        }

        It 'rejects a response with no result code when completeness is required' {
            $fixture = New-ADFixture @([pscustomobject]@{ Entries = @((New-ADEntry)); Controls = @(); References = @(); ResultCode = $null })
            { $script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -PageSize 0 -RequireComplete }, $fixture.Connection, $script:ADBase) } | Should -Throw '*complete query response*'
        }

        It 'requires a paging response control only in strict mode' {
            $response = New-ADResponse -Entries @((New-ADEntry))
            $legacy = New-ADFixture @($response)
            @($script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -PageSize 1 }, $legacy.Connection, $script:ADBase)) | Should -HaveCount 1
            $strict = New-ADFixture @($response)
            { $script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -PageSize 1 -RequireComplete }, $strict.Connection, $script:ADBase) } | Should -Throw '*paging response control*'
        }

        It 'adds a domain-scope control and consumes a successful paged response' {
            $response = New-ADResponse -Entries @((New-ADEntry)) -Controls @([pscustomobject]@{ Cookie = [byte[]]@() })
            $fixture = New-ADFixture @($response)
            $rows = @($script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -PageSize 1 -RequireComplete }, $fixture.Connection, $script:ADBase))
            $rows | Should -HaveCount 1
            @($fixture.State.Requests[0].Controls | Where-Object { $_ -is [System.DirectoryServices.Protocols.DomainScopeControl] }) | Should -HaveCount 1
            @($fixture.State.Requests[0].Controls | Where-Object { $_ -is [System.DirectoryServices.Protocols.PageResultRequestControl] }) | Should -HaveCount 1
        }

        It 'carries paging cookies through strict mode and checks every response' {
            $first = New-ADResponse -Entries @((New-ADEntry)) -Controls @([pscustomobject]@{ Cookie = [byte[]]@(3, 4) })
            $last = New-ADResponse -Entries @((New-ADEntry -Dn 'CN=Other,DC=contoso,DC=com')) -Controls @([pscustomobject]@{ Cookie = [byte[]]@() })
            $fixture = New-ADFixture @($first, $last)
            $rows = @($script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -PageSize 1 -RequireComplete }, $fixture.Connection, $script:ADBase))
            $rows | Should -HaveCount 2
            $fixture.State.Requests | Should -HaveCount 2
            [Convert]::ToHexString($fixture.State.Requests[1].Controls[0].Cookie) | Should -Be '0304'
            @($fixture.State.Requests[1].Controls | Where-Object { $_ -is [System.DirectoryServices.Protocols.DomainScopeControl] }) | Should -HaveCount 1
        }

        It 'rejects referral references in strict mode but tolerates them by default' {
            $response = New-ADResponse -Entries @((New-ADEntry)) -References @('ldap://other.example')
            $legacy = New-ADFixture @($response)
            @($script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -PageSize 0 }, $legacy.Connection, $script:ADBase)) | Should -HaveCount 1
            $strict = New-ADFixture @($response)
            { $script:MaesterModule.Invoke({ param($c, $b) Invoke-MtLdapSearch -Connection $c -SearchBase $b -PageSize 0 -RequireComplete }, $strict.Connection, $script:ADBase) } | Should -Throw '*continuation references*'
        }

        It 'disallows callbacks and directory entries with either modular option before sending' {
            foreach ($option in @('AsAttributeBag', 'RequireComplete')) {
                foreach ($incompatible in @('ReturnDirectoryEntry', 'ProcessPage')) {
                    $fixture = New-ADFixture @()
                    $arguments = @{ Connection = $fixture.Connection; SearchBase = $script:ADBase; Attributes = @('cn'); PageSize = 0 }
                    $arguments[$option] = $true
                    $arguments[$incompatible] = if ($incompatible -eq 'ProcessPage') { {} } else { $true }
                    { $script:MaesterModule.Invoke({ param($p) Invoke-MtLdapSearch @p }, $arguments) } | Should -Throw '*modular query contract*'
                    $fixture.State.Index | Should -Be 0
                }
            }
        }
    }

    Context 'ranged attribute completion' {
        It 'accepts an empty base placeholder with a populated <Range> response' -ForEach @(
            @{ Range = 'member;range=0-1'; Continuation = $true }
            @{ Range = 'member;range=0-*'; Continuation = $false }
        ) {
            $base = [System.DirectoryServices.Protocols.DirectoryAttribute]::new()
            $base.Name = 'member'
            $ranged = [System.DirectoryServices.Protocols.DirectoryAttribute]::new()
            $ranged.Name = $Range
            [void]$ranged.Add([Text.Encoding]::UTF8.GetBytes('CN=Alice'))
            [void]$ranged.Add([Text.Encoding]::UTF8.GetBytes('CN=Bob'))
            $attributes = [ordered]@{ member = $base }
            $attributes[$Range] = $ranged
            $responses = @((New-ADResponse -Entries @((New-ADEntry $attributes))))
            if ($Continuation) {
                $responses += New-ADResponse -Entries @((New-ADEntry ([ordered]@{ 'member;range=2-*' = @('CN=Carol') })))
            }
            $fixture = New-ADFixture $responses
            $result = $script:MaesterModule.Invoke({ param($c, $b)
                $entry = Invoke-MtLdapSearch -Connection $c -SearchBase $b -Attributes member -PageSize 0 -AsAttributeBag -RequireComplete
                Complete-MtADQueryRange -Connection $c -Entry $entry -Timeout ([timespan]::FromSeconds(5))
            }, $fixture.Connection, $script:ADBase)
            $expected = @('CN=Alice', 'CN=Bob')
            if ($Continuation) { $expected += 'CN=Carol' }
            $result.Attributes['member'] | Should -Be $expected
            ($result.Attributes['member'] -is [object[]]) | Should -BeTrue
            @($result.Attributes.Keys | Where-Object { $_ -match ';range=' }) | Should -HaveCount 0
            $fixture.State.Index | Should -Be $(if ($Continuation) { 2 } else { 1 })
            if ($Continuation) { $fixture.State.Timeouts[1] | Should -Be ([timespan]::FromSeconds(5)) }
        }

        It 'decodes ranged membership from server byte values on initial and continuation responses' {
            $first = [System.DirectoryServices.Protocols.DirectoryAttribute]::new()
            [void]$first.Add([Text.Encoding]::UTF8.GetBytes('CN=Alice'))
            $last = [System.DirectoryServices.Protocols.DirectoryAttribute]::new()
            [void]$last.Add([Text.Encoding]::UTF8.GetBytes('CN=Bob'))
            $fixture = New-ADFixture @(
                (New-ADResponse -Entries @((New-ADEntry ([ordered]@{ 'member;range=0-0' = $first })))),
                (New-ADResponse -Entries @((New-ADEntry ([ordered]@{ 'member;range=1-*' = $last }))))
            )
            $result = $script:MaesterModule.Invoke({ param($c, $b)
                $entry = Invoke-MtLdapSearch -Connection $c -SearchBase $b -Attributes member -PageSize 0 -AsAttributeBag
                Complete-MtADQueryRange -Connection $c -Entry $entry -Timeout ([timespan]::FromSeconds(30))
            }, $fixture.Connection, $script:ADBase)
            $result.Attributes['member'] | Should -Be @('CN=Alice', 'CN=Bob')
        }
        It 'follows unsolicited contiguous member ranges via base-scope requests until the final chunk' {
            $first = New-ADEntry ([ordered]@{ 'member;range=0-1' = [object[]]@('A', 'B') })
            $middle = New-ADEntry ([ordered]@{ 'member;range=2-3' = [object[]]@('C', 'D') })
            $last = New-ADEntry ([ordered]@{ 'member;range=4-*' = [object[]]@('E') })
            $fixture = New-ADFixture @((New-ADResponse -Entries @($middle)), (New-ADResponse -Entries @($last)))
            $result = $script:MaesterModule.Invoke({ param($c, $e) Complete-MtADQueryRange -Connection $c -Entry $e -Timeout ([timespan]::FromSeconds(5)) }, $fixture.Connection, $first)
            $result.Attributes['member'] | Should -HaveCount 5
            ($result.Attributes['member'] -join ',') | Should -Be 'A,B,C,D,E'
            $result.Attributes.Contains('member;range=0-1') | Should -BeFalse
            $fixture.State.Requests | Should -HaveCount 2
            foreach ($index in 0..1) {
                $request = $fixture.State.Requests[$index]
                $request.DistinguishedName | Should -Be $script:ADDn
                $request.Scope | Should -Be ([System.DirectoryServices.Protocols.SearchScope]::Base)
                @($request.Controls | Where-Object { $_ -is [System.DirectoryServices.Protocols.DomainScopeControl] }) | Should -HaveCount 1
                @($request.Controls | Where-Object { $_ -is [System.DirectoryServices.Protocols.PageResultRequestControl] }) | Should -HaveCount 0
            }
            @($fixture.State.Requests[0].Attributes) | Should -HaveCount 1
            @($fixture.State.Requests[1].Attributes) | Should -HaveCount 1
            $fixture.State.Requests[0].Attributes[0] | Should -Be 'member;range=2-*'
            $fixture.State.Requests[1].Attributes[0] | Should -Be 'member;range=4-*'
            $fixture.State.Timeouts | Should -Be @([timespan]::FromSeconds(5), [timespan]::FromSeconds(5))
        }

        It 'normalizes an initially final range without requesting another page' {
            $entry = New-ADEntry ([ordered]@{ 'member;range=0-*' = [object[]]@('A') })
            $fixture = New-ADFixture @()
            $result = $script:MaesterModule.Invoke({ param($c, $e) Complete-MtADQueryRange -Connection $c -Entry $e -Timeout ([timespan]::FromSeconds(5)) }, $fixture.Connection, $entry)
            $result.Attributes['member'] | Should -HaveCount 1
            $result.Attributes['member'][0] | Should -Be 'A'
            $fixture.State.Index | Should -Be 0
        }

        It 'leaves a nonranged attribute intact without additional requests' {
            $entry = New-ADEntry ([ordered]@{ member = [object[]]@('A') })
            $fixture = New-ADFixture @()
            $result = $script:MaesterModule.Invoke({ param($c, $e) Complete-MtADQueryRange -Connection $c -Entry $e -Timeout ([timespan]::FromSeconds(5)) }, $fixture.Connection, $entry)
            $result.Attributes['member'] | Should -HaveCount 1
            $result.Attributes['member'][0] | Should -Be 'A'
            $fixture.State.Index | Should -Be 0
        }

        It 'rejects missing entries, wrong DNs, discontinuities, mismatched lengths and ambiguous continuations' {
            $cases = @(
                @{ Name = 'missing'; Entries = @(); Message = '*original entry*' }
                @{ Name = 'multiple entries'; Entries = @((New-ADEntry ([ordered]@{ 'member;range=1-*' = [object[]]@('B') })), (New-ADEntry ([ordered]@{ 'member;range=1-*' = [object[]]@('C') }))); Message = '*original entry*' }
                @{ Name = 'wrong DN'; Entries = @((New-ADEntry -Attributes ([ordered]@{ 'member;range=1-*' = [object[]]@('B') }) -Dn 'CN=Other,DC=contoso,DC=com')); Message = '*original entry*' }
                @{ Name = 'missing range'; Entries = @((New-ADEntry ([ordered]@{ member = [object[]]@('B') }))); Message = '*missing or ambiguous*' }
                @{ Name = 'out of sequence'; Entries = @((New-ADEntry ([ordered]@{ 'member;range=2-*' = [object[]]@('B') }))); Message = '*not contiguous*' }
                @{ Name = 'size mismatch'; Entries = @((New-ADEntry ([ordered]@{ 'member;range=1-3' = [object[]]@('B') }))); Message = '*length did not match*' }
                @{ Name = 'ambiguous'; Entries = @((New-ADEntry ([ordered]@{ 'member;range=1-*' = [object[]]@('B'); 'member;range=2-*' = [object[]]@('C') }))); Message = '*missing or ambiguous*' }
            )
            foreach ($case in $cases) {
                $entry = New-ADEntry ([ordered]@{ 'member;range=0-0' = [object[]]@('A') })
                $fixture = New-ADFixture @((New-ADResponse -Entries $case.Entries))
                { $script:MaesterModule.Invoke({ param($c, $e) Complete-MtADQueryRange -Connection $c -Entry $e -Timeout ([timespan]::FromSeconds(5)) }, $fixture.Connection, $entry) } | Should -Throw $case.Message -Because $case.Name
                $entry.Attributes.Contains('member;range=0-0') | Should -BeTrue
                $entry.Attributes.Contains('member') | Should -BeFalse
            }
        }

        It 'rejects an ambiguous nonranged attribute and an invalid initial range length' {
            foreach ($attributes in @(
                ([ordered]@{ member = [object[]]@('A'); 'member;range=0-*' = [object[]]@('B') }),
                ([ordered]@{ 'member;range=0-2' = [object[]]@('A') })
            )) {
                $fixture = New-ADFixture @()
                $entry = New-ADEntry $attributes
                { $script:MaesterModule.Invoke({ param($c, $e) Complete-MtADQueryRange -Connection $c -Entry $e -Timeout ([timespan]::FromSeconds(5)) }, $fixture.Connection, $entry) } | Should -Throw
                $fixture.State.Index | Should -Be 0
            }
        }
    }
}
