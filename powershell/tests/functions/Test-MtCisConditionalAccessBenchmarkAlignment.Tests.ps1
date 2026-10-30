Describe 'CIS Conditional Access benchmark alignment' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name @(
            'Test-MtCisGeographicAccessControl',
            'Test-MtCisTokenProtection',
            'Test-MtCisMfaForAdminRole',
            'Test-MtCisMfaForEveryUser',
            'Test-MtCisPhishingResistantMfaForAdmin',
            'Test-MtCisBlockMediumHighSignInRisk',
            'Test-MtCisManagedDeviceForAuthentication',
            'Test-MtCisManagedDeviceForSecurityInfo'
        )
        $script:adminRoleIds = @(InModuleScope Maester { Get-MtCisAdministratorRole | ForEach-Object { $_.Id } })

        function New-TestPolicy {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
            param(
                [string[]] $IncludeUsers = @('All'),
                [string[]] $IncludeRoles = @(),
                [string[]] $IncludeApplications = @('All'),
                [string[]] $IncludeUserActions = @(),
                [string[]] $ExcludeApplications = @(),
                [string[]] $IncludeLocations = @(),
                [string[]] $ExcludeLocations = @(),
                [string[]] $BuiltInControls = @(),
                [string[]] $AllowedCombinations = @(),
                [switch] $IncludeAuthenticationStrength,
                [string[]] $Platforms = @(),
                [string[]] $ClientAppTypes = @(),
                [string[]] $SignInRiskLevels = @(),
                [ValidateSet('AND', 'OR')]
                [string] $GrantOperator = 'OR'
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
                        includeUserActions = $IncludeUserActions
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
                    signInRiskLevels = $SignInRiskLevels
                    insiderRiskLevels = @()
                    authenticationFlows = [PSCustomObject]@{ transferMethods = @() }
                    devices = [PSCustomObject]@{ deviceFilter = [PSCustomObject]@{ rule = $null } }
                }
                grantControls = [PSCustomObject]@{
                    operator = $GrantOperator
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

            Test-MtCisGeographicAccessControl | Should -BeFalse
        }

        It 'passes an all-location block policy that excludes AllTrusted' {
            $script:policy = New-TestPolicy -IncludeLocations @('All') -ExcludeLocations @('AllTrusted') -BuiltInControls @('block')

            Test-MtCisGeographicAccessControl | Should -BeTrue
        }

        It 'fails a country-only block policy without a trusted-location exclusion' {
            $script:policy = New-TestPolicy -IncludeLocations @('country-location') -BuiltInControls @('block')

            Test-MtCisGeographicAccessControl | Should -BeFalse
        }

        It 'passes a country-only block policy with a trusted-location exclusion' {
            $script:policy = New-TestPolicy -IncludeLocations @('country-location') -ExcludeLocations @('trusted-location') -BuiltInControls @('block')

            Test-MtCisGeographicAccessControl | Should -BeTrue
        }

        It 'passes a block policy for an untrusted IP location with a trusted-location exclusion' {
            $script:namedLocations += [PSCustomObject]@{ '@odata.type' = '#microsoft.graph.ipNamedLocation'; id = 'untrusted-ip'; isTrusted = $false }
            $script:policy = New-TestPolicy -IncludeLocations @('untrusted-ip') -ExcludeLocations @('trusted-location') -BuiltInControls @('block')

            Test-MtCisGeographicAccessControl | Should -BeTrue
        }

        It 'fails a block policy that includes a trusted IP location' {
            $script:namedLocations += [PSCustomObject]@{ '@odata.type' = '#microsoft.graph.ipNamedLocation'; id = 'trusted-ip'; isTrusted = $true }
            $script:policy = New-TestPolicy -IncludeLocations @('trusted-ip') -ExcludeLocations @('trusted-location') -BuiltInControls @('block')

            Test-MtCisGeographicAccessControl | Should -BeFalse
        }
    }

    Context 'CIS.M365.5.2.2.1 application exclusions' {
        It 'fails an MFA policy for all admin roles when an application is excluded' {
            $script:policy = New-TestPolicy -IncludeRoles $script:adminRoleIds -ExcludeApplications @('application-id') -BuiltInControls @('mfa')

            Test-MtCisMfaForAdminRole | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Result -like '*application-id*' -and $Result -like '*No excluded applications*'
            }
        }
    }

    Context 'CIS.M365.5.2.2.2 application exclusions' {
        It 'passes an MFA policy for all users and all apps' {
            $script:policy = New-TestPolicy -BuiltInControls @('mfa')

            Test-MtCisMfaForEveryUser | Should -BeTrue
        }

        It 'fails when a non-exempt application is excluded' {
            $script:policy = New-TestPolicy -BuiltInControls @('mfa') -ExcludeApplications @('00000002-0000-0ff1-ce00-000000000000')

            Test-MtCisMfaForEveryUser | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Result -like '*00000002-0000-0ff1-ce00-000000000000*' -and $Result -like '*No excluded applications*'
            }
        }

        It 'allows Microsoft Rights Management Services to be excluded' {
            $script:policy = New-TestPolicy -BuiltInControls @('mfa') -ExcludeApplications @('00000012-0000-0000-c000-000000000000')

            Test-MtCisMfaForEveryUser | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Result -like '*Microsoft Rights Management Services (00000012-0000-0000-c000-000000000000)*'
            }
        }
    }

    Context 'CIS.M365.5.2.2.9 managed device' {
        It 'passes when a compliant device is required' {
            $script:policy = New-TestPolicy -BuiltInControls @('compliantDevice', 'domainJoinedDevice')

            Test-MtCisManagedDeviceForAuthentication | Should -BeTrue
        }

        It 'fails when only a hybrid joined device is required' {
            $script:policy = New-TestPolicy -BuiltInControls @('domainJoinedDevice')

            Test-MtCisManagedDeviceForAuthentication | Should -BeFalse
        }
    }

    Context 'CIS.M365.5.2.2.10 managed device for security information' {
        It 'passes when a compliant device is required' {
            $script:policy = New-TestPolicy -IncludeUserActions @('urn:user:registersecurityinfo') -BuiltInControls @('compliantDevice')

            Test-MtCisManagedDeviceForSecurityInfo | Should -BeTrue
        }

        It 'fails when only a hybrid joined device is required' {
            $script:policy = New-TestPolicy -IncludeUserActions @('urn:user:registersecurityinfo') -BuiltInControls @('domainJoinedDevice')

            Test-MtCisManagedDeviceForSecurityInfo | Should -BeFalse
        }

        It 'passes when compliant and hybrid joined devices are combined with OR' {
            $script:policy = New-TestPolicy -IncludeUserActions @('urn:user:registersecurityinfo') -BuiltInControls @('compliantDevice', 'domainJoinedDevice') -GrantOperator 'OR'

            Test-MtCisManagedDeviceForSecurityInfo | Should -BeTrue
        }

        It 'fails when compliant and hybrid joined devices are combined with AND' {
            $script:policy = New-TestPolicy -IncludeUserActions @('urn:user:registersecurityinfo') -BuiltInControls @('compliantDevice', 'domainJoinedDevice') -GrantOperator 'AND'

            Test-MtCisManagedDeviceForSecurityInfo | Should -BeFalse
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

            Test-MtCisPhishingResistantMfaForAdmin | Should -BeTrue
        }

        It 'fails when the allowed combinations contain another method' {
            $script:policy = New-TestPolicy -IncludeRoles $script:adminRoleIds -AllowedCombinations @('fido2', 'passwordlessMfa')

            Test-MtCisPhishingResistantMfaForAdmin | Should -BeFalse
        }

        It 'fails when an application is excluded' {
            $script:policy = New-TestPolicy -IncludeRoles $script:adminRoleIds -ExcludeApplications @('application-id') -AllowedCombinations @('fido2')

            Test-MtCisPhishingResistantMfaForAdmin | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Result -like '*application-id*' -and $Result -like '*No excluded applications*'
            }
        }

        It 'fails when no allowed combinations are configured' {
            $script:policy = New-TestPolicy -IncludeRoles $script:adminRoleIds -IncludeAuthenticationStrength

            Test-MtCisPhishingResistantMfaForAdmin | Should -BeFalse
        }
    }

    Context 'CIS.M365.5.2.2.8 application exclusions' {
        It 'passes when medium and high sign-in risk are blocked without application exclusions' {
            $script:policy = New-TestPolicy -SignInRiskLevels @('medium', 'high') -BuiltInControls @('block')

            Test-MtCisBlockMediumHighSignInRisk | Should -BeTrue
        }

        It 'fails when an application is excluded' {
            $script:policy = New-TestPolicy -SignInRiskLevels @('medium', 'high') -ExcludeApplications @('application-id') -BuiltInControls @('block')

            Test-MtCisBlockMediumHighSignInRisk | Should -BeFalse
        }
    }
}
