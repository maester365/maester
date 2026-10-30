Describe 'Entra ID Protection unremediated high-risk users (MT.1260)' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The native-test function is not exported; reach it the same way the agent tests do.
        Use-MtModuleFunction -Name Test-MtEntraUnremediatedHighRiskUser
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:SkippedError = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedError)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedError = $SkippedError
        }
    }

    AfterEach {
        # Result text must not contain backtick-wrapped code spans (repo result-text lint).
        if ($null -ne $script:TestResult) {
            $script:TestResult | Should -Not -Match '`[^`]+`'
        }
    }

    It 'passes when there are no high-risk users' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'fails when a high-risk user is atRisk' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id                      = 'user-1'
                    userPrincipalName       = 'alice@contoso.com'
                    userDisplayName         = 'Alice'
                    riskLevel               = 'high'
                    riskState               = 'atRisk'
                    riskDetail              = 'none'
                    riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
        $script:TestResult | Should -Match 'alice@contoso.com'
        $script:TestResult | Should -Match 'atRisk'
    }

    It 'fails when a high-risk user is confirmedCompromised (must not be treated as remediated)' {
        # This is the case that breaks if the check filters on riskState eq atRisk only:
        # confirmCompromised lands a user in confirmedCompromised, which is still unremediated.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id                      = 'user-2'
                    userPrincipalName       = 'bob@contoso.com'
                    userDisplayName         = 'Bob'
                    riskLevel               = 'high'
                    riskState               = 'confirmedCompromised'
                    riskDetail              = 'adminConfirmedUserCompromised'
                    riskLastUpdatedDateTime = '2026-10-02T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
        $script:TestResult | Should -Match 'bob@contoso.com'
        $script:TestResult | Should -Match 'confirmedCompromised'
    }

    It 'passes when the only high-risk users are already remediated or dismissed' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'user-3'; userPrincipalName = 'carol@contoso.com'; userDisplayName = 'Carol'
                    riskLevel = 'high'; riskState = 'remediated'; riskDetail = 'userPerformedSecuredPasswordReset'
                    riskLastUpdatedDateTime = '2026-10-03T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'user-4'; userPrincipalName = 'dave@contoso.com'; userDisplayName = 'Dave'
                    riskLevel = 'high'; riskState = 'dismissed'; riskDetail = 'adminDismissedAllRiskForUser'
                    riskLastUpdatedDateTime = '2026-10-04T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
    }

    It 'reports only the unremediated users in a mixed set' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return @(
                [pscustomobject]@{
                    id = 'user-1'; userPrincipalName = 'alice@contoso.com'; userDisplayName = 'Alice'
                    riskLevel = 'high'; riskState = 'atRisk'; riskDetail = 'none'
                    riskLastUpdatedDateTime = '2026-10-01T00:00:00Z'
                },
                [pscustomobject]@{
                    id = 'user-3'; userPrincipalName = 'carol@contoso.com'; userDisplayName = 'Carol'
                    riskLevel = 'high'; riskState = 'remediated'; riskDetail = 'userPerformedSecuredPasswordReset'
                    riskLastUpdatedDateTime = '2026-10-03T00:00:00Z'
                }
            )
        }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeFalse
        $script:TestResult | Should -Match 'alice@contoso.com'
        $script:TestResult | Should -Not -Match 'carol@contoso.com'
        $script:TestResult | Should -Match 'Found 1 high-risk'
    }

    It 'skips as NotAuthorized on a 403 from Graph' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw '403 Forbidden: Authorization_RequestDenied' }

        Test-MtEntraUnremediatedHighRiskUser | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'lets an unexpected failure throw so the engine records it as Error' {
        # The engine owns the try: a non-403 failure must propagate, not be swallowed by the check.
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Service unavailable' }

        { Test-MtEntraUnremediatedHighRiskUser } | Should -Throw '*Service unavailable*'
    }
}
