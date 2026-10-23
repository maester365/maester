BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    $script:createdStubs = @()
    foreach ($cmd in 'Invoke-AzRest', 'Get-AzContext') {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            New-Item -Path "function:global:$cmd" -Value { } | Out-Null
            $script:createdStubs += $cmd
        }
    }
}

AfterAll {
    foreach ($cmd in $script:createdStubs) {
        Remove-Item -Path "function:global:$cmd" -ErrorAction SilentlyContinue
    }
}

Describe 'Invoke-MtAzureRequest' -Tag 'Unit' {
    Context 'Azure Resource Manager requests' {
        It 'returns the parsed body for a successful response' {
            Mock -ModuleName Maester Invoke-AzRest { [pscustomobject]@{ StatusCode = 200; Content = '{"value":[{"id":"a"}]}' } }

            $result = Invoke-MtAzureRequest -RelativeUri 'providers/Microsoft.Authorization/roleAssignments'

            $result.value.id | Should -Be 'a'
        }

        It 'returns $null when Azure answers <Status>, so callers can skip as not authorized' -ForEach @(
            @{ Status = 401 }
            @{ Status = 403 }
        ) {
            Mock -ModuleName Maester Invoke-AzRest {
                [pscustomobject]@{ StatusCode = $Status; Content = '{"error":{"code":"AuthorizationFailed"}}' }
            }.GetNewClosure()

            Invoke-MtAzureRequest -RelativeUri 'providers/Microsoft.Authorization/roleAssignments' | Should -BeNullOrEmpty
        }
    }

    Context 'Microsoft Graph requests through Azure' {
        It 'still returns the error body for a 403 so the app commands can read it' {
            Mock -ModuleName Maester Get-AzContext { [pscustomobject]@{ Environment = [pscustomobject]@{ ExtendedProperties = @{ MicrosoftGraphUrl = 'https://graph.microsoft.com' } } } }
            Mock -ModuleName Maester Invoke-AzRest { [pscustomobject]@{ StatusCode = 403; Content = '{"error":{"code":"Forbidden"}}' } }

            $result = Invoke-MtAzureRequest -RelativeUri 'applications' -Graph

            $result.error.code | Should -Be 'Forbidden'
        }
    }
}
