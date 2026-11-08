Describe 'Entra ID Protection open workload identity risk detections (MT.1274)' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The native-test functions are not exported; reach them the same way the other check tests do.
        Use-MtModuleFunction -Name Test-MtEntraServicePrincipalRiskDetection, Get-MtServicePrincipalRiskDetectionInstance

        function script:New-TestDetection {
            param(
                [string] $Type = 'leakedCredentials',
                [string] $Level = 'high',
                [string] $State = 'atRisk',
                [string] $Upn = 'alice@contoso.com',
                [string] $Detected = '2026-10-01T00:00:00Z'
            )
            [pscustomobject]@{
                id                = [guid]::NewGuid().ToString()
                riskEventType     = $Type
                riskLevel         = $Level
                riskState         = $State
                activity          = 'signin'
                ipAddress         = '203.0.113.10'
                location          = [pscustomobject]@{ city = 'Seattle'; countryOrRegion = 'US' }
                detectedDateTime  = $Detected
                servicePrincipalId = 'sp-1'
                servicePrincipalDisplayName = 'Alice'
                appId             = $Upn
            }
        }

        # The documented instances, read once so the per-test mocks of Get-MtServicePrincipalRiskDetection stay in charge.
        $script:DocumentedInstances = InModuleScope Maester {
            # Capture the script block first: Set-Item updates the FunctionInfo object in place.
            $realBody = (Get-Command Get-MtServicePrincipalRiskDetection).ScriptBlock
            Set-Item -Path function:Get-MtServicePrincipalRiskDetection -Value { @() }
            try { Get-MtServicePrincipalRiskDetectionInstance } finally { Set-Item -Path function:Get-MtServicePrincipalRiskDetection -Value $realBody }
        }

        function script:Get-TestInstance {
            param([string] $Id)
            $script:DocumentedInstances | Where-Object { $_.Id -eq $Id }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:Severity = $null

        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedError, $Severity)
            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:Severity = $Severity
        }
    }

    AfterEach {
        # Result text must not contain backtick-wrapped code spans (repo result-text lint).
        if ($null -ne $script:TestResult) {
            $script:TestResult | Should -Not -Match '`[^`]+`'
        }
    }

    Context 'Instance source' {
        It 'returns one instance per documented detection type' {
            $instances = InModuleScope Maester {
                Mock Get-MtServicePrincipalRiskDetection { return @() }
                Get-MtServicePrincipalRiskDetectionInstance
            }
            $instances.Count | Should -Be 8
            ($instances.Id | Sort-Object -Unique).Count | Should -Be 8
            $instances.Id | Should -Contain 'maliciousApplication'
            $instances.Id | Should -Contain 'anomalousServicePrincipalActivity'
            foreach ($instance in $instances) {
                $instance.Id | Should -Match '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
                $instance.Severity | Should -BeIn @('High', 'Medium', 'Low')
                $instance.Data.About | Should -Not -BeNullOrEmpty
                $instance.Data.Tips | Should -Match '^https://learn\.microsoft\.com/'
            }
        }

        It 'adds a row for an undocumented detection type that has open detections' {
            $instances = InModuleScope Maester {
                Mock Get-MtServicePrincipalRiskDetection {
                    return @(
                        [pscustomobject]@{ riskEventType = 'leakedCredentials' }
                        [pscustomobject]@{ riskEventType = 'brandNewDetection' }
                    )
                }
                Get-MtServicePrincipalRiskDetectionInstance
            }
            $instances.Count | Should -Be 9
            $instances.Id | Should -Contain 'brandNewDetection'
        }

        It 'returns the documented types when the detections cannot be read' {
            $instances = InModuleScope Maester {
                Mock Get-MtServicePrincipalRiskDetection { throw '403 Forbidden' }
                Get-MtServicePrincipalRiskDetectionInstance
            }
            $instances.Count | Should -Be 8
        }
    }

    Context 'Check' {
        It 'passes when no detection of the type is open' {
            Mock -ModuleName Maester Get-MtServicePrincipalRiskDetection { return @(New-TestDetection -Type 'suspiciousSignins') }

            Test-MtEntraServicePrincipalRiskDetection -Instance (Get-TestInstance 'leakedCredentials') | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
            $script:Severity | Should -Be 'High'
        }

        It 'fails and lists the open detections of the type, high risk first' {
            Mock -ModuleName Maester Get-MtServicePrincipalRiskDetection {
                return @(
                    New-TestDetection -Level 'low' -Upn 'low@contoso.com'
                    New-TestDetection -Level 'high' -Upn 'high@contoso.com'
                    New-TestDetection -Level 'medium' -Upn 'medium@contoso.com' -State 'confirmedCompromised'
                    New-TestDetection -Type 'suspiciousSignins' -Upn 'other@contoso.com'
                )
            }

            Test-MtEntraServicePrincipalRiskDetection -Instance (Get-TestInstance 'leakedCredentials') | Should -BeFalse
            $script:TestResult | Should -Match 'Found 3 open'
            $script:TestResult | Should -Match '1 high, 1 medium, 1 low'
            $script:TestResult | Should -Not -Match 'other@contoso\.com'
            $script:TestResult.IndexOf('high@contoso.com') | Should -BeLessThan $script:TestResult.IndexOf('medium@contoso.com')
            $script:TestResult.IndexOf('medium@contoso.com') | Should -BeLessThan $script:TestResult.IndexOf('low@contoso.com')
        }

        It 'skips as not authorized when Graph returns 403' {
            Mock -ModuleName Maester Get-MtServicePrincipalRiskDetection { throw 'Response status code does not indicate success: 403 (Forbidden).' }

            Test-MtEntraServicePrincipalRiskDetection -Instance (Get-TestInstance 'leakedCredentials') | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'limits the table and says how many more there are' {
            Mock -ModuleName Maester Get-MtServicePrincipalRiskDetection {
                return @(1..105 | ForEach-Object { New-TestDetection -Type 'suspiciousAPITraffic' -Level 'low' -Upn "user$_@contoso.com" })
            }

            Test-MtEntraServicePrincipalRiskDetection -Instance (Get-TestInstance 'suspiciousAPITraffic') | Should -BeFalse
            $script:TestResult | Should -Match 'Showing the first 100 of 105'
        }

        It 'escapes a tenant-controlled display name' {
            Mock -ModuleName Maester Get-MtServicePrincipalRiskDetection {
                $d = New-TestDetection
                $d.servicePrincipalDisplayName = '[Sign in again](https://phish.example)'
                return @($d)
            }

            Test-MtEntraServicePrincipalRiskDetection -Instance (Get-TestInstance 'leakedCredentials') | Should -BeFalse
            $script:TestResult | Should -Not -Match '(?<!\\)\[Sign in again\]\('
        }
    }

    Context 'Data access' {
        It 'reads the two open risk states from the v1.0 endpoint' {
            InModuleScope Maester {
                Mock Invoke-MtGraphRequest { return @() }
                Get-MtServicePrincipalRiskDetection | Should -BeNullOrEmpty
                Should -Invoke Invoke-MtGraphRequest -Exactly -Times 2
                Should -Invoke Invoke-MtGraphRequest -Exactly -Times 1 -ParameterFilter {
                    $ApiVersion -eq 'v1.0' -and $RelativeUri -eq 'identityProtection/servicePrincipalRiskDetections' -and $Filter -eq "riskState eq 'atRisk'"
                }
                Should -Invoke Invoke-MtGraphRequest -Exactly -Times 1 -ParameterFilter {
                    $Filter -eq "riskState eq 'confirmedCompromised'"
                }
            }
        }
    }
}
