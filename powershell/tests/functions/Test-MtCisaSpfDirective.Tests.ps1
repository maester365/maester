BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    # Check functions that became native tests are not exported.
    Use-MtModuleFunction -Name Test-MtCisaSpfDirective

    function Get-TestSpfRecord {
        param(
            [string] $DomainName = 'example.gov',
            [string] $Record,
            [string] $Mechanism = '',
            [string] $Qualifier = '?',
            [string] $Modifier = ''
        )

        $spfRecord = $null
        $spfLookups = @()
        if ($PSBoundParameters.ContainsKey('Record')) {
            $spfRecord = $Record
            if ($Record -like 'v=spf1*') {
                $terms = foreach ($term in ($Record -split '\s+' | Select-Object -Skip 1)) {
                    $isAll = $term -match '^(?<qualifier>[-~?+]?)all$'
                    [pscustomobject]@{
                        directive       = $term
                        qualifier       = if ($isAll) { $Matches.qualifier } else { '' }
                        mechanism       = if ($isAll) { 'all' } elseif ($term -like 'include:*') { 'include' } else { '' }
                        mechanismTarget = if ($term -like 'include:*') { $term.Substring(8) } else { '' }
                        modifier        = if ($term -like 'redirect=*') { 'redirect' } else { '' }
                    }
                }
                $spfRecord = [pscustomobject]@{ record = $Record; terms = @($terms) }
                $spfLookups = @($terms | Where-Object { $_.mechanism -eq 'include' } | ForEach-Object {
                        [pscustomobject]@{ SPFSourceDomain = $_.mechanismTarget; Include = $true }
                    })
            }
        } else {
            $terms = @(
                [pscustomobject]@{
                    directive       = if ($Modifier) { "$Modifier=example.gov" } else { "$Qualifier$Mechanism" }
                    qualifier       = $Qualifier
                    mechanism       = $Mechanism
                    mechanismTarget = ''
                    modifier        = $Modifier
                }
            )
            $spfRecord = [pscustomobject]@{ terms = $terms }
        }

        return [pscustomobject]@{
            domain     = $DomainName
            spfRecord  = $spfRecord
            spfLookups = $spfLookups
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

Describe 'CISA.MS.EXO.2.2 with ParkedDomains' {
    BeforeEach {
        $script:acceptedDomains = @()
        $script:spfRecords = @{}
        Mock -ModuleName Maester Get-MtExo { return $script:acceptedDomains }
        Mock -ModuleName Maester Get-MailAuthenticationRecord {
            return Get-TestSpfRecord -DomainName $DomainName -Record $script:spfRecords[$DomainName]
        }
        Mock -ModuleName Maester Add-MtTestResultDetail { }
    }

    It 'checks a domain that cannot send as a sending domain when it is not listed' {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false; SendingFromDomainDisabled = $true })
        $script:spfRecords['parked.example'] = 'v=spf1 include:spf.example.net'

        Test-MtCisaSpfDirective | Should -BeFalse

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -match '\| parked\.example \| ❌ Fail \| No -all, ~all, or redirect mechanism \|' }
    }

    It 'accepts <Record> for a listed parked domain' -ForEach @(
        @{ Record = 'v=spf1 -all' }
        @{ Record = 'v=spf1 ~all' }
        @{ Record = 'v=spf1 include:spf.example.net -all' }
    ) {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false })
        $script:spfRecords['parked.example'] = $Record

        Test-MtCisaSpfDirective -ParkedDomains 'PARKED.example.' | Should -BeTrue

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -match '\| parked\.example \| ✅ Pass \| Parked domain: fails all senders \|' }
    }

    It 'fails a listed parked domain that publishes <Record>' -ForEach @(
        @{ Record = 'v=spf1 ?all'; Reason = 'policy does not end in -all or ~all' }
        @{ Record = 'v=spf1 +all'; Reason = 'policy does not end in -all or ~all' }
        @{ Record = 'v=spf1 include:spf.protection.outlook.com'; Reason = 'policy does not end in -all or ~all' }
        @{ Record = 'Failure to obtain record'; Reason = 'Failure to obtain record' }
    ) {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false })
        $script:spfRecords['parked.example'] = $Record

        Test-MtCisaSpfDirective -ParkedDomains 'parked.example' | Should -BeFalse

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -match ([regex]::Escape("| parked.example | ❌ Fail | Parked domain: $Reason |")) }
    }

    It 'accepts a non-Exchange sender mechanism when a sending domain fails all other senders' {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'contoso.com'; IsCoexistenceDomain = $false })
        $script:spfRecords['contoso.com'] = 'v=spf1 include:spf.example.net -all'

        Test-MtCisaSpfDirective | Should -BeTrue
    }

    It 'fails a sending domain with an Exchange Online include but no fail-all or redirect mechanism' {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'contoso.com'; IsCoexistenceDomain = $false })
        $script:spfRecords['contoso.com'] = 'v=spf1 include:spf.protection.outlook.com'

        Test-MtCisaSpfDirective | Should -BeFalse

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $Result -match '\| contoso\.com \| ❌ Fail \| No -all, ~all, or redirect mechanism \|' }
    }

    It 'passes when the sending domain names Exchange Online and the parked domain fails all senders' {
        $script:acceptedDomains = @(
            [pscustomobject]@{ DomainName = 'contoso.com'; IsCoexistenceDomain = $false }
            [pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false }
        )
        $script:spfRecords['contoso.com'] = 'v=spf1 include:spf.protection.outlook.com -all'
        $script:spfRecords['parked.example'] = 'v=spf1 -all'

        Test-MtCisaSpfDirective -ParkedDomains 'parked.example' | Should -BeTrue
    }

    It 'is not supported when the only domain is parked and DNS is not available' {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false })
        $script:spfRecords['parked.example'] = 'Unsupported platform, Resolve-DnsName not available'

        Test-MtCisaSpfDirective -ParkedDomains 'parked.example' | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'NotSupported' }
    }

    It 'does not pass when one accepted domain cannot be assessed' {
        $script:acceptedDomains = @(
            [pscustomobject]@{ DomainName = 'contoso.com'; IsCoexistenceDomain = $false }
            [pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false }
        )
        $script:spfRecords['contoso.com'] = 'v=spf1 -all'
        $script:spfRecords['parked.example'] = 'Unsupported platform, Resolve-DnsName not available'

        Test-MtCisaSpfDirective -ParkedDomains 'parked.example' | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'NotSupported' }
    }

    It 'does not pass a parked domain with an unverified redirect' {
        $script:acceptedDomains = @([pscustomobject]@{ DomainName = 'parked.example'; IsCoexistenceDomain = $false })
        $script:spfRecords['parked.example'] = 'v=spf1 redirect=spf.example.net'

        Test-MtCisaSpfDirective -ParkedDomains 'parked.example' | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'NotSupported' }
    }
}
