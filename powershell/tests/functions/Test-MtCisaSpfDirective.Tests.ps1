BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCisaSpfDirective

    function Get-TestSpfRecord {
        param(
            [string] $Mechanism,
            [string] $Qualifier = '?',
            [string] $Modifier = ''
        )

        return [pscustomobject]@{
            domain = 'example.gov'
            spfRecord = [pscustomobject]@{
                terms = @(
                    [pscustomobject]@{
                        mechanism = $Mechanism
                        qualifier = $Qualifier
                        modifier = $Modifier
                        mechanismTarget = ''
                        directive = ''
                    }
                )
            }
            spfLookups = @()
        }
    }
}

Describe 'Test-MtCisaSpfDirective' {
    BeforeEach {
        $script:TestSpfRecord = $null
        $script:TestResultMarkdown = $null
        $script:SkippedBecause = $null
        $script:AcceptedDomains = @(
            [pscustomobject]@{
                DomainName = 'example.gov'
                SendingFromDomainDisabled = $false
                IsCoexistenceDomain = $false
            }
        )

        Mock -ModuleName Maester Get-MtExo {
            return $script:AcceptedDomains
        }
        Mock -ModuleName Maester Get-MailAuthenticationRecord { return $script:TestSpfRecord }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause)

            $script:TestResultMarkdown = $Result
            $script:SkippedBecause = $SkippedBecause
        }
    }

    It 'passes hard-fail and soft-fail mechanisms without requiring an Exchange Online include' -ForEach @(
        @{ Qualifier = '-' }
        @{ Qualifier = '~' }
    ) {
        $script:TestSpfRecord = Get-TestSpfRecord -Mechanism 'all' -Qualifier $Qualifier

        Test-MtCisaSpfDirective | Should -BeTrue
        $script:TestResultMarkdown | Should -Match 'Fail-all mechanism'
    }

    It 'fails when the SPF all mechanism does not fail unapproved senders' -ForEach @(
        @{ Qualifier = '+' }
        @{ Qualifier = '?' }
    ) {
        $script:TestSpfRecord = Get-TestSpfRecord -Mechanism 'all' -Qualifier $Qualifier

        Test-MtCisaSpfDirective | Should -BeFalse
        $script:TestResultMarkdown | Should -Match 'No -all, ~all, or redirect mechanism'
    }

    It 'accepts a redirect modifier' {
        $script:TestSpfRecord = Get-TestSpfRecord -Mechanism '' -Modifier 'redirect'

        Test-MtCisaSpfDirective | Should -BeTrue
        $script:TestResultMarkdown | Should -Match 'Redirect modifier'
    }

    It 'evaluates accepted domains even when sending is disabled or the domain is marked as coexistence' {
        $script:AcceptedDomains = @(
            [pscustomobject]@{
                DomainName = 'coexistence.example.gov'
                SendingFromDomainDisabled = $true
                IsCoexistenceDomain = $true
            }
        )
        $script:TestSpfRecord = Get-TestSpfRecord -Mechanism 'all' -Qualifier '+'
        $script:TestSpfRecord.domain = 'coexistence.example.gov'

        Test-MtCisaSpfDirective | Should -BeFalse
        $script:SkippedBecause | Should -BeNullOrEmpty
        $script:TestResultMarkdown | Should -Match 'coexistence.example.gov'
    }

    It 'describes the redirect check as a heuristic that requires review' {
        $script:TestSpfRecord = Get-TestSpfRecord -Mechanism 'all' -Qualifier '+' -Modifier 'redirect'

        Test-MtCisaSpfDirective | Should -BeTrue
        $script:TestResultMarkdown | Should -Match 'passed this heuristic'
        $script:TestResultMarkdown | Should -Match 'Review the policies'
        $script:TestResultMarkdown | Should -Not -Match 'Well done'
    }
}
