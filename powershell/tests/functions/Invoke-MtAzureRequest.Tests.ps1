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

    Context 'Azure Resource Manager writes' {
        It 'does not hide a denied <Method> behind a $null result' -ForEach @(
            @{ Method = 'POST' }
            @{ Method = 'PATCH' }
            @{ Method = 'PUT' }
            @{ Method = 'DELETE' }
        ) {
            Mock -ModuleName Maester Invoke-AzRest {
                [pscustomobject]@{ StatusCode = 403; Content = '{"error":{"code":"AuthorizationFailed"}}' }
            }

            $result = Invoke-MtAzureRequest -RelativeUri 'providers/Microsoft.Authorization/roleAssignments' -Method $Method

            $result.error.code | Should -Be 'AuthorizationFailed'
        }
    }

    Context 'Microsoft Graph requests through Azure' {
        It 'still returns the error body for a 403 so the app commands can read it' {
            Mock -ModuleName Maester Get-AzContext { [pscustomobject]@{ Environment = [pscustomobject]@{ ExtendedProperties = @{ MicrosoftGraphUrl = 'https://graph.microsoft.com' } } } }
            Mock -ModuleName Maester Invoke-AzRest { [pscustomobject]@{ StatusCode = 403; Content = '{"error":{"code":"Forbidden"}}' } }

            $result = Invoke-MtAzureRequest -RelativeUri 'applications' -Graph

            $result.error.code | Should -Be 'Forbidden'
        }

        # Azure reports the Graph address without a trailing slash (https://graph.microsoft.com).
        It 'builds the request address from "<Base>" and "<Relative>"' -ForEach @(
            @{ Base = 'https://graph.microsoft.com'; Relative = 'applications' }
            @{ Base = 'https://graph.microsoft.com/'; Relative = 'applications' }
            @{ Base = 'https://graph.microsoft.com'; Relative = '/applications' }
            @{ Base = 'https://graph.microsoft.us'; Relative = 'servicePrincipals/abc/appRoleAssignments' }
        ) {
            $graphUrl = $Base
            Mock -ModuleName Maester Get-AzContext { [pscustomobject]@{ Environment = [pscustomobject]@{ ExtendedProperties = @{ MicrosoftGraphUrl = $graphUrl } } } }.GetNewClosure()
            Mock -ModuleName Maester Invoke-AzRest { [pscustomobject]@{ StatusCode = 200; Content = '{}' } }

            $null = Invoke-MtAzureRequest -RelativeUri $Relative -Graph

            $expected = '{0}/v1.0/{1}' -f $Base.TrimEnd('/'), $Relative.TrimStart('/')
            Should -Invoke Invoke-AzRest -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Uri.AbsoluteUri -eq $expected }
        }
    }
}
