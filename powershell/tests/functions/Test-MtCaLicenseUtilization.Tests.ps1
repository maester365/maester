Describe 'Test-MtCaLicenseUtilization' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCaLicenseUtilization

        function New-LicenseInsight {
            param(
                [int]$EntitledP1 = 0,
                [int]$EntitledP2 = 0,
                [int]$P1Users = 0,
                [int]$P2Users = 0
            )
            return [PSCustomObject]@{
                entitledP1LicenseCount = $EntitledP1
                entitledP2LicenseCount = $EntitledP2
                p1FeatureUtilizations  = [PSCustomObject]@{
                    conditionalAccess           = [PSCustomObject]@{ userCount = $P1Users }
                    conditionalAccessGuestUsers = [PSCustomObject]@{ userCount = 0 }
                }
                p2FeatureUtilizations  = [PSCustomObject]@{
                    riskBasedConditionalAccess           = [PSCustomObject]@{ userCount = $P2Users }
                    riskBasedConditionalAccessGuestUsers = [PSCustomObject]@{ userCount = 0 }
                }
            }
        }

        function New-CaPolicy {
            param(
                [string]$DisplayName,
                [string]$State = 'enabled',
                [string[]]$SignInRiskLevels = @(),
                [string[]]$UserRiskLevels = @(),
                [switch]$NoRiskProperties
            )
            $conditions = if ($NoRiskProperties) {
                [PSCustomObject]@{}
            } else {
                [PSCustomObject]@{
                    signInRiskLevels = $SignInRiskLevels
                    userRiskLevels   = $UserRiskLevels
                }
            }
            return [PSCustomObject]@{
                id          = [guid]::NewGuid().ToString()
                displayName = $DisplayName
                state       = $State
                conditions  = $conditions
            }
        }
    }

    BeforeEach {
        $script:Result = $null
        $script:GraphObjects = $null
        Mock -ModuleName Maester Get-MtTotalEntraIdUserCount { return 100 }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Description, $Result, $GraphObjects, $GraphObjectType)
            $script:Result = $Result
            $script:GraphObjects = $GraphObjects
        }
    }

    Context 'Usage is within the licence count' {
        It 'Returns the same counts and adds no gap text' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { New-LicenseInsight -EntitledP2 50 -P2Users 40 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { @() }

            $report = Test-MtCaLicenseUtilization -License P2

            $report.EntitledLicenseCount | Should -Be 50
            $report.TotalLicensesUtilized | Should -Be 40
            $script:Result | Should -Not -BeLike '*more users are using*'
            $script:GraphObjects | Should -BeNullOrEmpty
            Should -Invoke -ModuleName Maester Get-MtConditionalAccessPolicy -Times 0
        }
    }

    Context 'More users use P2 features than are licensed' {
        It 'States the gap, links to License usage and lists only the risk-based policies' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { New-LicenseInsight -EntitledP2 10 -P2Users 22 }
            $policies = @(
                New-CaPolicy -DisplayName 'Sign-in risk' -SignInRiskLevels 'high', 'medium'
                New-CaPolicy -DisplayName 'User risk report-only' -State 'enabledForReportingButNotEnforced' -UserRiskLevels 'high'
                New-CaPolicy -DisplayName 'MFA for all users'
                New-CaPolicy -DisplayName 'Disabled sign-in risk' -State 'disabled' -SignInRiskLevels 'high'
                New-CaPolicy -DisplayName 'No risk properties' -NoRiskProperties
            )
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { $policies }

            $report = Test-MtCaLicenseUtilization -License P2

            $report.TotalLicensesUtilized | Should -Be 22
            $script:Result | Should -BeLike '*12** more users are using Entra ID P2 features*'
            $script:Result | Should -BeLike '*LicenseUtilization*'
            $script:Result | Should -BeLike '*%TestResult%*'
            @($script:GraphObjects).displayName | Should -Be @('Sign-in risk', 'User risk report-only')
        }

        It 'Adds no policy table when no risk-based policy is on' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { New-LicenseInsight -EntitledP2 10 -P2Users 22 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { @(New-CaPolicy -DisplayName 'MFA for all users') }

            Test-MtCaLicenseUtilization -License P2 | Out-Null

            $script:Result | Should -BeLike '*more users are using*'
            $script:Result | Should -Not -BeLike '*%TestResult%*'
            $script:GraphObjects | Should -BeNullOrEmpty
        }
    }

    Context 'More users use P1 features than are licensed' {
        It 'States the gap and does not list policies' {
            Mock -ModuleName Maester Invoke-MtGraphRequest { New-LicenseInsight -EntitledP1 5 -EntitledP2 5 -P1Users 30 }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { @() }

            $report = Test-MtCaLicenseUtilization -License P1

            $report.EntitledLicenseCount | Should -Be 10
            $script:Result | Should -BeLike '*20** more users are using Entra ID P1 features*'
            $script:GraphObjects | Should -BeNullOrEmpty
            Should -Invoke -ModuleName Maester Get-MtConditionalAccessPolicy -Times 0
        }
    }
}
