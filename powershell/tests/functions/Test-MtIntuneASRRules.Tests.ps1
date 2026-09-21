Describe 'Test-MtIntuneASRRules' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force

        $script:AsrRoot = 'device_vendor_msft_policy_config_defender_attacksurfacereductionrules'

        # Builds one groupSettingCollection settingInstance from a rule suffix -> mode-suffix map,
        # matching the shape the configurationPolicies settings endpoint returns.
        function New-AsrSettingInstance {
            param([hashtable] $Rules)

            $children = foreach ($suffix in $Rules.Keys) {
                [PSCustomObject]@{
                    settingDefinitionId = "$($script:AsrRoot)_$suffix"
                    choiceSettingValue  = [PSCustomObject]@{ value = "$($script:AsrRoot)_$($suffix)_$($Rules[$suffix])" }
                }
            }

            return [PSCustomObject]@{
                settingInstance = [PSCustomObject]@{
                    settingDefinitionId        = $script:AsrRoot
                    groupSettingCollectionValue = @([PSCustomObject]@{ children = @($children) })
                }
            }
        }

        function New-Policy {
            param([string] $Id, [string] $Name, [string] $TemplateFamily)

            return [PSCustomObject]@{
                id                = $Id
                name              = $Name
                templateReference = [PSCustomObject]@{ templateFamily = $TemplateFamily }
            }
        }
    }

    BeforeEach {
        $script:Result = $null
        $script:SkippedBecause = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Get-MtLicenseInformation { return 'Intune Plan 1' }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedError)
            $script:Result = $Result
            $script:SkippedBecause = $SkippedBecause
        }
    }

    It 'finds ASR rules configured in a Settings catalog policy' {
        # Regression: filtering on templateReference/templateFamily missed settings catalog
        # policies entirely, so a fully compliant tenant reported "no ASR policies found".
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri, $ApiVersion)

            # '?' is a single-character wildcard for -like, so match /settings first.
            if ($RelativeUri -notlike '*/settings*') {
                $RelativeUri | Should -BeLike "*platforms has 'windows10'*"
                return @(New-Policy -Id 'def-l1' -Name 'Def L1' -TemplateFamily 'none')
            }

            return @(New-AsrSettingInstance -Rules @{
                    'blockabuseofexploitedvulnerablesigneddrivers'                      = 'block'
                    'blockcredentialstealingfromwindowslocalsecurityauthoritysubsystem' = 'block'
                    'blockpersistencethroughwmieventsubscription'                       = 'audit'
                })
        }

        Test-MtIntuneASRRules | Should -Be $true
        $script:Result | Should -BeLike '*Def L1*'
        $script:Result | Should -BeLike '*Configured via:** Settings catalog*'
    }

    It 'ignores policies that share the ASR template family but configure no ASR rules' {
        # Device Control and Exploit Protection both live under the
        # endpointSecurityAttackSurfaceReduction template family.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri, $ApiVersion)

            if ($RelativeUri -notlike '*/settings*') {
                return @(
                    (New-Policy -Id 'asr' -Name 'ASR rules' -TemplateFamily 'endpointSecurityAttackSurfaceReduction'),
                    (New-Policy -Id 'devctrl' -Name 'Device Control' -TemplateFamily 'endpointSecurityAttackSurfaceReduction')
                )
            }

            if ($RelativeUri -like "*('devctrl')*") {
                return @([PSCustomObject]@{
                        settingInstance = [PSCustomObject]@{
                            settingDefinitionId = 'device_vendor_msft_policy_config_defender_devicecontrolenabled'
                        }
                    })
            }

            return @(New-AsrSettingInstance -Rules @{
                    'blockabuseofexploitedvulnerablesigneddrivers'                      = 'block'
                    'blockcredentialstealingfromwindowslocalsecurityauthoritysubsystem' = 'block'
                    'blockpersistencethroughwmieventsubscription'                       = 'block'
                })
        }

        Test-MtIntuneASRRules | Should -Be $true
        $script:Result | Should -BeLike '*Found 1 policy/policies*'
        $script:Result | Should -Not -BeLike '*Device Control*'
        $script:Result | Should -BeLike '*Configured via:** Endpoint Security*'
    }

    It 'fails when a Standard Protection baseline rule is not in Block or Audit' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri, $ApiVersion)

            if ($RelativeUri -notlike '*/settings*') {
                return @(New-Policy -Id 'partial' -Name 'Partial ASR' -TemplateFamily 'none')
            }

            return @(New-AsrSettingInstance -Rules @{
                    'blockabuseofexploitedvulnerablesigneddrivers'                      = 'block'
                    'blockcredentialstealingfromwindowslocalsecurityauthoritysubsystem' = 'block'
                    'blockpersistencethroughwmieventsubscription'                       = 'off'
                })
        }

        Test-MtIntuneASRRules | Should -Be $false
        $script:Result | Should -BeLike '*Block persistence through WMI event subscription (current: Disabled)*'
    }

    It 'fails when no policy configures ASR rules' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($RelativeUri, $ApiVersion)

            if ($RelativeUri -notlike '*/settings*') {
                return @(New-Policy -Id 'other' -Name 'Some other policy' -TemplateFamily 'none')
            }

            return @([PSCustomObject]@{
                    settingInstance = [PSCustomObject]@{
                        settingDefinitionId = 'device_vendor_msft_policy_config_autoplay_turnoffautoplay'
                    }
                })
        }

        Test-MtIntuneASRRules | Should -Be $false
        $script:Result | Should -BeLike '*No Attack Surface Reduction rules found*'
    }

    It 'skips when Intune is not licensed' {
        Mock -ModuleName Maester Get-MtLicenseInformation { return $null }

        Test-MtIntuneASRRules | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotLicensedIntune'
    }
}
