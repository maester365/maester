Describe 'Get-MailAuthenticationRecord' {
    BeforeEach {
        Clear-MtDnsCache

        Mock ConvertFrom-MailAuthenticationRecordSpf -ModuleName Maester {
            [PSCustomObject]@{
                terms = @()
            }
        }

        Mock Resolve-SPFRecord -ModuleName Maester {
            [PSCustomObject]@{
                IPAddress = '192.0.2.1'
            }
        }
    }

    It 'Does not pass Server to SPF lookup when DnsServerIpAddress is omitted' {
        Get-MailAuthenticationRecord -DomainName 'contoso.com' -Records SPF | Out-Null

        Should -Invoke Resolve-SPFRecord -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Name -eq 'contoso.com' -and -not $PSBoundParameters.ContainsKey('Server')
        }
    }

    It 'Does not pass Server to SPF lookup when DnsServerIpAddress is explicitly null' {
        { Get-MailAuthenticationRecord -DomainName 'contoso.com' -Records SPF -DnsServerIpAddress $null } | Should -Not -Throw

        Should -Invoke Resolve-SPFRecord -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Name -eq 'contoso.com' -and -not $PSBoundParameters.ContainsKey('Server')
        }
    }

    It 'Passes Server to SPF lookup when DnsServerIpAddress has a value' {
        Get-MailAuthenticationRecord -DomainName 'contoso.com' -Records SPF -DnsServerIpAddress '1.1.1.1' | Out-Null

        Should -Invoke Resolve-SPFRecord -ModuleName Maester -Exactly 1 -ParameterFilter {
            $Name -eq 'contoso.com' -and $Server -eq '1.1.1.1'
        }
    }
}

Describe 'ConvertFrom-MailAuthenticationRecord DNS error classification' {
    BeforeAll {
        $script:DnsResolverCommand = if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') { 'Resolve-DnsName' } else { 'Resolve-Dns' }
        $script:CreatedDnsResolverStub = & (Get-Module Maester) {
            param($CommandName)
            if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
                # DnsClient-PS is optional. Provide the command signature so Pester can mock it offline.
                Set-Item -Path "Function:script:$CommandName" -Value {
                    [CmdletBinding()]
                    param($Query, $QueryType, $NameServer)
                    throw 'The DNS resolver must be mocked in this test.'
                }
                $true
            } else {
                $false
            }
        } $script:DnsResolverCommand
    }

    AfterAll {
        if ($script:CreatedDnsResolverStub) {
            & (Get-Module Maester) {
                param($CommandName)
                Remove-Item -Path "Function:script:$CommandName"
            } $script:DnsResolverCommand
        }
    }

    BeforeEach {
        Mock -CommandName $script:DnsResolverCommand -ModuleName Maester {
            throw [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('No DNS records were returned.'),
                'DNS_INFO_NO_RECORDS',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $null
            )
        }
    }

    It 'classifies DNS_INFO_NO_RECORDS as a missing SPF record' {
        ConvertFrom-MailAuthenticationRecordSpf -DomainName 'contoso.com' | Should -Be 'Failure to obtain record'
    }

    It 'classifies DNS_INFO_NO_RECORDS as a missing DKIM record' {
        ConvertFrom-MailAuthenticationRecordDkim -DomainName 'contoso.com' -DkimDnsName 'selector._domainkey.contoso.com' | Should -Be 'Failure to obtain record'
    }

    It 'classifies DNS_INFO_NO_RECORDS as a missing DMARC record' {
        ConvertFrom-MailAuthenticationRecordDmarc -DomainName 'contoso.com' | Should -Be 'Failure to obtain record'
    }

    It 'keeps DNS resolver failures classified as unavailable' {
        Mock -CommandName $script:DnsResolverCommand -ModuleName Maester {
            throw [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('The DNS server returned a failure.'),
                'DNS_ERROR_RCODE_SERVER_FAILURE',
                [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
                $null
            )
        }

        ConvertFrom-MailAuthenticationRecordSpf -DomainName 'contoso.com' | Should -Be 'DNS lookup unavailable'
    }

    It 'keeps DKIM resolver failures classified as unavailable' {
        Mock -CommandName $script:DnsResolverCommand -ModuleName Maester {
            throw [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('The DNS server returned a failure.'),
                'DNS_ERROR_RCODE_SERVER_FAILURE',
                [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
                $null
            )
        }

        ConvertFrom-MailAuthenticationRecordDkim -DomainName 'contoso.com' -DkimDnsName 'selector._domainkey.contoso.com' | Should -Be 'DNS lookup unavailable'
    }

    It 'keeps DMARC resolver failures classified as unavailable' {
        Mock -CommandName $script:DnsResolverCommand -ModuleName Maester {
            throw [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('The DNS server returned a failure.'),
                'DNS_ERROR_RCODE_SERVER_FAILURE',
                [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
                $null
            )
        }

        ConvertFrom-MailAuthenticationRecordDmarc -DomainName 'contoso.com' | Should -Be 'DNS lookup unavailable'
    }

    It 'returns invalid DKIM records with a false Base64 result' {
        Mock -CommandName $script:DnsResolverCommand -ModuleName Maester {
            [pscustomobject]@{
                Type = 'TXT'
                Strings = 'v=DKIM1; k=rsa; p=%%%'
                Answers = @([pscustomobject]@{ RecordType = 'TXT'; Text = 'v=DKIM1; k=rsa; p=%%%' })
            }
        }

        $record = ConvertFrom-MailAuthenticationRecordDkim -DomainName 'contoso.com' -DkimDnsName 'selector._domainkey.contoso.com'

        $record.GetType().Name | Should -Be 'DKIMRecord'
        $record.validBase64 | Should -BeFalse
    }

    It 'returns an invalid DMARC record without classifying it as DNS unavailability' {
        Mock -CommandName $script:DnsResolverCommand -ModuleName Maester {
            [pscustomobject]@{
                Type = 'TXT'
                Strings = 'v=DMARC1; p=reject; pct=101'
                Answers = @([pscustomobject]@{ RecordType = 'TXT'; Text = 'v=DMARC1; p=reject; pct=101' })
            }
        }

        ConvertFrom-MailAuthenticationRecordDmarc -DomainName 'contoso.com' | Should -Be 'Invalid DMARC record'
    }

    It 'returns a malformed DMARC URI as an invalid record' {
        Mock -CommandName $script:DnsResolverCommand -ModuleName Maester {
            [pscustomobject]@{
                Type = 'TXT'
                Strings = 'v=DMARC1; p=reject; rua=mailto:@@; ruf=mailto:forensic@contoso.com'
                Answers = @([pscustomobject]@{ RecordType = 'TXT'; Text = 'v=DMARC1; p=reject; rua=mailto:@@; ruf=mailto:forensic@contoso.com' })
            }
        }

        ConvertFrom-MailAuthenticationRecordDmarc -DomainName 'contoso.com' | Should -Be 'Invalid DMARC record'
    }
}
