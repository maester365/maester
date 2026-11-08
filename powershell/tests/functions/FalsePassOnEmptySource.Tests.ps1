Describe 'Checks that must not pass when their data source returns nothing' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # A native test, so the function is not exported.
        Use-MtModuleFunction -Name Test-MtAdTombstoneLifetime
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
            # DirectoryServiceRead false: the Directory Service object was not read at all, so
            # there is no effective lifetime to report. This is the genuine retrieval failure.
            Mock -ModuleName Maester Get-MtADDomainState {
                [pscustomobject]@{
                    Configuration = [pscustomobject]@{ TombstoneLifetime = $null; DirectoryServiceRead = $false }
                    Forest        = [pscustomobject]@{ Name = 'contoso.com' }
                }
            }

            $null = Test-MtAdTombstoneLifetime
            $script:TestResult | Should -Not -Match '180 days'
            $script:TestResult | Should -Not -Match 'Meets recommendation'
        }

        It 'reports the 60-day fallback when the attribute is not set but the object was read' {
            # Raised by @merill on #2699: a forest that never set tombstoneLifetime is not a
            # retrieval failure. Active Directory uses 60 days, which is a known value and below
            # the recommendation, so the check reports it instead of saying it could not be read.
            Mock -ModuleName Maester Get-MtADDomainState {
                [pscustomobject]@{
                    Configuration = [pscustomobject]@{ TombstoneLifetime = $null; DirectoryServiceRead = $true }
                    Forest        = [pscustomobject]@{ Name = 'contoso.com' }
                }
            }

            Test-MtAdTombstoneLifetime | Should -BeTrue
            $script:TestResult | Should -Match '60 days'
            $script:TestResult | Should -Match 'Not set on the forest'
            $script:TestResult | Should -Match 'Below recommendation'
            $script:TestResult | Should -Not -Match 'Unable to retrieve'
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
