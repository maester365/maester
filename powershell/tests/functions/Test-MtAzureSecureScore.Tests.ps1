Describe 'Azure secure score and regulatory compliance' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Native test, its instance source and the internal helper; none is exported.
        Use-MtModuleFunction -Name Test-MtAzureSecureScore,
            Get-MtAzureSecureScoreInstance,
            Get-MtAzureSecureScore

        function Get-TestSubscription {
            param(
                [double] $Current = 44, [double] $Max = 55, [string] $Name = 'Contoso Production',
                [object] $Percentage = 80, [object[]] $Standards = $null
            )
            if ($null -eq $Standards) {
                $Standards = @(
                    [pscustomobject]@{ Standard = 'Azure-Security-Benchmark'; State = 'Failed'; PassedControls = 30; FailedControls = 4; SkippedControls = 1; UnsupportedControls = 0 }
                )
            }
            return [pscustomobject]@{
                SubscriptionId   = '11111111-2222-3333-4444-555555555555'
                SubscriptionName = $Name
                Initiative       = 'ascScore'
                CurrentScore     = $Current
                MaxScore         = $Max
                ScorePercentage  = $Percentage
                StandardList     = @($Standards)
            }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:SkippedCustomReason = $null
        $script:Severity = $null

        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedCustomReason, $Severity)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedCustomReason = $SkippedCustomReason
            $script:Severity = $Severity
        }
    }

    Context 'MT.1266 secure score' {
        It 'passes at the target and fails below it' {
            $at = [pscustomobject]@{ Data = Get-TestSubscription -Percentage 80 }
            Test-MtAzureSecureScore -Instance $at | Should -BeTrue -Because '80 meets a target of 80'

            $below = [pscustomobject]@{ Data = Get-TestSubscription -Percentage 79.9 }
            Test-MtAzureSecureScore -Instance $below | Should -BeFalse
        }

        It 'fails a score just under the target, and shows it under the target' {
            $i = [pscustomobject]@{ Data = Get-TestSubscription -Percentage 79.96 }

            Test-MtAzureSecureScore -Instance $i | Should -BeFalse -Because '79.96 is below a target of 80'
            $script:TestResult | Should -Match 'is \*\*79\.9%\*\*'
        }

        It 'honours a target other than the default' {
            $i = [pscustomobject]@{ Data = Get-TestSubscription -Percentage 85 }

            Test-MtAzureSecureScore -Instance $i -MinimumScorePercentage 90 | Should -BeFalse
            Test-MtAzureSecureScore -Instance $i -MinimumScorePercentage 80 | Should -BeTrue
            $script:TestResult | Should -Match 'against a target of \*\*80%\*\*'
        }

        It 'skips with a reason when Defender for Cloud assessed nothing, rather than reporting zero' {
            $i = [pscustomobject]@{ Data = Get-TestSubscription -Current 0 -Max 0 -Percentage $null }

            Test-MtAzureSecureScore -Instance $i | Should -BeNullOrEmpty
            $script:SkippedBecause | Should -Be 'Custom'
            $script:SkippedCustomReason | Should -Match 'maximum secure score is zero'
            $script:TestResult | Should -BeNullOrEmpty -Because 'a skip reports the reason, not a score table'
        }

        It 'escapes the subscription name in the skip reason too, not only in the result' {
            $i = [pscustomobject]@{ Data = Get-TestSubscription -Current 0 -Max 0 -Percentage $null -Name '[Sign in again](https://phish.example)' }

            $null = Test-MtAzureSecureScore -Instance $i
            $script:SkippedCustomReason | Should -Not -Match '\[Sign in again\]\(https'
            $script:SkippedCustomReason | Should -Match '\\\[Sign in again\\\]'
        }

        It 'reports the compliance standards as a summary, worst first' {
            $i = [pscustomobject]@{ Data = Get-TestSubscription -Standards @(
                    [pscustomobject]@{ Standard = 'Azure-CIS-1.4.0'; State = 'Failed'; PassedControls = 10; FailedControls = 2; SkippedControls = 0; UnsupportedControls = 1 },
                    [pscustomobject]@{ Standard = 'Azure-Security-Benchmark'; State = 'Failed'; PassedControls = 30; FailedControls = 9; SkippedControls = 1; UnsupportedControls = 0 }
                ) }

            $null = Test-MtAzureSecureScore -Instance $i
            $script:TestResult | Should -Match 'Regulatory compliance standards assigned to this subscription'
            $benchmarkRow = ([regex]::Match($script:TestResult, '(?m)^\| Azure-Security-Benchmark .*$')).Index
            $cisRow = ([regex]::Match($script:TestResult, '(?m)^\| Azure-CIS-1\\?\.4\\?\.0 .*$')).Index
            $benchmarkRow | Should -BeLessThan $cisRow -Because 'nine failed controls outrank two'
        }

        It 'says so when no standard is assigned, instead of showing an empty table' {
            $i = [pscustomobject]@{ Data = Get-TestSubscription -Standards @() }

            $null = Test-MtAzureSecureScore -Instance $i
            $script:TestResult | Should -Match 'No regulatory compliance standard is assigned'
            $script:TestResult | Should -Not -Match '\| Standard \| State \|'
        }

        It 'escapes a subscription name that contains markdown, so it cannot render as a link' {
            $i = [pscustomobject]@{ Data = Get-TestSubscription -Name '[Sign in again](https://phish.example)' }

            $null = Test-MtAzureSecureScore -Instance $i
            $script:TestResult | Should -Not -Match '\[Sign in again\]\(https'
            $script:TestResult | Should -Match '\\\[Sign in again\\\]'
        }
    }

    Context 'Get-MtAzureSecureScoreInstance (MT.1266 instance source)' {
        It 'emits one instance per subscription, and none when there is no score' {
            Mock -ModuleName Maester Get-MtAzureSecureScore { @(Get-TestSubscription), @(Get-TestSubscription) }
            @(Get-MtAzureSecureScoreInstance).Count | Should -Be 2

            Mock -ModuleName Maester Get-MtAzureSecureScore { @() }
            @(Get-MtAzureSecureScoreInstance).Count | Should -Be 0
        }

        It 'uses the subscription id as the instance id and names the subscription in the title' {
            Mock -ModuleName Maester Get-MtAzureSecureScore { @(Get-TestSubscription -Name 'Contoso Production') }

            $instance = @(Get-MtAzureSecureScoreInstance)[0]
            $instance.Id | Should -Be '11111111-2222-3333-4444-555555555555'
            $instance.Title | Should -Match "subscription 'Contoso Production'"
        }
    }

    Context 'Get-MtAzureSecureScore' {
        BeforeEach {
            Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest {
                param($Query)

                if ($Query -match 'securescores') {
                    return @([pscustomobject]@{ subscriptionId = 'sub-1'; currentScore = 44; maxScore = 55; initiative = 'ascScore' },
                        [pscustomobject]@{ subscriptionId = 'sub-2'; currentScore = 0; maxScore = 0; initiative = 'ascScore' })
                }
                if ($Query -match 'regulatorycompliancestandards') {
                    return @([pscustomobject]@{ subscriptionId = 'sub-1'; standard = 'Azure-Security-Benchmark'; state = 'Failed'; passedControls = 30; failedControls = 4; skippedControls = 1; unsupportedControls = 0 })
                }
                return @([pscustomobject]@{ subscriptionId = 'sub-1'; subscriptionName = 'Contoso Production' })
            }
        }

        It 'computes the percentage from the current and maximum score' {
            # No @(): the helper writes the list with -NoEnumerate, so @() would wrap it in a single
            # element and the filter would see the whole list rather than its rows.
            $rows = Get-MtAzureSecureScore

            ($rows | Where-Object { $_.SubscriptionId -eq 'sub-1' }).ScorePercentage | Should -Be 80 -Because '44 of 55 is 80%'
        }

        It 'returns the percentage unrounded, so the test compares the exact value with the target' -ForEach @(
            @{ Current = 79.96; Max = 100; Expected = 79.96 }
            @{ Current = 57; Max = 100; Expected = 57 }
            @{ Current = 1; Max = 3; Expected = 100 / 3 }
        ) {
            Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest {
                param($Query)
                if ($Query -match 'securescores') { return @([pscustomobject]@{ subscriptionId = 'sub-1'; currentScore = $Current; maxScore = $Max; initiative = 'ascScore' }) }
                return @()
            }.GetNewClosure()

            # No @(): the helper writes the list with -NoEnumerate.
            $rows = Get-MtAzureSecureScore

            ($rows | Where-Object { $_.SubscriptionId -eq 'sub-1' }).ScorePercentage | Should -Be $Expected
        }

        It 'leaves the percentage null when the maximum score is zero, rather than reporting zero per cent' {
            # No @(): the helper writes the list with -NoEnumerate, so @() would wrap it in a single
            # element and the filter would see the whole list rather than its rows.
            $rows = Get-MtAzureSecureScore

            ($rows | Where-Object { $_.SubscriptionId -eq 'sub-2' }).ScorePercentage | Should -BeNullOrEmpty
        }

        It 'falls back to the subscription id when the name is not readable' {
            # No @(): the helper writes the list with -NoEnumerate, so @() would wrap it in a single
            # element and the filter would see the whole list rather than its rows.
            $rows = Get-MtAzureSecureScore

            ($rows | Where-Object { $_.SubscriptionId -eq 'sub-2' }).SubscriptionName | Should -Be 'sub-2'
        }

        It 'attaches the standards to their own subscription only' {
            # No @(): the helper writes the list with -NoEnumerate, so @() would wrap it in a single
            # element and the filter would see the whole list rather than its rows.
            $rows = Get-MtAzureSecureScore

            @(($rows | Where-Object { $_.SubscriptionId -eq 'sub-1' }).StandardList).Count | Should -Be 1
            @(($rows | Where-Object { $_.SubscriptionId -eq 'sub-2' }).StandardList).Count | Should -Be 0
        }

        It 'asks Azure for the default initiative only, so one subscription cannot yield two rows' {
            # The instance ID for this family is the subscription ID, so two score rows for one
            # subscription would repeat it, and Invoke-MtNativePlan answers a repeated instance ID
            # with a single InvalidInstanceId Error row for the WHOLE family: one extra initiative
            # anywhere would take MT.1266 out across the estate. Score resources are per initiative,
            # so the query has to ask for the ASC Default one by name.
            #
            # The mock honours the filter instead of asserting on the query text: without the
            # name filter it answers with the two rows Azure would really return, and this test
            # fails. That is the point of writing it this way.
            Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest {
                param($Query)

                if ($Query -match 'securescores') {
                    if ($Query -match 'name == "ascScore"') {
                        return @([pscustomobject]@{ subscriptionId = 'sub-1'; currentScore = 44; maxScore = 55; initiative = 'ASC Default' })
                    }

                    return @([pscustomobject]@{ subscriptionId = 'sub-1'; currentScore = 44; maxScore = 55; initiative = 'ASC Default' },
                        [pscustomobject]@{ subscriptionId = 'sub-1'; currentScore = 10; maxScore = 90; initiative = 'Custom initiative' })
                }
                if ($Query -match 'regulatorycompliancestandards') { return @() }
                return @([pscustomobject]@{ subscriptionId = 'sub-1'; subscriptionName = 'Contoso Production' })
            }

            # No @(): the helper writes the list with -NoEnumerate, so @() would wrap it in a single
            # element and the filter would see the whole list rather than its rows.
            $rows = Get-MtAzureSecureScore

            @($rows | Where-Object { $_.SubscriptionId -eq 'sub-1' }).Count | Should -Be 1 -Because 'one subscription is one instance, whatever initiatives it carries'
            ($rows | Where-Object { $_.SubscriptionId -eq 'sub-1' }).ScorePercentage | Should -Be 80 -Because 'the default initiative is the one that counts'
        }

        It 'returns an empty list, not null, when there is no secure score, and asks for nothing else' {
            Mock -ModuleName Maester Invoke-MtAzureResourceGraphRequest { @() }

            $rows = Get-MtAzureSecureScore
            $null -ne $rows | Should -BeTrue
            @($rows).Count | Should -Be 0
            Should -Invoke -ModuleName Maester Invoke-MtAzureResourceGraphRequest -Times 1 -Exactly -Because 'without a score there is nothing to enrich'
        }
    }
}
