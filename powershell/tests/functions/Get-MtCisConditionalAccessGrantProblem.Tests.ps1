Describe 'Get-MtCisConditionalAccessGrantProblem' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Get-MtCisConditionalAccessGrantProblem

        # Builds a policy from a grant hashtable and returns the object that Graph returns.
        function New-GrantPolicy {
            param([hashtable] $Grant)
            @{ displayName = 'Test policy'; state = 'enabled'; grantControls = $Grant } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }
    }

    It 'Passes a single multifactor authentication control' {
        $policy = New-GrantPolicy @{ builtInControls = @('mfa'); operator = 'OR' }
        @(Get-MtCisConditionalAccessGrantProblem -Policy $policy) | Should -HaveCount 0
    }

    It 'Reports multifactor authentication or a compliant device joined with OR' {
        $policy = New-GrantPolicy @{ builtInControls = @('mfa', 'compliantDevice'); operator = 'OR' }
        $problems = @(Get-MtCisConditionalAccessGrantProblem -Policy $policy)
        $problems | Should -HaveCount 1
        $problems[0] | Should -Be 'grant operator is OR'
    }

    It 'Passes multifactor authentication and a compliant device joined with AND' {
        $policy = New-GrantPolicy @{ builtInControls = @('mfa', 'compliantDevice'); operator = 'AND' }
        @(Get-MtCisConditionalAccessGrantProblem -Policy $policy) | Should -HaveCount 0
    }

    It 'Passes a block on its own' {
        $policy = New-GrantPolicy @{ builtInControls = @('block'); operator = 'OR' }
        @(Get-MtCisConditionalAccessGrantProblem -Policy $policy) | Should -HaveCount 0
    }

    It 'Reports a block combined with multifactor authentication' {
        $policy = New-GrantPolicy @{ builtInControls = @('block', 'mfa'); operator = 'AND' }
        @(Get-MtCisConditionalAccessGrantProblem -Policy $policy) | Should -HaveCount 1
    }

    It 'Reports a password change and multifactor authentication joined with OR' {
        $policy = New-GrantPolicy @{ builtInControls = @('passwordChange', 'mfa'); operator = 'OR' }
        @(Get-MtCisConditionalAccessGrantProblem -Policy $policy) | Should -HaveCount 1
    }

    It 'Passes an authentication strength without built-in controls' {
        $policy = New-GrantPolicy @{ builtInControls = @(); operator = 'OR'; authenticationStrength = @{ id = '00000000-0000-0000-0000-000000000004' } }
        @(Get-MtCisConditionalAccessGrantProblem -Policy $policy) | Should -HaveCount 0
    }

    It 'Reports an authentication strength joined with a compliant device by OR' {
        $policy = New-GrantPolicy @{ builtInControls = @('compliantDevice'); operator = 'OR'; authenticationStrength = @{ id = '00000000-0000-0000-0000-000000000004' } }
        @(Get-MtCisConditionalAccessGrantProblem -Policy $policy) | Should -HaveCount 1
    }

    It 'Passes an authentication strength joined with a compliant device by AND' {
        $policy = New-GrantPolicy @{ builtInControls = @('compliantDevice'); operator = 'AND'; authenticationStrength = @{ id = '00000000-0000-0000-0000-000000000004' } }
        @(Get-MtCisConditionalAccessGrantProblem -Policy $policy) | Should -HaveCount 0
    }

    It 'Reports a block combined with an authentication strength' {
        $policy = New-GrantPolicy @{ builtInControls = @('block'); operator = 'AND'; authenticationStrength = @{ id = '00000000-0000-0000-0000-000000000004' } }
        @(Get-MtCisConditionalAccessGrantProblem -Policy $policy) | Should -HaveCount 1
    }

    It 'Passes a policy without grant controls' {
        $policy = @{ displayName = 'Session policy'; state = 'enabled' } | ConvertTo-Json | ConvertFrom-Json
        @(Get-MtCisConditionalAccessGrantProblem -Policy $policy) | Should -HaveCount 0
    }
}
