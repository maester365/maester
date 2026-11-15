BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    Add-Type -AssemblyName System.Net.Http

    # A small fake tenant behind Invoke-MgGraphRequest, for recording. All of it is synthetic.
    function global:Invoke-MtFakeGraph {
        param($Method, $Uri, $Body, $Headers, $OutputType)
        $global:MtFakeGraphCalls.Add([pscustomobject]@{ Method = $Method; Uri = "$Uri"; OutputType = $OutputType; Headers = $Headers })
        $u = "$Uri"
        # The first pattern that matches answers.
        $json = switch -Regex ($u) {
            'organization\?\$select=verifiedDomains' {
                '{"value":[{"verifiedDomains":[{"name":"contoso.com","isDefault":true},{"name":"contoso.onmicrosoft.com","isInitial":true}]}]}'
                break
            }
            'v1\.0/organization$' {
                '{"@odata.context":"https://graph.microsoft.com/v1.0/$metadata#organization","value":[{"id":"11111111-2222-3333-4444-555555555555","displayName":"Contoso Ltd","onPremisesSyncEnabled":true,"createdDateTime":"2020-01-02T03:04:05Z","verifiedDomains":[{"name":"contoso.com","isDefault":true,"isInitial":false}],"technicalNotificationMails":["it@contoso.com"]}]}'
                break
            }
            'skiptoken=REALTOKEN' {
                '{"value":[{"id":"bbbbbbbb-0000-4000-8000-000000000002","displayName":"Bob Smith","userPrincipalName":"bob@contoso.com","givenName":"Bob"}]}'
                break
            }
            'v1\.0/users' {
                '{"value":[{"id":"aaaaaaaa-0000-4000-8000-000000000001","displayName":"Alice Jones","userPrincipalName":"alice@contoso.com","mail":"alice@contoso.com","businessPhones":["+61 3 5555 1234"]},{"id":"cccccccc-0000-4000-8000-000000000003","displayName":"Carol (Guest)","userPrincipalName":"carol_fabrikam.com#EXT#@contoso.onmicrosoft.com"}],"@odata.nextLink":"https://graph.microsoft.com/v1.0/users?$top=2&$skiptoken=REALTOKEN"}'
                break
            }
            'roleManagement/directory/roleDefinitions' {
                '{"value":[{"id":"62e90394-69f5-4237-9190-012177145e10","displayName":"Global Administrator","isBuiltIn":true,"templateId":"62e90394-69f5-4237-9190-012177145e10"}]}'
                break
            }
            'directory/onPremisesSynchronization' {
                $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden)
                $message = 'GET https://graph.microsoft.com/v1.0/directory/onPremisesSynchronization HTTP/1.1 403 Forbidden request-id: 9f0e x-ms-ags-diagnostic: x ' +
                '{"error":{"code":"Authorization_RequestDenied","message":"Insufficient privileges for alice@contoso.com.","innerError":{"date":"2026-01-01T00:00:00","request-id":"9f0e"}}}'
                throw [Microsoft.Graph.PowerShell.Authentication.Helpers.HttpResponseException]::new($message, $response)
                break
            }
            '\$batch' {
                $request = $Body | ConvertFrom-Json
                $responses = foreach ($r in $request.requests) {
                    if ($r.url -like 'groups/dddddddd*') {
                        @{ id = "$($r.id)"; status = 200; body = @{ id = ($r.url -split '[/?]')[1]; displayName = 'Sales Team'; groupTypes = @() } }
                    } else {
                        @{ id = "$($r.id)"; status = 404; body = @{ error = @{ code = 'Request_ResourceNotFound'; message = 'Resource does not exist.'; innerError = @{ 'request-id' = 'x' } } } }
                    }
                }
                ConvertTo-Json -InputObject @{ responses = @($responses) } -Depth 10
            }
            default { throw "The fake tenant has no answer for $u" }
        }
        if ($OutputType -eq 'Json') { return $json }
        if ($OutputType -in 'PSObject', 'PSCustomObject') { return ($json | ConvertFrom-Json) }
        return ($json | ConvertFrom-Json -AsHashtable)
    }

    $script:FakeContext = [pscustomobject]@{
        TenantId = '11111111-2222-3333-4444-555555555555'; Account = 'alice@contoso.com'; AuthType = 'Delegated'
        Scopes = @('Directory.Read.All', 'Policy.Read.All'); Environment = 'Global'; ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
    }

    function script:Get-FixtureText {
        param([string] $Folder)
        (Get-ChildItem -LiteralPath $Folder -Recurse -File -Filter '*.json' | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
    }
}

AfterAll {
    InModuleScope Maester { $null = Disable-MtGraphFixture }
    Remove-Item -Path function:global:Invoke-MtFakeGraph -ErrorAction Ignore
}

Describe 'Graph fixture keys' {
    It 'gives the same key whatever the host, leading slash, query order, encoding and path case' {
        InModuleScope Maester {
            $a = Get-MtGraphFixtureKey -Uri 'https://graph.microsoft.com/v1.0/Users?$top=5&$select=id,displayName'
            $b = Get-MtGraphFixtureKey -Uri '/v1.0/users?$select=id%2CdisplayName&$top=5'
            $c = Get-MtGraphFixtureKey -Uri 'https://graph.microsoft.us/v1.0/users?$TOP=5&$select=id,displayName'
            $a.Key | Should -Be 'GET v1.0/users?$select=id,displayName&$top=5'
            $b.Key | Should -Be $a.Key
            $c.Key | Should -Be $a.Key
            $b.FileName | Should -Be $a.FileName
        }
    }

    It 'decodes form-encoded filters, as ConvertTo-QueryString writes them' {
        InModuleScope Maester {
            $query = ConvertTo-QueryString @{ '$filter' = "roleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10'" }
            $key = Get-MtGraphFixtureKey -Uri "v1.0/roleManagement/directory/roleAssignments?$query"
            $key.Key | Should -Be "GET v1.0/rolemanagement/directory/roleassignments?`$filter=roleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10'"
        }
    }

    It 'takes the API version from the uri, or from -ApiVersion for a batch request' {
        InModuleScope Maester {
            (Get-MtGraphFixtureKey -Uri 'beta/policies/authorizationPolicy').ApiVersion | Should -Be 'beta'
            (Get-MtGraphFixtureKey -Uri 'groups/abc' -ApiVersion beta).Key | Should -Be 'GET beta/groups/abc'
            (Get-MtGraphFixtureKey -Uri 'groups/abc' -ApiVersion beta).Key | Should -Be (Get-MtGraphFixtureKey -Uri 'https://graph.microsoft.com/beta/groups/abc').Key
        }
    }

    It 'hashes the body with its members sorted, so a hashtable body always gets the same key' {
        InModuleScope Maester {
            $a = Get-MtGraphFixtureKey -Method POST -Uri 'beta/directoryObjects/getByIds' -Body '{"ids":["a","b"],"types":["user"]}'
            $b = Get-MtGraphFixtureKey -Method POST -Uri 'beta/directoryObjects/getByIds' -Body (ConvertTo-Json -InputObject ([ordered]@{ types = @('user'); ids = @('a', 'b') }))
            $c = Get-MtGraphFixtureKey -Method POST -Uri 'beta/directoryObjects/getByIds' -Body '{"ids":["b","a"],"types":["user"]}'
            $a.Key | Should -Be $b.Key
            $a.Key | Should -Match '^POST beta/directoryobjects/getbyids body:[0-9a-f]{16}$'
            $c.Key | Should -Not -Be $a.Key -Because 'the order of an array is data'
        }
    }

    It 'names the file after the request, with a hash that tells requests with different queries apart' {
        InModuleScope Maester {
            $a = Get-MtGraphFixtureKey -Uri 'v1.0/users?$top=1'
            $b = Get-MtGraphFixtureKey -Uri 'v1.0/users?$top=2'
            $a.FileName | Should -Match '^get_v1\.0_users_[0-9a-f]{10}\.json$'
            $b.FileName | Should -Not -Be $a.FileName
        }
    }
}

Describe 'Graph record and replay is off by default' {
    BeforeEach {
        InModuleScope Maester { $null = Disable-MtGraphFixture; Clear-MtGraphCache }
        $global:MtFakeGraphCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Maester Get-MgContext { $script:FakeContext }
        Mock -ModuleName Maester Invoke-MgGraphRequest { Invoke-MtFakeGraph -Method $Method -Uri $Uri -Body $Body -OutputType $OutputType }
    }

    It 'reports the mode as Off' {
        (Get-MtGraphFixtureStatus).Mode | Should -Be 'Off'
    }

    It 'calls Invoke-MgGraphRequest with the parameters the caller gave' {
        $organization = Invoke-MtGraphRequest -RelativeUri 'organization'
        $organization.displayName | Should -Be 'Contoso Ltd'
        Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $OutputType -eq 'PSObject' -and "$Uri" -eq 'v1.0/organization' }
    }
}

Describe 'Graph recording' {
    BeforeEach {
        InModuleScope Maester { $null = Disable-MtGraphFixture; Clear-MtGraphCache }
        $global:MtFakeGraphCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Maester Get-MgContext { $script:FakeContext }
        Mock -ModuleName Maester Invoke-MgGraphRequest { Invoke-MtFakeGraph -Method $Method -Uri $Uri -Body $Body -OutputType $OutputType -Headers $Headers }
        $script:Root = Join-Path $TestDrive "record-$([guid]::NewGuid().ToString('n'))"
    }

    It 'needs a connection to record from' {
        Mock -ModuleName Maester Get-MgContext { $null }
        { Enable-MtGraphFixture -Mode Record -Path $script:Root -Scenario sample } | Should -Throw '*Connect-Maester*'
    }

    It 'returns live data while writing a sanitised fixture for every response' {
        $null = Enable-MtGraphFixture -Mode Record -Path $script:Root -Scenario sample
        $organization = Invoke-MtGraphRequest -RelativeUri 'organization'
        $organization.displayName | Should -Be 'Contoso Ltd' -Because 'the run that records sees the tenant as it is'
        $status = Disable-MtGraphFixture
        $status.Recorded | Should -Be 1

        $folder = Join-Path $script:Root 'sample'
        $text = Get-FixtureText -Folder $folder
        $text | Should -Not -Match '(?i)contoso'
        $text | Should -Not -Match '11111111-2222-3333-4444-555555555555'
        $text | Should -Not -Match 'alice'
        $text | Should -Match 'createdDateTime": "2020-01-02T03:04:05Z"' -Because 'dates are written back exactly as Graph sent them'

        $scenario = Get-Content (Join-Path $folder 'scenario.json') -Raw | ConvertFrom-Json
        $scenario.context.tenantId | Should -Match '^fa4efa4e-'
        $scenario.context.account | Should -Match '^user-[0-9a-f]{8}@fake[0-9a-f]{6}\.example$'
        $scenario.context.clientId | Should -Be '14d82eec-204b-4c2f-b7e8-296a70dab67e' -Because 'Microsoft Graph Command Line Tools is a well-known application ID in Maester'
        $fixture = Get-ChildItem (Join-Path $folder 'graph') | Select-Object -First 1 | Get-Content -Raw | ConvertFrom-Json
        $fixture.response.body.value[0].id | Should -Be $scenario.context.tenantId -Because 'the same GUID always gets the same fake GUID'
        Test-Path (Join-Path $folder '.salt') | Should -BeTrue
        Get-Content (Join-Path $folder '.gitignore') | Should -Contain '.salt'
    }

    It 'never writes request headers or tokens' {
        $null = Enable-MtGraphFixture -Mode Record -Path $script:Root -Scenario sample
        InModuleScope Maester {
            $null = Invoke-MtGraphTransport -Method GET -Uri 'v1.0/organization' -Headers @{ Authorization = 'Bearer eyJ0eXAiOiJKV1QiSECRET'; ConsistencyLevel = 'eventual' } -OutputType PSObject
        }
        $null = Disable-MtGraphFixture
        $text = Get-FixtureText -Folder (Join-Path $script:Root 'sample')
        $text | Should -Not -Match 'Bearer|eyJ0eXAi|SECRET|Authorization|ConsistencyLevel'
    }

    It 'keeps well-known IDs such as role templates' {
        $null = Enable-MtGraphFixture -Mode Record -Path $script:Root -Scenario sample
        $role = Get-MtRole | Select-Object -First 1
        $null = Disable-MtGraphFixture
        $role.id | Should -Be '62e90394-69f5-4237-9190-012177145e10'
        $text = Get-FixtureText -Folder (Join-Path $script:Root 'sample')
        $text | Should -Match '62e90394-69f5-4237-9190-012177145e10'
        $text | Should -Match '"displayName": "Global Administrator"' -Because 'a built-in role keeps its name'
    }

    It 'stores each page under a stable link, not under the skip token of the recording' {
        $null = Enable-MtGraphFixture -Mode Record -Path $script:Root -Scenario sample
        $users = @(Invoke-MtGraphRequest -RelativeUri 'users')
        $null = Disable-MtGraphFixture
        $users.Count | Should -Be 3
        $folder = Join-Path $script:Root 'sample'
        $text = Get-FixtureText -Folder $folder
        $text | Should -Not -Match 'REALTOKEN'
        $index = Get-Content (Join-Path $folder 'index.json') -Raw | ConvertFrom-Json
        $index.fixtures.key | Should -Contain 'GET v1.0/users'
        $index.fixtures.key | Should -Contain 'GET v1.0/users?$skiptoken=maester-page-2'
        $text | Should -Match '"@odata.nextLink": "https://graph.microsoft.com/v1.0/users\?\$skiptoken=maester-page-2"'
        $text | Should -Match 'guest-[0-9a-f]{8}#EXT#@fake[0-9a-f]{6}\.onmicrosoft\.com' -Because 'a guest UPN keeps #EXT# and the onmicrosoft.com suffix'
        $text | Should -Match '"displayName": "user-[0-9a-f]{6}"'
        $text | Should -Match '"redacted-[0-9a-f]{6}"' -Because 'phone numbers are personal fields'
    }

    It 'records a 403 with its status and error body, and still throws it' {
        $null = Enable-MtGraphFixture -Mode Record -Path $script:Root -Scenario sample
        { Invoke-MtGraphRequest -RelativeUri 'directory/onPremisesSynchronization' } | Should -Throw
        $null = Disable-MtGraphFixture
        $fixture = Get-ChildItem (Join-Path $script:Root 'sample/graph') -Filter '*onpremisessynchronization*' | Get-Content -Raw | ConvertFrom-Json
        $fixture.response.status | Should -Be 403
        $fixture.response.body.error.code | Should -Be 'Authorization_RequestDenied'
        $fixture.response.body.error.PSObject.Properties.Name | Should -Not -Contain 'innerError'
        $fixture.response.body.error.message | Should -Not -Match 'alice|contoso'
        (Get-FixtureText -Folder (Join-Path $script:Root 'sample')) | Should -Not -Match 'x-ms-ags-diagnostic|request-id'
    }

    It 'stores a batch as one fixture per request, including a 404' {
        $null = Enable-MtGraphFixture -Mode Record -Path $script:Root -Scenario sample
        $groups = @(Invoke-MtGraphRequest -RelativeUri 'groups' -UniqueId 'dddddddd-0000-4000-8000-000000000004', 'eeeeeeee-0000-4000-8000-000000000005')
        $null = Disable-MtGraphFixture
        $groups.Count | Should -Be 1
        $index = Get-Content (Join-Path $script:Root 'sample/index.json') -Raw | ConvertFrom-Json
        $index.fixtures.Count | Should -Be 2
        $index.fixtures.key | Should -Not -Contain 'POST v1.0/$batch' -Because 'the batch itself is not a fixture'
        ($index.fixtures | Where-Object status -EQ 404).key | Should -Match '^GET v1\.0/groups/fa4efa4e-'
    }

    It 'writes the responses as they are with -NoSanitize' {
        $null = Enable-MtGraphFixture -Mode Record -Path $script:Root -Scenario raw -NoSanitize
        $null = Invoke-MtGraphRequest -RelativeUri 'organization'
        $null = Disable-MtGraphFixture
        $text = Get-FixtureText -Folder (Join-Path $script:Root 'raw')
        $text | Should -Match 'Contoso Ltd'
        $text | Should -Match '11111111-2222-3333-4444-555555555555'
        Test-Path (Join-Path $script:Root 'raw/.salt') | Should -BeFalse
    }
}

Describe 'Graph replay' {
    BeforeAll {
        $script:Root = Join-Path $TestDrive 'replay'
        $tenant = 'fa4efa4e-0000-4000-8000-000000000000'
        $null = New-MtGraphFixture -Path $script:Root -Scenario sample -Uri 'v1.0/organization' -Response @{ value = @(@{ id = $tenant; displayName = 'organization-1'; onPremisesSyncEnabled = $true }) }
        $null = New-MtGraphFixture -Path $script:Root -Scenario sample -Uri 'v1.0/users' -Response @{
            value             = @(@{ id = 'fa4efa4e-0000-4000-8000-000000000001'; userPrincipalName = 'one@contoso.onmicrosoft.com' })
            '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?$skiptoken=maester-page-2'
        }
        $null = New-MtGraphFixture -Path $script:Root -Scenario sample -Uri 'v1.0/users?$skiptoken=maester-page-2' -Response @{ value = @(@{ id = 'fa4efa4e-0000-4000-8000-000000000002'; userPrincipalName = 'two@contoso.onmicrosoft.com' }) }
        $null = New-MtGraphFixture -Path $script:Root -Scenario sample -Uri 'v1.0/directory/onPremisesSynchronization' -StatusCode 403 -Response @{ error = @{ code = 'Authorization_RequestDenied'; message = 'Insufficient privileges to complete the operation.' } }
        $null = New-MtGraphFixture -Path $script:Root -Scenario sample -Uri 'v1.0/groups/fa4efa4e-0000-4000-8000-00000000000a' -Response @{ id = 'fa4efa4e-0000-4000-8000-00000000000a'; displayName = 'group-a' }
        $null = New-MtGraphFixture -Path $script:Root -Scenario sample -Uri 'v1.0/groups/fa4efa4e-0000-4000-8000-00000000000b' -StatusCode 404 -Response @{ error = @{ code = 'Request_ResourceNotFound'; message = 'Resource does not exist.' } }
    }

    BeforeEach {
        InModuleScope Maester { $null = Disable-MtGraphFixture; Clear-MtGraphCache }
        Mock -ModuleName Maester Invoke-MgGraphRequest { throw 'Replay must not call Microsoft Graph.' }
        $null = Enable-MtGraphFixture -Mode Replay -Path $script:Root -Scenario sample
    }

    AfterEach {
        $null = Disable-MtGraphFixture
    }

    It 'answers from the fixture set without calling Graph or needing a connection' {
        $organization = Invoke-MtGraphRequest -RelativeUri 'organization'
        $organization.onPremisesSyncEnabled | Should -BeTrue
        Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 0 -Exactly
        Test-MtConnection -Service Graph | Should -BeTrue
        InModuleScope Maester { (Get-MgContext).TenantId } | Should -Be 'fa4efa4e-0000-0000-0000-000000000000'
        (Get-MtGraphFixtureStatus).Served | Should -Be 1
    }

    It 'returns the shape the caller asked for' {
        InModuleScope Maester {
            (Invoke-MtGraphTransport -Uri 'v1.0/organization' -OutputType PSObject).value[0] | Should -BeOfType [pscustomobject]
            (Invoke-MtGraphTransport -Uri 'v1.0/organization').value[0] | Should -BeOfType [System.Collections.IDictionary]
            Invoke-MtGraphTransport -Uri 'v1.0/organization' -OutputType Json | Should -BeOfType [string]
        }
    }

    It 'follows nextLink through the pages' {
        $users = @(Invoke-MtGraphRequest -RelativeUri 'users')
        $users.userPrincipalName | Should -Be 'one@contoso.onmicrosoft.com', 'two@contoso.onmicrosoft.com'
    }

    It 'answers a batch request by request' {
        $groups = @(Invoke-MtGraphRequest -RelativeUri 'groups' -UniqueId 'fa4efa4e-0000-4000-8000-00000000000a', 'fa4efa4e-0000-4000-8000-00000000000b')
        $groups.displayName | Should -Be 'group-a' -Because 'a 404 in a batch returns nothing, as against Graph'
    }

    It 'throws a recorded 403 as Graph does, so a check takes the same branch' {
        $caught = $null
        try { Invoke-MtGraphRequest -RelativeUri 'directory/onPremisesSynchronization' } catch { $caught = $_ }
        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Response.StatusCode | Should -Be 403
        $caught.Exception.GetType().FullName | Should -Be 'Microsoft.Graph.PowerShell.Authentication.Helpers.HttpResponseException'
        $caught.Exception.Message | Should -Match 'Authorization_RequestDenied'
    }

    It 'throws a recorded 404 that Test-MtGraphNotFoundError recognises' {
        $caught = $null
        try { Invoke-MtGraphRequest -RelativeUri 'groups/fa4efa4e-0000-4000-8000-00000000000b' -DisableBatching } catch { $caught = $_ }
        InModuleScope Maester -Parameters @{ ErrorRecord = $caught } { param($ErrorRecord) Test-MtGraphNotFoundError -ErrorRecord $ErrorRecord } | Should -BeTrue
    }

    It 'fails a request with no fixture with an error that names it, and lists it for the run' {
        { Invoke-MtGraphRequest -RelativeUri 'policies/authorizationPolicy' -ApiVersion beta } | Should -Throw '*GET beta/policies/authorizationpolicy*'
        $status = Get-MtGraphFixtureStatus
        $status.MissingCount | Should -Be 1
        $status.Missing[0].Key | Should -Be 'GET beta/policies/authorizationpolicy'
        $status.Missing[0].File | Should -Match '^graph/get_beta_policies_authorizationpolicy_[0-9a-f]{10}\.json$'
        InModuleScope Maester { Write-MtGraphFixtureSummary 3>&1 } | Should -Match 'GET beta/policies/authorizationpolicy'
    }

    It 'does not mistake a missing fixture for a 404' {
        $caught = $null
        try { Invoke-MtGraphRequest -RelativeUri 'groups/fa4efa4e-0000-4000-8000-0000000000ff' -DisableBatching } catch { $caught = $_ }
        $caught.FullyQualifiedErrorId | Should -Match '^MtGraphFixtureMissing'
        InModuleScope Maester -Parameters @{ ErrorRecord = $caught } { param($ErrorRecord) Test-MtGraphNotFoundError -ErrorRecord $ErrorRecord } | Should -BeFalse
    }

    It 'refuses a direct Invoke-MgGraphRequest call it cannot replay, with an error the engine reports as a skip' {
        InModuleScope Maester {
            # Not mocked here: the replay stand-in answers.
            Remove-Item -Path alias:Invoke-MgGraphRequest -ErrorAction Ignore
            $caught = $null
            try { Invoke-MgGraphRequest -Method GET -Uri 'v1.0/admin/reportSettings' } catch { $caught = $_ }
            $caught.FullyQualifiedErrorId | Should -Match '^MtGraphFixtureUnsupported'
            (Get-MtGraphFixtureStatus).Unsupported.Uri | Should -Contain 'v1.0/admin/reportSettings'
        }
    }

    It 'restores Get-MgContext when it is turned off' {
        $null = Disable-MtGraphFixture
        InModuleScope Maester { Test-Path function:script:Get-MgContext } | Should -BeFalse
        InModuleScope Maester { Test-Path function:script:Invoke-MgGraphRequest } | Should -BeFalse
    }

    It 'refuses a fixture set that does not exist' {
        { Enable-MtGraphFixture -Mode Replay -Path $script:Root -Scenario nothing-here } | Should -Throw '*no Graph fixture set*'
    }

    It 'turns on from the environment variables' {
        $null = Disable-MtGraphFixture
        $saved = $env:MAESTER_GRAPH_FIXTURE_MODE, $env:MAESTER_GRAPH_FIXTURE_PATH, $env:MAESTER_GRAPH_FIXTURE_SCENARIO
        try {
            $env:MAESTER_GRAPH_FIXTURE_MODE = 'Replay'
            $env:MAESTER_GRAPH_FIXTURE_PATH = $script:Root
            $env:MAESTER_GRAPH_FIXTURE_SCENARIO = 'sample'
            InModuleScope Maester { Initialize-MtGraphFixture -NewRun }
            $status = Get-MtGraphFixtureStatus
            $status.Mode | Should -Be 'Replay'
            $status.Scenario | Should -Be 'sample'
        } finally {
            $env:MAESTER_GRAPH_FIXTURE_MODE, $env:MAESTER_GRAPH_FIXTURE_PATH, $env:MAESTER_GRAPH_FIXTURE_SCENARIO = $saved
        }
    }
}

Describe 'Record, then replay' {
    BeforeAll {
        $script:Root = Join-Path $TestDrive 'roundtrip'
    }

    It 'records a session from the tenant' {
        InModuleScope Maester { $null = Disable-MtGraphFixture; Clear-MtGraphCache }
        $global:MtFakeGraphCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Maester Get-MgContext { $script:FakeContext }
        Mock -ModuleName Maester Invoke-MgGraphRequest { Invoke-MtFakeGraph -Method $Method -Uri $Uri -Body $Body -OutputType $OutputType }

        $null = Enable-MtGraphFixture -Mode Record -Path $script:Root -Scenario tenant
        $script:RecordedOrganization = Invoke-MtGraphRequest -RelativeUri 'organization'
        $script:RecordedUsers = @(Invoke-MtGraphRequest -RelativeUri 'users')
        { Invoke-MtGraphRequest -RelativeUri 'directory/onPremisesSynchronization' } | Should -Throw
        $null = Disable-MtGraphFixture
        $script:RecordedUsers.Count | Should -Be 3
    }

    It 'replays it with no connection and no network, with the same results' {
        InModuleScope Maester { Clear-MtGraphCache }
        # No Get-MgContext mock here: there is no Graph connection, and replay reports the recorded one.
        Mock -ModuleName Maester Invoke-MgGraphRequest { throw 'Replay must not call Microsoft Graph.' }
        $null = Enable-MtGraphFixture -Mode Replay -Path $script:Root -Scenario tenant
        try {
            $organization = Invoke-MtGraphRequest -RelativeUri 'organization'
            $users = @(Invoke-MtGraphRequest -RelativeUri 'users')
            $caught = $null
            try { Invoke-MtGraphRequest -RelativeUri 'directory/onPremisesSynchronization' } catch { $caught = $_ }
            $context = InModuleScope Maester { Get-MgContext }
        } finally {
            $null = Disable-MtGraphFixture
        }

        Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 0 -Exactly
        $users.Count | Should -Be $script:RecordedUsers.Count
        $organization.onPremisesSyncEnabled | Should -Be $script:RecordedOrganization.onPremisesSyncEnabled
        $organization.id | Should -Match '^fa4efa4e-'
        $organization.id | Should -Be $context.TenantId -Because 'the organization ID and the tenant ID were the same GUID, and still are'
        $context.Scopes | Should -Be 'Directory.Read.All', 'Policy.Read.All'
        $caught.Exception.Response.StatusCode | Should -Be 403
    }
}

Describe 'Graph fixture sanitisation' {
    BeforeAll {
        $script:State = @{
            Salt = 'unit-test-salt'; WellKnownIds = [System.Collections.Generic.HashSet[string]]::new([string[]]@('62e90394-69f5-4237-9190-012177145e10'), [System.StringComparer]::OrdinalIgnoreCase)
            Domains = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase); DisplayNames = [System.Collections.Generic.Dictionary[string, string]]::new()
        }
    }

    It 'maps the same GUID to the same fake GUID, and never replaces a fake one again' {
        InModuleScope Maester -Parameters @{ State = $script:State } {
            param($State)
            $a = Protect-MtGraphFixtureData -Text 'id 0b7c6e8e-1111-4222-8333-944445555666' -State $State
            $b = Protect-MtGraphFixtureData -Text 'other 0B7C6E8E-1111-4222-8333-944445555666' -State $State
            $a | Should -Match '^id fa4efa4e-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            ($b -split ' ')[1].ToLowerInvariant() | Should -Be ($a -split ' ')[1]
            Protect-MtGraphFixtureData -Text $a -State $State | Should -Be $a
        }
    }

    It 'gives other fake values with another salt' {
        InModuleScope Maester -Parameters @{ State = $script:State } {
            param($State)
            $other = @{} + $State
            $other.Salt = 'another-salt'
            $guid = '0b7c6e8e-1111-4222-8333-944445555666'
            Protect-MtGraphFixtureData -Text $guid -State $other | Should -Not -Be (Protect-MtGraphFixtureData -Text $guid -State $State)
        }
    }

    It 'keeps well-known GUIDs' {
        InModuleScope Maester -Parameters @{ State = $script:State } {
            param($State)
            Protect-MtGraphFixtureData -Text "roleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10'" -State $State | Should -Be "roleDefinitionId eq '62e90394-69f5-4237-9190-012177145e10'"
        }
    }

    It 'replaces addresses, guest UPNs and domains, keeping the Microsoft suffixes' {
        InModuleScope Maester -Parameters @{ State = $script:State } {
            param($State)
            $upn = Protect-MtGraphFixtureData -Text 'alice@contoso.com' -State $State
            $upn | Should -Match '^user-[0-9a-f]{8}@fake[0-9a-f]{6}\.example$'
            Protect-MtGraphFixtureData -Text 'alice@contoso.com' -State $State | Should -Be $upn
            Protect-MtGraphFixtureData -Text 'carol_fabrikam.com#EXT#@contoso.onmicrosoft.com' -State $State | Should -Match '^guest-[0-9a-f]{8}#EXT#@fake[0-9a-f]{6}\.onmicrosoft\.com$'
            Protect-MtGraphFixtureData -Text 'https://contoso-admin.sharepoint.com/sites/x' -State $State | Should -Match '^https://fake[0-9a-f]{6}\.sharepoint\.com/sites/x$'
            # contoso.com is known now, from the address above.
            Protect-MtGraphFixtureData -Text 'v=spf1 include:mail.contoso.com -all' -State $State | Should -Match '^v=spf1 include:mail\.fake[0-9a-f]{6}\.example -all$'
            Protect-MtGraphFixtureData -Text 'notify no-reply@microsoft.com' -State $State | Should -Match '@microsoft\.com$' -Because "Microsoft's own domains are not the tenant's"
        }
    }

    It 'replaces display names of tenant objects but not of built-in ones, and the names in a later filter' {
        InModuleScope Maester -Parameters @{ State = $script:State } {
            param($State)
            $node = [System.Text.Json.Nodes.JsonNode]::Parse('{"value":[{"id":"0b7c6e8e-1111-4222-8333-944445555666","displayName":"Sales Team","groupTypes":[]},{"id":"0b7c6e8e-aaaa-4222-8333-944445555666","displayName":"Global Administrator","roleTemplateId":"62e90394-69f5-4237-9190-012177145e10"}]}')
            Protect-MtGraphFixtureData -Node $node -State $State
            $node['value'][0]['displayName'].GetValue[string]() | Should -Match '^group-[0-9a-f]{6}$'
            $node['value'][1]['displayName'].GetValue[string]() | Should -Be 'Global Administrator'
            $filter = Protect-MtGraphFixtureData -Text "v1.0/groups?`$filter=displayName eq 'Sales Team'" -Uri -State $State
            $filter | Should -Be ("v1.0/groups?`$filter=displayName eq '{0}'" -f $node['value'][0]['displayName'].GetValue[string]())
        }
    }
}
