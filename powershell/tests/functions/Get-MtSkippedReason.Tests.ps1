BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Skipped reason metadata' {
    It 'Accepts NotLicensedEntraIDP2OrGovernance in Add-MtTestResultDetail' {
        $validateSet = (Get-Command Add-MtTestResultDetail).Parameters['SkippedBecause'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -ExpandProperty ValidValues

        $validateSet | Should -Contain 'NotLicensedEntraIDP2OrGovernance'
    }

    It 'Preserves the NotConnectedGitHub skip reason after merging main' {
        $validateSet = (Get-Command Add-MtTestResultDetail).Parameters['SkippedBecause'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -ExpandProperty ValidValues

        $validateSet | Should -Contain 'NotConnectedGitHub'
    }

    It 'Returns the combined Entra licensing guidance text' {
        $reason = InModuleScope Maester {
            Get-MtSkippedReason -SkippedBecause 'NotLicensedEntraIDP2OrGovernance'
        }

        $reason | Should -Match 'Entra ID P2 or Entra ID Governance'
        $reason | Should -Match 'learn\.microsoft\.com/entra/fundamentals/licensing'
    }
}
