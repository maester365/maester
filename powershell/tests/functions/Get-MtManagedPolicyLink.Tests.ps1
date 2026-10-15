Describe 'Get-MtManagedPolicyLink' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Get-MtManagedPolicyLink
    }

    It 'escapes pipe characters in the policy displayName before building the link' {
        $script:captured = $null
        Mock -ModuleName Maester Get-GraphObjectMarkdown {
            $script:captured = $GraphObjects
            'policy-link'
        }

        $policy = [pscustomobject]@{
            id          = '00000000-0000-0000-0000-000000000001'
            displayName = 'Microsoft-managed: Require MFA | admins'
        }

        Get-MtManagedPolicyLink -Policy $policy | Should -Be 'policy-link'
        $script:captured.displayName | Should -Be 'Microsoft-managed: Require MFA \| admins'
    }
}
