BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCaPlanHasOwner
}
Describe 'Conditional Access plan accountability' {
    BeforeEach {
        Mock Add-MtTestResultDetail -ModuleName Maester {}
        Mock Get-MtConditionalAccessPolicyPlan -ModuleName Maester { [pscustomobject]@{ id = 'plan'; owners = @('owner'); displayName = 'Plan' } }
    }
    It 'Passes when every plan records an owner' {
        Test-MtCaPlanHasOwner | Should -BeTrue
        Should -Invoke Get-MtConditionalAccessPolicyPlan -ModuleName Maester -Times 1 -ParameterFilter { $MetadataOnly }
    }
    It 'Fails on a plan without an owner without attributing administrative rights' {
        Mock Get-MtConditionalAccessPolicyPlan -ModuleName Maester { [pscustomobject]@{ id = 'plan'; owners = @(); displayName = 'Unowned' } }
        Test-MtCaPlanHasOwner | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -ParameterFilter { $GraphObjectType -eq 'ConditionalAccessPlan' -and $GraphObjects[0].id -eq 'plan' }
    }
    It 'Treats null and whitespace entries as missing ownership' {
        Mock Get-MtConditionalAccessPolicyPlan -ModuleName Maester { [pscustomobject]@{ id = 'plan'; owners = @($null, ' '); displayName = 'Unowned' } }
        Test-MtCaPlanHasOwner | Should -BeFalse
    }
    It 'Skips a tenant without plans even if standalone policies exist' {
        Mock Get-MtConditionalAccessPolicyPlan -ModuleName Maester { @() }
        Test-MtCaPlanHasOwner | Should -BeNullOrEmpty
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'NotApplicable' }
    }
    It 'Does not mistake a forbidden inventory read for an empty plans inventory' {
        Mock Get-MtConditionalAccessPolicyPlan -ModuleName Maester { throw '403 Forbidden' }
        { Test-MtCaPlanHasOwner } | Should -Throw '*403*'
    }
    It 'Preserves service errors instead of returning a successful governance result' {
        Mock Get-MtConditionalAccessPolicyPlan -ModuleName Maester { throw '503 unavailable' }
        { Test-MtCaPlanHasOwner } | Should -Throw '*503*'
    }
}
