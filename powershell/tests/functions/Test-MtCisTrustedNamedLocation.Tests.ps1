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

    It 'Passes for a trusted location with a public range, without a note' {
        $locations = @(Get-TestIpLocation -DisplayName 'Head office' -CidrAddress '8.8.8.0/24' -Trusted)
        Mock Invoke-MtGraphRequest -ModuleName Maester { $locations }

        Test-MtCisTrustedNamedLocation | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -like 'Well done.*' -and $Result -notlike '*never match a sign-in*'
        }
    }

    It 'Passes for a trusted location whose ranges are all <Kind>, and lists it' -ForEach @(
        @{ Kind = 'private (RFC 1918)'; Cidr = @('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16') }
        @{ Kind = 'documentation ranges'; Cidr = @('203.0.113.0/24', '2001:db8::/32') }
        @{ Kind = 'IPv6 unique local'; Cidr = @('fd00::/8') }
    ) {
        $locations = @(Get-TestIpLocation -DisplayName 'Internal networks' -CidrAddress $Cidr -Trusted)
        Mock Invoke-MtGraphRequest -ModuleName Maester { $locations }

        Test-MtCisTrustedNamedLocation | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -like 'Well done.*' -and
            $Result -like "*| Internal networks | $($Cidr.Count) | $($Cidr.Count) | True |*" -and
            $Result -like '*never match a sign-in*- Internal networks*'
        }
    }

    It 'Passes for a trusted location that mixes private and public ranges, without a note' {
        $locations = @(Get-TestIpLocation -DisplayName 'Offices' -CidrAddress '192.168.0.0/16', '2001:4860::/32' -Trusted)
        Mock Invoke-MtGraphRequest -ModuleName Maester { $locations }

        Test-MtCisTrustedNamedLocation | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Result -like '*| Offices | 2 | 1 | True |*' -and $Result -notlike '*never match a sign-in*'
        }
    }

    It 'Fails for a public range that is not trusted' {
        $locations = @(Get-TestIpLocation -DisplayName 'Partner' -CidrAddress '8.8.4.0/24')
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
