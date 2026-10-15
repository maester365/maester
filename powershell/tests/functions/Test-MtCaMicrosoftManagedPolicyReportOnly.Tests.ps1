Describe 'Test-MtCaMicrosoftManagedPolicyReportOnly' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCaMicrosoftManagedPolicyReportOnly

        function New-ManagedCaPolicy {
            param(
                [string]$Id = [guid]::NewGuid().ToString(),
                [string]$DisplayName,
                [string]$State = 'enabled',
                [datetime]$CreatedDateTime = (Get-Date).AddDays(-5)
            )
            return [PSCustomObject]@{
                id              = $Id
                displayName     = $DisplayName
                state           = $State
                createdDateTime = $CreatedDateTime
                grantControls   = [PSCustomObject]@{
                    builtInControls        = @('mfa')
                    authenticationStrength = $null
                    operator               = 'OR'
                }
            }
        }
    }

    Context 'No Microsoft-managed policies in the tenant' {
        It 'Should skip and return null, even when a customer policy is in report-only' {
            $script:SkippedBecause = $null
            $policies = @(
                New-ManagedCaPolicy -DisplayName 'ZT-001: Block Legacy Authentication' -State 'enabled'
                New-ManagedCaPolicy -DisplayName 'CA002 - Monitor SharePoint' -State 'enabledForReportingButNotEnforced'
            )
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policies }
            Mock -ModuleName Maester Add-MtTestResultDetail {
                param($SkippedBecause)
                $script:SkippedBecause = $SkippedBecause
            }

            Test-MtCaMicrosoftManagedPolicyReportOnly | Should -BeNull
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }
    }

    Context 'Microsoft-managed policies exist but none are in report-only' {
        It 'Should pass and return true' {
            $policies = @(
                New-ManagedCaPolicy -DisplayName 'Microsoft-managed: Multifactor authentication for all users' -State 'enabled'
                New-ManagedCaPolicy -DisplayName 'Microsoft-managed: Block legacy authentication' -State 'disabled'
            )
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policies }
            Mock -ModuleName Maester Add-MtTestResultDetail {}
            Mock -ModuleName Maester Get-GraphObjectMarkdown { 'policy-link' }

            Test-MtCaMicrosoftManagedPolicyReportOnly | Should -BeTrue
        }
    }

    Context 'A Microsoft-managed policy is still in report-only' {
        It 'Should fail and return false' {
            $policies = @(
                New-ManagedCaPolicy -DisplayName 'Microsoft-managed: Require remediation for high-risk users' -State 'enabledForReportingButNotEnforced'
            )
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policies }
            Mock -ModuleName Maester Add-MtTestResultDetail {}
            Mock -ModuleName Maester Get-GraphObjectMarkdown { 'policy-link' }

            Test-MtCaMicrosoftManagedPolicyReportOnly | Should -BeFalse
        }

        It 'Should fail when one managed policy is report-only even if others are on' {
            $policies = @(
                New-ManagedCaPolicy -DisplayName 'Microsoft-managed: Multifactor authentication for all users' -State 'enabled'
                New-ManagedCaPolicy -DisplayName 'Microsoft-managed: Block device code flow' -State 'enabledForReportingButNotEnforced'
            )
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $policies }
            Mock -ModuleName Maester Add-MtTestResultDetail {}
            Mock -ModuleName Maester Get-GraphObjectMarkdown { 'policy-link' }

            Test-MtCaMicrosoftManagedPolicyReportOnly | Should -BeFalse
        }
    }
}
