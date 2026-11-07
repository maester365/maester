Describe 'Checks that must not pass when their data source returns nothing' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Both are native tests, so neither function is exported.
        Use-MtModuleFunction -Name Test-MtCisCustomerLockBox, Test-MtAdTombstoneLifetime
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null

        Mock -ModuleName Maester Get-MtLicenseInformation { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
        }
    }

    Context 'CIS.M365.1.3.6 customer lockbox' {
        It 'skips instead of passing when the organization configuration comes back empty' {
            # An empty collection filters to nothing, the count is zero, and zero was the pass.
            Mock -ModuleName Maester Get-MtExo { @() }

            $null -eq (Test-MtCisCustomerLockBox) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'skips instead of passing when the row carries no CustomerLockBoxEnabled property' {
            Mock -ModuleName Maester Get-MtExo { [pscustomobject]@{ Id = 'contoso' } }

            $null -eq (Test-MtCisCustomerLockBox) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'passes when the lockbox is enabled' {
            Mock -ModuleName Maester Get-MtExo { [pscustomobject]@{ Id = 'contoso'; CustomerLockBoxEnabled = 'True' } }

            Test-MtCisCustomerLockBox | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
            # A passing tenant must not be shown a failing row under the "Well done" heading.
            $script:TestResult | Should -Match '\| ✅ Pass \|'
            $script:TestResult | Should -Not -Match '❌ Fail'
        }

        It 'fails when the lockbox is disabled' {
            Mock -ModuleName Maester Get-MtExo { [pscustomobject]@{ Id = 'contoso'; CustomerLockBoxEnabled = 'False' } }

            Test-MtCisCustomerLockBox | Should -BeFalse
            $script:TestResult | Should -Match 'does not have the customer lockbox enabled'
            $script:TestResult | Should -Match '\| ❌ Fail \|'
            $script:TestResult | Should -Not -Match '✅ Pass'
        }

        It 'renders the result table on a pass as well as on a failure' {
            # The table used to be built only on failure while the -replace consumed it either way,
            # so a passing tenant rendered an empty table and the expression would throw under
            # Set-StrictMode.
            Mock -ModuleName Maester Get-MtExo { [pscustomobject]@{ Id = 'contoso'; CustomerLockBoxEnabled = 'True' } }

            $null = Test-MtCisCustomerLockBox
            $script:TestResult | Should -Match '\| Customer Lockbox \|'
            $script:TestResult | Should -Not -Match '%TestResult%'
        }
    }

    Context 'AD-FOR-03 tombstone lifetime' {
        It 'fails with the unable-to-retrieve message when the lifetime cannot be read' {
            # The value used to be replaced with 180, which made the condition impossible to fail
            # and reported a forest as retaining deleted objects for 180 days on an invented number.
            Mock -ModuleName Maester Get-MtADDomainState {
                [pscustomobject]@{
                    Configuration = [pscustomobject]@{ TombstoneLifetime = $null }
                    Forest        = [pscustomobject]@{ Name = 'contoso.com' }
                }
            }

            Test-MtAdTombstoneLifetime | Should -BeFalse
            $script:TestResult | Should -Match 'Unable to retrieve tombstone lifetime'
        }

        It 'does not invent a lifetime of 180 days when the value is missing' {
            Mock -ModuleName Maester Get-MtADDomainState {
                [pscustomobject]@{
                    Configuration = [pscustomobject]@{ TombstoneLifetime = $null }
                    Forest        = [pscustomobject]@{ Name = 'contoso.com' }
                }
            }

            $null = Test-MtAdTombstoneLifetime
            $script:TestResult | Should -Not -Match '180 days'
            $script:TestResult | Should -Not -Match 'Meets recommendation'
        }

        It 'passes and reports the value when the lifetime is readable' {
            Mock -ModuleName Maester Get-MtADDomainState {
                [pscustomobject]@{
                    Configuration = [pscustomobject]@{ TombstoneLifetime = 365 }
                    Forest        = [pscustomobject]@{ Name = 'contoso.com' }
                }
            }

            Test-MtAdTombstoneLifetime | Should -BeTrue
            $script:TestResult | Should -Match '365 days'
            $script:TestResult | Should -Match 'Meets recommendation'
        }

        It 'reports below the recommendation for a forest on the older default of 60 days' {
            # The substituted 180 could also claim the recommendation was met on an older forest,
            # whose default is 60.
            Mock -ModuleName Maester Get-MtADDomainState {
                [pscustomobject]@{
                    Configuration = [pscustomobject]@{ TombstoneLifetime = 60 }
                    Forest        = [pscustomobject]@{ Name = 'contoso.com' }
                }
            }

            $null = Test-MtAdTombstoneLifetime
            $script:TestResult | Should -Match 'Below recommendation'
        }

        It 'skips when Active Directory is not reachable at all' {
            Mock -ModuleName Maester Get-MtADDomainState { return $null }

            $null -eq (Test-MtAdTombstoneLifetime) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotConnectedActiveDirectory'
        }
    }
}
