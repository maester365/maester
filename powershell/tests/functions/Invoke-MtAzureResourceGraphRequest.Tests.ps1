BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    $script:createdStubs = @()
    foreach ($cmd in 'Invoke-AzRestMethod', 'Get-AzContext') {
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

Describe 'Invoke-MtAzureResourceGraphRequest' -Tag 'Unit' {
    BeforeEach {
        Mock -ModuleName Maester Get-AzContext { [pscustomobject]@{ Environment = [pscustomobject]@{ ResourceManagerUrl = 'https://management.azure.com/' } } }
    }

    It 'returns the rows of a successful query' {
        Mock -ModuleName Maester Invoke-AzRestMethod { [pscustomobject]@{ StatusCode = 200; Content = '{"data":[{"name":"v1"},{"name":"v2"}]}' } }

        $result = Invoke-MtAzureResourceGraphRequest -Query 'Resources'

        $result.name | Should -Be @('v1', 'v2')
    }

    It 'throws on a <Status> response instead of returning nothing' -ForEach @(
        @{ Status = 403 }
        @{ Status = 429 }
        @{ Status = 500 }
    ) {
        Mock -ModuleName Maester Invoke-AzRestMethod { [pscustomobject]@{ StatusCode = $Status; Content = '{"error":"denied"}' } }.GetNewClosure()

        { Invoke-MtAzureResourceGraphRequest -Query 'Resources' } | Should -Throw "*Status code: $Status*"
    }
}
