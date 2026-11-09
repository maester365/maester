BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtCisaSpfDirective

    function New-TestSpfRecord {
        param(
            [string] $Mechanism,
            [string] $Qualifier = '?',
            [string] $Modifier = ''
        )

        return [pscustomobject]@{
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
        $script:IsCoexistenceDomain = $false

        Mock -ModuleName Maester Get-MtExo {
            return @([pscustomobject]@{
                DomainName = 'example.gov'
                SendingFromDomainDisabled = $false
                IsCoexistenceDomain = $script:IsCoexistenceDomain
            })
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
        $script:TestSpfRecord = New-TestSpfRecord -Mechanism 'all' -Qualifier $Qualifier

        Test-MtCisaSpfDirective | Should -BeTrue
        $script:TestResultMarkdown | Should -Match 'Fail-all mechanism'
    }

    It 'fails when the SPF all mechanism does not fail unapproved senders' -ForEach @(
        @{ Qualifier = '+' }
        @{ Qualifier = '?' }
    ) {
        $script:TestSpfRecord = New-TestSpfRecord -Mechanism 'all' -Qualifier $Qualifier

        Test-MtCisaSpfDirective | Should -BeFalse
        $script:TestResultMarkdown | Should -Match 'No -all, ~all, or redirect mechanism'
    }

    It 'accepts a redirect modifier' {
        $script:TestSpfRecord = New-TestSpfRecord -Mechanism '' -Modifier 'redirect'

        Test-MtCisaSpfDirective | Should -BeTrue
        $script:TestResultMarkdown | Should -Match 'Redirect modifier'
    }

    It 'skips coexistence domains even when the SPF record would otherwise pass' {
        $script:IsCoexistenceDomain = $true
        $script:TestSpfRecord = New-TestSpfRecord -Mechanism 'all' -Qualifier '-'

        Test-MtCisaSpfDirective | Should -BeNull
        $script:SkippedBecause | Should -Be 'NotSupported'
    }
}
