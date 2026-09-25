BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    Add-Type -AssemblyName System.Net.Http
}

Describe 'Invoke-MtGraphRequestCache' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GraphCache = @{}
        }
        $global:MtGraphRetryTest = @{ Calls = 0; Failures = 1; StatusCode = 500; RetryAfter = $null }
        Mock Start-Sleep -ModuleName Maester {}
        Mock Invoke-MgGraphRequest -ModuleName Maester {
            $test = $global:MtGraphRetryTest
            $test.Calls++
            if ($test.Calls -le $test.Failures) {
                $response = [System.Net.Http.HttpResponseMessage]::new($test.StatusCode)
                if ($test.RetryAfter) {
                    $response.Headers.RetryAfter = [System.Net.Http.Headers.RetryConditionHeaderValue]::new([TimeSpan]::FromSeconds($test.RetryAfter))
                }
                throw [Microsoft.Graph.PowerShell.Authentication.Helpers.HttpResponseException]::new('Graph error', $response)
            }
            @{ value = @('ok') }
        }
    }

    AfterEach {
        Remove-Variable -Name MtGraphRetryTest -Scope Global -ErrorAction SilentlyContinue
    }

    Context 'Transient server errors' {
        It 'Retries a GET that returns <StatusCode>' -ForEach @(
            @{ StatusCode = 500 }
            @{ StatusCode = 502 }
        ) {
            $global:MtGraphRetryTest.StatusCode = $StatusCode
            InModuleScope Maester {
                $result = Invoke-MtGraphRequestCache -Uri 'https://graph.microsoft.com/v1.0/users' -OutputType PSObject
                $result.value | Should -Be 'ok'
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 2 -Exactly
        }

        It 'Retries a runHuntingQuery POST' {
            InModuleScope Maester {
                $result = Invoke-MtGraphRequestCache -Method POST -Uri 'https://graph.microsoft.com/beta/security/runHuntingQuery' -Body '{"Query":"DeviceInfo"}' -OutputType PSObject
                $result.value | Should -Be 'ok'
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 2 -Exactly
        }

        It 'Rethrows the original error after two retries' {
            $global:MtGraphRetryTest.Failures = 3
            InModuleScope Maester {
                { Invoke-MtGraphRequestCache -Uri 'https://graph.microsoft.com/v1.0/users' -OutputType PSObject } | Should -Throw 'Graph error'
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 3 -Exactly
            Should -Invoke Start-Sleep -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Seconds -eq 2 }
            Should -Invoke Start-Sleep -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Seconds -eq 4 }
        }

        It 'Waits for Retry-After when Graph sends it' {
            $global:MtGraphRetryTest.RetryAfter = 7
            InModuleScope Maester {
                $null = Invoke-MtGraphRequestCache -Uri 'https://graph.microsoft.com/v1.0/users' -OutputType PSObject
            }
            Should -Invoke Start-Sleep -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Seconds -eq 7 }
        }

        It 'Caps Retry-After at 30 seconds' {
            $global:MtGraphRetryTest.RetryAfter = 600
            InModuleScope Maester {
                $null = Invoke-MtGraphRequestCache -Uri 'https://graph.microsoft.com/v1.0/users' -OutputType PSObject
            }
            Should -Invoke Start-Sleep -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Seconds -eq 30 }
        }
    }

    Context 'Errors that are not retried' {
        It 'Does not retry a GET that returns <StatusCode>' -ForEach @(
            @{ StatusCode = 400 }
            @{ StatusCode = 403 }
            @{ StatusCode = 404 }
            @{ StatusCode = 503 }
        ) {
            $global:MtGraphRetryTest.StatusCode = $StatusCode
            InModuleScope Maester {
                { Invoke-MtGraphRequestCache -Uri 'https://graph.microsoft.com/v1.0/users' -OutputType PSObject } | Should -Throw 'Graph error'
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly
        }

        It 'Does not retry an error without a response' {
            Mock Invoke-MgGraphRequest -ModuleName Maester {
                throw [System.AggregateException]::new('Too many retries performed.')
            }
            InModuleScope Maester {
                { Invoke-MtGraphRequestCache -Uri 'https://graph.microsoft.com/v1.0/users' -OutputType PSObject } | Should -Throw '*Too many retries performed*'
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly
        }

        It 'Does not retry a POST to <Path>' -ForEach @(
            @{ Path = 'users' }
            @{ Path = '$batch' }
        ) {
            InModuleScope Maester -Parameters @{ Path = $Path } {
                param($Path)
                { Invoke-MtGraphRequestCache -Method POST -Uri "https://graph.microsoft.com/v1.0/$Path" -Body '{}' -OutputType PSObject } | Should -Throw 'Graph error'
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly
        }
    }
}
