# How the MDE antivirus checks (MT.1148 to MT.1171) combine the settings of several assigned
# Defender Antivirus policies. Graph is mocked: each policy's settings come from $script:MdeSettings.

BeforeAll { Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue }

Describe 'Test-MdePolicyCompliance' {
    BeforeAll {
        InModuleScope Maester {
            $script:ArchiveId = 'device_vendor_msft_policy_config_defender_allowarchivescanning'
            $script:CpuId = 'device_vendor_msft_policy_config_defender_avgcpuloadfactor'

            # A policy's settings response: a choice setting ('_1', '_0') or a simple value (an integer).
            $script:NewSetting = {
                param($SettingId, $Value)
                if ($Value -is [int]) {
                    [pscustomobject]@{ settingInstance = [pscustomobject]@{ settingDefinitionId = $SettingId; simpleSettingValue = [pscustomobject]@{ value = $Value } } }
                } else {
                    [pscustomobject]@{ settingInstance = [pscustomobject]@{ settingDefinitionId = $SettingId; choiceSettingValue = [pscustomobject]@{ value = "$SettingId$Value" } } }
                }
            }

            # Policies as name => settings; returns what Get-MdePolicyConfiguration returns.
            $script:NewPolicyConfiguration = {
                param([System.Collections.Specialized.OrderedDictionary] $Policies)
                $script:MdeSettings = @{}
                $list = foreach ($name in $Policies.Keys) {
                    $id = "id-$name"
                    $script:MdeSettings["deviceManagement/configurationPolicies/$id/settings"] = @($Policies[$name])
                    [pscustomobject]@{ id = $id; name = $name }
                }
                @{ ConfigurationPolicies = @($list); TotalCount = @($list).Count }
            }
        }
    }

    BeforeEach {
        InModuleScope Maester {
            Mock Invoke-MtGraphRequest { $script:MdeSettings[$RelativeUri] }
        }
    }

    AfterAll {
        InModuleScope Maester {
            Remove-Variable -Scope Script -Name ArchiveId, CpuId, NewSetting, NewPolicyConfiguration, MdeSettings -ErrorAction SilentlyContinue
        }
    }

    It 'lets a Graph error reach the engine instead of counting the policy as unconfigured' {
        InModuleScope Maester {
            # One compliant policy plus one that cannot be read: treating the unreadable policy as
            # unconfigured would make EffectivePolicy pass on data it never saw.
            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Core protection' = @(& $script:NewSetting $script:ArchiveId '_1')
                    'AV - Developer'       = @()
                })
            Mock Invoke-MtGraphRequest { throw 'Forbidden' } -ParameterFilter { $RelativeUri -like '*id-AV - Developer*' }
            { Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $script:ArchiveId -ComplianceCheck Boolean -ExpectedValue '_1' } |
                Should -Throw '*Forbidden*'
        }
    }

    It 'counts a policy that contains the setting with an unreadable value as non-compliant, not neutral' {
        InModuleScope Maester {
            $unreadable = [pscustomobject]@{ settingInstance = [pscustomobject]@{ settingDefinitionId = $script:ArchiveId; choiceSettingValue = [pscustomobject]@{ value = $null } } }
            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Core protection' = @(& $script:NewSetting $script:ArchiveId '_1')
                    'AV - Imported'        = @($unreadable)
                })
            $result = Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $script:ArchiveId -ComplianceCheck Boolean -ExpectedValue '_1'
            $result.IsCompliant | Should -BeFalse
            $result.NonCompliantPolicies | Should -Be @('AV - Imported')
        }
    }

    It 'passes when one policy enables the setting and the others do not configure it (#1922)' {
        InModuleScope Maester {
            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Core protection' = @(& $script:NewSetting $script:ArchiveId '_1')
                    'AV - Exclusions'      = @()
                })
            $result = Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $script:ArchiveId -ComplianceCheck Boolean -ExpectedValue '_1'
            $result.ComplianceLogic | Should -Be 'EffectivePolicy'
            $result.IsCompliant | Should -BeTrue
            $result.HasConflict | Should -BeFalse
            $result.CompliantPolicies | Should -Be @('AV - Core protection')
            $result.NotConfiguredPolicies | Should -Be @('AV - Exclusions')
        }
    }

    It 'keeps the strict result with -ComplianceLogic AllPolicies' {
        InModuleScope Maester {
            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Core protection' = @(& $script:NewSetting $script:ArchiveId '_1')
                    'AV - Exclusions'      = @()
                })
            $result = Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $script:ArchiveId -ComplianceCheck Boolean -ExpectedValue '_1' -ComplianceLogic AllPolicies
            $result.IsCompliant | Should -BeFalse
        }
    }

    It 'fails a conflict: one policy enables the setting and another disables it' {
        InModuleScope Maester {
            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Baseline'  = @(& $script:NewSetting $script:ArchiveId '_1')
                    'AV - Developer' = @(& $script:NewSetting $script:ArchiveId '_0')
                })
            $result = Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $script:ArchiveId -ComplianceCheck Boolean -ExpectedValue '_1'
            $result.IsCompliant | Should -BeFalse
            $result.HasConflict | Should -BeTrue
            $result.NonCompliantPolicies | Should -Be @('AV - Developer')
        }
    }

    It 'fails when the only policy that sets the setting uses another value' {
        InModuleScope Maester {
            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Baseline'   = @(& $script:NewSetting $script:ArchiveId '_0')
                    'AV - Exclusions' = @()
                })
            $result = Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $script:ArchiveId -ComplianceCheck Boolean -ExpectedValue '_1'
            $result.IsCompliant | Should -BeFalse
            $result.HasConflict | Should -BeFalse
        }
    }

    It 'fails when no assigned policy configures the setting' {
        InModuleScope Maester {
            $config = & $script:NewPolicyConfiguration ([ordered]@{ 'AV - A' = @(); 'AV - B' = @() })
            $result = Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $script:ArchiveId -ComplianceCheck Boolean -ExpectedValue '_1'
            $result.IsCompliant | Should -BeFalse
            $result.NotConfiguredPolicies.Count | Should -Be 2
        }
    }

    It 'passes when every policy sets a compliant value' {
        InModuleScope Maester {
            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Servers' = @(& $script:NewSetting $script:ArchiveId '_1')
                    'AV - Laptops' = @(& $script:NewSetting $script:ArchiveId '_1')
                })
            foreach ($logic in 'EffectivePolicy', 'AllPolicies', 'AnyPolicy') {
                (Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $script:ArchiveId -ComplianceCheck Boolean -ExpectedValue '_1' -ComplianceLogic $logic).IsCompliant |
                    Should -BeTrue -Because "$logic passes when every policy is compliant"
            }
        }
    }

    It 'evaluates a numeric value of 0 instead of reading it as unconfigured' {
        InModuleScope Maester {
            # 0 -eq "" is $true in PowerShell; a 0 in a second policy used to be neutral under EffectivePolicy.
            $interval = 'device_vendor_msft_policy_config_defender_signatureupdateinterval'
            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Core'   = @(& $script:NewSetting $interval 2)
                    'AV - Legacy' = @(& $script:NewSetting $interval 0)
                })
            $result = Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $interval -ComplianceCheck Range -RangeMin 1 -RangeMax 4
            $result.IsCompliant | Should -BeFalse
            $result.NonCompliantPolicies | Should -Be @('AV - Legacy')
        }
    }

    It 'passes policies that set different values that are each compliant, as AllPolicies does' {
        InModuleScope Maester {
            # Decided in review of #2606: values are not compared between compliant policies, because
            # without assignment resolution Maester cannot tell whether any device receives both.
            $block = 'device_vendor_msft_policy_config_defender_cloudblocklevel'
            $levels = @{ '_0' = 0; '_2' = 2; '_4' = 4; '_6' = 6 }
            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Servers' = @(& $script:NewSetting $block '_2')
                    'AV - Laptops' = @(& $script:NewSetting $block '_4')
                })
            foreach ($logic in 'EffectivePolicy', 'AllPolicies') {
                $result = Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $block -ComplianceCheck MinimumLevel -ValidLevels $levels -MinimumValue 2 -ComplianceLogic $logic
                $result.IsCompliant | Should -BeTrue -Because "$logic does not compare values between compliant policies"
                $result.HasConflict | Should -BeFalse
            }
        }
    }

    It 'passes an optional (NotRequired) setting that no policy sets, under every logic' {
        InModuleScope Maester {
            $quick = 'device_vendor_msft_policy_config_defender_schedulequickscantime'
            $config = & $script:NewPolicyConfiguration ([ordered]@{ 'AV - Core' = @(); 'AV - Exclusions' = @() })
            foreach ($logic in 'EffectivePolicy', 'AllPolicies', 'AnyPolicy') {
                (Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $quick -ComplianceCheck NotRequired -ComplianceLogic $logic).IsCompliant |
                    Should -BeTrue -Because "MT.1159's help says it passes under $logic when no policy sets it"
            }
        }
    }

    It 'applies the same rule to Enum, MinimumLevel and MinimumValue checks' {
        InModuleScope Maester {
            $pua = 'device_vendor_msft_policy_config_defender_puaprotection'
            $config = & $script:NewPolicyConfiguration ([ordered]@{ 'AV - Core' = @(& $script:NewSetting $pua '_1'); 'AV - Exclusions' = @() })
            (Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $pua -ComplianceCheck Enum -ValidValues '_1', '_2').IsCompliant | Should -BeTrue
            $config = & $script:NewPolicyConfiguration ([ordered]@{ 'AV - Core' = @(& $script:NewSetting $pua '_1'); 'AV - Kiosk' = @(& $script:NewSetting $pua '_0') })
            (Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $pua -ComplianceCheck Enum -ValidValues '_1', '_2').HasConflict | Should -BeTrue

            $block = 'device_vendor_msft_policy_config_defender_cloudblocklevel'
            $levels = @{ '_0' = 0; '_2' = 2; '_4' = 4; '_6' = 6 }
            $config = & $script:NewPolicyConfiguration ([ordered]@{ 'AV - Core' = @(& $script:NewSetting $block '_4'); 'AV - Exclusions' = @() })
            (Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $block -ComplianceCheck MinimumLevel -ValidLevels $levels -MinimumValue 2).IsCompliant | Should -BeTrue

            $days = 'device_vendor_msft_policy_config_defender_daystoretaincleanedmalware'
            $config = & $script:NewPolicyConfiguration ([ordered]@{ 'AV - Core' = @(& $script:NewSetting $days 15); 'AV - Exclusions' = @() })
            $result = Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $days -ComplianceCheck MinimumValue -MinimumValue 30
            $result.IsCompliant | Should -BeFalse
            $result.NonCompliantPolicies | Should -Be @('AV - Core')
        }
    }

    It 'passes PolicyFiltering through so the result text can say which policies were read' {
        InModuleScope Maester {
            $config = & $script:NewPolicyConfiguration ([ordered]@{ 'AV - Core' = @(& $script:NewSetting $script:ArchiveId '_1') })
            $config.PolicyFiltering = 'IncludeUnassigned'
            (Test-MdePolicyCompliance -PolicyConfiguration $config -SettingId $script:ArchiveId -ComplianceCheck Boolean -ExpectedValue '_1').PolicyFiltering |
                Should -Be 'IncludeUnassigned'
        }
    }

    It 'treats two compliant values in a range as no conflict, and an out-of-range one as a conflict' {
        InModuleScope Maester {
            $range = @{ SettingId = $script:CpuId; ComplianceCheck = 'Range'; RangeMin = 20; RangeMax = 30 }
            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Servers'   = @(& $script:NewSetting $script:CpuId 20)
                    'AV - Laptops'   = @(& $script:NewSetting $script:CpuId 30)
                    'AV - Exclusions' = @()
                })
            (Test-MdePolicyCompliance -PolicyConfiguration $config @range).IsCompliant | Should -BeTrue

            $config = & $script:NewPolicyConfiguration ([ordered]@{
                    'AV - Servers' = @(& $script:NewSetting $script:CpuId 25)
                    'AV - Kiosks'  = @(& $script:NewSetting $script:CpuId 50)
                })
            $result = Test-MdePolicyCompliance -PolicyConfiguration $config @range
            $result.IsCompliant | Should -BeFalse
            $result.HasConflict | Should -BeTrue
        }
    }
}

Describe 'Get-MdePolicyConfiguration' {
    BeforeEach {
        InModuleScope Maester {
            $antivirus = { param($id, $name) [pscustomobject]@{ id = $id; name = $name; platforms = 'windows10'; templateReference = [pscustomobject]@{ templateDisplayName = 'Microsoft Defender Antivirus' } } }
            $script:MdeTestPolicies = @((& $antivirus 'p1' 'AV - Core'), (& $antivirus 'p2' 'AV - Developer'), (& $antivirus 'p3' 'AV - Draft'))
            Mock Get-MdeConfiguration { @{ ConfigurationPolicies = $script:MdeTestPolicies } }
        }
    }

    AfterAll {
        InModuleScope Maester { Remove-Variable -Scope Script -Name MdeTestPolicies -ErrorAction SilentlyContinue }
    }

    It 'keeps assigned policies, drops unassigned ones, and records the filtering it applied' {
        InModuleScope Maester {
            Mock Invoke-MtGraphRequest {
                if ($RelativeUri -like '*/p3/assignments') { return @() }
                @([pscustomobject]@{ target = [pscustomobject]@{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget' } })
            }
            $config = Get-MdePolicyConfiguration
            $config.ConfigurationPolicies.name | Should -Be @('AV - Core', 'AV - Developer')
            $config.PolicyFiltering | Should -Be 'OnlyAssigned'
        }
    }

    It 'lets an assignments read error reach the engine instead of dropping the policy' {
        InModuleScope Maester {
            # Dropping the policy that sets a different value would make EffectivePolicy pass on the rest.
            Mock Invoke-MtGraphRequest {
                if ($RelativeUri -like '*/p2/assignments') { throw '429 Too Many Requests' }
                @([pscustomobject]@{ target = [pscustomobject]@{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget' } })
            }
            { Get-MdePolicyConfiguration } | Should -Throw '*429*'
        }
    }
}

Describe 'Get-MdeComplianceResultMarkdown' {
    BeforeAll {
        InModuleScope Maester {
            # A Test-MdePolicyCompliance result; the overrides set the outcome being worded.
            $script:NewCompliance = {
                param([hashtable] $Override)
                $base = @{
                    IsCompliant = $false; HasConflict = $false; ComplianceLogic = 'EffectivePolicy'; ComplianceCheck = 'Boolean'
                    PolicyFiltering = 'OnlyAssigned'; TotalCount = 2
                    CompliantPolicies = @(); NonCompliantPolicies = @(); NotConfiguredPolicies = @()
                }
                foreach ($key in $Override.Keys) { $base[$key] = $Override[$key] }
                $base
            }
        }
    }

    AfterAll {
        InModuleScope Maester { Remove-Variable -Scope Script -Name NewCompliance -ErrorAction SilentlyContinue }
    }

    It 'explains an effective pass, says what Maester did not check, and lists every policy' {
        InModuleScope Maester {
            $md = Get-MdeComplianceResultMarkdown -SettingName 'Archive scanning' -ExpectedState 'enabled' -Compliance (& $script:NewCompliance @{
                    IsCompliant = $true; CompliantPolicies = @('AV - Core'); NotConfiguredPolicies = @('AV - Exclusions') })
            $md | Should -Match '^Well done\. Archive scanning is enabled in 1 of the 2 assigned Defender Antivirus policies; the others don''t configure it\. Make sure the policy that sets it is assigned to every device that needs this setting\.'
            $md | Should -Not -Match 'different value' -Because 'a pass does not establish that compliant policies use the same value'
            $md | Should -Match '\| AV - Core \| ✅ Compliant \|'
            $md | Should -Match '\| AV - Exclusions \| ➖ Not configured \|'
        }
    }

    It 'calls the policies "evaluated" when PolicyFiltering read unassigned ones' {
        InModuleScope Maester {
            $md = Get-MdeComplianceResultMarkdown -SettingName 'Archive scanning' -ExpectedState 'enabled' -Compliance (& $script:NewCompliance @{
                    IsCompliant = $true; PolicyFiltering = 'IncludeUnassigned'; CompliantPolicies = @('AV - Draft'); NotConfiguredPolicies = @('AV - Core') })
            $md | Should -Match 'in 1 of the 2 evaluated Defender Antivirus policies'
            $md | Should -Not -Match 'assigned Defender'
        }
    }

    It 'describes compliant and non-compliant policies without claiming their values differ' {
        InModuleScope Maester {
            $md = Get-MdeComplianceResultMarkdown -SettingName 'Archive scanning' -ExpectedState 'enabled' -Compliance (& $script:NewCompliance @{
                    HasConflict = $true; CompliantPolicies = @('AV - Baseline'); NonCompliantPolicies = @('AV - Developer') })
            $md | Should -Match '^Archive scanning is compliant in some of the assigned Defender Antivirus policies and not in others\. Devices that receive only a non-compliant policy are not compliant'
            $md | Should -Match '\| AV - Developer \| ❌ Not compliant \|'
        }
    }

    It 'words a non-compliant value for one policy and for several' {
        InModuleScope Maester {
            $one = Get-MdeComplianceResultMarkdown -SettingName 'Full scan on mapped network drives' -ExpectedState 'correctly disabled' -Compliance (& $script:NewCompliance @{
                    NonCompliantPolicies = @('AV - Core'); NotConfiguredPolicies = @('AV - Exclusions') })
            $one | Should -Match '^Full scan on mapped network drives is not correctly disabled: the assigned policy that sets it doesn''t use a compliant value\.'
            $two = Get-MdeComplianceResultMarkdown -SettingName 'Archive scanning' -ExpectedState 'enabled' -Compliance (& $script:NewCompliance @{
                    NonCompliantPolicies = @('AV - A', 'AV - B') })
            $two | Should -Match '^Archive scanning is not enabled: the assigned policies that set it don''t use a compliant value\.'
        }
    }

    It 'words an unconfigured setting for one policy and for several, without guessing the device default' {
        InModuleScope Maester {
            $one = Get-MdeComplianceResultMarkdown -SettingName 'Archive scanning' -ExpectedState 'enabled' -Compliance (& $script:NewCompliance @{
                    TotalCount = 1; NotConfiguredPolicies = @('AV - Core') })
            $one | Should -Match '^Archive scanning isn''t set in the assigned Defender Antivirus policy, so Maester can''t confirm it\.'
            $two = Get-MdeComplianceResultMarkdown -SettingName 'Archive scanning' -ExpectedState 'enabled' -Compliance (& $script:NewCompliance @{
                    NotConfiguredPolicies = @('AV - A', 'AV - B') })
            $two | Should -Match '^Archive scanning isn''t set in any of the 2 assigned Defender Antivirus policies'
            $two | Should -Not -Match 'default'
        }
    }

    It 'escapes markdown in tenant-controlled policy names' {
        InModuleScope Maester {
            $md = Get-MdeComplianceResultMarkdown -SettingName 'Archive scanning' -ExpectedState 'enabled' -Compliance (& $script:NewCompliance @{
                    NonCompliantPolicies = @('AV | Dev', '[Sign in](https://phish.example)') })
            $md | Should -Match ([regex]::Escape("| $(Get-MtSafeMarkdown 'AV | Dev') |"))
            $md | Should -Match ([regex]::Escape("| $(Get-MtSafeMarkdown '[Sign in](https://phish.example)') |"))
            $md | Should -Not -Match '\| \[Sign in\]\(https'
        }
    }

    It 'keeps the AllPolicies wording and marks an unconfigured policy as a failure' {
        InModuleScope Maester {
            $md = Get-MdeComplianceResultMarkdown -SettingName 'Archive scanning' -ExpectedState 'enabled' -Compliance (& $script:NewCompliance @{
                    ComplianceLogic = 'AllPolicies'; CompliantPolicies = @('AV - Core'); NotConfiguredPolicies = @('AV - Exclusions') })
            $md | Should -Match '^Archive scanning is not properly configured in all policies\.'
            $md | Should -Match '\| AV - Exclusions \| ❌ Not configured \|'
        }
    }

    It 'words an AnyPolicy failure as "in any" policy' {
        InModuleScope Maester {
            Get-MdeComplianceResultMarkdown -SettingName 'Archive scanning' -ExpectedState 'enabled' -Compliance (& $script:NewCompliance @{
                    ComplianceLogic = 'AnyPolicy'; TotalCount = 1; NonCompliantPolicies = @('AV - Core') }) |
                Should -Match '^Archive scanning is not enabled in any assigned Defender Antivirus policy\.'
        }
    }

    It 'words an optional setting (MT.1159) as before' {
        InModuleScope Maester {
            Get-MdeComplianceResultMarkdown -SettingName 'Quick scan time configuration' -ExpectedState 'not required' -Compliance (& $script:NewCompliance @{
                    IsCompliant = $true; ComplianceCheck = 'NotRequired'; TotalCount = 1; CompliantPolicies = @('AV - Core') }) |
                Should -Match '^Well done\. Quick scan time configuration is not required, and the assigned Defender Antivirus policy is compliant\.'
        }
    }
}

Describe 'MDE antivirus checks MT.1148 to MT.1171' {
    It 'MT.1148 passes a tenant that enables archive scanning in one of two assigned policies' {
        InModuleScope Maester {
            $settingId = 'device_vendor_msft_policy_config_defender_allowarchivescanning'
            $script:MdeSettings = @{
                'deviceManagement/configurationPolicies/p1/settings' = @([pscustomobject]@{ settingInstance = [pscustomobject]@{ settingDefinitionId = $settingId; choiceSettingValue = [pscustomobject]@{ value = "${settingId}_1" } } })
                'deviceManagement/configurationPolicies/p2/settings' = @()
            }
            Mock Get-MdeDeviceCount { 3 }
            Mock Get-MdePolicyConfiguration { @{ ConfigurationPolicies = @([pscustomobject]@{ id = 'p1'; name = 'AV - Core' }, [pscustomobject]@{ id = 'p2'; name = 'AV - Exclusions' }); TotalCount = 2; PolicyFiltering = 'OnlyAssigned' } }
            Mock Invoke-MtGraphRequest { $script:MdeSettings[$RelativeUri] }
            Mock Add-MtTestResultDetail { $script:MdeResult = $Result }

            Test-MtMdeArchiveScanning | Should -BeTrue
            $script:MdeResult | Should -Match '^Well done\. Archive scanning is enabled in 1 of the 2 assigned Defender Antivirus policies'
            Test-MtMdeArchiveScanning -ComplianceLogic AllPolicies | Should -BeFalse
            Remove-Variable -Scope Script -Name MdeSettings, MdeResult -ErrorAction SilentlyContinue
        }
    }

    It 'every check defaults to EffectivePolicy and still offers AllPolicies and AnyPolicy' {
        InModuleScope Maester {
            $names = 'ArchiveScanning', 'BehaviorMonitoring', 'CloudProtection', 'EmailScanning', 'ScriptScanning',
            'RealtimeMonitoring', 'RemovableDriveScanning', 'MappedDriveScanning', 'NetworkFileScanning', 'CpuLoadFactor',
            'ScheduleScanDay', 'QuickScanTime', 'SignatureBeforeScan', 'CloudBlockLevel', 'CloudExtendedTimeout',
            'SignatureUpdateInterval', 'PuaProtection', 'NetworkProtection', 'DisableLocalAdminMerge', 'RealtimeScanDirection',
            'RetainCleanedMalware', 'CatchupFullScan', 'CatchupQuickScan', 'SubmitSamplesConsent'
            foreach ($name in $names) {
                $command = Get-Command "Test-MtMde$name"
                $param = $command.Parameters['ComplianceLogic']
                $param.Attributes.Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] }).ValidValues |
                    Should -Be @('EffectivePolicy', 'AllPolicies', 'AnyPolicy') -Because "Test-MtMde$name offers the three logics"
                $command.ScriptBlock.Ast.Body.ParamBlock.Parameters.Where({ $_.Name.VariablePath.UserPath -eq 'ComplianceLogic' }).DefaultValue.Value |
                    Should -Be 'EffectivePolicy' -Because "Test-MtMde$name defaults to EffectivePolicy"
            }
        }
    }
}
