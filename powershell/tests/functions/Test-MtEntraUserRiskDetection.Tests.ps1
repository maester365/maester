Describe 'Entra ID Protection open user risk detections (MT.1273)' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The native-test functions are not exported; reach them the same way the other check tests do.
        Use-MtModuleFunction -Name Test-MtEntraUserRiskDetection, Get-MtUserRiskDetectionInstance

        function script:New-TestDetection {
            param(
                [string] $Type = 'passwordSpray',
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
                userId            = 'user-1'
                userDisplayName   = 'Alice'
                userPrincipalName = $Upn
            }
        }

        # The documented instances, read once so the per-test mocks of Get-MtUserRiskDetection stay in charge.
        $script:DocumentedInstances = InModuleScope Maester {
            # Capture the script block first: Set-Item updates the FunctionInfo object in place.
            $realBody = (Get-Command Get-MtUserRiskDetection).ScriptBlock
            Set-Item -Path function:Get-MtUserRiskDetection -Value { @() }
            try { Get-MtUserRiskDetectionInstance } finally { Set-Item -Path function:Get-MtUserRiskDetection -Value $realBody }
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
        Mock -ModuleName Maester Get-MtLicenseInformation { return 'P2' }
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
                Mock Get-MtUserRiskDetection { return @() }
                Get-MtUserRiskDetectionInstance
            }
            $instances.Count | Should -Be 27
            ($instances.Id | Sort-Object -Unique).Count | Should -Be 27
            $instances.Id | Should -Contain 'suspiciousCredentialAddition'
            $instances.Id | Should -Contain 'generic'
            foreach ($instance in $instances) {
                $instance.Id | Should -Match '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
                $instance.Severity | Should -BeIn @('High', 'Medium', 'Low')
                $instance.Data.About | Should -Not -BeNullOrEmpty
                $instance.Data.Tips | Should -Match '^https://learn\.microsoft\.com/'
            }
        }

        It 'adds a row for an undocumented detection type that has open detections' {
            $instances = InModuleScope Maester {
                Mock Get-MtUserRiskDetection {
                    return @(
                        [pscustomobject]@{ riskEventType = 'passwordSpray' }
                        [pscustomobject]@{ riskEventType = 'brandNewDetection' }
                    )
                }
                Get-MtUserRiskDetectionInstance
            }
            $instances.Count | Should -Be 28
            $instances.Id | Should -Contain 'brandNewDetection'
        }

        It 'returns the documented types when the detections cannot be read' {
            $instances = InModuleScope Maester {
                Mock Get-MtUserRiskDetection { throw '403 Forbidden' }
                Get-MtUserRiskDetectionInstance
            }
            $instances.Count | Should -Be 27
        }
    }

    Context 'Check' {
        It 'passes when no detection of the type is open' {
            Mock -ModuleName Maester Get-MtUserRiskDetection { return @(New-TestDetection -Type 'leakedCredentials') }

            Test-MtEntraUserRiskDetection -Instance (Get-TestInstance 'passwordSpray') | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
            $script:Severity | Should -Be 'High'
        }

        It 'fails and lists the open detections of the type, high risk first' {
            Mock -ModuleName Maester Get-MtUserRiskDetection {
                return @(
                    New-TestDetection -Level 'low' -Upn 'low@contoso.com'
                    New-TestDetection -Level 'high' -Upn 'high@contoso.com'
                    New-TestDetection -Level 'medium' -Upn 'medium@contoso.com' -State 'confirmedCompromised'
                    New-TestDetection -Type 'leakedCredentials' -Upn 'other@contoso.com'
                )
            }

            Test-MtEntraUserRiskDetection -Instance (Get-TestInstance 'passwordSpray') | Should -BeFalse
            $script:TestResult | Should -Match 'Found 3 open'
            $script:TestResult | Should -Match '1 high, 1 medium, 1 low'
            $script:TestResult | Should -Not -Match 'other@contoso\.com'
            $script:TestResult.IndexOf('high@contoso.com') | Should -BeLessThan $script:TestResult.IndexOf('medium@contoso.com')
            $script:TestResult.IndexOf('medium@contoso.com') | Should -BeLessThan $script:TestResult.IndexOf('low@contoso.com')
        }

        It 'skips a premium detection type without Entra ID P2' {
            Mock -ModuleName Maester Get-MtLicenseInformation { return 'P1' }
            Mock -ModuleName Maester Get-MtUserRiskDetection { return @() }

            Test-MtEntraUserRiskDetection -Instance (Get-TestInstance 'passwordSpray') | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotLicensedEntraIDP2'
            Should -Invoke Get-MtUserRiskDetection -ModuleName Maester -Exactly -Times 0
        }

        It 'checks a non-premium detection type without Entra ID P2' {
            Mock -ModuleName Maester Get-MtLicenseInformation { return 'P1' }
            Mock -ModuleName Maester Get-MtUserRiskDetection { return @(New-TestDetection -Type 'leakedCredentials') }

            Test-MtEntraUserRiskDetection -Instance (Get-TestInstance 'leakedCredentials') | Should -BeFalse
        }

        It 'skips as not authorized when Graph returns 403' {
            Mock -ModuleName Maester Get-MtUserRiskDetection { throw 'Response status code does not indicate success: 403 (Forbidden).' }

            Test-MtEntraUserRiskDetection -Instance (Get-TestInstance 'passwordSpray') | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'NotAuthorized'
        }

        It 'limits the table and says how many more there are' {
            Mock -ModuleName Maester Get-MtUserRiskDetection {
                return @(1..105 | ForEach-Object { New-TestDetection -Type 'anonymizedIPAddress' -Level 'low' -Upn "user$_@contoso.com" })
            }

            Test-MtEntraUserRiskDetection -Instance (Get-TestInstance 'anonymizedIPAddress') | Should -BeFalse
            $script:TestResult | Should -Match 'Showing the first 100 of 105'
        }

        It 'escapes a tenant-controlled display name' {
            Mock -ModuleName Maester Get-MtUserRiskDetection {
                $d = New-TestDetection
                $d.userDisplayName = '[Sign in again](https://phish.example)'
                return @($d)
            }

            Test-MtEntraUserRiskDetection -Instance (Get-TestInstance 'passwordSpray') | Should -BeFalse
            $script:TestResult | Should -Not -Match '(?<!\\)\[Sign in again\]\('
        }
    }

    Context 'Data access' {
        It 'reads the two open risk states from the v1.0 endpoint' {
            InModuleScope Maester {
                Mock Invoke-MtGraphRequest { return @() }
                Get-MtUserRiskDetection | Should -BeNullOrEmpty
                Should -Invoke Invoke-MtGraphRequest -Exactly -Times 2
                Should -Invoke Invoke-MtGraphRequest -Exactly -Times 1 -ParameterFilter {
                    $ApiVersion -eq 'v1.0' -and $RelativeUri -eq 'identityProtection/riskDetections' -and $Filter -eq "riskState eq 'atRisk'"
                }
                Should -Invoke Invoke-MtGraphRequest -Exactly -Times 1 -ParameterFilter {
                    $Filter -eq "riskState eq 'confirmedCompromised'"
                }
            }
        }
    }
}
