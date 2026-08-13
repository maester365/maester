BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Test-MtConditionalAccessWhatIf' {
    BeforeEach {
        Mock -ModuleName Maester Invoke-MgGraphRequest {
            return [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id            = 'policy-id'
                        policyApplies = $true
                    }
                )
            }
        }
    }

    It 'uses a relative URI so Microsoft Graph PowerShell selects the connected cloud' {
        $result = Test-MtConditionalAccessWhatIf `
            -UserId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' `
            -IncludeApplications 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'

        Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Method -eq 'POST' -and
            [string] $Uri -eq '/beta/identity/conditionalAccess/evaluate' -and
            $OutputType -eq 'PSObject'
        }
        $result.id | Should -Be 'policy-id'
    }
}
