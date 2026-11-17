BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Invoke-MtGraphSecurityQuery' {
    BeforeEach {
        $script:MtHuntingQueryTest = @{
            CallsByQuery = @{}
            Failures = 0
            FailQuery = $null
            StatusCode = 429
        }
        Mock Start-Sleep -ModuleName Maester {}
        Mock Invoke-MtGraphRequest -ModuleName Maester {
            $request = $Body | ConvertFrom-Json
            $test = $script:MtHuntingQueryTest
            $test.CallsByQuery[$request.Query]++
            if ($test.CallsByQuery[$request.Query] -le $test.Failures -or $request.Query -eq $test.FailQuery) {
                $response = [System.Net.Http.HttpResponseMessage]::new($test.StatusCode)
                throw [Microsoft.Graph.PowerShell.Authentication.Helpers.HttpResponseException]::new('Hunting query failed', $response)
            }
            [pscustomobject]@{
                Results = @(
                    if ($request.Query -ne 'EmptyQuery') {
                        [pscustomobject]@{ Id = $request.Query; Details = '{"Count":2}' }
                    }
                )
                Schema = @([pscustomobject]@{ Name = 'Details'; Type = 'Object' })
            }
        }
    }

    AfterEach {
        Remove-Variable -Name MtHuntingQueryTest -Scope Script -ErrorAction SilentlyContinue
    }

    It 'Sends the query and timespan through the Graph transport' {
        $result = Invoke-MtGraphSecurityQuery -Query 'DeviceInfo | take 1' -Timespan 'PT6H'

        $result.Id | Should -Be 'DeviceInfo | take 1'
        $result.Details.Count | Should -Be 2
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $ApiVersion -eq 'beta' -and $RelativeUri -eq 'security/runHuntingQuery' -and
            $Method -eq 'POST' -and $OutputType -eq 'PSObject' -and
            ($Body | ConvertFrom-Json).Query -eq 'DeviceInfo | take 1' -and
            ($Body | ConvertFrom-Json).Timespan -eq 'PT6H'
        }
        Should -Not -Invoke Start-Sleep -ModuleName Maester
    }

    It 'Returns no rows for a successful empty query' {
        @(Invoke-MtGraphSecurityQuery -Query 'EmptyQuery').Count | Should -Be 0
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 1 -Exactly
        Should -Not -Invoke Start-Sleep -ModuleName Maester
    }

    It 'Keeps successful pipeline query results separate' {
        $results = @('FirstQuery', 'SecondQuery' | Invoke-MtGraphSecurityQuery)

        $results.Id | Should -Be @('FirstQuery', 'SecondQuery')
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 2 -Exactly
    }

    It 'Does not reuse results when the next pipeline query succeeds with no rows' {
        $results = @('FirstQuery', 'EmptyQuery' | Invoke-MtGraphSecurityQuery)

        $results.Count | Should -Be 1
        $results[0].Id | Should -Be 'FirstQuery'
    }

    It 'Succeeds after <Failures> throttled attempts' -ForEach @(
        @{ Failures = 1 }
        @{ Failures = 2 }
    ) {
        $script:MtHuntingQueryTest.Failures = $Failures

        $results = @(Invoke-MtGraphSecurityQuery -Query 'DeviceInfo')

        $results.Count | Should -Be 1
        $results[0].Id | Should -Be 'DeviceInfo'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times ($Failures + 1) -Exactly
        Should -Invoke Start-Sleep -ModuleName Maester -Times $Failures -Exactly -ParameterFilter { $Seconds -eq 1 }
    }

    It 'Throws the Graph error after three throttled attempts instead of returning an empty result' {
        $script:MtHuntingQueryTest.Failures = 3
        $rows = [System.Collections.Generic.List[object]]::new()
        $caught = $null
        try {
            Invoke-MtGraphSecurityQuery -Query 'DeviceInfo' | ForEach-Object { $rows.Add($_) }
        }
        catch { $caught = $_ }

        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Message | Should -Be 'Hunting query failed'
        [int]$caught.Exception.Response.StatusCode | Should -Be 429
        $rows.Count | Should -Be 0
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 3 -Exactly
        Should -Invoke Start-Sleep -ModuleName Maester -Times 2 -Exactly
    }

    It 'Does not repeat earlier pipeline results when a later query exhausts its attempts' {
        $script:MtHuntingQueryTest.FailQuery = 'SecondQuery'
        $rows = [System.Collections.Generic.List[object]]::new()
        $caught = $null
        try {
            'FirstQuery', 'SecondQuery', 'ThirdQuery' | Invoke-MtGraphSecurityQuery |
                ForEach-Object { $rows.Add($_) }
        }
        catch { $caught = $_ }

        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Message | Should -Be 'Hunting query failed'
        $rows.Count | Should -Be 1
        $rows[0].Id | Should -Be 'FirstQuery'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 4 -Exactly
        Should -Invoke Start-Sleep -ModuleName Maester -Times 2 -Exactly
    }

    It 'Starts a fresh retry budget for each pipeline query' {
        $script:MtHuntingQueryTest.Failures = 2

        $results = @('FirstQuery', 'SecondQuery' | Invoke-MtGraphSecurityQuery)

        $results.Id | Should -Be @('FirstQuery', 'SecondQuery')
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 6 -Exactly
        Should -Invoke Start-Sleep -ModuleName Maester -Times 4 -Exactly
    }

    It 'Does not retry HTTP <StatusCode>' -ForEach @(
        @{ StatusCode = 400 }
        @{ StatusCode = 403 }
        @{ StatusCode = 503 }
    ) {
        $script:MtHuntingQueryTest.Failures = 3
        $script:MtHuntingQueryTest.StatusCode = $StatusCode

        { Invoke-MtGraphSecurityQuery -Query 'DeviceInfo' } | Should -Throw 'Hunting query failed'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 1 -Exactly
        Should -Not -Invoke Start-Sleep -ModuleName Maester
    }

    It 'Propagates a transport error without an HTTP response' {
        Mock Invoke-MtGraphRequest -ModuleName Maester { throw 'Connection failed' }

        { Invoke-MtGraphSecurityQuery -Query 'DeviceInfo' } | Should -Throw 'Connection failed'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 1 -Exactly
        Should -Not -Invoke Start-Sleep -ModuleName Maester
    }
}

Describe 'Invoke-MtGraphSecurityQuery through the Graph transport and cache' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GraphCache = @{}
            $__MtSession.GraphBaseUri = $null
        }
        $script:MtHuntingTransportTest = @{ Calls = 0; FirstQuerySucceeds = $false }
        Mock Get-MgContext -ModuleName Maester { @{ Environment = 'Global'; TenantId = 'test-tenant' } }
        Mock Get-MgEnvironment -ModuleName Maester { @{ GraphEndpoint = 'https://graph.microsoft.com/' } }
        Mock Start-Sleep -ModuleName Maester {}
        Mock Invoke-MgGraphRequest -ModuleName Maester {
            $test = $script:MtHuntingTransportTest
            $test.Calls++
            if ($test.FirstQuerySucceeds -and $test.Calls -eq 1) {
                return [pscustomobject]@{
                    Results = @([pscustomobject]@{ Id = 'FirstQuery' })
                    Schema = @()
                }
            }
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
            throw [Microsoft.Graph.PowerShell.Authentication.Helpers.HttpResponseException]::new('Graph throttled hunting', $response)
        }
    }

    AfterEach {
        Remove-Variable -Name MtHuntingTransportTest -Scope Script -ErrorAction SilentlyContinue
        InModuleScope Maester { $__MtSession.GraphCache = @{} }
    }

    It 'Propagates exhausted throttling through the real Graph helpers' {
        { Invoke-MtGraphSecurityQuery -Query 'DeviceInfo' } | Should -Throw 'Graph throttled hunting'

        Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 3 -Exactly
        Should -Invoke Start-Sleep -ModuleName Maester -Times 2 -Exactly
        InModuleScope Maester { $__MtSession.GraphCache.Count | Should -Be 0 }
    }

    It 'Does not attribute cached earlier results to a failed pipeline query' {
        $script:MtHuntingTransportTest.FirstQuerySucceeds = $true
        $rows = [System.Collections.Generic.List[object]]::new()
        $caught = $null
        try {
            'FirstQuery', 'SecondQuery' | Invoke-MtGraphSecurityQuery | ForEach-Object { $rows.Add($_) }
        }
        catch { $caught = $_ }

        $caught.Exception.Message | Should -Be 'Graph throttled hunting'
        $rows.Count | Should -Be 1
        $rows[0].Id | Should -Be 'FirstQuery'
        Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 4 -Exactly
        InModuleScope Maester { $__MtSession.GraphCache.Count | Should -Be 1 }
    }
}
