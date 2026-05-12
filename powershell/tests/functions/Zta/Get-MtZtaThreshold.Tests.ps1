# Unit tests for Get-MtZtaThreshold.
# Covers: default fallback when context is empty / ZtaSettings missing / key absent,
# and value resolution from both hashtable and pscustomobject ZtaSettings shapes.

Describe 'Get-MtZtaThreshold' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
        $script:fixtureDir = Join-Path $PSScriptRoot 'fixtures'
    }

    BeforeEach {
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        $script:bundle = Join-Path ([System.IO.Path]::GetTempPath()) ("mt-zta-thr-$([guid]::NewGuid())")
        New-Item -ItemType Directory -Force -Path $script:bundle | Out-Null
        Copy-Item (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')
        Copy-Item (Join-Path $script:fixtureDir 'manifest.sample.json') (Join-Path $script:bundle 'manifest.json')
    }

    AfterEach {
        if ($script:bundle -and (Test-Path $script:bundle)) { Remove-Item -Recurse -Force $script:bundle }
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
    }

    Context 'Default fallback' {
        It 'returns the -Default when no MtZtaContext is loaded' {
            (Get-MtZtaThreshold -TestId 'MT.Zta.1001' -Default 42) | Should -Be 42
        }

        It 'returns the -Default when ZtaSettings is null' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            (Get-MtZtaThreshold -TestId 'MT.Zta.1001' -Default 99) | Should -Be 99
        }

        It 'returns the -Default when Thresholds is absent from ZtaSettings' {
            $settings = [pscustomobject]@{ FreshnessDays = 14 }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings
            (Get-MtZtaThreshold -TestId 'MT.Zta.1001' -Default 17) | Should -Be 17
        }

        It 'returns the -Default when the key is not present in Thresholds' {
            $settings = [pscustomobject]@{
                Thresholds = [pscustomobject]@{ 'MT.Zta.1004' = 5 }
            }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings
            (Get-MtZtaThreshold -TestId 'MT.Zta.1001' -Default 30) | Should -Be 30
        }
    }

    Context 'Value resolution' {
        It 'returns the configured value when Thresholds is a pscustomobject (ConvertFrom-Json default)' {
            $settings = [pscustomobject]@{
                Thresholds = [pscustomobject]@{
                    'MT.Zta.1001' = 50
                    'MT.Zta.1002' = 0.7
                }
            }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings
            (Get-MtZtaThreshold -TestId 'MT.Zta.1001' -Default 30) | Should -Be 50
            (Get-MtZtaThreshold -TestId 'MT.Zta.1002' -Default 0.5) | Should -Be 0.7
        }

        It 'returns the configured value when Thresholds is a hashtable (-AsHashtable shape)' {
            $settings = @{ Thresholds = @{ 'MT.Zta.1001' = 25 } }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings
            (Get-MtZtaThreshold -TestId 'MT.Zta.1001' -Default 30) | Should -Be 25
        }

        It 'preserves the configured value type (int stays int, double stays double)' {
            $settings = [pscustomobject]@{
                Thresholds = [pscustomobject]@{
                    'MT.Zta.1001' = 30
                    'MT.Zta.1002' = 0.5
                }
            }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -ZtaSettings $settings
            (Get-MtZtaThreshold -TestId 'MT.Zta.1001' -Default 0)   | Should -BeOfType ([int])
            (Get-MtZtaThreshold -TestId 'MT.Zta.1002' -Default 0.0) | Should -BeOfType ([double])
        }
    }
}
