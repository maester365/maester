Describe 'Defender for Cloud recommendations and attack paths' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Native tests, their instance sources and internal helpers; none is exported.
        Use-MtModuleFunction -Name Test-MtAzureDefenderForCloudRecommendation,
            Get-MtAzureDefenderForCloudRecommendationInstance,
            Test-MtAzureDefenderForCloudAttackPath,
            Get-MtAzureDefenderForCloudAttackPathInstance,
            Get-MtDefenderForCloudRecommendation,
            Get-MtDefenderForCloudAttackPath

        function Get-TestRecommendation {
            param(
                [int] $Unhealthy = 0, [int] $Healthy = 3, [int] $NotApplicable = 0, [int] $Exempt = 0,
                [string] $Severity = 'Medium', [string] $RiskLevel = ''
            )
            $total = $Unhealthy + $Healthy + $NotApplicable
            return [pscustomobject]@{
                AssessmentKey         = '01d9a108-3379-4c5a-8236-1a724dummy'
                DisplayName           = 'App Service apps should use the latest HTTP version'
                Severity              = $Severity
                RiskLevel             = $RiskLevel
                PortalUri             = 'https://portal.azure.com/#blade/dummy'
                TotalCount            = $total
                UnhealthyCount        = $Unhealthy
                HealthyCount          = $Healthy
                NotApplicableCount    = $NotApplicable
                ExemptCount           = $Exempt
                UnhealthyResourceList = @('app-01', 'app-02')
            }
        }

        function Get-TestPath {
            return [pscustomobject]@{
                AttackPathType     = '563f8222-1c75-4d35-3114-588a83b45762'
                DisplayName        = 'Internet exposed Azure VM allows lateral movement to a storage account'
                RiskLevel          = 'High'
                PathCount          = 1
                RiskFactorList     = @('Internet exposure', 'Vulnerabilities')
                TacticList         = @('Lateral Movement', 'Initial Access')
                EntryPointTypeList = @('microsoft.compute/virtualmachines')
                TargetList         = @('storage-01')
                TargetTypeList     = @('microsoft.storage/storageaccounts')
            }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:SkippedCustomReason = $null
        $script:Severity = $null

        Mock -ModuleName Maester Get-MtLicenseInformation { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedCustomReason, $Severity)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedCustomReason = $SkippedCustomReason
            $script:Severity = $Severity
        }
    }

    Context 'MT.1257 recommendations' {
        It 'passes when no resource is unhealthy' {
            $i = [pscustomobject]@{ Data = Get-TestRecommendation -Unhealthy 0 -Healthy 5 }

            Test-MtAzureDefenderForCloudRecommendation -Instance $i | Should -BeTrue
            $script:TestResult | Should -Match 'None is unhealthy'
        }

        It 'fails when any resource is unhealthy and names them' {
            $i = [pscustomobject]@{ Data = Get-TestRecommendation -Unhealthy 2 -Healthy 1 }

            Test-MtAzureDefenderForCloudRecommendation -Instance $i | Should -BeFalse
            $script:TestResult | Should -Match '\*\*2\*\* of them are unhealthy'
            $script:TestResult | Should -Match 'app-01, app-02'
        }

        It 'skips with the exemption count when every resource is exempt' {
            $i = [pscustomobject]@{ Data = Get-TestRecommendation -Unhealthy 0 -Healthy 0 -NotApplicable 4 -Exempt 4 }

            $null -eq (Test-MtAzureDefenderForCloudRecommendation -Instance $i) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'Custom'
            $script:SkippedCustomReason | Should -Match 'exempt'
        }

        It 'skips instead of passing when nothing was evaluated either way' {
            # No unhealthy over no evaluated resource is not a pass.
            $i = [pscustomobject]@{ Data = Get-TestRecommendation -Unhealthy 0 -Healthy 0 -NotApplicable 6 }

            $null -eq (Test-MtAzureDefenderForCloudRecommendation -Instance $i) | Should -BeTrue
            $script:SkippedBecause | Should -Be 'NotApplicable'
        }

        It 'prefers the Defender CSPM risk level over the metadata severity' {
            $i = [pscustomobject]@{ Data = Get-TestRecommendation -Unhealthy 1 -Severity 'Low' -RiskLevel 'Critical' }

            $null = Test-MtAzureDefenderForCloudRecommendation -Instance $i
            $script:Severity | Should -Be 'High' -Because 'Critical maps to High and beats the Low metadata severity'
        }

        It 'falls back to the metadata severity when there is no risk level' {
            $i = [pscustomobject]@{ Data = Get-TestRecommendation -Unhealthy 1 -Severity 'Low' -RiskLevel '' }

            $null = Test-MtAzureDefenderForCloudRecommendation -Instance $i
            $script:Severity | Should -Be 'Low'
        }

        It 'emits one instance per recommendation and none when there is no assessment' {
            Mock -ModuleName Maester Get-MtDefenderForCloudRecommendation { @(Get-TestRecommendation), @(Get-TestRecommendation) }
            @(Get-MtAzureDefenderForCloudRecommendationInstance).Count | Should -Be 2

            Mock -ModuleName Maester Get-MtDefenderForCloudRecommendation { @() }
            @(Get-MtAzureDefenderForCloudRecommendationInstance).Count | Should -Be 0
        }
    }

    Context 'MT.1258 attack paths' {
        It 'reports the family as not licensed when Defender CSPM is off' {
            # Without the plan no attack path was ever computed, so an empty result says nothing.
            Mock -ModuleName Maester Get-MtDefenderForCloudAttackPath {
                [pscustomobject]@{ CspmEnabled = $false; PathList = @() }
            }

            @(Get-MtAzureDefenderForCloudAttackPathInstance).Count | Should -Be 0
            $script:SkippedBecause | Should -Be 'Custom'
            $script:SkippedCustomReason | Should -Match 'Defender CSPM is not enabled'
        }

        It 'emits nothing without claiming a licence problem when the plan is on and no path exists' {
            Mock -ModuleName Maester Get-MtDefenderForCloudAttackPath {
                [pscustomobject]@{ CspmEnabled = $true; PathList = @() }
            }

            @(Get-MtAzureDefenderForCloudAttackPathInstance).Count | Should -Be 0
            $script:SkippedCustomReason | Should -BeNullOrEmpty
        }

        It 'uses the attack path type GUID as the instance id, not the sentence' {
            # The engine requires ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$, which a sentence never matches.
            Mock -ModuleName Maester Get-MtDefenderForCloudAttackPath {
                [pscustomobject]@{ CspmEnabled = $true; PathList = @(Get-TestPath) }
            }

            $instance = @(Get-MtAzureDefenderForCloudAttackPathInstance)[0]
            $instance.Id | Should -Match '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
            $instance.Title | Should -Match 'Internet exposed Azure VM'
        }

        It 'fails for a reported path, with its risk factors and tactics' {
            $i = [pscustomobject]@{ Data = Get-TestPath }

            Test-MtAzureDefenderForCloudAttackPath -Instance $i | Should -BeFalse
            $script:Severity | Should -Be 'High'
            $script:TestResult | Should -Match 'microsoft.compute/virtualmachines'
            $script:TestResult | Should -Match 'Internet exposure, Vulnerabilities'
            $script:TestResult | Should -Match 'Lateral Movement, Initial Access'
        }
    }

    Context 'Get-MtDefenderForCloudAttackPath' {
        It 'reads CspmEnabled from the CloudPosture pricing tier' {
            Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest {
                if ($Query -match 'microsoft.security/pricings') { return @([pscustomobject]@{ StandardCount = 1 }) }
                return @()
            }

            (Get-MtDefenderForCloudAttackPath).CspmEnabled | Should -BeTrue

            Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest {
                if ($Query -match 'microsoft.security/pricings') { return @([pscustomobject]@{ StandardCount = 0 }) }
                return @()
            }

            (Get-MtDefenderForCloudAttackPath).CspmEnabled | Should -BeFalse
        }

        It 'parses the risk factors and tactics that arrive as JSON text' {
            # Azure Resource Graph has no mv-apply, so the arrays travel as their JSON text.
            Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest {
                if ($Query -match 'microsoft.security/pricings') { return @([pscustomobject]@{ StandardCount = 1 }) }
                return @([pscustomobject]@{
                        AttackPathType     = '563f8222-1c75-4d35-3114-588a83b45762'
                        DisplayName        = 'A path'
                        RiskLevel          = 'High'
                        PathCount          = 2
                        RiskFactorsJson    = '["Internet exposure","Plaintext keys"]'
                        TacticsJson        = '["Exfiltration"]'
                        EntryPointTypeList = @('microsoft.compute/virtualmachines')
                        TargetList         = @('storage-01')
                        TargetTypeList     = @('microsoft.storage/storageaccounts')
                    })
            }

            $path = (Get-MtDefenderForCloudAttackPath).PathList[0]
            $path.RiskFactorList | Should -Contain 'Plaintext keys'
            $path.TacticList | Should -Contain 'Exfiltration'
            $path.PathCount | Should -Be 2
        }

        It 'survives risk factors that are not valid JSON' {
            Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest {
                if ($Query -match 'microsoft.security/pricings') { return @([pscustomobject]@{ StandardCount = 1 }) }
                return @([pscustomobject]@{
                        AttackPathType  = 'abc'
                        DisplayName     = 'A path'
                        RiskLevel       = 'Low'
                        PathCount       = 1
                        RiskFactorsJson = 'not json at all'
                        TacticsJson     = ''
                    })
            }

            $path = (Get-MtDefenderForCloudAttackPath).PathList[0]
            @($path.RiskFactorList).Count | Should -Be 0
            @($path.TacticList).Count | Should -Be 0
        }
    }

    Context 'Get-MtDefenderForCloudRecommendation' {
        It 'returns an empty list, not null, when there is no assessment' {
            Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest { @() }

            $r = Get-MtDefenderForCloudRecommendation
            $null -eq $r | Should -BeFalse
            $r.Count | Should -Be 0
        }

        It 'drops rows without an assessment key and normalises the counts' {
            Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest {
                @(
                    [pscustomobject]@{
                        AssessmentKey = 'key-1'; DisplayName = 'A'; Severity = 'High'; RiskLevel = 'Medium'
                        PortalUri = 'https://x'; TotalCount = 7; UnhealthyCount = 3; HealthyCount = 4
                        NotApplicableCount = 0; ExemptCount = 0; UnhealthyResourceList = @('r1')
                    },
                    [pscustomobject]@{ AssessmentKey = '' }
                )
            }

            $r = Get-MtDefenderForCloudRecommendation
            $r.Count | Should -Be 1
            $r[0].UnhealthyCount | Should -Be 3
            $r[0].RiskLevel | Should -Be 'Medium'
        }
    }
}
