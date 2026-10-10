BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Add-MtTestResultDetail skip handling inside try/catch' {
    BeforeEach {
        # Add-MtTestResultDetail keys the result by the current Pester test name.
        $pesterContext = [PSCustomObject]@{
            CurrentTest = [PSCustomObject]@{
                ExpandedName = 'Add-MtTestResultDetail skip probe'
                Tag          = @()
                Block        = [PSCustomObject]@{ Tag = @() }
            }
        }
        Set-Variable -Name ____Pester -Scope Global -Value $pesterContext
        InModuleScope Maester {
            $__MtSession.TestResultDetail = @{}
        }
    }

    AfterEach {
        Remove-Variable -Name ____Pester -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Re-raises a Pester skip passed in as -SkippedError instead of recording an error' {
        $skipRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new('is skipped, because of a custom reason'),
            'PesterTestSkipped',
            [System.Management.Automation.ErrorCategory]::InvalidResult,
            $null)

        { Add-MtTestResultDetail -SkippedBecause Error -SkippedError $skipRecord } | Should -Throw -ErrorId 'PesterTestSkipped'

        $detail = InModuleScope Maester { $__MtSession.TestResultDetail.Values | Select-Object -First 1 }
        $detail | Should -BeNullOrEmpty
    }

    It 'Records an ordinary error passed in as -SkippedError' {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new('Graph request failed'),
            'GraphRequestFailed',
            [System.Management.Automation.ErrorCategory]::NotSpecified,
            $null)

        { Add-MtTestResultDetail -SkippedBecause Error -SkippedError $errorRecord } | Should -Throw -ErrorId 'PesterTestSkipped'

        $detail = InModuleScope Maester { $__MtSession.TestResultDetail.Values | Select-Object -First 1 }
        $detail.TestSkipped | Should -Be 'Error'
        $detail.SkippedReason | Should -Match 'Graph request failed'
    }

    It 'Keeps the original skip reason when a test function skips from inside its try block (MT.1049, #2289)' {
        Mock -ModuleName Maester Get-MtLicenseInformation { 'P2' }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            @([pscustomobject]@{ displayName = 'Require MFA'; state = 'enabled'; conditions = [pscustomobject]@{ userRiskLevels = @(); signInRiskLevels = @() } })
        }

        { InModuleScope Maester { Test-MtCaMisconfiguredIDProtection } } | Should -Throw -ErrorId 'PesterTestSkipped'

        $detail = InModuleScope Maester { $__MtSession.TestResultDetail.Values | Select-Object -First 1 }
        $detail.TestSkipped | Should -Be 'Custom'
        $detail.SkippedReason | Should -Be 'There are no Conditional Access policies with risk controls configured.'
    }
}
