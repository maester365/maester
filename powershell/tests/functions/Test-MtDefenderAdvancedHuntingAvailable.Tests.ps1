Describe 'Test-MtDefenderAdvancedHuntingAvailable' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # An internal helper, so it is not exported.
        Use-MtModuleFunction -Name Test-MtDefenderAdvancedHuntingAvailable
    }

    It 'reports available when the probe query answers' {
        Mock -ModuleName Maester Invoke-MtGraphSecurityQuery { @([pscustomobject]@{ DeviceId = 'd1' }) }

        Test-MtDefenderAdvancedHuntingAvailable | Should -BeTrue
    }

    It 'reports available when the table answers with no row' {
        # A table that resolves and returns nothing has answered. Reading an empty result as
        # unavailable would skip every tenant with no onboarded device for the wrong reason, and those
        # tenants have their own skip with its own wording.
        Mock -ModuleName Maester Invoke-MtGraphSecurityQuery { @() }

        Test-MtDefenderAdvancedHuntingAvailable | Should -BeTrue
    }

    It 'reports unavailable when the probe query throws' {
        Mock -ModuleName Maester Invoke-MtGraphSecurityQuery { throw '. Fix semantic errors in your query.' }

        Test-MtDefenderAdvancedHuntingAvailable | Should -BeFalse
    }

    It 'reports unavailable on the message that names the table too' {
        # The same unavailability reaches the caller as either message depending on the table, which is
        # why the catch does not match on the text.
        Mock -ModuleName Maester Invoke-MtGraphSecurityQuery { throw "Failed to resolve table or column expression named 'DeviceInfo'" }

        Test-MtDefenderAdvancedHuntingAvailable | Should -BeFalse
    }

    It 'asks only for what it needs, once' {
        # The probe runs before every check that depends on it, so a probe that pulled rows would be a
        # per-run cost on every tenant, including the ones where nothing is wrong.
        Mock -ModuleName Maester Invoke-MtGraphSecurityQuery { @() }

        $null = Test-MtDefenderAdvancedHuntingAvailable

        Should -Invoke -ModuleName Maester Invoke-MtGraphSecurityQuery -Times 1 -Exactly
        Should -Invoke -ModuleName Maester Invoke-MtGraphSecurityQuery -ParameterFilter {
            $Query -eq 'DeviceInfo | project DeviceId | take 1'
        } -Times 1 -Exactly
    }

    It 'does not swallow the failure silently' {
        Mock -ModuleName Maester Invoke-MtGraphSecurityQuery { throw 'boom' }

        $verbose = Test-MtDefenderAdvancedHuntingAvailable -Verbose 4>&1 |
            Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }

        ($verbose -join ' ') | Should -Match 'did not answer advanced hunting'
    }
}
