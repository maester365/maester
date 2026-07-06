Describe 'Add-MtTestResultDetail' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    }

    BeforeEach {
        & (Get-Module Maester) {
            $__MtSession.TestResultDetail = @{}
            $__MtSession.TestResultDetailPending = @()
        }

        Mock -ModuleName Maester Get-MtPesterTagValue { return $null }
    }

    It 'buffers details when TestName is omitted and the Pester test name is not visible from module scope' {
        Add-MtTestResultDetail -Result 'Captured result detail'

        $pendingDetail = & (Get-Module Maester) {
            $__MtSession.TestResultDetailPending | Select-Object -First 1
        }

        $pendingDetail.Detail.TestTitle | Should -BeNullOrEmpty
        $pendingDetail.Detail.TestResult | Should -Be 'Captured result detail'
    }

    It 'attaches a pending detail to the matching converted Pester test' {
        $capturedAt = Get-Date
        $scriptBlock = { 'sample' }
        $block = [PSCustomObject]@{
            Name         = 'Sample'
            ExpandedName = 'Sample'
            Result       = 'Failed'
            Tag          = @()
        }
        $test = [PSCustomObject]@{
            ExpandedName = 'MT.9999: Pending detail test'
            Name         = 'MT.9999: Pending detail test'
            Result       = 'Failed'
            ErrorRecord  = @()
            ExecutedAt   = $capturedAt.AddMilliseconds(-50)
            Duration     = [TimeSpan]::FromSeconds(1)
            Block        = $block
            Tag          = @()
            ScriptBlock  = $scriptBlock
        }
        $pesterResults = [PSCustomObject]@{
            Tests             = @($test)
            Containers        = @([PSCustomObject]@{ Blocks = @($block) })
            Result            = 'Failed'
            ExecutedAt        = $capturedAt
            Duration          = [TimeSpan]::FromSeconds(1)
            UserDuration      = [TimeSpan]::FromSeconds(1)
            DiscoveryDuration = [TimeSpan]::Zero
            FrameworkDuration = [TimeSpan]::Zero
        }

        & (Get-Module Maester) {
            param($CapturedAt)

            $__MtSession.TestResultDetailPending = @(
                [PSCustomObject]@{
                    CapturedAt = $CapturedAt
                    Detail     = @{
                        TestTitle       = $null
                        TestDescription = $null
                        TestResult      = 'Captured result detail'
                        TestSkipped     = $null
                        SkippedReason   = $null
                        TestInvestigate = $false
                        Severity        = 'Medium'
                        Service         = $null
                    }
                }
            )
        } $capturedAt

        Mock -ModuleName Maester Test-MtConnection { return $false }
        Mock -ModuleName Maester Get-MtLatestModuleVersion { return $null }
        Mock -ModuleName Maester Get-MtModuleVersion { return '0.0.0' }
        Mock -ModuleName Maester Get-MtMaesterConfigTestSetting { return $null }

        $convertedResults = & (Get-Module Maester) {
            param($PesterResults)

            ConvertTo-MtMaesterResult -PesterResults $PesterResults
        } $pesterResults

        $convertedResults.Tests[0].ResultDetail.TestResult | Should -Be 'Captured result detail'
        $convertedResults.Tests[0].Severity | Should -Be 'Medium'
    }
}
