BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Test-MtGsaCompliantNetworkBreakGlassExcluded' {
    Context 'When no emergency access accounts are configured' {
        It 'Skips the test instead of letting it be counted as passed' {
            # The check states that break-glass exclusion cannot be verified and returns
            # $null. The bundled MT.1191 wrapper only asserts when the result is non-null,
            # so without a skip reason the It block completes with no assertion at all and
            # Pester reports Passed. Add-MtTestResultDetail calls Set-ItResult -Skipped only
            # when -SkippedBecause is supplied, which is what keeps an unverifiable control
            # out of the passed count.
            InModuleScope Maester {
                Mock Test-MtConnection { $true }
                Mock Get-MtLicenseInformation { 'P1' }
                Mock Get-MtCompliantNetworkPolicy {
                    @([pscustomobject]@{ displayName = 'Compliant Network'; id = 'policy-01' })
                }
                Mock Get-MtEmergencyAccessAccount { @() }
                Mock Add-MtTestResultDetail { }

                $result = Test-MtGsaCompliantNetworkBreakGlassExcluded

                $result | Should -BeNullOrEmpty
                Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                    $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -like '*cannot be verified*'
                }
            }
        }
    }

    Context 'When emergency access accounts are configured' {
        It 'Returns false when a policy does not exclude a break-glass account' {
            InModuleScope Maester {
                Mock Test-MtConnection { $true }
                Mock Get-MtLicenseInformation { 'P1' }
                Mock Get-MtCompliantNetworkPolicy {
                    @([pscustomobject]@{
                            displayName = 'Compliant Network'
                            id          = 'policy-01'
                            conditions  = @{ users = @{ excludeUsers = @(); excludeGroups = @() } }
                        })
                }
                Mock Get-MtEmergencyAccessAccount {
                    @([pscustomobject]@{ ObjectId = 'bg-user-01'; DisplayName = 'Break Glass 01'; Type = 'user' })
                }
                Mock Invoke-MtGraphRequest { @() }
                Mock Add-MtTestResultDetail { }

                Test-MtGsaCompliantNetworkBreakGlassExcluded | Should -BeFalse
            }
        }

        It 'Returns true when the break-glass account is excluded' {
            InModuleScope Maester {
                Mock Test-MtConnection { $true }
                Mock Get-MtLicenseInformation { 'P1' }
                Mock Get-MtCompliantNetworkPolicy {
                    @([pscustomobject]@{
                            displayName = 'Compliant Network'
                            id          = 'policy-01'
                            conditions  = @{ users = @{ excludeUsers = @('bg-user-01'); excludeGroups = @() } }
                        })
                }
                Mock Get-MtEmergencyAccessAccount {
                    @([pscustomobject]@{ ObjectId = 'bg-user-01'; DisplayName = 'Break Glass 01'; Type = 'user' })
                }
                Mock Invoke-MtGraphRequest { @() }
                Mock Add-MtTestResultDetail { }

                Test-MtGsaCompliantNetworkBreakGlassExcluded | Should -BeTrue
            }
        }
    }
}
