BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    # Check functions that became native tests, and internal helpers, are not exported.
    Use-MtModuleFunction -Name Test-MtCisaDmarcRecordExist, Find-MtDmarcRecord, Resolve-MtDnsTxtRecord

    function New-TestLookup {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
        param(
            [string]$Name,
            [string[]]$Answers = @(),
            [string]$Status = 'Success',
            [string]$Message
        )

        return [pscustomobject]@{
            Name    = $Name
            Status  = $Status
            Answers = [string[]]$Answers
            Error   = $Message
        }
    }

    function New-TestAcceptedDomain {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
        param(
            [string]$DomainName,
            [bool]$InitialDomain = $false,
            [bool]$IsCoexistenceDomain = $false
        )

        return [pscustomobject]@{
            DomainName          = $DomainName
            InitialDomain       = $InitialDomain
            IsCoexistenceDomain = $IsCoexistenceDomain
        }
    }
}

Describe 'CISA.MS.EXO.4.1 with DNS mocked' {
    # The DNS answers the mocked resolver returns, keyed by DNS name: a list of TXT records, or a whole lookup
    # result. A name that is not listed does not exist.
    BeforeEach {
        $script:dnsAnswers = @{}
        $script:dnsQueries = [System.Collections.Generic.List[string]]::new()
        Mock -ModuleName Maester Resolve-MtDnsTxtRecord {
            $script:dnsQueries.Add($Name)
            if ($script:dnsAnswers.ContainsKey($Name)) {
                $answer = $script:dnsAnswers[$Name]
                if ($answer -is [System.Management.Automation.PSCustomObject]) { return $answer }
                return New-TestLookup -Name $Name -Answers $answer
            }
            return New-TestLookup -Name $Name -Status 'NXDomain'
        }
    }

    # The cases of ScubaGear's Get-ScubaDmarcRecord.Tests.ps1 (cisagov/ScubaGear v2.0.0).
    Describe 'Find-MtDmarcRecord' {
        It 'uses the record published at the domain without walking up' {
            $script:dnsAnswers['_dmarc.example.com'] = 'v=DMARC1; p=reject;'

            $result = Find-MtDmarcRecord -DomainName 'example.com'

            $result.Record | Should -Be 'v=DMARC1; p=reject;'
            $result.PolicyDomain | Should -Be 'example.com'
            $script:dnsQueries | Should -Be @('_dmarc.example.com')
        }

        It 'walks up to a parent domain when the domain has no record' {
            $script:dnsAnswers['_dmarc.example.com'] = 'v=DMARC1; p=reject;'

            $result = Find-MtDmarcRecord -DomainName 'a.b.example.com'

            $result.Record | Should -Be 'v=DMARC1; p=reject;'
            $result.PolicyDomain | Should -Be 'example.com'
            $script:dnsQueries | Should -Be @('_dmarc.a.b.example.com', '_dmarc.b.example.com', '_dmarc.example.com', '_dmarc.com')
        }

        It 'finds the record of a domain under a multi-label public suffix' {
            $script:dnsAnswers['_dmarc.example.co.uk'] = 'v=DMARC1; p=reject;'

            $result = Find-MtDmarcRecord -DomainName 'mail.example.co.uk'

            $result.PolicyDomain | Should -Be 'example.co.uk'
            $script:dnsQueries | Should -Contain '_dmarc.example.co.uk'
        }

        It 'keeps walking after it finds a record, so a record higher up replaces one lower down' {
            $script:dnsAnswers['_dmarc.b.example.com'] = 'v=DMARC1; p=none;'
            $script:dnsAnswers['_dmarc.example.com'] = 'v=DMARC1; p=reject;'

            $result = Find-MtDmarcRecord -DomainName 'a.b.example.com'

            $result.Record | Should -Be 'v=DMARC1; p=reject;'
            $result.PolicyDomain | Should -Be 'example.com'
        }

        It 'makes at most eight DNS queries, keeping the last seven labels of a long name' {
            $result = Find-MtDmarcRecord -DomainName 'a.b.c.d.e.f.g.h.i.j.mail.example.com'

            $result.Record | Should -BeNullOrEmpty
            $result.PolicyDomain | Should -BeNullOrEmpty
            $script:dnsQueries | Should -Be @(
                '_dmarc.a.b.c.d.e.f.g.h.i.j.mail.example.com',
                '_dmarc.g.h.i.j.mail.example.com',
                '_dmarc.h.i.j.mail.example.com',
                '_dmarc.i.j.mail.example.com',
                '_dmarc.j.mail.example.com',
                '_dmarc.mail.example.com',
                '_dmarc.example.com',
                '_dmarc.com'
            )
        }

        It 'stops at a record with psd=y and uses it when no organizational domain record was found' {
            $script:dnsAnswers['_dmarc.b.example.com'] = 'v=DMARC1; p=none; psd=y;'
            $script:dnsAnswers['_dmarc.example.com'] = 'v=DMARC1; p=reject;'

            $result = Find-MtDmarcRecord -DomainName 'a.b.example.com'

            $result.Record | Should -Be 'v=DMARC1; p=none; psd=y;'
            $script:dnsQueries | Should -Be @('_dmarc.a.b.example.com', '_dmarc.b.example.com')
        }

        It 'prefers the organizational domain record over the psd=y record above it' {
            $script:dnsAnswers['_dmarc.cisa.gov'] = 'v=DMARC1; p=reject;'
            $script:dnsAnswers['_dmarc.gov'] = 'v=DMARC1; p=reject; psd=y;'

            $result = Find-MtDmarcRecord -DomainName 'example.cisa.gov'

            $result.Record | Should -Be 'v=DMARC1; p=reject;'
            $result.PolicyDomain | Should -Be 'cisa.gov'
            $script:dnsQueries | Should -Be @('_dmarc.example.cisa.gov', '_dmarc.cisa.gov', '_dmarc.gov')
        }

        It 'uses the psd=y record when the record found is not the organizational domain' {
            $script:dnsAnswers['_dmarc.b.c.gov'] = 'v=DMARC1; p=none;'
            $script:dnsAnswers['_dmarc.gov'] = 'v=DMARC1; p=reject; psd=y;'

            $result = Find-MtDmarcRecord -DomainName 'a.b.c.gov'

            $result.Record | Should -Be 'v=DMARC1; p=reject; psd=y;'
            $result.PolicyDomain | Should -Be 'gov'
            $script:dnsQueries | Should -Be @('_dmarc.a.b.c.gov', '_dmarc.b.c.gov', '_dmarc.c.gov', '_dmarc.gov')
        }

        It 'stops at a record with psd=n' {
            $script:dnsAnswers['_dmarc.b.example.com'] = 'v=DMARC1; p=none; psd=n;'
            $script:dnsAnswers['_dmarc.example.com'] = 'v=DMARC1; p=reject;'

            $result = Find-MtDmarcRecord -DomainName 'a.b.example.com'

            $result.Record | Should -Be 'v=DMARC1; p=none; psd=n;'
            $script:dnsQueries | Should -Be @('_dmarc.a.b.example.com', '_dmarc.b.example.com')
        }

        It 'walks past <Case> at the <Where>' -ForEach @(
            @{ Case = 'a TXT record that is not a DMARC record'; Where = 'domain'; Name = '_dmarc.a.b.example.com'; Answers = @('some unrelated TXT record') }
            @{ Case = 'more than one DMARC record'; Where = 'domain'; Name = '_dmarc.a.b.example.com'; Answers = @('v=DMARC1; p=none;', 'v=DMARC1; p=quarantine;') }
            @{ Case = 'a TXT record that is not a DMARC record'; Where = 'parent domain'; Name = '_dmarc.b.example.com'; Answers = @('some unrelated TXT record') }
            @{ Case = 'more than one DMARC record'; Where = 'parent domain'; Name = '_dmarc.b.example.com'; Answers = @('v=DMARC1; p=none;', 'v=DMARC1; p=quarantine;') }
        ) {
            $script:dnsAnswers[$Name] = $Answers
            $script:dnsAnswers['_dmarc.example.com'] = 'v=DMARC1; p=reject;'

            $result = Find-MtDmarcRecord -DomainName 'a.b.example.com'

            $result.Record | Should -Be 'v=DMARC1; p=reject;'
            $script:dnsQueries | Should -Be @('_dmarc.a.b.example.com', '_dmarc.b.example.com', '_dmarc.example.com', '_dmarc.com')
        }

        It 'returns the lookups it made, including failed ones' {
            $script:dnsAnswers['_dmarc.example.com'] = New-TestLookup -Name '_dmarc.example.com' -Status 'Error' -Message 'Timed out'

            $result = Find-MtDmarcRecord -DomainName 'example.com'

            $result.Record | Should -BeNullOrEmpty
            $result.Lookups.Name | Should -Be @('_dmarc.example.com', '_dmarc.com')
            $result.Lookups[0].Status | Should -Be 'Error'
        }

        It 'queries a name once when the cache is shared' {
            $cache = @{}
            Find-MtDmarcRecord -DomainName 'contoso.com' -Cache $cache | Out-Null
            Find-MtDmarcRecord -DomainName 'fabrikam.com' -Cache $cache | Out-Null

            $script:dnsQueries | Should -Be @('_dmarc.contoso.com', '_dmarc.com', '_dmarc.fabrikam.com')
        }

        It 'stops when no DNS resolver is available' {
            $script:dnsAnswers['_dmarc.a.example.com'] = New-TestLookup -Name '_dmarc.a.example.com' -Status 'NotAvailable' -Message 'Missing dependency, Resolve-Dns not available'

            $result = Find-MtDmarcRecord -DomainName 'a.example.com'

            $result.Record | Should -BeNullOrEmpty
            $script:dnsQueries | Should -Be @('_dmarc.a.example.com')
        }
    }

    Describe 'Test-MtCisaDmarcRecordExist' {
        BeforeEach {
            $script:testResultMarkdown = $null
            $script:skippedBecause = $null
            Mock -ModuleName Maester Add-MtTestResultDetail {
                param($Result, $SkippedBecause)

                $script:testResultMarkdown = $Result
                $script:skippedBecause = $SkippedBecause
            }
            Mock -ModuleName Maester Get-MtExo {
                return @(
                    (New-TestAcceptedDomain -DomainName 'contoso.onmicrosoft.com' -InitialDomain $true),
                    (New-TestAcceptedDomain -DomainName 'contoso.mail.onmicrosoft.com' -IsCoexistenceDomain $true),
                    (New-TestAcceptedDomain -DomainName 'contoso.com'),
                    (New-TestAcceptedDomain -DomainName 'mail.contoso.com')
                )
            }
            $script:dnsAnswers['_dmarc.contoso.onmicrosoft.com'] = 'v=DMARC1; p=reject;'
            $script:dnsAnswers['_dmarc.contoso.com'] = 'v=DMARC1; p=reject; rua=mailto:reports@contoso.com'
        }

        It 'passes when a record applies to every accepted domain, including subdomains through the tree walk' {
            Test-MtCisaDmarcRecordExist | Should -BeTrue

            $script:testResultMarkdown | Should -Match 'Well done'
            $script:testResultMarkdown | Should -Match '\| mail\.contoso\.com \| ✅ Pass \| \\_dmarc\.contoso\.com \|'
        }

        It 'does not check the coexistence domain' {
            Test-MtCisaDmarcRecordExist | Out-Null

            $script:dnsQueries | Should -Not -Contain '_dmarc.contoso.mail.onmicrosoft.com'
            $script:testResultMarkdown | Should -Not -Match 'contoso\.mail\.onmicrosoft\.com'
        }

        It 'checks the initial domain' {
            $script:dnsAnswers.Remove('_dmarc.contoso.onmicrosoft.com')

            Test-MtCisaDmarcRecordExist | Should -BeFalse

            $script:testResultMarkdown | Should -Match '\| contoso\.onmicrosoft\.com \| ❌ Fail \|  \| No DMARC record found\. \|'
        }

        It 'checks each domain under a multi-label public suffix on its own' {
            Mock -ModuleName Maester Get-MtExo {
                return @(
                    (New-TestAcceptedDomain -DomainName 'example.co.uk'),
                    (New-TestAcceptedDomain -DomainName 'other.co.uk')
                )
            }
            $script:dnsAnswers['_dmarc.example.co.uk'] = 'v=DMARC1; p=reject;'

            Test-MtCisaDmarcRecordExist | Should -BeFalse

            $script:testResultMarkdown | Should -Match '\| example\.co\.uk \| ✅ Pass \|'
            $script:testResultMarkdown | Should -Match '\| other\.co\.uk \| ❌ Fail \|'
        }

        It 'passes a record that starts with v=DMARC1; whatever its policy: <Record>' -ForEach @(
            @{ Record = 'v=DMARC1;' }
            @{ Record = 'v=DMARC1; p=none;' }
            @{ Record = 'v=DMARC1; rua=mailto:reports@contoso.com' }
            @{ Record = 'v=DMARC1; p=bogus; pct=200' }
        ) {
            $script:dnsAnswers['_dmarc.contoso.com'] = $Record

            Test-MtCisaDmarcRecordExist | Should -BeTrue
        }

        It 'fails a record that does not start with exactly v=DMARC1;: <Record>' -ForEach @(
            @{ Record = 'v=DMARC1' }
            @{ Record = 'v=DMARC1 ; p=reject;' }
            @{ Record = 'V=DMARC1; p=reject;' }
        ) {
            $script:dnsAnswers['_dmarc.contoso.com'] = $Record

            Test-MtCisaDmarcRecordExist | Should -BeFalse

            $script:testResultMarkdown | Should -Match '\| contoso\.com \| ❌ Fail \| \\_dmarc\.contoso\.com \| The record does not start with v=DMARC1;'
        }

        It 'fails a domain whose DNS lookup failed' {
            Mock -ModuleName Maester Get-MtExo { return @(New-TestAcceptedDomain -DomainName 'contoso.com') }
            $script:dnsAnswers['_dmarc.contoso.com'] = New-TestLookup -Name '_dmarc.contoso.com' -Status 'Error' -Message 'Timed out'

            Test-MtCisaDmarcRecordExist | Should -BeFalse

            $script:testResultMarkdown | Should -Match 'The DNS lookup for \\_dmarc\.contoso\.com failed: Timed out'
        }

        It 'passes a domain whose own lookup failed when a parent domain has a record, as ScubaGear does' {
            Mock -ModuleName Maester Get-MtExo { return @(New-TestAcceptedDomain -DomainName 'mail.contoso.com') }
            $script:dnsAnswers['_dmarc.mail.contoso.com'] = New-TestLookup -Name '_dmarc.mail.contoso.com' -Status 'Error' -Message 'Timed out'

            Test-MtCisaDmarcRecordExist | Should -BeTrue

            $script:testResultMarkdown | Should -Match '\| mail\.contoso\.com \| ✅ Pass \| \\_dmarc\.contoso\.com \|'
        }

        It 'fails a domain with more than one DMARC record and none above it' {
            Mock -ModuleName Maester Get-MtExo { return @(New-TestAcceptedDomain -DomainName 'contoso.com') }
            $script:dnsAnswers['_dmarc.contoso.com'] = @('v=DMARC1; p=none;', 'v=DMARC1; p=reject;')

            Test-MtCisaDmarcRecordExist | Should -BeFalse

            $script:testResultMarkdown | Should -Match '\\_dmarc\.contoso\.com has more than one DMARC record'
        }

        It 'escapes the record in the result' {
            $script:dnsAnswers['_dmarc.contoso.com'] = 'v=DMARC1; p=reject; rua=mailto:a@contoso.com!10m|$1'

            Test-MtCisaDmarcRecordExist | Should -BeTrue

            $script:testResultMarkdown | Should -BeLike '*rua=mailto:a@contoso.com\!10m\|$1 |*'
        }

        It 'skips when no DNS resolver is available' {
            $script:dnsAnswers['_dmarc.contoso.com'] = New-TestLookup -Name '_dmarc.contoso.com' -Status 'NotAvailable' -Message 'Missing dependency, Resolve-Dns not available'

            Test-MtCisaDmarcRecordExist | Should -BeNullOrEmpty

            $script:skippedBecause | Should -Be 'NotSupported'
        }

        It 'accepts and ignores -Strict' {
            $script:dnsAnswers.Remove('_dmarc.contoso.com')

            Test-MtCisaDmarcRecordExist -Strict | Should -BeFalse
            $strictMarkdown = $script:testResultMarkdown
            Test-MtCisaDmarcRecordExist | Should -BeFalse

            $script:testResultMarkdown | Should -Be $strictMarkdown
        }
    }
}

Describe 'Resolve-MtDnsTxtRecord' {
    Context 'with Resolve-Dns from DnsClient-PS' -Skip:$IsWindows {
        BeforeAll {
            $script:createdStub = $false
            if (-not (Get-Command -Name 'Resolve-Dns' -ErrorAction SilentlyContinue)) {
                function global:Resolve-Dns {
                    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Stands in for Resolve-Dns from DnsClient-PS.')]
                    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Declares the parameters of DnsClient-PS for Pester mock binding.')]
                    [CmdletBinding()]
                    param($Query, $QueryType)
                }
                $script:createdStub = $true
            }
        }

        AfterAll {
            if ($script:createdStub) {
                Remove-Item -Path 'function:global:Resolve-Dns' -ErrorAction SilentlyContinue
            }
        }

        It 'returns every TXT answer, joining the strings of each record' {
            Mock -ModuleName Maester Resolve-Dns {
                [pscustomobject]@{
                    HasError = $false
                    Header   = [pscustomobject]@{ ResponseCode = 'NoError' }
                    Answers  = @(
                        [pscustomobject]@{ RecordType = 'CNAME'; CanonicalName = 'dmarc.example.net.' },
                        [pscustomobject]@{ RecordType = 'TXT'; Text = @('v=DMARC1; p=reject; rua=mailto:reports@', 'contoso.com') },
                        [pscustomobject]@{ RecordType = 'TXT'; Text = @('some unrelated TXT record') }
                    )
                }
            }

            $result = Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com'

            $result.Status | Should -Be 'Success'
            $result.Answers | Should -Be @('v=DMARC1; p=reject; rua=mailto:reports@contoso.com', 'some unrelated TXT record')
            Should -Invoke -ModuleName Maester Resolve-Dns -Exactly 1 -ParameterFilter { $Query -eq '_dmarc.contoso.com' -and $QueryType -eq 'TXT' }
        }

        It 'returns no answers when the name has no TXT records' {
            Mock -ModuleName Maester Resolve-Dns {
                [pscustomobject]@{ HasError = $false; Header = [pscustomobject]@{ ResponseCode = 'NoError' }; Answers = @() }
            }

            $result = Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com'

            $result.Status | Should -Be 'Success'
            $result.Answers | Should -HaveCount 0
        }

        It 'reports NXDomain when the name does not exist' {
            Mock -ModuleName Maester Resolve-Dns {
                [pscustomobject]@{ HasError = $true; ErrorMessage = 'Non-Existent Domain'; Header = [pscustomobject]@{ ResponseCode = 'NotExistentDomain' }; Answers = @() }
            }

            (Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com').Status | Should -Be 'NXDomain'
        }

        It 'reports an error when the server fails' {
            Mock -ModuleName Maester Resolve-Dns {
                [pscustomobject]@{ HasError = $true; ErrorMessage = 'Server Failure'; Header = [pscustomobject]@{ ResponseCode = 'ServerFailure' }; Answers = @() }
            }

            $result = Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com'

            $result.Status | Should -Be 'Error'
            $result.Error | Should -Be 'Server Failure'
        }

        It 'reports an error when the query throws' {
            Mock -ModuleName Maester Resolve-Dns { throw 'Connection timed out' }

            $result = Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com'

            $result.Status | Should -Be 'Error'
            $result.Error | Should -Be 'Connection timed out'
        }

        It 'reports NotAvailable when DnsClient-PS is not installed' {
            Mock -ModuleName Maester Get-Command { } -ParameterFilter { $Name -eq 'Resolve-Dns' }

            $result = Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com'

            $result.Status | Should -Be 'NotAvailable'
            $result.Error | Should -BeLike '*not available'
        }
    }

    Context 'with Resolve-DnsName on Windows' -Skip:(-not $IsWindows) {
        BeforeAll {
            function New-TestDnsError {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that only builds test data.')]
                param([string]$ErrorId)

                [System.Management.Automation.ErrorRecord]::new(
                    [System.ComponentModel.Win32Exception]::new('DNS query failed'),
                    "$ErrorId,Microsoft.DnsClient.Commands.ResolveDnsName",
                    [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
                    $null)
            }
        }

        It 'returns every TXT answer, joining the strings of each record' {
            Mock -ModuleName Maester Resolve-DnsName {
                @(
                    [pscustomobject]@{ Section = 'Answer'; Type = 'CNAME'; NameHost = 'dmarc.example.net' },
                    [pscustomobject]@{ Section = 'Answer'; Type = 'TXT'; Strings = @('v=DMARC1; p=reject; rua=mailto:reports@', 'contoso.com') },
                    [pscustomobject]@{ Section = 'Answer'; Type = 'TXT'; Strings = @('some unrelated TXT record') },
                    [pscustomobject]@{ Section = 'Authority'; Type = 'SOA'; PrimaryServer = 'ns1.contoso.com' }
                )
            }

            $result = Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com'

            $result.Status | Should -Be 'Success'
            $result.Answers | Should -Be @('v=DMARC1; p=reject; rua=mailto:reports@contoso.com', 'some unrelated TXT record')
            Should -Invoke -ModuleName Maester Resolve-DnsName -Exactly 1 -ParameterFilter { $Name -eq '_dmarc.contoso.com' -and $Type -eq 'TXT' }
        }

        It 'reports NXDomain when the name does not exist' {
            Mock -ModuleName Maester Resolve-DnsName { throw (New-TestDnsError -ErrorId 'DNS_ERROR_RCODE_NAME_ERROR') }

            (Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com').Status | Should -Be 'NXDomain'
        }

        It 'returns no answers when the name has no TXT records' {
            Mock -ModuleName Maester Resolve-DnsName { throw (New-TestDnsError -ErrorId 'DNS_INFO_NO_RECORDS') }

            $result = Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com'

            $result.Status | Should -Be 'Success'
            $result.Answers | Should -HaveCount 0
        }

        It 'reports an error when the query fails' {
            Mock -ModuleName Maester Resolve-DnsName { throw (New-TestDnsError -ErrorId 'ERROR_TIMEOUT') }

            $result = Resolve-MtDnsTxtRecord -Name '_dmarc.contoso.com'

            $result.Status | Should -Be 'Error'
            $result.Error | Should -Be 'DNS query failed'
        }
    }
}
