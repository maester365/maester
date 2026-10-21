Describe 'CIS Conditional Access benchmark alignment' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name Test-MtCisGeographicAccessControls, Test-MtCisTokenProtection, Test-MtCisPhishingResistantMfaForAdministrators
        $script:adminRoleIds = @(InModuleScope Maester { Get-MtCisAdministratorRole | ForEach-Object { $_.Id } })

        function New-TestPolicy {
            param(
                [string[]] $IncludeUsers = @('All'),
                [string[]] $IncludeRoles = @(),
                [string[]] $IncludeApplications = @('All'),
                [string[]] $ExcludeApplications = @(),
                [string[]] $IncludeLocations = @(),
                [string[]] $ExcludeLocations = @(),
                [string[]] $BuiltInControls = @(),
                [string[]] $AllowedCombinations = @(),
                [switch] $IncludeAuthenticationStrength,
                [string[]] $Platforms = @(),
                [string[]] $ClientAppTypes = @()
            )

            $authenticationStrength = if ($AllowedCombinations.Count -gt 0 -or $IncludeAuthenticationStrength) {
                [PSCustomObject]@{ id = 'strength-id'; allowedCombinations = $AllowedCombinations }
            } else {
                $null
            }

            [PSCustomObject]@{
                displayName = 'Test policy'
                state = 'enabled'
                conditions = [PSCustomObject]@{
                    users = [PSCustomObject]@{
                        includeUsers = $IncludeUsers
                        includeRoles = $IncludeRoles
                        excludeUsers = @()
                        excludeGroups = @()
                        excludeRoles = @()
                    }
                    applications = [PSCustomObject]@{
                        includeApplications = $IncludeApplications
                        includeUserActions = @()
                        excludeApplications = $ExcludeApplications
                    }
                    locations = [PSCustomObject]@{
                        includeLocations = $IncludeLocations
                        excludeLocations = $ExcludeLocations
                    }
                    platforms = [PSCustomObject]@{
                        includePlatforms = $Platforms
                        excludePlatforms = @()
                    }
                    clientAppTypes = $ClientAppTypes
                    userRiskLevels = @()
                    signInRiskLevels = @()
                    insiderRiskLevels = @()
                    authenticationFlows = [PSCustomObject]@{ transferMethods = @() }
                    devices = [PSCustomObject]@{ deviceFilter = [PSCustomObject]@{ rule = $null } }
                }
                grantControls = [PSCustomObject]@{
                    operator = 'OR'
                    builtInControls = $BuiltInControls
                    authenticationStrength = $authenticationStrength
                    termsOfUse = @()
                    customAuthenticationFactors = @()
                }
                sessionControls = [PSCustomObject]@{
                    secureSignInSession = [PSCustomObject]@{ isEnabled = $true }
                }
            }
        }
    }

    BeforeEach {
        $script:policy = $null
        $script:namedLocations = @([PSCustomObject]@{
                '@odata.type' = '#microsoft.graph.countryNamedLocation'
                id = 'country-location'
            })
        $script:trustedLocationIds = @('trusted-location')

        Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $script:policy }
        Mock -ModuleName Maester Invoke-MtGraphRequest { return $script:namedLocations }
        Mock -ModuleName Maester Get-MtTrustedNamedLocationId { return $script:trustedLocationIds }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    Context 'CIS.M365.5.2.2.15 geographic exclusions' {
        It 'fails an all-location block policy without an exclusion' {
            $script:policy = New-TestPolicy -IncludeLocations @('All') -BuiltInControls @('block')

            Test-MtCisGeographicAccessControls | Should -BeFalse
        }

        It 'passes an all-location block policy that excludes AllTrusted' {
            $script:policy = New-TestPolicy -IncludeLocations @('All') -ExcludeLocations @('AllTrusted') -BuiltInControls @('block')

            Test-MtCisGeographicAccessControls | Should -BeTrue
        }

        It 'fails a country-only block policy without a trusted-location exclusion' {
            $script:policy = New-TestPolicy -IncludeLocations @('country-location') -BuiltInControls @('block')

            Test-MtCisGeographicAccessControls | Should -BeFalse
        }

        It 'passes a country-only block policy with a trusted-location exclusion' {
            $script:policy = New-TestPolicy -IncludeLocations @('country-location') -ExcludeLocations @('trusted-location') -BuiltInControls @('block')

            Test-MtCisGeographicAccessControls | Should -BeTrue
        }
    }

    Context 'CIS.M365.5.2.2.16 token protection user scope' {
        BeforeAll {
            $script:requiredApps = @(
                '00000002-0000-0ff1-ce00-000000000000',
                '00000003-0000-0ff1-ce00-000000000000',
                'cc15fd57-2c6c-4117-a88c-83b1d56b4bbe'
            )
        }

        It 'fails when includeUsers is None' {
            $script:policy = New-TestPolicy -IncludeUsers @('None') -IncludeApplications $script:requiredApps -Platforms @('windows') -ClientAppTypes @('mobileAppsAndDesktopClients')

            Test-MtCisTokenProtection | Should -BeFalse
        }

        It 'passes with a selected user scope and the required apps' {
            $script:policy = New-TestPolicy -IncludeUsers @('user-id') -IncludeApplications $script:requiredApps -Platforms @('windows') -ClientAppTypes @('mobileAppsAndDesktopClients')

            Test-MtCisTokenProtection | Should -BeTrue
        }
    }

    Context 'CIS.M365.5.2.2.5 phishing-resistant methods' {
        It 'passes when the allowed combinations contain an approved subset' {
            $script:policy = New-TestPolicy -IncludeRoles $script:adminRoleIds -AllowedCombinations @('fido2')

            Test-MtCisPhishingResistantMfaForAdministrators | Should -BeTrue
        }

        It 'fails when the allowed combinations contain another method' {
            $script:policy = New-TestPolicy -IncludeRoles $script:adminRoleIds -AllowedCombinations @('fido2', 'passwordlessMfa')

            Test-MtCisPhishingResistantMfaForAdministrators | Should -BeFalse
        }

        It 'fails when no allowed combinations are configured' {
            $script:policy = New-TestPolicy -IncludeRoles $script:adminRoleIds -IncludeAuthenticationStrength

            Test-MtCisPhishingResistantMfaForAdministrators | Should -BeFalse
        }
    }
}
