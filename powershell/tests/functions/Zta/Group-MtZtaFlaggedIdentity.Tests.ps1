# Unit tests for Group-MtZtaFlaggedIdentity.
# Tests the 7-step bucketing algorithm against synthetic Tests[] arrays and the
# captured fixture, with and without DuckDB enrichment (stub callable).

Describe 'Group-MtZtaFlaggedIdentity — bucketing algorithm' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
        $script:fixtureDir = Join-Path $PSScriptRoot 'fixtures'

        $script:standardMappings = @(
            @{ Category = 'IdentityPosture';     MatchPillar = 'Identity'; MatchCategoryAny = @(); MaesterTagBoost = @('Identity','MFA') }
            @{ Category = 'DevicePosture';       MatchPillar = 'Devices';  MatchCategoryAny = @(); MaesterTagBoost = @('Intune') }
            @{ Category = 'NetworkPosture';      MatchPillar = 'Network';  MatchCategoryAny = @(); MaesterTagBoost = @('GSA') }
            @{ Category = 'DataPosture';         MatchPillar = 'Data';     MatchCategoryAny = @(); MaesterTagBoost = @('Purview') }
            @{ Category = 'PrivilegedAccess';    MatchPillar = '*';        MatchCategoryAny = @('Privileged access','Role management','Credential management')
               MaesterTagBoost = @('PIM','PrivilegedAccess') }
            @{ Category = 'GuestUnconstrained';  MatchPillar = 'Identity'; MatchCategoryAny = @('External collaboration','External Identities','Guest','Cross-tenant')
               MaesterTagBoost = @('Guest','B2B') }
        )
    }

    Context 'JSON-only mode (no ContextDatabase)' {

        It 'classifies Privileged-access tests into the cross-cut bucket' {
            $tests = @(
                [pscustomobject]@{ TestId='1'; TestStatus='Failed'; TestPillar='Identity'; TestCategory='Privileged access'; TestTitle='t1'; TestResult='alice@example.com flagged' }
            )
            $buckets = & $script:mod {
                param($t,$m) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m
            } $tests $script:standardMappings
            ($buckets | Where-Object Category -eq 'PrivilegedAccess').Count | Should -Be 1
        }

        It 'classifies Identity-pillar non-cross-cut tests into IdentityPosture' {
            $tests = @(
                [pscustomobject]@{ TestId='2'; TestStatus='Failed'; TestPillar='Identity'; TestCategory='Authentication Methods'; TestTitle='t2'; TestResult='bob@example.com' }
            )
            $buckets = & $script:mod {
                param($t,$m) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m
            } $tests $script:standardMappings
            ($buckets | Where-Object Category -eq 'IdentityPosture').Count | Should -Be 1
        }

        It 'falls back to Other when no mapping matches and pillar is unknown' {
            $tests = @(
                [pscustomobject]@{ TestId='3'; TestStatus='Failed'; TestPillar='UnknownPillar'; TestCategory='Whatever'; TestTitle='t3'; TestResult='' }
            )
            $buckets = & $script:mod {
                param($t,$m) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m
            } $tests $script:standardMappings
            ($buckets | Where-Object Category -eq 'Other').Count | Should -Be 1
        }

        It 'explicit-category rule wins over pillar-level catch-all regardless of order (GuestUnconstrained beats IdentityPosture)' {
            # GuestUnconstrained has explicit MatchCategoryAny including 'External collaboration'.
            # IdentityPosture has empty MatchCategoryAny -> it is a pillar-level catch-all.
            # The two-pass algorithm: pass-2 (explicit category) beats pass-3 (catch-all),
            # so order in the mappings array does NOT affect the outcome.
            $tests = @(
                [pscustomobject]@{ TestId='4'; TestStatus='Failed'; TestPillar='Identity'; TestCategory='External collaboration'; TestTitle='t4'; TestResult='' }
            )
            $buckets = & $script:mod {
                param($t,$m) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m
            } $tests $script:standardMappings
            ($buckets | Where-Object Category -eq 'GuestUnconstrained').Count | Should -Be 1
            ($buckets | Where-Object Category -eq 'IdentityPosture').Count    | Should -Be 0
        }

        It 'classification is order-independent — same result with cross-cut rule listed first' {
            $crossCutFirst = @(
                @{ Category = 'GuestUnconstrained'; MatchPillar = 'Identity'; MatchCategoryAny = @('External collaboration','Guest'); MaesterTagBoost = @() }
                @{ Category = 'IdentityPosture';    MatchPillar = 'Identity'; MatchCategoryAny = @(); MaesterTagBoost = @() }
            )
            $tests = @(
                [pscustomobject]@{ TestId='5'; TestStatus='Failed'; TestPillar='Identity'; TestCategory='External collaboration'; TestTitle='t5'; TestResult='' }
            )
            $buckets = & $script:mod {
                param($t,$m) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m
            } $tests $crossCutFirst
            ($buckets | Where-Object Category -eq 'GuestUnconstrained').Count | Should -Be 1
        }

        It 'extracts UPNs and GUIDs from TestResult markdown' {
            $tests = @(
                [pscustomobject]@{ TestId='6'; TestStatus='Failed'; TestPillar='Identity'; TestCategory='Authentication Methods'; TestTitle='t6'
                                   TestResult = 'Users without MFA: alice@example.com, bob@example.com, 11111111-2222-3333-4444-555555555555' }
            )
            $buckets = & $script:mod {
                param($t,$m) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m
            } $tests $script:standardMappings
            $bucket = $buckets | Where-Object Category -eq 'IdentityPosture'
            $bucket.Count | Should -Be 3
            ($bucket.Group | Where-Object UserPrincipalName -eq 'alice@example.com').Count | Should -Be 1
            ($bucket.Group | Where-Object UserId -eq '11111111-2222-3333-4444-555555555555').Count | Should -Be 1
        }

        It 'caps each bucket at MaxUsersPerCategory' {
            $manyUsers = (1..25 | ForEach-Object { "user$_@example.com" }) -join ', '
            $tests = @(
                [pscustomobject]@{ TestId='7'; TestStatus='Failed'; TestPillar='Identity'; TestCategory='Authentication Methods'; TestTitle='t7'; TestResult=$manyUsers }
            )
            $buckets = & $script:mod {
                param($t,$m) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m -MaxUsersPerCategory 10
            } $tests $script:standardMappings
            $bucket = $buckets | Where-Object Category -eq 'IdentityPosture'
            $bucket.Count       | Should -Be 25      # pre-cap total preserved
            @($bucket.Group).Count | Should -Be 10   # post-cap sample is 10
        }

        It 'dedupes per (UserPrincipalName, Category) and merges Evidence' {
            $tests = @(
                [pscustomobject]@{ TestId='8'; TestStatus='Failed'; TestPillar='Identity'; TestCategory='Authentication Methods'; TestTitle='AuthMeth missing'; TestResult='alice@example.com' }
                [pscustomobject]@{ TestId='9'; TestStatus='Failed'; TestPillar='Identity'; TestCategory='Authentication Methods'; TestTitle='Other AM gap';      TestResult='alice@example.com' }
            )
            $buckets = & $script:mod {
                param($t,$m) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m
            } $tests $script:standardMappings
            $bucket = $buckets | Where-Object Category -eq 'IdentityPosture'
            $bucket.Count | Should -Be 1            # one user after dedupe
            $alice = $bucket.Group | Select-Object -First 1
            $alice.Evidence.Count | Should -BeGreaterOrEqual 2  # both test titles preserved
        }

        It 'ignores tests with TestStatus != Failed' {
            $tests = @(
                [pscustomobject]@{ TestId='10'; TestStatus='Passed';  TestPillar='Identity'; TestCategory='X'; TestTitle='passed'; TestResult='alice@example.com' }
                [pscustomobject]@{ TestId='11'; TestStatus='Skipped'; TestPillar='Identity'; TestCategory='X'; TestTitle='skipped'; TestResult='bob@example.com' }
            )
            $buckets = & $script:mod {
                param($t,$m) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m
            } $tests $script:standardMappings
            @($buckets).Count | Should -Be 0
        }

        It 'returns the captured fixture into known buckets' {
            $report = Get-Content (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') -Raw | ConvertFrom-Json
            $buckets = & $script:mod {
                param($t,$m) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m
            } $report.Tests $script:standardMappings
            # Fixture has 4 Failed tests across Identity/Devices/Network + 1 Skipped Data test.
            ($buckets | Where-Object Category -eq 'IdentityPosture').Count | Should -BeGreaterThan 0
            ($buckets | Where-Object Category -eq 'DevicePosture').Count   | Should -BeGreaterThan 0
            ($buckets | Where-Object Category -eq 'NetworkPosture').Count  | Should -BeGreaterThan 0
        }
    }

    Context 'DuckDB enrichment (stub callable)' {

        BeforeAll {
            # Stub a context object that returns canned rows for known queries.
            $script:dbStub = [pscustomobject]@{
                Query = {
                    param($sql)
                    if ($sql -like '*UserRegistrationDetails*isMfaRegistered = false*') {
                        return ,@(
                            [pscustomobject]@{ id='aaa'; userPrincipalName='nomfa1@example.com' }
                            [pscustomobject]@{ id='bbb'; userPrincipalName='nomfa2@example.com' }
                        )
                    }
                    if ($sql -like '*FROM "User"*Guest*') {
                        return ,@(
                            [pscustomobject]@{ id='ccc'; userPrincipalName='guest1@partner.com' }
                        )
                    }
                    if ($sql -like '*FROM Device*isCompliant = false*') {
                        return ,@(
                            [pscustomobject]@{ deviceId='ddd'; displayName='LAPTOP-01'; isCompliant=$false }
                        )
                    }
                    return ,@()
                }.GetNewClosure()
            }
        }

        It 'enriches IdentityPosture from UserRegistrationDetails (NoMFA)' {
            $tests = @()  # no JSON failures — only DB enrichment should produce buckets
            $buckets = & $script:mod {
                param($t,$m,$db) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m -ContextDatabase $db
            } $tests $script:standardMappings $script:dbStub

            $idBucket = $buckets | Where-Object Category -eq 'IdentityPosture'
            $idBucket.Count | Should -BeGreaterOrEqual 2
        }

        It 'enriches GuestUnconstrained from User table' {
            $buckets = & $script:mod {
                param($t,$m,$db) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m -ContextDatabase $db
            } @() $script:standardMappings $script:dbStub
            ($buckets | Where-Object Category -eq 'GuestUnconstrained').Count | Should -BeGreaterOrEqual 1
        }

        It 'enriches DevicePosture from Device table' {
            $buckets = & $script:mod {
                param($t,$m,$db) Group-MtZtaFlaggedIdentity -Tests $t -CategoryMappings $m -ContextDatabase $db
            } @() $script:standardMappings $script:dbStub
            ($buckets | Where-Object Category -eq 'DevicePosture').Count | Should -BeGreaterOrEqual 1
        }
    }
}
