Describe 'Test-MtCisTrustedNamedLocation' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\..\Maester.psd1" -Force
        . "$PSScriptRoot\..\helpers\Use-MtModuleFunction.ps1"
        # Check functions that became native tests are not exported.
        Use-MtModuleFunction -Name Test-MtCisTrustedNamedLocation

        function Get-TestIpLocation {
            param(
                [string] $DisplayName,
                [string[]] $CidrAddress,
                [switch] $Trusted
            )
            [pscustomobject]@{
                '@odata.type' = '#microsoft.graph.ipNamedLocation'
                displayName   = $DisplayName
                isTrusted     = [bool]$Trusted
                ipRanges      = @(
                    foreach ($cidr in $CidrAddress) {
                        [pscustomobject]@{
                            '@odata.type' = if ($cidr -like '*:*') { '#microsoft.graph.iPv6CidrRange' } else { '#microsoft.graph.iPv4CidrRange' }
                            cidrAddress   = $cidr
                        }
                    }
                )
            }
        }
    }

    BeforeEach {
        Mock Add-MtTestResultDetail -ModuleName Maester { }
    }

    It 'Passes for a trusted location with a public range' {
        $locations = @(Get-TestIpLocation -DisplayName 'Head office' -CidrAddress '203.0.113.0/24' -Trusted)
        Mock Invoke-MtGraphRequest -ModuleName Maester { $locations }

        Test-MtCisTrustedNamedLocation | Should -BeTrue
    }

    It 'Fails for a trusted location that has only private ranges, and says why' {
        $locations = @(Get-TestIpLocation -DisplayName 'RFC 1918' -CidrAddress '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16' -Trusted)
        Mock Invoke-MtGraphRequest -ModuleName Maester { $locations }

        Test-MtCisTrustedNamedLocation | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -like 'No trusted IP named location has a public IP range*' -and
            $Result -like '*| RFC 1918 | 3 | 3 | True |*'
        }
    }

    It 'Fails for a trusted location in IPv6 unique local space' {
        $locations = @(Get-TestIpLocation -DisplayName 'IPv6 lab' -CidrAddress 'fd00::/8' -Trusted)
        Mock Invoke-MtGraphRequest -ModuleName Maester { $locations }

        Test-MtCisTrustedNamedLocation | Should -BeFalse
    }

    It 'Passes for a trusted location that mixes private and public ranges' {
        $locations = @(Get-TestIpLocation -DisplayName 'Offices' -CidrAddress '192.168.0.0/16', '2001:db8::/32' -Trusted)
        Mock Invoke-MtGraphRequest -ModuleName Maester { $locations }

        Test-MtCisTrustedNamedLocation | Should -BeTrue
    }

    It 'Fails for a public range that is not trusted' {
        $locations = @(Get-TestIpLocation -DisplayName 'Partner' -CidrAddress '198.51.100.0/24')
        Mock Invoke-MtGraphRequest -ModuleName Maester { $locations }

        Test-MtCisTrustedNamedLocation | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -like 'No IP named location is both trusted and has IP ranges*'
        }
    }

    It 'Fails when only country locations exist' {
        $locations = @(
            [pscustomobject]@{
                '@odata.type'       = '#microsoft.graph.countryNamedLocation'
                displayName         = 'Allowed countries'
                countriesAndRegions = @('FR')
            }
        )
        Mock Invoke-MtGraphRequest -ModuleName Maester { $locations }

        Test-MtCisTrustedNamedLocation | Should -BeFalse
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -like 'No IP named locations are defined*'
        }
    }
}
