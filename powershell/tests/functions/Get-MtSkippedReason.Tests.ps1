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

    It 'Accepts NotConnectedActiveDirectoryDNS in Add-MtTestResultDetail' {
        $validateSet = (Get-Command Add-MtTestResultDetail).Parameters['SkippedBecause'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -ExpandProperty ValidValues

        $validateSet | Should -Contain 'NotConnectedActiveDirectoryDNS'
    }

    It 'Returns the Active Directory DNS skip reason text' {
        $reason = InModuleScope Maester {
            Get-MtSkippedReason -SkippedBecause 'NotConnectedActiveDirectoryDNS'
        }

        $reason | Should -Match 'Active Directory DNS data could not be retrieved'
    }

    It 'Preserves the NotConnectedGitHub skip reason after merging main' {
        $validateSet = (Get-Command Add-MtTestResultDetail).Parameters['SkippedBecause'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -ExpandProperty ValidValues

        $validateSet | Should -Contain 'NotConnectedGitHub'
    }

    It 'Tells how to check non-.gov domains with a setting that exists, not with a command that does not' {
        $reason = InModuleScope Maester {
            Get-MtSkippedReason -SkippedBecause 'NotDotGovDomain'
        }

        $reason | Should -Match 'federal, executive branch, departments and agencies'
        $reason | Should -Match '"Id": "CISA\.MS\.EXO\.4\.3", "Parameters": \{ "Force": true \}'
        $reason | Should -Not -Match 'Test-MtCisaDmarcAggregateCisa'
    }

    It 'Returns the combined Entra licensing guidance text' {
        $reason = InModuleScope Maester {
            Get-MtSkippedReason -SkippedBecause 'NotLicensedEntraIDP2OrGovernance'
        }

        $reason | Should -Match 'Entra ID P2 or Entra ID Governance'
        $reason | Should -Match 'learn\.microsoft\.com/entra/fundamentals/licensing'
    }

    It 'Accepts NotSupportedAzureDevOpsAppPermission in Add-MtTestResultDetail' {
        $validateSet = (Get-Command Add-MtTestResultDetail).Parameters['SkippedBecause'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
            Select-Object -ExpandProperty ValidValues

        $validateSet | Should -Contain 'NotSupportedAzureDevOpsAppPermission'
    }

    It 'Returns the Azure DevOps user authentication skip reason text' {
        $reason = InModuleScope Maester {
            Get-MtSkippedReason -SkippedBecause 'NotSupportedAzureDevOpsAppPermission'
        }

        $reason | Should -Match 'service principals or managed identities'
    }
}
