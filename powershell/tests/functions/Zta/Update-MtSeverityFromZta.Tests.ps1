# Unit tests for Update-MtSeverityFromZta.
# Verifies rule firing thresholds (WhenPillarFailedAtLeast / WhenCategoryFlaggedUsersAtLeast),
# selector matching (Tagged / TestId wildcards), severity ladder enforcement, and idempotence.

Describe 'Update-MtSeverityFromZta — severity escalation' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
        $script:fixtureDir = Join-Path $PSScriptRoot 'fixtures'
    }

    BeforeEach {
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        $script:bundle = Join-Path ([System.IO.Path]::GetTempPath()) ("mt-zta-sev-$([guid]::NewGuid())")
        New-Item -ItemType Directory -Force -Path $script:bundle | Out-Null
        Copy-Item (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')
        Copy-Item (Join-Path $script:fixtureDir 'manifest.sample.json') (Join-Path $script:bundle 'manifest.json')
    }

    AfterEach {
        if ($script:bundle -and (Test-Path $script:bundle)) { Remove-Item -Recurse -Force $script:bundle }
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
    }

    Context 'No-op paths' {

        It 'returns input unchanged when MtZtaContext is unset' {
            $ts = @( [pscustomobject]@{ Id='X.1'; Severity='Medium' } )
            $out = @(Update-MtSeverityFromZta -TestSettings $ts -WhatIf:$false)
            $out[0].Severity | Should -Be 'Medium'
        }

        It 'returns input unchanged when ZTA loaded without ZtaSettings' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            $ts = @( [pscustomobject]@{ Id='X.1'; Severity='Medium'; Tag=@('MFA') } )
            $out = @(Update-MtSeverityFromZta -TestSettings $ts)
            $out[0].Severity | Should -Be 'Medium'
        }

        It 'returns input unchanged when SeverityEscalationRules array is empty' {
            $settings = [pscustomobject]@{ SeverityEscalationRules = @() }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings
            $ts = @( [pscustomobject]@{ Id='X.1'; Severity='Medium'; Tag=@('MFA') } )
            $out = @(Update-MtSeverityFromZta -TestSettings $ts)
            $out[0].Severity | Should -Be 'Medium'
        }
    }

    Context 'Pillar-threshold rules' {

        It 'escalates when WhenPillarFailedAtLeast threshold is met' {
            # Fixture has exactly 1 Identity failure. Use threshold 1 so the rule fires.
            $settings = [pscustomobject]@{
                SeverityEscalationRules = @(
                    [pscustomobject]@{
                        WhenPillarFailedAtLeast = 1
                        Pillar                  = 'Identity'
                        EscalateMaesterTagged   = @('MFA')
                        From                    = 'Medium'
                        To                      = 'High'
                    }
                )
            }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings

            $ts = @(
                [pscustomobject]@{ Id='M.1'; Severity='Medium'; Tag=@('MFA','Identity') }
                [pscustomobject]@{ Id='M.2'; Severity='Medium'; Tag=@('Other') }
            )
            $out = @(Update-MtSeverityFromZta -TestSettings $ts)
            $out[0].Severity | Should -Be 'High'    # tag 'MFA' matched
            $out[1].Severity | Should -Be 'Medium'  # tag 'Other' did not match
        }

        It 'does NOT escalate when WhenPillarFailedAtLeast threshold is not met' {
            $settings = [pscustomobject]@{
                SeverityEscalationRules = @(
                    [pscustomobject]@{
                        WhenPillarFailedAtLeast = 99
                        Pillar                  = 'Identity'
                        EscalateMaesterTagged   = @('MFA')
                        From                    = 'Medium'
                        To                      = 'High'
                    }
                )
            }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings

            $ts = @( [pscustomobject]@{ Id='M.1'; Severity='Medium'; Tag=@('MFA') } )
            $out = @(Update-MtSeverityFromZta -TestSettings $ts)
            $out[0].Severity | Should -Be 'Medium'
        }

        It 'honours From-gate (only escalates if current severity matches From)' {
            $settings = [pscustomobject]@{
                SeverityEscalationRules = @(
                    [pscustomobject]@{
                        WhenPillarFailedAtLeast = 1
                        Pillar                  = 'Identity'
                        EscalateMaesterTagged   = @('MFA')
                        From                    = 'Medium'
                        To                      = 'High'
                    }
                )
            }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings

            $ts = @(
                [pscustomobject]@{ Id='L.1'; Severity='Low';      Tag=@('MFA') }    # not Medium -> skip
                [pscustomobject]@{ Id='C.1'; Severity='Critical'; Tag=@('MFA') }    # already > High -> skip
                [pscustomobject]@{ Id='M.1'; Severity='Medium';   Tag=@('MFA') }    # exact match -> escalate
            )
            $out = @(Update-MtSeverityFromZta -TestSettings $ts)
            $out[0].Severity | Should -Be 'Low'
            $out[1].Severity | Should -Be 'Critical'
            $out[2].Severity | Should -Be 'High'
        }
    }

    Context 'TestId selector with wildcards' {

        It 'matches by EscalateMaesterTestId wildcard pattern' {
            $settings = [pscustomobject]@{
                SeverityEscalationRules = @(
                    [pscustomobject]@{
                        WhenPillarFailedAtLeast = 1
                        Pillar                  = 'Identity'
                        EscalateMaesterTestId   = @('CISA.MS.AAD.8.*')
                        To                      = 'High'
                    }
                )
            }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings

            $ts = @(
                [pscustomobject]@{ Id='CISA.MS.AAD.8.1'; Severity='Medium' }
                [pscustomobject]@{ Id='CISA.MS.AAD.7.1'; Severity='Medium' }
            )
            $out = @(Update-MtSeverityFromZta -TestSettings $ts)
            $out[0].Severity | Should -Be 'High'
            $out[1].Severity | Should -Be 'Medium'
        }
    }

    Context 'Severity ladder' {

        It 'never lowers severity (Medium -> Low rule is a no-op)' {
            $settings = [pscustomobject]@{
                SeverityEscalationRules = @(
                    [pscustomobject]@{
                        WhenPillarFailedAtLeast = 1
                        Pillar                  = 'Identity'
                        EscalateMaesterTagged   = @('MFA')
                        To                      = 'Low'   # below default Medium -> no-op
                    }
                )
            }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings

            $ts = @( [pscustomobject]@{ Id='M.1'; Severity='Medium'; Tag=@('MFA') } )
            $out = @(Update-MtSeverityFromZta -TestSettings $ts)
            $out[0].Severity | Should -Be 'Medium'
        }
    }

    Context 'Idempotence' {

        It 'second invocation does not re-escalate (already at target)' {
            $settings = [pscustomobject]@{
                SeverityEscalationRules = @(
                    [pscustomobject]@{
                        WhenPillarFailedAtLeast = 1
                        Pillar                  = 'Identity'
                        EscalateMaesterTagged   = @('MFA')
                        From                    = 'Medium'
                        To                      = 'High'
                    }
                )
            }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings

            $ts = @( [pscustomobject]@{ Id='M.1'; Severity='Medium'; Tag=@('MFA') } )

            $out1 = @(Update-MtSeverityFromZta -TestSettings $ts)
            $out1[0].Severity | Should -Be 'High'

            $out2 = @(Update-MtSeverityFromZta -TestSettings $ts)
            $out2[0].Severity | Should -Be 'High'    # unchanged on second run
        }
    }
}
