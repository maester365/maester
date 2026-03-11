Describe 'Get-MtLatestModuleVersion' {
    BeforeAll {
        . "$PSScriptRoot/../../internal/Get-MtLatestModuleVersion.ps1"
    }

    Context 'OData API lookup' {
        It 'returns a stable version from an object-based OData response' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    properties = [PSCustomObject]@{ Version = '2.4.0' }
                }
            }

            $latestVersion = Get-MtLatestModuleVersion -Name 'Maester' -TimeoutSec 10

            $latestVersion | Should -Be ([version]'2.4.0')
        }

        It 'returns a stable version from an XML OData response' {
            $xmlResponse = @"
<entry xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata" xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices">
  <m:properties>
    <d:Version>3.1.0</d:Version>
  </m:properties>
</entry>
"@

            Mock Invoke-RestMethod {
                ([xml]$xmlResponse).DocumentElement
            }

            $latestVersion = Get-MtLatestModuleVersion -Name 'Maester' -TimeoutSec 10

            $latestVersion | Should -Be ([version]'3.1.0')
        }

        It 'returns null when OData returns prerelease version and no fallback is available' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    properties = [PSCustomObject]@{ Version = '2.5.0-preview1' }
                }
            }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Find-PSResource' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Find-Module' }

            $latestVersion = Get-MtLatestModuleVersion -Name 'Maester' -TimeoutSec 10

            $latestVersion | Should -BeNullOrEmpty
        }

        It 'passes the requested timeout to Invoke-RestMethod' {
            Mock Invoke-RestMethod {
                [PSCustomObject]@{
                    properties = [PSCustomObject]@{ Version = '2.4.0' }
                }
            }

            $latestVersion = Get-MtLatestModuleVersion -Name 'Maester' -TimeoutSec 30

            $latestVersion | Should -Be ([version]'2.4.0')
            Should -Invoke Invoke-RestMethod -Exactly 1 -ParameterFilter { $TimeoutSec -eq 30 }
        }
    }

    Context 'Fallback to PSResourceGet' {
        It 'uses Find-PSResource when OData lookup fails' {
            Mock Invoke-RestMethod { throw 'Network failure' }
            Mock Get-Command {
                [PSCustomObject]@{ Name = 'Find-PSResource' }
            } -ParameterFilter { $Name -eq 'Find-PSResource' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Find-Module' }
            Mock Find-PSResource {
                [PSCustomObject]@{ Version = '2.6.1' }
            }

            $latestVersion = Get-MtLatestModuleVersion -Name 'Maester' -TimeoutSec 10

            $latestVersion | Should -Be ([version]'2.6.1')
        }
    }

    Context 'Guarded Find-Module fallback' {
        It 'skips Find-Module when NuGet provider is unavailable' {
            Mock Invoke-RestMethod { throw 'Network failure' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Find-PSResource' }
            Mock Get-Command {
                [PSCustomObject]@{ Name = 'Find-Module' }
            } -ParameterFilter { $Name -eq 'Find-Module' }
            Mock Get-PackageProvider { $null }
            Mock Find-Module {
                [PSCustomObject]@{ Version = '2.7.0' }
            }

            $latestVersion = Get-MtLatestModuleVersion -Name 'Maester' -TimeoutSec 10

            $latestVersion | Should -BeNullOrEmpty
            Should -Invoke Find-Module -Exactly 0
        }

        It 'uses Find-Module when NuGet provider is available' {
            Mock Invoke-RestMethod { throw 'Network failure' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Find-PSResource' }
            Mock Get-Command {
                [PSCustomObject]@{ Name = 'Find-Module' }
            } -ParameterFilter { $Name -eq 'Find-Module' }
            Mock Get-PackageProvider {
                [PSCustomObject]@{ Name = 'NuGet' }
            }
            Mock Find-Module {
                [PSCustomObject]@{ Version = '2.7.0' }
            }

            $latestVersion = Get-MtLatestModuleVersion -Name 'Maester' -TimeoutSec 10

            $latestVersion | Should -Be ([version]'2.7.0')
            Should -Invoke Find-Module -Exactly 1
        }
    }
}
