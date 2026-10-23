BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Test-MtConditionalAccessWhatIf' -Tag 'Unit' {
    BeforeAll {
        $script:userId = '00000000-0000-0000-0000-0000000000b1'
        $script:appId = '00000002-0000-0ff1-ce00-000000000000'
    }

    It 'returns only the policies that apply' {
        Mock -ModuleName Maester Invoke-MgGraphRequest {
            [pscustomobject]@{ value = @(
                    [pscustomobject]@{ id = 'p1'; policyApplies = $true }
                    [pscustomobject]@{ id = 'p2'; policyApplies = $false }
                ) }
        }

        $result = Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId

        @($result).id | Should -Be @('p1')
    }

    It 'throws when the evaluation call fails, so a failure is not read as "no policy applies"' {
        Mock -ModuleName Maester Invoke-MgGraphRequest { throw 'Insufficient privileges to complete the operation.' }

        { Test-MtConditionalAccessWhatIf -UserId $script:userId -IncludeApplications $script:appId } |
            Should -Throw '*Insufficient privileges*'
    }
}
